#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
WINSSL_LIB="$ROOT_DIR/core/src/nextpas.core.tls.winssl.lib.pas"

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





echo "[PASS] WinSSL none-capability surface doc truth contract passed"
