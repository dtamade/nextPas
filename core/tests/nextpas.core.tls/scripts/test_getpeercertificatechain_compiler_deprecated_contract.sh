#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"

cd "$PROJECT_ROOT"

base_file="core/src/nextpas.core.tls.base.pas"
conn_base_file="core/src/nextpas.core.tls.connection.base.pas"
example_file="core/tests/nextpas.core.tls/examples/test_certchain.pas"
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
  'helper fallback、contract mirror proof 和 backend-specific runtime residuals'
)

for pattern in "${required_conn_base_patterns[@]}"; do
  if ! grep -F -q -- "$pattern" "$conn_base_file"; then
    echo "[FAIL] base connection class missing peer-certificate-chain residual note: $pattern"
    exit 1
  fi
done





declare -a required_troubleshooting_patterns=(
  "LCertVerify: ISSLCertificateVerification;"
  "Supports(LConn, ISSLCertificateVerification, LCertVerify)"
  "LChain := LCertVerify.GetPeerCertificateChain;"
)



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


test_examples_hits="$(rg -lP '\b(?!LCertVerify\b|CertVerify\b)[A-Za-z0-9_\.]+\.GetPeerCertificateChain\b' core/tests/nextpas.core.tls/examples | sort || true)"
if [[ -n "$test_examples_hits" ]]; then
  echo "[FAIL] core/tests/nextpas.core.tls/examples reintroduced direct core peer-certificate-chain usage"
  printf '%s\n' "$test_examples_hits"
  exit 1
fi

connection_hits="$(rg -lP '\b(?!LCertVerify\b|CertVerify\b)[A-Za-z0-9_\.]+\.GetPeerCertificateChain\b' core/tests/nextpas.core.tls/connection | sort || true)"
compare_file_list "tests/connection direct-core peer-certificate-chain file set" \
  "$connection_hits" \
  "core/tests/nextpas.core.tls/connection/test_wolfssl_client_peer_certificate_surface.pas"

root_test_hits="$(rg -lP '\b(?!LCertVerify\b|CertVerify\b)[A-Za-z0-9_\.]+\.GetPeerCertificateChain\b' core/tests/nextpas.core.tls/*.pas | sort || true)"
compare_file_list "root tests direct-core peer-certificate-chain file set" \
  "$root_test_hits" \
  "$(cat <<'EOF'
core/tests/nextpas.core.tls/test_freepascal_client_peer_certificate_surface.pas
core/tests/nextpas.core.tls/test_mbedtls_connection_peer_certificate_contract.pas
core/tests/nextpas.core.tls/test_openssl_connection_peer_certificate_chain_contract.pas
core/tests/nextpas.core.tls/test_openssl_connection_peer_certificate_surface.pas
EOF
)"

winssl_hits="$(rg -lP '\b(?!LCertVerify\b|CertVerify\b)[A-Za-z0-9_\.]+\.GetPeerCertificateChain\b' core/tests/nextpas.core.tls/winssl | sort || true)"
compare_file_list "core/tests/nextpas.core.tls/winssl direct-core peer-certificate-chain file set" \
  "$winssl_hits" \
  "$(cat <<'EOF'
core/tests/nextpas.core.tls/winssl/test_winssl_connection_info.pas
core/tests/nextpas.core.tls/winssl/test_winssl_peer_certificate_surface.pas
EOF
)"

declare -a suppressed_files=(
  "core/tests/nextpas.core.tls/test_openssl_connection_peer_certificate_surface.pas"
  "core/tests/nextpas.core.tls/test_mbedtls_connection_peer_certificate_contract.pas"
  "core/tests/nextpas.core.tls/connection/test_wolfssl_client_peer_certificate_surface.pas"
  "core/tests/nextpas.core.tls/test_openssl_connection_peer_certificate_chain_contract.pas"
  "core/tests/nextpas.core.tls/test_freepascal_client_peer_certificate_surface.pas"
  "core/tests/nextpas.core.tls/winssl/test_winssl_connection_info.pas"
  "core/tests/nextpas.core.tls/winssl/test_winssl_peer_certificate_surface.pas"
)

for file in "${suppressed_files[@]}"; do
  if ! rg -F -n --quiet '{$WARN 6058 off}{$WARN SYMBOL_DEPRECATED OFF}' "$file"; then
    echo "[FAIL] missing GetPeerCertificateChain deprecation warning quarantine in $file"
    exit 1
  fi
done


echo "[PASS] GetPeerCertificateChain compiler deprecation is aligned across source, docs, active guidance, and intentional residual proofs"
