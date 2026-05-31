#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

declare -a files=(
  "tests/winssl/test_winssl_hostname_mismatch_online.pas"
  "tests/winssl/test_winssl_alpn_sni.pas"
  "tests/winssl/test_winssl_session_resumption.pas"
)

pattern='(Context|Ctx|LCtx|LContext)[0-9]*\.SetServerName\('

for file in "${files[@]}"; do
  if rg -n --quiet "$pattern" "$file"; then
    echo "[FAIL] WinSSL online-flow test still teaches deprecated context-level SNI: $file"
    rg -n "$pattern" "$file" || true
    exit 1
  fi
done

echo "[PASS] selected WinSSL online-flow tests no longer teach deprecated context-level SNI"
