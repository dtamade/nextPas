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

expected_sha="b7c566a772e6b6bfb58ed0dc250532a479d7789f"

mapfile -t workflow_files < <(find "$WORKFLOWS_DIR" -maxdepth 1 -type f \( -name '*.yml' -o -name '*.yml.disabled' \) | sort)
[[ "${#workflow_files[@]}" -gt 0 ]] || fail "no workflow files found under .github/workflows"

for workflow in "${workflow_files[@]}"; do
  if rg -n 'uses:\s*actions/upload-artifact@v[345]\b' "$workflow" >/dev/null; then
    rel="${workflow#$ROOT_DIR/}"
    fail "$rel must not keep pre-Node24 actions/upload-artifact references"
  fi
done
pass "all workflow files avoid actions/upload-artifact@v3, @v4, and @v5"

required_upload_workflows=(
  ".github/workflows/ci.yml"
  ".github/workflows/release.yml"
  ".github/workflows/release.yml.disabled"
  ".github/workflows/tls13-signer-gate.yml"
  ".github/workflows/wave-b-b2-manual.yml"
  ".github/workflows/wave-b-b2-manual.yml.disabled"
)

for rel in "${required_upload_workflows[@]}"; do
  abs="$ROOT_DIR/$rel"
  [[ -f "$abs" ]] || fail "missing expected workflow: $rel"
  if rg -n "uses:\\s*actions/upload-artifact@${expected_sha}\\b" "$abs" >/dev/null; then
    pass "$rel uses the pinned actions/upload-artifact commit"
  else
    fail "$rel must use actions/upload-artifact@${expected_sha}"
  fi
done

echo "[PASS] workflow upload-artifact Node24 contract passed"
