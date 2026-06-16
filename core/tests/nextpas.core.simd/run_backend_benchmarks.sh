#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
OUTPUT_ROOT="${SIMD_OUTPUT_ROOT:-${SCRIPT_DIR}}"
TS="$(date +%Y%m%d-%H%M%S)"
OUT_DIR="${OUTPUT_ROOT}/logs/backend-bench-${TS}"
BIN_DIR="${OUT_DIR}/bin"
LIB_DIR="${OUT_DIR}/lib"
SUMMARY_FILE="${OUT_DIR}/summary.md"
RUNNER_LOG="${OUT_DIR}/runner.log"
HOST_ARCH="$(uname -m)"

mkdir -p "${BIN_DIR}" "${LIB_DIR}"

FPC_BIN="${FPC:-fpc}"
if ! command -v "${FPC_BIN}" >/dev/null 2>&1; then
  echo "[BENCH] SKIP (fpc not found)" | tee "${RUNNER_LOG}"
  exit 0
fi

BENCH_FPC_EXTRA_DEFINES_STRING="${SIMD_BENCH_FPC_EXTRA_DEFINES:-}"
BENCH_FPC_EXTRA_ARGS_STRING="${SIMD_BENCH_FPC_EXTRA_ARGS:-}"
BENCH_FPC_EXTRA_DEFINES=()
BENCH_FPC_EXTRA_ARGS=()

if [[ -n "${BENCH_FPC_EXTRA_DEFINES_STRING}" ]]; then
  read -r -a BENCH_FPC_EXTRA_DEFINES <<< "${BENCH_FPC_EXTRA_DEFINES_STRING}"
fi
if [[ -n "${BENCH_FPC_EXTRA_ARGS_STRING}" ]]; then
  read -r -a BENCH_FPC_EXTRA_ARGS <<< "${BENCH_FPC_EXTRA_ARGS_STRING}"
fi

should_skip_compile_failure() {
  local aName="$1"
  local aBuildLog="$2"

  if [[ ! -f "${aBuildLog}" ]]; then
    return 1
  fi

  case "${aName}" in
    AVX512_vs_AVX2)
      if grep -Eq 'Unrecognized opcode|Assembler syntax error|Unknown identifier "ZMM|Unknown identifier "K1"' "${aBuildLog}" && \
         grep -Eq 'fafafa\.core\.simd\.avx512|avx512\.facade\.inc' "${aBuildLog}"; then
        return 0
      fi
      ;;
  esac

  return 1
}

run_one() {
  local aSource="$1"
  local aName="$2"
  local LBase
  local LBuildLog
  local LRunLog
  local LBinary
  local LBuildRc
  local LRunRc

  LBase="${aSource%.lpr}"
  LBuildLog="${OUT_DIR}/${LBase}.build.log"
  LRunLog="${OUT_DIR}/${LBase}.run.log"
  LBinary="${BIN_DIR}/${LBase}"

  echo "[BENCH] >>> ${aName}" | tee -a "${RUNNER_LOG}"
  (
    cd "${SCRIPT_DIR}"
    "${FPC_BIN}" \
      -Mobjfpc -Sh -O3 \
      -Fi"${ROOT_DIR}/src" \
      -Fu"${ROOT_DIR}/src" \
      -Fu"${SCRIPT_DIR}" \
      -FE"${BIN_DIR}" \
      -FU"${LIB_DIR}" \
      "${BENCH_FPC_EXTRA_DEFINES[@]}" \
      "${BENCH_FPC_EXTRA_ARGS[@]}" \
      "${aSource}"
  ) >"${LBuildLog}" 2>&1 || LBuildRc=$?
  LBuildRc="${LBuildRc:-0}"

  if [[ "${LBuildRc}" -ne 0 ]]; then
    if should_skip_compile_failure "${aName}" "${LBuildLog}"; then
      echo "[BENCH] SKIP ${aName} (compiler does not support required backend opcodes)" | tee -a "${RUNNER_LOG}"
      tail -n 40 "${LBuildLog}" || true
      return 0
    fi
    echo "[BENCH] FAILED (compile rc=${LBuildRc}): ${aName}" | tee -a "${RUNNER_LOG}"
    tail -n 80 "${LBuildLog}" || true
    return "${LBuildRc}"
  fi

  if [[ ! -x "${LBinary}" && -x "${LBinary}.exe" ]]; then
    LBinary="${LBinary}.exe"
  fi
  if [[ ! -x "${LBinary}" ]]; then
    echo "[BENCH] FAILED (binary missing): ${aSource}" | tee -a "${RUNNER_LOG}"
    ls -la "${BIN_DIR}" || true
    return 1
  fi

  (
    cd "${OUT_DIR}"
    "${LBinary}"
  ) >"${LRunLog}" 2>&1 || LRunRc=$?
  LRunRc="${LRunRc:-0}"

  if grep -q '^\[SKIP\]' "${LRunLog}"; then
    echo "[BENCH] SKIP ${aName}" | tee -a "${RUNNER_LOG}"
  elif [[ "${LRunRc}" -ne 0 ]]; then
    echo "[BENCH] FAILED (run rc=${LRunRc}): ${aName}" | tee -a "${RUNNER_LOG}"
    tail -n 80 "${LRunLog}" || true
    return "${LRunRc}"
  else
    echo "[BENCH] PASS ${aName}" | tee -a "${RUNNER_LOG}"
  fi
}

run_one_from_test_binary() {
  local aName="$1"
  local LBuildLog
  local LRunLog
  local LBinary
  local LBuildRc
  local LRunRc

  LBuildLog="${OUT_DIR}/simd_test_binary.build.log"
  LRunLog="${OUT_DIR}/simd_test_binary.run.log"
  LBinary="${ROOT_DIR}/build/bin/nextpas.core.simd.test"

  echo "[BENCH] >>> ${aName}" | tee -a "${RUNNER_LOG}"

  (
    make -C "${SCRIPT_DIR}" bench-build FPC="${FPC_BIN}"
  ) >"${LBuildLog}" 2>&1 || LBuildRc=$?
  LBuildRc="${LBuildRc:-0}"

  if [[ "${LBuildRc}" -ne 0 ]]; then
    echo "[BENCH] FAILED (build rc=${LBuildRc}): ${aName}" | tee -a "${RUNNER_LOG}"
    tail -n 80 "${LBuildLog}" || true
    return "${LBuildRc}"
  fi

  if [[ ! -x "${LBinary}" ]]; then
    echo "[BENCH] FAILED (test binary missing): ${LBinary}" | tee -a "${RUNNER_LOG}"
    return 1
  fi

  (
    cd "${OUT_DIR}"
    "${LBinary}" --bench-only --vector-asm
  ) >"${LRunLog}" 2>&1 || LRunRc=$?
  LRunRc="${LRunRc:-0}"

  if [[ "${LRunRc}" -ne 0 ]]; then
    echo "[BENCH] FAILED (run rc=${LRunRc}): ${aName}" | tee -a "${RUNNER_LOG}"
    tail -n 80 "${LRunLog}" || true
    return "${LRunRc}"
  fi

  if ! grep -q 'SIMD Benchmark (x86_64/AVX2)' "${LRunLog}"; then
    echo "[BENCH] SKIP ${aName} (active backend is not AVX2)" | tee -a "${RUNNER_LOG}"
    tail -n 40 "${LRunLog}" || true
    return 0
  fi

  echo "[BENCH] PASS ${aName}" | tee -a "${RUNNER_LOG}"
}

append_benchmark_excerpt() {
  local aRunLog="$1"
  if [[ ! -f "${aRunLog}" ]]; then
    return 0
  fi

  awk '
    BEGIN { capture=0; blank_count=0 }
    /^=== SIMD Benchmark/ {
      capture=1
    }
    capture {
      print
      if ($0 == "") {
        blank_count++
        if (blank_count >= 2) {
          exit
        }
      } else {
        blank_count=0
      }
    }
  ' "${aRunLog}" || true
}

benchmark_report_name() {
  local aSource="$1"

  case "${aSource}" in
    bench_avx512_vs_avx2.lpr)
      echo "AVX512_vs_AVX2_Benchmark_Report.md"
      ;;
    bench_neon_vs_scalar.lpr)
      echo "NEON_vs_Scalar_Benchmark_Report.md"
      ;;
    bench_riscvv_vs_scalar.lpr)
      echo "RISCVV_vs_Scalar_Benchmark_Report.md"
      ;;
    *)
      echo ""
      ;;
  esac
}

append_markdown_heading_excerpt() {
  local aReportPath="$1"
  local aHeading="$2"

  if [[ ! -f "${aReportPath}" ]]; then
    return 0
  fi

  awk -v heading="${aHeading}" '
    $0 == heading {
      capture = 1
    }
    capture {
      if ($0 != heading && /^### /) {
        exit
      }
      print
    }
  ' "${aReportPath}" || true
}

append_report_summary_extras() {
  local aName="$1"
  local aReportPath="$2"

  if [[ ! -f "${aReportPath}" ]]; then
    return 0
  fi

  echo "- Markdown report: ${aReportPath}"

  case "${aName}" in
    NEON_vs_Scalar)
      echo "- Caveat carry-forward: AArch64 ABI caveat; measured workload only; not a blanket claim that NEON is always faster than scalar fallback."
      append_markdown_heading_excerpt "${aReportPath}" "### AArch64 ABI caveat"
      ;;
  esac
}

declare -a TARGETS
if [[ "${SIMD_BENCH_ALL_BACKENDS:-0}" != "0" ]]; then
  TARGETS=(
    "__simd_test_binary_avx2__:AVX2_vs_Scalar:^(x86_64|amd64)$"
    "bench_avx512_vs_avx2.lpr:AVX512_vs_AVX2:^(x86_64|amd64)$"
    "bench_neon_vs_scalar.lpr:NEON_vs_Scalar:^(aarch64|arm64)$"
    "bench_riscvv_vs_scalar.lpr:RISCVV_vs_Scalar:^riscv64$"
  )
else
  case "${HOST_ARCH}" in
    x86_64|amd64)
      TARGETS=(
        "__simd_test_binary_avx2__:AVX2_vs_Scalar:^(x86_64|amd64)$"
        "bench_avx512_vs_avx2.lpr:AVX512_vs_AVX2:^(x86_64|amd64)$"
      )
      ;;
    aarch64|arm64)
      TARGETS=("bench_neon_vs_scalar.lpr:NEON_vs_Scalar:^(aarch64|arm64)$")
      ;;
    riscv64)
      TARGETS=("bench_riscvv_vs_scalar.lpr:RISCVV_vs_Scalar:^riscv64$")
      ;;
    *)
      TARGETS=()
      ;;
  esac
fi

if [[ "${#TARGETS[@]}" -eq 0 ]]; then
  echo "[BENCH] SKIP (no benchmark target for host arch: $(uname -m))" | tee "${RUNNER_LOG}"
  exit 0
fi

for LTarget in "${TARGETS[@]}"; do
  IFS=':' read -r LSource LName LHostRegex <<< "${LTarget}"
  if [[ "${SIMD_BENCH_FORCE_COMPILE:-0}" == "0" ]] && ! [[ "${HOST_ARCH}" =~ ${LHostRegex} ]]; then
    echo "[BENCH] SKIP ${LName} (host arch ${HOST_ARCH} does not match ${LHostRegex})" | tee -a "${RUNNER_LOG}"
    continue
  fi
  if [[ "${LSource}" == "__simd_test_binary_avx2__" ]]; then
    run_one_from_test_binary "${LName}"
  else
    run_one "${LSource}" "${LName}"
  fi
done

if [[ -n "${BENCH_FPC_EXTRA_DEFINES_STRING}" ]]; then
  echo "[BENCH] extra-defines=${BENCH_FPC_EXTRA_DEFINES_STRING}" | tee -a "${RUNNER_LOG}"
fi
if [[ -n "${BENCH_FPC_EXTRA_ARGS_STRING}" ]]; then
  echo "[BENCH] extra-args=${BENCH_FPC_EXTRA_ARGS_STRING}" | tee -a "${RUNNER_LOG}"
fi

{
  echo "# SIMD Backend Benchmark Evidence (${TS})"
  echo
  echo "- Output: ${OUT_DIR}"
  echo "- Host: ${HOST_ARCH}"
  echo
  for LTarget in "${TARGETS[@]}"; do
    IFS=':' read -r LSource LName LHostRegex <<< "${LTarget}"
    echo "## ${LName}"
    if [[ "${LSource}" == "__simd_test_binary_avx2__" ]]; then
      echo "- Build log: ${OUT_DIR}/simd_test_binary.build.log"
      echo "- Run log: ${OUT_DIR}/simd_test_binary.run.log"
      append_benchmark_excerpt "${OUT_DIR}/simd_test_binary.run.log"
    else
      LBase="${LSource%.lpr}"
      if [[ -f "${OUT_DIR}/${LBase}.build.log" ]]; then
        echo "- Build log: ${OUT_DIR}/${LBase}.build.log"
        echo "- Run log: ${OUT_DIR}/${LBase}.run.log"
        append_benchmark_excerpt "${OUT_DIR}/${LBase}.run.log"
        LReportName="$(benchmark_report_name "${LSource}")"
        if [[ -n "${LReportName}" ]]; then
          append_report_summary_extras "${LName}" "${OUT_DIR}/${LReportName}"
        fi
      else
        echo "- SKIP: host arch ${HOST_ARCH} not in ${LHostRegex}"
      fi
    fi
    echo
  done
} > "${SUMMARY_FILE}"

echo "[BENCH] DONE: ${OUT_DIR}"
echo "[BENCH] SUMMARY: ${SUMMARY_FILE}"
