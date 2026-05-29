#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

source_file="src/nextpas.core.tls.winssl.certificate.pas"
runtime_test="tests/winssl/test_winssl_unit_comprehensive.pas"

required_source_patterns=(
  'TryLoadParsedWinSSLCertificate\(Self, LParser\)'
  'Result\.PublicKeySize :='
  'Result\.PathLength :='
  'Result\.PathLenConstraint :='
  'Result\.KeyUsage :='
  'X509SubjectAltNamesToStrings'
  'X509ExtKeyUsageToStrings'
)

for pattern in "${required_source_patterns[@]}"; do
  if ! rg -n --quiet "$pattern" "$source_file"; then
    echo "[FAIL] WinSSL certificate metadata source is missing expected pattern: $pattern"
    exit 1
  fi
done

forbidden_source_patterns=(
  'AddToResult\(OIDStr\);'
  'TLS Web Server Authentication'
  'TLS Web Client Authentication'
)

for pattern in "${forbidden_source_patterns[@]}"; do
  if rg -n --quiet "$pattern" "$source_file"; then
    echo "[FAIL] WinSSL certificate metadata source still publishes legacy EKU drift: $pattern"
    exit 1
  fi
done

required_runtime_assertions=(
  'SAN-rich fixture getter contains admin@example-rich.test'
  'SAN-rich fixture getter contains spiffe://mesh/service'
  'SAN-rich fixture GetInfo keeps parser SAN truth'
  'KeyUsage fixture getter keeps parser extended-key-usage truth'
  'ECDSA CA fixture GetInfo exposes public-key size truth'
  'ECDSA CA fixture GetInfo path length matches parser truth'
)

for pattern in "${required_runtime_assertions[@]}"; do
  if ! rg -n --quiet "$pattern" "$runtime_test"; then
    echo "[FAIL] WinSSL runtime proof is missing assertion: $pattern"
    exit 1
  fi
done

echo "[PASS] WinSSL certificate metadata source/runtime truth is aligned"
