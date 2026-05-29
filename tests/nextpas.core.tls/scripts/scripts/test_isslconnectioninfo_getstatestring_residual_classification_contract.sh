#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

base_file="src/nextpas.core.tls.base.pas"
conn_base_file="src/nextpas.core.tls.connection.base.pas"

declare -a required_base_patterns=(
  "@preferred-access 新代码优先通过 ISSLConnectionInfo.GetStateString 获取"
  "@owner-note 当前状态描述字符串的默认 owner；ISSLConnection.GetStateString 保留为 v1.x compatibility mirror"
)

for pattern in "${required_base_patterns[@]}"; do
  if ! grep -F -q -- "$pattern" "$base_file"; then
    echo "[FAIL] base source missing GetStateString residual note: $pattern"
    exit 1
  fi
done

declare -a required_conn_base_patterns=(
  '`GetStateString` 当前共享同一条基类实现'
  'ordinary docs/tests 已转向'
  '`ISSLConnectionInfo.GetStateString`，direct core `GetStateString` 当前只剩'
  'contract mirror proof 和 backend-specific runtime residuals'
)

for pattern in "${required_conn_base_patterns[@]}"; do
  if ! grep -F -q -- "$pattern" "$conn_base_file"; then
    echo "[FAIL] base connection class missing GetStateString residual note: $pattern"
    exit 1
  fi
done

if ! grep -F -q -- "WriteLn('状态: ', LConnInfoAccess.GetStateString);" "docs/reference/API_REFERENCE.md"; then
  echo "[FAIL] API reference no longer shows the expected ISSLConnectionInfo.GetStateString path"
  exit 1
fi

if ! grep -F -q -- "ConnInfo.GetStateString" "docs/INTEGRATION_GUIDE.md"; then
  echo "[FAIL] integration guide no longer shows the expected ISSLConnectionInfo.GetStateString path"
  exit 1
fi

if grep -F -q -- "LConnection.GetStateString" "tests/connection/test_connection_basic.pas"; then
  echo "[FAIL] generic connection smoke test reintroduced direct core GetStateString"
  exit 1
fi

if grep -F -q -- "Conn.GetStateString" "tests/integration/test_real_https_connection.pas"; then
  echo "[FAIL] real HTTPS integration test reintroduced direct core GetStateString"
  exit 1
fi

direct_core_hits=$(rg -n '\b(?:Conn|LConn|LConnection)\.GetStateString\b' tests --glob '!tests/scripts/**' | wc -l | tr -d ' ')
if [ "$direct_core_hits" -ne 9 ]; then
  echo "[FAIL] expected exactly 9 direct core GetStateString test hits, found $direct_core_hits"
  rg -n '\b(?:Conn|LConn|LConnection)\.GetStateString\b' tests --glob '!tests/scripts/**' || true
  exit 1
fi

for expected in \
  "tests/contract/test_backend_contract.pas" \
  "tests/openssl/test_openssl_server_ocsp_stapling_runtime.pas" \
  "tests/wolfssl/test_wolfssl_server_ocsp_stapling_runtime.pas"; do
  if ! rg -F -q -- "$expected" <(rg -n '\b(?:Conn|LConn|LConnection)\.GetStateString\b' tests --glob '!tests/scripts/**'); then
    echo "[FAIL] missing expected direct core GetStateString residual file: $expected"
    exit 1
  fi
done

echo "[PASS] GetStateString residual direct-core surface matches the expected allowlist"
