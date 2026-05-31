#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$repo_root"

fail() {
  printf '[FAIL] %s\n' "$1" >&2
  exit 1
}

require_fixed() {
  local file="$1"
  local expected="$2"
  local name="$3"
  if ! grep -Fq -- "$expected" "$file"; then
    fail "$name"
  fi
}

builder="src/nextpas.core.tls.context.builder.pas"
readme="README.md"
api_ref="docs/reference/API_REFERENCE.md"
contract_src="tests/contract/test_context_builder_session_timeout_safety_entry.pas"
build_root="tmp/test_context_builder_session_timeout_safety_entry"
units_dir="$build_root/units"
bin_dir="$build_root/bin"
binary="$bin_dir/test_context_builder_session_timeout_safety_entry"

printf '[TEST] context builder session-timeout safety contract\n'

require_fixed "$builder" "function WithSessionTimeout(ASeconds: Integer): ISSLContextBuilder; overload;" \
  "context builder must keep legacy integer session-timeout overload"
require_fixed "$builder" "function WithSessionTimeout(const ATimeout: TTimeoutDuration): ISSLContextBuilder; overload;" \
  "context builder must export TTimeoutDuration session-timeout overload"
require_fixed "$builder" "Infinite timeout is not valid for session lifetime" \
  "context builder must reject infinite timeout for session lifetime"
require_fixed "$builder" "Session timeout must be a whole number of seconds" \
  "context builder must reject non-whole-second timeout values"
require_fixed "$readme" ".WithSessionTimeout(TTimeoutDuration.Minutes(120))" \
  "README builder example must show type-safe session timeout"
require_fixed "$api_ref" ".WithSessionTimeout(TTimeoutDuration.Minutes(120))" \
  "API reference builder example must show type-safe session timeout"

mkdir -p "$units_dir" "$bin_dir"
fpc -B -Fu./src -Fu./tests -FU"$units_dir" -FE"$bin_dir" -o"$binary" "$contract_src" >/dev/null
if [[ ! -x "$binary" ]]; then
  fail "context builder session-timeout safety contract source must compile"
fi

"$binary"

printf '[PASS] context builder session-timeout safety contract passed\n'
