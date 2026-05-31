#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

declare -a files=(
  "tests/integration/test_cross_backend_consistency_contract.pas"
  "tests/integration/test_cross_backend_errors_contract.pas"
)

for file in "${files[@]}"; do
  if grep -n -q 'Ctx\.SetServerName(' "$file"; then
    echo "[FAIL] cross-backend network contract still teaches context-level SNI: $file"
    grep -n 'Ctx\.SetServerName(' "$file" || true
    exit 1
  fi

  if ! grep -q 'SetServerName(' "$file"; then
    echo "[FAIL] missing explicit SNI configuration in: $file"
    exit 1
  fi
done

echo "[PASS] cross-backend network contracts use explicit per-connection SNI instead of context-level guidance"
