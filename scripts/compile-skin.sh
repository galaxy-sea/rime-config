#!/usr/bin/env bash
# 自动编译 ios/Skins 下所有 main.jsonnet。
set -euo pipefail

if [[ $# -ne 0 ]]; then
  echo "用法: $0（自动编译 ios/Skins 下的主题）" >&2
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
  # jsonnet/main.jsonnet 输出到上一级主题目录；直接放在主题下也支持。
  output_dir="$source_dir"
  if [[ $(basename -- "$source_dir") == jsonnet ]]; then
    output_dir=$(dirname -- "$source_dir")
  fi
  echo "编译：$source_file"
  theme_start=$SECONDS
  mkdir -p -- "$output_dir/light" "$output_dir/dark"
  jsonnet -S -m "$output_dir" -- "$source_file"
  theme_names+=("${output_dir#"$repo_dir/ios/Skins/"}")
  theme_times+=("$((SECONDS - theme_start))")
done < <(find "$repo_dir/ios/Skins" -type f -name main.jsonnet -print0)

if [[ $found -eq 0 ]]; then
  echo "未找到 main.jsonnet" >&2
  exit 1
fi

printf '\n编译耗时统计：\n'
for ((i = 0; i < ${#theme_names[@]}; i++)); do
  printf '  %s：%d 秒\n' "${theme_names[i]}" "${theme_times[i]}"
done
printf '总耗时：%d 秒\n' "$((SECONDS - total_start))"
