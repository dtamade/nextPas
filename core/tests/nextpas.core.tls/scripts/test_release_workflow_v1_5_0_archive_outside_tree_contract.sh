#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$repo_root"

pass() {
  printf '[PASS] %s\n' "$1"
}

fail() {
  printf '[FAIL] %s\n' "$1"
  if [[ $# -ge 2 ]]; then
    printf '       %s\n' "$2"
  fi
  exit 1
}

require_fixed() {
  local file="$1"
  local expected="$2"
  local name="$3"
  if grep -Fq -- "$expected" "$file"; then
    pass "$name"
  else
    fail "$name" "expected text not found in $file: $expected"
  fi
}

reject_fixed() {
  local file="$1"
  local expected="$2"
  local name="$3"
  if grep -Fq -- "$expected" "$file"; then
    fail "$name" "unexpected text still present in $file: $expected"
  else
    pass "$name"
  fi
}

printf '[TEST] v1.5.0 release archive path contract\n'

for workflow in .github/workflows/release.yml .github/workflows/release.yml.disabled; do
  require_fixed "$workflow" 'archive_tmp="${RUNNER_TEMP:-/tmp}/${ARCHIVE_NAME}.tar.gz"' \
    "$workflow stages the source archive outside the repo tree"
  require_fixed "$workflow" 'tar -czf "$archive_tmp"' \
    "$workflow writes the tarball to the staged temp path"
  require_fixed "$workflow" 'mv "$archive_tmp" "${ARCHIVE_NAME}.tar.gz"' \
    "$workflow moves the staged tarball back after creation"
  reject_fixed "$workflow" 'tar -czf "${ARCHIVE_NAME}.tar.gz"' \
    "$workflow no longer writes the tarball directly inside the archived tree"
done

printf '[PASS] v1.5.0 release archive path contract passed\n'
