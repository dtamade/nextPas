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

reject_fixed() {
  local file="$1"
  local unexpected="$2"
  local message="$3"
  if grep -Fq -- "$unexpected" "$file"; then
    fail "$message"
  fi
}

factory_file="src/nextpas.core.tls.factory.pas"
api_ref="docs/reference/API_REFERENCE.md"
contract_src="tests/test_tsslcontextconfig_surface.pas"
build_root="tmp/test_tsslcontextconfig_factory_direct_application"
units_dir="$build_root/units"
bin_dir="$build_root/bin"
binary="$bin_dir/test_tsslcontextconfig_surface"
fpc_exe="${FAFAFA_FPC_EXE:-fpc}"

printf '[TEST] TSSLContextConfig factory direct-application contract\n'

require_fixed "$factory_file" \
  "procedure NormalizeContextConfigOptions(var AConfig: TSSLContextConfig);" \
  "factory must normalize context-safe config without projecting through TSSLConfig"
require_fixed "$factory_file" \
  "procedure ApplyContextConfigToContext(" \
  "factory must have a direct context-safe apply helper"
reject_fixed "$factory_file" \
  "Result := CreateContext(SSLConfigFromContextConfig(AConfig));" \
  "TSSLContextConfig factory overload must not bounce through legacy TSSLConfig"
require_fixed "$api_ref" \
  'TSSLFactory.CreateContext(const TSSLContextConfig)` 会直接应用 context-safe 字段，不再为了新入口主路径投影回 legacy `TSSLConfig`。' \
  "API reference must describe the direct context-safe factory path"

mkdir -p "$units_dir" "$bin_dir"
"$fpc_exe" -B -Fu./src -Fu./tests -Fu./tests/framework -FU"$units_dir" -FE"$bin_dir" -o"$binary" "$contract_src" >/dev/null
if [[ ! -x "$binary" ]]; then
  fail "context-safe factory direct-application runtime probe must compile"
fi

"$binary"

printf '[PASS] TSSLContextConfig factory direct-application contract passed\n'
