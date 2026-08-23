#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../../../.." && pwd)"
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

base_file="core/src/nextpas.core.tls.base.pas"
factory_file="core/src/nextpas.core.tls.factory.pas"
contract_src="core/tests/nextpas.core.tls/test_tsslcontextconfig_surface.pas"
build_root="tmp/test_tsslcontextconfig_surface"
units_dir="$build_root/units"
bin_dir="$build_root/bin"
binary="$bin_dir/test_tsslcontextconfig_surface"

printf '[TEST] TSSLContextConfig additive surface contract\n'

require_fixed "$base_file" "TSSLContextConfig = record" \
  "base source must declare TSSLContextConfig"
require_fixed "$base_file" "function CreateDefaultContextConfig(AContextType: TSSLContextType = sslCtxClient): TSSLContextConfig;" \
  "base source must expose CreateDefaultContextConfig"
require_fixed "$base_file" "function ContextConfigFromSSLConfig(const AConfig: TSSLConfig): TSSLContextConfig;" \
  "base source must expose ContextConfigFromSSLConfig"
require_fixed "$base_file" "function SSLConfigFromContextConfig(const AConfig: TSSLContextConfig): TSSLConfig;" \
  "base source must expose SSLConfigFromContextConfig"


require_fixed "$factory_file" "class function CreateContext(const AConfig: TSSLContextConfig): ISSLContext; overload;" \
  "factory must accept TSSLContextConfig directly"


mkdir -p "$units_dir" "$bin_dir"
fpc -B -Fu"$PWD/core/src" -Fu"$PWD/core/tests/nextpas.core.tls/framework" -FU"$units_dir" -FE"$bin_dir" -o"$binary" "$contract_src" >/dev/null
if [[ ! -x "$binary" ]]; then
  fail "TSSLContextConfig runtime probe must compile"
fi

"$binary"

printf '[PASS] TSSLContextConfig additive surface contract passed\n'
