#!/usr/bin/env sh

set -eu

case "$0" in
  */*) SCRIPT_PATH="$0" ;;
  *) SCRIPT_PATH="./$0" ;;
esac

SCRIPT_DIR=$(CDPATH= cd -- "${SCRIPT_PATH%/*}" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)
CI_WORKFLOW="$REPO_ROOT/.github/workflows/ci.yml"
CORE_CI_WORKFLOW="$REPO_ROOT/.github/workflows/core-ci.yml"
ROOT_MAKEFILE="$REPO_ROOT/Makefile"

require_pattern() {
  file="$1"
  pattern="$2"
  description="$3"

  if ! grep -Eq "$pattern" "$file"; then
    printf 'missing CI workflow contract: %s\n' "$description" >&2
    exit 1
  fi
}

reject_pattern() {
  file="$1"
  pattern="$2"
  description="$3"

  if grep -Eq "$pattern" "$file"; then
    printf 'forbidden CI workflow contract: %s\n' "$description" >&2
    exit 1
  fi
}

line_number() {
  file="$1"
  pattern="$2"

  grep -nE "$pattern" "$file" | head -n 1 | cut -d: -f1
}

require_workflow_self_path() {
  file="$1"
  workflow_path="$2"
  description="$3"

  require_pattern "$file" "paths:.*['\"]$workflow_path['\"]|['\"]$workflow_path['\"]" "$description"
}

require_makefile_target() {
  target="$1"
  description="$2"

  if ! awk -v target="$target" '
    BEGIN { found = 0 }
    /^[^#[:space:]][^:]*:/ {
      split($0, parts, ":")
      n = split(parts[1], names, /[[:space:]]+/)
      for (i = 1; i <= n; i++) {
        if (names[i] == target) {
          found = 1
        }
      }
    }
    END { exit found ? 0 : 1 }
  ' "$ROOT_MAKEFILE"; then
    printf 'missing CI workflow contract: %s\n' "$description" >&2
    exit 1
  fi
}

root_ci_line_number() {
  pattern="$1"
  line_number "$CI_WORKFLOW" "$pattern"
}

require_pattern "$CI_WORKFLOW" '^[[:space:]]+run: make test-tooling$' 'root tooling gate'
require_pattern "$CI_WORKFLOW" '^[[:space:]]+run: make verify$' 'root verify gate'
reject_pattern "$CI_WORKFLOW" '^[[:space:]]+run: ./build/verify_local[.]sh$' 'direct verify_local bypasses Makefile hygiene'
reject_pattern "$CI_WORKFLOW" '^[[:space:]]+run: make lane-focused' 'lane-focused is local/reporting tooling, not CI matrix'
reject_pattern "$CORE_CI_WORKFLOW" '^[[:space:]]+run: make lane-focused' 'core CI must not consume local/reporting lane-focused helper'
reject_pattern "$CI_WORKFLOW" '^[[:space:]]+run: make landing-check .*LANE=' 'landing-check LANE is local/reporting tooling, not CI matrix'
reject_pattern "$CORE_CI_WORKFLOW" '^[[:space:]]+run: make landing-check .*LANE=' 'core CI must not consume landing-check lane helper'
reject_pattern "$CORE_CI_WORKFLOW" 'find tests -mindepth 2 -name Makefile' 'core CI test matrix must live behind Makefile gates'
reject_pattern "$CORE_CI_WORKFLOW" 'PASSED=0; SKIPPED=0|TOTAL=0; PASSED=0; SKIPPED=0' 'core CI must not inline best-effort test accounting'
require_workflow_self_path "$CORE_CI_WORKFLOW" '.github/workflows/core-ci.yml' 'core CI self-trigger path'
require_makefile_target 'core-ci-test' 'root core CI test target'
require_makefile_target 'core-ci-best-effort-test' 'root core CI best-effort target'
require_pattern "$CORE_CI_WORKFLOW" '^[[:space:]]+run: make -C \.\. core-ci-test$' 'core CI Linux uses root Makefile test gate'
require_pattern "$CORE_CI_WORKFLOW" 'make -C \.\. core-ci-best-effort-test CORE_CI_HOST=macOS' 'core CI macOS uses root Makefile best-effort gate'
require_pattern "$CORE_CI_WORKFLOW" 'make -C "[$]GITHUB_WORKSPACE" core-ci-best-effort-test CORE_CI_HOST=FreeBSD' 'core CI FreeBSD uses root Makefile best-effort gate'

tooling_line=$(root_ci_line_number '^[[:space:]]+run: make test-tooling$')
verify_line=$(root_ci_line_number '^[[:space:]]+run: make verify$')

if [ "$tooling_line" -ge "$verify_line" ]; then
  printf 'CI workflow contract failed: make test-tooling must run before make verify\n' >&2
  exit 1
fi

printf 'ci-workflow-contract=pass\n'
