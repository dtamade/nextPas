#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$repo_root"

fail() {
  printf '[FAIL] %s\n' "$1" >&2
  exit 1
}

contract_src="tests/contract/test_builder_merge_empty_verifymode_entry.pas"
build_root="tmp/test_builder_merge_empty_verifymode_entry"
units_dir="$build_root/units"
bin_dir="$build_root/bin"
binary="$bin_dir/test_builder_merge_empty_verifymode_entry"

printf '[TEST] builder merge empty verify-mode clear semantics contract\n'

mkdir -p "$units_dir" "$bin_dir"
fpc -B -Fu./src -Fu./tests -FU"$units_dir" -FE"$bin_dir" -o"$binary" "$contract_src" >/dev/null
if [[ ! -x "$binary" ]]; then
  fail "builder merge empty verify-mode contract source must compile"
fi

"$binary"

printf '[PASS] builder merge empty verify-mode clear semantics contract passed\n'
