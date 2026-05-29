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

DOC="docs/ZERO_DEPENDENCY_DEPLOYMENT.md"

assert_not_contains "$DOC" \
  "CreateSSLLibrary(" \
  "ZERO_DEPENDENCY_DEPLOYMENT still teaches the removed CreateSSLLibrary helper"
assert_not_contains "$DOC" \
  "CreateOpenSSLLibrary(" \
  "ZERO_DEPENDENCY_DEPLOYMENT still teaches the removed OpenSSL creator helper"
assert_not_contains "$DOC" \
  "CreateWinSSLLibrary(" \
  "ZERO_DEPENDENCY_DEPLOYMENT still teaches the removed WinSSL creator helper"
assert_not_contains "$DOC" \
  "nextpas.core.tls.abstract.types" \
  "ZERO_DEPENDENCY_DEPLOYMENT still imports the removed abstract.types unit"
assert_not_contains "$DOC" \
  "nextpas.core.tls.abstract.intf" \
  "ZERO_DEPENDENCY_DEPLOYMENT still imports the removed abstract.intf unit"
assert_not_contains "$DOC" \
  "Windows 上自动使用 WinSSL（零依赖）" \
  "ZERO_DEPENDENCY_DEPLOYMENT still presents auto-detect as a hardcoded platform rule"
assert_not_contains "$DOC" \
  "Linux/macOS 上自动使用 OpenSSL" \
  "ZERO_DEPENDENCY_DEPLOYMENT still hardcodes Linux/macOS auto-detect to OpenSSL"
assert_not_contains "$DOC" \
  "Lib.IsFeatureSupported('SNI')" \
  "ZERO_DEPENDENCY_DEPLOYMENT still uses the stale string-based SNI feature call"
assert_not_contains "$DOC" \
  "Lib.IsFeatureSupported('ALPN')" \
  "ZERO_DEPENDENCY_DEPLOYMENT still uses the stale string-based ALPN feature call"
assert_not_contains "$DOC" \
  "| TLS 握手 | ~160 ms | ~150 ms | WinSSL 略快 |" \
  "ZERO_DEPENDENCY_DEPLOYMENT still publishes fixed performance numbers as long-term truth"

assert_contains "$DOC" \
  "fafafa.ssl;" \
  "ZERO_DEPENDENCY_DEPLOYMENT should use the current facade import"
assert_contains "$DOC" \
  "Lib := TSSLFactory.GetLibraryInstance(sslWinSSL);" \
  "ZERO_DEPENDENCY_DEPLOYMENT should use the current explicit WinSSL entrypoint"
assert_contains "$DOC" \
  "Lib := TSSLFactory.GetLibraryInstance(sslOpenSSL);" \
  "ZERO_DEPENDENCY_DEPLOYMENT should use the current explicit OpenSSL fallback entrypoint"
assert_contains "$DOC" \
  "Result := TSSLFactory.GetLibraryInstance(sslAutoDetect);" \
  "ZERO_DEPENDENCY_DEPLOYMENT should use the current auto-detect entrypoint"
assert_contains "$DOC" \
  "工厂会按当前注册优先级与可用性选择 highest-priority available backend，而不是按平台硬编码单一路径。" \
  "ZERO_DEPENDENCY_DEPLOYMENT should document the current auto-detect truth"
assert_contains "$DOC" \
  "Lib.IsFeatureSupported(sslFeatSNI)" \
  "ZERO_DEPENDENCY_DEPLOYMENT diagnostics should use the current enum-based SNI feature call"
assert_contains "$DOC" \
  "Lib.IsFeatureSupported(sslFeatALPN)" \
  "ZERO_DEPENDENCY_DEPLOYMENT diagnostics should use the current enum-based ALPN feature call"
assert_contains "$DOC" \
  '- `docs/BACKEND_CAPABILITY_MATRIX.md`' \
  "ZERO_DEPENDENCY_DEPLOYMENT performance section should point to the current truth source"

echo "[PASS] ZERO_DEPENDENCY_DEPLOYMENT current public entrypoint truth contract passed"
