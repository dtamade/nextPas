#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

base_file="src/nextpas.core.tls.base.pas"
conn_base_file="src/nextpas.core.tls.connection.base.pas"

declare -a required_base_patterns=(
  "@preferred-access 新代码优先通过 ISSLConnectionInfo.GetConnectionInfo 获取"
  "@owner-note 当前连接信息记录的默认 owner；ISSLConnection.GetConnectionInfo 保留为 v1.x compatibility mirror"
)

for pattern in "${required_base_patterns[@]}"; do
  if ! grep -F -q -- "$pattern" "$base_file"; then
    echo "[FAIL] base source missing GetConnectionInfo residual note: $pattern"
    exit 1
  fi
done

declare -a required_conn_base_patterns=(
  '`GetConnectionInfo` 当前通过一条共享基类实现同时服务于 core mirror 和'
  '`ISSLConnectionInfo` owner；active docs/tests 已转向'
  '`ISSLConnectionInfo.GetConnectionInfo`，direct core'
  '`GetConnectionInfo` 当前只剩 contract mirror proof 和 backend-specific runtime/contract residuals'
)

for pattern in "${required_conn_base_patterns[@]}"; do
  if ! grep -F -q -- "$pattern" "$conn_base_file"; then
    echo "[FAIL] base connection class missing GetConnectionInfo residual note: $pattern"
    exit 1
  fi
done

if ! grep -F -q -- "LInfo := LConnInfoAccess.GetConnectionInfo;" "docs/reference/API_REFERENCE.md"; then
  echo "[FAIL] API reference no longer shows the expected ISSLConnectionInfo.GetConnectionInfo path"
  exit 1
fi

if grep -F -q -- "Conn.GetConnectionInfo" "tests/integration/test_real_https_connection.pas"; then
  echo "[FAIL] real HTTPS integration test reintroduced direct core GetConnectionInfo"
  exit 1
fi

if grep -F -q -- "Conn.GetConnectionInfo" "tests/integration/test_cross_backend_consistency_contract.pas"; then
  echo "[FAIL] cross-backend consistency contract reintroduced direct core GetConnectionInfo"
  exit 1
fi

direct_core_hits=$(rg -n '\b(?:Conn|LConn|LConnection)\.GetConnectionInfo\b' tests --glob '!tests/scripts/**' | wc -l | tr -d ' ')
if [ "$direct_core_hits" -ne 5 ]; then
  echo "[FAIL] expected exactly 5 direct core GetConnectionInfo test hits, found $direct_core_hits"
  rg -n '\b(?:Conn|LConn|LConnection)\.GetConnectionInfo\b' tests --glob '!tests/scripts/**' || true
  exit 1
fi

for expected in \
  "tests/contract/test_backend_contract.pas" \
  "tests/winssl/test_winssl_connection_info.pas" \
  "tests/winssl/test_winssl_connection_edge_cases.pas"; do
  if ! rg -F -q -- "$expected" <(rg -n '\b(?:Conn|LConn|LConnection)\.GetConnectionInfo\b' tests --glob '!tests/scripts/**'); then
    echo "[FAIL] missing expected direct core GetConnectionInfo residual file: $expected"
    exit 1
  fi
done

for forbidden in \
  "tests/test_connection_builder_hostname_precedence.pas" \
  "tests/test_openssl_connection_info_cipher_contract.pas" \
  "tests/test_wolfssl_connection_info_macsize_contract.pas" \
  "tests/test_mbedtls_connection_info_ciphersuite_contract.pas" \
  "tests/test_freepascal_server_accept_skeleton.pas" \
  "tests/test_freepascal_client_session_resumption.pas"; do
  if rg -F -q -- "$forbidden" <(rg -n '\b(?:Conn|LConn|LConnection)\.GetConnectionInfo\b' tests --glob '!tests/scripts/**'); then
    echo "[FAIL] direct core GetConnectionInfo residual surface was re-expanded: $forbidden"
    exit 1
  fi
done

echo "[PASS] GetConnectionInfo residual direct-core surface matches the expected allowlist"
