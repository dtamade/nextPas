#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

TEST_DIR="tmp/test_blockers_$(date +%s)"
mkdir -p "$PROJECT_ROOT/$TEST_DIR"
trap 'rm -rf "$PROJECT_ROOT/$TEST_DIR"' EXIT

echo "[TEST] Extract Pre-Release Audit Blockers - Path Resolution Contract"

# 使用实际的样例文件
CHECKLIST="docs/test_reports/PRE_RELEASE_ARCHIVE_AUDIT_CHECKLIST_SAMPLE_B28.md"
WEEKLY="docs/test_reports/ARCHIVE_AUDIT_WEEKLY_REPORT_SAMPLE_B29.md"
RISK_MATRIX="docs/test_reports/ARCHIVE_AUDIT_RISK_RESPONSE_SAMPLE_B31.md"
DASHBOARD="docs/test_reports/ARCHIVE_AUDIT_STATUS_DASHBOARD_SAMPLE_B30.md"

echo "[SCENARIO A] Execute from project root with relative paths"

cd "$PROJECT_ROOT"

bash scripts/extract_pre_release_audit_blockers_draft.sh \
  --blocker-id test_root \
  --checklist "$CHECKLIST" \
  --weekly-report "$WEEKLY" \
  --risk-matrix "$RISK_MATRIX" \
  --dashboard "$DASHBOARD" \
  --output "$TEST_DIR/blockers_root.md"

if [[ ! -f "$PROJECT_ROOT/$TEST_DIR/blockers_root.md" ]]; then
  echo "[FAIL] Scenario A: output file not generated"
  exit 1
fi

echo "[PASS] Scenario A: project root execution succeeded"

echo "[SCENARIO B] Execute from /tmp with relative paths"

cd /tmp

bash "$PROJECT_ROOT/scripts/extract_pre_release_audit_blockers_draft.sh" \
  --blocker-id test_tmp \
  --checklist "$CHECKLIST" \
  --weekly-report "$WEEKLY" \
  --risk-matrix "$RISK_MATRIX" \
  --dashboard "$DASHBOARD" \
  --output "$TEST_DIR/blockers_tmp.md" 2>&1 || {
    echo "[EXPECTED FAIL] Scenario B: /tmp execution failed (RED state)"
    exit 1
  }

if [[ ! -f "$PROJECT_ROOT/$TEST_DIR/blockers_tmp.md" ]]; then
  echo "[EXPECTED FAIL] Scenario B: output file not in expected location (RED state)"
  exit 1
fi

echo "[PASS] Scenario B: /tmp execution succeeded"
echo "[PASS] Path resolution contract passed"
exit 0
