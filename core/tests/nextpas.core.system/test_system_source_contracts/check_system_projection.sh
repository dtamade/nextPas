#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
PROJECTION_SCRIPT="$REPO_ROOT/scripts/system-projection.sh"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

[[ -x "$PROJECTION_SCRIPT" ]] ||
  fail "projection command missing or not executable: scripts/system-projection.sh"

invalid_output="$(mktemp)"
trap 'rm -f "$invalid_output"' EXIT
if "$PROJECTION_SCRIPT" check unsupported-target >"$invalid_output" 2>&1; then
  fail "unsupported target unexpectedly accepted"
fi
grep -Fq "unsupported System projection target: unsupported-target" "$invalid_output" ||
  fail "unsupported target diagnostic is not stable"

"$PROJECTION_SCRIPT" check linux-x86_64
cmp -s "$REPO_ROOT/rtl/core/system/System.pas" \
  "$REPO_ROOT/units/linux-x86_64/System.pas" ||
  fail "canonical and installed System units differ after projection check"

printf 'system-projection-contract=pass target=linux-x86_64\n'
