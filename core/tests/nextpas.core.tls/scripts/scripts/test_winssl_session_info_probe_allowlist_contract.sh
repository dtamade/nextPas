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
proof_file="tests/winssl/test_winssl_session_resumption.pas"
shim_file="src/nextpas.core.tls.winssl.session.pas"

printf '[TEST] WinSSL session-info probe allowlist contract\n'

require_match "$connection_file" \
  'QueryContextAttributesW\(@FCtxtHandle,\s*SECPKG_ATTR_SESSION_INFO,\s*@ASessionInfo\)' \
  'canonical WinSSL connection helper remains an explicit controlled session-info probe site'

require_match "$proof_file" \
  'TryQueryCurrentSessionInfoWithSizedBuffer\(LCtxtHandle,\s*LSessionInfo,\s*LStatus,\s*LUsedQueryEx\)' \
  'dedicated WinSSL native-probe proof remains an explicit controlled session-info probe site'

require_absent "$shim_file" \
  'SECPKG_ATTR_SESSION_INFO|QueryContextAttributesW' \
  'WinSSL compatibility shim stays outside the session-info probe allowlist'

printf '[PASS] WinSSL session-info probe allowlist contract passed\n'
