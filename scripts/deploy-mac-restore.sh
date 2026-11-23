#!/usr/bin/env bash
# 在工程备份中选择完整版本进行还原。
set -euo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
RIME_DIR="$HOME/.local/share/fcitx5/rime"
FCITX_APP="/Library/Input Methods/Fcitx5.app"
source "$ROOT/scripts/lib/mac-backup.sh"

[[ -d "$FCITX_APP" ]] || { echo "找不到 Fcitx5：$FCITX_APP" >&2; exit 1; }
shopt -s nullglob
BACKUPS=()
for backup in "$ROOT"/backups/mac/*; do
    [[ -d "$backup/rime" && -f "$backup/.complete" ]] || continue
    BACKUPS=("$backup" "${BACKUPS[@]}")
done
[[ ${#BACKUPS[@]} -gt 0 ]] || { echo "工程中没有完整备份" >&2; exit 1; }
[[ -t 0 ]] || { echo "请在交互终端中运行，以选择还原版本" >&2; exit 1; }

selected=0
printf '选择还原版本：↑↓ 移动，回车还原，q 取消\n'
while true; do
    for ((i = 0; i < ${#BACKUPS[@]}; i++)); do
        if ((i == selected)); then
            printf '\033[2K> %s\n' "${BACKUPS[$i]##*/}"
        else
            printf '\033[2K  %s\n' "${BACKUPS[$i]##*/}"
        fi
    done
    IFS= read -rsn1 key || exit 1
    case "$key" in
        q|Q) printf '\n已取消\n'; exit 0 ;;
        '') break ;;
        $'\e')
            sequence=""
            IFS= read -rsn2 -t 1 sequence || true
            case "$sequence" in
                '[A'|'OA') selected=$(((selected + ${#BACKUPS[@]} - 1) % ${#BACKUPS[@]})) ;;
                '[B'|'OB') selected=$(((selected + 1) % ${#BACKUPS[@]})) ;;
            esac ;;
    esac
    printf '\033[%dA' "${#BACKUPS[@]}"
done

chosen="${BACKUPS[$selected]}"
printf '\n还原版本：%s\n' "${chosen##*/}"
# 覆盖前保存当前完整状态；失败时不会继续还原。
backup_mac_rime
mkdir -p "$RIME_DIR"
# 完整还原，移除所选版本中不存在的文件。
rsync -a --delete "$chosen/rime/" "$RIME_DIR/"
printf '\n正在重启 Fcitx5...\n'
# 未运行时 pkill 返回 1，仍继续启动；其他错误停止。
pkill -x Fcitx5 || [[ $? -eq 1 ]]
sleep 1
open -a "$FCITX_APP"
echo "还原完成"
