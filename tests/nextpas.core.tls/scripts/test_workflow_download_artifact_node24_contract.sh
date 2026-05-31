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

expected_sha="37930b1c2abaa49bbe596cd826c3c89aef350131"

mapfile -t workflow_files < <(find "$WORKFLOWS_DIR" -maxdepth 1 -type f \( -name '*.yml' -o -name '*.yml.disabled' \) | sort)
[[ "${#workflow_files[@]}" -gt 0 ]] || fail "no workflow files found under .github/workflows"

for workflow in "${workflow_files[@]}"; do
  if rg -n 'uses:\s*actions/download-artifact@v[3-6]\b' "$workflow" >/dev/null; then
    rel="${workflow#$ROOT_DIR/}"
    fail "$rel must not keep pre-Node24-default actions/download-artifact references"
  fi
done
pass "all workflow files avoid actions/download-artifact@v3 through @v6"

required_download_workflows=(
  ".github/workflows/ci-matrix-draft.yml.disabled"
  ".github/workflows/performance.yml.disabled"
  ".github/workflows/test-all-platforms.yml.disabled"
  ".github/workflows/wave-b-b2-manual.yml"
  ".github/workflows/wave-b-b2-manual.yml.disabled"
)

for rel in "${required_download_workflows[@]}"; do
  abs="$ROOT_DIR/$rel"
  [[ -f "$abs" ]] || fail "missing expected workflow: $rel"
  if rg -n "uses:\\s*actions/download-artifact@${expected_sha}\\b" "$abs" >/dev/null; then
    pass "$rel uses the pinned actions/download-artifact commit"
  else
    fail "$rel must use actions/download-artifact@${expected_sha}"
  fi
done

echo "[PASS] workflow download-artifact Node24 contract passed"
