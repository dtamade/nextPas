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

echo "[TEST] WinSSL platform support doc truth contract"

require_fixed "$WINSSL_LIB" \
  "SetError(-1, 'Windows version too old. Schannel requires Windows Vista or later.');" \
  "WinSSL initialize path must keep the Vista+ baseline"
require_fixed "$WINSSL_LIB" \
  "((FWindowsVersion.Major = 6) and (FWindowsVersion.Minor >= 1));  // Win 7+" \
  "WinSSL source must keep TLS 1.1/1.2 gated at Windows 7+"
require_fixed "$WINSSL_LIB" \
  "Result := (FWindowsVersion.Major >= 10) and (FWindowsVersion.Build >= 18362);" \
  "WinSSL source must keep TLS 1.3 gated at Windows 10 1903+"




echo "[PASS] WinSSL platform support doc truth contract passed"
