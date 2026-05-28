#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
COLLECT_SCRIPT="${ROOT}/collect_windows_b07_evidence.bat"
RUNBOOK="${ROOT}/docs/windows_b07_closeout_runbook.md"

if [[ ! -f "${COLLECT_SCRIPT}" ]]; then
  echo "[WIN-BASH-GATE-FALLBACK-REHEARSAL] Missing collect script: ${COLLECT_SCRIPT}"
  exit 2
fi

if [[ ! -f "${RUNBOOK}" ]]; then
  echo "[WIN-BASH-GATE-FALLBACK-REHEARSAL] Missing runbook: ${RUNBOOK}"
  exit 2
fi

if ! grep -F -- '[B07] WARN: SIMD_WIN_EVIDENCE_USE_BASH_GATE=1 requested, but cmd.exe cannot satisfy the current bash-gate prerequisites; fallback to native batch gate' "${COLLECT_SCRIPT}" >/dev/null; then
  echo "[WIN-BASH-GATE-FALLBACK-REHEARSAL] FAILED: missing strengthened fallback warning in collect_windows_b07_evidence.bat"
  exit 1
fi

if ! grep -F -- '[B07] WARN: current local Wine probes did not yield a working host-side Unix bridge ^(`where bash` / `start /unix`^); keep using native Windows LAZBUILD or a real Windows runner' "${COLLECT_SCRIPT}" >/dev/null; then
  echo "[WIN-BASH-GATE-FALLBACK-REHEARSAL] FAILED: missing Wine host-side bridge boundary warning in collect_windows_b07_evidence.bat"
  exit 1
fi

if ! grep -F -- '或仅在 `cmd.exe` 真的能解析 `bash` 的环境里显式 opt-in `SIMD_WIN_EVIDENCE_USE_BASH_GATE=1` 做诊断性预演；当前本机 Wine 不属于这种环境。' "${RUNBOOK}" >/dev/null; then
  echo "[WIN-BASH-GATE-FALLBACK-REHEARSAL] FAILED: runbook missing cmd.exe/bash caveat for SIMD_WIN_EVIDENCE_USE_BASH_GATE=1"
  exit 1
fi

echo "[WIN-BASH-GATE-FALLBACK-REHEARSAL] OK"
