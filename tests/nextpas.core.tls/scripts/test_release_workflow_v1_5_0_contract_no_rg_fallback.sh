#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$repo_root"

tmpbin="$(mktemp -d)"
cleanup() {
  rm -rf "$tmpbin"
}
trap cleanup EXIT

for cmd in bash grep cmp printf python3 git dirname pwd mktemp ln rm; do
  path="$(command -v "$cmd" || true)"
  if [[ -n "$path" ]]; then
    ln -s "$path" "$tmpbin/$cmd"
  fi
done

if PATH="$tmpbin" bash tests/scripts/test_release_workflow_v1_5_0_contract.sh; then
  echo "[PASS] release workflow contract supports environments without rg"
else
  echo "[FAIL] release workflow contract supports environments without rg"
  exit 1
fi
