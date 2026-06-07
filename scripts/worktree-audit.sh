#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git worktree list --porcelain | awk '
  /^worktree / && !found { print substr($0, 10); found = 1 }
')"

if [[ -z "$repo_root" ]]; then
  echo "error: unable to detect repository root from git worktree list" >&2
  exit 1
fi

allowed_prefix="$repo_root/.worktrees/"
violations=0

print_record() {
  local path="$1"
  local head="$2"
  local branch="$3"
  local location="ok"
  local dirty="clean"

  if [[ -z "$path" ]]; then
    return
  fi

  if [[ "$path" != "$repo_root" && "$path" != "$allowed_prefix"* ]]; then
    location="outside-.worktrees"
    violations=$((violations + 1))
  fi

  if [[ -n "$(git -C "$path" status --porcelain)" ]]; then
    dirty="dirty"
  fi

  printf '%-8s %-21s %-12s %-40s %s\n' \
    "$dirty" "$location" "${head:0:8}" "$branch" "$path"
}

printf '%-8s %-21s %-12s %-40s %s\n' "status" "location" "head" "branch" "path"
printf '%-8s %-21s %-12s %-40s %s\n' "------" "--------" "----" "------" "----"

path=""
head=""
branch="(unknown)"

while IFS= read -r line || [[ -n "$line" ]]; do
  case "$line" in
    worktree\ *)
      print_record "$path" "$head" "$branch"
      path="${line#worktree }"
      head=""
      branch="(unknown)"
      ;;
    HEAD\ *)
      head="${line#HEAD }"
      ;;
    branch\ refs/heads/*)
      branch="${line#branch refs/heads/}"
      ;;
    detached)
      branch="(detached)"
      ;;
  esac
done < <(git -C "$repo_root" worktree list --porcelain)

print_record "$path" "$head" "$branch"

if (( violations > 0 )); then
  echo
  echo "error: found $violations linked worktree(s) outside .worktrees/" >&2
  exit 1
fi
