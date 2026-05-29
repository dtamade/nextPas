#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$root_dir"

fail() {
  echo "[FAIL] $1" >&2
  exit 1
}

require_fixed() {
  local file="$1"
  local pattern="$2"
  local message="$3"
  if ! rg -F -n --quiet -- "$pattern" "$file"; then
    fail "$message"
  fi
}

require_absent() {
  local file="$1"
  local pattern="$2"
  local message="$3"
  if rg -F -n --quiet -- "$pattern" "$file"; then
    fail "$message"
  fi
}

audit="docs/test_reports/INTERFACE_DESIGN_AUDIT_V1.5.0.md"
factory="src/nextpas.core.tls.factory.pas"
builder="src/nextpas.core.tls.context.builder.pas"
architecture="docs/ARCHITECTURE.md"
v2_doc="docs/reference/INTERFACE_DESIGN_V2.md"

echo "[TEST] interface audit current truth contract"

require_fixed "$factory" "CreateContext ignores it for new contexts" \
  "factory must keep the current warning+ignore ServerName truth"
require_fixed "$builder" "BuildClient ignores it" \
  "builder must keep the current client-side WithSNI ignore truth"
require_fixed "$builder" "BuildServer ignores it and server-side connections ignore it" \
  "builder must keep the current server-side WithSNI ignore truth"
require_fixed "$architecture" '当前 public Pascal source 只声明了 `ISSLClientConnection`' \
  "ARCHITECTURE must explicitly state that only ISSLClientConnection exists today"
require_fixed "$v2_doc" '当前 public Pascal source 尚未声明 `ISSLServerConnection`。' \
  "INTERFACE_DESIGN_V2 must explicitly state the current ISSLServerConnection absence"

require_fixed "$audit" '高层 factory / builder 主路径现在已经是 warning + ignore，不再把 `ServerName` 写回新建 context。' \
  "audit must reflect the current high-level ServerName warning+ignore truth"
require_fixed "$audit" '活跃架构/设计文档现在已经显式说明当前 public Pascal source 尚未声明 `ISSLServerConnection`。' \
  "audit must reflect that active docs no longer promise ISSLServerConnection"
require_fixed "$audit" '`BufferSize` / `HandshakeTimeout` 在 factory / direct-library 路径上当前是显式 reject，不是 silent inert。' \
  "audit must reflect the current BufferSize/HandshakeTimeout reject truth"

require_absent "$audit" 'factory 和 builder 仍然把 `ServerName` 写回 context' \
  "audit must stop claiming that high-level paths still write ServerName into contexts"
require_absent "$audit" '文档承诺了 `ISSLServerConnection`，源码里没有' \
  "audit must stop claiming that active docs still promise ISSLServerConnection"
require_absent "$audit" '`BufferSize` / `HandshakeTimeout` 只在默认值/调试里出现，主创建路径没有看到实际消费' \
  "audit must stop describing BufferSize/HandshakeTimeout as merely unseen/inert"

echo "[PASS] interface audit current truth contract passed"
