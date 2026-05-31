#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORKFLOW_FILE="$ROOT_DIR/.github/workflows/performance.yml.disabled"

fail() {
  echo "[FAIL] $1"
  exit 1
}

[[ -f "$WORKFLOW_FILE" ]] || fail "missing workflow file: .github/workflows/performance.yml.disabled"

python3 - "$WORKFLOW_FILE" <<'PY'
from pathlib import Path
import sys

workflow = Path(sys.argv[1])
text = workflow.read_text(encoding="utf-8")

required_fragments = [
    "workflow_dispatch:",
    "./tests/bin/test_performance_comparison",
    "- Benchmark scope: full checked-in comparison suite",
    "This dormant Linux benchmark workflow does not expose per-category dispatch inputs until the benchmark binary supports them.",
]

forbidden_fragments = [
    "Benchmark to run",
    "github.event.inputs.benchmark",
    "Benchmark selection:",
    "options:",
    "          - crypto",
    "          - ssl",
    "          - memory",
]

for fragment in required_fragments:
    if fragment not in text:
        print(f"[FAIL] missing truthful performance dispatch fragment: {fragment}")
        raise SystemExit(1)

for fragment in forbidden_fragments:
    if fragment in text:
        print(f"[FAIL] stale performance dispatch fragment still present: {fragment}")
        raise SystemExit(1)

print("[PASS] performance workflow dispatch truth contract passed")
PY
