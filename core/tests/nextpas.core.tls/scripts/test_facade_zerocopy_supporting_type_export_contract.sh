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

require_fixed() {
  local file="$1"
  local expected="$2"
  local name="$3"
  if grep -Fq -- "$expected" "$file"; then
    pass "$name"
  else
    fail "$name" "expected text not found in $file: $expected"
  fi
}

facade="src/nextpas.core.tls.pas"
api_ref="docs/reference/API_REFERENCE.md"
contract_src="tests/contract/test_facade_zerocopy_supporting_type_entry.pas"
build_root="tmp/test_facade_zerocopy_supporting_type_entry"
units_dir="$build_root/units"
bin_dir="$build_root/bin"
binary="$bin_dir/test_facade_zerocopy_supporting_type_entry"

printf '[TEST] facade zero-copy supporting-type export contract\n'

require_fixed "$facade" "TBytesView = nextpas.core.tls.base.TBytesView;" \
  "main facade must re-export TBytesView"
require_fixed "$api_ref" '主门面 `fafafa.ssl` 当前也 re-export `TBytesView`；使用 `nextpas.core.tls.encoding` / `nextpas.core.tls.crypto.utils` 的 zero-copy 入口时不需要回退 `nextpas.core.tls.base`。' \
  "API reference must record the main-facade zero-copy supporting type"

mkdir -p "$units_dir" "$bin_dir"
fpc -B -Fu./src -Fu./tests -FU"$units_dir" -FE"$bin_dir" -o"$binary" "$contract_src" >/dev/null
if [[ ! -x "$binary" ]]; then
  fail "facade zero-copy contract source compiles through main facade" "expected binary missing: $binary"
fi
pass "facade zero-copy contract source compiles through main facade"

"$binary" >/dev/null
pass "facade zero-copy contract runs successfully"

printf '[PASS] facade zero-copy supporting-type export contract passed\n'
