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

SCRIPT_UNDER_TEST="$REPO_ROOT/scripts/landing-worktree-report.sh"

create_repo() {
  repo_path="$1"
  mkdir -p "$repo_path/scripts" "$repo_path/tests/tooling"
  git -C "$repo_path" init -b main >/dev/null
  git -C "$repo_path" config user.email "tooling@example.invalid"
  git -C "$repo_path" config user.name "tooling test"
  printf 'initial\n' >"$repo_path/README.md"
  git -C "$repo_path" add README.md
  git -C "$repo_path" commit -m "initial" >/dev/null
}

create_worktree() {
  repo_path="$1"
  branch_name="$2"
  path_name="$3"
  git -C "$repo_path" branch "$branch_name"
  git -C "$repo_path" worktree add ".worktrees/$path_name" "$branch_name" >/dev/null
}

require_line() {
  output="$1"
  pattern="$2"
  if ! printf '%s\n' "$output" | grep -E "$pattern" >/dev/null; then
    printf 'missing expected report line: %s\n' "$pattern" >&2
    printf '%s\n' "$output" >&2
    exit 1
  fi
}

reject_line() {
  output="$1"
  pattern="$2"
  if printf '%s\n' "$output" | grep -E "$pattern" >/dev/null; then
    printf 'unexpected report line: %s\n' "$pattern" >&2
    printf '%s\n' "$output" >&2
    exit 1
  fi
}

REPORT_REPO="$TMP_ROOT/report"
create_repo "$REPORT_REPO"

create_worktree "$REPORT_REPO" landing/absorbed landing-absorbed
printf 'absorbed\n' >"$REPORT_REPO/.worktrees/landing-absorbed/README.md"
git -C "$REPORT_REPO/.worktrees/landing-absorbed" add README.md
git -C "$REPORT_REPO/.worktrees/landing-absorbed" commit -m "absorbed candidate" >/dev/null

create_worktree "$REPORT_REPO" landing/stale landing-stale
mkdir -p "$REPORT_REPO/.worktrees/landing-stale/scripts"
printf 'stale helper\n' >"$REPORT_REPO/.worktrees/landing-stale/scripts/stale.sh"
git -C "$REPORT_REPO/.worktrees/landing-stale" add scripts/stale.sh
git -C "$REPORT_REPO/.worktrees/landing-stale" commit -m "stale candidate" >/dev/null

create_worktree "$REPORT_REPO" landing/dirty landing-dirty
mkdir -p "$REPORT_REPO/.worktrees/landing-dirty/tests/tooling"
printf 'generated log\n' >"$REPORT_REPO/.worktrees/landing-dirty/tests/tooling/tooling.log"

create_worktree "$REPORT_REPO" codex/active-lane active-lane
mkdir -p "$REPORT_REPO/.worktrees/active-lane/scripts"
printf 'active\n' >"$REPORT_REPO/.worktrees/active-lane/scripts/active.sh"
git -C "$REPORT_REPO/.worktrees/active-lane" add scripts/active.sh
git -C "$REPORT_REPO/.worktrees/active-lane" commit -m "active lane change" >/dev/null

printf 'main advance\n' >"$REPORT_REPO/main.txt"
git -C "$REPORT_REPO" add main.txt
git -C "$REPORT_REPO" commit -m "main advance" >/dev/null
git -C "$REPORT_REPO" cherry-pick landing/absorbed >/dev/null

create_worktree "$REPORT_REPO" landing/path-unsafe landing-path-unsafe
mkdir -p "$REPORT_REPO/.worktrees/landing-path-unsafe/compiler"
printf 'compiler\n' >"$REPORT_REPO/.worktrees/landing-path-unsafe/compiler/change.pas"
git -C "$REPORT_REPO/.worktrees/landing-path-unsafe" add compiler/change.pas
git -C "$REPORT_REPO/.worktrees/landing-path-unsafe" commit -m "path unsafe candidate" >/dev/null

REPORT_OUTPUT=$(
  cd "$REPORT_REPO"
  "$SCRIPT_UNDER_TEST" --base main --allow-path README.md --allow-path scripts
)

require_line "$REPORT_OUTPUT" '^landing-worktree-report=pass$'
require_line "$REPORT_OUTPUT" '^base=main$'
require_line "$REPORT_OUTPUT" '^readonly=true$'
require_line "$REPORT_OUTPUT" '^summary\.absorbed=1$'
require_line "$REPORT_OUTPUT" '^summary\.stale=1$'
require_line "$REPORT_OUTPUT" '^summary\.dirty=1$'
require_line "$REPORT_OUTPUT" '^summary\.path-unsafe=1$'
require_line "$REPORT_OUTPUT" '^summary\.total=4$'
require_line "$REPORT_OUTPUT" '^candidate[[:space:]]+landing/absorbed[[:space:]]+absorbed[[:space:]]+drop-from-queue[[:space:]]+1[[:space:]]+2[[:space:]]+.*\.worktrees/landing-absorbed$'
require_line "$REPORT_OUTPUT" '^candidate[[:space:]]+landing/stale[[:space:]]+stale[[:space:]]+replay-on-latest-base[[:space:]]+1[[:space:]]+2[[:space:]]+.*\.worktrees/landing-stale$'
require_line "$REPORT_OUTPUT" '^candidate[[:space:]]+landing/dirty[[:space:]]+dirty-generated-artifacts[[:space:]]+run-clean-artifacts-or-remove-generated-files[[:space:]]+0[[:space:]]+2[[:space:]]+.*\.worktrees/landing-dirty$'
require_line "$REPORT_OUTPUT" '^candidate[[:space:]]+landing/path-unsafe[[:space:]]+path-unsafe[[:space:]]+split-or-replay-allowed-paths-only[[:space:]]+1[[:space:]]+0[[:space:]]+.*\.worktrees/landing-path-unsafe$'
reject_line "$REPORT_OUTPUT" 'codex/active-lane'

test -d "$REPORT_REPO/.worktrees/landing-absorbed"
test -d "$REPORT_REPO/.worktrees/landing-stale"
test -d "$REPORT_REPO/.worktrees/landing-dirty"
test -d "$REPORT_REPO/.worktrees/landing-path-unsafe"
test -d "$REPORT_REPO/.worktrees/active-lane"

printf 'landing-worktree-report=pass\n'
