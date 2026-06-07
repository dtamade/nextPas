#!/usr/bin/env sh

set -eu

case "$0" in
  */*) SCRIPT_PATH="$0" ;;
  *) SCRIPT_PATH="./$0" ;;
esac

SCRIPT_DIR=$(CDPATH= cd -- "${SCRIPT_PATH%/*}" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)
TMP_ROOT=$(mktemp -d)

cleanup() {
  rm -rf "$TMP_ROOT"
}

trap cleanup EXIT INT TERM HUP

MISSING_CLEAN="$TMP_ROOT/missing-clean.txt"

find "$REPO_ROOT/core/tests" -name Makefile -print | sort | while IFS= read -r MAKEFILE_PATH; do
  TARGETS=$(awk '
    /^[^#[:space:]][^:]*:/ {
      split($0, parts, ":")
      count = split(parts[1], names, /[[:space:]]+/)
      for (i = 1; i <= count; i++) {
        if (names[i] == "clean") {
          clean = 1
        }
        if (names[i] == "test") {
          test = 1
        }
      }
    }
    END {
      printf "%s %s\n", clean ? "clean" : "no-clean", test ? "test" : "no-test"
    }
  ' "$MAKEFILE_PATH")

  set -- $TARGETS
  if [ "$1" = "no-clean" ] && [ "$2" = "test" ]; then
    printf '%s\n' "${MAKEFILE_PATH#$REPO_ROOT/}" >> "$MISSING_CLEAN"
  fi
done

if [ -s "$MISSING_CLEAN" ]; then
  printf 'core test Makefiles with test target must expose clean target:\n' >&2
  cat "$MISSING_CLEAN" >&2
  exit 1
fi

printf 'core-focused-makefiles=pass\n'
