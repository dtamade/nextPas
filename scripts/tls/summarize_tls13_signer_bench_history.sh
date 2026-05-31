#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PATTERN="${FAFAFA_TLS13_SIGN_BENCH_HISTORY_GLOB:-test-reports/wave_b_tls13_sign_bench_*.log}"
OUT_FILE="${FAFAFA_TLS13_SIGN_BENCH_HISTORY_OUT:-}"
LIMIT="${FAFAFA_TLS13_SIGN_BENCH_HISTORY_LIMIT:-20}"

if [[ ! "$LIMIT" =~ ^[0-9]+$ ]] || [[ "$LIMIT" -le 0 ]]; then
  echo "[history] invalid FAFAFA_TLS13_SIGN_BENCH_HISTORY_LIMIT: $LIMIT" >&2
  exit 2
fi

cd "$ROOT_DIR"

mapfile -t logs < <(ls -1t $PATTERN 2>/dev/null | head -n "$LIMIT" || true)

if [[ ${#logs[@]} -eq 0 ]]; then
  echo "[history] no logs matched: $PATTERN" >&2
  exit 1
fi

build_report() {
  local generated_at
  generated_at="$(date '+%Y-%m-%d %H:%M:%S %z')"

  echo "# TLS13 Signer Bench History"
  echo
  echo "- generated_at: $generated_at"
  echo "- root: $ROOT_DIR"
  echo "- pattern: $PATTERN"
  echo "- count: ${#logs[@]}"
  echo
  echo "| log | scheme | iterations | warmup | CRT_avg_ms | D_avg_ms | Speedup_D_over_CRT |"
  echo "|-----|--------|------------|--------|------------|----------|---------------------|"

  for log in "${logs[@]}"; do
    local scheme iterations warmup crt dms speed
    scheme=$(grep -E '^BENCH_SCHEME=' "$log" | tail -1 | cut -d '=' -f2 || true)
    iterations=$(grep -E '^BENCH_ITERATIONS=' "$log" | tail -1 | cut -d '=' -f2 || true)
    warmup=$(grep -E '^BENCH_WARMUP=' "$log" | tail -1 | cut -d '=' -f2 || true)
    crt=$(grep -E '^CRT_avg_ms=' "$log" | tail -1 | cut -d '=' -f2 || true)
    dms=$(grep -E '^D_avg_ms=' "$log" | tail -1 | cut -d '=' -f2 || true)
    speed=$(grep -E '^Speedup_D_over_CRT=' "$log" | tail -1 | cut -d '=' -f2 || true)

    scheme="${scheme:-n/a}"
    iterations="${iterations:-n/a}"
    warmup="${warmup:-n/a}"
    crt="${crt:-n/a}"
    dms="${dms:-n/a}"
    speed="${speed:-n/a}"

    printf '| `%s` | `%s` | `%s` | `%s` | `%s` | `%s` | `%s` |\n' \
      "$log" "$scheme" "$iterations" "$warmup" "$crt" "$dms" "$speed"
  done
}

if [[ -n "$OUT_FILE" ]]; then
  mkdir -p "$(dirname "$OUT_FILE")"
  build_report > "$OUT_FILE"
  echo "[history] wrote: $OUT_FILE" >&2
fi

build_report
