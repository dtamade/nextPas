#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

mbedtls_guide="docs/guides/MBEDTLS_USER_GUIDE.md"
winssl_quickstart="docs/guides/WINSSL_QUICKSTART.md"

require_fixed() {
  local needle="$1"
  local file="$2"
  local message="$3"

  if ! rg -F -n --quiet -- "$needle" "$file"; then
    echo "[FAIL] $message"
    exit 1
  fi
}

require_fixed '这段简单 HTTPS 示例直接操作 `Context.CreateConnection(...)`，是为了展示当前 MbedTLS backend 的 raw shipped surface；如果你只是普通跨后端 HTTPS 客户端，优先使用通用的 `TSSLContextBuilder` + `TSSLConnector` + `TSSLStream`。' \
  "$mbedtls_guide" \
  "MBEDTLS_USER_GUIDE must classify its simple HTTPS connection sample as backend raw-surface guidance"

require_fixed '这份 WinSSL quickstart 聚焦 Windows-native / WinSSL-specific path，因此会直接展示 `ISSLConnection`；如果你只是普通跨后端 HTTPS 客户端，优先使用通用的 `TSSLContextBuilder` + `TSSLConnector` + `TSSLStream`。' \
  "$winssl_quickstart" \
  "WINSSL_QUICKSTART must explain why it shows direct ISSLConnection instead of the generic facade main path"

echo "[PASS] backend quickstarts classify direct ISSLConnection against the generic facade main-entry truth"
