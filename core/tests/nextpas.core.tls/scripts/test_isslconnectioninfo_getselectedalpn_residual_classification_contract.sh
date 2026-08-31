#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"

cd "$PROJECT_ROOT"

base_file="core/src/nextpas.core.tls.base.pas"
conn_base_file="core/src/nextpas.core.tls.connection.base.pas"

declare -a required_base_patterns=(
  "@preferred-access 新代码优先通过 ISSLConnectionInfo.GetSelectedALPNProtocol 获取"
  "@owner-note 当前 ALPN 协商结果的默认 owner；ISSLConnection.GetSelectedALPNProtocol 保留为 v1.x compatibility mirror"
)

for pattern in "${required_base_patterns[@]}"; do
  if ! grep -F -q -- "$pattern" "$base_file"; then
    echo "[FAIL] base source missing GetSelectedALPNProtocol residual note: $pattern"
    exit 1
  fi
done

declare -a required_conn_base_patterns=(
  '`GetSelectedALPNProtocol` 当前通过一条共享基类实现同时服务于 core mirror 和'
  '`ISSLConnectionInfo.GetSelectedALPNProtocol`，direct core'
  '`GetSelectedALPNProtocol` 当前只剩 contract mirror proof 和 backend-specific runtime residuals'
)

for pattern in "${required_conn_base_patterns[@]}"; do
  if ! grep -F -q -- "$pattern" "$conn_base_file"; then
    echo "[FAIL] base connection class missing GetSelectedALPNProtocol residual note: $pattern"
    exit 1
  fi
done



if grep -F -q -- "Conn.GetSelectedALPNProtocol" "core/tests/nextpas.core.tls/integration/test_real_https_connection.pas"; then
  echo "[FAIL] real HTTPS integration test reintroduced direct core GetSelectedALPNProtocol"
  exit 1
fi

if grep -F -q -- "Conn.GetSelectedALPNProtocol" "core/tests/nextpas.core.tls/integration/test_cross_backend_consistency_contract.pas"; then
  echo "[FAIL] cross-backend consistency contract reintroduced direct core GetSelectedALPNProtocol"
  exit 1
fi

direct_core_hits=$(rg -n '\b(?:Conn|LConn|LConnection)\.GetSelectedALPNProtocol\b' core/tests/nextpas.core.tls --glob '!**/scripts/**' | wc -l | tr -d ' ')
if [ "$direct_core_hits" -ne 6 ]; then
  echo "[FAIL] expected exactly 6 direct core GetSelectedALPNProtocol test hits, found $direct_core_hits"
  rg -n '\b(?:Conn|LConn|LConnection)\.GetSelectedALPNProtocol\b' core/tests/nextpas.core.tls --glob '!**/scripts/**' || true
  exit 1
fi

for expected in \
  "core/tests/nextpas.core.tls/mbedtls/test_mbedtls_alpn.pas" \
  "core/tests/nextpas.core.tls/winssl/test_winssl_alpn_sni.pas" \
  "core/tests/nextpas.core.tls/winssl/test_winssl_connection_edge_cases.pas" \
  "core/tests/nextpas.core.tls/unit/test_freepascal_connection_info.pas"; do
  if ! rg -F -q -- "$expected" <(rg -n '\b(?:Conn|LConn|LConnection)\.GetSelectedALPNProtocol\b' core/tests/nextpas.core.tls --glob '!**/scripts/**'); then
    echo "[FAIL] missing expected direct core GetSelectedALPNProtocol residual file: $expected"
    exit 1
  fi
done

echo "[PASS] GetSelectedALPNProtocol residual direct-core surface matches the expected allowlist"
