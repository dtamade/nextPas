#!/usr/bin/env bash

set -euo pipefail

RUN_ID="$(date +%Y%m%d_%H%M%S)"
REPORTS_DIR="test-reports"
OUTPUT_FILE=""
STRICT=false
ARCHIVE_ENABLED="${FAFAFA_TLS13_SIGNER_GATE_ARCHIVE:-1}"
ARCHIVE_PROFILE="${FAFAFA_TLS13_SIGNER_GATE_ARCHIVE_PROFILE:-pr}"
ARCHIVE_ROOT="${FAFAFA_TLS13_SIGNER_GATE_ARCHIVE_ROOT:-artifacts/ci}"

usage() {
  cat <<'USAGE'
TLS13 Signer Gate Bundle

用途：
  一次执行 TLS13 signer gate CI 入口 + snapshot + status json，生成汇总报告。

用法：
  scripts/run_tls13_signer_gate_bundle.sh [options]

选项：
  --run-id ID         指定 run_id
  --reports-dir DIR   报告目录（默认 test-reports）
  --output FILE       输出汇总报告路径
  --strict            任一步骤失败返回非 0
  --help              显示帮助
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --run-id)
      RUN_ID="$2"
      shift 2
      ;;
    --reports-dir)
      REPORTS_DIR="$2"
      shift 2
      ;;
    --output)
      OUTPUT_FILE="$2"
      shift 2
      ;;
    --strict)
      STRICT=true
      shift
      ;;
    --help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ -z "$OUTPUT_FILE" ]]; then
  OUTPUT_FILE="$REPORTS_DIR/tls13_signer_gate_bundle_${RUN_ID}.md"
fi

if [[ "$ARCHIVE_ENABLED" != "0" && "$ARCHIVE_ENABLED" != "1" ]]; then
  echo "invalid FAFAFA_TLS13_SIGNER_GATE_ARCHIVE: $ARCHIVE_ENABLED (expect 0|1)" >&2
  exit 2
fi

archive_run_id="tls13_signer_${RUN_ID}"

mkdir -p "$REPORTS_DIR"

ci_summary="$REPORTS_DIR/wave_b_ci_gate_summary_tls13_signer_${RUN_ID}.md"
ci_bench_json="$REPORTS_DIR/wave_b_tls13_signer_${RUN_ID}.json"
ci_history="$REPORTS_DIR/tls13_signer_bench_history_${RUN_ID}.md"
snapshot_report="$REPORTS_DIR/tls13_signer_gate_snapshot_${RUN_ID}.md"
status_json="$REPORTS_DIR/tls13_signer_gate_status_${RUN_ID}.json"

ci_log="$REPORTS_DIR/tls13_signer_gate_ci_${RUN_ID}.log"
snapshot_log="$REPORTS_DIR/tls13_signer_gate_snapshot_${RUN_ID}.log"
status_log="$REPORTS_DIR/tls13_signer_gate_status_${RUN_ID}.log"
archive_log="$REPORTS_DIR/tls13_signer_gate_archive_${RUN_ID}.log"

shell_join() {
  local parts=()
  local part
  for part in "$@"; do
    parts+=("$(printf '%q' "$part")")
  done
  local IFS=' '
  echo "${parts[*]}"
}

run_step() {
  local step_name="$1"
  local log="$2"
  local cmd_desc="$3"
  shift 3

  echo "[tls13-bundle] [$step_name] $cmd_desc" >&2

  set +e
  "$@" > "$log" 2>&1
  local ec=$?
  set -e

  echo "[tls13-bundle] [$step_name] exit=$ec log=$log" >&2
  echo "$ec"
}

ci_cmd_words=(
  env
  "FAFAFA_TLS13_SIGNER_GATE_RUN_ID=$RUN_ID"
  "FAFAFA_TLS13_SIGNER_GATE_OUTPUT_DIR=$REPORTS_DIR"
  "FAFAFA_TLS13_SIGNER_GATE_ARCHIVE=0"
  bash
  scripts/run_tls13_signer_gate_ci.sh
)
ci_exit=$(run_step \
  "signer_gate_ci" \
  "$ci_log" \
  "$(shell_join "${ci_cmd_words[@]}")" \
  "${ci_cmd_words[@]}")

snapshot_cmd_words=(
  bash
  scripts/generate_tls13_signer_gate_snapshot.sh
  --run-id "$RUN_ID"
  --output "$snapshot_report"
  --summary "$ci_summary"
  --bench-json "$ci_bench_json"
  --history "$ci_history"
)
snapshot_exit=$(run_step \
  "snapshot" \
  "$snapshot_log" \
  "$(shell_join "${snapshot_cmd_words[@]}")" \
  "${snapshot_cmd_words[@]}")

status_cmd_words=(
  bash
  scripts/export_tls13_signer_gate_status_json.sh
  --run-id "$RUN_ID"
  --output "$status_json"
  --summary "$ci_summary"
  --snapshot "$snapshot_report"
  --bench-json "$ci_bench_json"
)
status_exit=$(run_step \
  "status_json" \
  "$status_log" \
  "$(shell_join "${status_cmd_words[@]}")" \
  "${status_cmd_words[@]}")

archive_exit="SKIP"
archive_output="(disabled)"
archive_log_ref="(disabled)"
if [[ "$ARCHIVE_ENABLED" == "1" ]]; then
  archive_output="$ARCHIVE_ROOT/$archive_run_id"
  archive_log_ref="$archive_log"
  archive_cmd_words=(
    bash
    scripts/archive_ci_artifacts_draft.sh
    --profile "$ARCHIVE_PROFILE"
    --run-id "$archive_run_id"
    --output-root "$ARCHIVE_ROOT"
  )
  archive_exit=$(run_step \
    "archive" \
    "$archive_log" \
    "$(shell_join "${archive_cmd_words[@]}")" \
    "${archive_cmd_words[@]}")
fi

overall="PASS"
if [[ "$ci_exit" != "0" || "$snapshot_exit" != "0" || "$status_exit" != "0" ]]; then
  overall="FAIL"
fi

if [[ "$archive_exit" != "0" && "$archive_exit" != "SKIP" ]]; then
  overall="FAIL"
fi

overall_state="UNKNOWN"
if [[ -f "$status_json" ]]; then
  overall_state="$(python3 - "$status_json" <<'PY'
import json
import sys
p = sys.argv[1]
with open(p, 'r', encoding='utf-8') as f:
    d = json.load(f)
print(d.get('overall_state', 'UNKNOWN'))
PY
)"
fi

if [[ "$overall_state" != "HEALTHY" ]]; then
  overall="FAIL"
fi

{
  echo "# TLS13 Signer Gate Bundle"
  echo
  echo "- run_id: $RUN_ID"
  echo "- generated_at: $(date '+%Y-%m-%d %H:%M:%S %z')"
  echo "- overall: **$overall**"
  echo "- overall_state: **$overall_state**"
  echo
  echo "## Step Matrix"
  echo
  echo "| step | exit | output | log |"
  echo "|------|------|--------|-----|"
  echo "| signer_gate_ci | $ci_exit | $ci_summary | $ci_log |"
  echo "| snapshot | $snapshot_exit | $snapshot_report | $snapshot_log |"
  echo "| status_json | $status_exit | $status_json | $status_log |"
  echo "| archive | $archive_exit | $archive_output | $archive_log_ref |"
  echo
  echo "## Evidence"
  echo
  echo "- bench_json: $ci_bench_json"
  echo "- history: $ci_history"
  if [[ "$ARCHIVE_ENABLED" == "1" ]]; then
    echo "- archive_root: $ARCHIVE_ROOT"
    echo "- archive_run_id: $archive_run_id"
  fi
} > "$OUTPUT_FILE"

echo "[INFO] overall=$overall overall_state=$overall_state"
echo "[PASS] bundle report generated: $OUTPUT_FILE"

if [[ "$STRICT" == "true" && "$overall" != "PASS" ]]; then
  exit 1
fi

exit 0
