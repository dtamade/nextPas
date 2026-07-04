#!/bin/bash
set -e
cd /home/dtamade/projects/nextPas/.worktrees/bench
mkdir -p build
fpc -O3 -CX -XX -Xs -dRELEASE \
  -Fi./core/src -Fu./core/src \
  -Fu/opt/fpcupdeluxe/fpc/units/x86_64-linux/rtl \
  -Fu./units/linux-x86_64 -Fi./units/linux-x86_64 \
  -obuild/copy_bench bench/copy/copy_bench.pas
