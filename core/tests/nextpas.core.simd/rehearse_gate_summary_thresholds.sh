#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
RUNNER="${ROOT}/BuildOrTest.sh"
SAMPLE_GEN="${ROOT}/generate_gate_summary_sample.py"
REHEARSAL_DIR="${ROOT}/logs/rehearsal"

WARN_MS="${SIMD_REHEARSAL_WARN_MS:-10000}"
FAIL_MS="${SIMD_REHEARSAL_FAIL_MS:-15000}"

mkdir -p "${REHEARSAL_DIR}"

if [[ ! -f "${RUNNER}" ]]; then
  echo "[REHEARSAL] Missing runner: ${RUNNER}"
  exit 2
fi

if [[ ! -f "${SAMPLE_GEN}" ]]; then
  echo "[REHEARSAL] Missing sample generator: ${SAMPLE_GEN}"
  exit 2
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "[REHEARSAL] Missing python3"
  exit 2
fi

FAIL_SAMPLE="${REHEARSAL_DIR}/gate_summary.sample.fail.md"
SLOW_SAMPLE="${REHEARSAL_DIR}/gate_summary.sample.slow.md"
SLOW_JSON="${REHEARSAL_DIR}/gate_summary.sample.slow.json"

python3 "${SAMPLE_GEN}" --scenario fail --warn-ms "${WARN_MS}" --fail-ms "${FAIL_MS}" --output "${FAIL_SAMPLE}" >/tmp/simd_rehearsal_sample_fail.log
python3 "${SAMPLE_GEN}" --scenario slow --warn-ms "${WARN_MS}" --fail-ms "${FAIL_MS}" --output "${SLOW_SAMPLE}" >/tmp/simd_rehearsal_sample_slow.log

echo "[REHEARSAL] FAIL filter on fail sample"
FAIL_OUT="${REHEARSAL_DIR}/fail_filter.out"
SIMD_GATE_SUMMARY_FILE="${FAIL_SAMPLE}" SIMD_GATE_SUMMARY_FILTER=FAIL bash "${RUNNER}" gate-summary >"${FAIL_OUT}"
if ! rg -q "matched_rows=[1-9][0-9]*" "${FAIL_OUT}"; then
  echo "[REHEARSAL] FAILED: FAIL filter matched_rows expected > 0"
  exit 1
fi
if ! rg -q "\| FAIL \|" "${FAIL_OUT}"; then
  echo "[REHEARSAL] FAILED: FAIL row not shown"
  exit 1
fi

echo "[REHEARSAL] SLOW filter on slow sample"
SLOW_OUT="${REHEARSAL_DIR}/slow_filter.out"
SIMD_GATE_SUMMARY_FILE="${SLOW_SAMPLE}" SIMD_GATE_SUMMARY_FILTER=SLOW SIMD_GATE_STEP_WARN_MS="${WARN_MS}" SIMD_GATE_STEP_FAIL_MS="${FAIL_MS}" bash "${RUNNER}" gate-summary >"${SLOW_OUT}"
if ! rg -q "thresholds: warn_ms=${WARN_MS}, fail_ms=${FAIL_MS}" "${SLOW_OUT}"; then
  echo "[REHEARSAL] FAILED: thresholds line mismatch"
  exit 1
fi
if ! rg -q "matched_rows=[1-9][0-9]*" "${SLOW_OUT}"; then
  echo "[REHEARSAL] FAILED: SLOW filter matched_rows expected > 0"
  exit 1
fi
if ! rg -q "SLOW_WARN|SLOW_CRIT" "${SLOW_OUT}"; then
  echo "[REHEARSAL] FAILED: SLOW rows not shown"
  exit 1
fi

echo "[REHEARSAL] JSON export check"
SIMD_GATE_SUMMARY_FILE="${SLOW_SAMPLE}" SIMD_GATE_SUMMARY_FILTER=SLOW SIMD_GATE_SUMMARY_JSON=1 SIMD_GATE_SUMMARY_JSON_FILE="${SLOW_JSON}" SIMD_GATE_STEP_WARN_MS="${WARN_MS}" SIMD_GATE_STEP_FAIL_MS="${FAIL_MS}" bash "${RUNNER}" gate-summary >"${REHEARSAL_DIR}/slow_json.out"

python3 - "${SLOW_JSON}" "${WARN_MS}" "${FAIL_MS}" <<'PY'
import json
import sys
from pathlib import Path

json_path = Path(sys.argv[1])
warn_ms = int(sys.argv[2])
fail_ms = int(sys.argv[3])

if not json_path.exists() or json_path.stat().st_size == 0:
    raise SystemExit(1)

payload = json.loads(json_path.read_text(encoding='utf-8'))
if payload.get('filter') != 'SLOW':
    raise SystemExit(1)
if int(payload.get('warn_ms', -1)) != warn_ms:
    raise SystemExit(1)
if int(payload.get('fail_ms', -1)) != fail_ms:
    raise SystemExit(1)
if int(payload.get('matched_rows', 0)) <= 0:
    raise SystemExit(1)
PY

echo "[REHEARSAL] OK dir=${REHEARSAL_DIR}"
