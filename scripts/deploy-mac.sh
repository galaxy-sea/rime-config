#!/usr/bin/env bash
# 将共享及 macOS 专属配置部署到 Fcitx5-Rime。
set -Eeuo pipefail
trap 'status=$?; printf "失败：%s 第 %s 行执行出错（退出码 %s），原因见上方错误。\n" "${0##*/}" "$LINENO" "$status" >&2' ERR
printf '%s\n' '正在部署 macOS 配置和主题…'

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
RIME_DIR="$HOME/.local/share/fcitx5/rime"
FCITX_APP="/Library/Input Methods/Fcitx5.app"
START=$SECONDS

if [[ ! -d "$FCITX_APP" ]]; then
    echo "找不到 Fcitx5：$FCITX_APP" >&2
    exit 1
fi

:
bash "$ROOT/scripts/phrase-crypt.sh" > /dev/null

shopt -s nullglob
CUSTOM_FILES=("$ROOT"/mac/RimeUserData/rime-ice/*.custom.yaml)
FILES=("$ROOT/shared/rime-ice/fuzzy.yaml" "$ROOT/shared/rime-ice/custom_phrase.txt" "${CUSTOM_FILES[@]}")
if [[ ! -f "${FILES[0]}" || ! -f "${FILES[1]}" || ${#CUSTOM_FILES[@]} -eq 0 ]]; then
    echo "缺少 fuzzy.yaml、custom_phrase.txt 或 mac 下的 *.custom.yaml 配置" >&2
    exit 1
fi

THEMES=()
for css in "$ROOT"/mac/*/style.css; do
    [[ -f "$css" ]] && THEMES+=("$(dirname "$css")")
done
[[ ${#THEMES[@]} -gt 0 ]] || { echo "没有找到包含 style.css 的 macOS 主题" >&2; exit 1; }
# macOS-Test 固定排首位，其余保持原顺序。
ORDERED=()
for theme_path in "${THEMES[@]}"; do
    [[ "${theme_path##*/}" != macOS-Test ]] || ORDERED+=("$theme_path")
done
for theme_path in "${THEMES[@]}"; do
    [[ "${theme_path##*/}" == macOS-Test ]] || ORDERED+=("$theme_path")
done
THEMES=("${ORDERED[@]}")
[[ -t 0 ]] || { echo "请在交互终端中选择主题" >&2; exit 1; }
selected=0
printf '选择 macOS 主题：↑↓ 移动，回车部署，q 取消\n'
while true; do
    for ((i = 0; i < ${#THEMES[@]}; i++)); do
        if ((i == selected)); then
            printf '\033[2K> %s\n' "${THEMES[$i]##*/}"
        else
            printf '\033[2K  %s\n' "${THEMES[$i]##*/}"
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
                '[A'|'OA') selected=$(((selected + ${#THEMES[@]} - 1) % ${#THEMES[@]})) ;;
                '[B'|'OB') selected=$(((selected + 1) % ${#THEMES[@]})) ;;
            esac ;;
    esac
    printf '\033[%dA' "${#THEMES[@]}"
done
theme="${THEMES[$selected]##*/}"
:
CSS_SOURCE="$ROOT/mac/$theme/style.css"
CSS_TARGET="$HOME/.local/share/fcitx5/www/css/style.css"
WEBPANEL_CONFIG="$HOME/.config/fcitx5/conf/webpanel.conf"
if [[ ! -f "$CSS_SOURCE" ]]; then
    echo "找不到主题 CSS：$CSS_SOURCE" >&2
    exit 1
fi
command -v python3 >/dev/null 2>&1 || { echo "缺少 python3" >&2; exit 1; }

:
mkdir -p "$RIME_DIR"
# 完整备份到工程，再覆盖配置。
source "$ROOT/scripts/lib/mac-backup.sh"
backup_mac_rime
# 与本次 Rime 快照放在同一时间戳目录，覆盖之前先保存原件。
if [[ -f "$WEBPANEL_CONFIG" ]]; then
    cp -p "$WEBPANEL_CONFIG" "$MAC_BACKUP_DIR/webpanel.conf"
fi
if [[ -f "$CSS_TARGET" ]]; then
    mkdir -p "$MAC_BACKUP_DIR/css"
    cp -p "$CSS_TARGET" "$MAC_BACKUP_DIR/css/style.css"
fi
cp "${FILES[@]}" "$RIME_DIR/"

:
bash "$ROOT/scripts/init-mac-sync.sh" > /dev/null
mkdir -p "$(dirname "$CSS_TARGET")" "$(dirname "$WEBPANEL_CONFIG")"
cp "$CSS_SOURCE" "$CSS_TARGET"
python3 - "$WEBPANEL_CONFIG" <<'PYCONFIG'
import re
import sys
from pathlib import Path
p = Path(sys.argv[1])
s = p.read_text() if p.exists() else ''
setting = 'UserCss=fcitx:///file/css/style.css'
pattern = r'(?m)^[ \t]*#?[ \t]*UserCss[ \t]*=.*$'
if re.search(pattern, s):
    s = re.sub(pattern, setting, s)
else:
    # UserCss 属于顶层配置，插在首个分组之前。
    s = setting + '\n' + s
p.write_text(s)
PYCONFIG
:


:
# 未运行时 pkill 返回 1，仍继续启动；其他错误停止。
pkill -x Fcitx5 || [[ $? -eq 1 ]]
sleep 1
open -a "$FCITX_APP"
printf '\n部署完成，耗时：%d 秒\n' "$((SECONDS - START))"
