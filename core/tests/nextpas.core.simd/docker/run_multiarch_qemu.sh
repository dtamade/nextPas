#!/usr/bin/env bash
set -euo pipefail

ACTION="${1:-nonx86-evidence}"
shift || true

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CORE_ROOT="$(cd "${ROOT}/../.." && pwd)"
REPO_ROOT="$(cd "${CORE_ROOT}/.." && pwd)"
DEFAULT_OUTPUT_ROOT="${CORE_ROOT}/build/tests/nextpas.core.simd.qemu"
SIMD_OUTPUT_ROOT="${SIMD_OUTPUT_ROOT:-${DEFAULT_OUTPUT_ROOT}}"
SIMD_QEMU_DRY_RUN="${SIMD_QEMU_DRY_RUN:-0}"
SIMD_QEMU_CPUINFO_REPEAT_ROUNDS="${SIMD_QEMU_CPUINFO_REPEAT_ROUNDS:-2}"
LOG_DIR="${SIMD_OUTPUT_ROOT}/logs"

mkdir -p "${LOG_DIR}"

usage() {
  cat <<'EOF'
Usage: run_multiarch_qemu.sh [nonx86-evidence|cpuinfo-nonx86-evidence|cpuinfo-nonx86-full-evidence|cpuinfo-nonx86-full-repeat|cpuinfo-nonx86-suite-repeat|arch-matrix-evidence|nonx86-experimental-asm]

This is a minimal QEMU helper foundation slice.
- `SIMD_QEMU_DRY_RUN=1` emits the planned command chain and returns success.
- Default execution mode fails close until the real docker/qemu orchestration is restored.
EOF
}

default_nonx86_platforms() {
  printf '%s\n' "${SIMD_QEMU_PLATFORMS_NONX86:-linux/arm/v7 linux/arm64 linux/riscv64}"
}

platforms_for_action() {
  local a_action

  a_action="${1:-}"
  if [[ "${a_action}" == "arch-matrix-evidence" ]]; then
    printf '%s\n' "${SIMD_QEMU_PLATFORMS:-linux/386 linux/amd64 linux/arm/v7 linux/arm64 linux/riscv64}"
    return 0
  fi

  if [[ -n "${SIMD_QEMU_PLATFORMS:-}" ]]; then
    printf '%s\n' "${SIMD_QEMU_PLATFORMS}"
    return 0
  fi

  default_nonx86_platforms
}

emit_plan_or_fail_close() {
  local a_action
  local a_plan
  local l_plan_file

  a_action="${1:-}"
  a_plan="${2:-}"
  l_plan_file="${LOG_DIR}/${a_action}.plan.txt"

  printf '%s\n' "${a_plan}" > "${l_plan_file}"
  echo "[QEMU-RUNNER] action=${a_action}"
  echo "[QEMU-RUNNER] plan_file=${l_plan_file}"
  echo "[QEMU-RUNNER] platforms=$(platforms_for_action "${a_action}")"
  cat "${l_plan_file}"

  if [[ "${SIMD_QEMU_DRY_RUN}" == "1" ]]; then
    echo "[QEMU-RUNNER] DRY-RUN OK"
    return 0
  fi

  echo "[QEMU-RUNNER] FAIL-CLOSE: docker/qemu execution path is not restored in this minimal runner yet; rerun with SIMD_QEMU_DRY_RUN=1 to inspect the planned command chain"
  return 2
}

build_nonx86_evidence_cmd() {
  # Source-contract anchor for helper/native-evidence checkers:
  # LDirectParityLog="\${SIMD_OUTPUT_ROOT}/logs/direct_nonx86_runtime_parity.txt";
  local LDirectParityLog="${SIMD_OUTPUT_ROOT}/logs/direct_nonx86_runtime_parity.txt";

  cat <<EOF
# action=nonx86-evidence
# repo_root=${REPO_ROOT}
# platforms=$(platforms_for_action nonx86-evidence)
mkdir -p "$(dirname "${LDirectParityLog}")"
bash tests/nextpas.core.simd/docker/run_fpc_tests.sh --vector-asm --suite=TTestCase_NonX86BackendParity,TTestCase_DataPlane | tee "${LDirectParityLog}"
bash tests/nextpas.core.simd/run_backend_benchmarks.sh
EOF
}

build_cpuinfo_nonx86_evidence_cmd() {
  cat <<EOF
# action=cpuinfo-nonx86-evidence
# repo_root=${REPO_ROOT}
# platforms=$(platforms_for_action cpuinfo-nonx86-evidence)
bash tests/nextpas.core.simd.cpuinfo/BuildOrTest.sh check
bash tests/nextpas.core.simd.cpuinfo/BuildOrTest.sh test --list-suites
bash tests/nextpas.core.simd.cpuinfo/BuildOrTest.sh test --suite=TTestCase_PlatformSpecific
EOF
}

build_cpuinfo_nonx86_full_evidence_cmd() {
  cat <<EOF
# action=cpuinfo-nonx86-full-evidence
# repo_root=${REPO_ROOT}
# platforms=$(platforms_for_action cpuinfo-nonx86-full-evidence)
bash tests/nextpas.core.simd.cpuinfo/BuildOrTest.sh check
bash tests/nextpas.core.simd.cpuinfo/BuildOrTest.sh test --list-suites
bash tests/nextpas.core.simd.cpuinfo/BuildOrTest.sh test --suite=TTestCase_PlatformSpecific
bash tests/nextpas.core.simd.cpuinfo/BuildOrTest.sh test
EOF
}

build_cpuinfo_nonx86_full_repeat_cmd() {
  cat <<EOF
# action=cpuinfo-nonx86-full-repeat
# repo_root=${REPO_ROOT}
# platforms=$(platforms_for_action cpuinfo-nonx86-full-repeat)
# rounds=${SIMD_QEMU_CPUINFO_REPEAT_ROUNDS}
for round in \$(seq 1 "${SIMD_QEMU_CPUINFO_REPEAT_ROUNDS}"); do
  bash tests/nextpas.core.simd.cpuinfo/BuildOrTest.sh check
  bash tests/nextpas.core.simd.cpuinfo/BuildOrTest.sh test --list-suites
  bash tests/nextpas.core.simd.cpuinfo/BuildOrTest.sh test --suite=TTestCase_PlatformSpecific
  bash tests/nextpas.core.simd.cpuinfo/BuildOrTest.sh test
done
EOF
}

build_cpuinfo_nonx86_suite_repeat_cmd() {
  cat <<EOF
# action=cpuinfo-nonx86-suite-repeat
# repo_root=${REPO_ROOT}
# platforms=$(platforms_for_action cpuinfo-nonx86-suite-repeat)
# rounds=${SIMD_QEMU_CPUINFO_REPEAT_ROUNDS}
for round in \$(seq 1 "${SIMD_QEMU_CPUINFO_REPEAT_ROUNDS}"); do
  bash tests/nextpas.core.simd.cpuinfo/BuildOrTest.sh test --list-suites
  bash tests/nextpas.core.simd.cpuinfo/BuildOrTest.sh test --suite=TTestCase_PlatformSpecific
done
EOF
}

build_arch_matrix_evidence_cmd() {
  cat <<EOF
# action=arch-matrix-evidence
# repo_root=${REPO_ROOT}
# platforms=$(platforms_for_action arch-matrix-evidence)
bash tests/nextpas.core.simd/docker/run_fpc_tests.sh --vector-asm --suite=TTestCase_DispatchAPI,TTestCase_PublicAbi
bash tests/nextpas.core.simd/docker/run_fpc_tests.sh --vector-asm --suite=TTestCase_NonX86BackendParity,TTestCase_DataPlane
EOF
}

build_nonx86_experimental_asm_cmd() {
  cat <<EOF
# action=nonx86-experimental-asm
# repo_root=${REPO_ROOT}
# platforms=$(platforms_for_action nonx86-experimental-asm)
# non-x86 AES import/fail-close probe: compile/import guard wiring only, not runtime AES support.
bash tests/nextpas.core.simd.intrinsics.experimental/BuildOrTest.sh nonx86-aes-import-failclose
SIMD_FPC_EXTRA_DEFINES='${SIMD_QEMU_EXPERIMENTAL_DEFINE:--dFAFAFA_SIMD_EXPERIMENTAL_BACKEND_ASM}' bash tests/nextpas.core.simd/docker/run_fpc_tests.sh --vector-asm --suite=TTestCase_NonX86BackendParity,TTestCase_DataPlane
EOF
}

case "${ACTION}" in
  nonx86-evidence)
    emit_plan_or_fail_close "${ACTION}" "$(build_nonx86_evidence_cmd)"
    ;;
  cpuinfo-nonx86-evidence)
    emit_plan_or_fail_close "${ACTION}" "$(build_cpuinfo_nonx86_evidence_cmd)"
    ;;
  cpuinfo-nonx86-full-evidence)
    emit_plan_or_fail_close "${ACTION}" "$(build_cpuinfo_nonx86_full_evidence_cmd)"
    ;;
  cpuinfo-nonx86-full-repeat)
    emit_plan_or_fail_close "${ACTION}" "$(build_cpuinfo_nonx86_full_repeat_cmd)"
    ;;
  cpuinfo-nonx86-suite-repeat)
    emit_plan_or_fail_close "${ACTION}" "$(build_cpuinfo_nonx86_suite_repeat_cmd)"
    ;;
  arch-matrix-evidence)
    emit_plan_or_fail_close "${ACTION}" "$(build_arch_matrix_evidence_cmd)"
    ;;
  nonx86-experimental-asm)
    emit_plan_or_fail_close "${ACTION}" "$(build_nonx86_experimental_asm_cmd)"
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
