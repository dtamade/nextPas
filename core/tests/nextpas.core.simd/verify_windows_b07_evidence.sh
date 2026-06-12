#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYTHON_BIN="${PYTHON_BIN:-python3}"
VERIFY_SCRIPT="${ROOT}/verify_windows_b07_evidence.py"

if [[ ! -f "${VERIFY_SCRIPT}" ]]; then
  echo "[EVIDENCE] Missing verifier: ${VERIFY_SCRIPT}"
  exit 2
fi

if ! command -v "${PYTHON_BIN}" >/dev/null 2>&1; then
  echo "[EVIDENCE] Missing python runtime: ${PYTHON_BIN}"
  exit 2
fi

exec "${PYTHON_BIN}" "${VERIFY_SCRIPT}" "$@"
