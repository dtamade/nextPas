#!/usr/bin/env sh

set -eu

case "$0" in
  */*) SCRIPT_PATH="$0" ;;
  *) SCRIPT_PATH="./$0" ;;
esac

SCRIPT_DIR=$(CDPATH= cd -- "${SCRIPT_PATH%/*}" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)
WORKTREES_DOC="$REPO_ROOT/docs/worktrees.md"

require_doc_pattern() {
  pattern="$1"
  description="$2"

  if ! grep -Eq "$pattern" "$WORKTREES_DOC"; then
    printf 'missing focused gate matrix doc contract: %s\n' "$description" >&2
    exit 1
  fi
}

require_makefile_target() {
  makefile_path="$1"
  target="$2"

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
  ' "$makefile_path"; then
    printf 'focused gate matrix path lacks %s target: %s\n' "$target" "$makefile_path" >&2
    exit 1
  fi
}

require_focused_path_contract() {
  focus_path="$1"
  description="$2"
  gate_dir="$REPO_ROOT/$focus_path"
  makefile_path="$gate_dir/Makefile"

  require_doc_pattern "make focused FOCUS=$focus_path" "$description command"

  if [ ! -d "$gate_dir" ]; then
    printf 'focused gate matrix path missing directory: %s\n' "$focus_path" >&2
    exit 1
  fi

  if [ ! -f "$makefile_path" ]; then
    printf 'focused gate matrix path missing Makefile: %s\n' "$focus_path" >&2
    exit 1
  fi

  require_makefile_target "$makefile_path" clean
  require_makefile_target "$makefile_path" test
}

require_exact_matrix_lanes() {
  actual_lanes=$(
    awk '
      /^默认 focused gate matrix：/ { in_matrix = 1; next }
      in_matrix && /^如果某个模块/ { in_matrix = 0 }
      in_matrix && /^\| [^|]+ \|/ {
        lane = $2
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", lane)
        if (lane != "lane" && lane != "---") {
          print lane
        }
      }
    ' "$WORKTREES_DOC" | sort | tr '\n' ' '
  )
  expected_lanes="compiler config http mem platform system "

  if [ "$actual_lanes" != "$expected_lanes" ]; then
    printf 'focused gate matrix lanes differ from contract\n' >&2
    printf 'expected: %s\n' "$expected_lanes" >&2
    printf 'actual:   %s\n' "$actual_lanes" >&2
    exit 1
  fi
}

require_skip_exception_contract() {
  focus_path="$1"
  description="$2"
  makefile_path="$REPO_ROOT/$focus_path/Makefile"

  if [ ! -f "$makefile_path" ]; then
    printf 'skip exception path missing Makefile: %s\n' "$focus_path" >&2
    exit 1
  fi

  if ! grep -Eq 'SKIP:' "$makefile_path"; then
    printf 'skip exception path does not contain SKIP marker: %s\n' "$focus_path" >&2
    exit 1
  fi

  require_doc_pattern "$focus_path.*SKIP|SKIP.*$focus_path" "$description skip exception"
}

require_doc_pattern 'Focused Gate Matrix' 'focused gate matrix section'
require_exact_matrix_lanes
require_doc_pattern 'source-contract' 'source-contract truth category'
require_doc_pattern 'forced-compile' 'forced compile truth category'
require_doc_pattern 'runtime' 'runtime truth category'
require_doc_pattern 'CI truth' 'CI truth category'

require_focused_path_contract 'core/tests/nextpas.core.platform/test_platform_simulated_host_compile_matrix' 'platform lane simulated host compile gate'
require_focused_path_contract 'core/tests/nextpas.core.mem/test_memory_map_compile_gate' 'mem lane memory map compile gate'
require_focused_path_contract 'core/tests/nextpas.core.system/test_system_source_contracts' 'system lane source contract gate'
require_focused_path_contract 'core/tests/nextpas.core.config/test_config' 'config lane focused gate'
require_focused_path_contract 'core/tests/nextpas.core.http/test_http_client' 'http lane focused gate'
require_doc_pattern 'compiler.*not.*default focused gate|compiler.*不是.*默认 focused gate' 'compiler is not default focused gate'
require_doc_pattern 'compiler.*build/verify_local[.]sh|build/verify_local[.]sh.*compiler' 'compiler verify local exception'
require_skip_exception_contract 'core/tests/nextpas.core.hash/test_hash' 'hash placeholder'
require_skip_exception_contract 'core/tests/nextpas.core.hash/test_hash_audit' 'hash audit placeholder'
require_skip_exception_contract 'core/tests/nextpas.core.tls/unit' 'tls unit placeholder'
require_skip_exception_contract 'core/tests/nextpas.core.simd.cpuinfo' 'simd cpuinfo placeholder'
require_doc_pattern 'make -C core/tests/nextpas[.]core[.]simd cpuinfo-focused' 'simd cpuinfo real focused target'

printf 'focused-gate-matrix-doc-contract=pass\n'
