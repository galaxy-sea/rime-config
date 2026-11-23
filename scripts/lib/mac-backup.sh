# 由部署及还原脚本加载，ROOT 和 RIME_DIR 由调用方提供。
backup_mac_rime() {
    [[ -d "$RIME_DIR" ]] || return 0
    local backup_dir="$ROOT/backups/mac/$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$ROOT/backups/mac"
    if [[ -e "$backup_dir" ]]; then
        echo "同一时间戳备份已存在，请稍后重试：$backup_dir" >&2
        return 1
    fi
    mkdir "$backup_dir"
    if ! cp -a "$RIME_DIR" "$backup_dir/rime"; then
        echo "备份失败，未执行覆盖：$backup_dir" >&2
        return 1
    fi
    MAC_BACKUP_DIR="$backup_dir"
    touch "$backup_dir/.complete"
    printf '完整备份已保存：%s\n' "$backup_dir"
}
