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

guide="docs/guides/PERFORMANCE_OPTIMIZATION_GUIDE.md"
probe="tests/contract/test_performance_optimization_guide_public_owner_surface_probe.pas"

echo "[TEST] performance optimization guide public import truth contract"

require_fixed "$guide" "  SysUtils," \
  "PERFORMANCE_OPTIMIZATION_GUIDE first sample must keep SysUtils import"
require_fixed "$guide" "  fafafa.ssl;" \
  "PERFORMANCE_OPTIMIZATION_GUIDE samples must use the public facade unit"
require_fixed "$guide" "Resumption1, Resumption2: ISSLSessionResumption;" \
  "PERFORMANCE_OPTIMIZATION_GUIDE must keep the session owner-path sample"
require_fixed "$guide" "Diag: ISSLDiagnostics;" \
  "PERFORMANCE_OPTIMIZATION_GUIDE must keep the diagnostics owner-path sample"
require_fixed "$guide" "Perf := Diag.GetPerformanceMetrics;" \
  "PERFORMANCE_OPTIMIZATION_GUIDE must keep the diagnostics owner-path access"

require_absent "$guide" "  nextpas.core.tls.base;" \
  "PERFORMANCE_OPTIMIZATION_GUIDE must stop teaching direct base-unit imports"

mkdir -p tmp/perf_guide_public_owner_surface_probe
fpc -B -Fu./src \
  -FUtmp/perf_guide_public_owner_surface_probe \
  -FEtmp/perf_guide_public_owner_surface_probe \
  -otmp/perf_guide_public_owner_surface_probe/test_performance_optimization_guide_public_owner_surface_probe \
  "$probe" >/dev/null

echo "[PASS] performance optimization guide public import truth contract passed"
