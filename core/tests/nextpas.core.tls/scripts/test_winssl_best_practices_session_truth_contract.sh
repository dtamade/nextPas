#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

guide="docs/guides/WINSSL_BEST_PRACTICES.md"

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

require_fixed '这页作为 WinSSL-specific 最佳实践页，会直接展示 `ISSLConnection` / `CreateConnection(...)` / `ISSLSessionResumption` 这类 backend-facing path；如果你只是普通跨后端 HTTPS 客户端，优先使用通用的 `TSSLContextBuilder` + `TSSLConnector` + `TSSLStream`。' \
  "$guide" \
  "WINSSL_BEST_PRACTICES must classify direct connection/session examples as WinSSL-specific paths"

require_fixed '当前 dedicated Windows runtime truth 仍是 `observed_reuse=false` / `session_configured=true`，因此这组 session public surface 只能按实验性 public surface 理解；不要把它直接当成默认已命中的性能优化。' \
  "$guide" \
  "WINSSL_BEST_PRACTICES must explain the current conservative WinSSL session truth"

require_fixed '这段示例保留 `ISSLSessionResumption`，是因为 WinSSL 的 session published surface 挂在连接对象上；没有 dedicated Windows / target-specific validation 证明目标路径真的复用成功前，不要把 `LResumption.SetSession(...)` + `LConn.Connect` 直接读成已稳定命中的 resumed-handshake 收益。' \
  "$guide" \
  "WINSSL_BEST_PRACTICES must explain why the session example stays on the connection owner path"

require_fixed '- [ ] 仅在 dedicated Windows / target-specific validation 已证明命中时，再考虑 Session public surface' \
  "$guide" \
  "WINSSL_BEST_PRACTICES checklist must demote session public surface from a default optimization"

require_absent '### 2. 启用 Session 复用' \
  "$guide" \
  "WINSSL_BEST_PRACTICES must stop presenting session public surface as a default best practice heading"

require_absent '快速握手' \
  "$guide" \
  "WINSSL_BEST_PRACTICES must stop promising fast handshakes as current WinSSL session truth"

require_absent '- [ ] 启用 Session 复用' \
  "$guide" \
  "WINSSL_BEST_PRACTICES checklist must stop teaching session public surface as a default checkbox"

echo "[PASS] WinSSL best-practices guide is aligned with current session/runtime truth"
