#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

TMP_DIR="tmp/tls_facade_warning_contract"
rm -rf "$TMP_DIR"
mkdir -p "$TMP_DIR"
mkdir -p "$TMP_DIR/units"
trap 'rm -rf "$TMP_DIR"' EXIT

set +e
output="$(
  fpc -B \
    -Fu./src \
    -FU"$TMP_DIR/units" \
    -Mobjfpc \
    -Scgi \
    -O2 \
    -g \
    -gl \
    -vewnhi \
    src/nextpas.core.tls.tls.pas 2>&1
)"
exit_code=$?
set -e

if [[ "$exit_code" -ne 0 ]]; then
  echo "[FAIL] nextpas.core.tls.tls direct compile should succeed (got: $exit_code)"
  printf '%s\n' "$output"
  exit 1
fi

if printf '%s\n' "$output" | rg -n --quiet 'fafafa\.ssl\.tls\.pas\([^)]*\) Warning:'; then
  echo "[FAIL] nextpas.core.tls.tls should compile without file-local warnings"
  printf '%s\n' "$output" | rg -n 'fafafa\.ssl\.tls\.pas\([^)]*\) Warning:' || true
  exit 1
fi

echo "[PASS] nextpas.core.tls.tls compiles without file-local warnings"
