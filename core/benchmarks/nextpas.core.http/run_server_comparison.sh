#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CORE_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
BUILD_DIR="${CORE_ROOT}/build/projects/nextpas.core.http/server_comparison"
COMPARISON_LOCK_DIR="${BUILD_DIR}/.comparison-lock"
COMPARISON_LOCK_TIMEOUT_SECONDS=300
REQUESTS=20000
THREADS=4
REQUESTED_THREADS=4
EFFECTIVE_THREADS=4
WORKLOAD="no_url"
OUTPUT_PATH=""
RUNS=1
INCLUDE_HYPER=0
NEXTPAS_BACKEND="threaded"
COMPARISON_LOCK_HELD=0

usage() {
  cat <<'EOF'
usage: run_server_comparison.sh [--requests N] [--threads N] [--workload no_url|url_path|adapter_no_url|response_1k] [--runs N] [--include-hyper] [--nextpas-backend threaded|epoll] [--output PATH]

Build and run nextPas, Go, and Rust std-only HTTP/1.1 keep-alive server benchmarks.
Pass --include-hyper to also build and run the Cargo-based Hyper/Tokio comparator.
Pass --nextpas-backend to select the nextPas-only server backend for the nextPas row.
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
    --include-hyper)
      INCLUDE_HYPER=1
      shift
      ;;
    --nextpas-backend)
      NEXTPAS_BACKEND="${2:?missing value for --nextpas-backend}"
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

REQUESTED_THREADS="${THREADS}"
if [[ "${THREADS}" -gt "${REQUESTS}" ]]; then
  EFFECTIVE_THREADS="${REQUESTS}"
else
  EFFECTIVE_THREADS="${THREADS}"
fi

case "${WORKLOAD}" in
  no_url|url_path|adapter_no_url|response_1k)
    ;;
  *)
    echo "--workload must be no_url, url_path, adapter_no_url, or response_1k" >&2
    exit 2
    ;;
esac

case "${NEXTPAS_BACKEND}" in
  threaded|epoll)
    ;;
  *)
    echo "invalid --nextpas-backend: ${NEXTPAS_BACKEND} (expected threaded or epoll)" >&2
    exit 2
    ;;
esac

resolve_path() {
  if command -v realpath >/dev/null 2>&1; then
    realpath -m -- "$1"
  else
    python3 -c 'import os, sys; print(os.path.abspath(sys.argv[1]))' "$1"
  fi
}

validate_output_path() {
  local resolved_output
  local resolved_root

  if [[ "${OUTPUT_PATH}" == "" ]]; then
    return
  fi

  resolved_output="$(resolve_path "${OUTPUT_PATH}")"
  resolved_root="$(resolve_path "${BUILD_DIR}")"
  case "${resolved_output}" in
    "${resolved_root}"|"${resolved_root}/"*)
      OUTPUT_PATH="${resolved_output}"
      ;;
    *)
      echo "unsafe output path: ${OUTPUT_PATH}" >&2
      echo "allowed root: ${resolved_root}" >&2
      exit 2
      ;;
  esac
}

validate_output_path

RESULTS_TMP=""

cleanup() {
  if [[ "${RESULTS_TMP}" != "" ]]; then
    rm -f "${RESULTS_TMP}"
  fi
  release_comparison_lock
}
trap cleanup EXIT

acquire_comparison_lock() {
  local attempts_remaining

  mkdir -p "${BUILD_DIR}"
  attempts_remaining=$((COMPARISON_LOCK_TIMEOUT_SECONDS * 10))
  while true; do
    if mkdir "${COMPARISON_LOCK_DIR}" 2>/dev/null; then
      COMPARISON_LOCK_HELD=1
      printf '%s\n' "$$" > "${COMPARISON_LOCK_DIR}/pid"
      return
    fi

    if [[ "${attempts_remaining}" -le 0 ]]; then
      echo "timed out waiting for comparison lock: ${COMPARISON_LOCK_DIR}" >&2
      exit 2
    fi

    attempts_remaining=$((attempts_remaining - 1))
    sleep 0.1
  done
}

release_comparison_lock() {
  if [[ "${COMPARISON_LOCK_HELD}" -eq 1 ]]; then
    rm -f "${COMPARISON_LOCK_DIR}/pid"
    rmdir "${COMPARISON_LOCK_DIR}" 2>/dev/null || true
    COMPARISON_LOCK_HELD=0
  fi
}

build_comparators() {
  mkdir -p "${BUILD_DIR}"

  "${MAKE:-make}" -C "${SCRIPT_DIR}/bench_server" build
  go build -o "${BUILD_DIR}/bench_http_server_go" "${SCRIPT_DIR}/compare_go/main.go"
  rustc -O -o "${BUILD_DIR}/bench_http_server_rust" "${SCRIPT_DIR}/compare_rust/main.rs"
  if [[ "${INCLUDE_HYPER}" -eq 1 ]]; then
    "${CARGO:-cargo}" build --release \
      --manifest-path "${SCRIPT_DIR}/compare_hyper/Cargo.toml" \
      --target-dir "${BUILD_DIR}/cargo-target"
    cp "${BUILD_DIR}/cargo-target/release/bench_http_server_hyper" \
      "${BUILD_DIR}/bench_http_server_hyper"
  fi
}

append_result_row() {
  local run_index="$1"
  local expected_impl="$2"
  local output="$3"
  local ns_op
  local req_s
  local iterations
  local completed
  local operation
  local workload
  local client_read_mode
  local response_body_bytes
  local rust_profile
  local rust_http_stack
  local rust_runtime
  local requested_threads
  local effective_threads

  if ! printf '%s\n' "${output}" | grep -q "^impl=${expected_impl}$"; then
    echo "unable to find benchmark impl marker for impl=${expected_impl}" >&2
    echo "${output}" >&2
    exit 1
  fi

  operation="$(printf '%s\n' "${output}" | sed -nE 's/^operation=([^[:space:]]+)$/\1/p' | tail -n 1)"
  workload="$(printf '%s\n' "${output}" | sed -nE 's/^workload=([^[:space:]]+)$/\1/p' | tail -n 1)"
  iterations="$(printf '%s\n' "${output}" | sed -nE 's/^iterations=([0-9]+)$/\1/p' | tail -n 1)"
  completed="$(printf '%s\n' "${output}" | sed -nE 's/^completed=([0-9]+)$/\1/p' | tail -n 1)"
  ns_op="$(printf '%s\n' "${output}" | sed -nE 's/^ns\/op=([0-9]+)$/\1/p' | tail -n 1)"
  req_s="$(printf '%s\n' "${output}" | sed -nE 's/^req\/s=([0-9]+)$/\1/p' | tail -n 1)"
  client_read_mode="$(printf '%s\n' "${output}" | sed -nE 's/^client_read_mode=([^[:space:]]+)$/\1/p' | tail -n 1)"
  response_body_bytes="$(printf '%s\n' "${output}" | sed -nE 's/^response_body_bytes=([0-9]+)$/\1/p' | tail -n 1)"
  rust_profile="$(printf '%s\n' "${output}" | sed -nE 's/^rust_profile=([^[:space:]]+)$/\1/p' | tail -n 1)"
  rust_http_stack="$(printf '%s\n' "${output}" | sed -nE 's/^rust_http_stack=([^[:space:]]+)$/\1/p' | tail -n 1)"
  rust_runtime="$(printf '%s\n' "${output}" | sed -nE 's/^rust_runtime=([^[:space:]]+)$/\1/p' | tail -n 1)"
  requested_threads="$(printf '%s\n' "${output}" | sed -nE 's/^requested_threads=([0-9]+)$/\1/p' | tail -n 1)"
  effective_threads="$(printf '%s\n' "${output}" | sed -nE 's/^effective_threads=([0-9]+)$/\1/p' | tail -n 1)"
  if [[ "${rust_profile}" == "" ]]; then
    rust_profile="n/a"
  fi
  if [[ "${rust_http_stack}" == "" ]]; then
    rust_http_stack="n/a"
  fi
  if [[ "${rust_runtime}" == "" ]]; then
    rust_runtime="n/a"
  fi
  if [[ "${operation}" == "" || "${workload}" == "" || "${iterations}" == "" || "${completed}" == "" || "${ns_op}" == "" || "${req_s}" == "" || "${client_read_mode}" == "" || "${response_body_bytes}" == "" || "${requested_threads}" == "" || "${effective_threads}" == "" ]]; then
    echo "unable to parse benchmark output for impl=${expected_impl}" >&2
    echo "${output}" >&2
    exit 1
  fi

  if [[ "${operation}" != "http.server.keepalive" || "${workload}" != "${WORKLOAD}" ]]; then
    echo "operation/workload marker mismatch for impl=${expected_impl}: operation=${operation} workload=${workload} expected operation=http.server.keepalive workload=${WORKLOAD}" >&2
    echo "${output}" >&2
    exit 1
  fi
  if [[ "${expected_impl}" == "rust_hyper" && ("${rust_profile}" != "hyper_tokio" || "${rust_http_stack}" != "hyper_http1" || "${rust_runtime}" != "tokio_multi_thread") ]]; then
    echo "rust_hyper marker mismatch: profile=${rust_profile} stack=${rust_http_stack} runtime=${rust_runtime} expected profile=hyper_tokio stack=hyper_http1 runtime=tokio_multi_thread" >&2
    echo "${output}" >&2
    exit 1
  fi
  if [[ "${iterations}" != "${REQUESTS}" || "${completed}" != "${REQUESTS}" ]]; then
    echo "incomplete benchmark run for impl=${expected_impl}: iterations=${iterations} completed=${completed} expected=${REQUESTS}" >&2
    echo "${output}" >&2
    exit 1
  fi
  if [[ "${requested_threads}" != "${REQUESTED_THREADS}" || "${effective_threads}" != "${EFFECTIVE_THREADS}" ]]; then
    echo "thread metadata mismatch for impl=${expected_impl}: requested=${requested_threads} effective=${effective_threads} expected=${REQUESTED_THREADS}/${EFFECTIVE_THREADS}" >&2
    echo "${output}" >&2
    exit 1
  fi

  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "${run_index}" "${expected_impl}" "${ns_op}" "${req_s}" "${completed}" \
    "${client_read_mode}" "${response_body_bytes}" "${rust_profile}" \
    "${rust_http_stack}" "${rust_runtime}" "${requested_threads}" \
    "${effective_threads}" "${operation}" "${workload}" \
    >> "${RESULTS_TMP}"
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
      read_mode_values[impl, count[impl]] = $6;
      body_bytes_values[impl, count[impl]] = $7;
      rust_profile_values[impl, count[impl]] = $8;
      rust_http_stack_values[impl, count[impl]] = $9;
      rust_runtime_values[impl, count[impl]] = $10;
      requested_thread_values[impl, count[impl]] = $11;
      effective_thread_values[impl, count[impl]] = $12;
      operation_values[impl, count[impl]] = $13;
      workload_values[impl, count[impl]] = $14;
    }

    END {
      for (impl in count) {
        delete current_ns;
        delete current_req;
        delete current_completed;
        delete current_read_mode;
        delete current_body_bytes;
        delete current_rust_profile;
        delete current_rust_http_stack;
        delete current_rust_runtime;
        delete current_requested_threads;
        delete current_effective_threads;
        delete current_operation;
        delete current_workload;
        for (i = 1; i <= count[impl]; i++) {
          current_ns[i] = ns_values[impl, i];
          current_req[i] = req_values[impl, i];
          current_completed[i] = completed_values[impl, i];
          current_read_mode[i] = read_mode_values[impl, i];
          current_body_bytes[i] = body_bytes_values[impl, i];
          current_rust_profile[i] = rust_profile_values[impl, i];
          current_rust_http_stack[i] = rust_http_stack_values[impl, i];
          current_rust_runtime[i] = rust_runtime_values[impl, i];
          current_requested_threads[i] = requested_thread_values[impl, i];
          current_effective_threads[i] = effective_thread_values[impl, i];
          current_operation[i] = operation_values[impl, i];
          current_workload[i] = workload_values[impl, i];
        }
        printf "summary_impl=%s runs=%d median_completed=%.0f median_ns/op=%.1f median_req/s=%.0f summary_client_read_mode=%s summary_response_body_bytes=%s summary_rust_profile=%s summary_rust_http_stack=%s summary_rust_runtime=%s summary_requested_threads=%s summary_effective_threads=%s summary_operation=%s summary_workload=%s\n",
          impl, count[impl], median(current_completed, count[impl]),
          median(current_ns, count[impl]), median(current_req, count[impl]),
          current_read_mode[1], current_body_bytes[1], current_rust_profile[1],
          current_rust_http_stack[1], current_rust_runtime[1],
          current_requested_threads[1], current_effective_threads[1],
          current_operation[1], current_workload[1];
      }
    }
  ' "${RESULTS_TMP}" | sort
}

run_comparison() {
  acquire_comparison_lock
  build_comparators
  RESULTS_TMP="$(mktemp "${BUILD_DIR}/server-comparison-results.XXXXXX")"
  : > "${RESULTS_TMP}"

  echo "comparison=http.server.keepalive"
  echo "requests=${REQUESTS}"
  echo "threads=${EFFECTIVE_THREADS}"
  echo "requested_threads=${REQUESTED_THREADS}"
  echo "effective_threads=${EFFECTIVE_THREADS}"
  echo "workload=${WORKLOAD}"
  echo "runs=${RUNS}"
  echo "include_hyper=${INCLUDE_HYPER}"
  echo "nextpas_backend=${NEXTPAS_BACKEND}"
  echo

  for run_index in $(seq 1 "${RUNS}"); do
    echo "run=${run_index}"

    echo "section=nextpas"
    run_one_impl "${run_index}" "nextpas" \
      "${CORE_ROOT}/build/projects/nextpas.core.http/bench_server/bench_http_server" \
      --requests "${REQUESTS}" --threads "${REQUESTED_THREADS}" --workload "${WORKLOAD}" \
      --backend "${NEXTPAS_BACKEND}"

    echo "section=go"
    run_one_impl "${run_index}" "go" \
      "${BUILD_DIR}/bench_http_server_go" \
      --requests "${REQUESTS}" --threads "${REQUESTED_THREADS}" --workload "${WORKLOAD}"

    echo "section=rust_std"
    run_one_impl "${run_index}" "rust_std" \
      "${BUILD_DIR}/bench_http_server_rust" \
      --requests "${REQUESTS}" --threads "${REQUESTED_THREADS}" --workload "${WORKLOAD}"

    if [[ "${INCLUDE_HYPER}" -eq 1 ]]; then
      echo "section=rust_hyper"
      run_one_impl "${run_index}" "rust_hyper" \
        "${BUILD_DIR}/bench_http_server_hyper" \
        --requests "${REQUESTS}" --threads "${REQUESTED_THREADS}" --workload "${WORKLOAD}"
    fi
  done

  echo
  echo "summary=http.server.keepalive"
  write_summary
}

if [[ "${OUTPUT_PATH}" == "" ]]; then
  run_comparison
else
  mkdir -p "$(dirname "${OUTPUT_PATH}")"
  run_comparison > >(tee "${OUTPUT_PATH}")
fi
