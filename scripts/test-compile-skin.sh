#!/usr/bin/env bash
# 自动编译 ios/Skins 下所有 test-main.jsonnet。
set -Eeuo pipefail
trap 'status=$?; printf "失败：%s 第 %s 行执行出错（退出码 %s），原因见上方错误。\n" "${0##*/}" "$LINENO" "$status" >&2' ERR
printf '%s\n' '正在编译 iOS 测试主题…'

if [[ $# -ne 0 ]]; then
  echo "用法: $0（自动编译 ios/Skins 下的测试主题）" >&2
  exit 2
fi
if ! command -v jsonnet >/dev/null 2>&1; then
  echo "缺少 jsonnet，请先安装：brew install jsonnet" >&2
  exit 1
fi
repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
found=0
total_start=$SECONDS
theme_names=()
theme_times=()
while IFS= read -r -d '' source_file; do
  found=1
  source_dir=$(dirname -- "$source_file")
  # jsonnet/test-main.jsonnet 输出到上一级主题目录；直接放在主题下也支持。
  output_dir="$source_dir"
  if [[ $(basename -- "$source_dir") == jsonnet ]]; then
    output_dir=$(dirname -- "$source_dir")
  fi
  :
  theme_start=$SECONDS
  mkdir -p -- "$output_dir/light" "$output_dir/dark"
  jsonnet -S -m "$output_dir" -- "$source_file" > /dev/null
  theme_names+=("${output_dir#"$repo_dir/ios/Skins/"}")
  theme_times+=("$((SECONDS - theme_start))")
done < <(find "$repo_dir/ios/Skins" -type f -name test-main.jsonnet -print0)

if [[ $found -eq 0 ]]; then
  echo "未找到 test-main.jsonnet" >&2
  exit 1
fi

printf '编译成功，耗时 %d 秒。\n' "$((SECONDS - total_start))"
