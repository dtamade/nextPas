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

required_depth_jobs = [
    "pr-info:",
    "test-coverage-check:",
    "code-stats:",
]

no_depth_jobs = [
    "quick-build:",
    "pr-report:",
]

for job in required_depth_jobs:
    start = text.find(job)
    if start < 0:
        print(f"[FAIL] missing job block: {job}")
        raise SystemExit(1)
    end = min([pos for pos in [text.find(other, start + len(job)) for other in required_depth_jobs + no_depth_jobs if text.find(other, start + len(job)) >= 0] or [len(text)]])
    block = text[start:end]
    if "fetch-depth: 2" not in block:
        print(f"[FAIL] {job[:-1]} checkout must fetch at least two commits for HEAD~1 diff checks")
        raise SystemExit(1)

for job in no_depth_jobs:
    start = text.find(job)
    if start < 0:
        print(f"[FAIL] missing job block: {job}")
        raise SystemExit(1)
    end = min([pos for pos in [text.find(other, start + len(job)) for other in required_depth_jobs + no_depth_jobs if text.find(other, start + len(job)) >= 0] or [len(text)]])
    block = text[start:end]
    if "fetch-depth:" in block:
        print(f"[FAIL] {job[:-1]} should not request extra checkout history")
        raise SystemExit(1)

print("[PASS] pr-checks history contract passed")
PY
