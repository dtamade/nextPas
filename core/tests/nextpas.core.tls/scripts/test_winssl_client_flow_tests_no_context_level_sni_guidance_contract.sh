#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

declare -a files=(
  "tests/winssl/test_winssl_error_mapping_online.pas"
  "tests/winssl/test_winssl_https_client.pas"
  "tests/winssl/test_winssl_revocation_online.pas"
  "tests/winssl/test_winssl_mtls_e2e_local.pas"
)

pattern='(Context|Ctx|LCtx|LContext)\.SetServerName\('

for file in "${files[@]}"; do
  if grep -n -E -q "$pattern" "$file"; then
    echo "[FAIL] WinSSL client flow still uses deprecated context-level SNI guidance: $file"
    grep -n -E "$pattern" "$file" || true
    exit 1
  fi
done

echo "[PASS] selected WinSSL client flow tests no longer use context-level SNI guidance"
