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

require_list_focus_matches_lane() {
  lane_name="$1"
  focus_path="$2"

  "$SCRIPT_UNDER_TEST" --lane "$lane_name" --print-command >"$TMP_ROOT/$lane_name.out"
  if ! grep -qx "focus=$focus_path" "$TMP_ROOT/$lane_name.out"; then
    printf 'lane-focused --list focus differs from --lane output for %s\n' "$lane_name" >&2
    cat "$TMP_ROOT/$lane_name.out" >&2
    exit 1
  fi
}

expect_failure "missing lane" "$SCRIPT_UNDER_TEST" --print-command
grep -q 'LANE is required' "$TMP_ROOT/failure.err"

expect_failure "list with lane" "$SCRIPT_UNDER_TEST" --list --lane system
grep -q -- '--list cannot be combined with --lane' "$TMP_ROOT/failure.err"

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

"$SCRIPT_UNDER_TEST" --list >"$TMP_ROOT/list.out"
if [ "$(wc -l <"$TMP_ROOT/list.out" | tr -d ' ')" != "5" ]; then
  printf 'lane-focused --list should print exactly five default lane rows\n' >&2
  cat "$TMP_ROOT/list.out" >&2
  exit 1
fi

awk -F '\t' '
  BEGIN {
    expected["platform"] = 1
    expected["mem"] = 1
    expected["system"] = 1
    expected["config"] = 1
    expected["http"] = 1
  }
  NF != 3 {
    printf "lane-focused --list row is not lane/truth/focus: %s\n", $0 > "/dev/stderr"
    exit 1
  }
  $1 == "compiler" {
    printf "lane-focused --list must not include compiler\n" > "/dev/stderr"
    exit 1
  }
  !($1 in expected) {
    printf "unexpected lane-focused --list lane: %s\n", $1 > "/dev/stderr"
    exit 1
  }
  {
    seen[$1] = 1
  }
  END {
    for (lane in expected) {
      if (!(lane in seen)) {
        printf "missing lane-focused --list lane: %s\n", lane > "/dev/stderr"
        exit 1
      }
    }
  }
' "$TMP_ROOT/list.out"

while IFS="$(printf '\t')" read -r lane_name truth_kind focus_path; do
  require_list_focus_matches_lane "$lane_name" "$focus_path"
done <"$TMP_ROOT/list.out"

printf 'lane-focused-gate=pass\n'
