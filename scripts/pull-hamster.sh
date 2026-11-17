#!/usr/bin/env bash
# 从元书下载 hamster.yaml，不修改设备上的文件。
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_ID="com.ihsiao.apps.Hamster3"
for tool in pymobiledevice3 python3; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "缺少命令：$tool" >&2
        exit 1
    fi
done

# 搜索设备
printf '\n正在搜索设备...\n'

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

    echo "正在检查：$name"

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

        echo "已安装元书：$name"
    else
        echo "未安装元书，跳过：$name"
    fi

done <<< "$DEVICES"

if [[ "$COUNT" -eq 0 ]]; then
    echo "没有找到安装元书的可用设备"
    exit 1
fi

# 多设备时避免将不同设备的配置写到同一个文件。
if [[ "$COUNT" -gt 1 ]]; then
    echo "发现多个目标设备，请通过 UDID 指定来源：" >&2
    for ((i = 0; i < COUNT; i++)); do
        printf '  %s  %s\n' "${TARGETS[$i]}" "${NAMES[$i]}" >&2
    done
    exit 1
fi

STAGE="$(mktemp -d)"
trap 'rm -rf -- "$STAGE"' EXIT
printf '\n正在下载：%s 的 hamster.yaml\n' "${NAMES[0]}"
pymobiledevice3 apps pull --documents --udid "${TARGETS[0]}" \
    "$APP_ID" "/Documents/hamster.yaml" "$STAGE/hamster.yaml"
if [[ ! -f "$STAGE/hamster.yaml" ]]; then
    echo "下载未生成 hamster.yaml，保留原有本地文件" >&2
    exit 1
fi
mkdir -p "$ROOT/ios"
cp "$STAGE/hamster.yaml" "$ROOT/ios/hamster.yaml"
printf '已保存：%s/ios/hamster.yaml\n' "$ROOT"
