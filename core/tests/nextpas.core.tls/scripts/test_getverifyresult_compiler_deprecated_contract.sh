#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

base_file="src/nextpas.core.tls.base.pas"
api_ref="docs/reference/API_REFERENCE.md"
v2_doc="docs/reference/INTERFACE_DESIGN_V2.md"
message_result="Use ISSLCertificateVerification.GetVerifyResult"
message_result_string="Use ISSLCertificateVerification.GetVerifyResultString"

count=$(perl -0ne "
  my \$n = () = /function GetVerifyResult\\: Integer;\\s*deprecated '\\Q$message_result\\E';/g;
  print \$n;
" "$base_file")

if [[ "$count" != "1" ]]; then
  echo "[FAIL] expected exactly one compiler-deprecated core GetVerifyResult declaration in $base_file"
  echo "       matched declarations: $count"
  exit 1
fi

count=$(perl -0ne "
  my \$n = () = /function GetVerifyResultString\\: string;\\s*deprecated '\\Q$message_result_string\\E';/g;
  print \$n;
" "$base_file")

if [[ "$count" != "1" ]]; then
  echo "[FAIL] expected exactly one compiler-deprecated core GetVerifyResultString declaration in $base_file"
  echo "       matched declarations: $count"
  exit 1
fi

if ! rg -F -n --quiet "function GetVerifyResult: Integer; // 编译期 deprecated，仅兼容保留；新代码优先走 ISSLCertificateVerification owner surface" "$api_ref"; then
  echo "[FAIL] API reference no longer records GetVerifyResult as a compiler-deprecated compatibility mirror"
  exit 1
fi

if ! rg -F -n --quiet "function GetVerifyResultString: string; // 编译期 deprecated，仅兼容保留；新代码优先走 ISSLCertificateVerification owner surface" "$api_ref"; then
  echo "[FAIL] API reference no longer records GetVerifyResultString as a compiler-deprecated compatibility mirror"
  exit 1
fi

if ! rg -F -n --quiet "| GetVerifyResult, GetVerifyResultString | ISSLCertificateVerification | 默认 owner 已切到 ISSLCertificateVerification；core 侧仅兼容保留，源码声明已是编译期 deprecated |" "$v2_doc"; then
  echo "[FAIL] V2 migration table no longer records the compiler-deprecated verify-result core surface"
  exit 1
fi

if ! rg -F -n --quiet "其中 \`GetVerifyResult\` / \`GetVerifyResultString\` 在核心 \`ISSLConnection\` 上当前也只保留为 compatibility mirror，源码声明已经进入编译期 \`deprecated\`；后续仍可再评估是否把这组结果 surface 进一步完全收窄到 \`ISSLCertificateVerification\`。" "$v2_doc"; then
  echo "[FAIL] V2 migration note no longer records the compiler-deprecated verify-result fallback"
  exit 1
fi

declare -a suppressed_files=(
  "src/nextpas.core.tls.connection.builder.pas"
  "src/nextpas.core.tls.tls.pas"
  "examples/fafafa.examples.tcp.pas"
  "tests/connection/test_ssl_client_connection.pas"
  "tests/contract/test_backend_contract.pas"
  "tests/mbedtls/benchmark_handshake_simple.pas"
  "tests/mbedtls/test_mbedtls_cert_chain.pas"
  "tests/mbedtls/test_mbedtls_cert_errors.pas"
  "tests/mbedtls/test_mbedtls_cert_verify_flags.pas"
  "tests/mbedtls/test_mbedtls_lowlevel.pas"
  "tests/mbedtls/test_mbedtls_safe.pas"
  "tests/mbedtls/test_mbedtls_simple_connection.pas"
  "tests/openssl/test_openssl_server_ocsp_stapling_runtime.pas"
  "tests/test_openssl_connection_verify_result_contract.pas"
  "tests/test_wolfssl_framework.pas"
  "tests/winssl/test_winssl_error_mapping_online.pas"
  "tests/winssl/test_winssl_hostname_mismatch_online.pas"
  "tests/winssl/test_winssl_revocation_online.pas"
  "tests/wolfssl/test_wolfssl_server_ocsp_stapling_runtime.pas"
)

for file in "${suppressed_files[@]}"; do
  if ! rg -F -n --quiet '{$WARN 6058 off}{$WARN SYMBOL_DEPRECATED OFF}' "$file"; then
    echo "[FAIL] missing verify-result deprecation warning quarantine in $file"
    exit 1
  fi
done

if ! rg -F -n --quiet "LCertVerify.GetVerifyResult <> LConn.GetVerifyResult" "tests/contract/test_backend_contract.pas"; then
  echo "[FAIL] backend contract lost the expected direct GetVerifyResult mirror proof"
  exit 1
fi

if ! rg -F -n --quiet "LCertVerify.GetVerifyResultString <> LConn.GetVerifyResultString" "tests/contract/test_backend_contract.pas"; then
  echo "[FAIL] backend contract lost the expected direct GetVerifyResultString mirror proof"
  exit 1
fi

echo "[PASS] GetVerifyResult compiler deprecation is aligned across source, docs, and intentional residual proofs"
