#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CORE_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
BUILD_DIR="${CORE_ROOT}/build/projects/nextpas.core.http/server_comparison"
REQUESTS=20000
THREADS=4
WORKLOAD="no_url"
OUTPUT_PATH=""

usage() {
  cat <<'EOF'
usage: run_server_comparison.sh [--requests N] [--threads N] [--workload no_url|url_path|adapter_no_url|response_1k] [--output PATH]

Build and run nextPas, Go, and Rust HTTP/1.1 keep-alive server benchmarks.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --requests)
      REQUESTS="${2:?missing value for --requests}"
      shift 2
      ;;
    --threads)
      THREADS="${2:?missing value for --threads}"
      shift 2
      ;;
    --workload)
      WORKLOAD="${2:?missing value for --workload}"
      shift 2
      ;;
    --output)
      OUTPUT_PATH="${2:?missing value for --output}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

case "${REQUESTS}" in
  ''|*[!0-9]*)
    echo "--requests must be a positive integer" >&2
    exit 2
    ;;
esac

case "${THREADS}" in
  ''|*[!0-9]*)
    echo "--threads must be a positive integer" >&2
    exit 2
    ;;
esac

if [[ "${REQUESTS}" -lt 1 || "${THREADS}" -lt 1 ]]; then
  echo "--requests and --threads must be positive" >&2
  exit 2
fi

if [[ "${THREADS}" -gt "${REQUESTS}" ]]; then
  THREADS="${REQUESTS}"
fi

case "${WORKLOAD}" in
  no_url|url_path|adapter_no_url|response_1k)
    ;;
  *)
    echo "--workload must be no_url, url_path, adapter_no_url, or response_1k" >&2
    exit 2
    ;;
esac

run_comparison() {
  mkdir -p "${BUILD_DIR}"

  "${MAKE:-make}" -C "${SCRIPT_DIR}/bench_server" build
  go build -o "${BUILD_DIR}/bench_http_server_go" "${SCRIPT_DIR}/compare_go/main.go"
  rustc -O -o "${BUILD_DIR}/bench_http_server_rust" "${SCRIPT_DIR}/compare_rust/main.rs"

  echo "comparison=http.server.keepalive"
  echo "requests=${REQUESTS}"
  echo "threads=${THREADS}"
  echo "workload=${WORKLOAD}"
  echo

  echo "section=nextpas"
  "${CORE_ROOT}/build/projects/nextpas.core.http/bench_server/bench_http_server" \
    --requests "${REQUESTS}" --threads "${THREADS}" --workload "${WORKLOAD}"

  echo "section=go"
  "${BUILD_DIR}/bench_http_server_go" \
    --requests "${REQUESTS}" --threads "${THREADS}" --workload "${WORKLOAD}"

  echo "section=rust"
  "${BUILD_DIR}/bench_http_server_rust" \
    --requests "${REQUESTS}" --threads "${THREADS}" --workload "${WORKLOAD}"
}

if [[ "${OUTPUT_PATH}" == "" ]]; then
  run_comparison
else
  mkdir -p "$(dirname "${OUTPUT_PATH}")"
  run_comparison | tee "${OUTPUT_PATH}"
fi
