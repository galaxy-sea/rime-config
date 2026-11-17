#!/usr/bin/env bash
# 将皮肤 Jsonnet 返回的文件映射编译到皮肤目录。
set -euo pipefail

if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo "用法: $0 <皮肤目录/jsonnet/main.jsonnet> [输出目录]" >&2
  exit 2
fi
if ! command -v jsonnet >/dev/null 2>&1; then
  echo "缺少 jsonnet，请先安装：brew install jsonnet" >&2
  exit 1
fi
if [[ ! -f "$1" ]]; then
  echo "找不到 Jsonnet 入口：$1" >&2
  exit 1
fi

source_dir=$(cd -- "$(dirname -- "$1")" && pwd)
source_file="$source_dir/$(basename -- "$1")"
output_dir=${2:-"$(dirname -- "$source_dir")"}
mkdir -p -- "$output_dir/light" "$output_dir/dark"
jsonnet -S -m "$output_dir" -- "$source_file"
