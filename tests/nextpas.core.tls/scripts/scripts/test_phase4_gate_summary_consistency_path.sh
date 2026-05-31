#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$ROOT_DIR/scripts/check_cross_platform_gate_summary_consistency_draft.sh"
REL_SUMMARY="docs/test_reports/CROSS_PLATFORM_GATE_SUMMARY_SAMPLE_B20.md"

run_main_contract() {
  (cd "$ROOT_DIR" && bash "$SCRIPT" --summary "$REL_SUMMARY" >/dev/null)

  # Key contract: should also work outside repo root with same relative path
  (cd /tmp && bash "$SCRIPT" --summary "$REL_SUMMARY" >/dev/null)

  echo "[PASS] path resolution contract passed"
}

run_strict_contract() {
  local work="$ROOT_DIR/tmp/test_phase4_gate_summary_consistency"
  local inconsistent="$work/inconsistent_summary.md"
  mkdir -p "$work"

  cat > "$inconsistent" <<'MD'
# Cross Platform Gate Summary

- run_id: inconsistent_case
- input_reports: 2

## 1) Input Evidence Reports

| platform | report_file | note |
|----------|-------------|------|
| linux | report_a.md | ok |

## 2) Layer Signal Snapshot

| platform | layer | status |
|----------|-------|--------|
| linux | L0 | pass |
| linux | L1 | pass |
| linux | L2 | pass |
| linux | L3 | pass |

## 3) Platform Aggregate

| platform | pass | fail | unknown |
|----------|------|------|---------|
| linux | 4 | 0 | 0 |
MD

  if bash "$SCRIPT" --summary "$inconsistent" --strict >/dev/null 2>&1; then
    echo "[FAIL] strict mode should fail on inconsistent summary"
    exit 1
  fi

  echo "[PASS] strict mode contract passed"
}

if [[ "${1:-}" == "--strict-check" ]]; then
  run_strict_contract
  exit 0
fi

run_main_contract
