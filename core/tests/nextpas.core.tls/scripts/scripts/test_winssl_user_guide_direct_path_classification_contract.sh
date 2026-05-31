#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

guide="docs/guides/WINSSL_USER_GUIDE.md"

require_fixed() {
  local needle="$1"
  local file="$2"
  local message="$3"

  if ! rg -F -n --quiet -- "$needle" "$file"; then
    echo "[FAIL] $message"
    exit 1
  fi
}

require_fixed '这页作为 WinSSL-specific 用户指南，会直接展示 `ISSLConnection` / `CreateConnection(...)` 这类 backend-facing path；如果你只是普通跨后端 HTTPS 客户端，优先使用通用的 `TSSLContextBuilder` + `TSSLConnector` + `TSSLStream`。' \
  "$guide" \
  "WINSSL_USER_GUIDE must classify its direct connection examples as WinSSL-specific paths"

require_fixed '这里直接写 `CreateConnection(...)` + `ISSLClientConnection.SetServerName(...)`，是因为 hostname/SNI 的 published surface 挂在连接对象上；如果你不需要直接操作这层 WinSSL-specific path，也可以改用 `TSSLConnector.ConnectSocket(..., '\''www.example.com'\'')`。' \
  "$guide" \
  "WINSSL_USER_GUIDE must explain why its SNI example intentionally uses the connection-level path"

echo "[PASS] WinSSL user guide explains why it intentionally uses direct connection paths"
