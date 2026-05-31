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
contract_src="tests/contract/test_facade_option_surface_entry.pas"
build_root="tmp/test_facade_option_surface_entry"
units_dir="$build_root/units"
bin_dir="$build_root/bin"
binary="$bin_dir/test_facade_option_surface_entry"

printf '[TEST] facade option surface export contract\n'

require_fixed "$facade" "TSSLOption = nextpas.core.tls.base.TSSLOption;" \
  "main facade must re-export TSSLOption"
require_fixed "$facade" "TSSLOptions = nextpas.core.tls.base.TSSLOptions;" \
  "main facade must re-export TSSLOptions"
require_fixed "$facade" "ssoEnableSNI = nextpas.core.tls.base.ssoEnableSNI;" \
  "main facade must re-export ssoEnableSNI"
require_fixed "$facade" "ssoEnableALPN = nextpas.core.tls.base.ssoEnableALPN;" \
  "main facade must re-export ssoEnableALPN"
require_fixed "$facade" "ssoRequireCertificateTransparency = nextpas.core.tls.base.ssoRequireCertificateTransparency;" \
  "main facade must re-export the tail option constants too"
require_fixed "$api_ref" '主门面 `fafafa.ssl` 当前也 re-export `TSSLOption` / `TSSLOptions` 与 `sso*` option 常量；普通调用方配置 context options 时不需要回退 `nextpas.core.tls.base`。' \
  "API reference must record the main-facade option-surface coverage"

mkdir -p "$units_dir" "$bin_dir"
fpc -B -Fu./src -Fu./tests -FU"$units_dir" -FE"$bin_dir" -o"$binary" "$contract_src" >/dev/null
if [[ ! -x "$binary" ]]; then
  fail "facade-only option contract compiles via uses fafafa.ssl" "expected binary missing: $binary"
fi
pass "facade-only option contract compiles via uses fafafa.ssl"

"$binary" >/dev/null
pass "facade-only option contract runs successfully"

printf '[PASS] facade option surface export contract passed\n'
