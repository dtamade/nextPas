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

require_regex() {
  local file="$1"
  local pattern="$2"
  local message="$3"
  if ! rg -U -n --pcre2 --quiet -- "$pattern" "$file"; then
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

guide="docs/guides/PERFORMANCE_GUIDE.md"
opt_guide="docs/guides/PERFORMANCE_OPTIMIZATION_GUIDE.md"

echo "[TEST] performance guides benchmark truth contract"

require_regex "$guide" '本指南只负责说明当前 benchmark 入口、适用边界和结果解读；不要把某次历史\s*Phase/benchmark 报告里的固定吞吐量、延迟、倍率、成功率或完成度写成当前长期\s*truth。' \
  "PERFORMANCE_GUIDE must demote historical benchmark and phase snapshots"
require_fixed "$guide" '当前真相源优先看：' \
  "PERFORMANCE_GUIDE must point readers to current truth sources"
require_fixed "$guide" '- `scripts/run_phase2_performance_baseline.sh`' \
  "PERFORMANCE_GUIDE must link the phase2 baseline entrypoint"
require_fixed "$guide" '- `tests/benchmarks/run_all_benchmarks.sh`' \
  "PERFORMANCE_GUIDE must link the unified benchmark runner"
require_fixed "$guide" '- `tests/benchmarks/baselines/crypto_baseline.json`' \
  "PERFORMANCE_GUIDE must link the crypto baseline file"
require_fixed "$guide" '- `tests/benchmarks/baselines/random_pool_baseline.json`' \
  "PERFORMANCE_GUIDE must link the random-pool baseline file"
require_fixed "$guide" '- `tests/benchmarks/baselines/tls_handshake_baseline.json`' \
  "PERFORMANCE_GUIDE must link the TLS handshake baseline file"
require_fixed "$guide" '默认成功标准不是命中某个固定毫秒数或 ops/s，而是：' \
  "PERFORMANCE_GUIDE must define success without hardcoded numbers"

require_absent "$guide" 'Phase B 优化成果' \
  "PERFORMANCE_GUIDE must stop presenting historical phase results as current truth"
require_absent "$guide" '250,000 → 600,000 ops/s' \
  "PERFORMANCE_GUIDE must stop hardcoding random-pool throughput snapshots"
require_absent "$guide" '~10,000 requests/s' \
  "PERFORMANCE_GUIDE must stop hardcoding TLS request-rate snapshots"
require_absent "$guide" '> 100,000 ops/s (1KB)' \
  "PERFORMANCE_GUIDE must stop hardcoding threshold tables as current truth"
require_absent "$guide" '完成 Phase C 性能优化验证' \
  "PERFORMANCE_GUIDE must stop carrying historical completion logs as current truth"

require_fixed "$opt_guide" '本指南聚焦 TLS 握手、会话复用、上下文复用和诊断入口。TLS 握手延迟和会话复用收' \
  "PERFORMANCE_OPTIMIZATION_GUIDE must explain the variable TLS-performance boundary"
require_fixed "$opt_guide" '益会受到 backend、TLS 版本、目标站点、网络路径、runner/主机与是否拿到票据等' \
  "PERFORMANCE_OPTIMIZATION_GUIDE must explain which runtime factors affect TLS performance"
require_fixed "$opt_guide" '因素影响，不应该把某次本地或公网测试的固定毫秒数、P99、倍率写成长期 truth。' \
  "PERFORMANCE_OPTIMIZATION_GUIDE must explain why fixed TLS metrics are not durable truth"
require_fixed "$opt_guide" '核心 `ISSLConnection.GetSession` / `SetSession` / `IsSessionReused` 在新代码里只' \
  "PERFORMANCE_OPTIMIZATION_GUIDE must demote direct-core session mirrors"
require_fixed "$opt_guide" '作为 compatibility mirror 保留；性能相关示例优先走' \
  "PERFORMANCE_OPTIMIZATION_GUIDE must point session examples to the owner path"
require_fixed "$opt_guide" '`ISSLSessionResumption`。' \
  "PERFORMANCE_OPTIMIZATION_GUIDE must teach ISSLSessionResumption-first guidance"
require_fixed "$opt_guide" '核心 `ISSLConnection.GetPerformanceMetrics` 在新代码里只作为 compatibility' \
  "PERFORMANCE_OPTIMIZATION_GUIDE must demote direct-core performance-metric mirrors"
require_fixed "$opt_guide" 'mirror 保留；性能/诊断采样优先走 `ISSLDiagnostics`。' \
  "PERFORMANCE_OPTIMIZATION_GUIDE must teach ISSLDiagnostics-first guidance"
require_fixed "$opt_guide" 'Supports(Conn1, ISSLSessionResumption, Resumption1)' \
  "PERFORMANCE_OPTIMIZATION_GUIDE must show owner-path session acquisition"
require_fixed "$opt_guide" 'Session := Resumption1.GetSession;' \
  "PERFORMANCE_OPTIMIZATION_GUIDE must show owner-path GetSession usage"
require_fixed "$opt_guide" 'Supports(Conn2, ISSLSessionResumption, Resumption2)' \
  "PERFORMANCE_OPTIMIZATION_GUIDE must show owner-path session injection"
require_fixed "$opt_guide" 'Resumption2.SetSession(Session);' \
  "PERFORMANCE_OPTIMIZATION_GUIDE must show owner-path SetSession usage"
require_fixed "$opt_guide" 'BoolToStr(Resumption2.IsSessionReused, True)' \
  "PERFORMANCE_OPTIMIZATION_GUIDE must show owner-path session reuse checks"
require_fixed "$opt_guide" 'Supports(Stream.Connection, ISSLDiagnostics, Diag)' \
  "PERFORMANCE_OPTIMIZATION_GUIDE must show owner-path diagnostics access"
require_fixed "$opt_guide" 'Perf := Diag.GetPerformanceMetrics;' \
  "PERFORMANCE_OPTIMIZATION_GUIDE must show owner-path performance metrics access"
require_fixed "$opt_guide" '- `tests/benchmarks/benchmark_tls_handshake_diagnostic.pas`' \
  "PERFORMANCE_OPTIMIZATION_GUIDE must point readers to the TLS diagnostic source"

require_absent "$opt_guide" '3.7ms' \
  "PERFORMANCE_OPTIMIZATION_GUIDE must stop hardcoding loopback handshake timings"
require_absent "$opt_guide" '1160ms' \
  "PERFORMANCE_OPTIMIZATION_GUIDE must stop hardcoding network handshake timings"
require_absent "$opt_guide" '181ms' \
  "PERFORMANCE_OPTIMIZATION_GUIDE must stop hardcoding session reuse timings"
require_absent "$opt_guide" '6.4 倍' \
  "PERFORMANCE_OPTIMIZATION_GUIDE must stop hardcoding reuse multipliers"
require_absent "$opt_guide" '完美支持' \
  "PERFORMANCE_OPTIMIZATION_GUIDE must stop overclaiming universal runtime support"
require_absent "$opt_guide" '100% 缓存命中率' \
  "PERFORMANCE_OPTIMIZATION_GUIDE must stop carrying random-pool snapshot claims"
require_absent "$opt_guide" 'Session := Conn.GetSession;' \
  "PERFORMANCE_OPTIMIZATION_GUIDE must stop teaching direct-core GetSession"
require_absent "$opt_guide" 'Conn.SetSession(Session);' \
  "PERFORMANCE_OPTIMIZATION_GUIDE must stop teaching direct-core SetSession"
require_absent "$opt_guide" 'if Conn.IsSessionReused then' \
  "PERFORMANCE_OPTIMIZATION_GUIDE must stop teaching direct-core IsSessionReused"
require_absent "$opt_guide" 'Stream.Connection.IsSessionReused' \
  "PERFORMANCE_OPTIMIZATION_GUIDE must stop teaching direct-core reuse checks in troubleshooting"

echo "[PASS] performance guides benchmark truth contract passed"
