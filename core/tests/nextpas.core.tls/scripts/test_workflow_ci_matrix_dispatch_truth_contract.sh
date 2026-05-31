#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORKFLOW_FILE="$ROOT_DIR/.github/workflows/ci-matrix-draft.yml.disabled"

fail() {
  echo "[FAIL] $1"
  exit 1
}

[[ -f "$WORKFLOW_FILE" ]] || fail "missing workflow file: .github/workflows/ci-matrix-draft.yml.disabled"

python3 - "$WORKFLOW_FILE" <<'PY'
from pathlib import Path
import sys

workflow = Path(sys.argv[1])
text = workflow.read_text(encoding="utf-8")

required_fragments = [
    'echo "| Linux(system OpenSSL) | ${{ needs.linux-matrix.result }} | n/a |" >> $GITHUB_STEP_SUMMARY',
    'echo "| macOS | ${{ needs.macos-test.result }} | ${SKIP_MACOS} |" >> $GITHUB_STEP_SUMMARY',
    'echo "| Windows | ${{ needs.windows-test.result }} | ${SKIP_WINDOWS} |" >> $GITHUB_STEP_SUMMARY',
    'Manual skip inputs only apply to workflow_dispatch runs; push/pull_request lanes always use the workflow defaults.',
]

forbidden_fragments = [
    'for dir in all-reports/*/; do',
    'platform=$(basename "$dir")',
    'grep -q "PASS\\|SUCCESS"',
    'echo "| $platform | ✅ Pass |" >> $GITHUB_STEP_SUMMARY',
]

for fragment in required_fragments:
    if fragment not in text:
        print(f"[FAIL] missing truthful ci-matrix dispatch fragment: {fragment}")
        raise SystemExit(1)

for fragment in forbidden_fragments:
    if fragment in text:
        print(f"[FAIL] stale ci-matrix dispatch fragment still present: {fragment}")
        raise SystemExit(1)

print("[PASS] ci-matrix workflow dispatch truth contract passed")
PY
