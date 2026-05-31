#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

base_file="src/nextpas.core.tls.base.pas"
api_ref="docs/reference/API_REFERENCE.md"
v2_doc="docs/reference/INTERFACE_DESIGN_V2.md"
message="Use ISSLConnectionInfo.GetStateString"

count=$(perl -0ne "
  my \$n = () = /function GetStateString\\: string;\\s*deprecated '\\Q$message\\E';/g;
  print \$n;
" "$base_file")

if [[ "$count" != "1" ]]; then
  echo "[FAIL] expected exactly one compiler-deprecated core GetStateString declaration in $base_file"
  echo "       matched declarations: $count"
  exit 1
fi

if ! rg -F -n --quiet "function GetStateString: string; // 编译期 deprecated，仅兼容保留；新代码优先走 ISSLConnectionInfo.GetStateString" "$api_ref"; then
  echo "[FAIL] API reference no longer records GetStateString as a compiler-deprecated compatibility mirror"
  exit 1
fi

if ! rg -F -n --quiet "| GetStateString | ISSLConnectionInfo | 默认 owner 已切到 ISSLConnectionInfo；core 侧仅兼容保留，源码声明已是编译期 deprecated |" "$v2_doc"; then
  echo "[FAIL] V2 migration table no longer records the compiler-deprecated core GetStateString surface"
  exit 1
fi

if ! rg -F -n --quiet "其中 \`GetStateString\` 在核心 \`ISSLConnection\` 上当前也只保留为 compatibility mirror，源码声明已经进入编译期 \`deprecated\`；后续仍可再评估是否并入 \`GetState\`。" "$v2_doc"; then
  echo "[FAIL] V2 migration note no longer records the compiler-deprecated GetStateString fallback"
  exit 1
fi

declare -A expected_suppression_counts=(
  ["tests/contract/test_backend_contract.pas"]=1
  ["tests/openssl/test_openssl_server_ocsp_stapling_runtime.pas"]=2
  ["tests/wolfssl/test_wolfssl_server_ocsp_stapling_runtime.pas"]=6
)

for file in "${!expected_suppression_counts[@]}"; do
  expected="${expected_suppression_counts[$file]}"
  count=$(rg -F -c '{$PUSH}{$WARN 6058 off}{$WARN SYMBOL_DEPRECATED OFF}' "$file")
  if (( count < expected )); then
    echo "[FAIL] expected at least $expected GetStateString deprecation warning suppressions in $file, found $count"
    exit 1
  fi
done

echo "[PASS] GetStateString compiler deprecation is aligned across source, docs, and residual runtime proofs"
