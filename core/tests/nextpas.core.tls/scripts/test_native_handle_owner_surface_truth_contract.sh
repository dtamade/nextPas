#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

api_ref="docs/reference/API_REFERENCE.md"
v2_doc="docs/reference/INTERFACE_DESIGN_V2.md"
source_file="src/nextpas.core.tls.base.pas"
test_file="tests/connection/test_ssl_connection_local.pas"

api_ctx_block="$(perl -0ne 'if (/ISSLContext = interface.*?end;\n```/s) { print $& }' "$api_ref")"
v2_conn_block="$(perl -0ne 'if (/ISSLConnection = interface.*?end;\n```/s) { print $& }' "$v2_doc")"
v2_client_block="$(perl -0ne 'if (/ISSLClientConnection = interface\(ISSLConnection\).*?end;\n```/s) { print $& }' "$v2_doc")"

if [[ -z "$api_ctx_block" ]]; then
  echo "[FAIL] failed to extract API reference ISSLContext block"
  exit 1
fi

if [[ -z "$v2_conn_block" ]]; then
  echo "[FAIL] failed to extract INTERFACE_DESIGN_V2 ISSLConnection block"
  exit 1
fi

if [[ -z "$v2_client_block" ]]; then
  echo "[FAIL] failed to extract INTERFACE_DESIGN_V2 ISSLClientConnection block"
  exit 1
fi

if ! grep -F -q 'ISSLNativeHandleAccess = interface' "$source_file"; then
  echo "[FAIL] source no longer declares ISSLNativeHandleAccess"
  exit 1
fi

if grep -F -q 'function GetNativeHandle: Pointer;' <<<"$api_ctx_block"; then
  echo "[FAIL] API reference still lists GetNativeHandle inside ISSLContext"
  exit 1
fi

if ! grep -F -q 'ISSLNativeHandleAccess = interface' "$api_ref"; then
  echo "[FAIL] API reference no longer documents ISSLNativeHandleAccess"
  exit 1
fi

if ! grep -F -q '`GetNativeHandle` 不属于 `ISSLContext` / `ISSLConnection` 核心接口' "$api_ref"; then
  echo "[FAIL] API reference no longer records native-handle as an optional owner surface"
  exit 1
fi

if grep -F -q 'function GetNativeHandle: Pointer;' <<<"$v2_conn_block"; then
  echo "[FAIL] INTERFACE_DESIGN_V2 still lists GetNativeHandle inside ISSLConnection core"
  exit 1
fi

if grep -F -q 'function GetSelectedALPNProtocol: string;' <<<"$v2_client_block"; then
  echo "[FAIL] INTERFACE_DESIGN_V2 still lists GetSelectedALPNProtocol inside ISSLClientConnection"
  exit 1
fi

if ! rg -F -n --quiet '| GetNativeHandle | ISSLNativeHandleAccess | 不属于核心 ISSLConnection；通过可选 native-handle 接口访问 |' "$v2_doc"; then
  echo "[FAIL] INTERFACE_DESIGN_V2 migration table no longer records GetNativeHandle under ISSLNativeHandleAccess"
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

echo "[PASS] native-handle owner surface truth is aligned across source, docs, and generic connection smoke"
