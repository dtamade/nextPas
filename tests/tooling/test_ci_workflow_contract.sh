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
TEST_HARNESS_SPEC="$REPO_ROOT/docs/architecture/test-harness-specification.md"

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
require_pattern "$CI_WORKFLOW" '^[[:space:]]+run: make rebuild-compiler$' 'root rebuild-compiler gate'
require_pattern "$CI_WORKFLOW" '^[[:space:]]+run: make stage0-heap-debug-recipe$' 'root stage0 HEAP_DEBUG env recipe'
require_pattern "$CI_WORKFLOW" '^[[:space:]]+run: make verify$' 'root verify gate'
reject_pattern "$CI_WORKFLOW" '^[[:space:]]+run: ./build/verify_local[.]sh$' 'direct verify_local bypasses Makefile hygiene'
reject_pattern "$CI_WORKFLOW" '^[[:space:]]+run: ./scripts/rebuild-compiler[.]sh$' 'direct rebuild-compiler bypasses Makefile hygiene'
reject_pattern "$CI_WORKFLOW" '^[[:space:]]+run: ./scripts/stage0-heap-debug-env-recipe[.]sh$' 'direct HEAP_DEBUG recipe bypasses Makefile gate'
reject_pattern "$TEST_HARNESS_SPEC" 'Linux CI 当前直接复用 `./build/verify_local[.]sh`' 'test harness spec must not document direct verify_local CI wiring'
require_pattern "$TEST_HARNESS_SPEC" 'Linux CI 当前.*`make verify`' 'test harness spec documents Makefile-backed verify CI wiring'
require_pattern "$TEST_HARNESS_SPEC" 'make rebuild-compiler' 'test harness spec documents rebuild-compiler CI gate'
require_pattern "$TEST_HARNESS_SPEC" 'stage0-heap-debug-recipe|HEAP_DEBUG' 'test harness spec documents HEAP_DEBUG env recipe'
require_makefile_target 'rebuild-compiler' 'root rebuild-compiler Makefile target'
require_makefile_target 'stage0-heap-debug-recipe' 'root stage0 HEAP_DEBUG recipe Makefile target'
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
require_pattern "$CORE_CI_WORKFLOW" 'platform-macos-ci-matrix[.]sh' 'core CI macOS uses platform matrix gate'
require_pattern "$CORE_CI_WORKFLOW" 'http-host-ci-matrix[.]sh' 'core CI FreeBSD uses http-host matrix gate'

tooling_line=$(root_ci_line_number '^[[:space:]]+run: make test-tooling$')
rebuild_line=$(root_ci_line_number '^[[:space:]]+run: make rebuild-compiler$')
heap_debug_line=$(root_ci_line_number '^[[:space:]]+run: make stage0-heap-debug-recipe$')
verify_line=$(root_ci_line_number '^[[:space:]]+run: make verify$')

if [ "$tooling_line" -ge "$rebuild_line" ]; then
  printf 'CI workflow contract failed: make test-tooling must run before make rebuild-compiler\n' >&2
  exit 1
fi

if [ "$rebuild_line" -ge "$heap_debug_line" ]; then
  printf 'CI workflow contract failed: make rebuild-compiler must run before make stage0-heap-debug-recipe\n' >&2
  exit 1
fi

if [ "$heap_debug_line" -ge "$verify_line" ]; then
  printf 'CI workflow contract failed: make stage0-heap-debug-recipe must run before make verify\n' >&2
  exit 1
fi

printf 'ci-workflow-contract=pass\n'
