#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"

cd "$PROJECT_ROOT"

declare -A expected_labels=(
  ["core/tests/nextpas.core.tls/mbedtls/test_mbedtls_context_contract.pas"]="INTENTIONAL_API_SURFACE"
  ["core/tests/nextpas.core.tls/wolfssl/test_wolfssl_context_contract.pas"]="INTENTIONAL_API_SURFACE"
  ["core/tests/nextpas.core.tls/winssl/test_winssl_library_basic.pas"]="INTENTIONAL_API_SURFACE"
  ["core/tests/nextpas.core.tls/winssl/test_winssl_mtls_skeleton.pas"]="INTENTIONAL_API_SURFACE"
)

for file in "${!expected_labels[@]}"; do
  label="${expected_labels[$file]}"
  if ! grep -q "$label" "$file"; then
    echo "[FAIL] missing $label classification in $file"
    exit 1
  fi
done

if grep -n -q 'Ctx\.SetServerName(ServerHost);' core/tests/nextpas.core.tls/winssl/test_winssl_mtls_skeleton.pas; then
  echo "[FAIL] WinSSL mTLS handshake flow still uses deprecated context-level SNI"
  grep -n 'Ctx\.SetServerName(ServerHost);' core/tests/nextpas.core.tls/winssl/test_winssl_mtls_skeleton.pas || true
  exit 1
fi

echo "[PASS] residual context-level SNI files are explicitly classified and the mTLS handshake flow no longer uses context-level SNI"
