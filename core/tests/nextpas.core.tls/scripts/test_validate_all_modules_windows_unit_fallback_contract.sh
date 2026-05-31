#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$ROOT_DIR/scripts/validate_all_modules.ps1"

fail() {
  echo "[FAIL] $1"
  exit 1
}

echo "[TEST] validate_all_modules windows unit fallback contract"

[[ -f "$SCRIPT" ]] || fail "missing file: scripts/validate_all_modules.ps1"

if ! rg -F --quiet -- 'function Add-UnitBasesFromRoot' "$SCRIPT"; then
  fail "validate_all_modules.ps1 should probe unit roots instead of relying on a single exact target directory"
fi

if ! rg -F --quiet -- 'function Get-UnitSearchEntries' "$SCRIPT"; then
  fail "validate_all_modules.ps1 should expand discovered unit roots into recursive -Fu entries"
fi

if ! rg -F --quiet -- 'Join-Path $root "lib\\fpc"' "$SCRIPT"; then
  fail "validate_all_modules.ps1 should probe lib\\fpc-based unit layouts"
fi

if ! rg -F --quiet -- 'Join-Path $root "fpc"' "$SCRIPT"; then
  fail "validate_all_modules.ps1 should probe Lazarus-style fpc bundle layouts"
fi

if ! rg -F --quiet -- 'Where-Object { [string]::IsNullOrWhiteSpace($TargetOs) -or $_.Name -like ("*-" + $TargetOs) }' "$SCRIPT"; then
  fail "validate_all_modules.ps1 should fall back to discovered *-targetOS unit directories when processor naming differs"
fi

if rg -F --quiet -- 'if (-not (Test-Path $unitsBase)) { return $args }' "$SCRIPT"; then
  fail "validate_all_modules.ps1 should not abort unit-path discovery on a single exact-path miss"
fi

echo "[PASS] validate_all_modules windows unit fallback contract passed"
