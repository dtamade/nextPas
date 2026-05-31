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

quickstart="docs/guides/WINSSL_QUICKSTART.md"

echo "[TEST] WinSSL quickstart status/phase truth contract"

require_fixed "$quickstart" '> 当前口径：WinSSL 的零依赖客户端 baseline 已验证；更细 server runtime 场景继续按 [WinSSL 后端状态报告](../test_reports/WINSSL_BACKEND_STATUS_REPORT.md) 区分；如果你要判断 session resumption / Session Ticket 的当前真相，请同时查看 [WinSSL 后端能力矩阵](../reference/WINSSL_BACKEND_CAPABILITY_MATRIX.md)。这部分能力目前仍按实验性 public surface 理解。' \
  "WINSSL_QUICKSTART must declare the current bounded WinSSL runtime truth near the top"
require_fixed "$quickstart" 'WinSSL 当前已经发布服务器 TLS 握手 public surface；更细 server runtime 场景继续按 [WinSSL 后端状态报告](../test_reports/WINSSL_BACKEND_STATUS_REPORT.md) 区分。' \
  "WINSSL_QUICKSTART must keep server-mode guidance bounded to current public/runtime truth"
require_fixed "$quickstart" 'WinSSL 当前已经发布自动证书验证 public surface，基础证书链验证和主机名校验已接通。生产环境推荐使用 `Ctx.SetVerifyMode([sslVerifyPeer])`。' \
  "WINSSL_QUICKSTART must keep certificate-verification guidance bounded to current public truth"
require_fixed "$quickstart" 'WinSSL 与 OpenSSL 的实际性能取决于当前 Windows 版本、Schannel、runner/主机、网络路径和目标站点，不应该把某次历史 benchmark snapshot 当成长期 truth。' \
  "WINSSL_QUICKSTART must demote historical WinSSL performance snapshots"
require_fixed "$quickstart" '✅ 需要完整跨平台 server/runtime 路径' \
  "WINSSL_QUICKSTART must guide server/runtime-sensitive cases to OpenSSL using current wording"
require_fixed "$quickstart" '**状态**: ✅ WinSSL 零依赖客户端基线已验证；会话复用 / Session Ticket 仍按实验性 public surface 理解' \
  "WINSSL_QUICKSTART must keep the current bounded footer status"
require_fixed "$quickstart" '**当前权威入口**: [WinSSL 用户指南](WINSSL_USER_GUIDE.md) · [WinSSL 后端状态报告](../test_reports/WINSSL_BACKEND_STATUS_REPORT.md) · [WinSSL 后端能力矩阵](../reference/WINSSL_BACKEND_CAPABILITY_MATRIX.md)' \
  "WINSSL_QUICKSTART must point readers to the current WinSSL truth sources"

require_absent "$quickstart" "Phase 5 完成" \
  "WINSSL_QUICKSTART must stop advertising server mode via historical phase-completion wording"
require_absent "$quickstart" "Phase 1 完成" \
  "WINSSL_QUICKSTART must stop advertising verification via historical phase-completion wording"
require_absent "$quickstart" "WinSSL 后端 100% 完成（所有 6 个阶段）" \
  "WINSSL_QUICKSTART must stop advertising historical 100-percent completion wording"
require_absent "$quickstart" "WinSSL 性能与 OpenSSL 相当，甚至在某些场景下更快" \
  "WINSSL_QUICKSTART must stop hardcoding a historical performance conclusion"
require_absent "$quickstart" "~150ms" \
  "WINSSL_QUICKSTART must stop embedding historical latency snapshots"
require_absent "$quickstart" "~160ms" \
  "WINSSL_QUICKSTART must stop embedding historical OpenSSL latency snapshots"
require_absent "$quickstart" "~80 MB/s" \
  "WINSSL_QUICKSTART must stop embedding historical throughput snapshots"
require_absent "$quickstart" "~85 MB/s" \
  "WINSSL_QUICKSTART must stop embedding historical OpenSSL throughput snapshots"
require_absent "$quickstart" "需要服务器模式（当前）" \
  "WINSSL_QUICKSTART must stop teaching that server mode is categorically unavailable on WinSSL"
require_absent "$quickstart" "需要完整证书验证（当前）" \
  "WINSSL_QUICKSTART must stop teaching that full certificate verification is categorically unavailable on WinSSL"

echo "[PASS] WinSSL quickstart status/phase truth contract passed"
