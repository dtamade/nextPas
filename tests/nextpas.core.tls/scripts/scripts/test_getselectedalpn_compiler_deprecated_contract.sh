#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

base_file="src/nextpas.core.tls.base.pas"
api_ref="docs/reference/API_REFERENCE.md"
v2_doc="docs/reference/INTERFACE_DESIGN_V2.md"
message="Use ISSLConnectionInfo.GetSelectedALPNProtocol"

count=$(perl -0ne "
  my \$n = () = /function GetSelectedALPNProtocol\\: string;\\s*deprecated '\\Q$message\\E';/g;
  print \$n;
" "$base_file")

if [[ "$count" != "1" ]]; then
  echo "[FAIL] expected exactly one compiler-deprecated core GetSelectedALPNProtocol declaration in $base_file"
  echo "       matched declarations: $count"
  exit 1
fi

if ! rg -F -n --quiet "function GetSelectedALPNProtocol: string; // 编译期 deprecated，仅兼容保留；新代码优先走 ISSLConnectionInfo.GetSelectedALPNProtocol" "$api_ref"; then
  echo "[FAIL] API reference no longer records GetSelectedALPNProtocol as a compiler-deprecated compatibility mirror"
  exit 1
fi

if ! rg -F -n --quiet "| GetSelectedALPNProtocol | ISSLConnectionInfo | 默认 owner 已切到 ISSLConnectionInfo；core 侧仅兼容保留，源码声明已是编译期 deprecated |" "$v2_doc"; then
  echo "[FAIL] V2 migration table no longer records the compiler-deprecated core GetSelectedALPNProtocol surface"
  exit 1
fi

if ! rg -F -n --quiet "其中 \`GetSelectedALPNProtocol\` 在核心 \`ISSLConnection\` 上当前也只保留为 compatibility mirror，源码声明已经进入编译期 \`deprecated\`；后续仍可再评估是否进一步收窄到 \`ISSLClientConnection\`。" "$v2_doc"; then
  echo "[FAIL] V2 migration note no longer records the compiler-deprecated GetSelectedALPNProtocol fallback"
  exit 1
fi

declare -A residual_patterns=(
  ["tests/contract/test_backend_contract.pas"]='\{\$PUSH\}\{\$WARN 6058 off\}\{\$WARN SYMBOL_DEPRECATED OFF\}\s*LCoreALPN := LConn\.GetSelectedALPNProtocol;\s*\{\$POP\}'
  ["tests/mbedtls/test_mbedtls_alpn.pas"]='\{\$PUSH\}\{\$WARN 6058 off\}\{\$WARN SYMBOL_DEPRECATED OFF\}\s*LSelectedProtocol := LConn\.GetSelectedALPNProtocol;\s*\{\$POP\}'
  ["tests/winssl/test_winssl_alpn_sni.pas"]='\{\$PUSH\}\{\$WARN 6058 off\}\{\$WARN SYMBOL_DEPRECATED OFF\}\s*Proto := Conn\.GetSelectedALPNProtocol;\s*\{\$POP\}'
  ["tests/winssl/test_winssl_connection_edge_cases.pas"]='\{\$PUSH\}\{\$WARN 6058 off\}\{\$WARN SYMBOL_DEPRECATED OFF\}\s*LALPNProtocol := LConnection\.GetSelectedALPNProtocol;\s*\{\$POP\}'
)

for file in "${!residual_patterns[@]}"; do
  pattern="${residual_patterns[$file]}"
  if ! perl -0ne "exit(!(/$pattern/s))" "$file"; then
    echo "[FAIL] expected GetSelectedALPNProtocol deprecation warning quarantine in $file"
    exit 1
  fi
done

echo "[PASS] GetSelectedALPNProtocol compiler deprecation is aligned across source, docs, and residual runtime proofs"
