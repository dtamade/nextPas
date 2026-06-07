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
FOCUS_DIR="$FIXTURE_REPO/core/tests/nextpas.core.fake/test_fake"
NO_CLEAN_DIR="$FIXTURE_REPO/core/tests/nextpas.core.fake/test_no_clean"
OUTSIDE_DIR="$FIXTURE_REPO/docs/not_a_core_test"
NO_MAKEFILE_DIR="$FIXTURE_REPO/core/tests/nextpas.core.fake/no_makefile"

mkdir -p "$FIXTURE_REPO/scripts" "$FOCUS_DIR" "$NO_CLEAN_DIR" "$OUTSIDE_DIR" "$NO_MAKEFILE_DIR"
cp "$REPO_ROOT/Makefile" "$FIXTURE_REPO/Makefile"
cp "$REPO_ROOT/scripts/build-hygiene-check.sh" "$FIXTURE_REPO/scripts/build-hygiene-check.sh"
chmod +x "$FIXTURE_REPO/scripts/build-hygiene-check.sh"

git -C "$FIXTURE_REPO" init -b main >/dev/null
git -C "$FIXTURE_REPO" config user.email "tooling@example.invalid"
git -C "$FIXTURE_REPO" config user.name "tooling test"

cat >"$FOCUS_DIR/Makefile" <<'EOF'
.PHONY: clean test

clean:
	printf 'clean\n' >> focused.log

test:
	printf 'test\n' >> focused.log
EOF

cat >"$NO_CLEAN_DIR/Makefile" <<'EOF'
.PHONY: test

test:
	printf 'test\n' >> no-clean.log
EOF

cat >"$OUTSIDE_DIR/Makefile" <<'EOF'
.PHONY: clean test

clean:
	printf 'clean\n' >> outside.log

test:
	printf 'test\n' >> outside.log
EOF

git -C "$FIXTURE_REPO" add Makefile scripts/build-hygiene-check.sh core/tests docs/not_a_core_test
git -C "$FIXTURE_REPO" commit -m "fixture focused gates" >/dev/null

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

expect_failure "missing FOCUS" make -C "$FIXTURE_REPO" focused
grep -q 'FOCUS is required' "$TMP_ROOT/failure.err"

expect_failure "FOCUS outside core/tests" make -C "$FIXTURE_REPO" focused FOCUS=docs/not_a_core_test
grep -q 'FOCUS must be under core/tests/' "$TMP_ROOT/failure.err"

expect_failure "FOCUS escaping core/tests" make -C "$FIXTURE_REPO" focused FOCUS=core/tests/../../docs/not_a_core_test
grep -q 'FOCUS must be under core/tests/' "$TMP_ROOT/failure.err"

expect_failure "FOCUS without Makefile" make -C "$FIXTURE_REPO" focused FOCUS=core/tests/nextpas.core.fake/no_makefile
grep -q 'FOCUS Makefile not found' "$TMP_ROOT/failure.err"

expect_failure "FOCUS without clean target" make -C "$FIXTURE_REPO" focused FOCUS=core/tests/nextpas.core.fake/test_no_clean
grep -q 'FOCUS Makefile must expose a clean target' "$TMP_ROOT/failure.err"

make -C "$FIXTURE_REPO" focused FOCUS=core/tests/nextpas.core.fake/test_fake >/dev/null

if ! cmp -s "$FOCUS_DIR/focused.log" - <<'EOF'
clean
test
EOF
then
  printf 'focused target did not run clean then test\n' >&2
  cat "$FOCUS_DIR/focused.log" >&2
  exit 1
fi

printf 'root-focused-gate=pass\n'
