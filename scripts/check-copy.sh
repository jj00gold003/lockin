#!/bin/bash
# 规范：源码禁止硬编码中文文案（必须走 String Catalog key）
set -euo pipefail
if grep -rn '[一-龥]' LockIn --include='*.swift'; then
  echo "::error 源码中出现硬编码中文，请改用 Localizable.xcstrings 的 key"
  exit 1
fi
echo "copy check passed"
