#!/bin/bash
set -e
cd "$(dirname "$0")"
OUT=/tmp/multidim_bench
fpc -O3 -CX -XX -Xs -dRELEASE \
  -Fi/home/dtamade/projects/nextPas/.worktrees/bench/core/src \
  -Fu/home/dtamade/projects/nextPas/.worktrees/bench/core/src \
  -Fu/opt/fpcupdeluxe/fpc/units/x86_64-linux/rtl \
  -Fu/home/dtamade/projects/nextPas/.worktrees/bench/units/linux-x86_64 \
  -Fi/home/dtamade/projects/nextPas/.worktrees/bench/units/linux-x86_64 \
  -o"$OUT" multidim_bench.pas 2>&1 | tail -3
echo "=== Multidim Pascal ==="
"$OUT"
