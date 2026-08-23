#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
MBEDTLS_LIB="$ROOT_DIR/core/src/nextpas.core.tls.mbedtls.lib.pas"
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

echo "[TEST] MbedTLS protocol capability doc truth contract"

require_fixed "$MBEDTLS_LIB" \
  "sslProtocolTLS10: Result := False;  // MbedTLS 3.x 默认禁用" \
  "MbedTLS source must keep TLS 1.0 disabled"
require_fixed "$MBEDTLS_LIB" \
  "sslProtocolTLS11: Result := False;  // MbedTLS 3.x 默认禁用" \
  "MbedTLS source must keep TLS 1.1 disabled"
require_fixed "$MBEDTLS_LIB" \
  "sslProtocolDTLS10, sslProtocolDTLS12: Result := False;  // 暂不支持" \
  "MbedTLS source must keep DTLS disabled"
require_fixed "$MBEDTLS_LIB" \
  "Result.MinTLSVersion := sslProtocolTLS12;" \
  "MbedTLS source must keep TLS 1.2 as the published minimum version"
require_fixed "$MBEDTLS_LIB" \
  "Result.SupportsDTLS :=" \
  "MbedTLS capability record must still derive SupportsDTLS from protocol support"

require_fixed "$MBEDTLS_FRAMEWORK_TEST" \
  "Test('DTLS 1.0 not supported', not LLib.IsProtocolSupported(sslProtocolDTLS10));" \
  "MbedTLS framework test must keep DTLS 1.0 unsupported truth"
require_fixed "$MBEDTLS_FRAMEWORK_TEST" \
  "Test('DTLS 1.2 not supported', not LLib.IsProtocolSupported(sslProtocolDTLS12));" \
  "MbedTLS framework test must keep DTLS 1.2 unsupported truth"



echo "[PASS] MbedTLS protocol capability doc truth contract passed"
