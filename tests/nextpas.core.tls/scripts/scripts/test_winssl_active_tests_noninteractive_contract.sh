#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

files=(
  "tests/unit/test_winssl_comprehensive.pas"
  "tests/winssl/test_winssl_context_comprehensive.pas"
  "tests/winssl/test_winssl_errors_comprehensive.pas"
  "tests/winssl/test_winssl_monitoring.pas"
  "tests/winssl/test_winssl_connection_edge_cases.pas"
  "tests/winssl/test_winssl_certstore.pas"
  "tests/winssl/test_winssl_session_management.pas"
  "tests/winssl/test_winssl_library_basic.pas"
  "tests/winssl/test_winssl_certificate_loading.pas"
)

pattern='按回车键退出|Press Enter to exit|ReadLn\s*;'

for file in "${files[@]}"; do
  if rg -n --quiet "$pattern" "$file"; then
    echo "[FAIL] interactive exit tail remains in active WinSSL test: $file"
    rg -n "$pattern" "$file"
    exit 1
  fi
done

echo "[PASS] active WinSSL tests are noninteractive"
