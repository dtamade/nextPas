#!/usr/bin/env bash
set -euo pipefail

base_ref=""
allow_paths=()

usage() {
  cat >&2 <<'EOF'
usage: scripts/landing-worktree-report.sh [--base REF] --allow-path PREFIX [--allow-path PREFIX...]

Reports landing/* worktree queue state. This is read-only: it prints cleanup or
refresh recommendations but never removes worktrees or branches.
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

repo_root="$(git worktree list --porcelain | awk '
  /^worktree / && root == "" { root = substr($0, 10) }
  END { print root }
')"

if [[ -z "$repo_root" ]]; then
  echo "error: unable to detect repository root from git worktree list" >&2
  exit 2
fi

repo_root="$(CDPATH= cd -- "$repo_root" && pwd -P)"

default_base_ref() {
  if git -C "$repo_root" show-ref --verify --quiet refs/heads/main; then
    printf 'main'
    return
  fi

  if git -C "$repo_root" show-ref --verify --quiet refs/heads/master; then
    printf 'master'
    return
  fi

  echo "error: unable to detect default base ref; pass --base" >&2
  exit 2
}

if [[ -z "$base_ref" ]]; then
  base_ref="$(default_base_ref)"
fi

if ! git -C "$repo_root" rev-parse --verify --quiet "$base_ref^{commit}" >/dev/null; then
  echo "error: base ref does not resolve to a commit: $base_ref" >&2
  exit 2
fi

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

classify_candidate() {
  local worktree_path="$1"
  local branch="$2"
  local counts
  local behind
  local ahead
  local dirty_files
  local dirty_generated_files
  local dirty_packaging_files
  local changed_files
  local historical_changed_files
  local path_unsafe=0
  local changed_path
  local candidate_head
  local state
  local action

  counts="$(git -C "$worktree_path" rev-list --left-right --count "$base_ref...HEAD")"
  behind="${counts%%[[:space:]]*}"
  ahead="${counts##*[[:space:]]}"

  dirty_files="$(git -C "$worktree_path" status --porcelain --untracked-files=all | awk '{ print $2 }')"
  dirty_packaging_files="$(git -C "$worktree_path" status --porcelain --untracked-files=all | awk '$1 ~ /^D/ && $2 ~ /^build\// { print $2 }')"
  if [[ -n "$dirty_packaging_files" ]]; then
    printf 'candidate\t%s\tdirty-packaging\tinspect-packaging-deletions\t%s\t%s\t%s\n' \
      "$branch" "$ahead" "$behind" "$worktree_path"
    return
  fi

  dirty_generated_files="$(printf '%s\n' "$dirty_files" | grep -E '(^tests/tooling/.*\.log$|^core/tests/.*/test_.*/.*\.log$)' || true)"
  if [[ -n "$dirty_generated_files" ]]; then
    printf 'candidate\t%s\tdirty-generated-artifacts\trun-clean-artifacts-or-remove-generated-files\t%s\t%s\t%s\n' \
      "$branch" "$ahead" "$behind" "$worktree_path"
    return
  fi

  if [[ -n "$dirty_files" ]]; then
    printf 'candidate\t%s\tdirty\tinspect-or-stash-uncommitted-work\t%s\t%s\t%s\n' \
      "$branch" "$ahead" "$behind" "$worktree_path"
    return
  fi

  if [[ "$behind" != "0" ]]; then
    if [[ "$ahead" = "0" ]]; then
      printf 'candidate\t%s\tneeds-replay\treplay-or-drop-empty-candidate\t%s\t%s\t%s\n' \
        "$branch" "$ahead" "$behind" "$worktree_path"
      return
    fi

    if git -C "$worktree_path" cherry "$base_ref" HEAD | grep -q '^+'; then
      state="stale"
      action="replay-on-latest-base"
    else
      state="absorbed"
      action="drop-from-queue"
    fi
    printf 'candidate\t%s\t%s\t%s\t%s\t%s\t%s\n' \
      "$branch" "$state" "$action" "$ahead" "$behind" "$worktree_path"
    return
  fi

  candidate_head="$(git -C "$worktree_path" rev-parse HEAD)"
  if git -C "$repo_root" merge-base --is-ancestor "$candidate_head" "$base_ref"; then
    printf 'candidate\t%s\tabsorbed\tdrop-from-queue\t%s\t%s\t%s\n' \
      "$branch" "$ahead" "$behind" "$worktree_path"
    return
  fi

  changed_files="$(git -C "$worktree_path" diff --no-renames --name-only "$base_ref...HEAD")"
  historical_changed_files="$(git -C "$worktree_path" log --name-only --format= "$base_ref..HEAD" | sed '/^$/d' | sort -u)"

  while IFS= read -r changed_path || [[ -n "$changed_path" ]]; do
    if [[ -n "$changed_path" ]] && ! path_allowed "$changed_path"; then
      path_unsafe=1
    fi
  done <<< "$changed_files"

  while IFS= read -r changed_path || [[ -n "$changed_path" ]]; do
    if [[ -n "$changed_path" ]] && ! path_allowed "$changed_path"; then
      path_unsafe=1
    fi
  done <<< "$historical_changed_files"

  if [[ "$path_unsafe" = "1" ]]; then
    printf 'candidate\t%s\tpath-unsafe\tsplit-or-replay-allowed-paths-only\t%s\t%s\t%s\n' \
      "$branch" "$ahead" "$behind" "$worktree_path"
    return
  fi

  printf 'candidate\t%s\tready\trun-landing-check\t%s\t%s\t%s\n' \
    "$branch" "$ahead" "$behind" "$worktree_path"
}

report_rows="$(
  path=""
  branch=""
  while IFS= read -r line || [[ -n "$line" ]]; do
    case "$line" in
      worktree\ *)
        path="${line#worktree }"
        branch=""
        ;;
      branch\ refs/heads/landing/*)
        branch="${line#branch refs/heads/}"
        classify_candidate "$path" "$branch"
        ;;
      branch\ refs/heads/*)
        branch="${line#branch refs/heads/}"
        ;;
    esac
  done < <(git -C "$repo_root" worktree list --porcelain)
)"

count_state() {
  local state="$1"
  if [[ -z "$report_rows" ]]; then
    printf '0'
    return
  fi
  awk -F '\t' -v state="$state" '$1 == "candidate" && $3 == state { count++ } END { print count + 0 }' <<< "$report_rows"
}

count_dirty() {
  if [[ -z "$report_rows" ]]; then
    printf '0'
    return
  fi
  awk -F '\t' '$1 == "candidate" && ($3 == "dirty" || $3 == "dirty-generated-artifacts" || $3 == "dirty-packaging") { count++ } END { print count + 0 }' <<< "$report_rows"
}

total_count() {
  if [[ -z "$report_rows" ]]; then
    printf '0'
    return
  fi
  awk -F '\t' '$1 == "candidate" { count++ } END { print count + 0 }' <<< "$report_rows"
}

printf 'landing-worktree-report=pass\n'
printf 'base=%s\n' "$base_ref"
printf 'readonly=true\n'
printf 'columns=kind branch state action ahead behind worktree\n'
if [[ -n "$report_rows" ]]; then
  printf '%s\n' "$report_rows"
fi
printf 'summary.absorbed=%s\n' "$(count_state absorbed)"
printf 'summary.stale=%s\n' "$(count_state stale)"
printf 'summary.dirty=%s\n' "$(count_dirty)"
printf 'summary.dirty-generated-artifacts=%s\n' "$(count_state dirty-generated-artifacts)"
printf 'summary.dirty-packaging=%s\n' "$(count_state dirty-packaging)"
printf 'summary.path-unsafe=%s\n' "$(count_state path-unsafe)"
printf 'summary.needs-replay=%s\n' "$(count_state needs-replay)"
printf 'summary.ready=%s\n' "$(count_state ready)"
printf 'summary.total=%s\n' "$(total_count)"
