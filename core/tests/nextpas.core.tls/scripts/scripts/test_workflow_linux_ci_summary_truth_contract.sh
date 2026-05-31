#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORKFLOW_FILE="$ROOT_DIR/.github/workflows/linux-ci.yml.disabled"

fail() {
  echo "[FAIL] $1"
  exit 1
}

[[ -f "$WORKFLOW_FILE" ]] || fail "missing workflow file: .github/workflows/linux-ci.yml.disabled"

python3 - "$WORKFLOW_FILE" <<'PY'
from pathlib import Path
import sys

workflow = Path(sys.argv[1])
text = workflow.read_text(encoding="utf-8")

required_fragments = [
    'name: 🧾 Linux CI Result Summary',
    'echo "## 🐧 fafafa.ssl Linux CI Result" >> $GITHUB_STEP_SUMMARY',
    'echo "- Build & Test job result: ${{ needs.build-and-test.result }}" >> $GITHUB_STEP_SUMMARY',
    'echo "- Scope: ubuntu-latest build-and-test lane from this run only." >> $GITHUB_STEP_SUMMARY',
    'echo "- Review the \\`build-and-test\\` logs and \\`test-results-linux\\` artifact for details." >> $GITHUB_STEP_SUMMARY',
    'echo "- Compilation details: review the \\`compile_all_modules.py\\` job output for the exact module set compiled on this runner." >> $GITHUB_STEP_SUMMARY',
    'echo "- Compilation result for this run is reflected by the job status and logs above." >> $GITHUB_STEP_SUMMARY',
    'echo "- WinSSL-specific evidence requires a Windows lane; this Linux run does not prove WinSSL behavior." >> $GITHUB_STEP_SUMMARY',
]

forbidden_fragments = [
    'name: ✅ All Checks Passed',
    'echo "🎯 Project is ready for integration"',
    'echo "- Expected compile: ~75 (excludes WinSSL)" >> $GITHUB_STEP_SUMMARY',
    'echo "- Status: ✅ See job output" >> $GITHUB_STEP_SUMMARY',
    'echo "- Full test coverage requires Windows runner for WinSSL" >> $GITHUB_STEP_SUMMARY',
]

for fragment in required_fragments:
    if fragment not in text:
        print(f"[FAIL] missing truthful linux-ci fragment: {fragment}")
        raise SystemExit(1)

for fragment in forbidden_fragments:
    if fragment in text:
        print(f"[FAIL] stale linux-ci fragment still present: {fragment}")
        raise SystemExit(1)

print("[PASS] linux-ci summary truth contract passed")
PY
