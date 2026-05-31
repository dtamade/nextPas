#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

declare -a files=(
  "tests/examples/test_lib_core_functionality.pas"
  "tests/diagnostic/test_error_handling.pas"
  "tests/diagnostic/test_error_handling_comprehensive.pas"
  "tests/security/test_memory_safety.pas"
  "tests/security/test_input_validation.pas"
)

pattern='(Context|Ctx|LCtx|LContext)\.SetServerName\('
marker='INTENTIONAL_API_SURFACE: context-level SNI setter coverage'

for file in "${files[@]}"; do
  if ! rg -n --quiet "$pattern" "$file"; then
    echo "[FAIL] expected context-level SNI API-surface coverage was not found: $file"
    exit 1
  fi

  if ! rg -n --quiet "$marker" "$file"; then
    echo "[FAIL] missing API-surface label for context-level SNI coverage: $file"
    exit 1
  fi
done

echo "[PASS] selected API-surface context-level SNI tests are explicitly labeled"
