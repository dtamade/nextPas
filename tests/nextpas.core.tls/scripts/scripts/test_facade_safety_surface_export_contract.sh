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
readme="README.md"
migration="docs/guides/MIGRATION_GUIDE.md"
contract_src="tests/contract/test_facade_safety_surface_entry.pas"
build_root="tmp/test_facade_safety_surface_entry"
units_dir="$build_root/units"
bin_dir="$build_root/bin"
binary="$bin_dir/test_facade_safety_surface_entry"

printf '[TEST] facade safety surface export contract\n'

require_fixed "$facade" "TSSLVersion = nextpas.core.tls.safety.TSSLVersion;" \
  "main facade must re-export TSSLVersion"
require_fixed "$facade" "TKeySize = nextpas.core.tls.safety.TKeySize;" \
  "main facade must re-export TKeySize"
require_fixed "$facade" "function SSLVersionToString(AVersion: TSSLVersion): string;" \
  "main facade must forward SSLVersionToString"
require_fixed "$api_ref" '`fafafa.ssl` 主门面当前也 re-export 这组 non-generic type-safety public surface（如 `TSSLVersion` / `TKeySize` / `TTimeoutDuration` / `TBufferSize`）；`TSecureData<T>` / `TResult<T, E>` 继续保留在 `nextpas.core.tls.safety`。' \
  "API reference must record the main facade type-safety surface coverage"
require_fixed "$readme" '`fafafa.ssl` 主门面当前也 re-export `TSSLVersion` / `TKeySize` / `TTimeoutDuration` / `TBufferSize` 这组 non-generic type-safety surface；`TSecureData<T>` / `TResult<T, E>` 继续保留在 `nextpas.core.tls.safety`。' \
  "README must mention the current facade type-safety surface"
require_fixed "$migration" '如果你在新代码里要直接使用 `TSSLVersion` / `TKeySize` / `TTimeoutDuration` / `TBufferSize`，当前可以直接从 `fafafa.ssl` 取得；若你要使用 `TSecureData<T>` / `TResult<T, E>` 这组 generic pattern，则继续单独 `uses nextpas.core.tls.safety`。' \
  "migration guide must explain current safety-surface entrypoints"

mkdir -p "$units_dir" "$bin_dir"
fpc -B -Fu./src -Fu./tests -FU"$units_dir" -FE"$bin_dir" -o"$binary" "$contract_src" >/dev/null
if [[ ! -x "$binary" ]]; then
  fail "facade safety-surface contract source must compile through uses fafafa.ssl"
fi

"$binary"

printf '[PASS] facade safety surface export contract passed\n'
