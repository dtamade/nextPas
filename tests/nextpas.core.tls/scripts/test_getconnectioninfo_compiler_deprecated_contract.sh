#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

target="src/nextpas.core.tls.base.pas"
message="Use ISSLConnectionInfo.GetConnectionInfo"

count=$(perl -0ne "
  my \$n = () = /function GetConnectionInfo\\: TSSLConnectionInfo;\\s*deprecated '\\Q$message\\E';/g;
  print \$n;
" "$target")

if [[ "$count" != "1" ]]; then
  echo "[FAIL] expected exactly one compiler-deprecated core GetConnectionInfo declaration in $target"
  echo "       matched declarations: $count"
  exit 1
fi

if ! rg -F -n --quiet "function GetConnectionInfo: TSSLConnectionInfo; // 编译期 deprecated，仅兼容保留；新代码优先走 ISSLConnectionInfo.GetConnectionInfo" docs/reference/API_REFERENCE.md; then
  echo "[FAIL] API reference no longer records GetConnectionInfo as a compiler-deprecated compatibility mirror"
  exit 1
fi

if ! rg -F -n --quiet "LConn.GetConnectionInfo;  // 仅兼容保留，源码声明已是编译期 deprecated" docs/reference/INTERFACE_DESIGN_V2.md; then
  echo "[FAIL] V2 migration doc no longer records the compiler-deprecated GetConnectionInfo fallback"
  exit 1
fi

if ! rg -F -n --quiet "| GetConnectionInfo | ISSLConnectionInfo | 默认 owner 已切到 ISSLConnectionInfo；core 侧仅兼容保留，源码声明已是编译期 deprecated |" docs/reference/INTERFACE_DESIGN_V2.md; then
  echo "[FAIL] V2 migration table no longer records the compiler-deprecated core GetConnectionInfo surface"
  exit 1
fi

declare -A expected_suppression_counts=(
  ["tests/contract/test_backend_contract.pas"]=2
  ["tests/winssl/test_winssl_connection_info.pas"]=2
  ["tests/winssl/test_winssl_connection_edge_cases.pas"]=1
)

for file in "${!expected_suppression_counts[@]}"; do
  expected="${expected_suppression_counts[$file]}"
  count=$(rg -F -c '{$PUSH}{$WARN 6058 off}{$WARN SYMBOL_DEPRECATED OFF}' "$file")
  if (( count < expected )); then
    echo "[FAIL] expected at least $expected GetConnectionInfo deprecation warning suppressions in $file, found $count"
    exit 1
  fi
done

echo "[PASS] GetConnectionInfo compiler deprecation is aligned across source, docs, and intentional residual tests"
