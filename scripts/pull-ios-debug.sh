#!/usr/bin/env bash
# 拉取元书应用侧日志与 rime-ice 的 YAML / Lua 配置供本地排查。
set -Eeuo pipefail
trap 'status=$?; printf "拉取失败（退出码 %s），原因见上方错误。\n" "$status" >&2' ERR
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
APP_ID="com.ihsiao.apps.Hamster3"
printf '正在拉取元书日志与 rime-ice 配置…\n'
for tool in pymobiledevice3 python3; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "缺少命令：$tool" >&2
        exit 1
    fi
done

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

# 多设备时避免将不同设备的配置写到同一个文件。
if [[ "$COUNT" -gt 1 ]]; then
    echo "发现多个目标设备，请通过 UDID 指定设备：" >&2
    for ((i = 0; i < COUNT; i++)); do
        printf '  %s  %s\n' "${TARGETS[$i]}" "${NAMES[$i]}" >&2
    done
    exit 1
fi


mkdir -p "$ROOT/.log"
STAGE=$(mktemp -d "$ROOT/.log/.hamster-pull.XXXXXX")
trap 'rm -rf -- "$STAGE"' EXIT
# 目录下载会在目标下创建远端目录的 basename。
for remote in /Documents/Logs /Documents/RimeUserData/rime-ice; do
    if ! pymobiledevice3 apps pull --documents --udid "${TARGETS[0]}" \
        "$APP_ID" "$remote" "$STAGE" >"$STAGE/transfer.log" 2>&1; then
        cat "$STAGE/transfer.log" >&2
        echo "拉取失败：$remote；原有本地数据未修改。" >&2
        exit 1
    fi
done
[[ -d "$STAGE/Logs" && -d "$STAGE/rime-ice" ]] || {
    echo "拉取失败：下载目录不完整，原有本地数据未修改。" >&2
    exit 1
}
# CLI 递归下载后仅保留 YAML 和 Lua，保留 build、lua 等目录结构。
find "$STAGE/rime-ice" -type f ! -name '*.yaml' ! -name '*.lua' -delete
find "$STAGE/rime-ice" -type l -delete
find "$STAGE/rime-ice" -depth -type d -empty -delete
mkdir -p "$STAGE/rime-ice"
TARGET="$ROOT/.log/元书"
if [[ -e "$TARGET" ]]; then
    BACKUP="$ROOT/.log/元书备份/$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$ROOT/.log/元书备份"
    [[ ! -e "$BACKUP" ]] || { echo "同一时间戳备份已存在，请稍后重试" >&2; exit 1; }
    mv "$TARGET" "$BACKUP"
fi
mkdir -p "$TARGET"
mv "$STAGE/Logs" "$TARGET/log"
mv "$STAGE/rime-ice" "$TARGET/rime-ice"
printf '拉取成功：.log/元书/log/、.log/元书/rime-ice/（仅 YAML / Lua）\n'
