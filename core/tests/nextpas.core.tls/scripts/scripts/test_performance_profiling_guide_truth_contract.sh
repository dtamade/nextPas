#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

guide="docs/guides/PERFORMANCE_PROFILING_GUIDE.md"

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

require_fixed '这里保留 direct `CreateConnection(...)`，是因为 profiling 样例需要显式控制 caller-owned socket、连接建立和握手计时边界；如果你只是普通跨后端 HTTPS 客户端，优先使用 `TSSLContextBuilder` + `TSSLConnector` + `TSSLStream`。' \
  "$guide" \
  "PERFORMANCE_PROFILING_GUIDE must explain why profiling samples intentionally use direct connection paths"

require_fixed '当前 WinSSL session public surface 仍应按 `observed_reuse=false` / `session_configured=true` 的实验性 public truth 理解；如果没有 dedicated Windows / target-specific validation，不要把这段示例直接读成已稳定命中的通用性能收益。' \
  "$guide" \
  "PERFORMANCE_PROFILING_GUIDE must explain the current conservative WinSSL session truth"

require_fixed '下面这些数值最多只能作为“你自己 profiling 时可以关注的量级形状”，不能当成当前长期 truth；最新 baseline 请回到 `scripts/run_phase2_performance_baseline.sh`、`tests/benchmarks/run_all_benchmarks.sh`，并按 `docs/test_reports/PHASE2_PERFORMANCE_METRICS_TEMPLATE.md` 记录环境与结果。' \
  "$guide" \
  "PERFORMANCE_PROFILING_GUIDE must demote fixed performance targets to non-authoritative reference shapes"

require_fixed '- [ ] 仅在 dedicated Windows / target-specific validation 已证明命中时，再考虑 Session public surface' \
  "$guide" \
  "PERFORMANCE_PROFILING_GUIDE checklist must demote session public surface from a default optimization"

require_absent '**预期提升**: 70-90% 握手时间减少' \
  "$guide" \
  "PERFORMANCE_PROFILING_GUIDE must stop promising fixed 70-90 percent gains"

require_absent '- [ ] 启用 Session 复用' \
  "$guide" \
  "PERFORMANCE_PROFILING_GUIDE checklist must stop teaching session public surface as a default checkbox"

require_absent '| Session 复用握手 | < 10ms     | 本地网络 |' \
  "$guide" \
  "PERFORMANCE_PROFILING_GUIDE must stop presenting fixed session-resumption timing as current truth"

echo "[PASS] performance profiling guide is aligned with current profiling/runtime truth"
