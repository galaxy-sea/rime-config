#!/system/bin/sh
# 仅在 Android 设备上通过 root 执行，由 deploy-android.sh 传入暂存目录。
set -eu
stage=$1
documents=$2
[ "$(id -u)" = 0 ] || { echo '覆盖元书目录需要 root。' >&2; exit 1; }
[ -d "$documents" ] && [ -d "$stage/Skins" ] && [ -d "$stage/RimeUserData" ]
owner=$(stat -c '%u:%g' "$documents")
work=$(mktemp -d "${documents%/Documents}/.rime-deploy.XXXXXXXX")
trap 'rm -rf -- "$work"' EXIT
# 先在应用目录准备资源，并修正属主、访问权限，再开始覆盖。
cp -R "$stage/Skins" "$stage/RimeUserData" "$work/"
cp "$stage/hamster.yaml" "$work/hamster.yaml"
if [ -d "$stage/Scripts" ]; then cp -R "$stage/Scripts" "$work/"; fi
find "$work" -type d -exec chmod 700 {} \;
find "$work" -type f -exec chmod 600 {} \;
chown -R "$owner" "$work"
cp -a "$work/hamster.yaml" "$documents/hamster.yaml"
mkdir -p "$documents/Skins"
for skin in "$work/Skins"/*; do
    [ -d "$skin" ] || continue
    name=${skin##*/}
    rm -rf -- "$documents/Skins/$name"
    cp -a "$skin" "$documents/Skins/"
done
# 只覆盖同名文件，不删除设备上的词频数据库或其他 Lua 文件。
for name in RimeUserData Scripts; do
    [ -d "$work/$name" ] || continue
    mkdir -p "$documents/$name"
    cp -a "$work/$name/." "$documents/$name/"
done
# 新建的顶层目录归应用所有，文件的属主已在复制前处理。
chown "$owner" "$documents/Skins" "$documents/RimeUserData"
if [ -d "$documents/Scripts" ]; then chown "$owner" "$documents/Scripts"; fi
restorecon -R "$documents"
