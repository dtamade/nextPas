#!/usr/bin/env bash

set -euo pipefail

RUN_ID="$(date +%Y%m%d_%H%M%S)"
OUTPUT_FILE=""
SUMMARY_FILE=""
BENCH_JSON_FILE=""
HISTORY_FILE=""
STRICT=false

usage() {
  cat <<'USAGE'
TLS13 Signer Gate Snapshot

用途：
  生成 TLS13 signer gate 当前状态快照（汇总 gate 状态与关键基准指标）。

用法：
  scripts/generate_tls13_signer_gate_snapshot.sh [options]

选项：
  --run-id ID       指定 run_id
  --output FILE     输出报告路径
  --summary FILE    指定 gate summary（默认自动取最新）
  --bench-json FILE 指定 bench json（默认自动取最新）
  --history FILE    指定历史汇总（默认自动取最新）
  --strict          snapshot_state 非 GREEN 返回非 0
  --help            显示帮助
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --run-id)
      RUN_ID="$2"
      shift 2
      ;;
    --output)
      OUTPUT_FILE="$2"
      shift 2
      ;;
    --summary)
      SUMMARY_FILE="$2"
      shift 2
      ;;
    --bench-json)
      BENCH_JSON_FILE="$2"
      shift 2
      ;;
    --history)
      HISTORY_FILE="$2"
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
  OUTPUT_FILE="test-reports/tls13_signer_gate_snapshot_${RUN_ID}.md"
fi

mkdir -p "$(dirname "$OUTPUT_FILE")"

if [[ -z "$SUMMARY_FILE" ]]; then
  SUMMARY_FILE="$(ls -1t test-reports/wave_b_ci_gate_summary_tls13_signer_*.md 2>/dev/null | head -1 || true)"
fi

if [[ -z "$BENCH_JSON_FILE" ]]; then
  BENCH_JSON_FILE="$(ls -1t test-reports/wave_b_tls13_signer_*.json 2>/dev/null | head -1 || true)"
fi

if [[ -z "$HISTORY_FILE" ]]; then
  HISTORY_FILE="$(ls -1t test-reports/tls13_signer_bench_history_*.md 2>/dev/null | head -1 || true)"
fi

extract_overall_from_summary() {
  local file="$1"
  if [[ -z "$file" || ! -f "$file" ]]; then
    echo "MISSING"
    return 0
  fi
  local value
  value="$(rg -o "Overall Status:[[:space:]]*\*\*[A-Z_]+\*\*" "$file" | head -1 | sed -E 's/.*\*\*([A-Z_]+)\*\*/\1/' || true)"
  echo "${value:-UNKNOWN}"
}

extract_step_status() {
  local file="$1"
  local step_name="$2"
  if [[ -z "$file" || ! -f "$file" ]]; then
    echo "MISSING"
    return 0
  fi
  local value
  value="$(awk -F'|' -v step="$step_name" '
    $2 ~ step {
      s=$4
      gsub(/[`* ]/, "", s)
      print s
      exit
    }
  ' "$file")"
  echo "${value:-UNKNOWN}"
}

bench_scheme="n/a"
bench_iterations="n/a"
bench_warmup="n/a"
bench_crt_avg="n/a"
bench_d_avg="n/a"
bench_speedup="n/a"

if [[ -n "$BENCH_JSON_FILE" && -f "$BENCH_JSON_FILE" ]]; then
  readarray -t parsed < <(python3 - "$BENCH_JSON_FILE" <<'PY'
import json
import sys

path = sys.argv[1]
with open(path, 'r', encoding='utf-8') as f:
    d = json.load(f)

print(d.get('bench_scheme', 'n/a'))
print(d.get('bench_iterations', 'n/a'))
print(d.get('bench_warmup', 'n/a'))
print(d.get('crt_avg_ms', 'n/a'))
print(d.get('d_avg_ms', 'n/a'))
print(d.get('speedup_d_over_crt', 'n/a'))
PY
)
  bench_scheme="${parsed[0]:-n/a}"
  bench_iterations="${parsed[1]:-n/a}"
  bench_warmup="${parsed[2]:-n/a}"
  bench_crt_avg="${parsed[3]:-n/a}"
  bench_d_avg="${parsed[4]:-n/a}"
  bench_speedup="${parsed[5]:-n/a}"
fi

summary_overall="$(extract_overall_from_summary "$SUMMARY_FILE")"
purity_status="$(extract_step_status "$SUMMARY_FILE" "tls13_signer_purity")"
bench_status="$(extract_step_status "$SUMMARY_FILE" "tls13_servercertverify_bench")"

snapshot_state="GREEN"
if [[ "$summary_overall" != "PASS" || "$purity_status" != "PASS" || "$bench_status" != "PASS" ]]; then
  snapshot_state="ATTENTION"
fi

if [[ "$bench_speedup" == "n/a" || "$bench_crt_avg" == "n/a" || "$bench_d_avg" == "n/a" ]]; then
  snapshot_state="ATTENTION"
fi

if [[ -z "$SUMMARY_FILE" || ! -f "$SUMMARY_FILE" ]]; then
  snapshot_state="ATTENTION"
fi

if [[ -z "$BENCH_JSON_FILE" || ! -f "$BENCH_JSON_FILE" ]]; then
  snapshot_state="ATTENTION"
fi

{
  echo "# TLS13 Signer Gate Snapshot"
  echo
  echo "- run_id: $RUN_ID"
  echo "- generated_at: $(date '+%Y-%m-%d %H:%M:%S %z')"
  echo "- snapshot_state: **$snapshot_state**"
  echo
  echo "## Gate Status"
  echo
  echo "| item | value | expected | result |"
  echo "|------|-------|----------|--------|"
  echo "| summary_overall | $summary_overall | PASS | $([[ "$summary_overall" == "PASS" ]] && echo PASS || echo FAIL) |"
  echo "| purity_status | $purity_status | PASS | $([[ "$purity_status" == "PASS" ]] && echo PASS || echo FAIL) |"
  echo "| bench_status | $bench_status | PASS | $([[ "$bench_status" == "PASS" ]] && echo PASS || echo FAIL) |"
  echo
  echo "## Bench Metrics"
  echo
  echo "- scheme: $bench_scheme"
  echo "- iterations: $bench_iterations"
  echo "- warmup: $bench_warmup"
  echo "- CRT_avg_ms: $bench_crt_avg"
  echo "- D_avg_ms: $bench_d_avg"
  echo "- Speedup_D_over_CRT: $bench_speedup"
  echo
  echo "## Evidence"
  echo
  echo "- summary: ${SUMMARY_FILE:-<none>}"
  echo "- bench_json: ${BENCH_JSON_FILE:-<none>}"
  echo "- history: ${HISTORY_FILE:-<none>}"
} > "$OUTPUT_FILE"

echo "[INFO] snapshot_state=$snapshot_state"
echo "[PASS] report generated: $OUTPUT_FILE"

if [[ "$STRICT" == "true" && "$snapshot_state" != "GREEN" ]]; then
  exit 1
fi

exit 0
