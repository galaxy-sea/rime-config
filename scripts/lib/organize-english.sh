#!/usr/bin/env bash
# 整理回车收集的英文；可传入另一个词库路径。
set -euo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
exec python3 "$ROOT/scripts/lib/organize_english.py" \
    "${1:-$ROOT/shared/rime-ice/tech_codes.dict.yaml}" "$ROOT/backups/english-dictionary"
