#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

compare_file_list() {
  local label="$1"
  local actual="$2"
  local expected="$3"

  if [[ "$actual" != "$expected" ]]; then
    echo "[FAIL] $label mismatch"
    echo "[expected]"
    printf '%s\n' "$expected"
    echo "[actual]"
    printf '%s\n' "$actual"
    exit 1
  fi
}

require_pattern() {
  local file="$1"
  local pattern="$2"

  if ! grep -F -q -- "$pattern" "$file"; then
    echo "[FAIL] missing pattern in $file :: $pattern"
    exit 1
  fi
}

expected_hits="$(cat <<'EOF'
tests/mbedtls/benchmark_handshake_simple.pas
tests/mbedtls/test_mbedtls_cert_chain.pas
tests/mbedtls/test_mbedtls_cert_errors.pas
tests/mbedtls/test_mbedtls_cert_verify_flags.pas
tests/mbedtls/test_mbedtls_lowlevel.pas
tests/mbedtls/test_mbedtls_safe.pas
tests/mbedtls/test_mbedtls_simple_connection.pas
EOF
)"

actual_hits="$(rg -lP '\b(?:Conn|LConn|LConnection)\.GetVerifyResult(?:String)?\b' tests/mbedtls | sort || true)"
compare_file_list "MbedTLS direct-core verify-result residual file set" "$actual_hits" "$expected_hits"

declare -a residual_files=(
  "tests/mbedtls/benchmark_handshake_simple.pas"
  "tests/mbedtls/test_mbedtls_safe.pas"
  "tests/mbedtls/test_mbedtls_simple_connection.pas"
  "tests/mbedtls/test_mbedtls_lowlevel.pas"
  "tests/mbedtls/test_mbedtls_cert_chain.pas"
  "tests/mbedtls/test_mbedtls_cert_errors.pas"
  "tests/mbedtls/test_mbedtls_cert_verify_flags.pas"
)

declare -a required_comment_patterns=(
  "INTENTIONAL_VERIFY_RESULT_CORE_SURFACE: this MbedTLS-specific"
  "file intentionally keeps direct core"
  "Generic ISSLCertificateVerification owner-path"
  "guidance is frozen elsewhere."
)

for file in "${residual_files[@]}"; do
  for pattern in "${required_comment_patterns[@]}"; do
    require_pattern "$file" "$pattern"
  done
done

require_pattern "tests/mbedtls/benchmark_handshake_simple.pas" "GetVerifyResultString"
require_pattern "tests/mbedtls/test_mbedtls_safe.pas" "GetVerifyResultString"
require_pattern "tests/mbedtls/test_mbedtls_simple_connection.pas" "GetVerifyResult"
require_pattern "tests/mbedtls/test_mbedtls_lowlevel.pas" "GetVerifyResult"
require_pattern "tests/mbedtls/test_mbedtls_lowlevel.pas" "GetVerifyResultString"
require_pattern "tests/mbedtls/test_mbedtls_cert_chain.pas" "GetVerifyResult"
require_pattern "tests/mbedtls/test_mbedtls_cert_chain.pas" "GetVerifyResultString"
require_pattern "tests/mbedtls/test_mbedtls_cert_errors.pas" "GetVerifyResult"
require_pattern "tests/mbedtls/test_mbedtls_cert_errors.pas" "GetVerifyResultString"
require_pattern "tests/mbedtls/test_mbedtls_cert_verify_flags.pas" "GetVerifyResult"
require_pattern "tests/mbedtls/test_mbedtls_cert_verify_flags.pas" "GetVerifyResultString"

echo "[PASS] MbedTLS verify-result residual cluster stays intentionally frozen"
