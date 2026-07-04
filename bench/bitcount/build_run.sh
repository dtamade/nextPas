#!/bin/bash
set -euo pipefail
cd /home/dtamade/projects/nextPas/.worktrees/bench
fpc -O3 -CX -XX -Xs -dRELEASE \
  -Fi./core/src -Fu./core/src \
  -Fu/opt/fpcupdeluxe/fpc/units/x86_64-linux/rtl \
  -Fu./units/linux-x86_64 -Fi./units/linux-x86_64 \
  bench/bitcount/bitcount_bench.pas -o/tmp/bitcount_bench
/tmp/bitcount_bench | cat
