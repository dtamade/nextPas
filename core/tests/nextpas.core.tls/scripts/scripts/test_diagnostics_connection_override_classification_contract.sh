#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

troubleshooting="docs/guides/TROUBLESHOOTING.md"
mbedtls_guide="docs/guides/MBEDTLS_USER_GUIDE.md"

require_fixed() {
  local needle="$1"
  local file="$2"
  local message="$3"

  if ! rg -F -n --quiet -- "$needle" "$file"; then
    echo "[FAIL] $message"
    exit 1
  fi
}

require_fixed '这里的 `LConn.SetTimeout(...)` 是 direct-connection 诊断 override；如果你走的是 `TSSLConnectionBuilder` / `TSSLConnector` / `TSSLAcceptor`，普通新代码优先在构建阶段设置 timeout，并继续让外围 timer/cancel 负责真实超时控制。' \
  "$troubleshooting" \
  "TROUBLESHOOTING must classify SetTimeout as a direct-connection diagnostic override"

require_fixed '这里把 `LConn.SetBlocking(False)` 当成 direct-connection 调试入口；如果你已经有自己的事件循环或 facade 集成，优先继续让外围 event-loop / poller 管理非阻塞状态。' \
  "$troubleshooting" \
  "TROUBLESHOOTING must classify SetBlocking(False) as a direct-connection diagnostic override"

require_fixed '这里的 `Connection.SetTimeout(...)` 也是 connection-level override；如果你只是普通跨后端客户端，优先统一使用 builder / connector 路线与外围 transport timer，而不是把 timeout 策略全压在单个 connection 上。' \
  "$mbedtls_guide" \
  "MBEDTLS_USER_GUIDE must classify Connection.SetTimeout as connection-level override guidance"

echo "[PASS] diagnostics/backends classify connection-level timeout-blocking overrides against the current main-entry truth"
