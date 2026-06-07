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
git -C "$FIXTURE_REPO" add file.txt
git -C "$FIXTURE_REPO" commit -m "initial" >/dev/null

git -C "$FIXTURE_REPO" branch feature
git -C "$FIXTURE_REPO" worktree add .worktrees/feature feature >/dev/null

for INDEX in 1 2 3 4 5 6 7 8 9 10; do
  git -C "$FIXTURE_REPO" branch "extra-$INDEX"
  git -C "$FIXTURE_REPO" worktree add ".worktrees/extra-$INDEX" "extra-$INDEX" >/dev/null
done

printf 'feature\n' >"$FIXTURE_REPO/.worktrees/feature/feature.txt"
git -C "$FIXTURE_REPO/.worktrees/feature" add feature.txt
git -C "$FIXTURE_REPO/.worktrees/feature" commit -m "feature commit" >/dev/null

printf 'main\n' >"$FIXTURE_REPO/main.txt"
git -C "$FIXTURE_REPO" add main.txt
git -C "$FIXTURE_REPO" commit -m "main commit" >/dev/null

AUDIT_OUTPUT=$(cd "$FIXTURE_REPO" && "$REPO_ROOT/scripts/worktree-audit.sh")

require_audit_line() {
  pattern="$1"
  if ! printf '%s\n' "$AUDIT_OUTPUT" | grep -E "$pattern" >/dev/null; then
    printf 'missing expected worktree audit line: %s\n' "$pattern" >&2
    printf '%s\n' "$AUDIT_OUTPUT" >&2
    exit 1
  fi
}

require_audit_line '^status[[:space:]]+location[[:space:]]+head[[:space:]]+branch[[:space:]]+base[[:space:]]+ahead[[:space:]]+behind[[:space:]]+path$'
require_audit_line 'clean[[:space:]]+ok[[:space:]]+[0-9a-f]+[[:space:]]+feature[[:space:]]+main[[:space:]]+1[[:space:]]+1[[:space:]]+.*/\.worktrees/feature$'

printf 'worktree-audit-divergence=pass\n'
