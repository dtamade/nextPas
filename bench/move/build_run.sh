#!/bin/bash
set -euo pipefail
cd /home/dtamade/projects/nextPas/.worktrees/bench
fpc -O3 -CX -XX -Xs -dRELEASE \
  -Fi./core/src -Fu./core/src \
  -Fu/opt/fpcupdeluxe/fpc/units/x86_64-linux/rtl \
  -Fu./units/linux-x86_64 -Fi./units/linux-x86_64 \
  bench/move/move_bench.pas -o/tmp/move_bench
/tmp/move_bench | cat
