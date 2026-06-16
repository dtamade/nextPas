#!/usr/bin/env bash
set -euo pipefail

CORE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
RESULTS="$CORE_ROOT/benchmarks/nextpas.core.encoding/bench_encoding/RESULTS.md"
README="$CORE_ROOT/docs/encoding/README.md"

fail() {
  echo "[FAIL] $*" >&2
  exit 1
}

require_token() {
  local token="$1"
  rg -F --quiet -- "$token" "$RESULTS" || fail "RESULTS.md missing token: $token"
}

require_readme_token() {
  local token="$1"
  rg -F --quiet -- "$token" "$README" || fail "README.md missing token: $token"
}

[[ -s "$RESULTS" ]] || fail "missing non-empty benchmark results truth file"
[[ -s "$README" ]] || fail "missing non-empty encoding module README"

line_count="$(wc -l < "$RESULTS")"
[[ "$line_count" -le 60 ]] || fail "RESULTS.md is too large: $line_count lines"

readme_line_count="$(wc -l < "$README")"
[[ "$readme_line_count" -le 120 ]] || fail "README.md is too large: $readme_line_count lines"

require_token "historical snapshot"
require_token "not current CI performance truth"
require_token "same host"
require_token "FPC"
require_token "Go"
require_token "Rust"
require_token "make -C benchmarks/nextpas.core.encoding/bench_encoding clean run"

require_readme_token "RFC 4648"
require_readme_token "Base64UrlEncode omits padding"
require_readme_token "UrlDecode validates UTF-8"
require_readme_token "+ decodes to space"
require_readme_token "HexDecode rejects odd length"
require_readme_token "VarintDecode rejects non-canonical"
require_readme_token "NEXTPAS_BENCH_FILTER"
require_readme_token "NEXTPAS_BENCH_MAX_ITERS"
require_readme_token "Rust comparator is encode-only naive"
require_readme_token "not a durable ranking"

echo "encoding-docs-truth=pass"
