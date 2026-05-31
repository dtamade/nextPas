#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

guide="docs/guides/TROUBLESHOOTING.md"

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

require_fixed '这里保留 direct `CreateConnection(...)` + `ISSLSessionResumption`，是因为排障时要直接观察连接对象上的 session owner surface；如果你只是普通跨后端 HTTPS 客户端，优先继续使用通用的 `TSSLContextBuilder` + `TSSLConnector` + `TSSLStream`。' \
  "$guide" \
  "TROUBLESHOOTING must classify the direct WinSSL session snippet as an owner-surface troubleshooting path"

require_fixed '当前 dedicated Windows runtime truth 仍应按 `observed_reuse=false` / `session_configured=true` 理解，所以这段示例只能用来观察 session 是否被配置与连接是否暴露 owner surface；没有 dedicated Windows / target-specific validation 时，不要把 `LResumption2.SetSession(...)` + `LConn2.Connect` 直接读成已稳定命中的 resumed-handshake。' \
  "$guide" \
  "TROUBLESHOOTING must explain the current conservative WinSSL session truth for the troubleshooting snippet"

require_absent '1. **启用 Session 复用**' \
  "$guide" \
  "TROUBLESHOOTING must stop presenting the WinSSL session snippet as a default enablement step"

require_absent '快速复用' \
  "$guide" \
  "TROUBLESHOOTING must stop promising fast reuse in the WinSSL troubleshooting snippet"

require_absent '快速握手' \
  "$guide" \
  "TROUBLESHOOTING must stop promising fast handshakes in the WinSSL troubleshooting snippet"

echo "[PASS] troubleshooting guide is aligned with current WinSSL session/runtime truth"
