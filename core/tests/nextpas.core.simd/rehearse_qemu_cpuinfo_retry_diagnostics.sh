#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"

LACTION="${1:-qemu-cpuinfo-nonx86-evidence}"
LRETRIES="${SIMD_QEMU_RETRY_REHEARSAL_RETRIES:-2}"
LPLATFORMS="${SIMD_QEMU_RETRY_REHEARSAL_PLATFORMS:-linux/riscv64}"
LTAIL_LINES="${SIMD_QEMU_RETRY_REHEARSAL_TAIL_LINES:-40}"

require_docker_access() {
  if ! command -v docker >/dev/null 2>&1; then
    echo "[RETRY-REHEARSAL] FAILED: missing docker command required by QEMU multiarch rehearsal"
    return 2
  fi

  if ! docker version >/dev/null 2>&1; then
    echo "[RETRY-REHEARSAL] FAILED: docker daemon unavailable or permission denied"
    echo "[RETRY-REHEARSAL] Hint: ensure current user can access /var/run/docker.sock before running ${LACTION}"
    return 2
  fi
}

if [[ ! "${LACTION}" =~ ^qemu-cpuinfo-nonx86-(evidence|full-evidence|full-repeat)$ ]]; then
  echo "[RETRY-REHEARSAL] Unsupported action: ${LACTION}"
  echo "[RETRY-REHEARSAL] Supported: qemu-cpuinfo-nonx86-evidence | qemu-cpuinfo-nonx86-full-evidence | qemu-cpuinfo-nonx86-full-repeat"
  exit 2
fi

require_docker_access || exit $?

LSCENARIO="${LACTION#qemu-}"
LLOG_DIR="${ROOT}/logs"
LTS="$(date +%Y%m%d-%H%M%S)"
LLOG_FILE="${LLOG_DIR}/retry-rehearsal.${LSCENARIO}.${LTS}.log"

mkdir -p "${LLOG_DIR}"

echo "[RETRY-REHEARSAL] action=${LACTION}"
echo "[RETRY-REHEARSAL] scenario=${LSCENARIO}"
echo "[RETRY-REHEARSAL] platforms=${LPLATFORMS}"
echo "[RETRY-REHEARSAL] retries=${LRETRIES}"
echo "[RETRY-REHEARSAL] log=${LLOG_FILE}"

set +e
FAFAFA_BUILD_MODE=Release \
SIMD_QEMU_RETRIES="${LRETRIES}" \
SIMD_QEMU_PLATFORMS="${LPLATFORMS}" \
SIMD_QEMU_CPUINFO_FAIL_ONCE=1 \
SIMD_QEMU_CPUINFO_FAIL_ONCE_SCENARIO="${LSCENARIO}" \
SIMD_QEMU_CPUINFO_RETRY_LOG_TAIL_LINES="${LTAIL_LINES}" \
bash "${ROOT}/BuildOrTest.sh" "${LACTION}" 2>&1 | tee "${LLOG_FILE}"
LRC="${PIPESTATUS[0]}"
set -e

if [[ "${LRC}" -ne 0 ]]; then
  echo "[RETRY-REHEARSAL] FAILED: action returned rc=${LRC}"
  exit "${LRC}"
fi

if ! grep -q "\[INJECT\] cpuinfo fail-once" "${LLOG_FILE}"; then
  echo "[RETRY-REHEARSAL] FAILED: missing [INJECT] marker"
  exit 1
fi

if ! grep -q "\[DIAG\] cpuinfo retry context:" "${LLOG_FILE}"; then
  echo "[RETRY-REHEARSAL] FAILED: missing [DIAG] retry context"
  exit 1
fi

if ! grep -q "\[DIAG\] target build log:" "${LLOG_FILE}"; then
  echo "[RETRY-REHEARSAL] FAILED: missing [DIAG] target build log marker"
  exit 1
fi

if grep -q "\[DIAG\] missing build log" "${LLOG_FILE}"; then
  echo "[RETRY-REHEARSAL] FAILED: build log missing during diagnostics"
  exit 1
fi

LSUMMARY_FILE="$(grep -E '\[DONE\] Summary: ' "${LLOG_FILE}" | tail -n 1 | sed -E 's/.*Summary: //')"
if [[ -z "${LSUMMARY_FILE}" ]] || [[ ! -f "${LSUMMARY_FILE}" ]]; then
  echo "[RETRY-REHEARSAL] FAILED: summary file not found from output"
  exit 1
fi

if grep -q '| FAIL |' "${LSUMMARY_FILE}"; then
  echo "[RETRY-REHEARSAL] FAILED: summary contains FAIL rows"
  cat "${LSUMMARY_FILE}"
  exit 1
fi

echo "[RETRY-REHEARSAL] OK"
echo "[RETRY-REHEARSAL] summary=${LSUMMARY_FILE}"
echo "[RETRY-REHEARSAL] log=${LLOG_FILE}"
