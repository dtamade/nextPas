#!/usr/bin/env bash

set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$root_dir"

fail() {
  echo "[FAIL] $1" >&2
  exit 1
}

require_fixed() {
  local file="$1"
  local pattern="$2"
  local message="$3"
  if ! rg -F -n --quiet -- "$pattern" "$file"; then
    fail "$message"
  fi
}

require_absent() {
  local file="$1"
  local pattern="$2"
  local message="$3"
  if rg -F -n --quiet -- "$pattern" "$file"; then
    fail "$message"
  fi
}

cms_guide="docs/guides/CMS_USER_GUIDE.md"
pkcs12_guide="docs/guides/PKCS12_USER_GUIDE.md"

echo "[TEST] Specialized guides historical test snapshot contract"

require_fixed "$cms_guide" "这些测试命令是当前可执行验证入口，但不要把固定的总测试数、通过率或历史输出文本当成当前接口 truth。" \
  "CMS guide must demote historical captured test snapshots"
require_fixed "$pkcs12_guide" "这些测试命令是当前可执行验证入口，但不要把固定的总测试数、通过率或历史输出文本当成当前 helper/API truth。" \
  "PKCS12 guide must demote historical captured test snapshots"

require_absent "$cms_guide" "43/43" \
  "CMS guide must stop hardcoding historical comprehensive test counts"
require_absent "$cms_guide" "20/20" \
  "CMS guide must stop hardcoding historical base test counts"
require_absent "$cms_guide" "总测试数:" \
  "CMS guide must stop embedding captured summary counts"
require_absent "$cms_guide" "通过率: 100.0%" \
  "CMS guide must stop embedding captured pass-rate snapshots"
require_absent "$cms_guide" "预期输出：" \
  "CMS guide must stop embedding captured expected-output snapshots"

require_absent "$pkcs12_guide" "34/34" \
  "PKCS12 guide must stop hardcoding historical comprehensive test counts"
require_absent "$pkcs12_guide" "总测试数:" \
  "PKCS12 guide must stop embedding captured summary counts"
require_absent "$pkcs12_guide" "通过率: 100.0%" \
  "PKCS12 guide must stop embedding captured pass-rate snapshots"
require_absent "$pkcs12_guide" "预期输出：" \
  "PKCS12 guide must stop embedding captured expected-output snapshots"

echo "[PASS] Specialized guides historical test snapshot contract passed"
