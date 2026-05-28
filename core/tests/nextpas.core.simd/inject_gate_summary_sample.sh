#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
SAMPLE_SCRIPT="${ROOT}/generate_gate_summary_sample.py"

SCENARIO="${1:-mixed}"
TARGET_SUMMARY="${2:-${ROOT}/logs/gate_summary.md}"
APPLY_MODE="${SIMD_GATE_SUMMARY_APPLY:-0}"

WARN_MS="${SIMD_GATE_STEP_WARN_MS:-20000}"
FAIL_MS="${SIMD_GATE_STEP_FAIL_MS:-120000}"

INJECT_DIR="${ROOT}/logs/rehearsal/injected"
BACKUP_DIR="${ROOT}/logs/rehearsal/backups"
META_DIR="${ROOT}/logs/rehearsal"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
SAMPLE_FILE="${INJECT_DIR}/gate_summary.injected.${SCENARIO}.${TIMESTAMP}.md"
BACKUP_FILE="${BACKUP_DIR}/gate_summary.backup.${TIMESTAMP}.md"

mkdir -p "${INJECT_DIR}" "${BACKUP_DIR}" "${META_DIR}"

if [[ ! -f "${SAMPLE_SCRIPT}" ]]; then
  echo "[GATE-SUMMARY-INJECT] Missing sample generator: ${SAMPLE_SCRIPT}"
  exit 2
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "[GATE-SUMMARY-INJECT] Missing python3"
  exit 2
fi

python3 "${SAMPLE_SCRIPT}" \
  --scenario "${SCENARIO}" \
  --warn-ms "${WARN_MS}" \
  --fail-ms "${FAIL_MS}" \
  --output "${SAMPLE_FILE}" >/tmp/simd_gate_summary_inject_sample.log

echo "${SAMPLE_FILE}" > "${META_DIR}/latest_injected.path"
echo "[GATE-SUMMARY-INJECT] sample=${SAMPLE_FILE}"

action="shadow"
if [[ "${APPLY_MODE}" != "0" ]]; then
  if [[ -f "${TARGET_SUMMARY}" ]]; then
    cp "${TARGET_SUMMARY}" "${BACKUP_FILE}"
    echo "${BACKUP_FILE}" > "${META_DIR}/latest_backup.path"
    echo "[GATE-SUMMARY-INJECT] backup=${BACKUP_FILE}"
  else
    echo "[GATE-SUMMARY-INJECT] WARN: target missing, backup skipped: ${TARGET_SUMMARY}"
  fi

  cp "${SAMPLE_FILE}" "${TARGET_SUMMARY}"
  echo "[GATE-SUMMARY-INJECT] applied target=${TARGET_SUMMARY}"
  action="applied"
else
  echo "[GATE-SUMMARY-INJECT] non-invasive mode (set SIMD_GATE_SUMMARY_APPLY=1 to replace target)"
fi

echo "[GATE-SUMMARY-INJECT] mode=${action}"
