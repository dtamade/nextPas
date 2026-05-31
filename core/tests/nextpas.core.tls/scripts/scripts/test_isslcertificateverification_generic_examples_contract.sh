#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

helper_file="examples/fafafa.examples.tcp.pas"
connection_test="tests/connection/test_ssl_client_connection.pas"

declare -a required_helper_patterns=(
  "procedure GetCertificateVerificationInfo(AConnection: ISSLConnection;"
  "Supports(AConnection, ISSLCertificateVerification, LCertVerify)"
  "AVerifyResult := LCertVerify.GetVerifyResult;"
  "AVerifyResultString := LCertVerify.GetVerifyResultString;"
  "AVerifyResult := AConnection.GetVerifyResult;"
  "AVerifyResultString := AConnection.GetVerifyResultString;"
)

for pattern in "${required_helper_patterns[@]}"; do
  if ! grep -F -q -- "$pattern" "$helper_file"; then
    echo "[FAIL] example helper missing ISSLCertificateVerification-first verify-result path: $pattern"
    exit 1
  fi
done

declare -a required_connection_test_patterns=(
  "procedure GetCertificateVerificationInfo(AConnection: ISSLConnection;"
  "Supports(AConnection, ISSLCertificateVerification, LCertVerify)"
  "GetCertificateVerificationInfo(Connection, VerifyResult, VerifyResultString);"
)

for pattern in "${required_connection_test_patterns[@]}"; do
  if ! grep -F -q -- "$pattern" "$connection_test"; then
    echo "[FAIL] SSL client connection test missing local ISSLCertificateVerification owner path: $pattern"
    exit 1
  fi
done

check_target() {
  local file="$1"
  local required_pattern="$2"

  if ! grep -F -q -- "$required_pattern" "$file"; then
    echo "[FAIL] generic example/test missing shared verify-info helper call: $file :: $required_pattern"
    exit 1
  fi

  if rg -n --quiet '\.(GetVerifyResultString|GetVerifyResult)\b' "$file"; then
    echo "[FAIL] generic example/test still reads direct core verify-result getter: $file"
    rg -n '\.(GetVerifyResultString|GetVerifyResult)\b' "$file"
    exit 1
  fi
}

check_target "examples/01_tls_client.pas" \
  "GetCertificateVerificationInfo(TLS.Connection, LVerifyResult, LVerifyResultString);"
check_target "examples/example_https_api.pas" \
  "GetCertificateVerificationInfo(TLS.Connection, Result.VerifyResult, Result.VerifyResultString);"
check_target "examples/production/https_client_auth.pas" \
  "GetCertificateVerificationInfo(LConnection, LVerifyResult, LVerifyResultString);"
check_target "examples/validation/real_world_test.pas" \
  "GetCertificateVerificationInfo(LConnection, LVerifyResult, LVerifyResultString);"
check_target "tests/examples/test_openssl.pas" \
  "GetCertificateVerificationInfo(Conn, LVerifyResult, LVerifyResultString);"
check_target "tests/examples/test_real_websites.pas" \
  "GetCertificateVerificationInfo(TLS.Connection, LVerifyResult, LVerifyResultString);"
check_target "tests/examples/test_real_websites_enhanced.pas" \
  "GetCertificateVerificationInfo(TLS.Connection, LVerifyResult, Result.VerifyResult);"
check_target "tests/examples/test_real_websites_comprehensive.pas" \
  "GetCertificateVerificationInfo(TLS.Connection, LVerifyResult, Result.VerifyResult);"

echo "[PASS] generic examples/tests prefer ISSLCertificateVerification for verify-result surfaces"
