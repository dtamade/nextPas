#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

declare -a files=(
  "tests/winssl/test_winssl_context_comprehensive.pas"
  "tests/winssl/test_winssl_unit_comprehensive.pas"
  "tests/unit/test_winssl_comprehensive.pas"
)

pattern='(Context|Ctx|LCtx|LContext)[0-9]*\.SetServerName\('
marker='INTENTIONAL_API_SURFACE: context-level SNI setter coverage'

for file in "${files[@]}"; do
  if ! rg -n --quiet "$pattern" "$file"; then
    echo "[FAIL] expected WinSSL context-level SNI API-surface coverage was not found: $file"
    exit 1
  fi

  if ! rg -n --quiet "$marker" "$file"; then
    echo "[FAIL] missing WinSSL API-surface label for context-level SNI coverage: $file"
    exit 1
  fi
done

echo "[PASS] WinSSL comprehensive context-level SNI tests are explicitly labeled"
