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

context_file="src/nextpas.core.tls.wolfssl.context.pas"

require_absent "$context_file" \
  'TWolfSSLConnection = class\(TInterfacedObject,\s*ISSLConnection,\s*ISSLNativeHandleAccess\)' \
  'legacy private TWolfSSLConnection class declaration is removed from wolfssl.context'
require_absent "$context_file" \
  'constructor TWolfSSLConnection\.Create\(AContext: TWolfSSLContext,\s*ASocket: THandle\);' \
  'legacy socket constructor is removed from wolfssl.context'
require_absent "$context_file" \
  'constructor TWolfSSLConnection\.Create\(AContext: TWolfSSLContext,\s*AStream: TStream\);' \
  'legacy stream constructor is removed from wolfssl.context'
require_absent "$context_file" \
  'destructor TWolfSSLConnection\.Destroy;' \
  'legacy destructor is removed from wolfssl.context'
require_match "$context_file" \
  'Result := fafafa\.ssl\.wolfssl\.connection\.TWolfSSLConnection\.Create\(Self,\s*ASocket\);' \
  'socket factory path still uses modern wolfssl.connection unit'
require_match "$context_file" \
  'Result := fafafa\.ssl\.wolfssl\.connection\.TWolfSSLConnection\.Create\(Self,\s*AStream\);' \
  'stream factory path still uses modern wolfssl.connection unit'
