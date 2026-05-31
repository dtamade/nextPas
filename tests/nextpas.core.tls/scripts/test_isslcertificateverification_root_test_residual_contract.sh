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
tests/test_openssl_connection_verify_result_contract.pas
tests/test_wolfssl_framework.pas
EOF
)"

actual_hits="$(rg -lP '\b(?!LCertVerify\b|CertVerify\b)[A-Za-z0-9_\.]+\.GetVerifyResult(?:String)?\b' tests/*.pas | sort || true)"
compare_file_list "root-test direct-core verify-result residual file set" "$actual_hits" "$expected_hits"

declare -a residual_files=(
  "tests/test_openssl_connection_verify_result_contract.pas"
  "tests/test_wolfssl_framework.pas"
)

declare -a required_comment_patterns=(
  "INTENTIONAL_VERIFY_RESULT_CORE_SURFACE:"
  "intentionally keeps direct core"
  "Generic ISSLCertificateVerification"
  "owner-path"
  "guidance is frozen elsewhere."
)

for file in "${residual_files[@]}"; do
  for pattern in "${required_comment_patterns[@]}"; do
    require_pattern "$file" "$pattern"
  done
done

require_pattern "tests/test_openssl_connection_verify_result_contract.pas" "GetVerifyResult"
require_pattern "tests/test_openssl_connection_verify_result_contract.pas" "GetVerifyResultString"
require_pattern "tests/test_wolfssl_framework.pas" "GetVerifyResult"
require_pattern "tests/test_wolfssl_framework.pas" "GetVerifyResultString"

echo "[PASS] root-test verify-result residual subgroup stays intentionally frozen"
