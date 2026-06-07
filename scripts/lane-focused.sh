#!/usr/bin/env sh

set -eu

case "$0" in
  */*) SCRIPT_PATH="$0" ;;
  *) SCRIPT_PATH="./$0" ;;
esac

SCRIPT_DIR=$(CDPATH= cd -- "${SCRIPT_PATH%/*}" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
LANE_NAME="${LANE:-}"
PRINT_COMMAND=0
LIST_LANES=0

usage() {
  cat >&2 <<'EOF'
Usage:
  scripts/lane-focused.sh --lane <platform|mem|system|config|http> [--print-command]
  scripts/lane-focused.sh --list

Compiler has no default lane-focused gate. Name the narrow compiler fixture or smoke command,
then use bash build/verify_local.sh only as a verify exception.
EOF
}

require_makefile_target() {
  makefile_path="$1"
  target="$2"

  awk -v target="$target" '
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
  ' "$makefile_path"
}

set_lane_defaults() {
  lane_name="$1"

  case "$lane_name" in
    platform)
      TRUTH_KIND="forced-compile"
      FOCUS_PATH="core/tests/nextpas.core.platform/test_platform_simulated_host_compile_matrix"
      ;;
    mem)
      TRUTH_KIND="forced-compile"
      FOCUS_PATH="core/tests/nextpas.core.mem/test_memory_map_compile_gate"
      ;;
    system)
      TRUTH_KIND="source-contract"
      FOCUS_PATH="core/tests/nextpas.core.system/test_system_source_contracts"
      ;;
    config)
      TRUTH_KIND="runtime"
      FOCUS_PATH="core/tests/nextpas.core.config/test_config"
      ;;
    http)
      TRUTH_KIND="runtime"
      FOCUS_PATH="core/tests/nextpas.core.http/test_http_client"
      ;;
    compiler)
      printf 'compiler has no default lane-focused gate\n' >&2
      printf 'name the narrow compiler fixture or smoke command, then use bash build/verify_local.sh only as a verify exception\n' >&2
      exit 1
      ;;
    *)
      printf 'unknown lane: %s\n' "$lane_name" >&2
      usage
      exit 1
      ;;
  esac
}

print_lane_list() {
  for lane_name in platform mem system config http; do
    set_lane_defaults "$lane_name"
    printf '%s\t%s\t%s\n' "$lane_name" "$TRUTH_KIND" "$FOCUS_PATH"
  done
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --lane)
      shift
      if [ "$#" -eq 0 ]; then
        printf 'LANE is required\n' >&2
        usage
        exit 1
      fi
      LANE_NAME="$1"
      ;;
    --print-command)
      PRINT_COMMAND=1
      ;;
    --list)
      LIST_LANES=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'unknown argument: %s\n' "$1" >&2
      usage
      exit 1
      ;;
  esac
  shift
done

if [ "$LIST_LANES" -eq 1 ]; then
  if [ -n "$LANE_NAME" ]; then
    printf '%s\n' '--list cannot be combined with --lane' >&2
    usage
    exit 1
  fi
  print_lane_list
  exit 0
fi

if [ -z "$LANE_NAME" ]; then
  printf 'LANE is required\n' >&2
  usage
  exit 1
fi

set_lane_defaults "$LANE_NAME"

FOCUS_DIR="$REPO_ROOT/$FOCUS_PATH"
FOCUS_MAKEFILE="$FOCUS_DIR/Makefile"

if [ ! -d "$FOCUS_DIR" ]; then
  printf 'lane-focused focus directory not found: %s\n' "$FOCUS_PATH" >&2
  exit 1
fi

if [ ! -f "$FOCUS_MAKEFILE" ]; then
  printf 'lane-focused focus Makefile not found: %s\n' "$FOCUS_PATH/Makefile" >&2
  exit 1
fi

if ! require_makefile_target "$FOCUS_MAKEFILE" clean; then
  printf 'lane-focused focus Makefile must expose clean target: %s\n' "$FOCUS_PATH" >&2
  exit 1
fi

if ! require_makefile_target "$FOCUS_MAKEFILE" test; then
  printf 'lane-focused focus Makefile must expose test target: %s\n' "$FOCUS_PATH" >&2
  exit 1
fi

printf 'lane=%s\n' "$LANE_NAME"
printf 'truth=%s\n' "$TRUTH_KIND"
printf 'focus=%s\n' "$FOCUS_PATH"
printf 'command=make focused FOCUS=%s\n' "$FOCUS_PATH"

if [ "$PRINT_COMMAND" -eq 0 ]; then
  make -C "$REPO_ROOT" focused FOCUS="$FOCUS_PATH"
fi
