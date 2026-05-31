#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$ROOT_DIR/scripts/run_freepascal_tls13_completeness_gate.sh"

fail() {
  echo "[FAIL] $1"
  exit 1
}

if [[ ! -f "$SCRIPT" ]]; then
  fail "focused gate script must exist"
fi

if rg -n --quiet '(^|[^[:alnum:]_])(eval|bash[[:space:]]+-c|sh[[:space:]]+-c|zsh[[:space:]]+-c)\b' "$SCRIPT"; then
  fail "freepascal tls13 completeness gate should not rely on shell-string execution"
fi

echo "[PASS] freepascal tls13 completeness gate no-shell-execution contract passed"
