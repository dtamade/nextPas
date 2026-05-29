#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

declare -a files=(
  "tests/winssl/test_winssl_performance.pas"
  "tests/winssl/test_winssl_session_reuse_benchmark.pas"
  "tests/integration/test_backend_comparison.pas"
)

pattern='[A-Za-z_][A-Za-z0-9_]*(Context|Ctx)[0-9]*\.SetServerName\('

for file in "${files[@]}"; do
  if rg -n --quiet "$pattern" "$file"; then
    echo "[FAIL] performance/comparison test still teaches deprecated context-level SNI: $file"
    rg -n "$pattern" "$file" || true
    exit 1
  fi
done

echo "[PASS] selected WinSSL performance and backend comparison tests no longer teach deprecated context-level SNI"
