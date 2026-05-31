#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORKFLOW_FILE="$ROOT_DIR/.github/workflows/pr-checks.yml.disabled"

fail() {
  echo "[FAIL] $1"
  exit 1
}

[[ -f "$WORKFLOW_FILE" ]] || fail "missing workflow file: .github/workflows/pr-checks.yml.disabled"

python3 - "$WORKFLOW_FILE" <<'PY'
from pathlib import Path
import sys

workflow = Path(sys.argv[1])
text = workflow.read_text(encoding="utf-8")

required_fragments = [
    'echo "| PR Information | ${{ needs.pr-info.result }} |" >> $GITHUB_STEP_SUMMARY',
    'echo "| Quick Build | ${{ needs.quick-build.result }} |" >> $GITHUB_STEP_SUMMARY',
    'echo "| Test Coverage | ${{ needs.test-coverage-check.result }} |" >> $GITHUB_STEP_SUMMARY',
    'echo "| Code Statistics | ${{ needs.code-stats.result }} |" >> $GITHUB_STEP_SUMMARY',
    'echo "- This report reflects workflow job results from this run only." >> $GITHUB_STEP_SUMMARY',
]

forbidden_fragments = [
    'echo "| PR Information | ✅ Passed |" >> $GITHUB_STEP_SUMMARY',
    'echo "| Quick Build | ✅ Passed |" >> $GITHUB_STEP_SUMMARY',
    'echo "| Test Coverage | ✅ Passed |" >> $GITHUB_STEP_SUMMARY',
    'echo "| Code Statistics | ✅ Complete |" >> $GITHUB_STEP_SUMMARY',
    'echo "- Reviewers required: 2" >> $GITHUB_STEP_SUMMARY',
    'echo "- Checks required: 4" >> $GITHUB_STEP_SUMMARY',
    'echo "- Auto-merge: Disabled" >> $GITHUB_STEP_SUMMARY',
]

for fragment in required_fragments:
    if fragment not in text:
        print(f"[FAIL] missing truthful pr-checks summary fragment: {fragment}")
        raise SystemExit(1)

for fragment in forbidden_fragments:
    if fragment in text:
        print(f"[FAIL] stale pr-checks summary fragment still present: {fragment}")
        raise SystemExit(1)

print("[PASS] pr-checks summary truth contract passed")
PY
