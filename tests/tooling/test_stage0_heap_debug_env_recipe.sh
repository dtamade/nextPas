#!/usr/bin/env sh
# Source-contract + optional runtime: stage0 HEAP_DEBUG env recipe wiring.

set -eu

case "$0" in
  */*) SCRIPT_PATH="$0" ;;
  *) SCRIPT_PATH="./$0" ;;
esac

SCRIPT_DIR=$(CDPATH= cd -- "${SCRIPT_PATH%/*}" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)
RECIPE="$REPO_ROOT/scripts/stage0-heap-debug-env-recipe.sh"
CI_WORKFLOW="$REPO_ROOT/.github/workflows/ci.yml"
VERIFY_LOCAL="$REPO_ROOT/build/verify_local.sh"
MAKEFILE="$REPO_ROOT/Makefile"
CI_EVIDENCE="$REPO_ROOT/docs/architecture/ci-evidence-matrix.md"
TEST_HARNESS_SPEC="$REPO_ROOT/docs/architecture/test-harness-specification.md"
STAGE0_BINARY="$REPO_ROOT/build/stage0-bootstrap/nextpas"

require_file() {
  if [ ! -f "$1" ]; then
    printf 'missing stage0 HEAP_DEBUG recipe contract: %s\n' "$2" >&2
    exit 1
  fi
}

require_pattern() {
  file="$1"
  pattern="$2"
  description="$3"
  if ! grep -Eq "$pattern" "$file"; then
    printf 'missing stage0 HEAP_DEBUG recipe contract: %s\n' "$description" >&2
    exit 1
  fi
}

require_file "$RECIPE" 'scripts/stage0-heap-debug-env-recipe.sh'
require_pattern "$RECIPE" 'NEXTPAS_MEM_HEAP_DEBUG' 'recipe documents HEAP_DEBUG env'
require_pattern "$RECIPE" 'heap_debug=y' 'recipe asserts heap_debug=y under opt-in'
require_pattern "$RECIPE" 'heap_debug=n' 'recipe asserts heap_debug=n on default path'
require_pattern "$RECIPE" 'NEXTPAS_MEM_DEBUG' 'recipe covers plugin DEBUG track'
require_pattern "$RECIPE" 'stage0-heap-debug-env-recipe=pass' 'recipe prints pass token'

require_pattern "$MAKEFILE" '^stage0-heap-debug-recipe:' 'Makefile exposes stage0-heap-debug-recipe'
require_pattern "$MAKEFILE" 'stage0-heap-debug-env-recipe\.sh' 'Makefile invokes shared recipe script'

require_pattern "$CI_WORKFLOW" 'make stage0-heap-debug-recipe' 'CI runs stage0-heap-debug-recipe via Makefile'
reject_direct_script() {
  if grep -Eq '^[[:space:]]+run: \./scripts/stage0-heap-debug-env-recipe[.]sh$' "$CI_WORKFLOW"; then
    printf 'forbidden stage0 HEAP_DEBUG recipe contract: CI must use Makefile target\n' >&2
    exit 1
  fi
}
reject_direct_script

require_pattern "$VERIFY_LOCAL" 'stage0-heap-debug-env-recipe\.sh' 'verify_local invokes HEAP_DEBUG recipe'
require_pattern "$VERIFY_LOCAL" 'heap_debug=n' 'verify_local default doctor pins heap_debug=n'
require_pattern "$VERIFY_LOCAL" 'env -u NEXTPAS_MEM_HEAP_DEBUG -u NEXTPAS_MEM_DEBUG' \
  'verify_local isolates ambient mem debug env for default doctor'

require_pattern "$CI_EVIDENCE" 'stage0-heap-debug-recipe|HEAP_DEBUG' \
  'ci-evidence-matrix documents HEAP_DEBUG recipe'
require_pattern "$TEST_HARNESS_SPEC" 'stage0-heap-debug-recipe|HEAP_DEBUG' \
  'test-harness-specification documents HEAP_DEBUG recipe'

# Order: rebuild-compiler → stage0-heap-debug-recipe → verify
line_number() {
  file="$1"
  pattern="$2"
  awk -v pat="$pattern" '
    $0 ~ pat { print NR; exit }
  ' "$file"
}

rebuild_line=$(line_number "$CI_WORKFLOW" '^[[:space:]]+run: make rebuild-compiler$')
recipe_line=$(line_number "$CI_WORKFLOW" '^[[:space:]]+run: make stage0-heap-debug-recipe$')
verify_line=$(line_number "$CI_WORKFLOW" '^[[:space:]]+run: make verify$')

if [ -z "$rebuild_line" ] || [ -z "$recipe_line" ] || [ -z "$verify_line" ]; then
  printf 'stage0 HEAP_DEBUG recipe contract failed: missing CI step lines\n' >&2
  exit 1
fi

if [ "$rebuild_line" -ge "$recipe_line" ]; then
  printf 'stage0 HEAP_DEBUG recipe contract failed: rebuild must precede recipe\n' >&2
  exit 1
fi

if [ "$recipe_line" -ge "$verify_line" ]; then
  printf 'stage0 HEAP_DEBUG recipe contract failed: recipe must precede verify\n' >&2
  exit 1
fi

# Runtime when canonical stage0 already exists (CI after rebuild; local after rebuild).
if [ -x "$STAGE0_BINARY" ]; then
  "$RECIPE"
else
  printf 'stage0-heap-debug-env-recipe-runtime=skip (no stage0 binary yet)\n'
fi

printf 'stage0-heap-debug-env-recipe-contract=pass\n'
