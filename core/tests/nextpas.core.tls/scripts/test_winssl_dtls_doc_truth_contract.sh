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

echo "[TEST] WinSSL DTLS doc truth contract"

require_fixed "$WINSSL_LIB" \
  "Result.SupportsDTLS := False;  // Schannel 不支持 DTLS" \
  "WinSSL source must keep SupportsDTLS disabled"



echo "[PASS] WinSSL DTLS doc truth contract passed"
