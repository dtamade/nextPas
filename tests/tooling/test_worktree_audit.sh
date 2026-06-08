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
mkdir -p "$FIXTURE_REPO"
git -C "$FIXTURE_REPO" init -b main >/dev/null
git -C "$FIXTURE_REPO" config user.email "tooling@example.invalid"
git -C "$FIXTURE_REPO" config user.name "tooling test"

printf 'initial\n' >"$FIXTURE_REPO/file.txt"
printf '.worktrees/\n' >"$FIXTURE_REPO/.gitignore"
git -C "$FIXTURE_REPO" add .gitignore file.txt
git -C "$FIXTURE_REPO" commit -m "initial" >/dev/null

git -C "$FIXTURE_REPO" branch feature
git -C "$FIXTURE_REPO" worktree add .worktrees/feature feature >/dev/null
git -C "$FIXTURE_REPO" branch absorbed
git -C "$FIXTURE_REPO" worktree add .worktrees/absorbed absorbed >/dev/null
git -C "$FIXTURE_REPO" branch dirty
git -C "$FIXTURE_REPO" worktree add .worktrees/dirty dirty >/dev/null

for INDEX in 1 2 3 4 5 6 7 8 9 10; do
  git -C "$FIXTURE_REPO" branch "extra-$INDEX"
  git -C "$FIXTURE_REPO" worktree add ".worktrees/extra-$INDEX" "extra-$INDEX" >/dev/null
done

printf 'feature\n' >"$FIXTURE_REPO/.worktrees/feature/feature.txt"
git -C "$FIXTURE_REPO/.worktrees/feature" add feature.txt
git -C "$FIXTURE_REPO/.worktrees/feature" commit -m "feature commit" >/dev/null

printf 'absorbed\n' >"$FIXTURE_REPO/.worktrees/absorbed/absorbed.txt"
git -C "$FIXTURE_REPO/.worktrees/absorbed" add absorbed.txt
git -C "$FIXTURE_REPO/.worktrees/absorbed" commit -m "absorbed commit" >/dev/null

printf 'dirty\n' >"$FIXTURE_REPO/.worktrees/dirty/dirty.txt"

printf 'main\n' >"$FIXTURE_REPO/main.txt"
git -C "$FIXTURE_REPO" add main.txt
git -C "$FIXTURE_REPO" commit -m "main commit" >/dev/null
git -C "$FIXTURE_REPO" cherry-pick absorbed >/dev/null

git -C "$FIXTURE_REPO" branch codex/module-ready
git -C "$FIXTURE_REPO" worktree add .worktrees/module-ready codex/module-ready >/dev/null
git -C "$FIXTURE_REPO" branch landing/module-ready
git -C "$FIXTURE_REPO" worktree add .worktrees/landing-ready landing/module-ready >/dev/null

printf 'module\n' >"$FIXTURE_REPO/.worktrees/module-ready/module.txt"
git -C "$FIXTURE_REPO/.worktrees/module-ready" add module.txt
git -C "$FIXTURE_REPO/.worktrees/module-ready" commit -m "module ready" >/dev/null

printf 'landing\n' >"$FIXTURE_REPO/.worktrees/landing-ready/landing.txt"
git -C "$FIXTURE_REPO/.worktrees/landing-ready" add landing.txt
git -C "$FIXTURE_REPO/.worktrees/landing-ready" commit -m "landing ready" >/dev/null

AUDIT_OUTPUT=$(cd "$FIXTURE_REPO" && "$REPO_ROOT/scripts/worktree-audit.sh")

require_audit_line() {
  pattern="$1"
  if ! printf '%s\n' "$AUDIT_OUTPUT" | grep -E "$pattern" >/dev/null; then
    printf 'missing expected worktree audit line: %s\n' "$pattern" >&2
    printf '%s\n' "$AUDIT_OUTPUT" >&2
    exit 1
  fi
}

require_audit_line '^status[[:space:]]+queue[[:space:]]+action[[:space:]]+location[[:space:]]+head[[:space:]]+branch[[:space:]]+base[[:space:]]+ahead[[:space:]]+behind[[:space:]]+path$'
require_audit_line 'clean[[:space:]]+stale[[:space:]]+replay-on-latest-base[[:space:]]+ok[[:space:]]+[0-9a-f]+[[:space:]]+feature[[:space:]]+main[[:space:]]+1[[:space:]]+2[[:space:]]+.*/\.worktrees/feature$'
require_audit_line 'clean[[:space:]]+absorbed[[:space:]]+drop-from-queue[[:space:]]+ok[[:space:]]+[0-9a-f]+[[:space:]]+absorbed[[:space:]]+main[[:space:]]+1[[:space:]]+2[[:space:]]+.*/\.worktrees/absorbed$'
require_audit_line 'dirty[[:space:]]+dirty[[:space:]]+inspect-or-stash-uncommitted-work[[:space:]]+ok[[:space:]]+[0-9a-f]+[[:space:]]+dirty[[:space:]]+main[[:space:]]+0[[:space:]]+2[[:space:]]+.*/\.worktrees/dirty$'
require_audit_line 'clean[[:space:]]+needs-landing[[:space:]]+prepare-clean-landing[[:space:]]+ok[[:space:]]+[0-9a-f]+[[:space:]]+codex/module-ready[[:space:]]+main[[:space:]]+1[[:space:]]+0[[:space:]]+.*/\.worktrees/module-ready$'
require_audit_line 'clean[[:space:]]+ready[[:space:]]+run-landing-check[[:space:]]+ok[[:space:]]+[0-9a-f]+[[:space:]]+landing/module-ready[[:space:]]+main[[:space:]]+1[[:space:]]+0[[:space:]]+.*/\.worktrees/landing-ready$'
require_audit_line 'clean[[:space:]]+current[[:space:]]+no-action[[:space:]]+ok[[:space:]]+[0-9a-f]+[[:space:]]+main[[:space:]]+main[[:space:]]+0[[:space:]]+0[[:space:]]+.*/repo$'

printf 'worktree-audit-divergence=pass\n'
