#!/usr/bin/env bash
set -euo pipefail

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

SCRIPT_UNDER_TEST="$REPO_ROOT/scripts/worktree-add.sh"
FAKE_BIN="$TMP_ROOT/bin"
mkdir -p "$FAKE_BIN"

cat >"$FAKE_BIN/git" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

log_call() {
  printf 'CALL'
  printf ' %s' "$@"
  printf '\n'
}

: "${FAKE_GIT_LOG:?}"
: "${FAKE_REPO_ROOT:?}"

log_call "$@" >>"$FAKE_GIT_LOG"

if [[ "${1:-}" == "worktree" && "${2:-}" == "list" && "${3:-}" == "--porcelain" ]]; then
  printf 'worktree %s\n' "$FAKE_REPO_ROOT"
  printf 'HEAD 0000000000000000000000000000000000000000\n'
  printf 'branch refs/heads/main\n\n'

  count="${FAKE_WORKTREE_COUNT:-0}"
  index=0
  while (( index < count )); do
    printf 'worktree %s/.worktrees/existing-%06d\n' "$FAKE_REPO_ROOT" "$index"
    printf 'HEAD 0000000000000000000000000000000000000000\n'
    printf 'branch refs/heads/existing-%06d\n\n' "$index"
    index=$((index + 1))
  done
  exit 0
fi

if [[ "${1:-}" != "-C" ]]; then
  printf 'unexpected git invocation without -C: %s\n' "$*" >&2
  exit 99
fi

repo_arg="$2"
shift 2

if [[ "$repo_arg" != "$FAKE_REPO_ROOT" ]]; then
  printf 'unexpected git repo: %s\n' "$repo_arg" >&2
  exit 99
fi

if [[ "${1:-}" == "check-ignore" && "${2:-}" == "-q" && "${3:-}" == ".worktrees/" ]]; then
  [[ "${FAKE_CHECK_IGNORE:-pass}" == "pass" ]]
  exit $?
fi

if [[ "${1:-}" == "show-ref" && "${2:-}" == "--verify" && "${3:-}" == "--quiet" ]]; then
  [[ "${FAKE_BRANCH_EXISTS:-0}" == "1" ]]
  exit $?
fi

if [[ "${1:-}" == "worktree" && "${2:-}" == "add" ]]; then
  if [[ "${3:-}" == "-b" ]]; then
    target="${5:-}"
  else
    target="${3:-}"
  fi
  mkdir -p "$target"
  exit 0
fi

printf 'unexpected git invocation: %s\n' "$*" >&2
exit 99
EOF

chmod +x "$FAKE_BIN/git"

create_fake_repo() {
  repo_path="$1"
  mkdir -p "$repo_path"
  : >"$repo_path/.gitignore"
}

run_worktree_add() {
  repo_path="$1"
  log_path="$2"
  worktree_count="$3"
  check_ignore="$4"
  branch="$5"
  base="$6"

  FAKE_REPO_ROOT="$repo_path" \
    FAKE_GIT_LOG="$log_path" \
    FAKE_WORKTREE_COUNT="$worktree_count" \
    FAKE_CHECK_IGNORE="$check_ignore" \
    PATH="$FAKE_BIN:$PATH" \
    "$SCRIPT_UNDER_TEST" "$branch" "$base"
}

assert_no_worktree_add_call() {
  log_path="$1"
  if grep -q ' worktree add' "$log_path"; then
    printf 'unexpected git worktree add call\n' >&2
    cat "$log_path" >&2
    exit 1
  fi
}

LARGE_REPO="$TMP_ROOT/large"
LARGE_LOG="$TMP_ROOT/large.log"
create_fake_repo "$LARGE_REPO"

set +e
LARGE_OUTPUT=$(run_worktree_add "$LARGE_REPO" "$LARGE_LOG" 5000 pass landing/worktree-add-141 origin/main 2>"$TMP_ROOT/large.err")
LARGE_STATUS=$?
set -e

if [[ "$LARGE_STATUS" -ne 0 ]]; then
  printf 'worktree-add should tolerate large worktree-list output; exit=%s\n' "$LARGE_STATUS" >&2
  cat "$TMP_ROOT/large.err" >&2
  exit 1
fi

grep -q '^worktree ready: .*/\.worktrees/landing-worktree-add-141$' <<<"$LARGE_OUTPUT"
grep -q '^branch: landing/worktree-add-141$' <<<"$LARGE_OUTPUT"
test -d "$LARGE_REPO/.worktrees/landing-worktree-add-141"
grep -q ' worktree add -b landing/worktree-add-141 .*/\.worktrees/landing-worktree-add-141 origin/main$' "$LARGE_LOG"

CHECK_IGNORE_REPO="$TMP_ROOT/check-ignore"
CHECK_IGNORE_LOG="$TMP_ROOT/check-ignore.log"
create_fake_repo "$CHECK_IGNORE_REPO"

set +e
run_worktree_add "$CHECK_IGNORE_REPO" "$CHECK_IGNORE_LOG" 5 fail codex/check-ignore main >"$TMP_ROOT/check-ignore.out" 2>"$TMP_ROOT/check-ignore.err"
CHECK_IGNORE_STATUS=$?
set -e

if [[ "$CHECK_IGNORE_STATUS" -eq 0 ]]; then
  printf 'worktree-add should fail when .worktrees/ is not ignored\n' >&2
  cat "$TMP_ROOT/check-ignore.out" >&2
  exit 1
fi

grep -q 'error: .worktrees/ is not ignored by git' "$TMP_ROOT/check-ignore.err"
test ! -e "$CHECK_IGNORE_REPO/.worktrees/check-ignore"
assert_no_worktree_add_call "$CHECK_IGNORE_LOG"

TARGET_EXISTS_REPO="$TMP_ROOT/target-exists"
TARGET_EXISTS_LOG="$TMP_ROOT/target-exists.log"
create_fake_repo "$TARGET_EXISTS_REPO"
mkdir -p "$TARGET_EXISTS_REPO/.worktrees/target-exists"

set +e
run_worktree_add "$TARGET_EXISTS_REPO" "$TARGET_EXISTS_LOG" 5 pass codex/target-exists main >"$TMP_ROOT/target-exists.out" 2>"$TMP_ROOT/target-exists.err"
TARGET_EXISTS_STATUS=$?
set -e

if [[ "$TARGET_EXISTS_STATUS" -eq 0 ]]; then
  printf 'worktree-add should fail when target already exists\n' >&2
  cat "$TMP_ROOT/target-exists.out" >&2
  exit 1
fi

grep -q "error: target already exists: $TARGET_EXISTS_REPO/.worktrees/target-exists" "$TMP_ROOT/target-exists.err"
assert_no_worktree_add_call "$TARGET_EXISTS_LOG"

printf 'worktree-add=pass\n'
