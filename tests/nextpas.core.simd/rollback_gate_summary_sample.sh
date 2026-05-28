#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
TARGET_SUMMARY="${1:-${ROOT}/logs/gate_summary.md}"
BACKUP_FILE="${2:-${SIMD_GATE_SUMMARY_BACKUP_FILE:-}}"
BACKUP_DIR="${ROOT}/logs/rehearsal/backups"
META_FILE="${ROOT}/logs/rehearsal/latest_backup.path"

if [[ -z "${BACKUP_FILE}" && -f "${META_FILE}" ]]; then
  BACKUP_FILE="$(cat "${META_FILE}")"
fi

if [[ -z "${BACKUP_FILE}" ]]; then
  BACKUP_FILE="$(ls -1t "${BACKUP_DIR}"/gate_summary.backup.*.md 2>/dev/null | head -n 1 || true)"
fi

if [[ -z "${BACKUP_FILE}" ]]; then
  echo "[GATE-SUMMARY-ROLLBACK] No backup found under ${BACKUP_DIR}"
  exit 2
fi

if [[ ! -f "${BACKUP_FILE}" ]]; then
  echo "[GATE-SUMMARY-ROLLBACK] Backup not found: ${BACKUP_FILE}"
  exit 2
fi

mkdir -p "$(dirname "${TARGET_SUMMARY}")"
cp "${BACKUP_FILE}" "${TARGET_SUMMARY}"
echo "[GATE-SUMMARY-ROLLBACK] restored=${TARGET_SUMMARY} from=${BACKUP_FILE}"
