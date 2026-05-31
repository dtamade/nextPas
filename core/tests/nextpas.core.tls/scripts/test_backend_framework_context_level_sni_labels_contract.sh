#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

declare -a files=(
  "tests/test_wolfssl_framework.pas"
)

pattern='(Context|Ctx|LCtx|LContext)[0-9]*\.SetServerName\('
marker='INTENTIONAL_API_SURFACE: context-level SNI setter coverage'

for file in "${files[@]}"; do
  if ! rg -n --quiet "$pattern" "$file"; then
    echo "[FAIL] expected backend framework context-level SNI coverage was not found: $file"
    exit 1
  fi

  if ! rg -n --quiet "$marker" "$file"; then
    echo "[FAIL] missing backend framework API-surface label for context-level SNI coverage: $file"
    exit 1
  fi
done

echo "[PASS] backend framework context-level SNI tests are explicitly labeled"
