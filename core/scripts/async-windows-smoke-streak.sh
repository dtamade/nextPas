#!/usr/bin/env bash
# async-windows-smoke-streak.sh
#
# Inspect recent GitHub Actions runs for the async Windows native smoke step.
# Prints success/failure streak and whether fail-closed promotion is ready.
#
# Usage (repo root or core/):
#   bash core/scripts/async-windows-smoke-streak.sh
#   bash core/scripts/async-windows-smoke-streak.sh --limit 20
#
# Env:
#   ASYNC_WINDOWS_STREAK_NEED=N   # consecutive successes required (default 14
#                                 # ≈ 2 weeks of daily main pushes; override for
#                                 # local experiments)
#   GH_REPO=owner/repo            # optional; default from `gh repo view`
#
# Exit:
#   0 always when analysis completes (including promote-ready=no)
#   2 on usage / tool errors
#
# truth: observational only — does not flip CI.

set -euo pipefail

LIMIT=20
NEED="${ASYNC_WINDOWS_STREAK_NEED:-14}"
STEP_NAME='Async Windows native smoke'

while [[ $# -gt 0 ]]; do
  case "$1" in
    --limit)
      LIMIT="${2:?}"
      shift 2
      ;;
    -h|--help)
      sed -n '2,25p' "$0"
      exit 0
      ;;
    *)
      echo "error: unknown arg: $1" >&2
      exit 2
      ;;
  esac
done

if ! command -v gh >/dev/null 2>&1; then
  echo "error: gh CLI required" >&2
  exit 2
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "error: jq required" >&2
  exit 2
fi

REPO="${GH_REPO:-}"
if [[ -z "$REPO" ]]; then
  REPO="$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || true)"
fi
if [[ -z "$REPO" ]]; then
  # Fallback: parse origin remote
  origin_url="$(git remote get-url origin 2>/dev/null || true)"
  if [[ "$origin_url" =~ github.com[:/]([^/]+)/([^/.]+) ]]; then
    REPO="${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
  fi
fi
if [[ -z "$REPO" ]]; then
  echo "error: cannot resolve repo (set GH_REPO=owner/repo)" >&2
  exit 2
fi
echo "=== async-windows-smoke-streak ==="
echo "repo=$REPO limit=$LIMIT need=$NEED step~='$STEP_NAME'"
echo "truth=observational; not a CI gate flipper"
echo

# Recent workflow runs for core-ci on main
mapfile -t RUN_IDS < <(gh run list \
  --repo "$REPO" \
  --workflow core-ci.yml \
  --branch main \
  --limit "$LIMIT" \
  --json databaseId,conclusion,status,displayTitle,createdAt \
  --jq '.[] | select(.status=="completed") | .databaseId' 2>/dev/null || true)

if [[ ${#RUN_IDS[@]} -eq 0 ]]; then
  echo "no completed core-ci runs found"
  echo "promote-ready=no reason=no-runs"
  exit 0
fi

success_streak=0
any_seen=0
results=()

for rid in "${RUN_IDS[@]}"; do
  # Find test-windows-runtime job steps matching async smoke
  json="$(gh run view "$rid" --repo "$REPO" --json jobs,displayTitle,createdAt,conclusion 2>/dev/null || true)"
  if [[ -z "$json" ]]; then
    results+=("$rid missing")
    continue
  fi
  title="$(echo "$json" | jq -r '.displayTitle // "?"')"
  created="$(echo "$json" | jq -r '.createdAt // "?"')"
  step_conc="$(echo "$json" | jq -r --arg s "$STEP_NAME" '
    [.jobs[]?
      | select(.name=="test-windows-runtime")
      | .steps[]?
      | select(.name|test("Async Windows native smoke";"i"))
      | .conclusion] | first // "absent"
  ')"
  job_conc="$(echo "$json" | jq -r '
    [.jobs[]? | select(.name=="test-windows-runtime") | .conclusion] | first // "absent"
  ')"

  any_seen=1
  line="$rid step=$step_conc job=$job_conc created=$created title=$title"
  results+=("$line")
  printf '%s\n' "$line"
done

echo
echo "--- streak (most recent first; only step==success counts) ---"
streak=0
for line in "${results[@]}"; do
  if [[ "$line" == *"step=success"* ]]; then
    streak=$((streak + 1))
  else
    # absent/skipped/failure breaks consecutive success
    break
  fi
done
success_streak=$streak

echo "consecutive_step_success=$success_streak need=$NEED"
if [[ "$success_streak" -ge "$NEED" ]]; then
  echo "promote-ready=yes"
  echo "action: remove continue-on-error on async-windows step; set STRICT on Windows host"
else
  echo "promote-ready=no"
  if [[ "$any_seen" -eq 0 ]]; then
    echo "reason=no-step-observations"
  else
    echo "reason=streak<$NEED"
  fi
fi

exit 0
