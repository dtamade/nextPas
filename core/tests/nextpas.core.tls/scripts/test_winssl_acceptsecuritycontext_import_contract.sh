#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
API_FILE="$ROOT_DIR/src/nextpas.core.tls.winssl.api.pas"
CONNECTION_FILE="$ROOT_DIR/src/nextpas.core.tls.winssl.connection.pas"

fail() {
  echo "[FAIL] $1"
  exit 1
}

echo "[TEST] winssl AcceptSecurityContext import contract"

[[ -f "$API_FILE" ]] || fail "missing file: src/nextpas.core.tls.winssl.api.pas"
[[ -f "$CONNECTION_FILE" ]] || fail "missing file: src/nextpas.core.tls.winssl.connection.pas"

if ! rg -F --quiet -- "function AcceptSecurityContext(" "$API_FILE"; then
  fail "winssl api should declare the unsuffixed AcceptSecurityContext import"
fi

if rg -F --quiet -- "AcceptSecurityContextW" "$API_FILE"; then
  fail "winssl api must not import a nonexistent AcceptSecurityContextW entry point"
fi

if ! rg -F --quiet -- "Status := AcceptSecurityContext(" "$CONNECTION_FILE"; then
  fail "winssl connection should call the unsuffixed AcceptSecurityContext binding"
fi

if rg -F --quiet -- "AcceptSecurityContextW" "$CONNECTION_FILE"; then
  fail "winssl connection must not call AcceptSecurityContextW"
fi

echo "[PASS] winssl AcceptSecurityContext import contract passed"
