#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MBEDTLS_BASE="$ROOT_DIR/src/nextpas.core.tls.mbedtls.base.pas"
MBEDTLS_LIB="$ROOT_DIR/src/nextpas.core.tls.mbedtls.lib.pas"
BACKEND_MATRIX="$ROOT_DIR/docs/BACKEND_CAPABILITY_MATRIX.md"
MBEDTLS_DOC="$ROOT_DIR/docs/reference/MBEDTLS_BACKEND_CAPABILITY_MATRIX.md"

fail() {
  echo "[FAIL] $1"
  exit 1
}

require_fixed() {
  local file="$1"
  local needle="$2"
  local message="$3"
  if grep -Fq -- "$needle" "$file"; then
    echo "[PASS] $message"
  else
    fail "$message"
  fi
}

require_absent() {
  local file="$1"
  local needle="$2"
  local message="$3"
  if grep -Fq -- "$needle" "$file"; then
    fail "$message"
  else
    echo "[PASS] $message"
  fi
}

echo "[TEST] MbedTLS TLS 1.3 capability doc truth contract"

require_fixed "$MBEDTLS_BASE" \
  'MBEDTLS_MIN_VERSION = $03000000;  // 3.0.0 minimum for TLS 1.3' \
  "MbedTLS base must keep TLS 1.3 gated behind the 3.x minimum version constant"
require_fixed "$MBEDTLS_LIB" \
  "FCapabilities.HasTLS13 := FCapabilities.VersionNumber >= MBEDTLS_MIN_VERSION;" \
  "MbedTLS source must derive TLS 1.3 capability from runtime version detection"
require_fixed "$MBEDTLS_LIB" \
  "sslProtocolTLS13: Result := FCapabilities.HasTLS13;" \
  "MbedTLS runtime protocol truth must keep TLS 1.3 conditional"
require_fixed "$MBEDTLS_LIB" \
  "Result.SupportsTLS13 := FCapabilities.HasTLS13;" \
  "MbedTLS capability record must keep SupportsTLS13 conditional"

require_fixed "$BACKEND_MATRIX" \
  "| **TLS 1.3**                  | ✅         | ✅      | ⚠️     | ⚠️      | ✅      |" \
  "Canonical backend matrix must continue to classify MbedTLS TLS 1.3 as conditional"

require_fixed "$MBEDTLS_DOC" \
  '| TLS 1.3 | ⚠️ 条件支持 | 当前 `SupportsTLS13` / `sslProtocolTLS13` 取决于运行时 MbedTLS 版本；仅当检测到 MbedTLS 3.x+ 时才发布 |' \
  "MbedTLS dedicated matrix must describe TLS 1.3 as conditional capability"

require_absent "$MBEDTLS_DOC" \
  "| TLS 1.3 | ✅ 支持 | MbedTLS 3.x 支持 |" \
  "MbedTLS dedicated matrix must stop publishing TLS 1.3 as unconditional support"

echo "[PASS] MbedTLS TLS 1.3 capability doc truth contract passed"
