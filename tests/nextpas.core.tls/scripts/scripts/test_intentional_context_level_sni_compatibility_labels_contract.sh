#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

declare -a files=(
  "tests/test_context_builder_server_servername_runtime_consistency.pas"
)

pattern='(Context|Ctx|LCtx|LContext)\.SetServerName\('
marker='INTENTIONAL_COMPAT:'

for file in "${files[@]}"; do
  if ! rg -n --quiet "$pattern" "$file"; then
    echo "[FAIL] expected intentional context-level SNI coverage was not found: $file"
    exit 1
  fi

  if ! rg -n --quiet "$marker" "$file"; then
    echo "[FAIL] missing compatibility label for intentional context-level SNI: $file"
    exit 1
  fi
done

echo "[PASS] intentional context-level SNI compatibility tests are explicitly labeled"
