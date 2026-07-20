#!/usr/bin/env bash
# Preferred-path residual nail for lockfree production sources.
# Forbids PascalCase Atomic* *calls* in core/src/nextpas.core.lockfree*.pas.
# Does not scan tests, atomic.compat definitions, or comment-only mentions without '('.
set -euo pipefail

CORE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SRC_GLOB="$CORE_ROOT/src/nextpas.core.lockfree*.pas"

fail() {
  echo "[lockfree-preferred-path] FAIL: $*" >&2
  exit 1
}

# Match call-like forms only (name + optional width suffix + '(').
PATTERN='\bAtomic(Load|Store|Exchange|CompareExchange|FetchAdd|FetchSub|FetchAnd|FetchOr|FetchXor)(32|64|Ptr)?[[:space:]]*\('

shopt -s nullglob
files=( $SRC_GLOB )
if [[ ${#files[@]} -eq 0 ]]; then
  fail "no lockfree sources matched: $SRC_GLOB"
fi

hits="$(rg -n --pcre2 "$PATTERN" "${files[@]}" 2>/dev/null || true)"
if [[ -n "$hits" ]]; then
  echo "$hits" >&2
  fail "legacy PascalCase Atomic* calls found in lockfree production sources (use atomic_* + mo_*)"
fi

# Positive control: preferred path still present on a known T1 unit.
rg -F --quiet 'atomic_compare_exchange_strong' \
  "$CORE_ROOT/src/nextpas.core.lockfree.stack.pas" ||
  fail "expected preferred CAS still present in lockfree.stack"

rg -F --quiet 'LoadNode' \
  "$CORE_ROOT/src/nextpas.core.lockfree.mpsc.pas" ||
  fail "expected mpsc LoadNode helper (preferred naming)"

echo "lockfree-preferred-path=pass (scanned ${#files[@]} files)"
