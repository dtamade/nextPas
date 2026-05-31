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

expected_sha="93cb6efe18208431cddfb8368fd83d5badbf9bfd"

mapfile -t workflow_files < <(find "$WORKFLOWS_DIR" -maxdepth 1 -type f \( -name '*.yml' -o -name '*.yml.disabled' \) | sort)
[[ "${#workflow_files[@]}" -gt 0 ]] || fail "no workflow files found under .github/workflows"

for workflow in "${workflow_files[@]}"; do
  if rg -n 'uses:\s*actions/checkout@v[34]\b' "$workflow" >/dev/null; then
    rel="${workflow#$ROOT_DIR/}"
    fail "$rel must not keep Node20-era actions/checkout references"
  fi
done
pass "all workflow files avoid actions/checkout@v3 and @v4"

required_checkout_workflows=(
  ".github/workflows/ci.yml"
  ".github/workflows/release.yml"
  ".github/workflows/release.yml.disabled"
  ".github/workflows/tls13-signer-gate.yml"
  ".github/workflows/wave-b-b2-manual.yml"
  ".github/workflows/wave-b-b2-manual.yml.disabled"
)

for rel in "${required_checkout_workflows[@]}"; do
  abs="$ROOT_DIR/$rel"
  [[ -f "$abs" ]] || fail "missing expected workflow: $rel"
  if rg -n "uses:\\s*actions/checkout@${expected_sha}\\b" "$abs" >/dev/null; then
    pass "$rel uses the pinned actions/checkout commit"
  else
    fail "$rel must use actions/checkout@${expected_sha}"
  fi
done

echo "[PASS] workflow checkout Node24 contract passed"
