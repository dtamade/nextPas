#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
usage: scripts/report-envelope-check.sh --status Ready|Blocked|Landed REPORT.md

Checks that a controller-facing status report contains the required envelope
fields for queue triage. It reads one report file and does not modify the tree.
EOF
}

status=""
report_path=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --status)
      if [[ $# -lt 2 || -z "$2" ]]; then
        echo "error: --status requires a value" >&2
        usage
        exit 2
      fi
      status="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      if [[ -n "$report_path" ]]; then
        echo "error: unexpected argument: $1" >&2
        usage
        exit 2
      fi
      report_path="$1"
      shift
      ;;
  esac
done

if [[ -z "$status" || -z "$report_path" ]]; then
  usage
  exit 2
fi

if [[ ! -f "$report_path" ]]; then
  echo "error: report file not found: $report_path" >&2
  exit 2
fi

require_field() {
  local field="$1"
  local pattern="$2"

  if ! grep -Eiq "$pattern" "$report_path"; then
    echo "missing required $status field: $field" >&2
    return 1
  fi
}

case "$status" in
  Ready)
    require_field "branch" '(^|[[:space:]])branch[[:space:]/_-]*:'
    require_field "worktree" '(^|[[:space:]])worktree[[:space:]/_-]*:'
    require_field "HEAD" '(^|[[:space:]])HEAD[[:space:]/_-]*:'
    require_field "retained files" 'retained[[:space:]/_-]+files[[:space:]/_-]*:'
    require_field "excluded files" 'excluded[[:space:]/_-]+files[[:space:]/_-]*:'
    require_field "verification" 'verification[[:space:]/_-]*:'
    require_field "landing recommendation" 'landing[[:space:]/_-]+recommendation[[:space:]/_-]*:'
    ;;
  Blocked)
    require_field "blocking condition" 'blocking[[:space:]/_-]+condition[[:space:]/_-]*:'
    require_field "attempted actions" 'attempted[[:space:]/_-]+actions[[:space:]/_-]*:'
    require_field "required owner decision" 'required[[:space:]/_-]+owner[[:space:]/_-]+decision[[:space:]/_-]*:'
    ;;
  Landed)
    require_field "main commit" 'main[[:space:]/_-]+commit[[:space:]/_-]*:'
    require_field "verification" 'verification[[:space:]/_-]*:'
    require_field "equivalent absorption/cleanup state" 'equivalent[[:space:]/_-]+absorption[[:space:]/_-]*cleanup[[:space:]/_-]+state[[:space:]/_-]*:'
    ;;
  *)
    echo "unknown status: $status" >&2
    exit 2
    ;;
esac

printf 'report-envelope=pass\n'
printf 'status=%s\n' "$status"
printf 'report=%s\n' "$report_path"
