#!/usr/bin/env bash
# landing-finalize.sh — finalize a landing candidate into main
# =================================================================
# Automates the manual landing tail that used to be done by hand:
#   1. fast-forward check (candidate must be a descendant of main)
#   2. git update-ref refs/heads/main <candidate>
#   3. optional archive tag (archive/<name>)
#   4. sync the main worktree to the new HEAD
#
# Why the worktree sync exists: `git update-ref` only moves the ref; the
# checked-out worktree and index are left at the old content. Every landing
# that used update-ref therefore left the main checkout silently stale
# (observed: core/src kept the pre-fix servercertverify for several batches
# while refs/heads/main pointed at the fixed code). The sync below restores
# HEAD content but never touches real uncommitted work: it aborts when the
# worktree differs from the index or when untracked files exist.
#
# Usage:
#   scripts/landing-finalize.sh <candidate-sha> [tag-name]
#     candidate-sha  commit to land (must be a fast-forward from main)
#     tag-name       optional; creates archive/<tag-name> at candidate

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

if [[ $# -lt 1 || $# -gt 2 ]]; then
  cat >&2 <<'EOF'
usage: scripts/landing-finalize.sh <candidate-sha> [tag-name]
EOF
  exit 2
fi

candidate="$1"
tag_name="${2:-}"

# 1. fast-forward gate
main_head="$(git rev-parse --short main)"
if ! git rev-parse -q --verify "$candidate^{commit}" >/dev/null; then
  echo "error: not a commit: $candidate" >&2
  exit 2
fi
if [[ "$(git rev-parse main)" == "$(git rev-parse "$candidate")" ]]; then
  echo "noop: candidate == main, nothing to do"
  exit 0
fi
if ! git merge-base --is-ancestor main "$candidate"; then
  echo "error: not a fast-forward from main ($main_head): $candidate" >&2
  exit 1
fi

# 2. advance main
git update-ref refs/heads/main "$candidate"
echo "main: $main_head -> $(git rev-parse --short main)"

# 3. optional archive tag
if [[ -n "$tag_name" ]]; then
  git tag "archive/$tag_name" "$candidate"
  echo "tag: archive/$tag_name @ $(git rev-parse --short "$candidate")"
fi

# 4. sync main worktree (only when main is checked out here and it is safe)
sync_ok=1
if [[ "$(git rev-parse --abbrev-ref HEAD)" != "main" ]]; then
  echo "info: main not checked out here (HEAD=$(git rev-parse --abbrev-ref HEAD)); skip worktree sync"
  sync_ok=0
elif ! git diff --quiet; then
  echo "warning: worktree has uncommitted changes; sync skipped (leaving as-is, inspect manually)" >&2
  sync_ok=0
elif git status --porcelain | grep -q '^??'; then
  echo "warning: untracked files present; sync skipped (leaving as-is, inspect manually)" >&2
  sync_ok=0
else
  git checkout HEAD -- .
  if git status --porcelain | grep -q .; then
    echo "error: residual differences after sync:" >&2
    git status --short >&2
    sync_ok=0
  else
    echo "worktree-sync: ok"
  fi
fi

[[ $sync_ok -eq 1 ]] || exit 3
echo "landing-finalize: done"
