#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
BASE_FILE="$ROOT_DIR/core/src/nextpas.core.tls.base.pas"
MBEDTLS_CONN="$ROOT_DIR/core/src/nextpas.core.tls.mbedtls.connection.pas"
MBEDTLS_FRAMEWORK_TEST="$ROOT_DIR/core/tests/nextpas.core.tls/test_mbedtls_framework.pas"

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



echo "[PASS] MbedTLS async capability doc truth contract passed"

