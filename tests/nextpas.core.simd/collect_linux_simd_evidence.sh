#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
OUTPUT_ROOT="${SIMD_OUTPUT_ROOT:-${SCRIPT_DIR}}"
TS="$(date +%Y%m%d-%H%M%S)"
OUT_DIR="${OUTPUT_ROOT}/logs/evidence-${TS}"
mkdir -p "${OUT_DIR}"
ENABLE_QEMU_EXPERIMENTAL="${SIMD_EVIDENCE_QEMU_EXPERIMENTAL:-0}"

run_step() {
  local a_name="$1"
  shift
  local a_log_file="${OUT_DIR}/${a_name}.log"
  echo "[EVIDENCE] >>> ${a_name}" | tee -a "${OUT_DIR}/_runner.log"
  (
    cd "${ROOT_DIR}"
    "$@"
  ) 2>&1 | tee "${a_log_file}"
}

run_step sse_intrinsics bash tests/nextpas.core.simd.intrinsics.sse/BuildOrTest.sh test
run_step mmx_intrinsics bash tests/nextpas.core.simd.intrinsics.mmx/BuildOrTest.sh test
run_step coverage bash tests/nextpas.core.simd/BuildOrTest.sh coverage
run_step coverage_strict env SIMD_COVERAGE_STRICT_EXTRA=1 bash tests/nextpas.core.simd/BuildOrTest.sh coverage
run_step wiring_sync_strict env SIMD_WIRING_SYNC_STRICT_EXTRA=1 bash tests/nextpas.core.simd/BuildOrTest.sh wiring-sync
run_step advanced bash tests/nextpas.core.simd/BuildOrTest.sh test --suite=TTestCase_AdvancedAlgorithms
run_step nonx86_ieee754 bash tests/nextpas.core.simd/BuildOrTest.sh nonx86-ieee754
run_step backend_bench bash tests/nextpas.core.simd/run_backend_benchmarks.sh
if [[ "${ENABLE_QEMU_EXPERIMENTAL}" != "0" ]]; then
  run_step qemu_experimental_report bash tests/nextpas.core.simd/BuildOrTest.sh qemu-experimental-report
  run_step qemu_experimental_baseline bash tests/nextpas.core.simd/BuildOrTest.sh qemu-experimental-baseline-check
else
  {
    echo "[QEMU-EXPERIMENTAL] SKIP (set SIMD_EVIDENCE_QEMU_EXPERIMENTAL=1 to enable)"
  } > "${OUT_DIR}/qemu_experimental_report.log"
  {
    echo "[QEMU-EXPERIMENTAL] SKIP (set SIMD_EVIDENCE_QEMU_EXPERIMENTAL=1 to enable)"
  } > "${OUT_DIR}/qemu_experimental_baseline.log"
fi
run_step perf_smoke env SIMD_PERF_VECTOR_ASM=auto bash tests/nextpas.core.simd/BuildOrTest.sh perf-smoke
run_step gate_strict env SIMD_GATE_REQUIRE_WINDOWS_EVIDENCE=0 SIMD_GATE_QEMU_CPUINFO_NONX86_EVIDENCE=1 SIMD_GATE_EXPERIMENTAL_TESTS=0 SIMD_GATE_PERF_SMOKE=1 SIMD_PERF_VECTOR_ASM=auto bash tests/nextpas.core.simd/BuildOrTest.sh gate-strict
run_step gate_summary_json env SIMD_GATE_SUMMARY_JSON=1 bash tests/nextpas.core.simd/BuildOrTest.sh gate-summary
run_step freeze_status_linux env SIMD_FREEZE_REQUIRE_QEMU_CPUINFO_NONX86_EVIDENCE=1 SIMD_FREEZE_GATE_SUMMARY_FILE="${OUTPUT_ROOT}/logs/gate_summary.md" SIMD_FREEZE_STATUS_JSON_FILE="${OUTPUT_ROOT}/logs/freeze_status.json" bash tests/nextpas.core.simd/BuildOrTest.sh freeze-status-linux

{
  echo "# SIMD Linux Evidence (${TS})"
  echo
  echo "- Root: ${ROOT_DIR}"
  echo "- Output: ${OUT_DIR}"
  echo
  echo "## SSE intrinsics"
  grep -E "\[BUILD\]|\[CHECK\]|\[TEST\]|\[LEAK\]" "${OUT_DIR}/sse_intrinsics.log" || true
  echo
  echo "## MMX intrinsics"
  grep -E "\[BUILD\]|\[CHECK\]|\[TEST\]|\[LEAK\]" "${OUT_DIR}/mmx_intrinsics.log" || true
  echo
  echo "## Coverage"
  grep -E "declared=|\[COVERAGE\]" "${OUT_DIR}/coverage.log" || true
  echo
  echo "## Coverage Strict"
  grep -E "declared=|\[COVERAGE\]" "${OUT_DIR}/coverage_strict.log" || true
  echo
  echo "## Wiring Sync Strict"
  grep -E "\[WIRING-SYNC\]|WIRING_SYNC_SUMMARY" "${OUT_DIR}/wiring_sync_strict.log" || true
  echo
  echo "## AdvancedAlgorithms"
  grep -E "\[BUILD\]|\[TEST\]|\[LEAK\]" "${OUT_DIR}/advanced.log" || true
  echo
  echo "## NonX86 IEEE754"
  grep -E "\[BUILD\]|\[TEST\]|\[LEAK\]|No non-x86 backend available" "${OUT_DIR}/nonx86_ieee754.log" || true
  echo
  echo "## Backend Benchmarks"
  grep -E "\[BENCH\]|^\[SKIP\]|^===|Average Speedup:" "${OUT_DIR}/backend_bench.log" || true
  echo
  echo "## QEMU Experimental Report"
  grep -E "\[QEMU-EXPERIMENTAL|SKIP|output=|platform_rows=|parsed_errors=" "${OUT_DIR}/qemu_experimental_report.log" || true
  echo
  echo "## QEMU Experimental Baseline"
  grep -E "\[QEMU-EXPERIMENTAL-BASELINE|SKIP|errors:|warnings:|OK" "${OUT_DIR}/qemu_experimental_baseline.log" || true
  echo
  echo "## Perf Smoke"
  grep -E "\[BUILD\]|\[TEST\]|\[LEAK\]|\[PERF\]" "${OUT_DIR}/perf_smoke.log" || true
  echo
  echo "## Gate Strict"
  grep -E "\[GATE\]|Total:|Passed:|Failed:|\[CHECK\]" "${OUT_DIR}/gate_strict.log" || true
  echo
  echo "## Gate Summary JSON"
  grep -E "\[GATE-SUMMARY\]|json=" "${OUT_DIR}/gate_summary_json.log" || true
  echo
  echo "## Freeze Status Linux"
  grep -E "\[FREEZE\]|ready=|next-actions" "${OUT_DIR}/freeze_status_linux.log" || true
} > "${OUT_DIR}/summary.md"

echo "[EVIDENCE] DONE: ${OUT_DIR}"
echo "[EVIDENCE] SUMMARY: ${OUT_DIR}/summary.md"
