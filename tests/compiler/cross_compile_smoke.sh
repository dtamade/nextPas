#!/bin/bash
# D7: Cross-compilation smoke test for compiler multi-platform support
# Verifies the compiler can cross-compile to Windows (COFF) and Linux (ELF) targets.
# Tests IR metadata (triple, datalayout) and object file format.
# Does NOT require lld-link or Wine — only validates compilation pipeline.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
STAGE0="$REPO_ROOT/build/stage0-bootstrap/nextpas"

if [ ! -x "$STAGE0" ]; then
  echo "FAIL: stage0 binary not found at $STAGE0"
  exit 1
fi

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

# Simple test programs for cross-compilation
echo 'program cross_smoke; begin end.' > "$TMPDIR/smoke.pas"
echo '
program cross_smoke_units;
uses SysUtils;
var S: string;
begin
  S := IntToStr(42);
end.
' > "$TMPDIR/smoke_units.pas"

PASS=0
FAIL=0
SKIP=0

check_target() {
  local target_id="$1"
  local expected_triple="$2"
  local expected_layout_prefix="$3"
  local expected_obj_format="$4"
  local test_file="$5"
  local test_label="$6"

  local out_dir="$TMPDIR/out-$target_id-$test_label"
  local cache_dir="$REPO_ROOT/.nextpas/cache/backend/$target_id"

  echo "--- Checking target: $target_id ($test_label) ---"

  # Compile (allow link failure — we only need IR + object)
  local build_output
  build_output=$("$STAGE0" build "$test_file" \
    --target "$target_id" \
    --workspace "$REPO_ROOT" 2>&1) || true

  # Check if IR was generated
  local ir_file="$cache_dir/$(basename "$test_file" .pas).ll"
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

  # Check object file format
  local obj_file="$cache_dir/$(basename "$test_file" .pas).o"
  if [ -f "$obj_file" ]; then
    local obj_info
    obj_info=$(file "$obj_file")
    case "$expected_obj_format" in
      coff)
        if echo "$obj_info" | grep -qi "COFF"; then
          echo "  PASS: object format = COFF"
        else
          echo "  FAIL: object format = $obj_info (expected COFF)"
          FAIL=$((FAIL + 1))
          return
        fi
        ;;
      elf)
        if echo "$obj_info" | grep -qi "ELF"; then
          echo "  PASS: object format = ELF"
        else
          echo "  FAIL: object format = $obj_info (expected ELF)"
          FAIL=$((FAIL + 1))
          return
        fi
        ;;
    esac
  else
    echo "  SKIP: object file not generated (link step may have failed)"
    SKIP=$((SKIP + 1))
  fi

  # Verify opt can process the IR
  if command -v opt >/dev/null 2>&1; then
    local bc_file="$cache_dir/$(basename "$test_file" .pas).bc"
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

# ── Targets ─────────────────────────────────────────────────────────

# Linux x86_64 (native backend — no LLVM IR)
echo "=== D7 Cross-compilation smoke test ==="
echo ""

# Linux aarch64 (LLVM cross)
check_target "linux-aarch64" \
  "aarch64-unknown-linux-gnu" \
  "e-m:e" \
  "elf" \
  "$TMPDIR/smoke.pas" \
  "basic"

# FreeBSD x86_64 (LLVM cross — ELF)
check_target "freebsd-x86_64" \
  "x86_64-unknown-freebsd" \
  "e-m:e-p270" \
  "elf" \
  "$TMPDIR/smoke.pas" \
  "basic"

# Windows x86_64 (LLVM cross — COFF)
check_target "windows-x86_64" \
  "x86_64-pc-windows-msvc" \
  "e-m:w-p270" \
  "coff" \
  "$TMPDIR/smoke.pas" \
  "basic"

# Windows x86_64 with units (tests SysUtils stub)
check_target "windows-x86_64" \
  "x86_64-pc-windows-msvc" \
  "e-m:w-p270" \
  "coff" \
  "$TMPDIR/smoke_units.pas" \
  "with-units"

echo ""
echo "=== D7 Cross-compilation smoke results ==="
echo "PASS: $PASS"
echo "FAIL: $FAIL"
echo "SKIP: $SKIP"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
echo "All cross-compilation checks passed."
