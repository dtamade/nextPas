#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

root_readme="README.md"
getting_started="docs/guides/GETTING_STARTED.md"
quickstart="docs/guides/QUICKSTART.md"

require_fixed() {
  local needle="$1"
  local file="$2"
  local message="$3"

  if ! rg -F -n --quiet -- "$needle" "$file"; then
    echo "[FAIL] $message"
    exit 1
  fi
}

require_fixed '下面这段 `TLS 连接` 代码块展示的是底层 core surface reference；普通新代码优先沿用上面的 `TSSLContextBuilder` + `TSSLConnector` + `TSSLStream` 快速路径。' \
  "$root_readme" \
  "root README must classify the raw TLS connection snippet as low-level core-surface reference"

require_fixed '这条 direct `ISSLConnection` 路径仍是当前 shipped 的低层入口；如果你只是普通客户端/服务端接入，优先继续使用 `TSSLConnector` / `TSSLAcceptor` / `TSSLStream`。' \
  "$getting_started" \
  "GETTING_STARTED must classify direct ISSLConnection as a low-level path instead of the default recommendation"

require_fixed '这里之所以回到 direct `ISSLConnection`，是因为当前 public session-resumption surface 通过 `ISSLSessionResumption` 挂在连接对象上；普通 HTTPS 客户端仍优先走前面的 `TSSLConnector` + `TSSLStream` 快速路径。' \
  "$quickstart" \
  "QUICKSTART must explain why the WinSSL session example uses direct ISSLConnection"

echo "[PASS] landing quickstarts classify direct ISSLConnection paths against the current main-entry truth"
