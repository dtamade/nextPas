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
base_file="src/nextpas.core.tls.winssl.base.pas"
context_file="src/nextpas.core.tls.winssl.context.pas"
library_file="src/nextpas.core.tls.winssl.lib.pas"

require_absent "$connection_file" \
  'TWinSSLContext\(FContext\)' \
  'winssl connection no longer hard-casts ISSLContext to TWinSSLContext'
require_absent "$connection_file" \
  'TWinSSLLibrary\(TWinSSLContext\(FContext\)\.GetLibrary\)' \
  'winssl connection no longer hard-casts ISSLLibrary to TWinSSLLibrary through TWinSSLContext'
require_match "$base_file" \
  'IWinSSLContextAccess = interface' \
  'winssl base declares internal context access interface'
require_match "$context_file" \
  'TWinSSLContext = class\(TInterfacedObject,\s*ISSLContext,\s*ISSLNativeHandleAccess,\s*IWinSSLContextAccess\)' \
  'winssl context implements internal context access interface'
require_match "$base_file" \
  'IWinSSLLibraryStatsAccess = interface' \
  'winssl base declares internal stats access interface'
require_match "$library_file" \
  'TWinSSLLibrary = class\(TInterfacedObject,\s*ISSLLibrary,\s*IWinSSLLibraryStatsAccess\)' \
  'winssl library implements internal stats access interface'
require_match "$connection_file" \
  'function TWinSSLConnection\.TryGetContextAccess\(out AContextAccess: IWinSSLContextAccess\): Boolean;.*?Supports\(FContext,\s*IWinSSLContextAccess,\s*AContextAccess\)' \
  'winssl connection queries internal context access interface explicitly'
require_match "$connection_file" \
  'function TWinSSLConnection\.TryGetLibraryStatsAccess\(.*?Supports\(LContextAccess\.GetWinSSLLibrary,\s*IWinSSLLibraryStatsAccess,\s*ALibraryStatsAccess\)' \
  'winssl connection queries internal library stats access interface explicitly'
