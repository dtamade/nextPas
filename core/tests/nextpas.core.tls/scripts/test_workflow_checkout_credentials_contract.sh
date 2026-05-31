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
import re
import sys

workflows_dir = Path(sys.argv[1])
workflow_files = sorted(
    p for p in workflows_dir.iterdir()
    if p.is_file() and (p.name.endswith(".yml") or p.name.endswith(".yml.disabled"))
)

if not workflow_files:
    print("[FAIL] no workflow files found under .github/workflows")
    raise SystemExit(1)

uses_re = re.compile(r"^(\s*)uses:\s*actions/checkout@[0-9a-f]{40}\b")

for workflow in workflow_files:
    rel = workflow.relative_to(workflows_dir.parent.parent).as_posix()
    lines = workflow.read_text(encoding="utf-8").splitlines()

    i = 0
    while i < len(lines):
      match = uses_re.match(lines[i])
      if match is None:
          i += 1
          continue

      base_indent = len(match.group(1))
      found_persist = False
      j = i + 1
      while j < len(lines):
          line = lines[j]
          stripped = line.strip()
          if stripped == "":
              j += 1
              continue
          indent = len(line) - len(line.lstrip(" "))
          # Step child keys (`with:`, `if:`, etc.) stay at the same indent as `uses:`.
          if indent < base_indent:
              break
          if stripped == "persist-credentials: false":
              found_persist = True
          j += 1

      if not found_persist:
          print(f"[FAIL] {rel}:{i + 1} checkout step must set persist-credentials: false")
          raise SystemExit(1)

      i = j

print("[PASS] workflow checkout credential contract passed")
PY
