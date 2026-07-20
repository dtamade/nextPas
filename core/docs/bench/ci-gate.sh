#!/bin/bash
# nextpas.core.bench CI template (module-level)
#
# Usage (from repo root):
#   bash core/docs/bench/ci-gate.sh
#   bash core/docs/bench/ci-gate.sh --skip-module-bench
#
# What this template actually runs (no placeholder binaries):
#   1) make hygiene
#   2) make -C core/tests/nextpas.core.bench clean test
#   3) optional: make -C core/benchmarks/nextpas.core.bench clean test
#
# Exit codes:
#   0 = pass
#   1 = test or hygiene failure
#   2 = usage / environment error
#
# For product-specific regression gates (JSON baseline compare), wire your own
# TBenchSuite binary and HasRegression/GetRegressionReport — this script is the
# module quality gate, not a universal CLI for arbitrary apps.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SKIP_MODULE_BENCH=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-module-bench) SKIP_MODULE_BENCH=1; shift ;;
    -h|--help)
      sed -n '2,20p' "$0"
      exit 0
      ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done

cd "$ROOT"
echo "=== nextpas.core.bench CI gate ==="
echo "ROOT=$ROOT"
echo ""

echo "[1/3] hygiene"
make hygiene

echo "[2/3] module tests (22 suites)"
make -C core/tests/nextpas.core.bench clean test

if [[ "$SKIP_MODULE_BENCH" == "0" ]]; then
  echo "[3/3] module micro-benchmarks"
  make -C core/benchmarks/nextpas.core.bench clean test
else
  echo "[3/3] skip module micro-benchmarks"
fi

echo ""
echo "=== CI PASS ==="
