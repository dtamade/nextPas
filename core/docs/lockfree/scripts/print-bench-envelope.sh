#!/usr/bin/env bash
# Print a minimal H2-4 bench evidence envelope to stdout.
# Usage: print-bench-envelope.sh [workload-description]
set -euo pipefail

WORKLOAD="${1:-unspecified}"
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
  COMPILER="$(fpc -iV 2>/dev/null | head -n1 || fpc -h 2>&1 | head -n1 || echo fpc-present)"
fi
BUILD_ID="unknown"
if command -v git >/dev/null 2>&1 && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  BUILD_ID="$(git rev-parse HEAD 2>/dev/null || echo unknown)"
fi
HOST="$(hostname 2>/dev/null || echo unknown)"

cat <<EOF
=== nextpas bench envelope (H2-4) ===
date_utc:  ${DATE_UTC}
host:      ${HOST}
os:        ${OS_LINE}
cpu:       ${CPU_LINE} (logical=${CORES})
compiler:  ${COMPILER}
build_id:  ${BUILD_ID}
workload:  ${WORKLOAD}
warmup:    (fill: iterations or ms)
measured:  (fill: iterations or duration)
stats:     (fill: samples>=3 mean/median/min/max)
units:     (fill: ops/s or ns/op)
command:   (fill: exact repro)
=== end envelope ===
EOF
