#!/usr/bin/env sh

set -eu

case "$0" in
  */*) SCRIPT_PATH="$0" ;;
  *) SCRIPT_PATH="./$0" ;;
esac

SCRIPT_DIR=$(CDPATH= cd -- "${SCRIPT_PATH%/*}" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)
SCRIPT_UNDER_TEST="$REPO_ROOT/scripts/lane-focused.sh"
TMP_ROOT=$(mktemp -d)

cleanup() {
  rm -rf "$TMP_ROOT"
}

trap cleanup EXIT INT TERM HUP

expect_failure() {
  description="$1"
  shift
  if "$@" >"$TMP_ROOT/failure.out" 2>"$TMP_ROOT/failure.err"; then
    printf 'expected failure: %s\n' "$description" >&2
    cat "$TMP_ROOT/failure.out" >&2
    cat "$TMP_ROOT/failure.err" >&2
    exit 1
  fi
}

require_output_line() {
  file_path="$1"
  pattern="$2"
  description="$3"

  if ! grep -Eq "$pattern" "$file_path"; then
    printf 'missing lane-focused output: %s\n' "$description" >&2
    cat "$file_path" >&2
    exit 1
  fi
}

expect_failure "missing lane" "$SCRIPT_UNDER_TEST" --print-command
grep -q 'LANE is required' "$TMP_ROOT/failure.err"

expect_failure "unknown lane" "$SCRIPT_UNDER_TEST" --lane unknown --print-command
grep -q 'unknown lane: unknown' "$TMP_ROOT/failure.err"

expect_failure "compiler exception" "$SCRIPT_UNDER_TEST" --lane compiler --print-command
grep -q 'compiler has no default lane-focused gate' "$TMP_ROOT/failure.err"
grep -q 'build/verify_local.sh' "$TMP_ROOT/failure.err"

"$SCRIPT_UNDER_TEST" --lane platform --print-command >"$TMP_ROOT/platform.out"
require_output_line "$TMP_ROOT/platform.out" '^lane=platform$' 'platform lane'
require_output_line "$TMP_ROOT/platform.out" '^truth=forced-compile$' 'platform truth'
require_output_line "$TMP_ROOT/platform.out" '^focus=core/tests/nextpas[.]core[.]platform/test_platform_simulated_host_compile_matrix$' 'platform focus'
require_output_line "$TMP_ROOT/platform.out" '^command=make focused FOCUS=core/tests/nextpas[.]core[.]platform/test_platform_simulated_host_compile_matrix$' 'platform command'

"$SCRIPT_UNDER_TEST" --lane mem --print-command >"$TMP_ROOT/mem.out"
require_output_line "$TMP_ROOT/mem.out" '^truth=forced-compile$' 'mem truth'
require_output_line "$TMP_ROOT/mem.out" '^focus=core/tests/nextpas[.]core[.]mem/test_memory_map_compile_gate$' 'mem focus'

"$SCRIPT_UNDER_TEST" --lane system --print-command >"$TMP_ROOT/system.out"
require_output_line "$TMP_ROOT/system.out" '^truth=source-contract$' 'system truth'
require_output_line "$TMP_ROOT/system.out" '^focus=core/tests/nextpas[.]core[.]system/test_system_source_contracts$' 'system focus'

"$SCRIPT_UNDER_TEST" --lane config --print-command >"$TMP_ROOT/config.out"
require_output_line "$TMP_ROOT/config.out" '^truth=runtime$' 'config truth'
require_output_line "$TMP_ROOT/config.out" '^focus=core/tests/nextpas[.]core[.]config/test_config$' 'config focus'

"$SCRIPT_UNDER_TEST" --lane http --print-command >"$TMP_ROOT/http.out"
require_output_line "$TMP_ROOT/http.out" '^truth=runtime$' 'http truth'
require_output_line "$TMP_ROOT/http.out" '^focus=core/tests/nextpas[.]core[.]http/test_http_client$' 'http focus'

if "$SCRIPT_UNDER_TEST" --lane hash --print-command >"$TMP_ROOT/hash.out" 2>"$TMP_ROOT/hash.err"; then
  printf 'hash lane should not have a default lane-focused gate while hash gates are SKIP placeholders\n' >&2
  cat "$TMP_ROOT/hash.out" >&2
  exit 1
fi
grep -q 'unknown lane: hash' "$TMP_ROOT/hash.err"

printf 'lane-focused-gate=pass\n'
