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
    "name: linux-system-openssl-reports",
    'echo "[INFO] system OpenSSL: $(openssl version)"',
]

forbidden_fragments = [
    "openssl: ['3.0', '3.1', '3.2']",
    "apt_package:",
    "linux-openssl-${{ matrix.openssl }}-reports",
    "${{ matrix.openssl }}",
]

for fragment in required_fragments:
    if fragment not in text:
        print(f"[FAIL] missing truthful ci-matrix-draft fragment: {fragment}")
        raise SystemExit(1)

for fragment in forbidden_fragments:
    if fragment in text:
        print(f"[FAIL] stale fake-matrix fragment still present: {fragment}")
        raise SystemExit(1)

print("[PASS] ci-matrix-draft workflow truth contract passed")
PY
