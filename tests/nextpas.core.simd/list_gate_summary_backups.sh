#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
BACKUP_DIR="${ROOT}/logs/rehearsal/backups"

if [[ ! -d "${BACKUP_DIR}" ]]; then
  echo "[GATE-SUMMARY-BACKUPS] none (dir missing: ${BACKUP_DIR})"
  exit 0
fi

LATEST="$(ls -1t "${BACKUP_DIR}"/gate_summary.backup.*.md 2>/dev/null | head -n 1 || true)"
if [[ -z "${LATEST}" ]]; then
  echo "[GATE-SUMMARY-BACKUPS] none"
  exit 0
fi

echo "[GATE-SUMMARY-BACKUPS] dir=${BACKUP_DIR}"
ls -1t "${BACKUP_DIR}"/gate_summary.backup.*.md 2>/dev/null
