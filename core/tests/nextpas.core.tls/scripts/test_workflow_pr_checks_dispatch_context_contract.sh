#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORKFLOW_FILE="$ROOT_DIR/.github/workflows/pr-checks.yml.disabled"

fail() {
  echo "[FAIL] $1"
  exit 1
}

pass() {
  echo "[PASS] $1"
}

[[ -f "$WORKFLOW_FILE" ]] || fail "missing workflow file: .github/workflows/pr-checks.yml.disabled"

python3 - "$WORKFLOW_FILE" <<'PY'
from pathlib import Path
import sys

workflow = Path(sys.argv[1])
text = workflow.read_text(encoding="utf-8")

required_fragments = [
    'if [[ "${{ github.event_name }}" == "pull_request" ]]; then',
    'echo "ℹ️  Manual dispatch: no PR title available"',
    'echo "ℹ️  Manual dispatch: no PR description available"',
    'PR_NUMBER="manual"',
    'PR_TITLE="Manual dispatch"',
    'PR_AUTHOR="${{ github.actor }}"',
    'BRANCH="${{ github.ref_name }}"',
    'BASE_BRANCH="manual-dispatch"',
]

for fragment in required_fragments:
    if fragment not in text:
        print(f"[FAIL] missing manual-dispatch guard fragment: {fragment}")
        raise SystemExit(1)

print("[PASS] pr-checks dispatch context contract passed")
PY
