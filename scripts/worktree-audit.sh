#!/usr/bin/env bash
set -euo pipefail

summary_only=0

usage() {
  cat >&2 <<'EOF'
usage: scripts/worktree-audit.sh [--summary]

Audits linked worktrees. Default output is a table; --summary prints
machine-readable queue counts for controller triage.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --summary)
      summary_only=1
      shift
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

repo_root="$(git worktree list --porcelain | awk '
  /^worktree / && !found { print substr($0, 10); found = 1 }
')"

if [[ -z "$repo_root" ]]; then
  echo "error: unable to detect repository root from git worktree list" >&2
  exit 1
fi

allowed_prefix="$repo_root/.worktrees/"
violations=0
total_count=0
current_count=0
dirty_count=0
stale_count=0
absorbed_count=0
behind_main_count=0
needs_landing_count=0
ready_count=0
unknown_count=0
review_count=0
outside_worktrees_count=0

default_base_ref() {
  if git -C "$repo_root" show-ref --verify --quiet refs/heads/main; then
    printf 'main'
    return
  fi

  if git -C "$repo_root" show-ref --verify --quiet refs/heads/master; then
    printf 'master'
    return
  fi

  printf '-'
}

branch_ref() {
  local branch="$1"
  local head="$2"

  case "$branch" in
    "(detached)"|"(unknown)")
      printf '%s' "$head"
      ;;
    *)
      printf 'refs/heads/%s' "$branch"
      ;;
  esac
}

print_divergence() {
  local branch="$1"
  local head="$2"
  local base_ref="$3"
  local compare_ref
  local counts
  local behind
  local ahead

  if [[ "$base_ref" = "-" ]]; then
    printf '%s %s' "-" "-"
    return
  fi

  compare_ref="$(branch_ref "$branch" "$head")"
  if ! git -C "$repo_root" rev-parse --verify --quiet "$compare_ref^{commit}" >/dev/null; then
    printf '%s %s' "?" "?"
    return
  fi

  if ! counts="$(git -C "$repo_root" rev-list --left-right --count "$base_ref...$compare_ref" 2>/dev/null)"; then
    printf '%s %s' "?" "?"
    return
  fi

  behind="${counts%%[[:space:]]*}"
  ahead="${counts##*[[:space:]]}"
  printf '%s %s' "$ahead" "$behind"
}

print_queue_state() {
  local dirty="$1"
  local branch="$2"
  local head="$3"
  local base_ref="$4"
  local ahead="$5"
  local behind="$6"
  local compare_ref
  local cherry_line

  if [[ "$dirty" = "dirty" ]]; then
    printf '%s %s' "dirty" "inspect-or-stash-uncommitted-work"
    return
  fi

  if [[ "$base_ref" = "-" || "$ahead" = "?" || "$behind" = "?" ]]; then
    printf '%s %s' "unknown" "inspect-manually"
    return
  fi

  if [[ "$behind" != "0" ]]; then
    if [[ "$ahead" = "0" ]]; then
      printf '%s %s' "behind-main" "drop-empty-or-refresh-from-main"
      return
    fi

    compare_ref="$(branch_ref "$branch" "$head")"
    while IFS= read -r cherry_line || [[ -n "$cherry_line" ]]; do
      case "$cherry_line" in
        +*)
          printf '%s %s' "stale" "replay-on-latest-base"
          return
          ;;
      esac
    done < <(git -C "$repo_root" cherry "$base_ref" "$compare_ref")

    if [[ "$ahead" != "0" ]]; then
      printf '%s %s' "absorbed" "drop-from-queue"
      return
    fi
  fi

  if [[ "$ahead" = "0" ]]; then
    printf '%s %s' "current" "no-action"
    return
  fi

  if [[ "$branch" == codex/* ]]; then
    printf '%s %s' "needs-landing" "prepare-clean-landing"
    return
  fi

  if [[ "$branch" != landing/* ]]; then
    printf '%s %s' "review" "inspect-branch-policy"
    return
  fi

  printf '%s %s' "ready" "run-landing-check"
}

print_record() {
  local path="$1"
  local head="$2"
  local branch="$3"
  local base_ref="$4"
  local location="ok"
  local dirty="clean"
  local divergence
  local ahead
  local behind
  local queue_state
  local queue
  local action

  if [[ -z "$path" ]]; then
    return
  fi

  if [[ "$path" != "$repo_root" && "$path" != "$allowed_prefix"* ]]; then
    location="outside-.worktrees"
    outside_worktrees_count=$((outside_worktrees_count + 1))
    violations=$((violations + 1))
  fi

  if [[ -n "$(git -C "$path" status --porcelain)" ]]; then
    dirty="dirty"
  fi

  divergence="$(print_divergence "$branch" "$head" "$base_ref")"
  ahead="${divergence%% *}"
  behind="${divergence##* }"
  queue_state="$(print_queue_state "$dirty" "$branch" "$head" "$base_ref" "$ahead" "$behind")"
  queue="${queue_state%% *}"
  action="${queue_state##* }"

  total_count=$((total_count + 1))
  case "$queue" in
    current) current_count=$((current_count + 1)) ;;
    dirty) dirty_count=$((dirty_count + 1)) ;;
    stale) stale_count=$((stale_count + 1)) ;;
    absorbed) absorbed_count=$((absorbed_count + 1)) ;;
    behind-main) behind_main_count=$((behind_main_count + 1)) ;;
    needs-landing) needs_landing_count=$((needs_landing_count + 1)) ;;
    ready) ready_count=$((ready_count + 1)) ;;
    unknown) unknown_count=$((unknown_count + 1)) ;;
    review) review_count=$((review_count + 1)) ;;
  esac

  if (( summary_only == 0 )); then
    printf '%-8s %-12s %-36s %-21s %-12s %-40s %-12s %-6s %-6s %s\n' \
      "$dirty" "$queue" "$action" "$location" "${head:0:8}" "$branch" "$base_ref" "$ahead" "$behind" "$path"
  fi
}

base_ref="$(default_base_ref)"

if (( summary_only == 0 )); then
  printf '%-8s %-12s %-36s %-21s %-12s %-40s %-12s %-6s %-6s %s\n' "status" "queue" "action" "location" "head" "branch" "base" "ahead" "behind" "path"
  printf '%-8s %-12s %-36s %-21s %-12s %-40s %-12s %-6s %-6s %s\n' "------" "-----" "------" "--------" "----" "------" "----" "-----" "------" "----"
fi

path=""
head=""
branch="(unknown)"

while IFS= read -r line || [[ -n "$line" ]]; do
  case "$line" in
    worktree\ *)
      print_record "$path" "$head" "$branch" "$base_ref"
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

print_record "$path" "$head" "$branch" "$base_ref"

if (( summary_only == 1 )); then
  printf 'worktree-audit-summary=pass\n'
  printf 'total=%s\n' "$total_count"
  printf 'current=%s\n' "$current_count"
  printf 'dirty=%s\n' "$dirty_count"
  printf 'stale=%s\n' "$stale_count"
  printf 'absorbed=%s\n' "$absorbed_count"
  printf 'behind-main=%s\n' "$behind_main_count"
  printf 'needs-landing=%s\n' "$needs_landing_count"
  printf 'ready=%s\n' "$ready_count"
  printf 'unknown=%s\n' "$unknown_count"
  printf 'review=%s\n' "$review_count"
  printf 'outside-worktrees=%s\n' "$outside_worktrees_count"
fi

if (( violations > 0 )); then
  echo
  echo "error: found $violations linked worktree(s) outside .worktrees/" >&2
  exit 1
fi
