#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
OUTPUT_ROOT="${SIMD_OUTPUT_ROOT:-${SCRIPT_DIR}}"
REQUESTED_BACKEND="${1:-auto}"
TS="$(date +%Y%m%d-%H%M%S)"
REQUESTED_RUNNER="${SIMD_NATIVE_EVIDENCE_RUNNER:-auto}"
ENABLE_BACKEND_ASM="${SIMD_NATIVE_EVIDENCE_ENABLE_BACKEND_ASM:-0}"

normalize_arch() {
  local aRawArch

  aRawArch="$(uname -m 2>/dev/null || echo unknown)"
  case "${aRawArch}" in
    aarch64|arm64)
      echo "arm64"
      ;;
    riscv64)
      echo "riscv64"
      ;;
    *)
      echo "${aRawArch}"
      ;;
  esac
}

resolve_backend() {
  local aRequested
  local aArch

  aRequested="${1:-auto}"
  aArch="${2:-unknown}"

  case "${aRequested}" in
    auto)
      case "${aArch}" in
        arm64)
          echo "neon"
          ;;
        riscv64)
          echo "riscvv"
          ;;
        *)
          echo ""
          ;;
      esac
      ;;
    neon|riscvv)
      echo "${aRequested}"
      ;;
    *)
      echo ""
      ;;
  esac
}

version_ge() {
  local aLeft
  local aRight

  aLeft="${1:-0}"
  aRight="${2:-0}"
  if [[ "${aLeft}" == "${aRight}" ]]; then
    return 0
  fi
  [[ "$(printf '%s\n%s\n' "${aRight}" "${aLeft}" | sort -V | tail -n 1)" == "${aLeft}" ]]
}

resolve_runner() {
  local aRequested
  local aBackend
  local aEnableBackendAsm

  aRequested="${1:-auto}"
  aBackend="${2:-}"
  aEnableBackendAsm="${3:-0}"

  case "${aRequested}" in
    auto)
      if [[ "${aEnableBackendAsm}" == "1" ]]; then
        echo "direct-fpc"
      else
        echo "canonical"
      fi
      ;;
    canonical|direct-fpc)
      echo "${aRequested}"
      ;;
    *)
      echo ""
      ;;
  esac
}

ARCH="$(normalize_arch)"
BACKEND="$(resolve_backend "${REQUESTED_BACKEND}" "${ARCH}")"
if [[ -z "${BACKEND}" ]]; then
  echo "[NATIVE-EVIDENCE] Unsupported host/backend combination: host=${ARCH}, requested=${REQUESTED_BACKEND}"
  echo "[NATIVE-EVIDENCE] Supported: arm64->neon, riscv64->riscvv, or explicit neon/riscvv on a matching native host"
  exit 2
fi

RUNNER_KIND="$(resolve_runner "${REQUESTED_RUNNER}" "${BACKEND}" "${ENABLE_BACKEND_ASM}")"
if [[ -z "${RUNNER_KIND}" ]]; then
  echo "[NATIVE-EVIDENCE] Unsupported runner mode: ${REQUESTED_RUNNER}"
  echo "[NATIVE-EVIDENCE] Supported runners: auto, canonical, direct-fpc"
  exit 2
fi

case "${BACKEND}" in
  neon)
    if [[ "${ARCH}" != "arm64" ]]; then
      echo "[NATIVE-EVIDENCE] neon evidence requires arm64 native host; got ${ARCH}"
      exit 2
    fi
    BACKEND_ENV_NAME="SIMD_ENABLE_NEON_BACKEND"
    BACKEND_ENV_VALUE="1"
    BACKEND_LABEL="NEON"
    ;;
  riscvv)
    if [[ "${ARCH}" != "riscv64" ]]; then
      echo "[NATIVE-EVIDENCE] riscvv evidence requires riscv64 native host; got ${ARCH}"
      exit 2
    fi
    BACKEND_ENV_NAME="SIMD_ENABLE_RISCVV_BACKEND"
    BACKEND_ENV_VALUE="1"
    BACKEND_LABEL="RISCVV"
    ;;
  *)
    echo "[NATIVE-EVIDENCE] Internal error: unsupported backend ${BACKEND}"
    exit 2
    ;;
esac

BACKEND_ASM_DEFINES=""
case "${BACKEND}" in
  neon)
    BACKEND_ASM_DEFINES="-dFAFAFA_SIMD_EXPERIMENTAL_BACKEND_ASM -dFAFAFA_SIMD_ENABLE_NEON_ASM -dFAFAFA_SIMD_NEON_ASM_COMPILER_READY"
    ;;
  riscvv)
    BACKEND_ASM_DEFINES="-dFAFAFA_SIMD_EXPERIMENTAL_BACKEND_ASM -dFAFAFA_SIMD_ENABLE_RISCVV_ASM -dFAFAFA_SIMD_RISCVV_ASM_COMPILER_READY"
    ;;
esac

OUT_DIR="${OUTPUT_ROOT}/logs/native-evidence-${BACKEND}-${TS}"
RUN_OUTPUT_ROOT="${OUT_DIR}/run"
RUN_TMPDIR="${OUT_DIR}/tmp"
SUMMARY_FILE="${OUT_DIR}/summary.md"
ENV_FILE="${OUT_DIR}/environment.txt"
mkdir -p "${OUT_DIR}" "${RUN_OUTPUT_ROOT}" "${RUN_TMPDIR}"

FPC_VERSION="$(fpc -iV 2>/dev/null || true)"
LAZBUILD_PATH="$(command -v lazbuild || true)"
LAZBUILD_HAS_OPT="0"
if [[ -n "${LAZBUILD_PATH}" ]]; then
  if "${LAZBUILD_PATH}" --help 2>&1 | grep -q -- '--opt'; then
    LAZBUILD_HAS_OPT="1"
  fi
fi

if [[ "${RUNNER_KIND}" == "direct-fpc" && "${ENABLE_BACKEND_ASM}" == "1" ]]; then
  if [[ -z "${FPC_VERSION}" ]]; then
    echo "[NATIVE-EVIDENCE] direct-fpc backend-asm mode requires a working fpc in PATH"
    exit 2
  fi
  if ! version_ge "${FPC_VERSION}" "3.3.1"; then
    echo "[NATIVE-EVIDENCE] backend asm evidence for ${BACKEND} requires FPC >= 3.3.1; got ${FPC_VERSION}"
    exit 2
  fi
fi

run_step() {
  local aName
  local aLogFile

  aName="${1:-}"
  shift || true
  aLogFile="${OUT_DIR}/${aName}.log"

  echo "[NATIVE-EVIDENCE] >>> ${aName}" | tee -a "${OUT_DIR}/_runner.log"
  (
    cd "${ROOT_DIR}"
    env \
      TMPDIR="${RUN_TMPDIR}" \
      FAFAFA_BUILD_MODE="${FAFAFA_BUILD_MODE:-Release}" \
      SIMD_OUTPUT_ROOT="${RUN_OUTPUT_ROOT}" \
      "${BACKEND_ENV_NAME}=${BACKEND_ENV_VALUE}" \
      "$@"
  ) 2>&1 | tee "${aLogFile}"
}

{
  echo "host_arch=${ARCH}"
  echo "backend=${BACKEND}"
  echo "backend_label=${BACKEND_LABEL}"
  echo "output_root=${RUN_OUTPUT_ROOT}"
  echo "tmpdir=${RUN_TMPDIR}"
  echo "fa_build_mode=${FAFAFA_BUILD_MODE:-Release}"
  echo "runner_kind=${RUNNER_KIND}"
  echo "enable_backend_asm=${ENABLE_BACKEND_ASM}"
  echo "backend_asm_defines=${BACKEND_ASM_DEFINES}"
  echo "kernel=$(uname -srmo 2>/dev/null || true)"
  echo "fpc=$(command -v fpc || true)"
  echo "fpc_version=${FPC_VERSION}"
  echo "fpc_target_cpu=$(fpc -iTP 2>/dev/null || true)"
  echo "fpc_target_os=$(fpc -iTO 2>/dev/null || true)"
  echo "lazbuild=${LAZBUILD_PATH}"
  echo "lazbuild_has_opt=${LAZBUILD_HAS_OPT}"
} > "${ENV_FILE}"

if [[ "${RUNNER_KIND}" == "direct-fpc" ]]; then
  run_step list_suites \
    env "SIMD_FPC_EXTRA_DEFINES=${BACKEND_ASM_DEFINES}" \
    bash tests/nextpas.core.simd/docker/run_fpc_tests.sh --vector-asm --list-suites
  run_step dispatch_publicabi \
    env "SIMD_FPC_EXTRA_DEFINES=${BACKEND_ASM_DEFINES}" \
    bash tests/nextpas.core.simd/docker/run_fpc_tests.sh --vector-asm --suite=TTestCase_DispatchAPI,TTestCase_PublicAbi
  run_step runtime_parity \
    env "SIMD_FPC_EXTRA_DEFINES=${BACKEND_ASM_DEFINES}" \
    bash tests/nextpas.core.simd/docker/run_fpc_tests.sh --vector-asm --suite=TTestCase_NonX86BackendParity,TTestCase_DataPlane
  run_step build_smoke \
    env "SIMD_RUN_ONLY_BUILD=1" "SIMD_FPC_EXTRA_DEFINES=${BACKEND_ASM_DEFINES}" \
    bash tests/nextpas.core.simd/docker/run_fpc_tests.sh --vector-asm --suite=TTestCase_DispatchAPI,TTestCase_PublicAbi
else
  run_step list_suites bash tests/nextpas.core.simd/BuildOrTest.sh test --list-suites
  run_step dispatch_publicabi bash tests/nextpas.core.simd/BuildOrTest.sh test --suite=TTestCase_DispatchAPI,TTestCase_PublicAbi
  run_step runtime_parity bash tests/nextpas.core.simd/BuildOrTest.sh test --suite=TTestCase_NonX86BackendParity,TTestCase_DataPlane
  run_step impl_audit_nonx86 bash tests/nextpas.core.simd/BuildOrTest.sh impl-audit-nonx86
fi

if [[ "${SIMD_NATIVE_EVIDENCE_INCLUDE_BENCH:-0}" == "1" ]]; then
  run_step backend_bench bash tests/nextpas.core.simd/run_backend_benchmarks.sh
fi

{
  echo "# SIMD Non-X86 Native Evidence (${TS})"
  echo
  echo "- Root: ${ROOT_DIR}"
  echo "- Host Arch: ${ARCH}"
  echo "- Backend: ${BACKEND_LABEL}"
  echo "- Output Root: ${RUN_OUTPUT_ROOT}"
  echo "- Environment: ${ENV_FILE}"
  echo
  echo "## list-suites"
  grep -E "\[BUILD\]|\[TEST\]|\[LEAK\]|TTestCase_" "${OUT_DIR}/list_suites.log" || true
  echo
  echo "## DispatchAPI + PublicAbi"
  grep -E "\[BUILD\]|\[TEST\]|\[LEAK\]" "${OUT_DIR}/dispatch_publicabi.log" || true
  echo
  if [[ -f "${OUT_DIR}/runtime_parity.log" ]]; then
    echo "## Runtime Parity (TTestCase_NonX86BackendParity,TTestCase_DataPlane)"
    grep -E "\[BUILD\]|\[TEST\]|\[LEAK\]" "${OUT_DIR}/runtime_parity.log" || true
    echo
  fi
  if [[ -f "${OUT_DIR}/impl_audit_nonx86.log" ]]; then
    echo "## Implementation Audit"
    grep -E "\[NONX86-IMPL-AUDIT\]|NONX86_IMPL_AUDIT_SUMMARY|NONX86_HELPER_SEMANTICS_SUMMARY|WIRING_SYNC_SUMMARY|RISCVV_ABI_SHAPE_SUMMARY|NONX86_REGISTER_TRUTHFULNESS_SUMMARY|NONX86_NATIVE_EVIDENCE_SUMMARY|\[HELPER-SEMANTICS\]|\[WIRING-SYNC\]|\[RISCVV-ABI\]|\[REG-TRUTH\]|\[NONX86-NATIVE-VERIFY\]|\[BUILD\]|\[TEST\]|\[LEAK\]" "${OUT_DIR}/impl_audit_nonx86.log" || true
  fi
  if [[ -f "${OUT_DIR}/build_smoke.log" ]]; then
    echo "## Build Smoke"
    grep -E "\[FPC\]|\[BUILD\]|\[CHECK\]|\[TEST\]" "${OUT_DIR}/build_smoke.log" || true
  fi
  if [[ -f "${OUT_DIR}/backend_bench.log" ]]; then
    echo
    echo "## Backend Benchmarks"
    grep -E "\[BENCH\]|^===|Average Speedup:|^\[SKIP\]" "${OUT_DIR}/backend_bench.log" || true
  fi
} > "${SUMMARY_FILE}"

echo "[NATIVE-EVIDENCE] DONE: ${OUT_DIR}"
echo "[NATIVE-EVIDENCE] SUMMARY: ${SUMMARY_FILE}"
