#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

source_file="src/nextpas.core.tls.winssl.certificate.pas"
runtime_test="tests/winssl/test_winssl_unit_comprehensive.pas"

if ! rg -n --quiet 'function TWinSSLCertificate.GetPublicKey: string;' "$source_file"; then
  echo "[FAIL] WinSSL certificate source is missing GetPublicKey declaration"
  exit 1
fi

if ! rg -n --quiet 'Result := GetPublicKeyAlgorithm;' "$source_file"; then
  echo "[FAIL] WinSSL GetPublicKey is not aligned to GetPublicKeyAlgorithm contract"
  exit 1
fi

required_runtime_assertions=(
  'GetPublicKeyAlgorithm exposes Ed25519 truth'
  'GetPublicKey stays aligned with public-key algorithm contract'
)

for pattern in "${required_runtime_assertions[@]}"; do
  if ! rg -n --quiet "$pattern" "$runtime_test"; then
    echo "[FAIL] WinSSL runtime proof is missing assertion: $pattern"
    exit 1
  fi
done

echo "[PASS] WinSSL GetPublicKey contract source/runtime truth is aligned"
