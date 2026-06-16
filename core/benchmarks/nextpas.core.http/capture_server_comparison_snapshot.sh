#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CORE_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
REQUESTS=20000
THREADS=4
REQUESTED_THREADS=4
EFFECTIVE_THREADS=4
WORKLOAD="no_url"
WORKLOAD_EXPLICIT=0
RUNS=1
INCLUDE_HYPER=0
NEXTPAS_BACKEND="threaded"
OUTPUT_PATH="${CORE_ROOT}/build/projects/nextpas.core.http/server_comparison/snapshot.md"

usage() {
  cat <<'EOF'
usage: capture_server_comparison_snapshot.sh [--requests N] [--threads N] [--workload no_url|url_path|adapter_no_url|response_1k] [--runs N] [--include-hyper] [--nextpas-backend threaded|epoll] [--output PATH]

Capture a Markdown snapshot for the nextPas/Go/Rust std-only HTTP server comparison.
Pass --include-hyper to include the optional Hyper/Tokio comparator.
Pass --nextpas-backend to record and select the nextPas-only backend in the embedded run.
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
      WORKLOAD_EXPLICIT=1
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

SERVER_COMPARISON_OUTPUT_ROOT="${CORE_ROOT}/build/projects/nextpas.core.http/server_comparison"

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

  resolved_output="$(resolve_path "${OUTPUT_PATH}")"
  resolved_root="$(resolve_path "${SERVER_COMPARISON_OUTPUT_ROOT}")"
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

OUTPUT_DIR="$(dirname "${OUTPUT_PATH}")"
RAW_OUTPUT="${OUTPUT_PATH}.raw"

cleanup() {
  rm -f "${RAW_OUTPUT}"
}
trap cleanup EXIT

mkdir -p "${OUTPUT_DIR}"

RUNNER_ARGS=(--requests "${REQUESTS}" --threads "${THREADS}")
RUNNER_COMMAND="benchmarks/nextpas.core.http/run_server_comparison.sh --requests ${REQUESTS} --threads ${THREADS}"
if [[ "${WORKLOAD_EXPLICIT}" -eq 1 ]]; then
  RUNNER_ARGS+=(--workload "${WORKLOAD}")
  RUNNER_COMMAND="${RUNNER_COMMAND} --workload ${WORKLOAD}"
fi
RUNNER_ARGS+=(--runs "${RUNS}")
RUNNER_COMMAND="${RUNNER_COMMAND} --runs ${RUNS}"
if [[ "${INCLUDE_HYPER}" -eq 1 ]]; then
  RUNNER_ARGS+=(--include-hyper)
  RUNNER_COMMAND="${RUNNER_COMMAND} --include-hyper"
fi
if [[ "${NEXTPAS_BACKEND}" != "threaded" ]]; then
  RUNNER_ARGS+=(--nextpas-backend "${NEXTPAS_BACKEND}")
  RUNNER_COMMAND="${RUNNER_COMMAND} --nextpas-backend ${NEXTPAS_BACKEND}"
fi

"${SCRIPT_DIR}/run_server_comparison.sh" \
  "${RUNNER_ARGS[@]}" \
  --output "${RAW_OUTPUT}" >/dev/null

git_head="$(git -C "${CORE_ROOT}/.." rev-parse HEAD 2>/dev/null || printf 'unknown')"
git_status="$(git -C "${CORE_ROOT}/.." status --short --branch 2>/dev/null | head -n 1 || printf 'unknown')"
captured_at="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
os_uname="$(uname -a)"
fpc_version="$(fpc -iV 2>/dev/null || printf 'unknown')"
go_version="$(go version 2>/dev/null || printf 'unknown')"
rustc_version="$(rustc --version 2>/dev/null || printf 'unknown')"
cargo_version="$(cargo --version 2>/dev/null || printf 'unknown')"
hyper_cargo_lock_sha256="unknown"
if command -v sha256sum >/dev/null 2>&1 && [[ -f "${SCRIPT_DIR}/compare_hyper/Cargo.lock" ]]; then
  hyper_cargo_lock_sha256="$(sha256sum "${SCRIPT_DIR}/compare_hyper/Cargo.lock" | awk '{print $1}')"
fi

cat >"${OUTPUT_PATH}" <<EOF
# nextpas.core.http Server Benchmark Snapshot

This snapshot captures one local run of the HTTP/1.1 keep-alive comparison
runner. Treat the numbers as environment-specific evidence, not as a permanent
performance ranking.

## Environment

\`\`\`text
captured_at=${captured_at}
git_head=${git_head}
git_status=${git_status}
os=${os_uname}
fpc_version=${fpc_version}
go_version=${go_version}
rustc_version=${rustc_version}
cargo_version=${cargo_version}
hyper_cargo_lock_sha256=${hyper_cargo_lock_sha256}
requests=${REQUESTS}
threads=${THREADS}
requested_threads=${REQUESTED_THREADS}
effective_threads=${EFFECTIVE_THREADS}
workload=${WORKLOAD}
runs=${RUNS}
include_hyper=${INCLUDE_HYPER}
nextpas_backend=${NEXTPAS_BACKEND}
\`\`\`

## Command

\`\`\`sh
${RUNNER_COMMAND}
\`\`\`

## Raw Comparison Output

\`\`\`text
$(cat "${RAW_OUTPUT}")
\`\`\`
EOF

printf '%s\n' "${OUTPUT_PATH}"
