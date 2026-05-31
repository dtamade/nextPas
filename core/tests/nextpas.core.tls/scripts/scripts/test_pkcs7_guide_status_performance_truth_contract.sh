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

guide="docs/guides/PKCS7_USER_GUIDE.md"

echo "[TEST] PKCS7 guide status/performance truth contract"

require_fixed "$guide" '本指南讨论的是 `OpenSSL` backend 暴露的 PKCS#7 raw API + helper surface，不代表所有 backend 都发布同等能力。' \
  "PKCS7 guide must declare its current backend surface boundary"
require_fixed "$guide" 'PKCS#7 当前没有一对一 capability 字段，支持判断以 `LoadPKCS7Functions`、模块加载状态 `osmPKCS7` 与 focused tests 为准。' \
  "PKCS7 guide must explain the current no-direct-capability-field truth"
require_fixed "$guide" '高入口 helper：`SignData` / `VerifySignedData` / `EncryptData` / `DecryptData`' \
  "PKCS7 guide must point readers to the current helper entrypoints"
require_fixed "$guide" '这些测试文件和命令是当前可执行验证入口，但不要把固定的总测试数、通过率、性能数字或历史输出文本当成当前接口 truth。' \
  "PKCS7 guide must demote historical status/performance snapshots"

require_absent "$guide" "Production Ready" \
  "PKCS7 guide must stop presenting historical production-ready snapshots as current truth"
require_absent "$guide" "100% 测试通过" \
  "PKCS7 guide must stop hardcoding historical pass-rate snapshots"
require_absent "$guide" "158/158" \
  "PKCS7 guide must stop hardcoding historical test totals"
require_absent "$guide" "2 ms" \
  "PKCS7 guide must stop hardcoding fixed performance timings"
require_absent "$guide" "500 ops/s" \
  "PKCS7 guide must stop hardcoding historical throughput numbers"

echo "[PASS] PKCS7 guide status/performance truth contract passed"
