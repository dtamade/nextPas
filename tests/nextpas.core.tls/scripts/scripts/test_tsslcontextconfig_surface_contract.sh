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

base_file="src/nextpas.core.tls.base.pas"
facade_file="src/nextpas.core.tls.pas"
factory_file="src/nextpas.core.tls.factory.pas"
api_ref="docs/reference/API_REFERENCE.md"
contract_src="tests/test_tsslcontextconfig_surface.pas"
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

require_fixed "$facade_file" "TSSLContextConfig = nextpas.core.tls.base.TSSLContextConfig;" \
  "facade must re-export TSSLContextConfig"
require_fixed "$facade_file" "function CreateDefaultContextConfig(AContextType: TSSLContextType = sslCtxClient): TSSLContextConfig;" \
  "facade must re-export CreateDefaultContextConfig"
require_fixed "$facade_file" "function ContextConfigFromSSLConfig(const AConfig: TSSLConfig): TSSLContextConfig;" \
  "facade must re-export ContextConfigFromSSLConfig"
require_fixed "$facade_file" "function SSLConfigFromContextConfig(const AConfig: TSSLContextConfig): TSSLConfig;" \
  "facade must re-export SSLConfigFromContextConfig"

require_fixed "$factory_file" "class function CreateContext(const AConfig: TSSLContextConfig): ISSLContext; overload;" \
  "factory must accept TSSLContextConfig directly"

require_fixed "$api_ref" '## Context-Safe Config Surface Note' \
  "API reference must describe the additive context-safe config surface"
require_fixed "$api_ref" '`TSSLContextConfig` 是 `TSSLConfig` scope surgery 的第一条 additive surface。' \
  "API reference must explain why TSSLContextConfig exists"

mkdir -p "$units_dir" "$bin_dir"
fpc -B -Fu./src -Fu./tests -Fu./tests/framework -FU"$units_dir" -FE"$bin_dir" -o"$binary" "$contract_src" >/dev/null
if [[ ! -x "$binary" ]]; then
  fail "TSSLContextConfig runtime probe must compile"
fi

"$binary"

printf '[PASS] TSSLContextConfig additive surface contract passed\n'
