#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

declare -a files=(
  "examples/example_factory_usage.pas"
  "examples/winssl_health_checker.pas"
  "examples/winssl_https_downloader.pas"
  "examples/winssl_rest_client.pas"
  "tests/examples/test_basic.pas"
  "tests/examples/test_certchain.pas"
  "tests/examples/test_performance.pas"
  "tests/examples/test_winssl.pas"
  "tests/examples/test_winssl_debug.pas"
  "tests/examples/test_winssl_simple.pas"
)

pattern='(Context|Ctx|LCtx|LContext)\.SetServerName\('

for file in "${files[@]}"; do
  if rg -n --quiet "$pattern" "$file"; then
    echo "[FAIL] high-visibility example still teaches deprecated context-level SNI: $file"
    rg -n "$pattern" "$file" || true
    exit 1
  fi
done

echo "[PASS] high-visibility examples no longer teach deprecated context-level SNI"
