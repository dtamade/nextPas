#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

integration_guide="docs/INTEGRATION_GUIDE.md"
migration_guide="docs/guides/MIGRATION_GUIDE.md"
user_guide="docs/guides/USER_GUIDE.md"

require_fixed() {
  local needle="$1"
  local file="$2"
  local message="$3"

  if ! rg -F -n --quiet -- "$needle" "$file"; then
    echo "[FAIL] $message"
    exit 1
  fi
}

require_fixed "如果你已经在 \`TSSLConnectionBuilder\` / \`TSSLConnector\` / \`TSSLAcceptor\` 上配置了 timeout/blocking，这里的 \`Conn.SetTimeout\` / \`Conn.SetBlocking\` 更适合作为 direct-connection 场景下的局部 override。" \
  "$integration_guide" \
  "integration guide must classify connection-level timeout/blocking as direct-connection override guidance"
require_fixed "\`Conn.SetTimeout\` 是连接级配置，但上层仍然应该负责 timer/cancel；如果你走的是 connector / acceptor facade，新代码优先在构建阶段使用 \`.WithTimeout(...)\`。" \
  "$integration_guide" \
  "integration guide must keep timeout guidance builder-first even when direct-connection examples remain"

require_fixed "这段 direct \`ISSLConnection\` 写法仍是当前 shipped surface；如果你只是做框架/transport 集成，优先走 \`TSSLStream\` 或 \`Read\` / \`Write\`，\`WriteString\` 继续作为 \`v1.x\` convenience-core 文本 helper 保留。" \
  "$migration_guide" \
  "migration guide must classify WriteString examples as shipped convenience helpers instead of the preferred main path"

require_fixed "上面为了快速演示 HTTP 文本往返，使用了 \`ReadString\` / \`WriteString\`。它们仍是 \`v1.x\` convenience-core 文本 helper；如果你在框架、事件循环或分帧协议里集成，优先使用 \`Read\` / \`Write\` 或 \`TSSLStream\`。" \
  "$user_guide" \
  "user guide must explain the current convenience-helper status of ReadString/WriteString"
require_fixed "服务端示例同理：这里保留 \`ReadString\` / \`WriteString\` 是为了让文本请求/响应示例更直观；真正接入 HTTP/SMTP/自定义 framed protocol 时，建议让上层协议自己管理边界，并改走 \`Read\` / \`Write\` 或 \`TSSLStream\`。" \
  "$user_guide" \
  "user guide must explain server-side text helpers as convenience examples rather than the preferred integration path"

echo "[PASS] active guides classify convenience connection surfaces against the current shipped truth"
