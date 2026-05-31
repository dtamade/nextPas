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

expected_hits="$(cat <<'EOF'
tests/winssl/test_winssl_error_mapping_online.pas
tests/winssl/test_winssl_hostname_mismatch_online.pas
tests/winssl/test_winssl_revocation_online.pas
EOF
)"

actual_hits="$(rg -lP '\b(?:Conn|LConn|LConnection)\.GetVerifyResult(?:String)?\b' tests/winssl | sort || true)"
compare_file_list "WinSSL runtime direct-core verify-result file set" "$actual_hits" "$expected_hits"

declare -a residual_files=(
  "tests/winssl/test_winssl_error_mapping_online.pas"
  "tests/winssl/test_winssl_hostname_mismatch_online.pas"
  "tests/winssl/test_winssl_revocation_online.pas"
)

declare -a required_comment_patterns=(
  "INTENTIONAL_VERIFY_RESULT_CORE_SURFACE: keep this direct core"
  "certificate-error proof. The ISSLCertificateVerification owner-path"
  "coverage is frozen by generic/contract guidance checks elsewhere."
)

for file in "${residual_files[@]}"; do
  for pattern in "${required_comment_patterns[@]}"; do
    if ! grep -F -q -- "$pattern" "$file"; then
      echo "[FAIL] WinSSL runtime residual file missing intentional core-surface note: $file :: $pattern"
      exit 1
    fi
  done

  if ! grep -F -q -- "GetVerifyResult;" "$file"; then
    echo "[FAIL] WinSSL runtime residual file no longer exercises GetVerifyResult: $file"
    exit 1
  fi

  if ! grep -F -q -- "GetVerifyResultString;" "$file"; then
    echo "[FAIL] WinSSL runtime residual file no longer exercises GetVerifyResultString: $file"
    exit 1
  fi
done

echo "[PASS] WinSSL verify-result runtime residual trio stays intentionally frozen"
