#!/usr/bin/env bash
# 有 root 直接覆盖元书目录，无 root 上传到下载目录等待导入。
set -Eeuo pipefail
trap 'status=$?; printf "上传失败：%s 第 %s 行执行出错（退出码 %s）。\n" "${0##*/}" "$LINENO" "$status" >&2' ERR
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
APP_ID="com.ihsiao.apps.hamster"
REMOTE=""
START=$SECONDS
for tool in adb python3; do
    command -v "$tool" >/dev/null 2>&1 || { echo "缺少命令：$tool" >&2; exit 1; }
done
printf '%s\n' '正在准备 Android 元书上传…'
TARGETS=()
while read -r serial state rest; do
    [[ "$state" == device ]] || continue
    [[ -z "${ANDROID_SERIAL:-}" || "$serial" == "$ANDROID_SERIAL" ]] || continue
    if adb -s "$serial" shell pm path "$APP_ID" | grep -q '^package:'; then
        TARGETS+=("$serial")
    fi
done < <(adb devices)
[[ ${#TARGETS[@]} -gt 0 ]] || { echo '没有找到已授权且安装元书的设备，请检查 adb devices。' >&2; exit 1; }
[[ ${#TARGETS[@]} -eq 1 ]] || { echo '发现多台设备，请通过 ANDROID_SERIAL 指定目标设备。' >&2; exit 1; }
SERIAL="${TARGETS[0]}"

HAS_ROOT=0
if ROOT_UID=$(adb -s "$SERIAL" shell "su -c 'id -u'" 2>/dev/null) && [[ "${ROOT_UID//$'\r'/}" == 0 ]]; then
    HAS_ROOT=1
    USER_ID=$(adb -s "$SERIAL" shell am get-current-user | tr -d '\r')
    [[ "$USER_ID" =~ ^[0-9]+$ ]] || { echo '无法获取 Android 用户编号。' >&2; exit 1; }
    DOCUMENTS="/data/user/$USER_ID/$APP_ID/files/Documents"
    adb -s "$SERIAL" shell "su -c 'test -d $DOCUMENTS'" || {
        echo '找不到元书 Documents 目录，请先打开元书完成初始化。' >&2
        exit 1
    }
else
    echo '未获得 root，将上传到下载目录，完成后需手动导入元书。'
fi

bash "$ROOT/scripts/lib/phrase-crypt.sh" > /dev/null
if [[ "${SKIP_BUILD:-0}" != 1 ]]; then
    bash "$ROOT/scripts/lib/compile-ios.sh"
fi
[[ -f "$ROOT/shared/rime-ice/custom_phrase.txt" ]] || { echo '缺少本地 custom_phrase.txt 明文。' >&2; exit 1; }
STAGE=$(mktemp -d)
cleanup() {
    if [[ -n "$REMOTE" ]]; then
        adb -s "$SERIAL" shell "rm -rf -- '$REMOTE'" >/dev/null 2>&1 || true
    fi
    rm -rf -- "$STAGE"
}
trap cleanup EXIT
mkdir -p "$STAGE/Skins" "$STAGE/RimeUserData"
SKIN_NAMES=()
for skin in "$ROOT"/ios/Skins/*; do
    [[ -f "$skin/config.yaml" && -d "$skin/light" && -d "$skin/dark" ]] || continue
    cp -R "$skin" "$STAGE/Skins/"
    SKIN_NAMES+=("${skin##*/}")
done
[[ ${#SKIN_NAMES[@]} -gt 0 ]] || { echo '没有找到可上传的主题。' >&2; exit 1; }
# 共享文件先复制，平台个性化文件覆盖同名文件，保留 Lua 子目录内容。
cp -R "$ROOT/shared/." "$STAGE/RimeUserData/"
cp -R "$ROOT/ios/RimeUserData/." "$STAGE/RimeUserData/"
if [[ -d "$ROOT/ios/Scripts" ]]; then
    cp -R "$ROOT/ios/Scripts" "$STAGE/Scripts"
fi
[[ -f "$ROOT/ios/hamster.yaml" ]] || { echo '找不到 ios/hamster.yaml，停止上传。' >&2; exit 1; }
cp "$ROOT/ios/hamster.yaml" "$STAGE/hamster.yaml"
find "$STAGE" -type f \( -iname '.DS_Store' -o -name '*.gpg' -o -name '*.sha256' -o -name '*.tmp' \) -delete

# 无 root 时保留完整上传目录，不将“上传成功”误报为“已覆盖元书”。
if [[ "$HAS_ROOT" == 0 ]]; then
    DEST="/sdcard/Download/rime-config"
    adb -s "$SERIAL" shell "mkdir -p '$DEST/Skins'" >/dev/null
    for name in "${SKIN_NAMES[@]}"; do
        quoted=$(python3 -c 'import shlex, sys; print(shlex.quote(sys.argv[1]))' "$DEST/Skins/$name")
        adb -s "$SERIAL" shell "rm -rf -- $quoted" >/dev/null
    done
    adb -s "$SERIAL" push "$STAGE/." "$DEST/" >"$STAGE/upload.log" 2>&1 || {
        cat "$STAGE/upload.log" >&2
        exit 1
    }
    printf '上传成功：%s，耗时 %d 秒；尚未覆盖元书内部目录。\n' "$DEST" "$((SECONDS - START))"
    printf '%s\n' '请在 MT 管理器添加「元书」存储入口：主题目录替换到 Skins，RimeUserData、Scripts 按文件覆盖合并，hamster.yaml 覆盖到根目录，再执行 RIME 部署并重载皮肤。'
    exit 0
fi

# 暂存文件先通过 adb 上传，再由 root 复制进应用目录。
REMOTE=$(adb -s "$SERIAL" shell mktemp -d /data/local/tmp/rime-config.XXXXXXXX | tr -d '\r')
[[ "$REMOTE" =~ ^/data/local/tmp/rime-config\.[A-Za-z0-9]+$ ]] || { echo '远端暂存目录异常。' >&2; REMOTE=""; exit 1; }
cp "$ROOT/scripts/lib/deploy-android-root.sh" "$STAGE/apply.sh"
adb -s "$SERIAL" push "$STAGE/." "$REMOTE/" >"$STAGE/upload.log" 2>&1 || {
    cat "$STAGE/upload.log" >&2
    exit 1
}
adb -s "$SERIAL" shell "su -c 'sh $REMOTE/apply.sh $REMOTE $DOCUMENTS'"
printf '上传成功，已直接覆盖元书目录，耗时 %d 秒。\n' "$((SECONDS - START))"
printf '%s\n' '请在元书中执行 RIME 部署并重载皮肤，无需手动复制文件。'
