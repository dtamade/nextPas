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

backend_matrix="docs/BACKEND_CAPABILITY_MATRIX.md"
perf_guide="docs/guides/PERFORMANCE_GUIDE.md"
perf_opt_guide="docs/guides/PERFORMANCE_OPTIMIZATION_GUIDE.md"
winssl_guide="docs/guides/WINSSL_USER_GUIDE.md"

echo "[TEST] backend capability matrix performance/selection truth contract"

require_fixed "$perf_guide" '- `scripts/run_phase2_performance_baseline.sh`' \
  "Performance guide must keep the phase2 baseline truth source"
require_fixed "$perf_opt_guide" '- `tests/benchmarks/benchmark_tls_handshake_diagnostic.pas`' \
  "TLS performance guide must keep the diagnostic benchmark truth source"
require_fixed "$winssl_guide" '- 需要 caller-provided server OCSP stapling 等 OpenSSL 优先能力' \
  "WinSSL guide must keep the OpenSSL-preferred capability caveat"
require_fixed "$winssl_guide" '- 需要把 session resumption / tickets 当成已稳定 runtime-proven 能力' \
  "WinSSL guide must keep the session-runtime caveat"

require_fixed "$backend_matrix" '当前性能真相源优先看：' \
  "Top-level backend matrix must point performance readers to current truth sources"
require_fixed "$backend_matrix" '- `scripts/run_phase2_performance_baseline.sh`' \
  "Top-level backend matrix must mention the phase2 baseline entrypoint"
require_fixed "$backend_matrix" '- `tests/benchmarks/run_all_benchmarks.sh`' \
  "Top-level backend matrix must mention the unified benchmark runner"
require_fixed "$backend_matrix" '- `docs/guides/PERFORMANCE_GUIDE.md`' \
  "Top-level backend matrix must link the general performance guide"
require_fixed "$backend_matrix" '- `docs/guides/PERFORMANCE_OPTIMIZATION_GUIDE.md`' \
  "Top-level backend matrix must link the TLS performance guide"
require_fixed "$backend_matrix" '本页不再维护固定“相对值表”。backend 性能会同时受到 CPU、操作系统、编译参数、' \
  "Top-level backend matrix must demote fixed backend performance tables"
require_fixed "$backend_matrix" 'OpenSSL/Schannel/WolfSSL 运行时、目标端点、网络路径、是否启用 TLS lane 与当前' \
  "Top-level backend matrix must explain which runtime factors affect backend performance"
require_fixed "$backend_matrix" 'session/ticket 证据状态影响；因此固定 `x 倍`、固定 `ms` 或固定 `ops/s` 都不应被' \
  "Top-level backend matrix must explain why fixed benchmark numbers are not durable truth"
require_fixed "$backend_matrix" '当成长期 truth。' \
  "Top-level backend matrix must demote historical benchmark snapshots"

require_fixed "$backend_matrix" '**优先考虑**: OpenSSL 后端' \
  "Top-level backend matrix must keep OpenSSL as the capability-first option"
require_fixed "$backend_matrix" '- 需要 custom cipher suites、PKCS#11、完整 PKCS#12 helper/API surface 时优先' \
  "Top-level backend matrix must make OpenSSL recommendation capability-aware"
require_fixed "$backend_matrix" '- 但 Early Data / caller-provided server OCSP stapling 当前不发布，session resumption / tickets 仍按 experimental public surface 理解' \
  "Top-level backend matrix must include WinSSL runtime caveats in the recommendation section"
require_fixed "$backend_matrix" '- `MbedTLS` 当前不要假设 Early Data / OCSP stapling / CT 已可用' \
  "Top-level backend matrix must include MbedTLS capability caveats"
require_fixed "$backend_matrix" '- `WolfSSL` 当前不要假设 early-data / OCSP stapling 无条件可用；它们仍受 build/runtime helper 门控' \
  "Top-level backend matrix must include WolfSSL gating caveats"
require_fixed "$backend_matrix" '- `0-RTT / early data`、OCSP stapling、CT 当前仍按 experimental capability 理解' \
  "Top-level backend matrix must keep FreePascal experimental caveats visible in the recommendation section"

require_absent "$backend_matrix" '| FreePascal | 1.0x    | 0.8x    | 0.3x            |' \
  "Top-level backend matrix must stop publishing stale handshake ratio tables"
require_absent "$backend_matrix" '| OpenSSL    | 1.3x          | 1.5x          |' \
  "Top-level backend matrix must stop publishing stale throughput ratio tables"
require_absent "$backend_matrix" '**推荐**: WinSSL 后端' \
  "Top-level backend matrix must stop presenting WinSSL as an unconditional blanket recommendation"
require_absent "$backend_matrix" '- 性能优秀' \
  "Top-level backend matrix must stop using unsupported blanket performance claims"

echo "[PASS] backend capability matrix performance/selection truth contract passed"
