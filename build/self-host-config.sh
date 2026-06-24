#!/bin/bash
# Self-hosting configuration for nextpas compiler
# Run from worktree root
ROOT=$(cd "$(dirname "$0")/.." && pwd)
build/stage0-bootstrap/nextpas build tools/stage0/nextpas.pas \
  --target linux-x86_64 \
  --unit-root "$ROOT/compiler/sema" \
  --unit-root "$ROOT/compiler/frontend" \
  --unit-root "$ROOT/compiler/ir" \
  --unit-root "$ROOT/compiler/backend" \
  --unit-root "$ROOT/compiler/diagnostics" \
  --unit-root "$ROOT/compiler/syntax" \
  --unit-root "$ROOT/compiler/toolchain" \
  --unit-root "$ROOT/compiler/targets" \
  --unit-root "$ROOT/rtl/core/base" \
  --unit-root "$ROOT/rtl/core/text" \
  --unit-root "$ROOT/core/src" \
  --out-dir build/stage2-test "$@"
