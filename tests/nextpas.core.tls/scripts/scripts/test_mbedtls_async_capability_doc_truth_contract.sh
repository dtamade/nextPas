#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BASE_FILE="$ROOT_DIR/src/nextpas.core.tls.base.pas"
MBEDTLS_CONN="$ROOT_DIR/src/nextpas.core.tls.mbedtls.connection.pas"
MBEDTLS_FRAMEWORK_TEST="$ROOT_DIR/tests/test_mbedtls_framework.pas"
API_REFERENCE="$ROOT_DIR/docs/reference/API_REFERENCE.md"
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

echo "[TEST] MbedTLS async capability doc truth contract"

require_fixed "$BASE_FILE" \
  "function WantRead: Boolean;" \
  "base ISSLConnection surface must keep WantRead published"
require_fixed "$BASE_FILE" \
  "function WantWrite: Boolean;" \
  "base ISSLConnection surface must keep WantWrite published"
require_fixed "$MBEDTLS_CONN" \
  "Result := FLastNativeError = MBEDTLS_ERR_SSL_WANT_READ;" \
  "MbedTLS connection must derive WantRead from native WANT_READ"
require_fixed "$MBEDTLS_CONN" \
  "Result := FLastNativeError = MBEDTLS_ERR_SSL_WANT_WRITE;" \
  "MbedTLS connection must derive WantWrite from native WANT_WRITE"
require_fixed "$MBEDTLS_FRAMEWORK_TEST" \
  "Test('ERR_SSL_WANT_READ maps to sslErrWantRead', LResult = sslErrWantRead);" \
  "MbedTLS framework test must keep WANT_READ error mapping"
require_fixed "$MBEDTLS_FRAMEWORK_TEST" \
  "Test('ERR_SSL_WANT_WRITE maps to sslErrWantWrite', LResult = sslErrWantWrite);" \
  "MbedTLS framework test must keep WANT_WRITE error mapping"
require_fixed "$API_REFERENCE" \
  "function WantRead: Boolean;" \
  "API reference must keep WantRead in the active connection surface"
require_fixed "$API_REFERENCE" \
  "function WantWrite: Boolean;" \
  "API reference must keep WantWrite in the active connection surface"

require_fixed "$MBEDTLS_DOC" \
  '| 异步操作 | ⚠️ 部分 | 当前 public surface 通过 `WantRead / WantWrite` 暴露非阻塞重试语义；没有 dedicated async callback / job public capability |' \
  "MbedTLS dedicated matrix must describe async as retry semantics rather than a broad async capability"

require_absent "$MBEDTLS_DOC" \
  "| 异步操作 | ⚠️ 部分 | 非阻塞 I/O |" \
  "MbedTLS dedicated matrix must stop using the vague non-blocking I/O wording"

echo "[PASS] MbedTLS async capability doc truth contract passed"

