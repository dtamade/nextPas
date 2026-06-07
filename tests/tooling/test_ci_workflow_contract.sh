#!/usr/bin/env sh

set -eu

case "$0" in
  */*) SCRIPT_PATH="$0" ;;
  *) SCRIPT_PATH="./$0" ;;
esac

SCRIPT_DIR=$(CDPATH= cd -- "${SCRIPT_PATH%/*}" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)
CI_WORKFLOW="$REPO_ROOT/.github/workflows/ci.yml"

require_pattern() {
  pattern="$1"
  description="$2"

  if ! grep -Eq "$pattern" "$CI_WORKFLOW"; then
    printf 'missing CI workflow contract: %s\n' "$description" >&2
    exit 1
  fi
}

reject_pattern() {
  pattern="$1"
  description="$2"

  if grep -Eq "$pattern" "$CI_WORKFLOW"; then
    printf 'forbidden CI workflow contract: %s\n' "$description" >&2
    exit 1
  fi
}

first_line_number() {
  pattern="$1"
  grep -nE "$pattern" "$CI_WORKFLOW" | head -n 1 | cut -d: -f1
}

require_pattern '^[[:space:]]+run: make test-tooling$' 'root tooling gate'
require_pattern '^[[:space:]]+run: make verify$' 'root verify gate'
reject_pattern '^[[:space:]]+run: ./build/verify_local[.]sh$' 'direct verify_local bypasses Makefile hygiene'

tooling_line=$(first_line_number '^[[:space:]]+run: make test-tooling$')
verify_line=$(first_line_number '^[[:space:]]+run: make verify$')

if [ "$tooling_line" -ge "$verify_line" ]; then
  printf 'CI workflow contract failed: make test-tooling must run before make verify\n' >&2
  exit 1
fi

printf 'ci-workflow-contract=pass\n'
