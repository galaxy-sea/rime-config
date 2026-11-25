#!/usr/bin/env bash

set -Eeuo pipefail
trap 'status=$?; printf "失败：%s 第 %s 行执行出错（退出码 %s），原因见上方错误。\n" "${0##*/}" "$LINENO" "$status" >&2' ERR
printf '%s\n' '正在部署 iOS 配置和主题…'

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_ID="com.ihsiao.apps.Hamster3"
SKINS="$ROOT/ios/Skins"
RIME_DATA="$ROOT/ios/RimeUserData"

START=$SECONDS

# 搜索设备
:

DEVICES="$(pymobiledevice3 usbmux list | python3 -c '
import json
import sys

seen = set()

for device in json.load(sys.stdin):
    if device.get("DeviceClass") not in ("iPhone", "iPad"):
        continue

    udid = device.get("UniqueDeviceID") or device.get("Identifier")

    if not udid or udid in seen:
        continue

    seen.add(udid)

    print("\t".join([
        udid,
        device.get("DeviceName", "Unknown")
    ]))
')"

if [[ -z "$DEVICES" ]]; then
    echo "未发现可用设备"
    exit 1
fi

# 筛选安装元书的设备
TARGETS=()
NAMES=()
COUNT=0

while IFS=$'\t' read -r udid name; do

    # 支持手动指定设备
    if [[ -n "${UDID:-}" && "$udid" != "$UDID" ]]; then
        continue
    fi

    :

    if ! apps="$(pymobiledevice3 apps list \
        --udid "$udid" --type User)"; then
        echo "设备访问失败，跳过：$name"
        continue
    fi

    installed="$(python3 -c '
import json
import sys

apps = json.load(sys.stdin)
print("yes" if sys.argv[1] in apps else "no")
' "$APP_ID" <<< "$apps")"

    if [[ "$installed" == "yes" ]]; then
        TARGETS+=("$udid")
        NAMES+=("$name")
        COUNT=$((COUNT + 1))

        :
    else
        :
    fi

done <<< "$DEVICES"

if [[ "$COUNT" -eq 0 ]]; then
    echo "没有找到安装元书的可用设备"
    exit 1
fi

:
bash "$ROOT/scripts/lib/phrase-crypt.sh" > /dev/null

# 确认目标设备后再编译；失败时停止同步。
if [[ "${SKIP_BUILD:-0}" != "1" ]]; then
    :
    bash "$ROOT/scripts/lib/compile-ios.sh" > /dev/null
fi

# 加解密成功后应有本地明文供部署使用。
if [[ ! -f "$ROOT/shared/rime-ice/custom_phrase.txt" ]]; then
    echo "缺少本地 custom_phrase.txt；如已有密文，请先运行 bash scripts/lib/phrase-crypt.sh decrypt" >&2
    exit 1
fi

# 准备部署资源
printf '\n'
STAGE="$(mktemp -d)"
trap 'rm -rf -- "$STAGE"' EXIT

mkdir -p "$STAGE/Skins"

SKIN_COUNT=0
SKIN_NAMES=""

for skin in "$SKINS"/*; do
    [[ -f "$skin/config.yaml" ]] || continue
    [[ -d "$skin/light" && -d "$skin/dark" ]] || continue

    name="$(basename "$skin")"
    target="$STAGE/Skins/$name"

    # 上传完整主题，包含预览图、说明和 Jsonnet 源文件。
    cp -R "$skin" "$target"

    SKIN_COUNT=$((SKIN_COUNT + 1))

    SKIN_NAMES="${SKIN_NAMES:+${SKIN_NAMES}、}${name}"
done

if [[ "$SKIN_COUNT" -eq 0 ]]; then
    echo "没有找到可部署的皮肤"
    exit 1
fi

# 先合并共享配置，再覆盖 iOS 专属配置；仅在暂存目录操作。
if [[ -d "$ROOT/shared" || -d "$RIME_DATA" ]]; then
    mkdir -p "$STAGE/RimeUserData"
    if [[ -d "$ROOT/shared" ]]; then
        cp -R "$ROOT/shared/." "$STAGE/RimeUserData/"
    fi
    if [[ -d "$RIME_DATA" ]]; then
        cp -R "$RIME_DATA/." "$STAGE/RimeUserData/"
    fi
    RIME_DATA="$STAGE/RimeUserData"
fi
find "$STAGE" -type f -iname '.DS_Store' -delete
# 私人短语密文仅用于仓库存储，不上传到输入法。
rm -f "$STAGE/RimeUserData/rime-ice/custom_phrase.txt.gpg" "$STAGE/RimeUserData/rime-ice/custom_phrase.txt.sha256"

:

# 部署所有目标设备
SUCCESS=0
FAILED=0

# 每个主题使用独立连接和日志；同一主题严格先删后传。
deploy_skin() {
    local udid="$1" skin="$2" log="$3" name
    name="$(basename "$skin")"
    if ! pymobiledevice3 apps rm --documents --udid "$udid" \
        "$APP_ID" "/Documents/Skins/$name" >"$log" 2>&1; then
        if ! grep -Eq 'OBJECT_NOT_FOUND|ObjectNotFound|No such file' "$log"; then
            cat "$log" >&2
            return 1
        fi
    fi
    pymobiledevice3 apps push --documents --udid "$udid" \
        "$APP_ID" "$skin" "/Documents/Skins"
}

deploy_device() {
    local index="$1" skin task status=0
    local tasks=()
    mkdir -p "$STAGE/device-$index"
    for skin in "$STAGE/Skins"/*; do
        deploy_skin "${TARGETS[$index]}" "$skin" \
            "$STAGE/device-$index/$(basename "$skin").remove.log" &
        tasks+=("$!")
    done
    # 配置只覆盖同名文件，与主题目录上传并行。
    if [[ -d "$RIME_DATA" ]]; then
        pymobiledevice3 apps push --documents --udid "${TARGETS[$index]}" \
            "$APP_ID" "$RIME_DATA" "/Documents" &
        tasks+=("$!")
    fi
    for task in "${tasks[@]}"; do
        if ! wait "$task"; then
            status=1
        fi
    done
    return "$status"
}

DEVICE_PIDS=()
for ((i = 0; i < COUNT; i++)); do
    :
    # 日志按设备收集，避免多设备的输出交错。
    deploy_device "$i" >"$STAGE/device-$i.log" 2>&1 &
    DEVICE_PIDS+=("$!")
done

for ((i = 0; i < COUNT; i++)); do
    device_ok=1
    if ! wait "${DEVICE_PIDS[$i]}"; then
        device_ok=0
    fi
    cat "$STAGE/device-$i.log"
    if [[ "$device_ok" -eq 1 ]]; then
        SUCCESS=$((SUCCESS + 1))
        :
    else
        FAILED=$((FAILED + 1))
        echo "部署失败：${NAMES[$i]}"
    fi
done

printf '部署结束：成功 %d 台，失败 %d 台，耗时 %d 秒。\n' "$SUCCESS" "$FAILED" "$((SECONDS - START))"

[[ "$FAILED" -eq 0 ]]
