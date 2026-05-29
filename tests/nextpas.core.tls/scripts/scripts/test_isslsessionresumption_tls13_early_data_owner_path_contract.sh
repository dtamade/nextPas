#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

target_file="tests/test_freepascal_tls13_early_data.pas"

if rg -n --quiet '\b(?:LConn|LTLSStream\.Connection)\.(?:GetSession|SetSession|IsSessionReused)\b' "$target_file"; then
  echo "[FAIL] direct core session-resumption mirror still present in $target_file"
  exit 1
fi

for pattern in \
  "function RequireSessionResumption(" \
  "procedure AssertSessionReused(const AConn: ISSLConnection; const AMessage: string);" \
  "Supports(AConn, ISSLSessionResumption, Result)" \
  "AssertSessionReused(LConn," \
  "Initial connector handshake connection should expose session-resumption owner path" \
  "Resumed client connection should expose session-resumption owner path" \
  "Configured-limit client connection should expose session-resumption owner path"; do
  if ! grep -F -q -- "$pattern" "$target_file"; then
    echo "[FAIL] missing ISSLSessionResumption owner-path helper usage in $target_file: $pattern"
    exit 1
  fi
done

echo "[PASS] FreePascal TLS 1.3 early-data test now prefers ISSLSessionResumption owner path"
