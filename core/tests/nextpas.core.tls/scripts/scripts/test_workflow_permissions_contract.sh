#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORKFLOWS_DIR="$ROOT_DIR/.github/workflows"

fail() {
  echo "[FAIL] $1"
  exit 1
}

pass() {
  echo "[PASS] $1"
}

[[ -d "$WORKFLOWS_DIR" ]] || fail "missing workflows directory: .github/workflows"

python3 - "$WORKFLOWS_DIR" <<'PY'
from pathlib import Path
import sys

workflows_dir = Path(sys.argv[1])
workflow_files = sorted(
    p for p in workflows_dir.iterdir()
    if p.is_file() and (p.name.endswith(".yml") or p.name.endswith(".yml.disabled"))
)

if not workflow_files:
    print("[FAIL] no workflow files found under .github/workflows")
    raise SystemExit(1)

release_names = {"release.yml", "release.yml.disabled"}
expected_read = "  contents: read"
expected_write = "  contents: write"

for workflow in workflow_files:
    rel = workflow.relative_to(workflows_dir.parent.parent).as_posix()
    lines = workflow.read_text(encoding="utf-8").splitlines()
    try:
        idx = lines.index("permissions:")
    except ValueError:
        print(f"[FAIL] {rel} must declare top-level permissions explicitly")
        raise SystemExit(1)

    if idx + 1 >= len(lines):
        print(f"[FAIL] {rel} permissions block is incomplete")
        raise SystemExit(1)

    expected = expected_write if workflow.name in release_names else expected_read
    actual = lines[idx + 1]
    if actual != expected:
        print(f"[FAIL] {rel} must use permissions line '{expected.strip()}', got '{actual.strip()}'")
        raise SystemExit(1)

print("[PASS] workflow permissions contract passed")
PY
