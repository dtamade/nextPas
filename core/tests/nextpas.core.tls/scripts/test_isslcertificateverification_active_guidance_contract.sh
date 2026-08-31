#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"

cd "$PROJECT_ROOT"

consistency_test="core/tests/nextpas.core.tls/integration/test_cross_backend_consistency_contract.pas"
errors_test="core/tests/nextpas.core.tls/integration/test_cross_backend_errors_contract.pas"
builder_file="core/src/nextpas.core.tls.connection.builder.pas"
tls_file="core/src/nextpas.core.tls.tls.pas"

declare -a forbidden_integration_patterns=(
  "Conn.GetVerifyResultString"
  'Conn.GetVerifyResult` / `Conn.GetVerifyResultString'
)

declare -a required_ocsp_patterns=(
  "CertVerify: ISSLCertificateVerification;"
  "Supports(Conn, ISSLCertificateVerification, CertVerify)"
  "raise Exception.Create(CertVerify.GetVerifyResultString);"
)


declare -a required_ct_patterns=(
  "CertVerify: ISSLCertificateVerification;"
  "Supports(Conn, ISSLCertificateVerification, CertVerify)"
  "raise Exception.Create('TLS handshake failed: ' + CertVerify.GetVerifyResultString);"
)


declare -a required_integration_patterns=(
  "CertVerify: ISSLCertificateVerification;"
  "Supports(Conn, ISSLCertificateVerification, CertVerify)"
  "CertVerify.GetVerifyResultString"
  'CertVerify.GetVerifyResult` / `CertVerify.GetVerifyResultString'
)



declare -a required_api_patterns=(
  "CertVerify: ISSLCertificateVerification;"
  "Supports(Conn, ISSLCertificateVerification, CertVerify)"
  "raise Exception.Create(CertVerify.GetVerifyResultString)"
)


if grep -F -q -- "VerifyCode := Conn.GetVerifyResult;" "$consistency_test"; then
  echo "[FAIL] cross-backend consistency contract still uses direct core GetVerifyResult"
  exit 1
fi

declare -a required_consistency_patterns=(
  "function GetVerificationResult(AConn: ISSLConnection): Integer;"
  "Supports(AConn, ISSLCertificateVerification, LCertVerify)"
  "Result := LCertVerify.GetVerifyResult"
  "VerifyCode := GetVerificationResult(Conn);"
)

for pattern in "${required_consistency_patterns[@]}"; do
  if ! grep -F -q -- "$pattern" "$consistency_test"; then
    echo "[FAIL] cross-backend consistency contract missing ISSLCertificateVerification owner path: $pattern"
    exit 1
  fi
done

declare -a forbidden_errors_patterns=(
  "Code := Conn.GetVerifyResult;"
  "Str := Conn.GetVerifyResultString;"
)

for pattern in "${forbidden_errors_patterns[@]}"; do
  if grep -F -q -- "$pattern" "$errors_test"; then
    echo "[FAIL] cross-backend errors contract still uses direct core certificate-verification mirrors: $pattern"
    exit 1
  fi
done

declare -a required_errors_patterns=(
  "function GetVerificationResult(AConn: ISSLConnection): Integer;"
  "function GetVerificationResultString(AConn: ISSLConnection): string;"
  "Supports(AConn, ISSLCertificateVerification, LCertVerify)"
  "Code := GetVerificationResult(Conn);"
  "Str := GetVerificationResultString(Conn);"
)

for pattern in "${required_errors_patterns[@]}"; do
  if ! grep -F -q -- "$pattern" "$errors_test"; then
    echo "[FAIL] cross-backend errors contract missing ISSLCertificateVerification owner path: $pattern"
    exit 1
  fi
done

declare -a forbidden_builder_patterns=(
  "\\bVerifyRes := AConnection\\.GetVerifyResult;"
  "\\bVerifyStr := AConnection\\.GetVerifyResultString;"
)

for pattern in "${forbidden_builder_patterns[@]}"; do
  if rg -n --quiet "$pattern" "$builder_file"; then
    echo "[FAIL] connection builder still reads direct core verify-result mirror: $pattern"
    exit 1
  fi
done

declare -a required_builder_patterns=(
  "Supports(AConnection, ISSLCertificateVerification, LCertVerify)"
  "AVerifyRes := LCertVerify.GetVerifyResult;"
  "AVerifyStr := LCertVerify.GetVerifyResultString;"
)

for pattern in "${required_builder_patterns[@]}"; do
  if ! grep -F -q -- "$pattern" "$builder_file"; then
    echo "[FAIL] connection builder missing ISSLCertificateVerification owner path: $pattern"
    exit 1
  fi
done

declare -a forbidden_tls_patterns=(
  "\\bVerifyRes := Conn\\.GetVerifyResult;"
  "\\bVerifyStr := Conn\\.GetVerifyResultString;"
)

for pattern in "${forbidden_tls_patterns[@]}"; do
  if rg -n --quiet "$pattern" "$tls_file"; then
    echo "[FAIL] TLS facade still reads direct core verify-result mirror: $pattern"
    exit 1
  fi
done

declare -a required_tls_patterns=(
  "Supports(AConn, ISSLCertificateVerification, LCertVerify)"
  "AVerifyRes := LCertVerify.GetVerifyResult;"
  "AVerifyStr := LCertVerify.GetVerifyResultString;"
)

for pattern in "${required_tls_patterns[@]}"; do
  if ! grep -F -q -- "$pattern" "$tls_file"; then
    echo "[FAIL] TLS facade missing ISSLCertificateVerification owner path: $pattern"
    exit 1
  fi
done


echo "[PASS] ISSLCertificateVerification active guidance contract passed"
