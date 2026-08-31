#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
WINSSL_LIB="$ROOT_DIR/core/src/nextpas.core.tls.winssl.lib.pas"
WINSSL_UNIT_TEST="$ROOT_DIR/core/tests/nextpas.core.tls/winssl/test_winssl_unit_comprehensive.pas"

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

echo "[TEST] WinSSL TLS 1.3 capability consistency contract"

require_fixed "$WINSSL_LIB" \
  "Result.SupportsTLS13 := (FWindowsVersion.Major >= 10) and (FWindowsVersion.Build >= 18362);" \
  "WinSSL capability record must keep TLS 1.3 gated at Windows 10 1903+"
require_fixed "$WINSSL_LIB" \
  "// TLS 1.3 在 Windows 10 Build 18362+ / Windows 11+ 支持" \
  "WinSSL runtime protocol comment must describe the 1903+ gate"
require_fixed "$WINSSL_LIB" \
  "Result := (FWindowsVersion.Major >= 10) and (FWindowsVersion.Build >= 18362);" \
  "WinSSL runtime protocol query must use the same TLS 1.3 gate as SupportsTLS13"

require_absent "$WINSSL_LIB" \
  "Result := (FWindowsVersion.Major >= 10) and (FWindowsVersion.Build >= 20348);" \
  "WinSSL source must stop publishing a stricter TLS 1.3 protocol gate than the capability record"


require_fixed "$WINSSL_UNIT_TEST" \
  "// Test 8: Check TLS 1.3 support (Windows 10 1903+)" \
  "WinSSL unit test must stop implying TLS 1.3 is Windows 11-only"
require_fixed "$WINSSL_UNIT_TEST" \
  "// Note: This may fail on pre-1903 Windows 10 or older releases, which is acceptable" \
  "WinSSL unit test note must match the current TLS 1.3 gate"
require_fixed "$WINSSL_UNIT_TEST" \
  "Test('TLS 1.3 supported (Windows 10 1903+ or later)', True)" \
  "WinSSL unit test success label must match the current TLS 1.3 gate"
require_fixed "$WINSSL_UNIT_TEST" \
  "Test('TLS 1.3 not supported (pre-1903 Windows 10 or older)', True);" \
  "WinSSL unit test fallback label must match the current TLS 1.3 gate"

require_absent "$WINSSL_UNIT_TEST" \
  "Test('TLS 1.3 supported (Windows 11)', True)" \
  "WinSSL unit test must stop advertising Windows 11 as the only TLS 1.3-capable path"
require_absent "$WINSSL_UNIT_TEST" \
  "Test('TLS 1.3 not supported (Windows 10 or earlier)', True);" \
  "WinSSL unit test must stop collapsing all Windows 10 builds into TLS 1.3 unsupported"

echo "[PASS] WinSSL TLS 1.3 capability consistency contract passed"
