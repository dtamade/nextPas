#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FILE="$ROOT_DIR/scripts/verify_examples_compile.sh"

fail() {
  echo "[FAIL] $1"
  exit 1
}

echo "[TEST] verify examples compile bash32 compat contract"

[[ -f "$FILE" ]] || fail "missing file: scripts/verify_examples_compile.sh"

if rg -n '\bmapfile\b' "$FILE" >/dev/null; then
  fail "verify_examples_compile.sh should stay compatible with macOS bash 3.2 and must not depend on mapfile"
fi

if ! rg -F --quiet -- 'while IFS= read -r file; do' "$FILE"; then
  fail "verify_examples_compile.sh should load the scanned example list through a bash 3.2-compatible read loop"
fi

if ! rg -F --quiet -- 'EXAMPLE_FILES+=("$file")' "$FILE"; then
  fail "verify_examples_compile.sh should append scanned example paths into EXAMPLE_FILES inside the compatibility loop"
fi

echo "[PASS] verify examples compile bash32 compat contract passed"
