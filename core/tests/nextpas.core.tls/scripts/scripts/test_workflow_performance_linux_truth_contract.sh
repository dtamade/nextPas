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
    "os: [ubuntu-latest]",
    "shell: bash",
    "fpc -Fusrc -FEtests/bin tests/test_performance_comparison.pas",
    "./tests/bin/test_performance_comparison",
    'find benchmark-reports -name "Performance-Report-*.md"',
    "- Benchmark scope: full checked-in comparison suite",
]

forbidden_fragments = [
    "Benchmark to run",
    "github.event.inputs.benchmark",
    "windows-latest",
    "macos-latest",
    "lazbuild tests/test_performance_comparison.lpi",
    "Write-Host",
    "Test-Path",
    "Out-File -FilePath",
    "Get-Date -Format",
    ".\\tests\\bin\\test_performance_comparison.exe",
    "Consistent performance across all platforms",
]

for fragment in required_fragments:
    if fragment not in text:
        print(f"[FAIL] missing performance workflow truth fragment: {fragment}")
        raise SystemExit(1)

for fragment in forbidden_fragments:
    if fragment in text:
        print(f"[FAIL] stale cross-platform workflow fragment still present: {fragment}")
        raise SystemExit(1)

print("[PASS] performance workflow linux-truth contract passed")
PY
