#!/usr/bin/env bash
set -euo pipefail

base_ref=""
allow_paths=()

usage() {
  cat >&2 <<'EOF'
usage: scripts/landing-queue-classifier.sh [--base REF] --allow-path PREFIX [--allow-path PREFIX...]

Classifies the current worktree for landing queue triage. It is read-only and
prints machine-readable fields for controller queue decisions.
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

if [[ ${#allow_paths[@]} -eq 0 ]]; then
  echo "error: at least one --allow-path prefix is required" >&2
  usage
  exit 2
fi

worktree_path="$(git rev-parse --show-toplevel)"

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

if ! git -C "$worktree_path" rev-parse --verify --quiet "$base_ref^{commit}" >/dev/null; then
  echo "error: base ref does not resolve to a commit: $base_ref" >&2
  exit 2
fi

branch="$(git -C "$worktree_path" branch --show-current)"
if [[ -z "$branch" ]]; then
  branch="(detached)"
fi

head_sha="$(git -C "$worktree_path" rev-parse --short HEAD)"
counts="$(git -C "$worktree_path" rev-list --left-right --count "$base_ref...HEAD")"
behind="${counts%%[[:space:]]*}"
ahead="${counts##*[[:space:]]}"

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

print_common() {
  printf 'branch=%s\n' "$branch"
  printf 'worktree=%s\n' "$worktree_path"
  printf 'head=%s\n' "$head_sha"
  printf 'base=%s\n' "$base_ref"
  printf 'ahead=%s\n' "$ahead"
  printf 'behind=%s\n' "$behind"
}

print_state() {
  local state="$1"
  local action="$2"

  printf 'landing-queue=%s\n' "$state"
  printf 'candidate-action=%s\n' "$action"
  print_common
}

dirty_files="$(git -C "$worktree_path" status --porcelain --untracked-files=all | awk '{ print $2 }')"
dirty_generated_files="$(printf '%s\n' "$dirty_files" | grep -E '(^tests/tooling/.*\.log$|^core/tests/.*/test_.*/.*\.log$)' || true)"
if [[ -n "$dirty_generated_files" ]]; then
  print_state "dirty-generated-artifacts" "run-clean-artifacts-or-remove-generated-files"
  printf 'dirty-files=\n'
  printf '%s\n' "$dirty_generated_files"
  exit 0
fi

if [[ -n "$dirty_files" ]]; then
  print_state "dirty" "inspect-or-stash-uncommitted-work"
  printf 'dirty-files=\n'
  printf '%s\n' "$dirty_files"
  exit 0
fi

if [[ "$behind" != "0" ]]; then
  if [[ "$ahead" = "0" ]]; then
    print_state "behind-main" "drop-empty-or-refresh-from-main"
    exit 0
  fi

  if ! git -C "$worktree_path" cherry "$base_ref" HEAD | grep -q '^+'; then
    print_state "absorbed" "drop-from-queue"
  else
    print_state "stale" "replay-on-latest-base"
  fi
  exit 0
fi

changed_files="$(git -C "$worktree_path" diff --no-renames --name-only "$base_ref...HEAD")"
historical_changed_files="$(git -C "$worktree_path" log --name-only --format= "$base_ref..HEAD" | sed '/^$/d' | sort -u)"

path_unsafe_files=()
while IFS= read -r changed_path || [[ -n "$changed_path" ]]; do
  if [[ -z "$changed_path" ]]; then
    continue
  fi
  if ! path_allowed "$changed_path"; then
    path_unsafe_files+=("$changed_path")
  fi
done <<< "$changed_files"

while IFS= read -r changed_path || [[ -n "$changed_path" ]]; do
  if [[ -z "$changed_path" ]]; then
    continue
  fi
  if ! path_allowed "$changed_path"; then
    path_unsafe_files+=("$changed_path")
  fi
done <<< "$historical_changed_files"

if [[ ${#path_unsafe_files[@]} -gt 0 ]]; then
  print_state "path-unsafe" "split-or-replay-allowed-paths-only"
  printf 'path-unsafe-files=\n'
  printf '%s\n' "${path_unsafe_files[@]}" | sort -u
  exit 0
fi

print_state "ready" "run-landing-check"
printf 'changed-files=\n'
if [[ -n "$changed_files" ]]; then
  printf '%s\n' "$changed_files"
fi
