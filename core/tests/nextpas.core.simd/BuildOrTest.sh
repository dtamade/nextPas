#!/usr/bin/env bash
set -euo pipefail

ACTION="${1:-test}"
shift || true

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CORE_ROOT="$(cd "${ROOT}/../.." && pwd)"
DEFAULT_OUTPUT_ROOT="${CORE_ROOT}/build/tests/nextpas.core.simd"
OUTPUT_ROOT="${SIMD_OUTPUT_ROOT:-${DEFAULT_OUTPUT_ROOT}}"
FIXTURES_NATIVE_EVIDENCE_ROOT="${ROOT}/fixtures/native-evidence"
FPC_BIN="${FPC_BIN:-${FPC:-fpc}}"
PYTHON_BIN="${PYTHON_BIN:-python3}"

TARGET_CPU="$("${FPC_BIN}" -iTP 2>/dev/null | tr '[:upper:]' '[:lower:]' || true)"
TARGET_OS="$("${FPC_BIN}" -iTO 2>/dev/null | tr '[:upper:]' '[:lower:]' || true)"
if [[ -z "${TARGET_CPU}" ]]; then
  TARGET_CPU="nativecpu"
fi
if [[ -z "${TARGET_OS}" ]]; then
  TARGET_OS="nativeos"
fi

BIN_DIR="${OUTPUT_ROOT}/bin"
UNIT_DIR="${OUTPUT_ROOT}/lib/${TARGET_CPU}-${TARGET_OS}"
LOG_DIR="${OUTPUT_ROOT}/logs"
RUNNER_NAME="nextpas.core.simd.test"
RUNNER_BIN="${BIN_DIR}/${RUNNER_NAME}"
PROJECT="${ROOT}/nextpas.core.simd.test.lpr"
BUILD_LOG="${LOG_DIR}/build.txt"
TEST_LOG="${LOG_DIR}/test.txt"
GATE_SUMMARY_LOG="${LOG_DIR}/gate_summary.md"
GATE_SUMMARY_JSON_LOG="${LOG_DIR}/gate_summary.json"
FREEZE_STATUS_JSON="${LOG_DIR}/freeze_status.json"
DISPATCH_CONTRACT_JSON="${LOG_DIR}/dispatch_contract_signature.json"
PUBLIC_ABI_JSON="${LOG_DIR}/public_abi_signature.json"
IMPLEMENTATION_MATRIX_JSON="${LOG_DIR}/implementation_matrix_sync.json"

mkdir -p "${BIN_DIR}" "${UNIT_DIR}" "${LOG_DIR}"

usage() {
  cat <<'EOF'
Usage: BuildOrTest.sh [clean|check|test|contract-signature|publicabi-signature|coverage|experimental-intrinsics-tests|experimental-intrinsics-closure|wiring-sync|nonx86-ieee754|perf-smoke|nonx86-optin-list-suites|helper-semantics|impl-smoke-nonx86|impl-audit-nonx86|native-evidence|verify-nonx86-native-evidence|import-nonx86-native-evidence|closeout-host-local|closeout-host-local-from-import|gate|gate-strict|gate-summary|gate-summary-sample|gate-summary-rehearsal|gate-summary-selfcheck|gate-summary-inject|gate-summary-rollback|gate-summary-backups|historical-closeout-note-check|active-closeout-truth-check|evidence-linux|verify-win-evidence|freeze-status|freeze-status-linux|freeze-status-rehearsal|win-closeout-dryrun|win-closeout-3cmd|qemu-nonx86-evidence|qemu-cpuinfo-nonx86-evidence|qemu-cpuinfo-nonx86-full-evidence|qemu-cpuinfo-nonx86-full-repeat|qemu-cpuinfo-nonx86-suite-repeat|qemu-arch-matrix-evidence|qemu-nonx86-experimental-asm|closeout-release|win-evidence-preflight|win-evidence-via-gh|finalize-win-evidence|win-closeout-snippets|win-closeout-finalize|freshness] [test-args...]

Supported actions:
  clean                             Remove shell-runner output directories
  check                             Run minimal shell-runner checks (list-suites + signatures)
  test [runner args...]             Compile and run nextpas.core.simd.test
  contract-signature                Run dispatch signature checker
  publicabi-signature               Run public ABI signature checker
  coverage                          Run live intrinsics direct-test coverage against current carriers
  experimental-intrinsics-tests     Run the dedicated experimental intrinsics test suite
  experimental-intrinsics-closure   Run explicit opt-in closure for experimental intrinsics
  wiring-sync                       Audit non-x86 wiring consistency
  nonx86-ieee754                    Run the non-x86 IEEE754 parity suite
  perf-smoke                        Run the lightweight backend benchmark smoke
  nonx86-optin-list-suites          Compile NEON/RISCVV opt-in runners and list suites
  helper-semantics                  Run the non-x86 helper semantics checker only
  impl-smoke-nonx86                 Run the high-frequency non-x86 helper/runtime smoke chain
  impl-audit-nonx86                 Run the non-x86 helper/native-evidence implementation audit
  native-evidence [backend]         Delegate to collect_nonx86_native_evidence.sh
  verify-nonx86-native-evidence     Verify archived native evidence summaries/logs
  import-nonx86-native-evidence     Import native-evidence-* directories, then verify them
  closeout-host-local               Run the host-local non-x86 audit chain and fail close before claiming full closeout
  closeout-host-local-from-import   Import archived native evidence, then run closeout-host-local
  gate                              Historical Linux shell gate surface currently unavailable in this worktree
  gate-strict                       Historical Linux shell gate surface currently unavailable in this worktree
  gate-summary                      Print the canonical gate summary table
  gate-summary-sample               Generate a sample gate summary fixture
  gate-summary-rehearsal            Rehearse gate-summary threshold shaping
  gate-summary-selfcheck            Quick gate-summary/freeze-status selfcheck
  gate-summary-inject               Inject a sample gate summary into canonical logs
  gate-summary-rollback             Restore the previous gate summary backup
  gate-summary-backups              List available gate-summary backups
  historical-closeout-note-check    Fail-close stale historical closeout notes
  active-closeout-truth-check       Fail-close active closeout docs that drift from current HEAD truth
  evidence-linux                    Historical Linux closeout shell surface currently unavailable in this worktree
  verify-win-evidence               Verify Windows evidence logs via the shell verifier
  freeze-status                     Evaluate current cross-platform freeze readiness
  freeze-status-linux               Evaluate Linux-only freeze readiness
  freeze-status-rehearsal           Rehearse freeze-status failure shaping
  win-closeout-dryrun               Print Windows closeout dry-run guidance
  win-closeout-3cmd                 Print the recommended Windows closeout command chain
  qemu-nonx86-evidence              Delegate to docker/run_multiarch_qemu.sh nonx86-evidence
  qemu-cpuinfo-nonx86-evidence      Delegate to docker/run_multiarch_qemu.sh cpuinfo-nonx86-evidence
  qemu-cpuinfo-nonx86-full-evidence Delegate to docker/run_multiarch_qemu.sh cpuinfo-nonx86-full-evidence
  qemu-cpuinfo-nonx86-full-repeat   Delegate to docker/run_multiarch_qemu.sh cpuinfo-nonx86-full-repeat
  qemu-cpuinfo-nonx86-suite-repeat  Delegate to docker/run_multiarch_qemu.sh cpuinfo-nonx86-suite-repeat
  qemu-arch-matrix-evidence         Delegate to docker/run_multiarch_qemu.sh arch-matrix-evidence
  qemu-nonx86-experimental-asm      Delegate to docker/run_multiarch_qemu.sh nonx86-experimental-asm
  closeout-release                  Historical Windows/GH closeout shell surface currently unavailable in this worktree
  win-evidence-preflight            Historical Windows/GH closeout shell surface currently unavailable in this worktree
  win-evidence-via-gh               Historical Windows/GH closeout shell surface currently unavailable in this worktree
  finalize-win-evidence             Historical Windows/GH closeout shell surface currently unavailable in this worktree
  win-closeout-snippets             Historical Windows/GH closeout shell surface currently unavailable in this worktree
  win-closeout-finalize             Historical Windows/GH closeout shell surface currently unavailable in this worktree
	  freshness                         Check evidence freshness vs source code (SKIP if evidence missing, FAIL if stale)

Examples:
  bash tests/nextpas.core.simd/BuildOrTest.sh test --list-suites
  bash tests/nextpas.core.simd/BuildOrTest.sh test --suite=TTestCase_DispatchAPI,TTestCase_PublicAbi
  FAFAFA_BUILD_MODE=Release bash tests/nextpas.core.simd/BuildOrTest.sh impl-audit-nonx86
EOF
}

run_python_checker() {
  local a_label
  local a_script

  a_label="${1:-}"
  a_script="${2:-}"
  shift 2 || true

  if [[ ! -f "${a_script}" ]]; then
    echo "[${a_label}] Missing checker: ${a_script}"
    return 2
  fi

  echo "[${a_label}] Running: ${PYTHON_BIN} -B ${a_script} $*"
  "${PYTHON_BIN}" -B "${a_script}" "$@"
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

build_runner() {
  local -a l_fpc_args

  mkdir -p "${BIN_DIR}" "${UNIT_DIR}" "${LOG_DIR}"
  : > "${BUILD_LOG}"

  l_fpc_args=(
    -B
    -Mobjfpc
    -Sc
    -Si
    -O2
    -gl
    -gh
    "-Fi${CORE_ROOT}/src"
    "-Fu${CORE_ROOT}/src"
    "-Fu${CORE_ROOT}/src/generated"
    "-Fu${ROOT}"
    "-FE${BIN_DIR}"
    "-FU${UNIT_DIR}"
    "-o${RUNNER_NAME}"
  )

  if [[ "${SIMD_ENABLE_NEON_BACKEND:-0}" == "1" ]]; then
    l_fpc_args+=(-dNEXTPAS_SIMD_TEST_REGISTER_NEON_BACKEND)
  fi
  if [[ "${SIMD_ENABLE_RISCVV_BACKEND:-0}" == "1" ]]; then
    l_fpc_args+=(-dNEXTPAS_SIMD_TEST_REGISTER_RISCVV_BACKEND)
  fi
  if [[ "${SIMD_ENABLE_AVX512_BACKEND:-0}" == "1" ]]; then
    l_fpc_args+=(-dSIMD_BACKEND_AVX512)
  fi
  if [[ "${SIMD_ENABLE_LINEINFO:-0}" == "1" ]]; then
    l_fpc_args+=(-gl)
  fi

  append_extra_defines l_fpc_args

  echo "[BUILD] Project: ${PROJECT} (output_root=${OUTPUT_ROOT})"
  echo "[BUILD] Running: ${FPC_BIN} ${l_fpc_args[*]} ${PROJECT}" >> "${BUILD_LOG}"

  if ! "${FPC_BIN}" "${l_fpc_args[@]}" "${PROJECT}" >> "${BUILD_LOG}" 2>&1; then
    echo "[BUILD] FAILED (see ${BUILD_LOG})"
    tail -n 120 "${BUILD_LOG}" || true
    return 1
  fi
  if [[ ! -x "${RUNNER_BIN}" ]]; then
    echo "[BUILD] FAILED (binary missing after build: ${RUNNER_BIN})"
    tail -n 120 "${BUILD_LOG}" || true
    return 1
  fi

  echo "[BUILD] OK"
}

check_heap_leaks() {
  if grep -Eq '(^|[[:space:]])[1-9][0-9]* unfreed memory blocks' "${TEST_LOG}"; then
    echo "[LEAK] FAILED: heaptrc reported unfreed blocks"
    cat "${TEST_LOG}"
    return 1
  fi
  return 0
}

run_test() {
  local -a l_args=("$@")
  local l_list_suites="0"
  local l_rc

  build_runner || return $?

  if [[ "${SIMD_RUN_ONLY_BUILD:-0}" == "1" ]]; then
    echo "[TEST] SKIP runtime (SIMD_RUN_ONLY_BUILD=1)"
    return 0
  fi

  for l_arg in "${l_args[@]}"; do
    if [[ "${l_arg}" == "--list-suites" ]]; then
      l_list_suites="1"
      break
    fi
  done

  : > "${TEST_LOG}"
  echo "[TEST] Running: ${RUNNER_BIN} ${l_args[*]}"
  set +e
  "${RUNNER_BIN}" "${l_args[@]}" > "${TEST_LOG}" 2>&1
  l_rc=$?
  set -e

  if [[ "${l_rc}" -ne 0 && "${l_list_suites}" == "1" ]] && grep -q '^Available suites:' "${TEST_LOG}"; then
    if ! grep -Eqi 'Access violation|EAccessViolation|Invalid option|Unhandled exception|Some tests failed!|ERROR:' "${TEST_LOG}"; then
      echo "[TEST] WARN: --list-suites returned rc=${l_rc} after printing suite manifest; treating as success"
      l_rc=0
    fi
  fi

  if [[ "${l_rc}" -ne 0 ]]; then
    echo "[TEST] FAILED (see ${TEST_LOG})"
    cat "${TEST_LOG}"
    return 1
  fi

  if grep -q '^Invalid option' "${TEST_LOG}"; then
    echo "[TEST] FAILED: unsupported test argument (see ${TEST_LOG})"
    cat "${TEST_LOG}"
    return 2
  fi

  if grep -Eq 'Number of failures:[[:space:]]*[1-9][0-9]*|Number of errors:[[:space:]]*[1-9][0-9]*|Time:.* E:[1-9][0-9]*|Time:.* F:[1-9][0-9]*|Failures:[[:space:]]*[1-9][0-9]*|Errors:[[:space:]]*[1-9][0-9]*' "${TEST_LOG}"; then
    echo "[TEST] FAILED: test runner reports failures/errors (see ${TEST_LOG})"
    cat "${TEST_LOG}"
    return 1
  fi

  echo "[TEST] OK"
  check_heap_leaks
}

run_check() {
  run_test --list-suites
  run_python_checker "DISPATCH-CONTRACT" "${ROOT}/check_dispatch_contract_signature.py" --summary-line --json-file "${DISPATCH_CONTRACT_JSON}"
  run_python_checker "PUBLIC-ABI" "${ROOT}/check_public_abi_signature.py" --summary-line --json-file "${PUBLIC_ABI_JSON}"
}

run_intrinsics_coverage() {
  local -a l_args=()

  if [[ -z "${SIMD_COVERAGE_JSON_FILE:-}" ]]; then
    SIMD_COVERAGE_JSON_FILE="${LOG_DIR}/intrinsics_coverage.json"
  fi
  if [[ "${SIMD_COVERAGE_STRICT_EXTRA:-0}" == "1" ]]; then
    l_args+=(--strict-extra)
  fi
  if [[ "${SIMD_COVERAGE_REQUIRE_AVX2:-0}" == "1" ]]; then
    l_args+=(--require-avx2)
  fi
  if [[ "${SIMD_COVERAGE_REQUIRE_EXPERIMENTAL:-0}" == "1" ]]; then
    l_args+=(--require-experimental)
  fi

  run_python_checker "COVERAGE-LAYOUT" "${ROOT}/check_intrinsics_coverage_layout_contract.py" --summary-line
  run_python_checker "COVERAGE" "${ROOT}/check_intrinsics_coverage.py" "${l_args[@]}" --summary-line --json-file "${SIMD_COVERAGE_JSON_FILE}"
}

run_experimental_intrinsics_tests() {
  local l_runner
  local l_output_root

  l_runner="${ROOT}/../nextpas.core.simd.intrinsics.experimental/BuildOrTest.sh"
  if [[ ! -f "${l_runner}" ]]; then
    echo "[EXPERIMENTAL-TESTS] Missing runner: ${l_runner}"
    return 2
  fi

  if [[ "${OUTPUT_ROOT}" == "${DEFAULT_OUTPUT_ROOT}" ]]; then
    l_output_root="${CORE_ROOT}/build/tests/nextpas.core.simd.intrinsics.experimental"
  else
    l_output_root="${OUTPUT_ROOT}/intrinsics.experimental"
  fi

  echo "[EXPERIMENTAL-TESTS] Running: ${l_runner} test-all $*"
  SIMD_OUTPUT_ROOT="${l_output_root}" bash "${l_runner}" test-all "$@"
}

run_experimental_intrinsics_closure() {
  run_check
  (
    SIMD_COVERAGE_STRICT_EXTRA=1
    SIMD_COVERAGE_REQUIRE_AVX2=1
    SIMD_COVERAGE_REQUIRE_EXPERIMENTAL=1
    run_intrinsics_coverage
  )
  run_python_checker "EXPERIMENTAL" "${ROOT}/check_intrinsics_experimental_status.py" --summary-line
  run_experimental_intrinsics_tests "$@"
}

run_nonx86_optin_list_suites_for() {
  local a_backend
  local l_backend_output_root

  a_backend="${1:-}"
  if [[ -z "${a_backend}" ]]; then
    echo "[NONX86-OPTIN] Missing backend selector"
    return 2
  fi

  l_backend_output_root="${OUTPUT_ROOT}/nonx86.optin/${a_backend}"
  if [[ "${a_backend}" == "neon" ]]; then
    echo "[NONX86-OPTIN] ${a_backend}: test --list-suites"
    SIMD_OUTPUT_ROOT="${l_backend_output_root}" \
      SIMD_ENABLE_NEON_BACKEND=1 \
      SIMD_ENABLE_RISCVV_BACKEND=0 \
      bash "${ROOT}/BuildOrTest.sh" test --list-suites
  elif [[ "${a_backend}" == "riscvv" ]]; then
    echo "[NONX86-OPTIN] ${a_backend}: test --list-suites"
    SIMD_OUTPUT_ROOT="${l_backend_output_root}" \
      SIMD_ENABLE_NEON_BACKEND=0 \
      SIMD_ENABLE_RISCVV_BACKEND=1 \
      bash "${ROOT}/BuildOrTest.sh" test --list-suites
  else
    echo "[NONX86-OPTIN] Unknown backend: ${a_backend}"
    return 2
  fi
}

run_nonx86_optin_list_suites() {
  run_nonx86_optin_list_suites_for neon
  run_nonx86_optin_list_suites_for riscvv
}

run_nonx86_helper_semantics() {
  run_python_checker "HELPER-SEMANTICS" "${ROOT}/check_nonx86_helper_semantics.py" --summary-line
}

run_nonx86_key_slot_audit() {
  run_python_checker "KEY-SLOT-AUDIT" "${ROOT}/check_nonx86_key_slot_audit.py" --summary-line
}

run_nonx86_wiring_sync() {
  local -a l_args=()

  if [[ "${SIMD_WIRING_SYNC_STRICT_EXTRA:-0}" == "1" ]]; then
    l_args+=(--strict-extra)
  fi

  run_python_checker "WIRING-SYNC" "${ROOT}/check_nonx86_wiring_sync.py" "${l_args[@]}"
}

run_nonx86_wiring_sync_strict() {
  run_python_checker "WIRING-SYNC" "${ROOT}/check_nonx86_wiring_sync.py" --strict-extra
}

run_riscvv_abi_shape() {
  run_python_checker "RISCVV-ABI" "${ROOT}/check_riscvv_abi_shape.py" --summary-line
}

run_implementation_matrix_sync() {
  run_python_checker "IMPL-MATRIX" "${ROOT}/check_implementation_matrix_sync.py" --summary-line --json-file "${IMPLEMENTATION_MATRIX_JSON}"
}

run_nonx86_register_truthfulness() {
  local a_backend

  a_backend="${1:-}"
  if [[ -z "${a_backend}" ]]; then
    echo "[REG-TRUTH] Missing backend selector"
    return 2
  fi

  run_python_checker "REG-TRUTH" "${ROOT}/check_nonx86_register_truthfulness.py" --backend "${a_backend}" --summary-line --strict
}

# Source contract: if these canonical Runtime Parity references drift,
# check_nonx86_helper_semantics.py reports "non-x86 native evidence helper missing runtime parity pattern".
print_nonx86_runtime_parity_reference() {
  cat <<'EOF'
## Runtime Parity (TTestCase_NonX86BackendParity,TTestCase_DataPlane)
bash tests/nextpas.core.simd/BuildOrTest.sh test --suite=TTestCase_NonX86BackendParity,TTestCase_DataPlane
bash tests/nextpas.core.simd/docker/run_fpc_tests.sh --vector-asm --suite=TTestCase_NonX86BackendParity,TTestCase_DataPlane
EOF
}

run_nonx86_native_evidence_verify_optional() {
  local LNonX86NativeEvidenceRoot
  local -a l_native_evidence_dirs=()

  LNonX86NativeEvidenceRoot="${SIMD_NONX86_NATIVE_EVIDENCE_ROOT:-${FIXTURES_NATIVE_EVIDENCE_ROOT}}"
  if [[ -d "${LNonX86NativeEvidenceRoot}" ]]; then
    shopt -s nullglob
    l_native_evidence_dirs=(
      "${LNonX86NativeEvidenceRoot}"/native-evidence-neon-*
      "${LNonX86NativeEvidenceRoot}"/native-evidence-riscvv-*
    )
    shopt -u nullglob
  fi

  if (( ${#l_native_evidence_dirs[@]} == 0 )); then
    echo "[GATE] SKIP non-x86 native evidence verify (no native-evidence-neon-*/native-evidence-riscvv-* entries under: ${LNonX86NativeEvidenceRoot})"
    echo "[NONX86-NATIVE-VERIFY] non-x86 native evidence entries missing under root (optional in gate): ${LNonX86NativeEvidenceRoot}"
    return 0
  fi

  run_python_checker "NONX86-NATIVE-VERIFY" "${ROOT}/verify_nonx86_native_evidence.py" --root "${LNonX86NativeEvidenceRoot}" --summary-line
}

run_nonx86_native_evidence_verify() {
  local -a l_args=("$@")
  local l_has_root_arg="0"
  local l_arg

  if [[ "${#l_args[@]}" -eq 0 ]]; then
    l_args=(--root "${SIMD_NONX86_NATIVE_EVIDENCE_ROOT:-${FIXTURES_NATIVE_EVIDENCE_ROOT}}")
  elif [[ "${l_args[0]}" != -* && "${#l_args[@]}" -eq 1 ]]; then
    l_args=(--root "${l_args[0]}")
  else
    for l_arg in "${l_args[@]}"; do
      if [[ "${l_arg}" == "--root" || "${l_arg}" == --root=* ]]; then
        l_has_root_arg="1"
        break
      fi
    done
    if [[ "${l_has_root_arg}" == "0" ]]; then
      l_args=(--root "${SIMD_NONX86_NATIVE_EVIDENCE_ROOT:-${FIXTURES_NATIVE_EVIDENCE_ROOT}}" "${l_args[@]}")
    fi
  fi

  run_python_checker "NONX86-NATIVE-VERIFY" "${ROOT}/verify_nonx86_native_evidence.py" "${l_args[@]}" --summary-line
}

run_nonx86_native_evidence_import() {
  local l_import_script

  l_import_script="${ROOT}/import_nonx86_native_evidence_artifacts.sh"
  if [[ ! -f "${l_import_script}" ]]; then
    echo "[IMPORT] Missing importer: ${l_import_script}"
    return 2
  fi
  if [[ "$#" -eq 0 ]]; then
    bash "${l_import_script}" --help
    return 2
  fi

  echo "[IMPORT] Running: bash ${l_import_script} $*"
  bash "${l_import_script}" "$@"
}

run_nonx86_native_evidence() {
  local l_collect_script

  l_collect_script="${ROOT}/collect_nonx86_native_evidence.sh"
  if [[ ! -f "${l_collect_script}" ]]; then
    echo "[NATIVE-EVIDENCE] Missing collector: ${l_collect_script}"
    return 2
  fi

  echo "[NATIVE-EVIDENCE] Running: bash ${l_collect_script} $*"
  bash "${l_collect_script}" "$@"
}

run_nonx86_ieee754() {
  run_test --list-suites
  if ! grep -F 'TTestCase_NonX86IEEE754' "${TEST_LOG}" >/dev/null; then
    echo "[NONX86-IEEE754] SKIP (suite TTestCase_NonX86IEEE754 not present in this build)"
    return 0
  fi

  run_test --suite=TTestCase_NonX86IEEE754
}

run_perf_smoke() {
  local -a l_perf_args=(--bench-only)
  local l_perf_vector_asm
  local l_rc
  local l_perf_check_script

  build_runner || return $?

  l_perf_vector_asm="${SIMD_PERF_VECTOR_ASM:-auto}"
  if [[ "${l_perf_vector_asm}" != "0" ]]; then
    if [[ "${l_perf_vector_asm}" == "1" ]]; then
      l_perf_args+=(--vector-asm)
    elif [[ "${TARGET_CPU}" == "x86_64" || "${TARGET_CPU}" == "amd64" ]]; then
      l_perf_args+=(--vector-asm)
    fi
  fi

  : > "${TEST_LOG}"
  echo "[PERF] Running: ${RUNNER_BIN} ${l_perf_args[*]}"
  set +e
  "${RUNNER_BIN}" "${l_perf_args[@]}" > "${TEST_LOG}" 2>&1
  l_rc=$?
  set -e

  if [[ "${l_rc}" -ne 0 ]]; then
    echo "[PERF] FAILED (see ${TEST_LOG})"
    cat "${TEST_LOG}"
    return 1
  fi

  if grep -q '^Invalid option' "${TEST_LOG}"; then
    echo "[PERF] FAILED: unsupported bench argument (see ${TEST_LOG})"
    cat "${TEST_LOG}"
    return 2
  fi

  check_heap_leaks || return $?

  if ! grep -F '=== SIMD Benchmark (' "${TEST_LOG}" >/dev/null; then
    echo "[PERF] FAILED: benchmark header not found in ${TEST_LOG}"
    cat "${TEST_LOG}"
    return 1
  fi

  if grep -F '/Scalar)' "${TEST_LOG}" >/dev/null; then
    echo "[PERF] FAILED (active backend is Scalar; perf-smoke requires non-scalar backend evidence)"
    return 1
  fi

  l_perf_check_script="${ROOT}/check_perf_smoke_log.py"
  if [[ -f "${l_perf_check_script}" ]]; then
    run_python_checker "PERF" "${l_perf_check_script}" "${TEST_LOG}"
  else
    echo "[PERF] OK"
  fi
}

run_nonx86_impl_smoke() {
  local l_steps=0

  run_nonx86_helper_semantics
  l_steps=$((l_steps + 1))
  run_nonx86_key_slot_audit
  l_steps=$((l_steps + 1))
  run_nonx86_wiring_sync_strict
  l_steps=$((l_steps + 1))
  run_riscvv_abi_shape
  l_steps=$((l_steps + 1))
  run_nonx86_register_truthfulness neon
  l_steps=$((l_steps + 1))
  run_nonx86_register_truthfulness riscvv
  l_steps=$((l_steps + 1))

  print_nonx86_runtime_parity_reference
  bash "${ROOT}/BuildOrTest.sh" test --suite=TTestCase_NonX86BackendParity
  l_steps=$((l_steps + 1))
  bash "${ROOT}/BuildOrTest.sh" test --suite=TTestCase_NonX86BackendParity,TTestCase_DataPlane
  l_steps=$((l_steps + 1))

  echo "NONX86_IMPL_SMOKE_SUMMARY steps=${l_steps} targeted_output_root=${OUTPUT_ROOT} status=ok"
}

run_nonx86_impl_audit() {
  run_nonx86_impl_smoke
  run_implementation_matrix_sync
  run_nonx86_native_evidence_verify_optional
}

run_closeout_host_local() {
  run_nonx86_impl_audit
  echo "[CLOSEOUT-HOST-LOCAL] FAIL-CLOSE: shell runner does not restore the full gate-strict / qemu closeout execution chain yet; use the dedicated qemu actions and checklist proof steps before claiming release closeout"
  return 2
}

run_closeout_host_local_from_import() {
  run_nonx86_native_evidence_import "$@"
  run_closeout_host_local
}

run_qemu_action() {
  local a_action
  local l_qemu_script

  a_action="${1:-}"
  shift || true
  l_qemu_script="${ROOT}/docker/run_multiarch_qemu.sh"
  if [[ -z "${a_action}" ]]; then
    echo "[QEMU] Missing qemu action"
    return 2
  fi
  if [[ ! -f "${l_qemu_script}" ]]; then
    echo "[QEMU] Missing script: ${l_qemu_script}"
    return 2
  fi

  echo "[QEMU] Running: bash ${l_qemu_script} ${a_action} $*"
  bash "${l_qemu_script}" "${a_action}" "$@"
}

run_gate_summary() {
  local l_summary_file
  local l_warn_ms
  local l_fail_ms
  local l_filter
  local l_max_detail
  local l_export_script
  local l_json_file
  local l_matched_rows

  l_summary_file="${SIMD_GATE_SUMMARY_FILE:-${GATE_SUMMARY_LOG}}"
  l_warn_ms="${SIMD_GATE_STEP_WARN_MS:-20000}"
  l_fail_ms="${SIMD_GATE_STEP_FAIL_MS:-120000}"
  l_filter="${SIMD_GATE_SUMMARY_FILTER:-ALL}"
  l_max_detail="${SIMD_GATE_SUMMARY_MAX_DETAIL:-260}"
  l_matched_rows="0"

  if [[ ! -f "${l_summary_file}" ]]; then
    echo "[GATE-SUMMARY] Missing summary file: ${l_summary_file}"
    return 2
  fi

  echo "[GATE-SUMMARY] ${l_summary_file}"
  echo "[GATE-SUMMARY] thresholds: warn_ms=${l_warn_ms}, fail_ms=${l_fail_ms}"
  echo "[GATE-SUMMARY] filter=${l_filter}, max_detail=${l_max_detail}"

  case "${l_filter^^}" in
    ALL)
      cat "${l_summary_file}"
      l_matched_rows="$(grep -Ec '^\| ' "${l_summary_file}" || true)"
      ;;
    FAIL)
      grep -E '^(\| Time \||\|---\||.*\| FAIL \|)' "${l_summary_file}" || true
      l_matched_rows="$(grep -Ec '.*\| FAIL \|' "${l_summary_file}" || true)"
      ;;
    SLOW)
      grep -E '^(\| Time \||\|---\||.*\| SLOW_(WARN|CRIT|FAIL) \|)' "${l_summary_file}" || true
      l_matched_rows="$(grep -Ec '.*\| SLOW_(WARN|CRIT|FAIL) \|' "${l_summary_file}" || true)"
      ;;
    *)
      echo "[GATE-SUMMARY] WARN: unsupported filter=${l_filter}, fallback=ALL"
      cat "${l_summary_file}"
      l_filter="ALL"
      l_matched_rows="$(grep -Ec '^\| ' "${l_summary_file}" || true)"
      ;;
  esac

  echo "[GATE-SUMMARY] matched_rows=${l_matched_rows}"

  if [[ "${SIMD_GATE_SUMMARY_JSON:-0}" != "1" ]]; then
    return 0
  fi

  l_json_file="${SIMD_GATE_SUMMARY_JSON_FILE:-${GATE_SUMMARY_JSON_LOG}}"
  l_export_script="${ROOT}/export_gate_summary_json.py"
  if [[ ! -f "${l_export_script}" ]]; then
    echo "[GATE-SUMMARY] Missing exporter: ${l_export_script}"
    return 2
  fi

  echo "[GATE-SUMMARY] Running: ${PYTHON_BIN} -B ${l_export_script} --input ${l_summary_file} --output ${l_json_file} --filter ${l_filter} --warn-ms ${l_warn_ms} --fail-ms ${l_fail_ms}"
  "${PYTHON_BIN}" -B "${l_export_script}" \
    --input "${l_summary_file}" \
    --output "${l_json_file}" \
    --filter "${l_filter}" \
    --warn-ms "${l_warn_ms}" \
    --fail-ms "${l_fail_ms}"
  echo "[GATE-SUMMARY] json=${l_json_file}"
}

run_gate_summary_sample() {
  local l_sample_script
  local l_scenario
  local l_output
  local l_warn_ms
  local l_fail_ms

  l_sample_script="${ROOT}/generate_gate_summary_sample.py"
  l_scenario="${1:-mixed}"
  l_output="${2:-${LOG_DIR}/gate_summary.sample.${l_scenario}.md}"
  l_warn_ms="${SIMD_GATE_STEP_WARN_MS:-20000}"
  l_fail_ms="${SIMD_GATE_STEP_FAIL_MS:-120000}"

  if [[ ! -f "${l_sample_script}" ]]; then
    echo "[GATE-SUMMARY-SAMPLE] Missing generator: ${l_sample_script}"
    return 2
  fi

  echo "[GATE-SUMMARY-SAMPLE] Running: ${PYTHON_BIN} -B ${l_sample_script} --scenario ${l_scenario} --warn-ms ${l_warn_ms} --fail-ms ${l_fail_ms} --output ${l_output}"
  "${PYTHON_BIN}" -B "${l_sample_script}" \
    --scenario "${l_scenario}" \
    --warn-ms "${l_warn_ms}" \
    --fail-ms "${l_fail_ms}" \
    --output "${l_output}"
  echo "[GATE-SUMMARY-SAMPLE] output=${l_output}"
}

run_gate_summary_rehearsal() {
  local l_rehearsal_script

  l_rehearsal_script="${ROOT}/rehearse_gate_summary_thresholds.sh"
  if [[ ! -f "${l_rehearsal_script}" ]]; then
    echo "[GATE-SUMMARY-REHEARSAL] Missing script: ${l_rehearsal_script}"
    return 2
  fi

  echo "[GATE-SUMMARY-REHEARSAL] Running: bash ${l_rehearsal_script}"
  bash "${l_rehearsal_script}"
}

run_gate_summary_selfcheck() {
  run_gate_summary_rehearsal "$@"
}

run_gate_summary_inject() {
  local l_inject_script

  l_inject_script="${ROOT}/inject_gate_summary_sample.sh"
  if [[ ! -f "${l_inject_script}" ]]; then
    echo "[GATE-SUMMARY-INJECT] Missing script: ${l_inject_script}"
    return 2
  fi

  echo "[GATE-SUMMARY-INJECT] Running: bash ${l_inject_script} $*"
  bash "${l_inject_script}" "$@"
}

run_gate_summary_rollback() {
  local l_rollback_script

  l_rollback_script="${ROOT}/rollback_gate_summary_sample.sh"
  if [[ ! -f "${l_rollback_script}" ]]; then
    echo "[GATE-SUMMARY-ROLLBACK] Missing script: ${l_rollback_script}"
    return 2
  fi

  echo "[GATE-SUMMARY-ROLLBACK] Running: bash ${l_rollback_script} $*"
  bash "${l_rollback_script}" "$@"
}

run_gate_summary_backups() {
  local l_backup_script

  l_backup_script="${ROOT}/list_gate_summary_backups.sh"
  if [[ ! -f "${l_backup_script}" ]]; then
    echo "[GATE-SUMMARY-BACKUPS] Missing script: ${l_backup_script}"
    return 2
  fi

  echo "[GATE-SUMMARY-BACKUPS] Running: bash ${l_backup_script} $*"
  bash "${l_backup_script}" "$@"
}

run_historical_closeout_note_check() {
  run_python_checker \
    "HISTORICAL-CLOSEOUT-NOTE-CHECK" \
    "${ROOT}/check_historical_closeout_current_head_notes.py" \
    "$@"
}

run_active_closeout_truth_check() {
  run_python_checker \
    "ACTIVE-CLOSEOUT-TRUTH-CHECK" \
    "${ROOT}/check_active_closeout_current_head_truth.py" \
    "$@"
}

run_verify_windows_evidence() {
  local l_verify_script

  l_verify_script="${ROOT}/verify_windows_b07_evidence.sh"
  if [[ ! -f "${l_verify_script}" ]]; then
    echo "[VERIFY-WIN-EVIDENCE] Missing verifier: ${l_verify_script}"
    return 2
  fi

  echo "[VERIFY-WIN-EVIDENCE] Running: bash ${l_verify_script} $*"
  bash "${l_verify_script}" "$@"
}

run_freeze_status() {
  local a_linux_only
  local -a l_args
  local l_eval_script

  a_linux_only="${1:-0}"
  shift || true
  l_eval_script="${ROOT}/evaluate_simd_freeze_status.py"
  if [[ ! -f "${l_eval_script}" ]]; then
    echo "[FREEZE] Missing evaluator: ${l_eval_script}"
    return 2
  fi

  l_args=(
    --root "${ROOT}"
    --json-file "${FREEZE_STATUS_JSON}"
  )
  if [[ "${a_linux_only}" == "1" ]]; then
    l_args+=(--linux-only)
  fi

  echo "[FREEZE] Running: ${PYTHON_BIN} -B ${l_eval_script} ${l_args[*]} $*"
  "${PYTHON_BIN}" -B "${l_eval_script}" "${l_args[@]}" "$@"
}

run_freeze_status_rehearsal() {
  local l_rehearsal_script

  l_rehearsal_script="${ROOT}/rehearse_freeze_status.sh"
  if [[ ! -f "${l_rehearsal_script}" ]]; then
    echo "[FREEZE-REHEARSAL] Missing script: ${l_rehearsal_script}"
    return 2
  fi

  echo "[FREEZE-REHEARSAL] Running: bash ${l_rehearsal_script}"
  bash "${l_rehearsal_script}"
}

run_win_closeout_3cmd() {
  local l_print_script

  l_print_script="${ROOT}/print_windows_b07_closeout_3cmd.sh"
  if [[ ! -f "${l_print_script}" ]]; then
    echo "[WIN-CLOSEOUT-3CMD] Missing script: ${l_print_script}"
    return 2
  fi

  echo "[WIN-CLOSEOUT-3CMD] Running: bash ${l_print_script} $*"
  bash "${l_print_script}" "$@"
}

fail_missing_windows_closeout_surface() {
  local a_label
  local a_action

  a_label="${1:-WINDOWS-CLOSEOUT}"
  a_action="${2:-unknown}"
  cat <<EOF
[${a_label}] FAILED (historical Windows/GH closeout shell helper "${a_action}" is not restored in this worktree)
[${a_label}] Use the currently live local path instead:
[${a_label}]   tests\\nextpas.core.simd\\buildOrTest.bat evidence-win-verify
[${a_label}]   bash tests/nextpas.core.simd/BuildOrTest.sh gate
[${a_label}]   bash tests/nextpas.core.simd/BuildOrTest.sh freeze-status
[${a_label}]   bash tests/nextpas.core.simd/BuildOrTest.sh win-closeout-3cmd <batch-id>
EOF
  return 2
}

fail_missing_linux_closeout_surface() {
  local a_label
  local a_action

  a_label="${1:-LINUX-CLOSEOUT}"
  a_action="${2:-unknown}"
  cat <<EOF
[${a_label}] FAILED (historical Linux closeout shell helper "${a_action}" is not restored in this worktree)
[${a_label}] Use currently live focused paths instead:
[${a_label}]   bash tests/nextpas.core.simd/BuildOrTest.sh wiring-sync
[${a_label}]   bash tests/nextpas.core.simd/BuildOrTest.sh nonx86-ieee754
[${a_label}]   bash tests/nextpas.core.simd/BuildOrTest.sh perf-smoke
[${a_label}]   bash tests/nextpas.core.simd/run_backend_benchmarks.sh
[${a_label}]   bash tests/nextpas.core.simd/BuildOrTest.sh gate-summary-selfcheck
[${a_label}]   bash tests/nextpas.core.simd/BuildOrTest.sh freeze-status-linux
[${a_label}]   bash tests/nextpas.core.simd/BuildOrTest.sh freeze-status
EOF
  return 2
}

fail_missing_linux_coverage_surface() {
  local a_label
  local a_action

  a_label="${1:-COVERAGE}"
  a_action="${2:-unknown}"
  cat <<EOF
[${a_label}] FAILED (current intrinsics coverage shell helper "${a_action}" is not restored in this worktree)
[${a_label}] The underlying direct-test coverage checker still drifts from the current test layout, so this path remains fail-close until the checker is repaired.
[${a_label}] Use currently live local helpers instead:
[${a_label}]   bash tests/nextpas.core.simd/BuildOrTest.sh wiring-sync
[${a_label}]   bash tests/nextpas.core.simd/BuildOrTest.sh nonx86-ieee754
[${a_label}]   bash tests/nextpas.core.simd/BuildOrTest.sh perf-smoke
[${a_label}]   bash tests/nextpas.core.simd/BuildOrTest.sh gate-summary-selfcheck
[${a_label}]   bash tests/nextpas.core.simd/BuildOrTest.sh freeze-status-linux
EOF
  return 2
}

fail_missing_linux_gate_surface() {
  local a_label
  local a_action

  a_label="${1:-LINUX-GATE}"
  a_action="${2:-unknown}"
  cat <<EOF
[${a_label}] FAILED (historical Linux shell gate helper "${a_action}" is not restored in this worktree)
[${a_label}] Use currently live local helpers instead:
[${a_label}]   bash tests/nextpas.core.simd/BuildOrTest.sh check
[${a_label}]   bash tests/nextpas.core.simd/BuildOrTest.sh wiring-sync
[${a_label}]   bash tests/nextpas.core.simd/BuildOrTest.sh nonx86-ieee754
[${a_label}]   bash tests/nextpas.core.simd/BuildOrTest.sh perf-smoke
[${a_label}]   bash tests/nextpas.core.simd/BuildOrTest.sh gate-summary-selfcheck
[${a_label}]   bash tests/nextpas.core.simd/BuildOrTest.sh freeze-status-linux
EOF
  return 2
}

case "${ACTION}" in
  clean)
    echo "[CLEAN] Removing ${OUTPUT_ROOT}/bin ${OUTPUT_ROOT}/lib ${OUTPUT_ROOT}/logs"
    rm -rf "${OUTPUT_ROOT}/bin" "${OUTPUT_ROOT}/lib" "${OUTPUT_ROOT}/logs" "${OUTPUT_ROOT}/nonx86.optin"
    ;;
  check)
    run_check
    ;;
  test)
    run_test "$@"
    ;;
  contract-signature)
    run_python_checker "DISPATCH-CONTRACT" "${ROOT}/check_dispatch_contract_signature.py" --summary-line --json-file "${DISPATCH_CONTRACT_JSON}"
    ;;
  publicabi-signature)
    run_python_checker "PUBLIC-ABI" "${ROOT}/check_public_abi_signature.py" --summary-line --json-file "${PUBLIC_ABI_JSON}"
    ;;
  coverage)
    run_intrinsics_coverage
    ;;
  experimental-intrinsics-tests)
    run_experimental_intrinsics_tests "$@"
    ;;
  experimental-intrinsics-closure)
    run_experimental_intrinsics_closure "$@"
    ;;
  wiring-sync)
    run_nonx86_wiring_sync "$@"
    ;;
  nonx86-ieee754)
    run_nonx86_ieee754 "$@"
    ;;
  perf-smoke)
    run_perf_smoke "$@"
    ;;
  nonx86-optin-list-suites)
    run_nonx86_optin_list_suites
    ;;
  helper-semantics)
    run_nonx86_helper_semantics
    ;;
  impl-smoke-nonx86)
    run_nonx86_impl_smoke
    ;;
  impl-audit-nonx86)
    run_nonx86_impl_audit
    ;;
  native-evidence)
    run_nonx86_native_evidence "$@"
    ;;
  verify-nonx86-native-evidence)
    run_nonx86_native_evidence_verify "$@"
    ;;
  import-nonx86-native-evidence)
    run_nonx86_native_evidence_import "$@"
    ;;
  closeout-host-local)
    run_closeout_host_local "$@"
    ;;
  closeout-host-local-from-import)
    run_closeout_host_local_from_import "$@"
    ;;
  gate)
    fail_missing_linux_gate_surface "GATE" "gate"
    ;;
  gate-strict)
    fail_missing_linux_gate_surface "GATE-STRICT" "gate-strict"
    ;;
  gate-summary)
    run_gate_summary "$@"
    ;;
  gate-summary-sample)
    run_gate_summary_sample "$@"
    ;;
  gate-summary-rehearsal)
    run_gate_summary_rehearsal "$@"
    ;;
  gate-summary-selfcheck)
    run_gate_summary_selfcheck "$@"
    ;;
  gate-summary-inject)
    run_gate_summary_inject "$@"
    ;;
  gate-summary-rollback)
    run_gate_summary_rollback "$@"
    ;;
  gate-summary-backups)
    run_gate_summary_backups "$@"
    ;;
  historical-closeout-note-check)
    run_historical_closeout_note_check "$@"
    ;;
  active-closeout-truth-check)
    run_active_closeout_truth_check "$@"
    ;;
  evidence-linux)
    fail_missing_linux_closeout_surface "EVIDENCE-LINUX" "evidence-linux"
    ;;
  verify-win-evidence)
    run_verify_windows_evidence "$@"
    ;;
  freeze-status)
    run_freeze_status 0 "$@"
    ;;
  freeze-status-linux)
    run_freeze_status 1 "$@"
    ;;
  freeze-status-rehearsal)
    run_freeze_status_rehearsal "$@"
    ;;
  win-closeout-dryrun|win-closeout-3cmd)
    run_win_closeout_3cmd "$@"
    ;;
  qemu-nonx86-evidence)
    run_qemu_action nonx86-evidence "$@"
    ;;
  qemu-cpuinfo-nonx86-evidence)
    run_qemu_action cpuinfo-nonx86-evidence "$@"
    ;;
  qemu-cpuinfo-nonx86-full-evidence)
    run_qemu_action cpuinfo-nonx86-full-evidence "$@"
    ;;
  qemu-cpuinfo-nonx86-full-repeat)
    run_qemu_action cpuinfo-nonx86-full-repeat "$@"
    ;;
  qemu-cpuinfo-nonx86-suite-repeat)
    run_qemu_action cpuinfo-nonx86-suite-repeat "$@"
    ;;
  qemu-arch-matrix-evidence)
    run_qemu_action arch-matrix-evidence "$@"
    ;;
  qemu-nonx86-experimental-asm)
    run_qemu_action nonx86-experimental-asm "$@"
    ;;
  closeout-release)
    fail_missing_windows_closeout_surface "CLOSEOUT-RELEASE" "closeout-release"
    ;;
  win-evidence-preflight)
    fail_missing_windows_closeout_surface "PREFLIGHT" "win-evidence-preflight"
    ;;
  win-evidence-via-gh)
    fail_missing_windows_closeout_surface "WIN-EVIDENCE-VIA-GH" "win-evidence-via-gh"
    ;;
  finalize-win-evidence)
    fail_missing_windows_closeout_surface "FINALIZE-WIN-EVIDENCE" "finalize-win-evidence"
    ;;
  win-closeout-snippets)
    fail_missing_windows_closeout_surface "WIN-CLOSEOUT-SNIPPETS" "win-closeout-snippets"
    ;;
  win-closeout-finalize)
    fail_missing_windows_closeout_surface "WIN-CLOSEOUT-FINALIZE" "win-closeout-finalize"
    ;;
  freshness)
    run_python_checker "FRESHNESS" "${ROOT}/check_freshness.py" --summary-line --json-file "${LOG_DIR}/freshness_check.json" --text-file "${LOG_DIR}/freshness_check.txt"
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
