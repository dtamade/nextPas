#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CORE_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
BUILD_DIR="${CORE_ROOT}/build/projects/nextpas.core.http/server_comparison"
REQUESTS=20000
THREADS=4
WORKLOAD="no_url"
OUTPUT_PATH=""
RUNS=1

usage() {
  cat <<'EOF'
usage: run_server_comparison.sh [--requests N] [--threads N] [--workload no_url|url_path|adapter_no_url|response_1k] [--runs N] [--output PATH]

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
    --runs)
      RUNS="${2:?missing value for --runs}"
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

case "${RUNS}" in
  ''|*[!0-9]*)
    echo "--runs must be a positive integer" >&2
    exit 2
    ;;
esac

if [[ "${REQUESTS}" -lt 1 || "${THREADS}" -lt 1 || "${RUNS}" -lt 1 ]]; then
  echo "--requests, --threads, and --runs must be positive" >&2
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

RESULTS_TMP=""

cleanup() {
  if [[ "${RESULTS_TMP}" != "" ]]; then
    rm -f "${RESULTS_TMP}"
  fi
}
trap cleanup EXIT

build_comparators() {
  mkdir -p "${BUILD_DIR}"

  "${MAKE:-make}" -C "${SCRIPT_DIR}/bench_server" build
  go build -o "${BUILD_DIR}/bench_http_server_go" "${SCRIPT_DIR}/compare_go/main.go"
  rustc -O -o "${BUILD_DIR}/bench_http_server_rust" "${SCRIPT_DIR}/compare_rust/main.rs"
}

append_result_row() {
  local run_index="$1"
  local expected_impl="$2"
  local output="$3"
  local ns_op
  local req_s
  local iterations
  local completed

  if ! printf '%s\n' "${output}" | grep -q "^impl=${expected_impl}$"; then
    echo "unable to find benchmark impl marker for impl=${expected_impl}" >&2
    echo "${output}" >&2
    exit 1
  fi

  iterations="$(printf '%s\n' "${output}" | sed -nE 's/^iterations=([0-9]+)$/\1/p' | tail -n 1)"
  completed="$(printf '%s\n' "${output}" | sed -nE 's/^completed=([0-9]+)$/\1/p' | tail -n 1)"
  ns_op="$(printf '%s\n' "${output}" | sed -nE 's/^ns\/op=([0-9]+)$/\1/p' | tail -n 1)"
  req_s="$(printf '%s\n' "${output}" | sed -nE 's/^req\/s=([0-9]+)$/\1/p' | tail -n 1)"
  if [[ "${iterations}" == "" || "${completed}" == "" || "${ns_op}" == "" || "${req_s}" == "" ]]; then
    echo "unable to parse benchmark output for impl=${expected_impl}" >&2
    echo "${output}" >&2
    exit 1
  fi

  if [[ "${iterations}" != "${REQUESTS}" || "${completed}" != "${REQUESTS}" ]]; then
    echo "incomplete benchmark run for impl=${expected_impl}: iterations=${iterations} completed=${completed} expected=${REQUESTS}" >&2
    echo "${output}" >&2
    exit 1
  fi

  printf '%s\t%s\t%s\t%s\t%s\n' \
    "${run_index}" "${expected_impl}" "${ns_op}" "${req_s}" "${completed}" >> "${RESULTS_TMP}"
}

run_one_impl() {
  local run_index="$1"
  local expected_impl="$2"
  shift 2
  local output

  output="$("$@")"
  printf '%s\n' "${output}"
  append_result_row "${run_index}" "${expected_impl}" "${output}"
}

write_summary() {
  awk -F $'\t' '
    function sort_values(values, count,    i, j, tmp) {
      for (i = 1; i < count; i++) {
        for (j = i + 1; j <= count; j++) {
          if (values[j] < values[i]) {
            tmp = values[i];
            values[i] = values[j];
            values[j] = tmp;
          }
        }
      }
    }

    function median(values, count,    copy, i) {
      delete copy;
      for (i = 1; i <= count; i++) {
        copy[i] = values[i];
      }
      sort_values(copy, count);
      if ((count % 2) == 1) {
        return copy[int((count + 1) / 2)];
      }
      return (copy[int(count / 2)] + copy[int(count / 2) + 1]) / 2.0;
    }

    {
      impl = $2;
      count[impl]++;
      ns_values[impl, count[impl]] = $3 + 0.0;
      req_values[impl, count[impl]] = $4 + 0.0;
      completed_values[impl, count[impl]] = $5 + 0.0;
    }

    END {
      for (impl in count) {
        delete current_ns;
        delete current_req;
        delete current_completed;
        for (i = 1; i <= count[impl]; i++) {
          current_ns[i] = ns_values[impl, i];
          current_req[i] = req_values[impl, i];
          current_completed[i] = completed_values[impl, i];
        }
        printf "summary_impl=%s runs=%d median_completed=%.0f median_ns/op=%.1f median_req/s=%.0f\n",
          impl, count[impl], median(current_completed, count[impl]),
          median(current_ns, count[impl]), median(current_req, count[impl]);
      }
    }
  ' "${RESULTS_TMP}" | sort
}

run_comparison() {
  build_comparators
  RESULTS_TMP="$(mktemp "${BUILD_DIR}/server-comparison-results.XXXXXX")"
  : > "${RESULTS_TMP}"

  echo "comparison=http.server.keepalive"
  echo "requests=${REQUESTS}"
  echo "threads=${THREADS}"
  echo "workload=${WORKLOAD}"
  echo "runs=${RUNS}"
  echo

  for run_index in $(seq 1 "${RUNS}"); do
    echo "run=${run_index}"

    echo "section=nextpas"
    run_one_impl "${run_index}" "nextpas" \
      "${CORE_ROOT}/build/projects/nextpas.core.http/bench_server/bench_http_server" \
      --requests "${REQUESTS}" --threads "${THREADS}" --workload "${WORKLOAD}"

    echo "section=go"
    run_one_impl "${run_index}" "go" \
      "${BUILD_DIR}/bench_http_server_go" \
      --requests "${REQUESTS}" --threads "${THREADS}" --workload "${WORKLOAD}"

    echo "section=rust"
    run_one_impl "${run_index}" "rust" \
      "${BUILD_DIR}/bench_http_server_rust" \
      --requests "${REQUESTS}" --threads "${THREADS}" --workload "${WORKLOAD}"
  done

  echo
  echo "summary=http.server.keepalive"
  write_summary
}

if [[ "${OUTPUT_PATH}" == "" ]]; then
  run_comparison
else
  mkdir -p "$(dirname "${OUTPUT_PATH}")"
  run_comparison | tee "${OUTPUT_PATH}"
fi
