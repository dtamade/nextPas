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
  local message="$3"
  if ! grep -Fq -- "$expected" "$file"; then
    fail "$message"
  fi
}

builder_file="src/nextpas.core.tls.context.builder.pas"
contract_src="tests/config/test_context_builder_try.pas"
build_root="tmp/test_tsslcontextconfig_builder_adoption"
units_dir="$build_root/units"
bin_dir="$build_root/bin"
binary="$bin_dir/test_context_builder_try"
fpc_exe="${FAFAFA_FPC_EXE:-fpc}"

printf '[TEST] TSSLContextConfig builder adoption contract\n'

require_fixed "$builder_file" \
  "function BuildContextConfig(AContextType: TSSLContextType; ALibraryType: TSSLLibraryType): TSSLContextConfig;" \
  "context builder must expose an internal TSSLContextConfig projection helper"
require_fixed "$builder_file" \
  "LConfig: TSSLContextConfig;" \
  "context builder must create contexts through a TSSLContextConfig value"
require_fixed "$builder_file" \
  "Result := TSSLFactory.CreateContext(LConfig);" \
  "context builder must consume the additive TSSLContextConfig factory overload"

mkdir -p "$units_dir" "$bin_dir"
"$fpc_exe" -B -Fu./src -Fu./tests -Fu./tests/framework -FU"$units_dir" -FE"$bin_dir" -o"$binary" "$contract_src" >/dev/null
if [[ ! -x "$binary" ]]; then
  fail "context builder runtime adoption probe must compile"
fi

"$binary"

printf '[PASS] TSSLContextConfig builder adoption contract passed\n'
