#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
conn_file="$ROOT_DIR/src/nextpas.core.tls.freepascal.connection.pas"
session_file="$ROOT_DIR/src/nextpas.core.tls.freepascal.session.pas"

if rg -n --fixed-strings "function TFreePascalConnection.GetConnectionInfo" "$conn_file" >/dev/null; then
  echo "[FAIL] FreePascal backend unexpectedly grew a dedicated GetConnectionInfo override"
  exit 1
fi

for pattern in \
  "FCipherName := TLS13CipherSuiteToString(LServerHello.SelectedCipherSuite);" \
  "FCipherName := TLS13CipherSuiteToString(LSelectedCipherSuite);" \
  "TLS13CipherSuiteToString(FApplicationSecrets.CipherSuite)" \
  "function GetCipherSuite: Word;" \
  "FCipherSuite: Word;"
do
  if ! grep -F -q -- "$pattern" "$conn_file" "$session_file"; then
    echo "[FAIL] FreePascal connection/session truth path is missing expected cipher-suite source: $pattern"
    exit 1
  fi
done

echo "[PASS] FreePascal GetConnectionInfo completion contract matches the expected shared-TLS13 truth path"
