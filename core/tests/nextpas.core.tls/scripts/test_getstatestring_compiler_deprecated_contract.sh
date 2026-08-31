#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"

cd "$PROJECT_ROOT"

base_file="core/src/nextpas.core.tls.base.pas"
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




declare -A expected_suppression_counts=(
  ["core/tests/nextpas.core.tls/openssl/test_openssl_server_ocsp_stapling_runtime.pas"]=2
  ["core/tests/nextpas.core.tls/wolfssl/test_wolfssl_server_ocsp_stapling_runtime.pas"]=6
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
