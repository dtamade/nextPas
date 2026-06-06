#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CORE_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
REQUESTS=20000
THREADS=4
RUNS=1
OUTPUT_PATH="${CORE_ROOT}/build/projects/nextpas.core.http/server_comparison/snapshot.md"

usage() {
  cat <<'EOF'
usage: capture_server_comparison_snapshot.sh [--requests N] [--threads N] [--runs N] [--output PATH]

Capture a Markdown snapshot for the nextPas/Go/Rust std-only HTTP server comparison.
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

OUTPUT_DIR="$(dirname "${OUTPUT_PATH}")"
RAW_OUTPUT="${OUTPUT_PATH}.raw"
mkdir -p "${OUTPUT_DIR}"

"${SCRIPT_DIR}/run_server_comparison.sh" \
  --requests "${REQUESTS}" \
  --threads "${THREADS}" \
  --runs "${RUNS}" \
  --output "${RAW_OUTPUT}" >/dev/null

git_head="$(git -C "${CORE_ROOT}/.." rev-parse HEAD 2>/dev/null || printf 'unknown')"
git_status="$(git -C "${CORE_ROOT}/.." status --short --branch 2>/dev/null | head -n 1 || printf 'unknown')"
captured_at="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
os_uname="$(uname -a)"
fpc_version="$(fpc -iV 2>/dev/null || printf 'unknown')"
go_version="$(go version 2>/dev/null || printf 'unknown')"
rustc_version="$(rustc --version 2>/dev/null || printf 'unknown')"

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
requests=${REQUESTS}
threads=${THREADS}
runs=${RUNS}
\`\`\`

## Command

\`\`\`sh
benchmarks/nextpas.core.http/run_server_comparison.sh --requests ${REQUESTS} --threads ${THREADS} --runs ${RUNS}
\`\`\`

## Raw Comparison Output

\`\`\`text
$(cat "${RAW_OUTPUT}")
\`\`\`
EOF

printf '%s\n' "${OUTPUT_PATH}"
