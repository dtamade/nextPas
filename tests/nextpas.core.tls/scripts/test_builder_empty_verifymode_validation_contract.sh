#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$repo_root"

fail() {
  printf '[FAIL] %s\n' "$1" >&2
  exit 1
}

builder_file="src/nextpas.core.tls.context.builder.pas"
contract_src="tests/contract/test_builder_empty_verifymode_validation_entry.pas"
build_root="tmp/test_builder_empty_verifymode_validation_entry"
units_dir="$build_root/units"
bin_dir="$build_root/bin"
binary="$bin_dir/test_builder_empty_verifymode_validation_entry"

printf '[TEST] builder empty verify-mode validation parity contract\n'

if ! rg -n --quiet --fixed-strings 'not (sslVerifyPeer in LVerifyMode)' "$builder_file"; then
  fail "builder validation must treat missing sslVerifyPeer as disabled certificate verification"
fi

mkdir -p "$units_dir" "$bin_dir"
fpc -B -Fu./src -Fu./tests -FU"$units_dir" -FE"$bin_dir" -o"$binary" "$contract_src" >/dev/null
if [[ ! -x "$binary" ]]; then
  fail "builder empty verify-mode validation contract source must compile"
fi

"$binary"

printf '[PASS] builder empty verify-mode validation parity contract passed\n'
