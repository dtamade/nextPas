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

guide="docs/guides/WINSSL_USER_GUIDE.md"

echo "[TEST] WinSSL user guide performance/runtime truth contract"

require_fixed "$guide" 'WinSSL 的 runtime 性能和稳定性会受到 Windows 版本、Schannel、runner/主机、网络路径、目标站点等因素影响，不应该把某次历史运行的固定延迟、连接速率或成功率写成当前长期 truth。' \
  "WINSSL_USER_GUIDE must explain why fixed WinSSL runtime numbers are not durable truth"
require_fixed "$guide" '如果你需要当前 WinSSL runtime baseline，请优先查看：' \
  "WINSSL_USER_GUIDE must point readers to current WinSSL runtime baseline entrypoints"
require_fixed "$guide" '- `tests/windows/VALIDATION_BUNDLE.md`' \
  "WINSSL_USER_GUIDE must link the Windows validation bundle"
require_fixed "$guide" '- `.github/workflows/wave-b-b2-manual.yml` 的 `windows-gate` lane' \
  "WINSSL_USER_GUIDE must link the Windows gate lane"
require_fixed "$guide" '不要把某次运行产物里的固定毫秒数、连接速率或成功率复制回当前用户指南正文。' \
  "WINSSL_USER_GUIDE must explicitly demote fixed runtime snapshots"

require_absent "$guide" "436.94 ms" \
  "WINSSL_USER_GUIDE must stop hardcoding historical handshake latency"
require_absent "$guide" "204.52 ms" \
  "WINSSL_USER_GUIDE must stop hardcoding historical transfer latency"
require_absent "$guide" "2.41 conn/s" \
  "WINSSL_USER_GUIDE must stop hardcoding historical connection rate"
require_absent "$guide" "30/30 成功" \
  "WINSSL_USER_GUIDE must stop hardcoding historical stability counts"
require_absent "$guide" "**测试环境**: Windows 11 x64, 网络连接到互联网服务器" \
  "WINSSL_USER_GUIDE must stop presenting one historical environment snapshot as current guide truth"

echo "[PASS] WinSSL user guide performance/runtime truth contract passed"
