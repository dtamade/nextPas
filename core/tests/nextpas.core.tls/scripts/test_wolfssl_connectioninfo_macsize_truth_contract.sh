#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
api_file="$ROOT_DIR/src/nextpas.core.tls.wolfssl.api.pas"
conn_file="$ROOT_DIR/src/nextpas.core.tls.wolfssl.connection.pas"

if ! grep -F -q -- "TwolfSSL_GetHmacSize = function(ssl: PWOLFSSL): Integer; cdecl;" "$api_file"; then
  echo "[FAIL] WolfSSL API is missing wolfSSL_GetHmacSize type binding"
  exit 1
fi

if ! grep -F -q -- "wolfSSL_GetHmacSize: TwolfSSL_GetHmacSize = nil;" "$api_file"; then
  echo "[FAIL] WolfSSL API is missing wolfSSL_GetHmacSize export"
  exit 1
fi

if ! grep -F -q -- "GetProc('wolfSSL_GetHmacSize')" "$api_file"; then
  echo "[FAIL] WolfSSL API no longer binds wolfSSL_GetHmacSize"
  exit 1
fi

if ! grep -F -q -- "Result := inherited GetConnectionInfo;" "$conn_file"; then
  echo "[FAIL] WolfSSL GetConnectionInfo no longer starts from shared connection-info truth"
  exit 1
fi

if ! grep -F -q -- "if (Result.MacSize = 0) and Assigned(wolfSSL_GetHmacSize) then" "$conn_file"; then
  echo "[FAIL] WolfSSL GetConnectionInfo no longer guards legacy MacSize behind missing shared truth"
  exit 1
fi

if ! grep -F -q -- "Result.MacSize := wolfSSL_GetHmacSize(FWolfSSL);" "$conn_file"; then
  echo "[FAIL] WolfSSL GetConnectionInfo no longer writes MacSize from wolfSSL_GetHmacSize"
  exit 1
fi

echo "[PASS] WolfSSL MacSize truth path matches the expected low-level HMAC contract"
