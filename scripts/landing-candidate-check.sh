#!/usr/bin/env bash
set -euo pipefail

base_ref=""
allow_paths=()

usage() {
  cat >&2 <<'EOF'
usage: scripts/landing-candidate-check.sh [--base REF] --allow-path PREFIX [--allow-path PREFIX...]

Checks the current worktree as a read-only landing evidence gate. It verifies
the worktree is clean, not detached, not behind the base ref, located in the
repository root or under .worktrees/, and that changed files are limited to the
allowed path prefixes.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --base)
      if [[ $# -lt 2 || -z "$2" ]]; then
        echo "error: --base requires a ref" >&2
        usage
        exit 2
      fi
      base_ref="$2"
      shift 2
      ;;
    --allow-path)
      if [[ $# -lt 2 || -z "$2" ]]; then
        echo "error: --allow-path requires a prefix" >&2
        usage
        exit 2
      fi
      allow_paths+=("${2%/}")
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "error: unknown argument: $1" >&2
      usage
      exit 2
      ;;
  esac
done

repo_root_path="$(git worktree list --porcelain | awk '
  /^worktree / && root == "" { root = substr($0, 10) }
  END { print root }
')"

if [[ -z "$repo_root_path" ]]; then
  echo "error: unable to detect repository root from git worktree list" >&2
  exit 2
fi

current_worktree_root="$(git rev-parse --show-toplevel)"
worktree_path="$(CDPATH= cd -- "$current_worktree_root" && pwd -P)"
repo_root_path="$(CDPATH= cd -- "$repo_root_path" && pwd -P)"
allowed_worktree_prefix="$repo_root_path/.worktrees/"

default_base_ref() {
  if git -C "$worktree_path" show-ref --verify --quiet refs/heads/main; then
    printf 'main'
    return
  fi

  if git -C "$worktree_path" show-ref --verify --quiet refs/heads/master; then
    printf 'master'
    return
  fi

  echo "error: unable to detect default base ref; pass --base" >&2
  exit 2
}

if [[ -z "$base_ref" ]]; then
  base_ref="$(default_base_ref)"
fi

if [[ ${#allow_paths[@]} -eq 0 ]]; then
  echo "error: at least one --allow-path prefix is required" >&2
  usage
  exit 2
fi

if [[ "$worktree_path" != "$repo_root_path" && "$worktree_path" != "$allowed_worktree_prefix"* ]]; then
  echo "error: landing candidate worktree must be repo root or under .worktrees/: $worktree_path" >&2
  exit 1
fi

if ! git -C "$worktree_path" rev-parse --verify --quiet "$base_ref^{commit}" >/dev/null; then
  echo "error: base ref does not resolve to a commit: $base_ref" >&2
  exit 2
fi

branch="$(git -C "$worktree_path" branch --show-current)"
if [[ -z "$branch" ]]; then
  echo "error: landing candidate must be on a named branch" >&2
  exit 1
fi

if [[ -n "$(git -C "$worktree_path" status --porcelain)" ]]; then
  echo "error: landing candidate worktree must be clean" >&2
  git -C "$worktree_path" status --short >&2
  exit 1
fi

counts="$(git -C "$worktree_path" rev-list --left-right --count "$base_ref...HEAD")"
behind="${counts%%[[:space:]]*}"
ahead="${counts##*[[:space:]]}"

if [[ "$behind" != "0" ]]; then
  echo "error: landing candidate is behind $base_ref by $behind commit(s)" >&2
  exit 1
fi

changed_files="$(git -C "$worktree_path" diff --no-renames --name-only "$base_ref...HEAD")"

path_allowed() {
  local path="$1"
  local prefix

  for prefix in "${allow_paths[@]}"; do
    if [[ "$path" == "$prefix" || "$path" == "$prefix/"* ]]; then
      return 0
    fi
  done

  return 1
}

while IFS= read -r changed_path || [[ -n "$changed_path" ]]; do
  if [[ -z "$changed_path" ]]; then
    continue
  fi
  if ! path_allowed "$changed_path"; then
    echo "error: changed path is outside allowed prefixes: $changed_path" >&2
    echo "allowed prefixes:" >&2
    printf '  %s\n' "${allow_paths[@]}" >&2
    exit 1
  fi
done <<< "$changed_files"

head_sha="$(git -C "$worktree_path" rev-parse --short HEAD)"

printf 'landing-candidate=pass\n'
printf 'branch=%s\n' "$branch"
printf 'worktree=%s\n' "$worktree_path"
printf 'head=%s\n' "$head_sha"
printf 'base=%s\n' "$base_ref"
printf 'ahead=%s\n' "$ahead"
printf 'behind=%s\n' "$behind"
printf 'allowed-paths=\n'
printf '%s\n' "${allow_paths[@]}"
printf 'changed-files=\n'
if [[ -n "$changed_files" ]]; then
  printf '%s\n' "$changed_files"
fi
