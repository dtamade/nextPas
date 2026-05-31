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

proof_file="tests/winssl/test_winssl_session_resumption.pas"

printf '[TEST] WinSSL native-probe handle metadata contract\n'

require_match "$proof_file" \
  'function BackendTypeText\(ABackend: TSSLLibraryType\): string;' \
  'WinSSL probe proof exposes a readable backend-type helper for evidence markers'

require_match "$proof_file" \
  'LNativeAccess\.GetBackendType' \
  'WinSSL native probe reads the backend type before the risky query'

require_match "$proof_file" \
  'LNativeAccess\.IsNativeHandleValid' \
  'WinSSL native probe reads the native-handle validity before the risky query'

require_match "$proof_file" \
  'native_probe label=%s stage=handle_metadata backend=%s handle_valid=%s lower=%s upper=%s' \
  'WinSSL native probe emits backend and raw handle metadata before QueryContextAttributesW'

require_match "$proof_file" \
  'IntToHex\(QWord\(LCtxtHandle\^\.dwLower\)' \
  'WinSSL native probe records the raw dwLower value from the context handle'

require_match "$proof_file" \
  'IntToHex\(QWord\(LCtxtHandle\^\.dwUpper\)' \
  'WinSSL native probe records the raw dwUpper value from the context handle'

printf '[PASS] WinSSL native-probe handle metadata contract passed\n'
