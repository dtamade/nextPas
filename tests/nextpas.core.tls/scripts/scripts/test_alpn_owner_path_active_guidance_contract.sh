#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

source_file="src/nextpas.core.tls.base.pas"
winssl_guide="docs/guides/WINSSL_USER_GUIDE.md"
alpn_example="examples/https_server/https_server_alpn.pas"

require_fixed() {
  local needle="$1"
  local file="$2"
  local message="$3"

  if ! rg -F -n --quiet -- "$needle" "$file"; then
    echo "[FAIL] $message"
    exit 1
  fi
}

require_absent() {
  local needle="$1"
  local file="$2"
  local message="$3"

  if rg -F -n --quiet -- "$needle" "$file"; then
    echo "[FAIL] $message"
    exit 1
  fi
}

require_fixed "deprecated 'Use ISSLConnectionInfo.GetSelectedALPNProtocol';" \
  "$source_file" \
  "source no longer marks ISSLConnection.GetSelectedALPNProtocol as deprecated in favor of ISSLConnectionInfo"

require_fixed '协商结果获取（优先通过 `ISSLConnectionInfo.GetSelectedALPNProtocol`）' \
  "$winssl_guide" \
  "WinSSL user guide no longer points ALPN readers at the owner surface"

require_absent "SelectedProto := Connection.GetSelectedALPNProtocol;" \
  "$alpn_example" \
  "ALPN server example still uses the deprecated connection-level ALPN mirror directly"
require_fixed "ConnectionInfo: ISSLConnectionInfo;" \
  "$alpn_example" \
  "ALPN server example no longer declares the owner-surface accessor"
require_fixed "if Supports(Connection, ISSLConnectionInfo, ConnectionInfo) then" \
  "$alpn_example" \
  "ALPN server example no longer probes ISSLConnectionInfo before reading the selected protocol"
require_fixed "SelectedProto := ConnectionInfo.GetSelectedALPNProtocol;" \
  "$alpn_example" \
  "ALPN server example no longer reads the selected protocol through ISSLConnectionInfo"

echo "[PASS] active ALPN guidance now prefers the ISSLConnectionInfo owner path"
