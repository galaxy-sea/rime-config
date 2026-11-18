#!/usr/bin/env bash
# 将共享及 macOS 专属配置部署到 Fcitx5-Rime。
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
RIME_DIR="$HOME/.local/share/fcitx5/rime"
FCITX_CURL="/Library/Input Methods/Fcitx5.app/Contents/bin/fcitx5-curl"
START=$SECONDS

if [[ ! -x "$FCITX_CURL" ]]; then
    echo "找不到 Fcitx5 部署工具：$FCITX_CURL" >&2
    exit 1
fi

shopt -s nullglob
CUSTOM_FILES=("$ROOT"/mac/RimeUserData/rime-ice/*.custom.yaml)
FILES=("$ROOT/shared/rime-ice/fuzzy.yaml" "${CUSTOM_FILES[@]}")
if [[ ! -f "${FILES[0]}" || ${#CUSTOM_FILES[@]} -eq 0 ]]; then
    echo "缺少 fuzzy.yaml 或 mac 下的 *.custom.yaml 配置" >&2
    exit 1
fi

printf '正在复制配置到：%s\n' "$RIME_DIR"
mkdir -p "$RIME_DIR"
# 完整备份到工程，再覆盖配置。
source "$ROOT/scripts/lib/mac-backup.sh"
backup_mac_rime
cp "${FILES[@]}" "$RIME_DIR/"

printf '\n正在重新部署 Fcitx5-Rime...\n'
"$FCITX_CURL" /config/addon/rime/deploy -X POST -d '{}'
printf '\n部署完成，耗时：%d 秒\n' "$((SECONDS - START))"
