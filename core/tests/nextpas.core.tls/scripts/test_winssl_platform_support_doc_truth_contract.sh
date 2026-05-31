#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WINSSL_LIB="$ROOT_DIR/src/nextpas.core.tls.winssl.lib.pas"
WINSSL_DOC="$ROOT_DIR/docs/reference/WINSSL_BACKEND_CAPABILITY_MATRIX.md"
PLATFORM_DOC="$ROOT_DIR/docs/PLATFORM_SUPPORT.md"
ZERO_DEP_DOC="$ROOT_DIR/docs/ZERO_DEPENDENCY_DEPLOYMENT.md"

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

require_fixed "$WINSSL_DOC" \
  "| Windows 7 SP1       | ✅ 支持  | ❌      | TLS 1.0/1.1/1.2 |" \
  "WinSSL dedicated matrix must describe Windows 7 SP1 as supported up to TLS 1.2"
require_fixed "$WINSSL_DOC" \
  "| Windows Server 2019 | ✅ 支持  | ❌      | TLS 1.2 |" \
  "WinSSL dedicated matrix must describe Windows Server 2019 as TLS 1.2 only"
require_absent "$WINSSL_DOC" \
  "| Windows 7 SP1       | ⚠️ 部分  | ❌      | 需更新  |" \
  "WinSSL dedicated matrix must stop describing Windows 7 SP1 as partial support"
require_absent "$WINSSL_DOC" \
  "| Windows Server 2019 | ✅ 支持  | ⚠️      | 需更新  |" \
  "WinSSL dedicated matrix must stop describing Windows Server 2019 TLS 1.3 as uncertain"

require_fixed "$PLATFORM_DOC" \
  "- TLS 1.3 支持: Windows 10 1903+ 或 Windows 11" \
  "Platform support doc must keep WinSSL TLS 1.3 at the 1903+ gate"
require_absent "$PLATFORM_DOC" \
  "- TLS 1.3 支持: Windows 10 20348+ 或 Windows 11" \
  "Platform support doc must stop using the stale 20348+ TLS 1.3 gate"

require_fixed "$ZERO_DEP_DOC" \
  "| Windows 10 (< 18362) | ✅ | ✅ | ✅ | ❌ |" \
  "Zero-dependency deployment doc must classify pre-1903 Windows 10 as TLS 1.2 only"
require_fixed "$ZERO_DEP_DOC" \
  "| Windows 10 (≥ 18362) | ✅ | ✅ | ✅ | ✅ |" \
  "Zero-dependency deployment doc must classify Windows 10 1903+ as TLS 1.3 capable"
require_fixed "$ZERO_DEP_DOC" \
  "- TLS 1.3 需要 Windows 10 1903+ 或 Windows 11" \
  "Zero-dependency deployment guidance must keep the 1903+ TLS 1.3 gate"
require_fixed "$ZERO_DEP_DOC" \
  "- ✅ Windows 10 (≥ 18362) / Server 2022+（TLS 1.3）" \
  "Zero-dependency deployment FAQ must keep the 1903+ TLS 1.3 gate for Windows 10"
require_absent "$ZERO_DEP_DOC" \
  "| Windows 10 (< 20348) | ✅ | ✅ | ✅ | ❌ |" \
  "Zero-dependency deployment doc must stop using the stale pre-20348 split"
require_absent "$ZERO_DEP_DOC" \
  "| Windows 10 (≥ 20348) | ✅ | ✅ | ✅ | ✅ |" \
  "Zero-dependency deployment doc must stop using the stale 20348+ split"
require_absent "$ZERO_DEP_DOC" \
  "- TLS 1.3 需要 Windows 10 20348+ 或 Windows 11" \
  "Zero-dependency deployment guidance must stop using the stale 20348+ TLS 1.3 gate"
require_absent "$ZERO_DEP_DOC" \
  "- ✅ Windows 10 (≥ 20348) / Server 2022+（TLS 1.3）" \
  "Zero-dependency deployment FAQ must stop using the stale 20348+ TLS 1.3 gate"

echo "[PASS] WinSSL platform support doc truth contract passed"
