#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

pitfalls="docs/guides/COMMON_PITFALLS.md"
security_guide="docs/guides/security-best-practices.md"
error_handling="docs/guides/ERROR_HANDLING_BEST_PRACTICES.md"

require_fixed() {
  local needle="$1"
  local file="$2"
  local message="$3"

  if ! rg -F -n --quiet -- "$needle" "$file"; then
    echo "[FAIL] $message"
    exit 1
  fi
}

require_fixed '这里故意保留 direct `CreateConnection(...)` 对比，是为了把“没设 SNI 会怎样、设了 SNI 又会怎样”写成最短 pitfall 对照；如果你只是普通客户端接入，仍然可以优先使用 `TSSLConnector.ConnectSocket(..., host)`。' \
  "$pitfalls" \
  "COMMON_PITFALLS must explain why it keeps the direct CreateConnection SNI pitfall contrast"

require_fixed '这里展开 direct `ISSLConnection`，是为了把 hostname/SNI 的连接级责任显式写出来；如果你不需要这层低层控制，继续使用 `TSSLConnector.ConnectSocket(..., host)` 也同样正确。' \
  "$security_guide" \
  "security-best-practices must explain why it uses direct ISSLConnection in the hostname example"

require_fixed '这里使用 direct `CreateConnection(...)`，是因为示例正在讨论 URL 解析后的 socket ownership、连接异常，以及 Result/exception 的边界；如果你不需要这层低层控制，可以把握手入口收回到 `TSSLConnector`。' \
  "$error_handling" \
  "ERROR_HANDLING_BEST_PRACTICES must explain why its URL-driven example uses direct CreateConnection"

echo "[PASS] high-frequency guides explain why they intentionally use direct ISSLConnection paths"
