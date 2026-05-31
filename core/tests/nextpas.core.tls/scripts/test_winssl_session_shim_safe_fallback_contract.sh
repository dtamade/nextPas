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

session_file="src/nextpas.core.tls.winssl.session.pas"

printf '[TEST] WinSSL session shim safe fallback contract\n'

require_absent "$session_file" \
  'QueryContextAttributesW' \
  'WinSSL compatibility shim no longer performs a direct Schannel session-info query'

require_absent "$session_file" \
  'SECPKG_ATTR_SESSION_INFO' \
  'WinSSL compatibility shim no longer references the risky session-info attribute directly'

require_match "$session_file" \
  'LSessionID := Format\('"'winssl-session-%p'"', \[Pointer\(AContext\)\]\);' \
  'WinSSL compatibility shim now falls back to the conservative pointer-based session id'

require_match "$session_file" \
  'SetSessionMetadata\(LSessionID,\s*AProtocol,\s*ACipher,\s*False\);' \
  'WinSSL compatibility shim keeps conservative reused=false truth when creating session metadata'

printf '[PASS] WinSSL session shim safe fallback contract passed\n'
