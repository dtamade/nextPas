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

SCRIPT_UNDER_TEST="$REPO_ROOT/scripts/landing-candidate-check.sh"

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

create_repo() {
  repo_path="$1"
  mkdir -p "$repo_path/scripts" "$repo_path/docs" "$repo_path/compiler" "$repo_path/tests/tooling"
  cp "$REPO_ROOT/Makefile" "$repo_path/Makefile"
  cp "$REPO_ROOT/scripts/build-hygiene-check.sh" "$repo_path/scripts/build-hygiene-check.sh"
  cp "$REPO_ROOT/scripts/lane-focused.sh" "$repo_path/scripts/lane-focused.sh"
  cp "$SCRIPT_UNDER_TEST" "$repo_path/scripts/landing-candidate-check.sh"
  chmod +x "$repo_path/scripts/build-hygiene-check.sh" "$repo_path/scripts/lane-focused.sh" "$repo_path/scripts/landing-candidate-check.sh"
  git -C "$repo_path" init -b main >/dev/null
  git -C "$repo_path" config user.email "tooling@example.invalid"
  git -C "$repo_path" config user.name "tooling test"
  printf 'initial\n' >"$repo_path/README.md"
  cat >"$repo_path/tests/tooling/Makefile" <<'EOF'
.PHONY: test

test:
	test "$(BASE_REF)" = "main"
	printf 'test-tooling\n' >> tooling.log
EOF
  git -C "$repo_path" add Makefile README.md scripts tests/tooling/Makefile
  git -C "$repo_path" commit -m "initial" >/dev/null
}

create_landing_worktree() {
  repo_path="$1"
  branch_name="$2"
  git -C "$repo_path" branch "$branch_name"
  git -C "$repo_path" worktree add ".worktrees/$branch_name" "$branch_name" >/dev/null
}

run_landing_check() {
  candidate_path="$1"
  shift
  (
    cd "$candidate_path"
    "$SCRIPT_UNDER_TEST" "$@"
  )
}

PASS_REPO="$TMP_ROOT/pass"
create_repo "$PASS_REPO"
git -C "$PASS_REPO" update-ref refs/remotes/origin/main refs/heads/main
create_landing_worktree "$PASS_REPO" landing
mkdir -p "$PASS_REPO/.worktrees/landing/scripts"
printf 'helper\n' >"$PASS_REPO/.worktrees/landing/scripts/helper.sh"
git -C "$PASS_REPO/.worktrees/landing" add scripts/helper.sh
git -C "$PASS_REPO/.worktrees/landing" commit -m "landing helper" >/dev/null

PASS_OUTPUT=$(
  cd "$PASS_REPO/.worktrees/landing"
  "$SCRIPT_UNDER_TEST" --allow-path scripts
)

printf '%s\n' "$PASS_OUTPUT" | grep -q '^landing-candidate=pass$'
printf '%s\n' "$PASS_OUTPUT" | grep -q '^branch=landing$'
printf '%s\n' "$PASS_OUTPUT" | grep -q '^base=main$'
printf '%s\n' "$PASS_OUTPUT" | grep -q '^ahead=1$'
printf '%s\n' "$PASS_OUTPUT" | grep -q '^behind=0$'
printf '%s\n' "$PASS_OUTPUT" | grep -q '^scripts/helper\.sh$'

make -C "$PASS_REPO/.worktrees/landing" landing-check BASE_REF=origin/main ALLOW_PATHS=scripts >/dev/null
grep -q '^test-tooling$' "$PASS_REPO/.worktrees/landing/tests/tooling/tooling.log"

LONG_LIVED_LANE_REPO="$TMP_ROOT/long-lived-lane"
create_repo "$LONG_LIVED_LANE_REPO"
git -C "$LONG_LIVED_LANE_REPO" branch codex/core-http
git -C "$LONG_LIVED_LANE_REPO" worktree add ".worktrees/core-http" codex/core-http >/dev/null
mkdir -p "$LONG_LIVED_LANE_REPO/.worktrees/core-http/scripts"
printf 'helper\n' >"$LONG_LIVED_LANE_REPO/.worktrees/core-http/scripts/helper.sh"
git -C "$LONG_LIVED_LANE_REPO/.worktrees/core-http" add scripts/helper.sh
git -C "$LONG_LIVED_LANE_REPO/.worktrees/core-http" commit -m "long-lived lane helper" >/dev/null
expect_failure "long-lived codex lane is not a landing candidate" run_landing_check "$LONG_LIVED_LANE_REPO/.worktrees/core-http" --allow-path scripts
grep -q 'landing candidate branch must not be a long-lived codex lane: codex/core-http' "$TMP_ROOT/failure.err"

LANE_REPO="$TMP_ROOT/lane"
create_repo "$LANE_REPO"
mkdir -p "$LANE_REPO/core/tests/nextpas.core.system/test_system_source_contracts"
cat >"$LANE_REPO/core/tests/nextpas.core.system/test_system_source_contracts/Makefile" <<'EOF'
.PHONY: clean test

clean:
	printf 'clean\n' >> focused.log

test:
	printf 'test\n' >> focused.log
EOF
git -C "$LANE_REPO" add core/tests
git -C "$LANE_REPO" commit -m "system focused fixture" >/dev/null
create_landing_worktree "$LANE_REPO" landing
mkdir -p "$LANE_REPO/.worktrees/landing/docs"
printf 'docs\n' >"$LANE_REPO/.worktrees/landing/docs/worktrees.md"
git -C "$LANE_REPO/.worktrees/landing" add docs/worktrees.md
git -C "$LANE_REPO/.worktrees/landing" commit -m "docs change" >/dev/null
LANE_OUTPUT=$(make -C "$LANE_REPO/.worktrees/landing" landing-check ALLOW_PATHS=docs/worktrees.md LANE=system)
printf '%s\n' "$LANE_OUTPUT" | grep -q 'lane=system'
printf '%s\n' "$LANE_OUTPUT" | grep -q 'truth=source-contract'
if ! cmp -s "$LANE_REPO/.worktrees/landing/core/tests/nextpas.core.system/test_system_source_contracts/focused.log" - <<'EOF'
clean
test
EOF
then
  printf 'landing-check LANE=system did not run resolved focused gate\n' >&2
  cat "$LANE_REPO/.worktrees/landing/core/tests/nextpas.core.system/test_system_source_contracts/focused.log" >&2
  exit 1
fi

OVERRIDE_REPO="$TMP_ROOT/lane-focus-override"
create_repo "$OVERRIDE_REPO"
mkdir -p "$OVERRIDE_REPO/core/tests/nextpas.core.system/test_system_source_contracts" "$OVERRIDE_REPO/core/tests/nextpas.core.config/test_config"
cat >"$OVERRIDE_REPO/core/tests/nextpas.core.system/test_system_source_contracts/Makefile" <<'EOF'
.PHONY: clean test

clean:
	printf 'system-clean\n' >> focused.log

test:
	printf 'system-test\n' >> focused.log
EOF
cat >"$OVERRIDE_REPO/core/tests/nextpas.core.config/test_config/Makefile" <<'EOF'
.PHONY: clean test

clean:
	printf 'config-clean\n' >> focused.log

test:
	printf 'config-test\n' >> focused.log
EOF
git -C "$OVERRIDE_REPO" add core/tests
git -C "$OVERRIDE_REPO" commit -m "focused fixtures" >/dev/null
create_landing_worktree "$OVERRIDE_REPO" landing
mkdir -p "$OVERRIDE_REPO/.worktrees/landing/docs"
printf 'docs\n' >"$OVERRIDE_REPO/.worktrees/landing/docs/worktrees.md"
git -C "$OVERRIDE_REPO/.worktrees/landing" add docs/worktrees.md
git -C "$OVERRIDE_REPO/.worktrees/landing" commit -m "docs change" >/dev/null
make -C "$OVERRIDE_REPO/.worktrees/landing" landing-check ALLOW_PATHS=docs/worktrees.md LANE=system FOCUS=core/tests/nextpas.core.config/test_config >/dev/null
if [ -e "$OVERRIDE_REPO/.worktrees/landing/core/tests/nextpas.core.system/test_system_source_contracts/focused.log" ]; then
  printf 'landing-check should prefer explicit FOCUS over LANE-derived focus\n' >&2
  cat "$OVERRIDE_REPO/.worktrees/landing/core/tests/nextpas.core.system/test_system_source_contracts/focused.log" >&2
  exit 1
fi
if ! cmp -s "$OVERRIDE_REPO/.worktrees/landing/core/tests/nextpas.core.config/test_config/focused.log" - <<'EOF'
config-clean
config-test
EOF
then
  printf 'landing-check explicit FOCUS did not run expected focused gate\n' >&2
  cat "$OVERRIDE_REPO/.worktrees/landing/core/tests/nextpas.core.config/test_config/focused.log" >&2
  exit 1
fi

COMPILER_LANE_REPO="$TMP_ROOT/compiler-lane"
create_repo "$COMPILER_LANE_REPO"
create_landing_worktree "$COMPILER_LANE_REPO" landing
mkdir -p "$COMPILER_LANE_REPO/.worktrees/landing/docs"
printf 'docs\n' >"$COMPILER_LANE_REPO/.worktrees/landing/docs/worktrees.md"
git -C "$COMPILER_LANE_REPO/.worktrees/landing" add docs/worktrees.md
git -C "$COMPILER_LANE_REPO/.worktrees/landing" commit -m "docs change" >/dev/null
expect_failure "compiler lane has no default focused gate" make -C "$COMPILER_LANE_REPO/.worktrees/landing" landing-check ALLOW_PATHS=docs/worktrees.md LANE=compiler
grep -q 'compiler has no default lane-focused gate' "$TMP_ROOT/failure.err"

UNKNOWN_LANE_REPO="$TMP_ROOT/unknown-lane"
create_repo "$UNKNOWN_LANE_REPO"
create_landing_worktree "$UNKNOWN_LANE_REPO" landing
mkdir -p "$UNKNOWN_LANE_REPO/.worktrees/landing/docs"
printf 'docs\n' >"$UNKNOWN_LANE_REPO/.worktrees/landing/docs/worktrees.md"
git -C "$UNKNOWN_LANE_REPO/.worktrees/landing" add docs/worktrees.md
git -C "$UNKNOWN_LANE_REPO/.worktrees/landing" commit -m "docs change" >/dev/null
expect_failure "unknown lane" make -C "$UNKNOWN_LANE_REPO/.worktrees/landing" landing-check ALLOW_PATHS=docs/worktrees.md LANE=unknown
grep -q 'unknown lane: unknown' "$TMP_ROOT/failure.err"

WHITESPACE_REPO="$TMP_ROOT/whitespace"
create_repo "$WHITESPACE_REPO"
create_landing_worktree "$WHITESPACE_REPO" landing
mkdir -p "$WHITESPACE_REPO/.worktrees/landing/scripts"
printf 'trailing whitespace \n' >"$WHITESPACE_REPO/.worktrees/landing/scripts/whitespace.sh"
git -C "$WHITESPACE_REPO/.worktrees/landing" add scripts/whitespace.sh
git -C "$WHITESPACE_REPO/.worktrees/landing" commit -m "whitespace helper" >/dev/null
expect_failure "committed whitespace" make -C "$WHITESPACE_REPO/.worktrees/landing" landing-check ALLOW_PATHS=scripts
cat "$TMP_ROOT/failure.out" "$TMP_ROOT/failure.err" | grep -q 'trailing whitespace'

FILE_REPO="$TMP_ROOT/file-allow"
create_repo "$FILE_REPO"
create_landing_worktree "$FILE_REPO" landing
mkdir -p "$FILE_REPO/.worktrees/landing/docs"
printf 'worktrees docs\n' >"$FILE_REPO/.worktrees/landing/docs/worktrees.md"
git -C "$FILE_REPO/.worktrees/landing" add docs/worktrees.md
git -C "$FILE_REPO/.worktrees/landing" commit -m "worktree docs" >/dev/null
run_landing_check "$FILE_REPO/.worktrees/landing" --allow-path docs/worktrees.md >/dev/null

PREFIX_REPO="$TMP_ROOT/prefix-collision"
create_repo "$PREFIX_REPO"
create_landing_worktree "$PREFIX_REPO" landing
mkdir -p "$PREFIX_REPO/.worktrees/landing/docs/worktrees.md.extra"
printf 'collision\n' >"$PREFIX_REPO/.worktrees/landing/docs/worktrees.md.extra/file.txt"
git -C "$PREFIX_REPO/.worktrees/landing" add docs/worktrees.md.extra/file.txt
git -C "$PREFIX_REPO/.worktrees/landing" commit -m "prefix collision" >/dev/null
expect_failure "path prefix collision" run_landing_check "$PREFIX_REPO/.worktrees/landing" --allow-path docs/worktrees.md
grep -q 'changed path is outside allowed prefixes: docs/worktrees.md.extra/file.txt' "$TMP_ROOT/failure.err"

DIRTY_REPO="$TMP_ROOT/dirty"
create_repo "$DIRTY_REPO"
create_landing_worktree "$DIRTY_REPO" landing
printf 'dirty\n' >"$DIRTY_REPO/.worktrees/landing/untracked.tmp"
expect_failure "dirty worktree" run_landing_check "$DIRTY_REPO/.worktrees/landing" --allow-path scripts
grep -q 'landing candidate worktree must be clean' "$TMP_ROOT/failure.err"

BEHIND_REPO="$TMP_ROOT/behind"
create_repo "$BEHIND_REPO"
create_landing_worktree "$BEHIND_REPO" landing
printf 'main advance\n' >"$BEHIND_REPO/main.txt"
git -C "$BEHIND_REPO" add main.txt
git -C "$BEHIND_REPO" commit -m "main advance" >/dev/null
expect_failure "behind main" run_landing_check "$BEHIND_REPO/.worktrees/landing" --allow-path scripts
grep -q 'landing candidate is behind main by 1 commit' "$TMP_ROOT/failure.err"

DISALLOWED_REPO="$TMP_ROOT/disallowed"
create_repo "$DISALLOWED_REPO"
create_landing_worktree "$DISALLOWED_REPO" landing
mkdir -p "$DISALLOWED_REPO/.worktrees/landing/compiler"
printf 'compiler change\n' >"$DISALLOWED_REPO/.worktrees/landing/compiler/change.pas"
git -C "$DISALLOWED_REPO/.worktrees/landing" add compiler/change.pas
git -C "$DISALLOWED_REPO/.worktrees/landing" commit -m "compiler change" >/dev/null
expect_failure "disallowed path" run_landing_check "$DISALLOWED_REPO/.worktrees/landing" --allow-path scripts
grep -q 'changed path is outside allowed prefixes: compiler/change.pas' "$TMP_ROOT/failure.err"

HISTORY_REPO="$TMP_ROOT/history-disallowed"
create_repo "$HISTORY_REPO"
create_landing_worktree "$HISTORY_REPO" landing
mkdir -p "$HISTORY_REPO/.worktrees/landing/compiler" "$HISTORY_REPO/.worktrees/landing/scripts"
printf 'hidden\n' >"$HISTORY_REPO/.worktrees/landing/compiler/hidden.pas"
git -C "$HISTORY_REPO/.worktrees/landing" add compiler/hidden.pas
git -C "$HISTORY_REPO/.worktrees/landing" commit -m "hidden compiler change" >/dev/null
git -C "$HISTORY_REPO/.worktrees/landing" rm compiler/hidden.pas >/dev/null
git -C "$HISTORY_REPO/.worktrees/landing" commit -m "remove hidden compiler change" >/dev/null
printf 'helper\n' >"$HISTORY_REPO/.worktrees/landing/scripts/helper.sh"
git -C "$HISTORY_REPO/.worktrees/landing" add scripts/helper.sh
git -C "$HISTORY_REPO/.worktrees/landing" commit -m "allowed helper" >/dev/null
expect_failure "historical disallowed path" run_landing_check "$HISTORY_REPO/.worktrees/landing" --allow-path scripts
grep -q 'historical changed path is outside allowed prefixes: compiler/hidden.pas' "$TMP_ROOT/failure.err"

RENAME_REPO="$TMP_ROOT/rename"
create_repo "$RENAME_REPO"
printf 'compiler source\n' >"$RENAME_REPO/compiler/source.pas"
git -C "$RENAME_REPO" add compiler/source.pas
git -C "$RENAME_REPO" commit -m "compiler source" >/dev/null
create_landing_worktree "$RENAME_REPO" landing
mkdir -p "$RENAME_REPO/.worktrees/landing/scripts"
git -C "$RENAME_REPO/.worktrees/landing" mv compiler/source.pas scripts/source.pas
git -C "$RENAME_REPO/.worktrees/landing" commit -m "move source into scripts" >/dev/null
expect_failure "rename source outside allowlist" run_landing_check "$RENAME_REPO/.worktrees/landing" --allow-path scripts
grep -q 'changed path is outside allowed prefixes: compiler/source.pas' "$TMP_ROOT/failure.err"

OUTSIDE_REPO="$TMP_ROOT/outside-repo"
OUTSIDE_PATH="$TMP_ROOT/outside-worktree"
create_repo "$OUTSIDE_REPO"
git -C "$OUTSIDE_REPO" branch landing
git -C "$OUTSIDE_REPO" worktree add "$OUTSIDE_PATH" landing >/dev/null
expect_failure "outside .worktrees" run_landing_check "$OUTSIDE_PATH" --allow-path scripts
grep -q 'landing candidate worktree must be repo root or under .worktrees/' "$TMP_ROOT/failure.err"

DETACHED_REPO="$TMP_ROOT/detached"
create_repo "$DETACHED_REPO"
git -C "$DETACHED_REPO" worktree add --detach .worktrees/detached HEAD >/dev/null
expect_failure "detached worktree" run_landing_check "$DETACHED_REPO/.worktrees/detached" --allow-path scripts
grep -q 'landing candidate must be on a named branch' "$TMP_ROOT/failure.err"

printf 'landing-candidate-check=pass\n'
