#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FPC="${FPC:-fpc}"

echo "=== nextpas.core.tui benchmark smoke ==="
echo "date=$(date -Iseconds)"
echo "uname=$(uname -a)"
echo "fpc=$("$FPC" -iV)"
echo ""

for bench in bench_diff bench_input bench_layout bench_render; do
  echo "== ${bench} =="
  make -C "${SCRIPT_DIR}/${bench}" FPC="${FPC}" clean run
  echo ""
done

echo "TUI benchmark smoke complete."
