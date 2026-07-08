#!/bin/bash
# C7 multi-target IR smoke test
# Verifies the compiler generates correct LLVM IR for different targets.
# Does NOT require cross-compilation toolchains — only validates IR metadata.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
STAGE0="$REPO_ROOT/build/stage0/nextpas"

if [ ! -x "$STAGE0" ]; then
  echo "FAIL: stage0 binary not found at $STAGE0"
  exit 1
fi

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

echo 'program multitarget_smoke; begin end.' > "$TMPDIR/smoke.pas"

PASS=0
FAIL=0

check_target() {
  local target_id="$1"
  local expected_triple="$2"
  local expected_layout_prefix="$3"
  local backend_family="${4:-llvm}"

  local out_dir="$TMPDIR/out-$target_id"
  local cache_dir="$REPO_ROOT/.nextpas/cache/backend/$target_id"

  echo "--- Checking target: $target_id (backend: $backend_family) ---"

  # Compile (allow llc failure — we only need the IR)
  "$STAGE0" build "$TMPDIR/smoke.pas" \
    --target "$target_id" \
    --workspace "$REPO_ROOT" \
    --fold 2>/dev/null || true

  # Native backend (FPC) — no LLVM IR to check
  if [ "$backend_family" = "native" ]; then
    local asm_file="$cache_dir/smoke.s"
    if [ -f "$asm_file" ]; then
      echo "  PASS: native backend produced assembly"
      PASS=$((PASS + 1))
    else
      echo "  FAIL: native backend did not produce assembly"
      FAIL=$((FAIL + 1))
    fi
    return
  fi

  # LLVM backend — check IR metadata
  local ir_file="$cache_dir/smoke.ll"
  if [ ! -f "$ir_file" ]; then
    echo "  FAIL: IR file not generated: $ir_file"
    FAIL=$((FAIL + 1))
    return
  fi

  # Check triple
  local actual_triple
  actual_triple=$(grep 'target triple' "$ir_file" | sed 's/.*= "\(.*\)"/\1/')
  if [ "$actual_triple" = "$expected_triple" ]; then
    echo "  PASS: triple = $actual_triple"
  else
    echo "  FAIL: triple = $actual_triple (expected $expected_triple)"
    FAIL=$((FAIL + 1))
    return
  fi

  # Check datalayout prefix
  local actual_layout
  actual_layout=$(grep 'target datalayout' "$ir_file" | sed 's/.*= "\(.*\)"/\1/')
  if echo "$actual_layout" | grep -q "^$expected_layout_prefix"; then
    echo "  PASS: datalayout starts with $expected_layout_prefix"
  else
    echo "  FAIL: datalayout = $actual_layout (expected prefix $expected_layout_prefix)"
    FAIL=$((FAIL + 1))
    return
  fi

  # Verify opt can process the IR
  local bc_file="$cache_dir/smoke.bc"
  if command -v opt >/dev/null 2>&1; then
    if opt -O2 -o "$bc_file" "$ir_file" 2>/dev/null; then
      echo "  PASS: opt -O2 succeeded"
    else
      echo "  FAIL: opt -O2 failed"
      FAIL=$((FAIL + 1))
      return
    fi
  else
    echo "  SKIP: opt not found, skipping bitcode verification"
  fi

  PASS=$((PASS + 1))
}

# x86_64 (native, uses FPC backend — no LLVM IR)
check_target "linux-x86_64" \
  "x86_64-unknown-linux-gnu" \
  "e-p:64:64:64" \
  "native"

# aarch64 (cross, uses LLVM backend)
check_target "linux-aarch64" \
  "aarch64-unknown-linux-gnu" \
  "e-m:e" \
  "llvm"

echo ""
echo "=== Multi-target IR smoke results ==="
echo "PASS: $PASS"
echo "FAIL: $FAIL"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
echo "All multi-target IR checks passed."
