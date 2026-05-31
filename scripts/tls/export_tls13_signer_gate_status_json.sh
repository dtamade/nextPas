#!/usr/bin/env bash

set -euo pipefail

RUN_ID="$(date +%Y%m%d_%H%M%S)"
OUTPUT_JSON=""
SUMMARY_FILE=""
SNAPSHOT_FILE=""
BENCH_JSON_FILE=""
STRICT=false

usage() {
  cat <<'USAGE'
TLS13 Signer Gate Status Export

用途：
  导出 TLS13 signer gate 当前状态为 JSON，供 CI 看板/告警消费。

用法：
  scripts/export_tls13_signer_gate_status_json.sh [options]

选项：
  --run-id ID         指定 run_id
  --output FILE       输出 JSON 路径
  --summary FILE      指定 gate summary（默认自动取最新）
  --snapshot FILE     指定 snapshot（默认自动取最新）
  --bench-json FILE   指定 bench json（默认自动取最新）
  --strict            overall_state 非 HEALTHY 返回非 0
  --help              显示帮助
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --run-id)
      RUN_ID="$2"
      shift 2
      ;;
    --output)
      OUTPUT_JSON="$2"
      shift 2
      ;;
    --summary)
      SUMMARY_FILE="$2"
      shift 2
      ;;
    --snapshot)
      SNAPSHOT_FILE="$2"
      shift 2
      ;;
    --bench-json)
      BENCH_JSON_FILE="$2"
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

if [[ -z "$OUTPUT_JSON" ]]; then
  OUTPUT_JSON="test-reports/tls13_signer_gate_status_${RUN_ID}.json"
fi

mkdir -p "$(dirname "$OUTPUT_JSON")"

if [[ -z "$SUMMARY_FILE" ]]; then
  SUMMARY_FILE="$(ls -1t test-reports/wave_b_ci_gate_summary_tls13_signer_*.md 2>/dev/null | head -1 || true)"
fi

if [[ -z "$SNAPSHOT_FILE" ]]; then
  SNAPSHOT_FILE="$(ls -1t test-reports/tls13_signer_gate_snapshot_*.md 2>/dev/null | head -1 || true)"
fi

if [[ -z "$BENCH_JSON_FILE" ]]; then
  BENCH_JSON_FILE="$(ls -1t test-reports/wave_b_tls13_signer_*.json 2>/dev/null | head -1 || true)"
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

extract_snapshot_state() {
  local file="$1"
  if [[ -z "$file" || ! -f "$file" ]]; then
    echo "MISSING"
    return 0
  fi
  local value
  value="$(rg -o "snapshot_state:[[:space:]]*\*\*[A-Z_]+\*\*" "$file" | head -1 | sed -E 's/.*\*\*([A-Z_]+)\*\*/\1/' || true)"
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
snapshot_state="$(extract_snapshot_state "$SNAPSHOT_FILE")"

overall_state="HEALTHY"
if [[ "$summary_overall" != "PASS" || "$purity_status" != "PASS" || "$bench_status" != "PASS" || "$snapshot_state" != "GREEN" ]]; then
  overall_state="ATTENTION"
fi
if [[ "$bench_speedup" == "n/a" ]]; then
  overall_state="ATTENTION"
fi

cat > "$OUTPUT_JSON" <<JSON
{
  "run_id": "$RUN_ID",
  "generated_at": "$(date '+%Y-%m-%d %H:%M:%S %z')",
  "overall_state": "$overall_state",
  "summary_overall": "$summary_overall",
  "snapshot_state": "$snapshot_state",
  "purity_status": "$purity_status",
  "bench_status": "$bench_status",
  "bench": {
    "scheme": "$bench_scheme",
    "iterations": "$bench_iterations",
    "warmup": "$bench_warmup",
    "crt_avg_ms": "$bench_crt_avg",
    "d_avg_ms": "$bench_d_avg",
    "speedup_d_over_crt": "$bench_speedup"
  },
  "evidence": {
    "summary": "${SUMMARY_FILE:-}",
    "snapshot": "${SNAPSHOT_FILE:-}",
    "bench_json": "${BENCH_JSON_FILE:-}"
  }
}
JSON

echo "[INFO] overall_state=$overall_state"
echo "[PASS] status json generated: $OUTPUT_JSON"

echo "TLS13_SIGNER_STATUS overall=$overall_state summary=$summary_overall snapshot=$snapshot_state purity=$purity_status bench=$bench_status speedup=$bench_speedup"

if [[ "$STRICT" == "true" && "$overall_state" != "HEALTHY" ]]; then
  exit 1
fi

exit 0
