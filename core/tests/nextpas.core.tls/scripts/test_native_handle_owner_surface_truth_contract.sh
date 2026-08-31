#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"

cd "$PROJECT_ROOT"

source_file="core/src/nextpas.core.tls.base.pas"
test_file="core/tests/nextpas.core.tls/connection/test_ssl_connection_local.pas"





if ! grep -F -q 'ISSLNativeHandleAccess = interface' "$source_file"; then
  echo "[FAIL] source no longer declares ISSLNativeHandleAccess"
  exit 1
fi







if rg -n -q 'ClientConnection\.GetNativeHandle|ServerConnection\.GetNativeHandle' "$test_file"; then
  echo "[FAIL] generic local connection test still calls removed core GetNativeHandle"
  exit 1
fi

if rg -n -q 'ClientConnection\.GetConnectionInfo' "$test_file"; then
  echo "[FAIL] generic local connection test still calls deprecated core GetConnectionInfo"
  exit 1
fi

if ! rg -F -n --quiet 'Supports(ClientConnection, ISSLNativeHandleAccess, LNativeHandleAccess)' "$test_file"; then
  echo "[FAIL] generic local connection test no longer probes client native handle through ISSLNativeHandleAccess"
  exit 1
fi

if ! rg -F -n --quiet 'Supports(ServerConnection, ISSLNativeHandleAccess, LNativeHandleAccess)' "$test_file"; then
  echo "[FAIL] generic local connection test no longer probes server native handle through ISSLNativeHandleAccess"
  exit 1
fi

if ! rg -F -n --quiet 'Info := LConnInfoAccess.GetConnectionInfo;' "$test_file"; then
  echo "[FAIL] generic local connection test no longer reads connection info through ISSLConnectionInfo"
  exit 1
fi

echo "[PASS] native-handle owner surface truth is aligned across source and generic connection smoke"
