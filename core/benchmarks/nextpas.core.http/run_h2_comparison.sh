#!/usr/bin/env bash
# Compare nextPas bench_h2_server vs Go h2c peer (same multiplex shape).
# Does not claim package scale-ready; emits ratio for H2 KPI draft peer gate.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CORE_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
BUILD_DIR="${CORE_ROOT}/build/projects/nextpas.core.http/h2_comparison"
CONNECTIONS=8
STREAMS=16
BATCHES=100
OUTPUT_PATH=""

usage() {
  cat <<'EOF'
usage: run_h2_comparison.sh [--connections N] [--streams N] [--batches N] [--output PATH]

Runs nextPas bench_h2_server (epoll multiplex) and Go compare_h2 peer with the
same shape. Prints summary lines and nextPas/Go req/s ratio.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --connections) CONNECTIONS="${2:?}"; shift 2 ;;
    --streams) STREAMS="${2:?}"; shift 2 ;;
    --batches) BATCHES="${2:?}"; shift 2 ;;
    --output) OUTPUT_PATH="${2:?}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

mkdir -p "${BUILD_DIR}"

echo "=== build nextPas bench_h2_server ==="
make -C "${SCRIPT_DIR}/bench_h2_server" build

echo "=== build Go h2 peer ==="
(
  cd "${SCRIPT_DIR}/compare_h2"
  go mod download
  go build -o "${BUILD_DIR}/bench_h2_server_go" .
)

NEXTPAS_BIN="${CORE_ROOT}/build/projects/nextpas.core.http/bench_h2_server/bench_h2_server"
GO_BIN="${BUILD_DIR}/bench_h2_server_go"
SHAPE=(--connections "${CONNECTIONS}" --streams "${STREAMS}" --batches "${BATCHES}")

run_capture() {
  local label="$1"
  local bin="$2"
  shift 2
  local log="${BUILD_DIR}/${label}.log"
  echo "=== run ${label} ===" >&2
  "${bin}" "$@" | tee "${log}"
  # emit last-line markers for parsers
  grep -E '^(req/s|completed|failed|stable|connections|streams_per_batch|batches_per_conn|impl|operation)=' "${log}" || true
}

NEXTPAS_LOG="${BUILD_DIR}/nextpas.log"
GO_LOG="${BUILD_DIR}/go.log"

{
  echo "shape=connections=${CONNECTIONS} streams=${STREAMS} batches=${BATCHES}"
  echo "date=$(date -Iseconds 2>/dev/null || date)"
  echo
  echo "=== nextpas ==="
  "${NEXTPAS_BIN}" --mode multiplex --backend epoll "${SHAPE[@]}" | tee "${NEXTPAS_LOG}"
  echo
  echo "=== go ==="
  "${GO_BIN}" "${SHAPE[@]}" | tee "${GO_LOG}"
  echo

  np_rps="$(awk -F= '/^req\/s=/{v=$2} END{print v}' "${NEXTPAS_LOG}")"
  go_rps="$(awk -F= '/^req\/s=/{v=$2} END{print v}' "${GO_LOG}")"
  np_stable="$(awk -F= '/^stable=/{v=$2} END{print v}' "${NEXTPAS_LOG}")"
  go_stable="$(awk -F= '/^stable=/{v=$2} END{print v}' "${GO_LOG}")"

  ratio="n/a"
  if [[ -n "${np_rps}" && -n "${go_rps}" && "${go_rps}" -gt 0 ]]; then
    ratio="$(awk -v a="${np_rps}" -v b="${go_rps}" 'BEGIN{printf "%.2f", a/b}')"
  fi

  echo "summary=http.server.h2.comparison"
  echo "summary_shape=${CONNECTIONS}x${STREAMS}x${BATCHES}"
  echo "summary_nextpas_req/s=${np_rps}"
  echo "summary_go_req/s=${go_rps}"
  echo "summary_ratio_nextpas_over_go=${ratio}"
  echo "summary_nextpas_stable=${np_stable}"
  echo "summary_go_stable=${go_stable}"
  echo "summary_gate_peer_0_80=$([ -n "${ratio}" ] && awk -v r="${ratio}" 'BEGIN{if(r+0>=0.80)print "Met";else if(r=="n/a")print "n/a";else print "NotMet"}')"
} | tee "${BUILD_DIR}/latest.md"

if [[ -n "${OUTPUT_PATH}" ]]; then
  cp "${BUILD_DIR}/latest.md" "${OUTPUT_PATH}"
  echo "wrote ${OUTPUT_PATH}"
fi
