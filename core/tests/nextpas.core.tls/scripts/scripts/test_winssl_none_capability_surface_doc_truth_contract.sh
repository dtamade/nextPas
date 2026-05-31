#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WINSSL_LIB="$ROOT_DIR/src/nextpas.core.tls.winssl.lib.pas"
TOP_MATRIX="$ROOT_DIR/docs/BACKEND_CAPABILITY_MATRIX.md"
WINSSL_MATRIX="$ROOT_DIR/docs/reference/WINSSL_BACKEND_CAPABILITY_MATRIX.md"

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

echo "[TEST] WinSSL none-capability surface doc truth contract"

require_fixed "$WINSSL_LIB" \
  "Result.OCSPStaplingSupport := sslSupportNone;" \
  "WinSSL source must keep OCSP stapling capability at none"
require_fixed "$WINSSL_LIB" \
  "Result.EarlyDataSupport := sslSupportNone;" \
  "WinSSL source must keep early-data capability at none"

require_fixed "$TOP_MATRIX" \
  "| **Early Data (0-RTT)**       | ⚠️         | ✅      | ❌     | ❌      | ⚠️      |" \
  "Top-level backend matrix must continue to classify WinSSL early-data as unavailable"
require_fixed "$TOP_MATRIX" \
  "| **OCSP Stapling**            | ⚠️         | ✅      | ❌     | ❌      | ⚠️      |" \
  "Top-level backend matrix must continue to classify WinSSL OCSP stapling as unavailable"

require_fixed "$WINSSL_MATRIX" \
  "| OCSP Stapling | ❌ 当前 capability 不发布 | Schannel 可能存在系统级自动行为；但 fafafa.ssl 当前 \`OCSPStaplingSupport=sslSupportNone\`，且不暴露 \`ISSLServerOCSPStaplingContext\` |" \
  "WinSSL dedicated matrix must describe OCSP stapling as none-published capability"
require_fixed "$WINSSL_MATRIX" \
  "| 0-RTT          | ❌ 当前 capability 不发布 | Windows Schannel 可能存在 TLS 1.3 / early-data 平台潜力；但 fafafa.ssl 当前 \`EarlyDataSupport=sslSupportNone\`，且不暴露 \`ISSLEarlyDataContext\` |" \
  "WinSSL dedicated matrix must describe early-data as none-published capability"

if grep -Fq -- "| OCSP Stapling | ⚠️ 部分" "$WINSSL_MATRIX"; then
  fail "WinSSL dedicated matrix must stop classifying OCSP stapling as partial support"
fi

if grep -Fq -- "| 0-RTT          | ⚠️ 部分" "$WINSSL_MATRIX"; then
  fail "WinSSL dedicated matrix must stop classifying early-data as partial support"
fi

echo "[PASS] WinSSL none-capability surface doc truth contract passed"
