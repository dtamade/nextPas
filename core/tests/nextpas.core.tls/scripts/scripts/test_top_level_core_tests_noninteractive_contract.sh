#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

files=(
  "tests/test_exceptions.pas"
  "tests/test_base_interface_contract.pas"
)

for file in "${files[@]}"; do
  if rg -n --quiet '按回车键退出|ReadLn\s*;' "$file"; then
    echo "[FAIL] interactive exit tail remains in top-level core test: $file"
    rg -n '按回车键退出|ReadLn\s*;' "$file"
    exit 1
  fi
done

echo "[PASS] top-level core tests are noninteractive"
