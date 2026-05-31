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
tests/openssl/test_openssl_server_ocsp_stapling_runtime.pas
tests/wolfssl/test_wolfssl_server_ocsp_stapling_runtime.pas
EOF
)"

actual_hits="$(rg -lP '\b(?:Conn|LConn|LConnection)\.GetVerifyResult(?:String)?\b' tests/openssl tests/wolfssl | sort || true)"
compare_file_list "OpenSSL/WolfSSL OCSP runtime verify-result residual file set" "$actual_hits" "$expected_hits"

declare -a residual_files=(
  "tests/openssl/test_openssl_server_ocsp_stapling_runtime.pas"
  "tests/wolfssl/test_wolfssl_server_ocsp_stapling_runtime.pas"
)

declare -a required_comment_patterns=(
  "INTENTIONAL_VERIFY_RESULT_CORE_SURFACE: this backend-specific"
  "OCSP stapling runtime file intentionally keeps direct core"
  "Generic ISSLCertificateVerification"
  "owner-path guidance is frozen elsewhere."
)

for file in "${residual_files[@]}"; do
  for pattern in "${required_comment_patterns[@]}"; do
    require_pattern "$file" "$pattern"
  done
done

require_pattern "tests/openssl/test_openssl_server_ocsp_stapling_runtime.pas" "GetVerifyResultString"
require_pattern "tests/wolfssl/test_wolfssl_server_ocsp_stapling_runtime.pas" "GetVerifyResult"
require_pattern "tests/wolfssl/test_wolfssl_server_ocsp_stapling_runtime.pas" "GetVerifyResultString"

echo "[PASS] OpenSSL/WolfSSL OCSP runtime verify-result duo stays intentionally frozen"
