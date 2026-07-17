#!/usr/bin/env sh
# Stage0 HEAP_DEBUG env recipe.
#
# Proves doctor mem-process-stats (FormatMemStats projection) respects
# NEXTPAS_MEM_HEAP_DEBUG / NEXTPAS_MEM_DEBUG without permanently changing the
# default-path process. Each case is a fresh stage0 process so the lazy
# IsMemHeapDebugEnabled cache cannot leak across cases.
#
# Usage:
#   ./scripts/stage0-heap-debug-env-recipe.sh
#   STAGE0_BINARY=/path/to/nextpas TARGET_ID=linux-x86_64 ./scripts/...
#
# Sourced entrypoints: make stage0-heap-debug-recipe, CI after rebuild-compiler,
# build/verify_local.sh (after default doctor).

set -eu

case "$0" in
  */*) SCRIPT_PATH="$0" ;;
  *) SCRIPT_PATH="./$0" ;;
esac

SCRIPT_DIR=$(CDPATH= cd -- "${SCRIPT_PATH%/*}" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)

STAGE0_BINARY="${STAGE0_BINARY:-$REPO_ROOT/build/stage0-bootstrap/nextpas}"
TARGET_ID="${TARGET_ID:-linux-x86_64}"
WORKDIR="${STAGE0_HEAP_DEBUG_WORKDIR:-$REPO_ROOT}"

fail() {
  printf 'stage0-heap-debug-env-recipe-failure: %s\n' "$1" >&2
  exit 1
}

require_executable() {
  if [ ! -x "$1" ]; then
    fail "missing executable stage0 binary at $1 (run make rebuild-compiler first)"
  fi
}

require_pattern() {
  file="$1"
  pattern="$2"
  description="$3"
  if ! grep -Eq "$pattern" "$file"; then
    printf 'stage0-heap-debug-env-recipe: output dump (%s):\n' "$description" >&2
    cat "$file" >&2 || true
    fail "$description"
  fi
}

run_doctor() {
  out="$1"
  shift
  # Fresh process + explicit env so ambient developer vars cannot poison cases.
  if ! env "$@" \
    NEXTPAS_REPO_ROOT="$REPO_ROOT" \
    "$STAGE0_BINARY" doctor --target "$TARGET_ID" --workspace "$WORKDIR" \
    >"$out" 2>&1; then
    cat "$out" >&2 || true
    fail "doctor failed under env: $*"
  fi
}

require_executable "$STAGE0_BINARY"

DEFAULT_OUT=$(mktemp)
HEAP_OUT=$(mktemp)
DEBUG_OUT=$(mktemp)
BOTH_OUT=$(mktemp)
cleanup() {
  rm -f "$DEFAULT_OUT" "$HEAP_OUT" "$DEBUG_OUT" "$BOTH_OUT"
}
trap cleanup EXIT INT TERM HUP

printf 'stage0-heap-debug-env-recipe: default path\n'
run_doctor "$DEFAULT_OUT" -u NEXTPAS_MEM_HEAP_DEBUG -u NEXTPAS_MEM_DEBUG
require_pattern "$DEFAULT_OUT" '^mem-process-stats=.*heap_debug=n' \
  'default doctor must report heap_debug=n'
require_pattern "$DEFAULT_OUT" '^mem-process-stats=.*debug=n' \
  'default doctor must report debug=n (NEXTPAS_MEM_DEBUG unset)'
require_pattern "$DEFAULT_OUT" '^command-envelope=.*"memProcessStats":".*heap_debug=n' \
  'default doctor envelope must report heap_debug=n'

printf 'stage0-heap-debug-env-recipe: NEXTPAS_MEM_HEAP_DEBUG=1\n'
run_doctor "$HEAP_OUT" -u NEXTPAS_MEM_DEBUG NEXTPAS_MEM_HEAP_DEBUG=1
require_pattern "$HEAP_OUT" '^mem-process-stats=.*heap_debug=y' \
  'HEAP_DEBUG=1 doctor must report heap_debug=y'
require_pattern "$HEAP_OUT" '^mem-process-stats=.*debug=n' \
  'HEAP_DEBUG alone must not invent plugin debug=y'
require_pattern "$HEAP_OUT" '^command-envelope=.*"memProcessStats":".*heap_debug=y' \
  'HEAP_DEBUG=1 doctor envelope must report heap_debug=y'

printf 'stage0-heap-debug-env-recipe: NEXTPAS_MEM_DEBUG=stats only\n'
run_doctor "$DEBUG_OUT" -u NEXTPAS_MEM_HEAP_DEBUG NEXTPAS_MEM_DEBUG=stats
require_pattern "$DEBUG_OUT" '^mem-process-stats=.*heap_debug=n' \
  'DEBUG=stats alone must keep heap_debug=n (plugin track)'
require_pattern "$DEBUG_OUT" '^mem-process-stats=.*debug=y' \
  'DEBUG=stats alone must report debug=y'
require_pattern "$DEBUG_OUT" '^mem-process-stats=.*debug_allocs=' \
  'DEBUG=stats must surface plugin debug_allocs'

printf 'stage0-heap-debug-env-recipe: HEAP_DEBUG + DEBUG=stats\n'
run_doctor "$BOTH_OUT" NEXTPAS_MEM_HEAP_DEBUG=1 NEXTPAS_MEM_DEBUG=stats
require_pattern "$BOTH_OUT" '^mem-process-stats=.*heap_debug=y' \
  'both envs must report heap_debug=y'
require_pattern "$BOTH_OUT" '^mem-process-stats=.*debug=y' \
  'both envs must report debug=y'
require_pattern "$BOTH_OUT" '^mem-process-stats=.*debug_allocs=' \
  'both envs must surface plugin debug_allocs'

printf 'stage0-heap-debug-env-recipe=pass\n'
