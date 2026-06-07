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
mkdir -p "$FIXTURE_REPO/scripts" \
  "$FIXTURE_REPO/compiler" \
  "$FIXTURE_REPO/benchmarks" \
  "$FIXTURE_REPO/docs" \
  "$FIXTURE_REPO/tests" \
  "$FIXTURE_REPO/examples" \
  "$FIXTURE_REPO/rtl" \
  "$FIXTURE_REPO/units" \
  "$FIXTURE_REPO/tools/stage0" \
  "$FIXTURE_REPO/core/tests/nextpas.core.fake/test_fake"

cp "$REPO_ROOT/scripts/build-hygiene-check.sh" "$FIXTURE_REPO/scripts/build-hygiene-check.sh"
cp "$REPO_ROOT/Makefile" "$FIXTURE_REPO/Makefile"
chmod +x "$FIXTURE_REPO/scripts/build-hygiene-check.sh"

git -C "$FIXTURE_REPO" init -b main >/dev/null
git -C "$FIXTURE_REPO" config user.email "tooling@example.invalid"
git -C "$FIXTURE_REPO" config user.name "tooling test"

printf 'program fixture; begin end.\n' >"$FIXTURE_REPO/tools/stage0/nextpas.pas"
printf 'program fixture; begin end.\n' >"$FIXTURE_REPO/core/tests/nextpas.core.fake/test_fake/test_fake.lpr"
printf 'tracked shared library\n' >"$FIXTURE_REPO/docs/tracked_generated.so"
git -C "$FIXTURE_REPO" add scripts/build-hygiene-check.sh tools/stage0/nextpas.pas core/tests/nextpas.core.fake/test_fake/test_fake.lpr docs/tracked_generated.so
git -C "$FIXTURE_REPO" commit -m "fixture sources" >/dev/null

create_extensionless_artifacts() {
  printf 'binary\n' >"$FIXTURE_REPO/tools/stage0/nextpas"
  printf 'binary\n' >"$FIXTURE_REPO/core/tests/nextpas.core.fake/test_fake/test_fake"
}

create_extensionless_artifacts

HYGIENE_OUTPUT=$("$FIXTURE_REPO/scripts/build-hygiene-check.sh" 2>&1) && {
  printf 'expected build-hygiene-check.sh to fail on extensionless artifacts\n' >&2
  printf '%s\n' "$HYGIENE_OUTPUT" >&2
  exit 1
}

require_hygiene_line() {
  pattern="$1"
  if ! printf '%s\n' "$HYGIENE_OUTPUT" | grep -E "$pattern" >/dev/null; then
    printf 'missing expected build hygiene line: %s\n' "$pattern" >&2
    printf '%s\n' "$HYGIENE_OUTPUT" >&2
    exit 1
  fi
}

require_hygiene_line '^source build artifacts:$'
require_hygiene_line '^tools/stage0/nextpas$'
require_hygiene_line '^core/tests/nextpas\.core\.fake/test_fake/test_fake$'
require_hygiene_line '^tracked generated artifacts:$'
require_hygiene_line '^docs/tracked_generated\.so$'
require_hygiene_line '^build-hygiene=failed$'

CLEAN_OUTPUT=$(make -C "$FIXTURE_REPO" clean-artifacts 2>&1) && {
  printf 'expected clean-artifacts to fail on tracked generated artifacts\n' >&2
  printf '%s\n' "$CLEAN_OUTPUT" >&2
  exit 1
}

require_clean_line() {
  pattern="$1"
  if ! printf '%s\n' "$CLEAN_OUTPUT" | grep -E "$pattern" >/dev/null; then
    printf 'missing expected clean artifact line: %s\n' "$pattern" >&2
    printf '%s\n' "$CLEAN_OUTPUT" >&2
    exit 1
  fi
}

require_clean_line '^tracked generated artifacts:$'
require_clean_line '^docs/tracked_generated\.so$'
require_clean_line '^build-artifact-clean=failed$'

if [ -e "$FIXTURE_REPO/tools/stage0/nextpas" ] || [ -e "$FIXTURE_REPO/core/tests/nextpas.core.fake/test_fake/test_fake" ]; then
  printf 'expected clean-artifacts to remove extensionless artifacts\n' >&2
  find "$FIXTURE_REPO" -type f | sed "s#^$FIXTURE_REPO/##" | sort >&2
  exit 1
fi

printf 'build-hygiene-extensionless-artifacts=pass\n'
