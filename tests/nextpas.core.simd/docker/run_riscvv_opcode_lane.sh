#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../../.." && pwd)"
LOG_ROOT="${ROOT_DIR}/tests/nextpas.core.simd/logs"
BUILD_IMAGE_SCRIPT="${ROOT_DIR}/tests/nextpas.core.simd/docker/build_riscv64_rvv_image.sh"

IMAGE_BASE="${SIMD_QEMU_RVV_IMAGE_BASE:-fafafa-core-simd-test-rvv}"
IMAGE_TAG="${IMAGE_BASE}:riscv64"
BUILD_IMAGE="${SIMD_RVV_BUILD_IMAGE:-0}"
DOCKER_RETRIES="${SIMD_QEMU_RETRIES:-3}"
LANE_SUITE="${SIMD_RVV_LANE_SUITE:-TTestCase_NonX86IEEE754}"
SKIP_SUITE="${SIMD_RVV_LANE_SKIP_SUITE:-0}"
SKIP_BENCH="${SIMD_RVV_LANE_SKIP_BENCH:-0}"
USE_PREBUILT_COMPILER="${SIMD_RVV_USE_PREBUILT_COMPILER:-1}"
PREBUILT_COMPILER_PATH="${SIMD_RVV_PREBUILT_COMPILER_PATH:-/opt/fpcupdeluxe/fpcsrc/compiler/ppcrossrv64_v}"
PREBUILT_QEMU_X86_64_STATIC="${SIMD_RVV_PREBUILT_QEMU_X86_64_STATIC:-/usr/bin/qemu-x86_64-static}"
PREBUILT_UNITS_HOST_PATH="${SIMD_RVV_PREBUILT_UNITS_HOST_PATH:-/opt/fpcupdeluxe/fpc-rvv-units/riscv64-linux}"
PREBUILT_COMPILER_PREFIX="${SIMD_RVV_PREBUILT_COMPILER_PREFIX:-riscv64-linux-gnu-}"
PREBUILT_CPU="${SIMD_RVV_PREBUILT_CPU:-RV64GCV}"

BASE_DEFINE="${SIMD_QEMU_EXPERIMENTAL_DEFINE:--dFAFAFA_SIMD_EXPERIMENTAL_BACKEND_ASM}"
RISCV_EXPERIMENTAL_DEFINE="${SIMD_QEMU_EXPERIMENTAL_RISCVV_FEATURE_DEFINE:--dSIMD_EXPERIMENTAL_RISCVV}"
RISCV_BACKEND_DEFINE="${SIMD_QEMU_EXPERIMENTAL_RISCV64_DEFINE:--dFAFAFA_SIMD_ENABLE_RISCVV_ASM}"
RISCV_COMPILER_DEFINE="${SIMD_QEMU_EXPERIMENTAL_RISCV64_COMPILER_DEFINE:--dFAFAFA_SIMD_RISCVV_ASM_COMPILER_READY}"
RISCV_OPCODE_DEFINE="${SIMD_QEMU_EXPERIMENTAL_RISCV64_OPCODE_DEFINE:--dFAFAFA_SIMD_RISCVV_ASM_OPCODE_READY}"
LANE_DEFINES="${SIMD_RVV_LANE_DEFINES:-${RISCV_EXPERIMENTAL_DEFINE} ${BASE_DEFINE} ${RISCV_BACKEND_DEFINE} ${RISCV_COMPILER_DEFINE} ${RISCV_OPCODE_DEFINE}}"
COMPILE_DEFINES="${SIMD_RVV_COMPILE_DEFINES:-${LANE_DEFINES}}"
# Keep runtime on the same default opcode-ready contract as compile-only.
# Callers that intentionally want a weaker runtime lane can still override
# SIMD_RVV_RUNTIME_DEFINES explicitly.
RUNTIME_DEFINES="${SIMD_RVV_RUNTIME_DEFINES:-${LANE_DEFINES}}"
COMPILE_TARGET="${SIMD_RVV_COMPILE_TARGET:-project}"
COMPILE_USE_PREBUILT_COMPILER="${SIMD_RVV_COMPILE_USE_PREBUILT_COMPILER:-${USE_PREBUILT_COMPILER}}"
# Keep suite/bench on the same default RVV-capable compiler as compile-only.
# Callers can still opt out per step with explicit SIMD_RVV_*_USE_PREBUILT_COMPILER=0.
SUITE_USE_PREBUILT_COMPILER="${SIMD_RVV_SUITE_USE_PREBUILT_COMPILER:-${USE_PREBUILT_COMPILER}}"
BENCH_USE_PREBUILT_COMPILER="${SIMD_RVV_BENCH_USE_PREBUILT_COMPILER:-${USE_PREBUILT_COMPILER}}"
RVV_OPCODE_SMOKE_SCRIPT="${ROOT_DIR}/tests/nextpas.core.simd/docker/run_rvv_opcode_smoke.sh"

TS="$(date +%Y%m%d-%H%M%S)"
REPORT_DIR="${LOG_ROOT}/rvv-opcode-lane-${TS}"
SUMMARY_FILE="${REPORT_DIR}/summary.md"
COMPILE_LOG="${REPORT_DIR}/compile_only.log"
SUITE_LOG="${REPORT_DIR}/suite.log"
BENCH_LOG="${REPORT_DIR}/bench.log"
PREBUILT_PREP_SCRIPT="${REPORT_DIR}/prebuilt_fpc_env.sh"
PREBUILT_PREP_SCRIPT_CONTAINER=""

mkdir -p "${REPORT_DIR}"

run_with_retry() {
  local aMax
  local aDesc
  local LAttempt
  local LRC

  aMax="${1}"
  shift
  aDesc="${1}"
  shift
  LAttempt=1

  while true; do
    set +e
    "$@"
    LRC=$?
    set -e

    if (( LRC == 0 )); then
      return 0
    fi
    if (( LAttempt >= aMax )); then
      echo "[RVV-LANE] ERROR: ${aDesc} failed after ${LAttempt} attempt(s), rc=${LRC}"
      return "${LRC}"
    fi
    echo "[RVV-LANE] WARN: ${aDesc} failed rc=${LRC}, retry ${LAttempt}/${aMax} ..."
    sleep $((LAttempt * 3))
    LAttempt=$((LAttempt + 1))
  done
}

prepare_prebuilt_compiler_mode() {
  if [[ "${USE_PREBUILT_COMPILER}" == "0" ]]; then
    return 0
  fi

  if [[ -z "${PREBUILT_COMPILER_PATH}" ]]; then
    echo "[RVV-LANE] ERROR: SIMD_RVV_USE_PREBUILT_COMPILER=1 but SIMD_RVV_PREBUILT_COMPILER_PATH is empty"
    exit 2
  fi
  if [[ ! -f "${PREBUILT_COMPILER_PATH}" ]]; then
    echo "[RVV-LANE] ERROR: prebuilt compiler not found: ${PREBUILT_COMPILER_PATH}"
    exit 2
  fi
  if [[ ! -x "${PREBUILT_COMPILER_PATH}" ]]; then
    echo "[RVV-LANE] ERROR: prebuilt compiler is not executable: ${PREBUILT_COMPILER_PATH}"
    exit 2
  fi
  if [[ ! -f "${PREBUILT_QEMU_X86_64_STATIC}" ]]; then
    echo "[RVV-LANE] ERROR: qemu-x86_64-static not found: ${PREBUILT_QEMU_X86_64_STATIC}"
    exit 2
  fi
  if [[ ! -x "${PREBUILT_QEMU_X86_64_STATIC}" ]]; then
    echo "[RVV-LANE] ERROR: qemu-x86_64-static is not executable: ${PREBUILT_QEMU_X86_64_STATIC}"
    exit 2
  fi
  if [[ ! -d "${PREBUILT_UNITS_HOST_PATH}" ]]; then
    echo "[RVV-LANE] ERROR: prebuilt units dir not found: ${PREBUILT_UNITS_HOST_PATH}"
    exit 2
  fi

  cat > "${PREBUILT_PREP_SCRIPT}" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [[ ! -f /host/ppcrossrv64 ]]; then
  echo "[RVV-LANE] ERROR: missing mounted compiler at /host/ppcrossrv64"
  exit 2
fi
if [[ ! -f /host/qemu-x86_64-static ]]; then
  echo "[RVV-LANE] ERROR: missing mounted qemu at /host/qemu-x86_64-static"
  exit 2
fi
if [[ ! -d /host/fpc-units ]]; then
  echo "[RVV-LANE] ERROR: missing mounted units dir at /host/fpc-units"
  exit 2
fi

install -m 755 /host/ppcrossrv64 /tmp/ppcrossrv64
install -m 755 /host/qemu-x86_64-static /tmp/qemu-x86_64-static

cat > /tmp/fpc <<'__RVV_FPC_WRAPPER__'
#!/usr/bin/env bash
set -euo pipefail
: "${SIMD_RVV_PREBUILT_COMPILER_PREFIX:=riscv64-linux-gnu-}"
: "${SIMD_RVV_PREBUILT_DISABLE_FPC_CFG:=1}"
: "${SIMD_RVV_PREBUILT_CPU:=RV64GCV}"
LNoCfg=()
if [[ "${SIMD_RVV_PREBUILT_DISABLE_FPC_CFG}" != "0" ]]; then
  LNoCfg+=("-n")
fi
exec /tmp/qemu-x86_64-static /tmp/ppcrossrv64 "${LNoCfg[@]}" "-Cp${SIMD_RVV_PREBUILT_CPU}" "-XP${SIMD_RVV_PREBUILT_COMPILER_PREFIX}" -Fu/host/fpc-units -Fu/host/fpc-units/* "$@"
__RVV_FPC_WRAPPER__
chmod +x /tmp/fpc
export PATH="/tmp:${PATH}"
echo "[RVV-LANE] prebuilt wrapper active"
echo "[RVV-LANE] fpc version=$(fpc -iV) target=$(fpc -iTP)-$(fpc -iTO)"
EOF
  chmod +x "${PREBUILT_PREP_SCRIPT}"
  PREBUILT_PREP_SCRIPT_CONTAINER="/work/${PREBUILT_PREP_SCRIPT#"${ROOT_DIR}/"}"
}

run_container_step() {
  local aDesc
  local aLog
  local aCommand
  local aUsePrebuilt
  local LContainerCommand
  local -a LDockerArgs

  aDesc="${1}"
  aLog="${2}"
  aCommand="${3}"
  aUsePrebuilt="${4:-${USE_PREBUILT_COMPILER}}"

  echo "[RVV-LANE] STEP ${aDesc}"
  : >"${aLog}"

  LDockerArgs=(
    --rm
    --platform linux/riscv64
    --user "$(id -u):$(id -g)"
    --volume "${ROOT_DIR}:/work"
    --workdir "/work"
  )

  LContainerCommand="set -euo pipefail; "
  if [[ "${aUsePrebuilt}" != "0" ]]; then
    LDockerArgs+=(
      --volume "${PREBUILT_COMPILER_PATH}:/host/ppcrossrv64:ro"
      --volume "${PREBUILT_QEMU_X86_64_STATIC}:/host/qemu-x86_64-static:ro"
      --volume "${PREBUILT_UNITS_HOST_PATH}:/host/fpc-units:ro"
      --env "SIMD_RVV_PREBUILT_COMPILER_PREFIX=${PREBUILT_COMPILER_PREFIX}"
      --env "SIMD_RVV_PREBUILT_DISABLE_FPC_CFG=1"
      --env "SIMD_RVV_PREBUILT_CPU=${PREBUILT_CPU}"
    )
    LContainerCommand+="source '${PREBUILT_PREP_SCRIPT_CONTAINER}'; "
  fi
  LContainerCommand+="${aCommand}"

  set +e
  run_with_retry "${DOCKER_RETRIES}" "${aDesc}" \
    docker run "${LDockerArgs[@]}" \
      "${IMAGE_TAG}" \
      bash -lc "${LContainerCommand}" 2>&1 | tee "${aLog}"
  local LRC=$?
  set -e

  return "${LRC}"
}

echo "[RVV-LANE] Repo: ${ROOT_DIR}"
echo "[RVV-LANE] Report: ${REPORT_DIR}"
echo "[RVV-LANE] Image: ${IMAGE_TAG}"
echo "[RVV-LANE] Compile target: ${COMPILE_TARGET}"
echo "[RVV-LANE] Compile defines: ${COMPILE_DEFINES}"
echo "[RVV-LANE] Runtime defines: ${RUNTIME_DEFINES}"
echo "[RVV-LANE] Prebuilt per-step: compile=${COMPILE_USE_PREBUILT_COMPILER} suite=${SUITE_USE_PREBUILT_COMPILER} bench=${BENCH_USE_PREBUILT_COMPILER}"
if [[ "${COMPILE_USE_PREBUILT_COMPILER}" != "0" || "${SUITE_USE_PREBUILT_COMPILER}" != "0" || "${BENCH_USE_PREBUILT_COMPILER}" != "0" ]]; then
  echo "[RVV-LANE] Prebuilt compiler: ENABLED"
  echo "[RVV-LANE]   compiler: ${PREBUILT_COMPILER_PATH}"
  echo "[RVV-LANE]   qemu: ${PREBUILT_QEMU_X86_64_STATIC}"
  echo "[RVV-LANE]   units(host): ${PREBUILT_UNITS_HOST_PATH}"
  echo "[RVV-LANE]   prefix: ${PREBUILT_COMPILER_PREFIX}"
  echo "[RVV-LANE]   cpu: ${PREBUILT_CPU}"
fi

if [[ "${BUILD_IMAGE}" != "0" ]]; then
  if [[ ! -x "${BUILD_IMAGE_SCRIPT}" ]]; then
    echo "[RVV-LANE] Missing build-image script: ${BUILD_IMAGE_SCRIPT}"
    exit 2
  fi
  echo "[RVV-LANE] Build custom RVV image (SIMD_RVV_BUILD_IMAGE=${BUILD_IMAGE})"
  bash "${BUILD_IMAGE_SCRIPT}"
fi

if ! docker image inspect "${IMAGE_TAG}" >/dev/null 2>&1; then
  echo "[RVV-LANE] Missing image: ${IMAGE_TAG}"
  echo "[RVV-LANE] Hint: set SIMD_RVV_BUILD_IMAGE=1 or set SIMD_QEMU_RVV_IMAGE_BASE to an existing image base."
  exit 2
fi

if [[ "${COMPILE_USE_PREBUILT_COMPILER}" != "0" || "${SUITE_USE_PREBUILT_COMPILER}" != "0" || "${BENCH_USE_PREBUILT_COMPILER}" != "0" ]]; then
  prepare_prebuilt_compiler_mode
fi

if [[ "${COMPILE_TARGET}" == "smoke" ]]; then
  if [[ ! -x "${RVV_OPCODE_SMOKE_SCRIPT}" ]]; then
    echo "[RVV-LANE] Missing opcode smoke script: ${RVV_OPCODE_SMOKE_SCRIPT}"
    exit 2
  fi
  COMPILE_CMD="SIMD_FPC_EXTRA_DEFINES='${COMPILE_DEFINES}' bash tests/nextpas.core.simd/docker/run_rvv_opcode_smoke.sh"
elif [[ "${COMPILE_TARGET}" == "project" ]]; then
  COMPILE_CMD="SIMD_RUN_ONLY_BUILD=1 SIMD_FPC_EXTRA_DEFINES='${COMPILE_DEFINES}' bash tests/nextpas.core.simd/docker/run_fpc_tests.sh"
else
  echo "[RVV-LANE] Unknown compile target: ${COMPILE_TARGET} (expect: smoke|project)"
  exit 2
fi

if ! run_container_step "compile-only(${COMPILE_TARGET})" "${COMPILE_LOG}" "${COMPILE_CMD}" "${COMPILE_USE_PREBUILT_COMPILER}"; then
  {
    echo "# RVV Opcode Lane"
    echo
    echo "- generated_at: $(date -Is)"
    echo "- image: \`${IMAGE_TAG}\`"
    echo "- compile_target: \`${COMPILE_TARGET}\`"
    echo "- compile_defines: \`${COMPILE_DEFINES}\`"
    echo "- runtime_defines: \`${RUNTIME_DEFINES}\`"
    echo "- compile_only: FAIL"
    echo "- compile_log: \`${COMPILE_LOG}\`"
  } > "${SUMMARY_FILE}"
  echo "[RVV-LANE] FAILED at compile-only"
  echo "[RVV-LANE] Summary: ${SUMMARY_FILE}"
  exit 1
fi

# Keep runtime suite/bench isolated from compile-only artifacts (especially mixed-toolchain fpcunit outputs).
if [[ "${SKIP_SUITE}" == "0" || "${SKIP_BENCH}" == "0" ]]; then
  rm -rf "${ROOT_DIR}/tests/nextpas.core.simd/bin2" "${ROOT_DIR}/tests/nextpas.core.simd/lib2"
fi

SUITE_STATUS="SKIP"
if [[ "${SKIP_SUITE}" == "0" ]]; then
  SUITE_CMD="SIMD_FPC_EXTRA_DEFINES='${RUNTIME_DEFINES}' bash tests/nextpas.core.simd/docker/run_fpc_tests.sh --suite=${LANE_SUITE}"
  if run_container_step "suite-${LANE_SUITE}" "${SUITE_LOG}" "${SUITE_CMD}" "${SUITE_USE_PREBUILT_COMPILER}"; then
    SUITE_STATUS="PASS"
  else
    SUITE_STATUS="FAIL"
  fi
fi

BENCH_STATUS="SKIP"
if [[ "${SKIP_BENCH}" == "0" && "${SUITE_STATUS}" != "FAIL" ]]; then
  BENCH_CMD="SIMD_BENCH_FPC_EXTRA_DEFINES='${RUNTIME_DEFINES}' bash tests/nextpas.core.simd/run_backend_benchmarks.sh"
  if run_container_step "bench" "${BENCH_LOG}" "${BENCH_CMD}" "${BENCH_USE_PREBUILT_COMPILER}"; then
    BENCH_STATUS="PASS"
  else
    BENCH_STATUS="FAIL"
  fi
fi

{
  echo "# RVV Opcode Lane"
  echo
  echo "- generated_at: $(date -Is)"
  echo "- image: \`${IMAGE_TAG}\`"
  echo "- compile_target: \`${COMPILE_TARGET}\`"
  echo "- compile_defines: \`${COMPILE_DEFINES}\`"
  echo "- runtime_defines: \`${RUNTIME_DEFINES}\`"
  echo
  echo "## Layered Acceptance"
  echo
  echo "| Step | Status | Log |"
  echo "|---|---|---|"
  echo "| compile-only | PASS | \`${COMPILE_LOG}\` |"
  if [[ "${SKIP_SUITE}" == "0" ]]; then
    echo "| suite (${LANE_SUITE}) | ${SUITE_STATUS} | \`${SUITE_LOG}\` |"
  else
    echo "| suite (${LANE_SUITE}) | SKIP | \`${SUITE_LOG}\` |"
  fi
  if [[ "${SKIP_BENCH}" == "0" ]]; then
    echo "| bench | ${BENCH_STATUS} | \`${BENCH_LOG}\` |"
  else
    echo "| bench | SKIP | \`${BENCH_LOG}\` |"
  fi
} > "${SUMMARY_FILE}"

if [[ "${SUITE_STATUS}" == "FAIL" || "${BENCH_STATUS}" == "FAIL" ]]; then
  echo "[RVV-LANE] FAILED"
  echo "[RVV-LANE] Summary: ${SUMMARY_FILE}"
  exit 1
fi

echo "[RVV-LANE] PASS"
echo "[RVV-LANE] Summary: ${SUMMARY_FILE}"
