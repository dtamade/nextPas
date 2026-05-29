#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

assert_contains() {
  local file="$1"
  local pattern="$2"
  local message="$3"

  if ! rg -F --quiet -- "$pattern" "$file"; then
    echo "[FAIL] $message"
    echo "[INFO] excerpt from $file:"
    sed -n '1,340p' "$file" || true
    exit 1
  fi
}

assert_not_contains() {
  local file="$1"
  local pattern="$2"
  local message="$3"

  if rg -n -F --quiet -- "$pattern" "$file"; then
    echo "[FAIL] $message"
    rg -n -F -- "$pattern" "$file" || true
    exit 1
  fi
}

DOC="docs/PLATFORM_SUPPORT.md"

assert_not_contains "$DOC" \
  "CreateSSLLibrary()" \
  "PLATFORM_SUPPORT still teaches the removed CreateSSLLibrary helper"
assert_not_contains "$DOC" \
  "Lib := CreateSSLLibrary();" \
  "PLATFORM_SUPPORT still uses the removed CreateSSLLibrary code path"
assert_not_contains "$DOC" \
  "Lib := CreateOpenSSLLibrary();" \
  "PLATFORM_SUPPORT still teaches the backend-specific low-level OpenSSL creator"
assert_not_contains "$DOC" \
  "Lib := CreateWinSSLLibrary();" \
  "PLATFORM_SUPPORT still teaches the backend-specific low-level WinSSL creator"
assert_not_contains "$DOC" \
  "macOS 平台验证正在进行中" \
  "PLATFORM_SUPPORT still publishes the stale macOS validation-in-progress status"

assert_contains "$DOC" \
  '**版本**: v1.5.0' \
  "PLATFORM_SUPPORT should reflect the current shipped version"
assert_contains "$DOC" \
  'Lib := TSSLFactory.GetLibraryInstance(sslAutoDetect);' \
  "PLATFORM_SUPPORT should use the current auto-detect library entrypoint"
assert_contains "$DOC" \
  'TSSLFactory.DetectBestLibrary()' \
  "PLATFORM_SUPPORT should mention the current factory auto-selection truth"
assert_contains "$DOC" \
  'Lib := TSSLFactory.GetLibraryInstance(sslOpenSSL);' \
  "PLATFORM_SUPPORT should use the current explicit OpenSSL entrypoint"
assert_contains "$DOC" \
  'Lib := TSSLFactory.GetLibraryInstance(sslWinSSL);' \
  "PLATFORM_SUPPORT should use the current explicit WinSSL entrypoint"
assert_contains "$DOC" \
  '**FreePascal** (pure Pascal / 无外部 SSL 动态库)' \
  "PLATFORM_SUPPORT should include the shipped FreePascal backend"
assert_contains "$DOC" \
  '当前注册优先级为：`WinSSL=200, MbedTLS=175, WolfSSL=150, OpenSSL=100, FreePascal=50`。' \
  "PLATFORM_SUPPORT should record the full current backend priority order"

echo "[PASS] PLATFORM_SUPPORT current public entrypoint truth contract passed"
