#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

base_file="src/nextpas.core.tls.base.pas"
conn_base_file="src/nextpas.core.tls.connection.base.pas"
api_ref="docs/reference/API_REFERENCE.md"
v2_doc="docs/reference/INTERFACE_DESIGN_V2.md"
troubleshooting_doc="docs/guides/TROUBLESHOOTING.md"
example_file="tests/examples/test_certchain.pas"
backend_contract="tests/contract/test_backend_contract.pas"
message_chain="Use ISSLCertificateVerification.GetPeerCertificateChain"

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

count=$(perl -0ne "
  my \$n = () = /function GetPeerCertificateChain\\: TSSLCertificateArray;\\s*deprecated '\\Q$message_chain\\E';/g;
  print \$n;
" "$base_file")

if [[ "$count" != "1" ]]; then
  echo "[FAIL] expected exactly one compiler-deprecated core GetPeerCertificateChain declaration in $base_file"
  echo "       matched declarations: $count"
  exit 1
fi

declare -a required_base_patterns=(
  "@preferred-access 新代码优先通过 ISSLCertificateVerification.GetPeerCertificateChain 获取"
  "@owner-note 当前默认 owner 为 ISSLCertificateVerification；ISSLConnection.GetPeerCertificateChain 保留为 v1.x compatibility mirror"
)

for pattern in "${required_base_patterns[@]}"; do
  if ! grep -F -q -- "$pattern" "$base_file"; then
    echo "[FAIL] base source missing GetPeerCertificateChain owner-surface note: $pattern"
    exit 1
  fi
done

declare -a required_conn_base_patterns=(
  '`GetPeerCertificateChain` 当前共享同一条基类 mirror 实现'
  'ordinary docs/tests 已转向 `ISSLCertificateVerification` owner path'
  'helper fallback、contract mirror proof 和 backend-specific runtime residuals'
)

for pattern in "${required_conn_base_patterns[@]}"; do
  if ! grep -F -q -- "$pattern" "$conn_base_file"; then
    echo "[FAIL] base connection class missing peer-certificate-chain residual note: $pattern"
    exit 1
  fi
done

if ! rg -F -n --quiet "function GetPeerCertificateChain: TSSLCertificateArray; // 编译期 deprecated，仅兼容保留；新代码优先走 ISSLCertificateVerification owner surface" "$api_ref"; then
  echo "[FAIL] API reference no longer records GetPeerCertificateChain as a compiler-deprecated compatibility mirror"
  exit 1
fi

if ! rg -F -n --quiet -- "- \`GetPeerCertificateChain\` / \`GetVerifyResult\` / \`GetVerifyResultString\` 在 \`ISSLConnection\` 上当前也只作为 \`v1.x\` compatibility-core mirror 保留；当前源码声明已经是编译期 \`deprecated\`，需要证书验证链或验证结果时，新代码优先通过 \`ISSLCertificateVerification\` owner surface 访问。" "$api_ref"; then
  echo "[FAIL] API reference compatibility note does not yet record the compiler-deprecated GetPeerCertificateChain owner path"
  exit 1
fi

if ! rg -F -n --quiet "| GetPeerCertificateChain | ISSLCertificateVerification | 默认 owner 已切到 ISSLCertificateVerification；core 侧仅兼容保留，源码声明已是编译期 deprecated |" "$v2_doc"; then
  echo "[FAIL] V2 migration table no longer records the compiler-deprecated GetPeerCertificateChain core surface"
  exit 1
fi

if ! rg -F -n --quiet "其中 \`GetPeerCertificateChain\` 在核心 \`ISSLConnection\` 上当前也只保留为 compatibility mirror，源码声明已经进入编译期 \`deprecated\`；后续仍可再评估是否把这条证书链 surface 进一步完全收窄到 \`ISSLCertificateVerification\`。" "$v2_doc"; then
  echo "[FAIL] V2 migration note no longer records the compiler-deprecated GetPeerCertificateChain fallback"
  exit 1
fi

declare -a required_troubleshooting_patterns=(
  "LCertVerify: ISSLCertificateVerification;"
  "Supports(LConn, ISSLCertificateVerification, LCertVerify)"
  "LChain := LCertVerify.GetPeerCertificateChain;"
)

for pattern in "${required_troubleshooting_patterns[@]}"; do
  if ! grep -F -q -- "$pattern" "$troubleshooting_doc"; then
    echo "[FAIL] troubleshooting guide missing ISSLCertificateVerification-first peer-chain guidance: $pattern"
    exit 1
  fi
done

if rg -n --quiet '\bLConn\.GetPeerCertificateChain\b' "$troubleshooting_doc"; then
  echo "[FAIL] troubleshooting guide still teaches direct core GetPeerCertificateChain"
  rg -n '\bLConn\.GetPeerCertificateChain\b' "$troubleshooting_doc"
  exit 1
fi

declare -a required_example_patterns=(
  "CertVerify: ISSLCertificateVerification;"
  "Supports(Connection, ISSLCertificateVerification, CertVerify)"
  "CertChain := CertVerify.GetPeerCertificateChain;"
)

for pattern in "${required_example_patterns[@]}"; do
  if ! grep -F -q -- "$pattern" "$example_file"; then
    echo "[FAIL] test example missing ISSLCertificateVerification-first peer-chain usage: $pattern"
    exit 1
  fi
done

if rg -n --quiet '\bConnection\.GetPeerCertificateChain\b' "$example_file"; then
  echo "[FAIL] test example still reads direct core GetPeerCertificateChain"
  rg -n '\bConnection\.GetPeerCertificateChain\b' "$example_file"
  exit 1
fi

direct_core_doc_hits="$(rg -lP '\b(?!LCertVerify\b|CertVerify\b)[A-Za-z0-9_\.]+\.GetPeerCertificateChain\b' docs --glob '!docs/archive/**' --glob '!docs/plans/**' --glob '!docs/test_reports/**' | sort || true)"
if [[ -n "$direct_core_doc_hits" ]]; then
  echo "[FAIL] active docs reintroduced direct core peer-certificate-chain usage"
  printf '%s\n' "$direct_core_doc_hits"
  exit 1
fi

test_examples_hits="$(rg -lP '\b(?!LCertVerify\b|CertVerify\b)[A-Za-z0-9_\.]+\.GetPeerCertificateChain\b' tests/examples | sort || true)"
if [[ -n "$test_examples_hits" ]]; then
  echo "[FAIL] tests/examples reintroduced direct core peer-certificate-chain usage"
  printf '%s\n' "$test_examples_hits"
  exit 1
fi

connection_hits="$(rg -lP '\b(?!LCertVerify\b|CertVerify\b)[A-Za-z0-9_\.]+\.GetPeerCertificateChain\b' tests/connection | sort || true)"
compare_file_list "tests/connection direct-core peer-certificate-chain file set" \
  "$connection_hits" \
  "tests/connection/test_wolfssl_client_peer_certificate_surface.pas"

contract_hits="$(rg -lP '\b(?!LCertVerify\b|CertVerify\b)[A-Za-z0-9_\.]+\.GetPeerCertificateChain\b' tests/contract | sort || true)"
compare_file_list "tests/contract direct-core peer-certificate-chain file set" \
  "$contract_hits" \
  "tests/contract/test_backend_contract.pas"

root_test_hits="$(rg -lP '\b(?!LCertVerify\b|CertVerify\b)[A-Za-z0-9_\.]+\.GetPeerCertificateChain\b' tests/*.pas | sort || true)"
compare_file_list "root tests direct-core peer-certificate-chain file set" \
  "$root_test_hits" \
  "$(cat <<'EOF'
tests/test_freepascal_client_peer_certificate_surface.pas
tests/test_mbedtls_connection_peer_certificate_contract.pas
tests/test_openssl_connection_peer_certificate_chain_contract.pas
tests/test_openssl_connection_peer_certificate_surface.pas
EOF
)"

winssl_hits="$(rg -lP '\b(?!LCertVerify\b|CertVerify\b)[A-Za-z0-9_\.]+\.GetPeerCertificateChain\b' tests/winssl | sort || true)"
compare_file_list "tests/winssl direct-core peer-certificate-chain file set" \
  "$winssl_hits" \
  "$(cat <<'EOF'
tests/winssl/test_winssl_connection_info.pas
tests/winssl/test_winssl_peer_certificate_surface.pas
EOF
)"

declare -a suppressed_files=(
  "tests/contract/test_backend_contract.pas"
  "tests/test_openssl_connection_peer_certificate_surface.pas"
  "tests/test_mbedtls_connection_peer_certificate_contract.pas"
  "tests/connection/test_wolfssl_client_peer_certificate_surface.pas"
  "tests/test_openssl_connection_peer_certificate_chain_contract.pas"
  "tests/test_freepascal_client_peer_certificate_surface.pas"
  "tests/winssl/test_winssl_connection_info.pas"
  "tests/winssl/test_winssl_peer_certificate_surface.pas"
)

for file in "${suppressed_files[@]}"; do
  if ! rg -F -n --quiet '{$WARN 6058 off}{$WARN SYMBOL_DEPRECATED OFF}' "$file"; then
    echo "[FAIL] missing GetPeerCertificateChain deprecation warning quarantine in $file"
    exit 1
  fi
done

if ! rg -F -n --quiet "LCoreChain := LConn.GetPeerCertificateChain;" "$backend_contract"; then
  echo "[FAIL] backend contract lost the expected direct core GetPeerCertificateChain mirror proof"
  exit 1
fi

if ! rg -F -n --quiet "LOptionalChain := LCertVerify.GetPeerCertificateChain;" "$backend_contract"; then
  echo "[FAIL] backend contract lost the expected ISSLCertificateVerification peer-chain comparison"
  exit 1
fi

echo "[PASS] GetPeerCertificateChain compiler deprecation is aligned across source, docs, active guidance, and intentional residual proofs"
