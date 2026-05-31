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

expected_sha="a309ff8b426b58ec0e2a45f0f869d46889d02405"

mapfile -t workflow_files < <(find "$WORKFLOWS_DIR" -maxdepth 1 -type f \( -name '*.yml' -o -name '*.yml.disabled' \) | sort)
[[ "${#workflow_files[@]}" -gt 0 ]] || fail "no workflow files found under .github/workflows"

for workflow in "${workflow_files[@]}"; do
  if rg -n 'uses:\s*actions/setup-python@v[1-5]\b' "$workflow" >/dev/null; then
    rel="${workflow#$ROOT_DIR/}"
    fail "$rel must not keep pre-Node24-default actions/setup-python references"
  fi
done
pass "all workflow files avoid actions/setup-python@v1 through @v5"

required_setup_python_workflows=(
  ".github/workflows/code-quality.yml.disabled"
)

for rel in "${required_setup_python_workflows[@]}"; do
  abs="$ROOT_DIR/$rel"
  [[ -f "$abs" ]] || fail "missing expected workflow: $rel"
  if rg -n "uses:\\s*actions/setup-python@${expected_sha}\\b" "$abs" >/dev/null; then
    pass "$rel uses the pinned actions/setup-python commit"
  else
    fail "$rel must use actions/setup-python@${expected_sha}"
  fi
done

echo "[PASS] workflow setup-python Node24 contract passed"
