#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

base_file="src/nextpas.core.tls.connection.base.pas"
winssl_file="src/nextpas.core.tls.winssl.connection.pas"

if ! grep -F -q -- "Result := inherited GetConnectionInfo;" "$winssl_file"; then
  echo "[FAIL] WinSSL GetConnectionInfo no longer starts from shared connection-info truth"
  exit 1
fi

if ! grep -F -q -- "if (Result.MacSize = 0) and (ConnInfo.dwHashStrength > 0) then" "$winssl_file"; then
  echo "[FAIL] WinSSL GetConnectionInfo no longer guards dwHashStrength fallback behind a missing shared MacSize"
  exit 1
fi

if ! grep -F -q -- "Result.MacSize := ConnInfo.dwHashStrength div 8;" "$winssl_file"; then
  echo "[FAIL] WinSSL GetConnectionInfo no longer retains the legacy dwHashStrength fallback path"
  exit 1
fi

if ! grep -F -q -- "Pos('CCM_8', LName)" "$base_file"; then
  echo "[FAIL] shared connection-info derivation is missing the CCM_8 MacSize rule"
  exit 1
fi

if ! grep -F -q -- "Pos('POLY1305', LName)" "$base_file"; then
  echo "[FAIL] shared connection-info derivation is missing the Poly1305 MacSize rule"
  exit 1
fi

if ! grep -F -q -- "AInfo.MacSize := 16;" "$base_file"; then
  echo "[FAIL] shared connection-info derivation is missing the AEAD 16-byte MacSize fallback"
  exit 1
fi

echo "[PASS] shared and WinSSL MacSize semantics match the expected AEAD-first contract"
