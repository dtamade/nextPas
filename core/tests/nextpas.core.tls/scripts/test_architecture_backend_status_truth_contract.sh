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

architecture="docs/reference/ARCHITECTURE.md"

echo "[TEST] architecture backend-status truth contract"

require_fixed "$architecture" '当前 backend 的 shipped/runtime truth 不以本表的完成度措辞为准；请同时查看 `docs/ROADMAP.md`、`docs/BACKEND_CAPABILITY_MATRIX.md`、以及 WinSSL 相关状态报告。' \
  "ARCHITECTURE must direct readers to current backend truth sources"
require_fixed "$architecture" '`nextpas.core.tls.openssl.*`    | OpenSSL 实现（Linux/macOS 默认）' \
  "ARCHITECTURE must keep the OpenSSL backend row"
require_fixed "$architecture" '✅ 当前默认 active backend' \
  "ARCHITECTURE must describe OpenSSL as the current default active backend"
require_fixed "$architecture" '`nextpas.core.tls.winssl.*`     | Windows Schannel 实现（Windows 默认）' \
  "ARCHITECTURE must keep the WinSSL backend row"
require_fixed "$architecture" '⚠️ Windows 零依赖客户端 baseline 已验证；更细 runtime truth 见状态报告' \
  "ARCHITECTURE must describe WinSSL with bounded runtime truth"

require_absent "$architecture" "Windows Schannel 实现（Windows 默认，100% 完成）" \
  "ARCHITECTURE must stop advertising WinSSL as 100-percent complete"
require_absent "$architecture" '| `nextpas.core.tls.openssl.*` | OpenSSL 实现（Linux/macOS 默认） | 默认启用 | ✅ 生产就绪 |' \
  "ARCHITECTURE must stop using release-style production-ready wording for OpenSSL"

echo "[PASS] architecture backend-status truth contract passed"
