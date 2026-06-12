#!/usr/bin/env bash
set -euo pipefail

ACTION="${1:-test}"
shift || true

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CORE_ROOT="$(cd "${ROOT}/../.." && pwd)"
DEFAULT_OUTPUT_ROOT="${CORE_ROOT}/build/tests/nextpas.core.simd.cpuinfo"
OUTPUT_ROOT="${SIMD_OUTPUT_ROOT:-${DEFAULT_OUTPUT_ROOT}}"
FPC_BIN="${FPC_BIN:-${FPC:-fpc}}"
MODE="${FAFAFA_BUILD_MODE:-Release}"

TARGET_CPU="$("${FPC_BIN}" -iTP 2>/dev/null | tr '[:upper:]' '[:lower:]' || true)"
TARGET_OS="$("${FPC_BIN}" -iTO 2>/dev/null | tr '[:upper:]' '[:lower:]' || true)"
if [[ -z "${TARGET_CPU}" ]]; then
  TARGET_CPU="nativecpu"
fi
if [[ -z "${TARGET_OS}" ]]; then
  TARGET_OS="nativeos"
fi

TARGET_TAG="${TARGET_CPU}-${TARGET_OS}"
BIN_DIR="${OUTPUT_ROOT}/bin"
UNIT_DIR="${OUTPUT_ROOT}/lib/${TARGET_TAG}"
LOG_DIR="${OUTPUT_ROOT}/logs"
TARGET_LOG_DIR="${LOG_DIR}/${TARGET_TAG}"
RUNNER_NAME="nextpas.core.simd.cpuinfo.test"
PROJECT="${ROOT}/${RUNNER_NAME}.lpr"
RUNNER_BIN="${BIN_DIR}/${RUNNER_NAME}"
BUILD_LOG="${LOG_DIR}/build.txt"
TEST_LOG="${LOG_DIR}/test.txt"
TARGET_BUILD_LOG="${TARGET_LOG_DIR}/build.txt"
TARGET_TEST_LOG="${TARGET_LOG_DIR}/test.txt"

mkdir -p "${BIN_DIR}" "${UNIT_DIR}" "${LOG_DIR}" "${TARGET_LOG_DIR}"

usage() {
  cat <<'EOF'
Usage: BuildOrTest.sh [clean|build|check|test|log-layout-check|debug|release] [test-args...]

Supported actions:
  clean                             Remove cpuinfo runner outputs
  build                             Compile nextpas.core.simd.cpuinfo.test
  check                             Build and fail-close on SIMD cpuinfo warnings/hints
  test [runner args...]             Compile and run nextpas.core.simd.cpuinfo.test
  log-layout-check                  Require target + legacy cpuinfo logs to stay in sync
  debug                             Alias for test with FAFAFA_BUILD_MODE=Debug
  release                           Alias for test with FAFAFA_BUILD_MODE=Release

Examples:
  FAFAFA_BUILD_MODE=Release bash tests/nextpas.core.simd.cpuinfo/BuildOrTest.sh test --suite=TTestCase_PlatformSpecific
  FAFAFA_BUILD_MODE=Release bash tests/nextpas.core.simd.cpuinfo/BuildOrTest.sh log-layout-check
EOF
}

append_extra_defines() {
  local -n a_fpc_args_ref=$1
  local l_extra
  local -a l_extra_parts=()

  l_extra="${SIMD_FPC_EXTRA_DEFINES:-}"
  if [[ -z "${l_extra}" ]]; then
    return 0
  fi

  read -r -a l_extra_parts <<<"${l_extra}"
  a_fpc_args_ref+=("${l_extra_parts[@]}")
}

append_target_capability_define() {
  local -n a_fpc_args_ref=$1

  case "${TARGET_CPU}" in
    i386|x86_64)
      a_fpc_args_ref+=(-dSIMD_X86_AVAILABLE)
      ;;
    arm|aarch64)
      a_fpc_args_ref+=(-dSIMD_ARM_AVAILABLE)
      ;;
    riscv32|riscv64)
      a_fpc_args_ref+=(-dSIMD_RISCV_AVAILABLE)
      ;;
    loongarch64)
      a_fpc_args_ref+=(-dSIMD_LOONGARCH_AVAILABLE)
      ;;
  esac
}

sync_legacy_log() {
  local a_source
  local a_target

  a_source="${1:?missing source log}"
  a_target="${2:?missing legacy log}"
  cp -f "${a_source}" "${a_target}"
}

record_failed_log() {
  local a_source
  local a_prefix
  local l_stamp

  a_source="${1:?missing failed log source}"
  a_prefix="${2:?missing failed log prefix}"
  if [[ ! -f "${a_source}" ]]; then
    return 0
  fi

  l_stamp="$(date +%Y%m%d-%H%M%S)"
  cp -f "${a_source}" "${TARGET_LOG_DIR}/${a_prefix}.failed.${l_stamp}.txt"
}

check_build_log_contract() {
  if grep -Eq 'nextpas\.core\.simd\.cpuinfo.*(Warning|Hint):' "${TARGET_BUILD_LOG}"; then
    echo "[CHECK] Found warnings/hints from SIMD cpuinfo units in build log"
    cat "${TARGET_BUILD_LOG}"
    return 1
  fi

  echo "[CHECK] OK (no SIMD cpuinfo warnings/hints)"
}

build_runner() {
  local -a l_fpc_args=()

  mkdir -p "${BIN_DIR}" "${UNIT_DIR}" "${LOG_DIR}" "${TARGET_LOG_DIR}"
  : > "${TARGET_BUILD_LOG}"

  if [[ "${MODE}" == "Debug" ]]; then
    l_fpc_args+=(-O1 -g -gl -dDEBUG)
  else
    MODE="Release"
    l_fpc_args+=(-O2 -gl)
  fi

  l_fpc_args+=(
    -B
    -Mobjfpc
    -Sc
    -Si
    "-Fu${ROOT}"
    "-Fu${CORE_ROOT}/src"
    "-Fu${CORE_ROOT}/src/generated"
    "-Fi${CORE_ROOT}/src"
    "-FE${BIN_DIR}"
    "-FU${UNIT_DIR}"
    "-o${RUNNER_NAME}"
  )
  append_target_capability_define l_fpc_args
  append_extra_defines l_fpc_args

  echo "[BUILD] Project: ${PROJECT} (mode=${MODE}, output_root=${OUTPUT_ROOT}, target=${TARGET_TAG})"
  echo "[BUILD] Running: ${FPC_BIN} ${l_fpc_args[*]} ${PROJECT}" >> "${TARGET_BUILD_LOG}"

  if ! "${FPC_BIN}" "${l_fpc_args[@]}" "${PROJECT}" >> "${TARGET_BUILD_LOG}" 2>&1; then
    sync_legacy_log "${TARGET_BUILD_LOG}" "${BUILD_LOG}"
    record_failed_log "${TARGET_BUILD_LOG}" "build"
    echo "[BUILD] FAILED (see ${TARGET_BUILD_LOG})"
    tail -n 120 "${TARGET_BUILD_LOG}" || true
    return 1
  fi

  sync_legacy_log "${TARGET_BUILD_LOG}" "${BUILD_LOG}"
  if [[ ! -x "${RUNNER_BIN}" ]]; then
    record_failed_log "${TARGET_BUILD_LOG}" "build"
    echo "[BUILD] FAILED (binary missing after build: ${RUNNER_BIN})"
    tail -n 120 "${TARGET_BUILD_LOG}" || true
    return 1
  fi

  echo "[BUILD] OK"
}

check_heap_leaks() {
  if grep -Eq '(^|[[:space:]])[1-9][0-9]* unfreed memory blocks' "${TARGET_TEST_LOG}"; then
    echo "[LEAK] FAILED: heaptrc reported unfreed blocks"
    cat "${TARGET_TEST_LOG}"
    return 1
  fi

  echo "[LEAK] OK"
}

run_test() {
  local -a l_args=("$@")
  local l_list_suites="0"
  local l_rc

  build_runner || return $?
  check_build_log_contract || return $?

  for l_arg in "${l_args[@]}"; do
    if [[ "${l_arg}" == "--list-suites" ]]; then
      l_list_suites="1"
      break
    fi
  done

  : > "${TARGET_TEST_LOG}"
  echo "[TEST] Running: ${RUNNER_BIN} ${l_args[*]}"
  set +e
  "${RUNNER_BIN}" "${l_args[@]}" > "${TARGET_TEST_LOG}" 2>&1
  l_rc=$?
  set -e
  sync_legacy_log "${TARGET_TEST_LOG}" "${TEST_LOG}"

  if [[ "${l_rc}" -ne 0 && "${l_list_suites}" == "1" ]] && grep -q '^Available suites:' "${TARGET_TEST_LOG}"; then
    if ! grep -Eqi 'Access violation|EAccessViolation|Invalid option|Unhandled exception|Some tests failed!|ERROR:' "${TARGET_TEST_LOG}"; then
      echo "[TEST] WARN: --list-suites returned rc=${l_rc} after printing suite manifest; treating as success"
      l_rc=0
    fi
  fi

  if [[ "${l_rc}" -ne 0 ]]; then
    record_failed_log "${TARGET_TEST_LOG}" "test"
    echo "[TEST] FAILED (see ${TARGET_TEST_LOG})"
    cat "${TARGET_TEST_LOG}"
    return 1
  fi

  if grep -q '^Invalid option' "${TARGET_TEST_LOG}"; then
    record_failed_log "${TARGET_TEST_LOG}" "test"
    echo "[TEST] FAILED: unsupported test argument (see ${TARGET_TEST_LOG})"
    cat "${TARGET_TEST_LOG}"
    return 2
  fi

  if grep -Eq 'Number of failures:[[:space:]]*[1-9][0-9]*|Number of errors:[[:space:]]*[1-9][0-9]*|Time:.* E:[1-9][0-9]*|Time:.* F:[1-9][0-9]*|Failures:[[:space:]]*[1-9][0-9]*|Errors:[[:space:]]*[1-9][0-9]*' "${TARGET_TEST_LOG}"; then
    record_failed_log "${TARGET_TEST_LOG}" "test"
    echo "[TEST] FAILED: test runner reports failures/errors (see ${TARGET_TEST_LOG})"
    cat "${TARGET_TEST_LOG}"
    return 1
  fi

  echo "[TEST] OK"
  check_heap_leaks
}

run_log_layout_check() {
  local l_name
  local l_target
  local l_legacy

  for l_name in build test; do
    l_target="${TARGET_LOG_DIR}/${l_name}.txt"
    l_legacy="${LOG_DIR}/${l_name}.txt"

    if [[ ! -f "${l_target}" ]]; then
      echo "[LAYOUT] Missing target log: ${l_target}"
      return 1
    fi
    if [[ ! -f "${l_legacy}" ]]; then
      echo "[LAYOUT] Missing legacy log: ${l_legacy}"
      return 1
    fi
    if ! cmp -s "${l_target}" "${l_legacy}"; then
      echo "[LAYOUT] Drift detected between target and legacy ${l_name} logs"
      echo "  target: ${l_target}"
      echo "  legacy: ${l_legacy}"
      return 1
    fi
  done

  echo "[LAYOUT] OK target=${TARGET_TAG} legacy=${LOG_DIR}"
}

clean_outputs() {
  echo "[CLEAN] Removing ${BIN_DIR}, ${OUTPUT_ROOT}/lib, ${LOG_DIR}"
  rm -rf "${BIN_DIR}" "${OUTPUT_ROOT}/lib" "${LOG_DIR}"
}

case "${ACTION}" in
  clean)
    clean_outputs
    ;;
  build)
    build_runner
    ;;
  check)
    build_runner
    check_build_log_contract
    ;;
  test)
    run_test "$@"
    ;;
  log-layout-check)
    run_log_layout_check
    ;;
  debug)
    MODE="Debug"
    run_test "$@"
    ;;
  release)
    MODE="Release"
    run_test "$@"
    ;;
  -h|--help|help)
    usage
    ;;
  *)
    echo "Unsupported action: ${ACTION}"
    usage
    exit 2
    ;;
esac
