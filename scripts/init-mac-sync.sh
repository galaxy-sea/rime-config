#!/usr/bin/env bash
# 将 Fcitx5-Rime 同步目录链接至 iCloud Drive。
set -Eeuo pipefail
trap 'status=$?; printf "失败：%s 第 %s 行执行出错（退出码 %s），原因见上方错误。\n" "${0##*/}" "$LINENO" "$status" >&2' ERR
printf '%s\n' '正在配置 iCloud 同步目录…'

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
RIME="$HOME/.local/share/fcitx5/rime"
CLOUD_ROOT="$HOME/Library/Mobile Documents/com~apple~CloudDocs"
CLOUD="$CLOUD_ROOT/RimeSync"

if [[ ! -d "$CLOUD_ROOT" ]]; then
    echo "找不到 iCloud Drive 目录，请先启用 iCloud Drive：$CLOUD_ROOT" >&2
    exit 1
fi
if [[ -L "$RIME/sync" ]]; then
    current="$(readlink "$RIME/sync")"
    if [[ "$current" == "$CLOUD" ]]; then
        mkdir -p "$CLOUD"
        printf '同步链接已配置：%s → %s\n' "$RIME/sync" "$CLOUD"
        exit 0
    fi
    printf '已有其他同步链接，未修改：%s → %s\n' "$RIME/sync" "$current" >&2
    exit 1
fi
if [[ -e "$RIME/sync" && ! -d "$RIME/sync" ]]; then
    echo "sync 已存在且不是目录，未修改：$RIME/sync" >&2
    exit 1
fi

mkdir -p "$RIME" "$CLOUD"
if [[ -d "$RIME/sync" ]]; then
    backup_dir="$ROOT/backups/mac-sync/$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$ROOT/backups/mac-sync"
    # 同一秒的备份不覆盖；仅在迁移现有数据时创建目录。
    mkdir "$backup_dir"
    backup="$backup_dir/local-sync"
    # 同名文件以本地为准；先保留云端副本，避免丢失旧版本。
    if [[ -n "$(ls -A "$CLOUD")" ]]; then
        cloud_backup="$backup_dir/icloud-sync"
        [[ ! -e "$cloud_backup" ]] || { echo "云端备份已存在：$cloud_backup" >&2; exit 1; }
        ditto "$CLOUD" "$cloud_backup"
        :
    fi
    ditto "$RIME/sync" "$CLOUD"
    mv "$RIME/sync" "$backup"
    :
fi

ln -s "$CLOUD" "$RIME/sync"
:
:
echo "iCloud 同步目录配置成功。"
