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
  if rg -n -P --multiline --multiline-dotall "$pattern" "$file" >/dev/null; then
    pass "$name"
  else
    fail "$name" "pattern not found in $file: $pattern"
  fi
}

proof_file="tests/winssl/test_winssl_session_resumption.pas"

printf '[TEST] WinSSL native-probe safe-query contract\n'

require_match "$proof_file" \
  'TQueryContextAttributesExWFunc = function\(\s*phContext: PCtxtHandle;\s*ulAttribute: ULONG;\s*pBuffer: Pointer;\s*cbBuffer: ULONG\s*\): SECURITY_STATUS; stdcall;' \
  'WinSSL proof defines an explicit QueryContextAttributesExW function type'

require_match "$proof_file" \
  'function ResolveQueryContextAttributesExW: TQueryContextAttributesExWFunc;.*?for I := Low\(LCandidates\) to High\(LCandidates\) do.*?GetProcAddress\(LModule,\s*PAnsiChar\(LCandidates\[I\]\.SymbolName\)\)' \
  'WinSSL proof resolves QueryContextAttributesEx dynamically through candidate export traversal'

require_match "$proof_file" \
  'function TryQueryCurrentSessionInfoWithSizedBuffer\(' \
  'WinSSL proof defines a dedicated sized-buffer session-info helper'

require_match "$proof_file" \
  'LQueryEx := ResolveQueryContextAttributesExW;' \
  'WinSSL sized-buffer helper resolves QueryContextAttributesExW before probing'

require_match "$proof_file" \
  'AStatus := LQueryEx\(ACtxtHandle,\s*SECPKG_ATTR_SESSION_INFO,\s*@ASessionInfo,\s*SizeOf\(ASessionInfo\)\);' \
  'WinSSL sized-buffer helper uses QueryContextAttributesExW with an explicit buffer size'

require_match "$proof_file" \
  'AStatus := QueryContextAttributesW\(ACtxtHandle,\s*SECPKG_ATTR_SESSION_INFO,\s*@ASessionInfo\);' \
  'WinSSL sized-buffer helper falls back to QueryContextAttributesW when ExW is unavailable'

require_match "$proof_file" \
  'native_probe label=%s stage=query_api api=%s' \
  'WinSSL native probe emits which query API path it is about to use'

require_match "$proof_file" \
  'TryQueryCurrentSessionInfoWithSizedBuffer\(LCtxtHandle,\s*LSessionInfo,\s*LStatus,\s*LUsedQueryEx\)' \
  'WinSSL native probe uses the sized-buffer helper instead of calling QueryContextAttributesW directly'

printf '[PASS] WinSSL native-probe safe-query contract passed\n'
