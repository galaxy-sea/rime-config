#!/usr/bin/env bash
# 跨电脑口令加密：需要 GnuPG，不依赖个人公钥或私钥。
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
PLAIN="$ROOT/shared/rime-ice/custom_phrase.txt"
CIPHER="$PLAIN.gpg"
HASH_FILE="$PLAIN.sha256"

show_failure_help() {
    local status=$?
    printf '\n短语加解密失败。\n' >&2
    printf '若只是口令输入错误，请重新运行。\n' >&2
    printf '若无法解密仓库附带的短语，请删除该密文，并创建你自己的短语文件：\n' >&2
    printf '  删除密文：%s\n' "$CIPHER" >&2
    printf '  创建明文：%s\n' "$PLAIN" >&2
    printf '  格式：短语<Tab>编码<Tab>权重，例如 Spring Security<Tab>ss<Tab>100\n' >&2
    printf '创建后重新运行部署脚本，会自动加密你的短语。文件不会被自动删除。\n' >&2
    return "$status"
}
trap show_failure_help ERR
if [[ $# -gt 1 ]]; then
    echo "用法：bash scripts/lib/phrase-crypt.sh [encrypt|decrypt]" >&2
    exit 2
fi
MODE="${1:-}"
if [[ $# -eq 0 ]]; then
    if [[ -f "$PLAIN" ]]; then
        MODE=encrypt
        :
    elif [[ -f "$CIPHER" ]]; then
        MODE=decrypt
        :
    else
        echo "没有找到 custom_phrase.txt 或 custom_phrase.txt.gpg" >&2
        exit 1
    fi
fi
case "$MODE" in
    encrypt|decrypt) ;;
    *) echo "用法：bash scripts/lib/phrase-crypt.sh [encrypt|decrypt]" >&2; exit 2 ;;
esac
command -v gpg >/dev/null 2>&1 || { echo "请先安装 GnuPG（macOS：brew install gnupg）" >&2; exit 1; }
sha256_file() {
    if command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$1" | cut -d ' ' -f 1
    elif command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" | cut -d ' ' -f 1
    else
        echo "缺少 SHA-256 工具：shasum 或 sha256sum" >&2
        return 1
    fi
}

WORK=$(mktemp -d)
trap 'rm -rf -- "$WORK"' EXIT
case "$MODE" in
    encrypt)
        [[ -f "$PLAIN" ]] || { echo "找不到明文：$PLAIN" >&2; exit 1; }
        cp "$PLAIN" "$WORK/source"
        source_hash=$(sha256_file "$WORK/source")
        if [[ -f "$CIPHER" && -f "$HASH_FILE" ]] && [[ "$(cat "$HASH_FILE")" == "$source_hash" ]]; then
            echo "短语未变化，保留现有密文。"
            exit 0
        fi
        :
        gpg --quiet --pinentry-mode loopback --symmetric --cipher-algo AES256 \
            --output "$WORK/encrypted.gpg" "$WORK/source"
        :
        gpg --quiet --pinentry-mode loopback --output "$WORK/verified" --decrypt "$WORK/encrypted.gpg"
        cmp -s "$WORK/source" "$WORK/verified" || { echo "校验失败，未更新密文" >&2; exit 1; }
        cp "$WORK/encrypted.gpg" "$CIPHER"
        printf '%s\n' "$source_hash" > "$HASH_FILE"
        echo "加密及解密比对通过：$CIPHER"
        :
        ;;
    decrypt)
        [[ -f "$CIPHER" ]] || { echo "找不到密文：$CIPHER" >&2; exit 1; }
        if [[ -e "$PLAIN" ]]; then
            echo "本地明文已存在，请先备份或移走，避免覆盖：$PLAIN" >&2
            exit 1
        fi
        gpg --quiet --pinentry-mode loopback --output "$WORK/plain" --decrypt "$CIPHER"
        cp "$WORK/plain" "$PLAIN"
        chmod 600 "$PLAIN"
        sha256_file "$PLAIN" > "$HASH_FILE"
        echo "已解密：$PLAIN"
        ;;
    *) echo "用法：bash scripts/lib/phrase-crypt.sh [encrypt|decrypt]" >&2; exit 2 ;;
esac
