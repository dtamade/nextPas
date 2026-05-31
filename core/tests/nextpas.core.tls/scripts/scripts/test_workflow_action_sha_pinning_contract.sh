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

declare -A expected_shas=(
  ["actions/checkout"]="93cb6efe18208431cddfb8368fd83d5badbf9bfd"
  ["actions/upload-artifact"]="b7c566a772e6b6bfb58ed0dc250532a479d7789f"
  ["actions/download-artifact"]="37930b1c2abaa49bbe596cd826c3c89aef350131"
  ["softprops/action-gh-release"]="b4309332981a82ec1c5618f44dd2e27cc8bfbfda"
  ["actions/setup-python"]="a309ff8b426b58ec0e2a45f0f869d46889d02405"
  ["actions/cache"]="27d5ce7f107fe9357f9df03efb73ab90386fccae"
)

mapfile -t uses_lines < <(rg -n 'uses:\s*[^ ]+@' "$WORKFLOWS_DIR")
[[ "${#uses_lines[@]}" -gt 0 ]] || fail "no uses: lines found under .github/workflows"

for entry in "${uses_lines[@]}"; do
  line="${entry#*:}"
  line="${line#*:}"
  if [[ ! "$line" =~ uses:[[:space:]]*([^[:space:]#]+)@([0-9a-f]{40})([[:space:]]*#[[:space:]]*v[0-9].*)?$ ]]; then
    fail "workflow uses line is not pinned to a full commit SHA: $entry"
  fi
done
pass "all workflow uses lines are pinned to full commit SHAs"

if rg -n 'uses:\s*[^ ]+@v[0-9]+' "$WORKFLOWS_DIR" >/dev/null; then
  fail "workflow files must not keep floating major version tags"
fi
pass "workflow files avoid floating major version tags"

if rg -n 'uses:\s*[^ ]+@(main|master|latest|HEAD)\b' "$WORKFLOWS_DIR" >/dev/null; then
  fail "workflow files must not pin to floating branch-like refs"
fi
pass "workflow files avoid floating branch refs"

for action in "${!expected_shas[@]}"; do
  sha="${expected_shas[$action]}"
  if rg -n "uses:\\s*${action}@${sha}\\b" "$WORKFLOWS_DIR" >/dev/null; then
    pass "$action is pinned to the expected commit SHA"
  else
    fail "$action must be pinned to $sha"
  fi
done

echo "[PASS] workflow action SHA pinning contract passed"
