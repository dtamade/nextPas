#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$repo_root"

pass() {
  printf '[PASS] %s\n' "$1"
}

fail() {
  printf '[FAIL] %s\n' "$1"
  if [[ $# -ge 2 ]]; then
    printf '       %s\n' "$2"
  fi
  exit 1
}

require_match() {
  local file="$1"
  local pattern="$2"
  local name="$3"
  if rg -n --multiline --multiline-dotall "$pattern" "$file" >/dev/null; then
    pass "$name"
  else
    fail "$name" "pattern not found in $file: $pattern"
  fi
}

require_absent() {
  local file="$1"
  local pattern="$2"
  local name="$3"
  if rg -n --multiline --multiline-dotall "$pattern" "$file" >/dev/null; then
    fail "$name" "unexpected pattern still present in $file: $pattern"
  else
    pass "$name"
  fi
}

readme="README.md"
matrix="docs/BACKEND_CAPABILITY_MATRIX.md"
guide="docs/guides/EARLY_DATA_GUIDE.md"

printf '[TEST] early-data docs truth contract\n'

require_match "$readme" '\| FreePascal *\| ⚠️ *\| 实验性 *\|' \
  'README marks FreePascal early-data as experimental'
require_match "$readme" '\| WolfSSL *\| ⚠️ *\| 按构建/运行时 helper 门控 *\|' \
  'README marks WolfSSL early-data as build/runtime gated'
require_absent "$readme" '\| FreePascal *\| ✅ *\| 生产就绪 *\|' \
  'README no longer marks FreePascal early-data production ready'

require_match "$guide" '\| FreePascal *\| ✅ .* \| ✅ .* \| 实验性 *\|' \
  'guide marks FreePascal early-data as experimental'
require_match "$guide" '\| WolfSSL *\| ⚠️ .* \| ⚠️ .* \| 按构建/运行时 helper 门控 *\|' \
  'guide marks WolfSSL early-data as build/runtime gated'
require_absent "$guide" '\| FreePascal *\| ✅ 完整支持 \| ✅ 完整支持 \| 生产就绪 *\|' \
  'guide no longer marks FreePascal early-data production ready'
require_match "$guide" '若当前 `wolfSSL` 动态库未导出 early-data helpers' \
  'guide explains WolfSSL helper-gated runtime fallback'

require_match "$matrix" '### WolfSSL 后端' \
  'capability matrix keeps WolfSSL early-data section'
require_match "$matrix" '\*\*状态\*\*: ⚠️ 受 build/runtime helper 门控的实验性支持' \
  'capability matrix marks WolfSSL early-data as helper gated experimental'
require_match "$matrix" '如果当前 `wolfSSL` 动态库未导出 `wolfSSL_write_early_data`' \
  'capability matrix explains WolfSSL none fallback when helpers are missing'
require_absent "$matrix" '当前已接通 `ISSLEarlyDataContext` 与 `ISSLEarlyDataConnection`' \
  'capability matrix no longer claims unconditional WolfSSL early-data interfaces'

printf '[PASS] early-data docs truth contract passed\n'
