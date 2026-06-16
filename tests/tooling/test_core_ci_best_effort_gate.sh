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

FIXTURE_REPO="$TMP_ROOT/repo"
mkdir -p "$FIXTURE_REPO/core/tests/nextpas.core.fake/test_skip"
cp "$REPO_ROOT/Makefile" "$FIXTURE_REPO/Makefile"

cat >"$FIXTURE_REPO/core/tests/nextpas.core.fake/test_skip/Makefile" <<'EOF'
.PHONY: clean test

clean:
	@:

test:
	@echo "  SKIP: fake placeholder"
EOF

CORE_CI_OUTPUT=$(make -C "$FIXTURE_REPO" core-ci-best-effort-test CORE_CI_HOST=fixture 2>&1) && {
  printf 'expected core-ci-best-effort-test to fail when every gate is skipped\n' >&2
  printf '%s\n' "$CORE_CI_OUTPUT" >&2
  exit 1
}

printf '%s\n' "$CORE_CI_OUTPUT" | grep -q '^SKIP: tests/nextpas\.core\.fake/test_skip'
printf '%s\n' "$CORE_CI_OUTPUT" | grep -q 'fixture: 0 passed, 1 skipped, 1 total'

printf 'core-ci-best-effort-gate=pass\n'
