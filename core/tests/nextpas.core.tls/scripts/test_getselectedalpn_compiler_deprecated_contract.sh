#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"

cd "$PROJECT_ROOT"

base_file="core/src/nextpas.core.tls.base.pas"
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




declare -A residual_patterns=(
  ["core/tests/nextpas.core.tls/contract/test_backend_contract.pas"]='\{\$PUSH\}\{\$WARN 6058 off\}\{\$WARN SYMBOL_DEPRECATED OFF\}\s*LCoreALPN := LConn\.GetSelectedALPNProtocol;\s*\{\$POP\}'
  ["core/tests/nextpas.core.tls/mbedtls/test_mbedtls_alpn.pas"]='\{\$PUSH\}\{\$WARN 6058 off\}\{\$WARN SYMBOL_DEPRECATED OFF\}\s*LSelectedProtocol := LConn\.GetSelectedALPNProtocol;\s*\{\$POP\}'
  ["core/tests/nextpas.core.tls/winssl/test_winssl_alpn_sni.pas"]='\{\$PUSH\}\{\$WARN 6058 off\}\{\$WARN SYMBOL_DEPRECATED OFF\}\s*Proto := Conn\.GetSelectedALPNProtocol;\s*\{\$POP\}'
  ["core/tests/nextpas.core.tls/winssl/test_winssl_connection_edge_cases.pas"]='\{\$PUSH\}\{\$WARN 6058 off\}\{\$WARN SYMBOL_DEPRECATED OFF\}\s*LALPNProtocol := LConnection\.GetSelectedALPNProtocol;\s*\{\$POP\}'
)

for file in "${!residual_patterns[@]}"; do
  pattern="${residual_patterns[$file]}"
  if ! perl -0ne "exit(!(/$pattern/s))" "$file"; then
    echo "[FAIL] expected GetSelectedALPNProtocol deprecation warning quarantine in $file"
    exit 1
  fi
done

echo "[PASS] GetSelectedALPNProtocol compiler deprecation is aligned across source, docs, and residual runtime proofs"
