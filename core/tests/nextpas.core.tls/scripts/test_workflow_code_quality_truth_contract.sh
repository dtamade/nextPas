#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORKFLOW_FILE="$ROOT_DIR/.github/workflows/code-quality.yml.disabled"

fail() {
  echo "[FAIL] $1"
  exit 1
}

[[ -f "$WORKFLOW_FILE" ]] || fail "missing workflow file: .github/workflows/code-quality.yml.disabled"

python3 - "$WORKFLOW_FILE" <<'PY'
from pathlib import Path
import sys

workflow = Path(sys.argv[1])
text = workflow.read_text(encoding="utf-8")

required_fragments = [
    "sudo apt-get install -y fpc lazarus",
    'echo "[INFO] system fpc: $(fpc -iV)"',
    'echo "[INFO] system lazbuild: $(lazbuild --version | head -n 1)"',
    "| Code Style | ${{ needs.code-style.result }} |",
    "| Documentation | ${{ needs.docs-check.result }} |",
    "| Build Verification | ${{ needs.build-check.result }} |",
    "| Module Integrity | ${{ needs.module-integrity.result }} |",
    "| Security Check | ${{ needs.security-check.result }} |",
    "This dormant template does not assert fixed coverage percentages, backend completeness, or a release grade.",
]

forbidden_fragments = [
    "fpc: '3.2.2'",
    "fpc: '3.3.1'",
    "| Test Coverage | ~85% |",
    "| Code Quality | ✅ Passed |",
    "| Documentation | ✅ Complete |",
    "| Build Status | ✅ Passing |",
    "**Overall Grade: A** ✅",
    "WinSSL Backend:    100% ✅",
]

for fragment in required_fragments:
    if fragment not in text:
        print(f"[FAIL] missing truthful code-quality fragment: {fragment}")
        raise SystemExit(1)

for fragment in forbidden_fragments:
    if fragment in text:
        print(f"[FAIL] stale code-quality fragment still present: {fragment}")
        raise SystemExit(1)

print("[PASS] code-quality workflow truth contract passed")
PY
