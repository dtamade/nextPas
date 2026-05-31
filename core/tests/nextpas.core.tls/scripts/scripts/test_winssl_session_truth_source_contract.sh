#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$repo_root"

pass() {
  printf '[PASS] %s\n' "$1"
}

fail() {
  printf '[FAIL] %s\n' "$1"
  if [[ $# -ge 2 ]]; then
    printf '       %s\n' "$2"
  fi
  exit 1
}

require_match() {
  local file="$1"
  local pattern="$2"
  local name="$3"
  if rg -n --multiline --multiline-dotall "$pattern" "$file" >/dev/null; then
    pass "$name"
  else
    fail "$name" "pattern not found in $file: $pattern"
  fi
}

require_absent() {
  local file="$1"
  local pattern="$2"
  local name="$3"
  if rg -n --multiline --multiline-dotall "$pattern" "$file" >/dev/null; then
    fail "$name" "unexpected pattern still present in $file: $pattern"
  else
    pass "$name"
  fi
}

connection_file="src/nextpas.core.tls.winssl.connection.pas"
session_file="src/nextpas.core.tls.winssl.session.pas"
test_file="tests/winssl/test_winssl_session_management.pas"
design_doc="docs/reference/WINSSL_DESIGN.md"
status_doc="docs/test_reports/WINSSL_BACKEND_STATUS_REPORT.md"

require_absent "$connection_file" \
  'TWinSSLSession = class\(TInterfacedObject,\s*ISSLSession,\s*ISSLNativeHandleAccess\)' \
  'winssl connection session class no longer exposes fake ISSLNativeHandleAccess'
require_absent "$connection_file" \
  'function TWinSSLSession\.GetNativeHandle: Pointer;' \
  'winssl connection session no longer implements GetNativeHandle'
require_absent "$connection_file" \
  'function TWinSSLSession\.GetBackendType: TSSLLibraryType;' \
  'winssl connection session no longer implements GetBackendType'
require_absent "$connection_file" \
  'function TWinSSLSession\.IsNativeHandleValid: Boolean;' \
  'winssl connection session no longer implements IsNativeHandleValid'
require_match "$session_file" \
  'TWinSSLSession = class\(fafafa\.ssl\.winssl\.connection\.TWinSSLSession\)' \
  'winssl session unit is now a compatibility shim over the canonical connection implementation'
require_absent "$session_file" \
  'TWinSSLSession = class\(TInterfacedObject,\s*ISSLSession' \
  'winssl session unit no longer carries a parallel standalone implementation'
require_match "$test_file" \
  'Supports\(LSession,\s*ISSLNativeHandleAccess,\s*LNative\)' \
  'winssl session management test now checks interface absence instead of calling stale GetNativeHandle'
require_absent "$test_file" \
  'LSession\.GetNativeHandle' \
  'winssl session management test no longer relies on stale ISSLSession.GetNativeHandle'
require_match "$design_doc" \
  'src/fafafa\.ssl\.winssl\.connection\.pas' \
  'WinSSL design doc points to the canonical session truth source'
require_match "$status_doc" \
  'fafafa\.ssl\.winssl\.connection\.pas' \
  'WinSSL status report points session ownership at the connection unit'
