#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORKFLOWS=(
  "$ROOT_DIR/.github/workflows/wave-b-b2-manual.yml"
  "$ROOT_DIR/.github/workflows/wave-b-b2-manual.yml.disabled"
  "$ROOT_DIR/.github/workflows/winssl-tests.yml.disabled"
  "$ROOT_DIR/.github/workflows/test-all-platforms.yml.disabled"
)

fail() {
  echo "[FAIL] $1"
  exit 1
}

echo "[TEST] workflow windows fpc preference contract"

for workflow in "${WORKFLOWS[@]}"; do
  [[ -f "$workflow" ]] || fail "missing workflow file: ${workflow#$ROOT_DIR/}"

  if ! rg -F --quiet -- '[INFO] Preferred FPC path:' "$workflow"; then
    fail "${workflow#$ROOT_DIR/} should record the preferred Windows FPC path"
  fi

  if ! rg -F --quiet -- '[INFO] fpc resolved to:' "$workflow"; then
    fail "${workflow#$ROOT_DIR/} should record the resolved fpc executable"
  fi

  if ! rg -F --quiet -- '$fpcPreferredDir = $fpcCandidates | Select-Object -First 1' "$workflow"; then
    fail "${workflow#$ROOT_DIR/} should choose one preferred FPC directory instead of prepending every candidate"
  fi
done

echo "[PASS] workflow windows fpc preference contract passed"
