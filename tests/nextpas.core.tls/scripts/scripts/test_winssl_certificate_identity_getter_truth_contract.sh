#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

source_file="src/nextpas.core.tls.winssl.certificate.pas"
runtime_test="tests/winssl/test_winssl_certstore.pas"

if rg -n --quiet 'CERT_NAME_SIMPLE_DISPLAY_TYPE' "$source_file"; then
  echo "[FAIL] WinSSL certificate identity getters still use CERT_NAME_SIMPLE_DISPLAY_TYPE"
  rg -n 'CERT_NAME_SIMPLE_DISPLAY_TYPE' "$source_file" || true
  exit 1
fi

required_source_patterns=(
  'function CertNameBlobToX500String\(AName: PCERT_NAME_BLOB\): string;'
  'CERT_X500_NAME_STR or CERT_NAME_STR_COMMA_FLAG'
  'Result := CertNameBlobToX500String\(@LCertInfo\^\.Subject\);'
  'Result := CertNameBlobToX500String\(@LCertInfo\^\.Issuer\);'
)

for pattern in "${required_source_patterns[@]}"; do
  if ! rg -n --quiet "$pattern" "$source_file"; then
    echo "[FAIL] WinSSL certificate identity getter source is missing expected full-DN pattern: $pattern"
    exit 1
  fi
done

required_runtime_assertions=(
  'GetSubject returns full DN CN component'
  'GetSubject returns full DN O component'
  'GetIssuer returns full DN CN component'
  'GetIssuer returns full DN O component'
)

for fragment in "${required_runtime_assertions[@]}"; do
  if ! rg -F -n --quiet "$fragment" "$runtime_test"; then
    echo "[FAIL] WinSSL runtime certstore contract is missing getter truth assertion: $fragment"
    exit 1
  fi
done

echo "[PASS] WinSSL certificate identity getters stay aligned to full-DN truth"
