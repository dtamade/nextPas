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

mapfile -t workflow_files < <(find "$WORKFLOWS_DIR" -maxdepth 1 -type f \( -name '*.yml' -o -name '*.yml.disabled' \) | sort)
[[ "${#workflow_files[@]}" -gt 0 ]] || fail "no workflow files found under .github/workflows"

for workflow in "${workflow_files[@]}"; do
  if rg -n 'uses:\s*gcarreno/setup-lazarus@' "$workflow" >/dev/null; then
    rel="${workflow#$ROOT_DIR/}"
    fail "$rel must not keep gcarreno/setup-lazarus now that the repo has an inlined Windows install pattern"
  fi
done
pass "all workflow files avoid gcarreno/setup-lazarus"

target="$ROOT_DIR/.github/workflows/test-all-platforms.yml.disabled"
[[ -f "$target" ]] || fail "missing expected workflow: .github/workflows/test-all-platforms.yml.disabled"

if rg -n 'choco install -y freepascal lazarus' "$target" >/dev/null; then
  pass ".github/workflows/test-all-platforms.yml.disabled installs FreePascal and Lazarus directly"
else
  fail ".github/workflows/test-all-platforms.yml.disabled must install FreePascal and Lazarus directly"
fi

if rg -n 'lazbuild --version' "$target" >/dev/null; then
  pass ".github/workflows/test-all-platforms.yml.disabled verifies lazbuild availability"
else
  fail ".github/workflows/test-all-platforms.yml.disabled must verify lazbuild availability"
fi

if rg -n 'Get-Command fpc' "$target" >/dev/null; then
  pass ".github/workflows/test-all-platforms.yml.disabled verifies fpc availability after install"
else
  fail ".github/workflows/test-all-platforms.yml.disabled must verify fpc availability after install"
fi

echo "[PASS] workflow lazarus setup Node24 contract passed"
