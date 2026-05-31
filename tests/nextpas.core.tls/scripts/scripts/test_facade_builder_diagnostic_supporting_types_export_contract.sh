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
contract_src="tests/contract/test_facade_builder_diagnostic_supporting_types_entry.pas"
build_root="tmp/test_facade_builder_diagnostic_supporting_types_entry"
units_dir="$build_root/units"
bin_dir="$build_root/bin"
binary="$bin_dir/test_facade_builder_diagnostic_supporting_types_entry"

printf '[TEST] facade builder/diagnostic supporting-type export contract\n'

require_fixed "$facade" "TBuildValidationResult = nextpas.core.tls.base.TBuildValidationResult;" \
  "main facade must re-export TBuildValidationResult"
require_fixed "$facade" "TSSLErrorRecord = nextpas.core.tls.base.TSSLErrorRecord;" \
  "main facade must re-export TSSLErrorRecord"
require_fixed "$api_ref" '主门面 `fafafa.ssl` 当前也 re-export `TBuildValidationResult`；使用 `nextpas.core.tls.context.builder` 时不需要回退 `nextpas.core.tls.base` 才能接住 `Validate*` / `Build*WithValidation(...)` 的结果。' \
  "API reference must record the main-facade builder-validation supporting type"
require_fixed "$api_ref" '主门面 `fafafa.ssl` 当前也 re-export `TSSLErrorRecord`；与 `TSSLDiagnosticInfo` 一起使用时不需要回退 `nextpas.core.tls.base`。' \
  "API reference must record the main-facade diagnostics supporting type"

mkdir -p "$units_dir" "$bin_dir"
fpc -B -Fu./src -Fu./tests -FU"$units_dir" -FE"$bin_dir" -o"$binary" "$contract_src" >/dev/null
if [[ ! -x "$binary" ]]; then
  fail "facade builder/diagnostic contract source compiles through main facade" "expected binary missing: $binary"
fi
pass "facade builder/diagnostic contract source compiles through main facade"

"$binary" >/dev/null
pass "facade builder/diagnostic contract runs successfully"

printf '[PASS] facade builder/diagnostic supporting-type export contract passed\n'
