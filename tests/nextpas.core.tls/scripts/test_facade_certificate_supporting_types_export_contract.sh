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

facade="src/nextpas.core.tls.pas"
api_ref="docs/reference/API_REFERENCE.md"
contract_src="tests/contract/test_facade_certificate_supporting_types_entry.pas"
build_root="tmp/test_facade_certificate_supporting_types_entry"
units_dir="$build_root/units"
bin_dir="$build_root/bin"
binary="$bin_dir/test_facade_certificate_supporting_types_entry"

printf '[TEST] facade certificate supporting-type export contract\n'

require_fixed "$facade" "TSSLStringArray = nextpas.core.tls.base.TSSLStringArray;" \
  "main facade must re-export TSSLStringArray"
require_fixed "$facade" "TSSLCertVerifyResult = nextpas.core.tls.base.TSSLCertVerifyResult;" \
  "main facade must re-export TSSLCertVerifyResult"
require_fixed "$api_ref" '`fafafa.ssl` 主门面当前也 re-export 证书 public surface 常用 supporting types（如 `TSSLStringArray` / `TSSLCertVerifyResult` / `TSSLCertVerifyFlags`）。' \
  "API reference must record the main facade certificate supporting-type coverage"

mkdir -p "$units_dir" "$bin_dir"
fpc -B -Fu./src -Fu./tests -FU"$units_dir" -FE"$bin_dir" -o"$binary" "$contract_src" >/dev/null
if [[ ! -x "$binary" ]]; then
  fail "facade certificate supporting-type contract source must compile through uses fafafa.ssl"
fi

"$binary"

printf '[PASS] facade certificate supporting-type export contract passed\n'
