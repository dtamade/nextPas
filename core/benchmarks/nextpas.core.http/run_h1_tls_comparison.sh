#!/usr/bin/env bash
# Compare nextPas bench_http_server --tls vs Go peer HTTPS H1 (C-H1).
# Shape mirrors H1 cleartext KPI: requests×threads×workload, epoll, runs≥3.
# Gates: median req/s ratio ≥0.80; median p99 ratio ≤2.0 (nextPas/Go).
# Does not claim package by itself — see CLAIM.md after product Yes + Met table.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CORE_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
BUILD_DIR="${CORE_ROOT}/build/projects/nextpas.core.http/h1_tls_comparison"
REQUESTS=20000
THREADS=4
WORKLOAD="no_url"
RUNS=1
OUTPUT_PATH=""

usage() {
  cat <<'EOF'
usage: run_h1_tls_comparison.sh [--requests N] [--threads N]
                                [--workload no_url|url_path|adapter_no_url|response_1k]
                                [--runs N] [--output PATH]

HTTPS ALPN http/1.1 keep-alive peer multi-run (nextPas epoll + Go).
Prints median req/s / p99 and gates (≥0.80 RPS, ≤2.0 p99 ratio).
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --requests) REQUESTS="${2:?}"; shift 2 ;;
    --threads) THREADS="${2:?}"; shift 2 ;;
    --workload) WORKLOAD="${2:?}"; shift 2 ;;
    --runs) RUNS="${2:?}"; shift 2 ;;
    --output) OUTPUT_PATH="${2:?}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

if ! [[ "${RUNS}" =~ ^[1-9][0-9]*$ ]]; then
  echo "--runs must be a positive integer" >&2
  exit 2
fi
if ! [[ "${REQUESTS}" =~ ^[1-9][0-9]*$ && "${THREADS}" =~ ^[1-9][0-9]*$ ]]; then
  echo "--requests and --threads must be positive integers" >&2
  exit 2
fi
case "${WORKLOAD}" in
  no_url|url_path|adapter_no_url|response_1k) ;;
  *) echo "--workload invalid" >&2; exit 2 ;;
esac

mkdir -p "${BUILD_DIR}"

echo "=== build nextPas bench_http_server ==="
make -C "${SCRIPT_DIR}/bench_server" build

echo "=== build Go h1 peer ==="
go build -o "${BUILD_DIR}/bench_http_server_go" "${SCRIPT_DIR}/compare_go/main.go"

NEXTPAS_BIN="${CORE_ROOT}/build/projects/nextpas.core.http/bench_server/bench_http_server"
GO_BIN="${BUILD_DIR}/bench_http_server_go"
SHAPE=(--requests "${REQUESTS}" --threads "${THREADS}" --workload "${WORKLOAD}")

RESULTS_TMP="$(mktemp "${BUILD_DIR}/h1-tls-comparison-results.XXXXXX")"
trap 'rm -f "${RESULTS_TMP}"' EXIT
: > "${RESULTS_TMP}"

run_one() {
  local impl="$1"
  local log="$2"
  shift 2
  "$@" >"${log}" 2>&1 || {
    echo "run failed impl=${impl}" >&2
    cat "${log}" >&2
    exit 1
  }
  cat "${log}"
  local reqs p99 completed
  reqs="$(sed -nE 's/^req\/s=([0-9]+)$/\1/p' "${log}" | tail -n 1)"
  p99="$(sed -nE 's/^p99_ns=([0-9]+)$/\1/p' "${log}" | tail -n 1)"
  completed="$(sed -nE 's/^completed=([0-9]+)$/\1/p' "${log}" | tail -n 1)"
  if [[ -z "${reqs}" || -z "${p99}" || -z "${completed}" ]]; then
    echo "parse failed impl=${impl}" >&2
    cat "${log}" >&2
    exit 1
  fi
  if [[ "${completed}" -lt "${REQUESTS}" ]]; then
    echo "incomplete impl=${impl} completed=${completed} requests=${REQUESTS}" >&2
    exit 1
  fi
  printf '%s %s %s\n' "${impl}" "${reqs}" "${p99}" >> "${RESULTS_TMP}"
}

run_all() {
  echo "comparison=http.server.h1.tls.comparison"
  echo "summary_shape=${REQUESTS}x${THREADS}x${WORKLOAD}"
  echo "transport=tls-alpn-http1.1"
  echo "runs=${RUNS}"
  echo "date=$(date -Iseconds)"
  echo

  local i
  for i in $(seq 1 "${RUNS}"); do
    echo "run=${i}"
    echo "section=nextpas"
    run_one nextpas "${BUILD_DIR}/nextpas.run${i}.log" \
      "${NEXTPAS_BIN}" --backend epoll --tls "${SHAPE[@]}"
    echo
    echo "section=go"
    run_one go "${BUILD_DIR}/go.run${i}.log" \
      "${GO_BIN}" --tls "${SHAPE[@]}"
    echo
  done

  awk '
    function median(a, n,    i, j, t) {
      for (i = 1; i <= n; i++)
        for (j = i + 1; j <= n; j++)
          if (a[j] < a[i]) { t = a[i]; a[i] = a[j]; a[j] = t }
      if (n % 2) return a[(n + 1) / 2]
      return (a[n / 2] + a[n / 2 + 1]) / 2
    }
    {
      impl = $1
      req[impl, ++n[impl]] = $2 + 0
      p99[impl, n[impl]] = $3 + 0
    }
    END {
      for (impl in n) {
        m = n[impl]
        for (i = 1; i <= m; i++) {
          r[i] = req[impl, i]
          p[i] = p99[impl, i]
        }
        med_req[impl] = median(r, m)
        med_p99[impl] = median(p, m)
        printf "summary_impl=%s runs=%d median_req/s=%.0f median_p99_ns=%.0f\n",
          impl, m, med_req[impl], med_p99[impl]
      }
      if (med_req["nextpas"] > 0 && med_req["go"] > 0) {
        ratio = med_req["nextpas"] / med_req["go"]
        p99r = med_p99["nextpas"] / med_p99["go"]
        gate_rps = (ratio >= 0.80) ? "Met" : "NotMet"
        gate_p99 = (p99r <= 2.0) ? "Met" : "NotMet"
        printf "summary_transport=tls-alpn-http1.1\n"
        printf "summary_median_nextpas_req/s=%.0f\n", med_req["nextpas"]
        printf "summary_median_go_req/s=%.0f\n", med_req["go"]
        printf "summary_ratio_nextpas_over_go=%.2f\n", ratio
        printf "summary_median_nextpas_p99_ns=%.0f\n", med_p99["nextpas"]
        printf "summary_median_go_p99_ns=%.0f\n", med_p99["go"]
        printf "summary_p99_ratio_nextpas_over_go=%.2f\n", p99r
        printf "summary_gate_peer_0_80=%s\n", gate_rps
        printf "summary_gate_p99_2_0=%s\n", gate_p99
      }
    }
  ' "${RESULTS_TMP}"
}

if [[ "${OUTPUT_PATH}" == "" ]]; then
  run_all
else
  mkdir -p "$(dirname "${OUTPUT_PATH}")"
  run_all | tee "${OUTPUT_PATH}"
fi