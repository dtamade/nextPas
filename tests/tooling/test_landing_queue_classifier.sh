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

SCRIPT_UNDER_TEST="$REPO_ROOT/scripts/landing-queue-classifier.sh"

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

create_landing_worktree() {
  repo_path="$1"
  branch_name="$2"
  git -C "$repo_path" branch "$branch_name"
  git -C "$repo_path" worktree add ".worktrees/$branch_name" "$branch_name" >/dev/null
}

run_classifier() {
  candidate_path="$1"
  shift
  (
    cd "$candidate_path"
    "$SCRIPT_UNDER_TEST" "$@"
  )
}

require_line() {
  output="$1"
  pattern="$2"
  if ! printf '%s\n' "$output" | grep -E "$pattern" >/dev/null; then
    printf 'missing expected classifier line: %s\n' "$pattern" >&2
    printf '%s\n' "$output" >&2
    exit 1
  fi
}

ABSORBED_REPO="$TMP_ROOT/absorbed"
create_repo "$ABSORBED_REPO"
create_landing_worktree "$ABSORBED_REPO" landing
printf 'candidate change\n' >"$ABSORBED_REPO/.worktrees/landing/README.md"
git -C "$ABSORBED_REPO/.worktrees/landing" add README.md
git -C "$ABSORBED_REPO/.worktrees/landing" commit -m "candidate change" >/dev/null
printf 'main advance\n' >"$ABSORBED_REPO/main.txt"
git -C "$ABSORBED_REPO" add main.txt
git -C "$ABSORBED_REPO" commit -m "main advance" >/dev/null
git -C "$ABSORBED_REPO" cherry-pick landing >/dev/null
ABSORBED_OUTPUT=$(run_classifier "$ABSORBED_REPO/.worktrees/landing" --base main --allow-path README.md)
require_line "$ABSORBED_OUTPUT" '^landing-queue=absorbed$'
require_line "$ABSORBED_OUTPUT" '^candidate-action=drop-from-queue$'
require_line "$ABSORBED_OUTPUT" '^ahead=1$'
require_line "$ABSORBED_OUTPUT" '^behind=2$'

STALE_REPO="$TMP_ROOT/stale"
create_repo "$STALE_REPO"
create_landing_worktree "$STALE_REPO" landing
mkdir -p "$STALE_REPO/.worktrees/landing/scripts"
printf 'helper\n' >"$STALE_REPO/.worktrees/landing/scripts/helper.sh"
git -C "$STALE_REPO/.worktrees/landing" add scripts/helper.sh
git -C "$STALE_REPO/.worktrees/landing" commit -m "candidate helper" >/dev/null
printf 'main advance\n' >"$STALE_REPO/main.txt"
git -C "$STALE_REPO" add main.txt
git -C "$STALE_REPO" commit -m "main advance" >/dev/null
STALE_OUTPUT=$(run_classifier "$STALE_REPO/.worktrees/landing" --base main --allow-path scripts)
require_line "$STALE_OUTPUT" '^landing-queue=stale$'
require_line "$STALE_OUTPUT" '^candidate-action=replay-on-latest-base$'
require_line "$STALE_OUTPUT" '^ahead=1$'
require_line "$STALE_OUTPUT" '^behind=1$'

BEHIND_REPO="$TMP_ROOT/behind"
create_repo "$BEHIND_REPO"
create_landing_worktree "$BEHIND_REPO" landing
printf 'main advance\n' >"$BEHIND_REPO/main.txt"
git -C "$BEHIND_REPO" add main.txt
git -C "$BEHIND_REPO" commit -m "main advance" >/dev/null
BEHIND_OUTPUT=$(run_classifier "$BEHIND_REPO/.worktrees/landing" --base main --allow-path scripts)
require_line "$BEHIND_OUTPUT" '^landing-queue=behind-main$'
require_line "$BEHIND_OUTPUT" '^candidate-action=drop-empty-or-refresh-from-main$'
require_line "$BEHIND_OUTPUT" '^ahead=0$'
require_line "$BEHIND_OUTPUT" '^behind=1$'

PATH_UNSAFE_REPO="$TMP_ROOT/path-unsafe"
create_repo "$PATH_UNSAFE_REPO"
create_landing_worktree "$PATH_UNSAFE_REPO" landing
mkdir -p "$PATH_UNSAFE_REPO/.worktrees/landing/compiler"
printf 'compiler change\n' >"$PATH_UNSAFE_REPO/.worktrees/landing/compiler/change.pas"
git -C "$PATH_UNSAFE_REPO/.worktrees/landing" add compiler/change.pas
git -C "$PATH_UNSAFE_REPO/.worktrees/landing" commit -m "compiler change" >/dev/null
PATH_UNSAFE_OUTPUT=$(run_classifier "$PATH_UNSAFE_REPO/.worktrees/landing" --base main --allow-path scripts)
require_line "$PATH_UNSAFE_OUTPUT" '^landing-queue=path-unsafe$'
require_line "$PATH_UNSAFE_OUTPUT" '^candidate-action=split-or-replay-allowed-paths-only$'
require_line "$PATH_UNSAFE_OUTPUT" '^path-unsafe-files=$'
require_line "$PATH_UNSAFE_OUTPUT" '^compiler/change\.pas$'

DIRTY_GENERATED_REPO="$TMP_ROOT/dirty-generated"
create_repo "$DIRTY_GENERATED_REPO"
create_landing_worktree "$DIRTY_GENERATED_REPO" landing
mkdir -p "$DIRTY_GENERATED_REPO/.worktrees/landing/tests/tooling"
printf 'generated log\n' >"$DIRTY_GENERATED_REPO/.worktrees/landing/tests/tooling/tooling.log"
DIRTY_GENERATED_OUTPUT=$(run_classifier "$DIRTY_GENERATED_REPO/.worktrees/landing" --base main --allow-path scripts)
require_line "$DIRTY_GENERATED_OUTPUT" '^landing-queue=dirty-generated-artifacts$'
require_line "$DIRTY_GENERATED_OUTPUT" '^candidate-action=run-clean-artifacts-or-remove-generated-files$'
require_line "$DIRTY_GENERATED_OUTPUT" '^dirty-files=$'
require_line "$DIRTY_GENERATED_OUTPUT" '^tests/tooling/tooling\.log$'

printf 'landing-queue-classifier=pass\n'
