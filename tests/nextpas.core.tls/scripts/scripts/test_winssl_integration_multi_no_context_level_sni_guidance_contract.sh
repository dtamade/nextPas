#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

test_file="tests/winssl/test_winssl_integration_multi.pas"
pattern='(Context|Ctx|LCtx|LContext)[0-9]*\.SetServerName\('

if rg -n --quiet "$pattern" "$test_file"; then
  echo "[FAIL] WinSSL integration multi test still teaches deprecated context-level SNI"
  rg -n "$pattern" "$test_file" || true
  exit 1
fi

echo "[PASS] WinSSL integration multi test no longer teaches deprecated context-level SNI"
