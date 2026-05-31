#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$repo_root"

fail() {
  printf '[FAIL] %s\n' "$1" >&2
  exit 1
}

require_fixed() {
  local file="$1"
  local expected="$2"
  local name="$3"
  if ! grep -Fq -- "$expected" "$file"; then
    fail "$name"
  fi
}

require_absent() {
  local file="$1"
  local expected="$2"
  local name="$3"
  if grep -Fq -- "$expected" "$file"; then
    fail "$name"
  fi
}

faq="docs/zh/FAQ.md"

printf '[TEST] zh FAQ session cache mode truth contract\n'

require_absent "$faq" 'LContext.SetSessionCacheMode(sslSessCacheClient);' \
  "zh FAQ must stop teaching the removed sslSessCacheClient-style session-cache mode argument"
require_fixed "$faq" 'LContext.SetSessionCacheMode(True);' \
  "zh FAQ must show the current Boolean session-cache mode seam"
require_fixed "$faq" '当前 `ISSLContext.SetSessionCacheMode(...)` 的参数仍是 `Boolean`；`TSessionCacheMode` / `scm_*` 更适合作为你自己的 policy wrapper，而不是当前直接传给 context 的参数类型。' \
  "zh FAQ must explain the current Boolean seam versus policy-wrapper safety types"

printf '[PASS] zh FAQ session cache mode truth contract passed\n'
