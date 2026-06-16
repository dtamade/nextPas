#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: scripts/worktree-add.sh <branch> [base]

Create or open a nextPas worktree under .worktrees/<short-name>.

Examples:
  scripts/worktree-add.sh codex/http-parser-20260606
  scripts/worktree-add.sh codex/http-parser-20260606 main
USAGE
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

branch="${1:-}"
base="${2:-main}"

if [[ -z "$branch" ]]; then
  usage >&2
  exit 2
fi

repo_root="$(git worktree list --porcelain | awk '
  /^worktree / && root == "" { root = substr($0, 10) }
  END { print root }
')"

if [[ -z "$repo_root" ]]; then
  echo "error: unable to detect repository root from git worktree list" >&2
  exit 1
fi

if ! git -C "$repo_root" check-ignore -q .worktrees/; then
  echo "error: .worktrees/ is not ignored by git; refusing to create a local worktree" >&2
  exit 1
fi

short_name="$branch"
short_name="${short_name#refs/heads/}"
short_name="${short_name#codex/}"
short_name="$(printf '%s' "$short_name" | sed -E 's#[^A-Za-z0-9._-]+#-#g; s#-+#-#g; s#^-##; s#-$##')"

if [[ -z "$short_name" ]]; then
  echo "error: branch name '$branch' does not produce a safe worktree directory name" >&2
  exit 1
fi

target="$repo_root/.worktrees/$short_name"

if [[ -e "$target" ]]; then
  echo "error: target already exists: $target" >&2
  echo "hint: run scripts/worktree-audit.sh to inspect existing worktrees" >&2
  exit 1
fi

mkdir -p "$repo_root/.worktrees"

if git -C "$repo_root" show-ref --verify --quiet "refs/heads/$branch"; then
  git -C "$repo_root" worktree add "$target" "$branch"
else
  git -C "$repo_root" worktree add -b "$branch" "$target" "$base"
fi

cat <<EOF
worktree ready: $target
branch: $branch

Next:
  cd "$target"
EOF
