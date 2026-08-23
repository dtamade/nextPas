#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"

cd "$PROJECT_ROOT"

base_file="core/src/nextpas.core.tls.base.pas"
conn_base_file="core/src/nextpas.core.tls.connection.base.pas"

declare -a required_base_patterns=(
  "@preferred-access 新代码优先通过 ISSLConnectionInfo.GetContext 获取"
  "@owner-note 当前 context 引用的默认 owner；ISSLConnection.GetContext 保留为 v1.x compatibility mirror"
)

for pattern in "${required_base_patterns[@]}"; do
  if ! grep -F -q -- "$pattern" "$base_file"; then
    echo "[FAIL] base source missing GetContext feasibility note: $pattern"
    exit 1
  fi
done

declare -a required_conn_base_patterns=(
  '`GetContext` 当前通过一条共享基类实现同时服务于 core mirror 和'
  'active docs 已转向 `ISSLConnectionInfo.GetContext`'
  'direct core `GetContext` 只剩 contract mirror proof'
)

for pattern in "${required_conn_base_patterns[@]}"; do
  if ! grep -F -q -- "$pattern" "$conn_base_file"; then
    echo "[FAIL] base connection class missing GetContext feasibility note: $pattern"
    exit 1
  fi
done

if [ "$(grep -F -c 'function GetContext: ISSLContext;' "$base_file")" -ne 2 ]; then
  echo "[FAIL] expected exactly two GetContext declarations in core/src/nextpas.core.tls.base.pas"
  exit 1
fi

if [ "$(grep -F -c 'function TBaseSSLConnection.GetContext: ISSLContext;' "$conn_base_file")" -ne 1 ]; then
  echo "[FAIL] expected exactly one TBaseSSLConnection.GetContext compatibility-mirror implementation"
  exit 1
fi



core_test_hits=$(( $( (rg -n '\bLConn\.GetContext\b' core/tests/nextpas.core.tls --glob '!**/scripts/**' || true) | wc -l | tr -d ' ' ) ))
if [ "$core_test_hits" -ne 0 ]; then
  echo "[FAIL] expected exactly one non-script direct core LConn.GetContext test hit, found $core_test_hits (legacy mirror file retired)"
  rg -n '\bLConn\.GetContext\b' core/tests/nextpas.core.tls --glob '!**/scripts/**' || true
  exit 1
fi

src_core_call_hits=$(( $( (rg -n '(:=|,|\()\s*[A-Za-z0-9_]+\.GetContext\b' src || true) | wc -l | tr -d ' ' ) ))
if [ "$src_core_call_hits" -ne 0 ]; then
  echo "[FAIL] production source unexpectedly contains direct GetContext call dependencies"
  rg -n '(:=|,|\()\s*[A-Za-z0-9_]+\.GetContext\b' src || true
  exit 1
fi

echo "[PASS] GetContext live surface is frozen to the expected source/class split allowlist"
