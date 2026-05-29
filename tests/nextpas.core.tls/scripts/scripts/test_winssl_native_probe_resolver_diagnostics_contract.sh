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

printf '[TEST] WinSSL native-probe resolver-diagnostics contract\n'

require_match "$proof_file" \
  'type\s+TQueryContextAttributesExCandidate = record\s*ModuleName: string;\s*SymbolName: AnsiString;\s*end;' \
  'WinSSL proof defines an explicit resolver candidate record'

require_match "$proof_file" \
  'QueryContextAttributesExResolvedModuleName: string = \x27\x27;' \
  'WinSSL proof caches the resolved module name for query resolver diagnostics'

require_match "$proof_file" \
  'QueryContextAttributesExResolvedSymbolName: string = \x27\x27;' \
  'WinSSL proof caches the resolved symbol name for query resolver diagnostics'

require_match "$proof_file" \
  'QueryContextAttributesExW\x27' \
  'WinSSL proof tries the QueryContextAttributesExW symbol'

require_match "$proof_file" \
  'QueryContextAttributesExA\x27' \
  'WinSSL proof tries the QueryContextAttributesExA symbol'

require_match "$proof_file" \
  'QueryContextAttributesEx\x27' \
  'WinSSL proof tries the undecorated QueryContextAttributesEx symbol'

require_match "$proof_file" \
  'GetProcAddress\(LModule,\s*PAnsiChar\(LCandidates\[I\]\.SymbolName\)\)' \
  'WinSSL proof resolves candidate exports through an explicit ANSI GetProcAddress call'

require_match "$proof_file" \
  'QueryContextAttributesExResolvedModuleName := LCandidates\[I\]\.ModuleName;' \
  'WinSSL proof records the resolved module name'

require_match "$proof_file" \
  'QueryContextAttributesExResolvedSymbolName := string\(LCandidates\[I\]\.SymbolName\);' \
  'WinSSL proof records the resolved symbol name'

require_match "$proof_file" \
  'native_probe label=%s stage=query_resolver module=%s symbol=%s resolved=%s' \
  'WinSSL native probe emits a resolver diagnostic marker before the risky query'

printf '[PASS] WinSSL native-probe resolver-diagnostics contract passed\n'
