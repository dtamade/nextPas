#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$ROOT_DIR/scripts/validate_all_modules.ps1"

fail() {
  echo "[FAIL] $1"
  exit 1
}

echo "[TEST] validate_all_modules module scan + threshold contract"

if [[ ! -f "$SCRIPT" ]]; then
  fail "missing file: scripts/validate_all_modules.ps1"
fi

# Must use CmdletBinding to allow common parameters like -Verbose.
if ! rg -F --quiet -- '[CmdletBinding()]' "$SCRIPT"; then
  fail "validate_all_modules.ps1 should use [CmdletBinding()]"
fi

# Must not declare a custom [switch]$Verbose (conflicts with common -Verbose).
if rg -F --quiet -- '[switch]$Verbose' "$SCRIPT"; then
  fail "validate_all_modules.ps1 must not declare [switch]\$Verbose"
fi

# Must scan actual OpenSSL units from src/ to avoid hard-coded drift.
if ! rg -F --quiet -- 'Get-ChildItem -Path $srcDir -Filter "nextpas.core.tls.openssl*.pas" -File' "$SCRIPT"; then
  fail "validate_all_modules.ps1 should scan src/ via Get-ChildItem -Filter nextpas.core.tls.openssl*.pas"
fi

# Must fail fast when too few modules are detected (prevents false-positive PASS).
if ! rg -n --quiet 'if \(\$allModules\.Count -lt \$MinModuleCount\)' "$SCRIPT"; then
  fail "validate_all_modules.ps1 should enforce MinModuleCount threshold"
fi

# Guard against old hard-coded module names sneaking back in.
if rg -F --quiet -- 'nextpas.core.tls.openssl.core.pas' "$SCRIPT"; then
  fail "validate_all_modules.ps1 must not reference legacy module path nextpas.core.tls.openssl.core.pas"
fi

echo "[PASS] validate_all_modules module scan + threshold contract passed"
