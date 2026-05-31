#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

source_file="src/nextpas.core.tls.winssl.certificate.pas"
runtime_test="tests/winssl/test_winssl_unit_comprehensive.pas"

if rg -n --quiet 'Result := BinaryToHexString\(ExtInfo\^\.Value\.pbData, ExtInfo\^\.Value\.cbData\);' "$source_file"; then
  echo "[FAIL] WinSSL GetExtension still publishes colon-separated raw hex instead of parser-backed contract truth"
  exit 1
fi

required_runtime_assertions=(
  'Resolve ECDSA fixture path for extension truth'
  'Load fixture into FreePascal parser truth owner'
  'GetExtension returns parser-backed Subject Key Identifier truth'
)

for pattern in "${required_runtime_assertions[@]}"; do
  if ! rg -n --quiet "$pattern" "$runtime_test"; then
    echo "[FAIL] WinSSL runtime proof is missing assertion: $pattern"
    exit 1
  fi
done

echo "[PASS] WinSSL GetExtension source/runtime truth is aligned"
