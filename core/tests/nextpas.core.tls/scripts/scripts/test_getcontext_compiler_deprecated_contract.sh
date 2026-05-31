#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

base_file="src/nextpas.core.tls.base.pas"
api_ref="docs/reference/API_REFERENCE.md"
v2_doc="docs/reference/INTERFACE_DESIGN_V2.md"
backend_contract="tests/contract/test_backend_contract.pas"
message="Use ISSLConnectionInfo.GetContext"

count=$(perl -0ne "
  my \$n = () = /function GetContext\\: ISSLContext;\\s*deprecated '\\Q$message\\E';/g;
  print \$n;
" "$base_file")

if [[ "$count" != "1" ]]; then
  echo "[FAIL] expected exactly one compiler-deprecated core GetContext declaration in $base_file"
  echo "       matched declarations: $count"
  exit 1
fi

if ! rg -F -n --quiet "function GetContext: ISSLContext; // 编译期 deprecated，仅兼容保留；新代码优先走 ISSLConnectionInfo.GetContext" "$api_ref"; then
  echo "[FAIL] API reference no longer records GetContext as a compiler-deprecated compatibility mirror"
  exit 1
fi

if ! rg -F -n --quiet "| GetContext | ISSLConnectionInfo | 默认 owner 已切到 ISSLConnectionInfo；core 侧仅兼容保留，源码声明已是编译期 deprecated |" "$v2_doc"; then
  echo "[FAIL] V2 migration table no longer records the compiler-deprecated core GetContext surface"
  exit 1
fi

if ! rg -F -n --quiet "其中 \`GetContext\` 在核心 \`ISSLConnection\` 上当前也只保留为 compatibility mirror，源码声明已经进入编译期 \`deprecated\`。" "$v2_doc"; then
  echo "[FAIL] V2 migration note no longer records the compiler-deprecated GetContext fallback"
  exit 1
fi

if ! rg -F -n --quiet '{$PUSH}{$WARN 6058 off}{$WARN SYMBOL_DEPRECATED OFF}' "$backend_contract"; then
  echo "[FAIL] backend contract no longer suppresses the intentional direct GetContext deprecation warning"
  exit 1
fi

if ! rg -F -n --quiet "LCoreCtx := LConn.GetContext;" "$backend_contract"; then
  echo "[FAIL] backend contract lost the expected direct GetContext mirror proof"
  exit 1
fi

echo "[PASS] GetContext compiler deprecation is aligned across source, docs, and residual mirror proof"
