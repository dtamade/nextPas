#!/usr/bin/env bash
# Print H2-4 / Q5 bench evidence envelope to stdout.
# Usage:
#   print-bench-envelope.sh [workload] [key=value ...]
# Extra key=value pairs override defaults for command/measured/stats/units/binary.
set -euo pipefail

WORKLOAD="${1:-unspecified}"
if [[ $# -gt 0 ]]; then
  shift
fi

DATE_UTC="$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u)"
OS_LINE="$(uname -srm 2>/dev/null || echo unknown)"
CPU_LINE="unknown"
if [[ -r /proc/cpuinfo ]]; then
  CPU_LINE="$(awk -F': ' '/model name/ {print $2; exit}' /proc/cpuinfo 2>/dev/null || true)"
  [[ -z "${CPU_LINE}" ]] && CPU_LINE="unknown"
fi
CORES="$(getconf _NPROCESSORS_ONLN 2>/dev/null || nproc 2>/dev/null || echo '?')"
COMPILER="unknown"
if command -v fpc >/dev/null 2>&1; then
  COMPILER="$(fpc -iV 2>/dev/null | head -n1 || echo fpc-present)"
fi
BUILD_ID="unknown"
if command -v git >/dev/null 2>&1 && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  BUILD_ID="$(git rev-parse HEAD 2>/dev/null || echo unknown)"
fi
HOST="$(hostname 2>/dev/null || echo unknown)"

COMMAND="(set via key=value)"
MEASURED="(set via key=value)"
STATS="samples=1 unless noted"
UNITS="ops/s and ns/op (see lines below)"
BINARY="core/build/projects/... (see make BUILD_DIR)"

for arg in "$@"; do
  case "$arg" in
    command=*) COMMAND="${arg#command=}" ;;
    measured=*) MEASURED="${arg#measured=}" ;;
    stats=*) STATS="${arg#stats=}" ;;
    units=*) UNITS="${arg#units=}" ;;
    binary=*) BINARY="${arg#binary=}" ;;
    compiler=*) COMPILER="${arg#compiler=}" ;;
  esac
done

cat <<EOF
=== nextpas bench envelope (H2-4/Q5) ===
date_utc:  ${DATE_UTC}
host:      ${HOST}
os:        ${OS_LINE}
cpu:       ${CPU_LINE} (logical=${CORES})
compiler:  ${COMPILER}
build_id:  ${BUILD_ID}
binary:    ${BINARY}
workload:  ${WORKLOAD}
warmup:    none (or as printed by suite)
measured:  ${MEASURED}
stats:     ${STATS}
units:     ${UNITS}
command:   ${COMMAND}
=== end envelope ===
EOF
