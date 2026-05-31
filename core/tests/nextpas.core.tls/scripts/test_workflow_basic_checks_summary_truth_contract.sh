#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORKFLOW_FILE="$ROOT_DIR/.github/workflows/basic-checks.yml.disabled"

fail() {
  echo "[FAIL] $1"
  exit 1
}

[[ -f "$WORKFLOW_FILE" ]] || fail "missing workflow file: .github/workflows/basic-checks.yml.disabled"

python3 - "$WORKFLOW_FILE" <<'PY'
from pathlib import Path
import sys

workflow = Path(sys.argv[1])
text = workflow.read_text(encoding="utf-8")

required_fragments = [
    '- name: 📊 Generate report',
    'if: always()',
    'id: file-structure',
    'id: required-files',
    'id: basic-syntax',
    'echo "| Check file structure | ${{ steps.file-structure.outcome }} |" >> $GITHUB_STEP_SUMMARY',
    'echo "| Check required files | ${{ steps.required-files.outcome }} |" >> $GITHUB_STEP_SUMMARY',
    'echo "| Basic Pascal syntax | ${{ steps.basic-syntax.outcome }} |" >> $GITHUB_STEP_SUMMARY',
    'echo "**Note**: This report reflects step results from this run only." >> $GITHUB_STEP_SUMMARY',
]

forbidden_fragments = [
    'echo "✅ Project structure valid" >> $GITHUB_STEP_SUMMARY',
    'echo "✅ Required files present" >> $GITHUB_STEP_SUMMARY',
    'echo "✅ Basic syntax check passed" >> $GITHUB_STEP_SUMMARY',
]

for fragment in required_fragments:
    if fragment not in text:
        print(f"[FAIL] missing truthful basic-checks fragment: {fragment}")
        raise SystemExit(1)

for fragment in forbidden_fragments:
    if fragment in text:
        print(f"[FAIL] stale basic-checks fragment still present: {fragment}")
        raise SystemExit(1)

print("[PASS] basic-checks summary truth contract passed")
PY
