#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

base_file="src/nextpas.core.tls.base.pas"
conn_base_file="src/nextpas.core.tls.connection.base.pas"

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

declare -a required_base_patterns=(
  "@preferred-access 新代码优先通过 ISSLCertificateVerification.GetVerifyResult 获取"
  "@owner-note 当前默认 owner 为 ISSLCertificateVerification；ISSLConnection.GetVerifyResult 保留为 v1.x compatibility mirror"
  "@preferred-access 新代码优先通过 ISSLCertificateVerification.GetVerifyResultString 获取"
  "@owner-note 当前默认 owner 为 ISSLCertificateVerification；ISSLConnection.GetVerifyResultString 保留为 v1.x compatibility mirror"
)

for pattern in "${required_base_patterns[@]}"; do
  if ! grep -F -q -- "$pattern" "$base_file"; then
    echo "[FAIL] base source missing certificate-verification residual note: $pattern"
    exit 1
  fi
done

declare -a required_conn_base_patterns=(
  '`GetVerifyResult` / `GetVerifyResultString` 当前共享同一条基类 mirror 实现'
  'ordinary docs/tests 已转向'
  '`ISSLCertificateVerification` owner path'
  'helper fallback、contract mirror proof 和 backend-specific runtime residuals'
)

for pattern in "${required_conn_base_patterns[@]}"; do
  if ! grep -F -q -- "$pattern" "$conn_base_file"; then
    echo "[FAIL] base connection class missing certificate-verification residual note: $pattern"
    exit 1
  fi
done

declare -a required_owner_doc_patterns=(
  "CertVerify.GetVerifyResultString"
  'CertVerify.GetVerifyResult` / `CertVerify.GetVerifyResultString'
  '`GetPeerCertificateChain` / `GetVerifyResult` / `GetVerifyResultString` 也由 `ISSLCertificateVerification` 暴露。'
)

if ! grep -F -q -- "CertVerify.GetVerifyResultString" "docs/guides/OCSP_USAGE_GUIDE.md"; then
  echo "[FAIL] OCSP guide no longer shows the expected ISSLCertificateVerification path"
  exit 1
fi

if ! grep -F -q -- "CertVerify.GetVerifyResultString" "docs/guides/CT_IMPLEMENTATION_GUIDE.md"; then
  echo "[FAIL] CT guide no longer shows the expected ISSLCertificateVerification path"
  exit 1
fi

if ! grep -F -q -- "CertVerify.GetVerifyResultString" "docs/reference/API_DOCUMENTATION.md"; then
  echo "[FAIL] API documentation no longer shows the expected ISSLCertificateVerification path"
  exit 1
fi

for pattern in "${required_owner_doc_patterns[@]}"; do
  if ! grep -F -q -- "$pattern" "docs/INTEGRATION_GUIDE.md" && ! grep -F -q -- "$pattern" "docs/reference/API_REFERENCE.md"; then
    echo "[FAIL] active docs missing expected ISSLCertificateVerification owner-path wording: $pattern"
    exit 1
  fi
done

direct_core_doc_hits="$(rg -lP '\b(?!LCertVerify\b|CertVerify\b)[A-Za-z0-9_\.]+\.GetVerifyResult(?:String)?\b' docs --glob '!docs/archive/**' --glob '!docs/plans/**' --glob '!docs/test_reports/**' | sort || true)"
if [[ -n "$direct_core_doc_hits" ]]; then
  echo "[FAIL] active docs reintroduced direct core certificate-verification getter usage"
  printf '%s\n' "$direct_core_doc_hits"
  exit 1
fi

examples_hits="$(rg -lP '\b(?!LCertVerify\b|CertVerify\b)[A-Za-z0-9_\.]+\.GetVerifyResult(?:String)?\b' examples | sort || true)"
compare_file_list "examples direct-core verify-result file set" \
  "$examples_hits" \
  "examples/fafafa.examples.tcp.pas"

test_examples_hits="$(rg -lP '\b(?!LCertVerify\b|CertVerify\b)[A-Za-z0-9_\.]+\.GetVerifyResult(?:String)?\b' tests/examples | sort || true)"
if [[ -n "$test_examples_hits" ]]; then
  echo "[FAIL] tests/examples reintroduced direct core certificate-verification getter usage"
  printf '%s\n' "$test_examples_hits"
  exit 1
fi

connection_hits="$(rg -lP '\b(?!LCertVerify\b|CertVerify\b)[A-Za-z0-9_\.]+\.GetVerifyResult(?:String)?\b' tests/connection | sort || true)"
compare_file_list "tests/connection direct-core verify-result file set" \
  "$connection_hits" \
  "tests/connection/test_ssl_client_connection.pas"

contract_hits="$(rg -lP '\b(?!LCertVerify\b|CertVerify\b)[A-Za-z0-9_\.]+\.GetVerifyResult(?:String)?\b' tests/contract | sort || true)"
compare_file_list "tests/contract direct-core verify-result file set" \
  "$contract_hits" \
  "tests/contract/test_backend_contract.pas"

backend_specific_hits="$(rg -lP '\b(?!LCertVerify\b|CertVerify\b)[A-Za-z0-9_\.]+\.GetVerifyResult(?:String)?\b' tests/mbedtls tests/winssl tests/wolfssl tests/openssl | sort || true)"
compare_file_list "backend-specific runtime direct-core verify-result file set" \
  "$backend_specific_hits" \
  "$(cat <<'EOF'
tests/mbedtls/benchmark_handshake_simple.pas
tests/mbedtls/test_mbedtls_cert_chain.pas
tests/mbedtls/test_mbedtls_cert_errors.pas
tests/mbedtls/test_mbedtls_cert_verify_flags.pas
tests/mbedtls/test_mbedtls_lowlevel.pas
tests/mbedtls/test_mbedtls_safe.pas
tests/mbedtls/test_mbedtls_simple_connection.pas
tests/openssl/test_openssl_server_ocsp_stapling_runtime.pas
tests/winssl/test_winssl_error_mapping_online.pas
tests/winssl/test_winssl_hostname_mismatch_online.pas
tests/winssl/test_winssl_revocation_online.pas
tests/wolfssl/test_wolfssl_server_ocsp_stapling_runtime.pas
EOF
)"

root_test_hits="$(rg -lP '\b(?!LCertVerify\b|CertVerify\b)[A-Za-z0-9_\.]+\.GetVerifyResult(?:String)?\b' tests/*.pas | sort || true)"
compare_file_list "root tests direct-core verify-result file set" \
  "$root_test_hits" \
  "$(cat <<'EOF'
tests/test_openssl_connection_verify_result_contract.pas
tests/test_wolfssl_framework.pas
EOF
)"

src_hits="$(rg -lP '\b(?!LCertVerify\b|CertVerify\b)[A-Za-z0-9_\.]+\.GetVerifyResult(?:String)?\b' src | sort || true)"
compare_file_list "src direct-core verify-result file set" \
  "$src_hits" \
  "$(cat <<'EOF'
src/nextpas.core.tls.base.pas
src/nextpas.core.tls.connection.base.pas
src/nextpas.core.tls.connection.builder.pas
src/nextpas.core.tls.tls.pas
src/nextpas.core.tls.winssl.context.pas
EOF
)"

echo "[PASS] certificate-verification residual direct-core surface matches the expected allowlist"
