#!/usr/bin/env bash
# 自动编译 ios/Skins 下所有 main.jsonnet。
set -Eeuo pipefail
trap 'status=$?; printf "失败：%s 第 %s 行执行出错（退出码 %s），原因见上方错误。\n" "${0##*/}" "$LINENO" "$status" >&2' ERR
printf '%s\n' '正在编译 iOS 主题…'

if [[ $# -ne 0 ]]; then
  echo "用法: $0（自动编译 ios/Skins 下的主题）" >&2
  exit 2
fi
JSONNET="${JSONNET:-jsonnet}"
# macOS 优先使用 sysctl，Linux 使用 getconf，无法检测时串行编译。
JOBS=$(sysctl -n hw.logicalcpu 2>/dev/null || getconf _NPROCESSORS_ONLN 2>/dev/null || echo 1)
if [[ ! "$JOBS" =~ ^[1-9][0-9]*$ ]]; then
  JOBS=1
fi
if ! command -v "$JSONNET" >/dev/null 2>&1; then
  echo "找不到 Jsonnet 可执行文件：$JSONNET" >&2
  exit 1
fi
# 子进程切换目录后仍能使用相对路径指定的可执行文件。
JSONNET=$(command -v "$JSONNET")
if [[ "$JSONNET" != /* ]]; then
  JSONNET="$PWD/$JSONNET"
fi
export JSONNET

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
work_dir=$(mktemp -d)
trap 'rm -rf -- "$work_dir"' EXIT
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
  :
  theme_start=$SECONDS
  (
    cd -- "$source_dir"
    export OUTPUT="$output_dir"
    # 先完整获取文件名；失败时不启动写入任务。NUL 分隔兼容空格。
    "$JSONNET" -S --no-trailing-newline -e \
      'std.join("\u0000", std.objectFields(import "main.jsonnet")) + "\u0000"' \
      > "$work_dir/outputs"
    xargs -0 -P "$JOBS" -I '{}' bash -c '
      set -euo pipefail
      key="$1"
      [[ -n "$key" ]] || exit 0
      mkdir -p -- "$(dirname -- "$OUTPUT/$key")"
      "$JSONNET" -S --ext-str "output=$key" -o "$OUTPUT/$key" \
        -e "(import \"main.jsonnet\")[std.extVar(\"output\")]"
    ' _ '{}' < "$work_dir/outputs"
  )
  theme_names+=("${output_dir#"$repo_dir/ios/Skins/"}")
  theme_times+=("$((SECONDS - theme_start))")
done < <(find "$repo_dir/ios/Skins" -type f -name main.jsonnet -print0)

if [[ $found -eq 0 ]]; then
  echo "未找到 main.jsonnet" >&2
  exit 1
fi

printf '编译成功，耗时 %d 秒。\n' "$((SECONDS - total_start))"
