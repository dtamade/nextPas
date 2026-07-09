#!/bin/bash
# D8: Compiler performance benchmark
# Measures:
#   1. Compilation time (wall clock) for various programs
#   2. LLVM IR quality metrics (instructions, blocks, functions)
#   3. Cross-target comparison (linux-aarch64 vs windows-x86_64 vs freebsd-x86_64)
#
# Usage: ./tests/compiler/perf_benchmark.sh [--verbose]

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
STAGE0="$REPO_ROOT/build/stage0-bootstrap/nextpas"
VERBOSE=0

if [[ "${1:-}" == "--verbose" ]]; then
  VERBOSE=1
fi

if [ ! -x "$STAGE0" ]; then
  echo "FAIL: stage0 binary not found at $STAGE0"
  exit 1
fi

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

# ── Test programs ──────────────────────────────────────────────────

# Simple program
cat > "$TMPDIR/simple.pas" << 'EOF'
program simple;
begin
end.
EOF

# Program with basic types and operations
cat > "$TMPDIR/arith.pas" << 'EOF'
program arith;
var
  A, B, C: Integer;
begin
  A := 10;
  B := 20;
  C := A + B;
  C := A * B;
  C := A - B;
end.
EOF

# Program with control flow
cat > "$TMPDIR/control.pas" << 'EOF'
program control;
var
  I: Integer;
begin
  I := 0;
  while I < 100 do
  begin
    if I mod 2 = 0 then
      I := I + 1
    else
      I := I + 2;
  end;
end.
EOF

# Program with string operations
cat > "$TMPDIR/strings.pas" << 'EOF'
program strings;
uses SysUtils;
var
  S: string;
  I: Integer;
begin
  S := 'Hello';
  S := S + ' World';
  I := StrToInt('42');
  S := IntToStr(I);
end.
EOF

# Program with function calls
cat > "$TMPDIR/functions.pas" << 'EOF'
program functions;

function Add(A, B: Integer): Integer;
begin
  Result := A + B;
end;

function Fib(N: Integer): Integer;
begin
  if N <= 1 then
    Result := N
  else
    Result := Fib(N - 1) + Fib(N - 2);
end;

var
  X: Integer;
begin
  X := Add(10, 20);
  X := Fib(10);
end.
EOF

# Program with arrays and loops
cat > "$TMPDIR/arrays.pas" << 'EOF'
program arrays;
var
  Arr: array[0..99] of Integer;
  I, Sum: Integer;
begin
  for I := 0 to 99 do
    Arr[I] := I;
  Sum := 0;
  for I := 0 to 99 do
    Sum := Sum + Arr[I];
end.
EOF

# ── IR Quality Analysis ────────────────────────────────────────────

analyze_ir() {
  local ir_file="$1"
  local label="$2"

  if [ ! -f "$ir_file" ]; then
    echo "  $label: IR file not found"
    return
  fi

  local lines=$(wc -l < "$ir_file")
  local functions=$(grep -c '^[[:space:]]*define ' "$ir_file" 2>/dev/null || echo 0)
  local blocks=$(grep -c '^[[:alnum:]_]*:' "$ir_file" 2>/dev/null || echo 0)
  local instructions=$(grep -cE '^\s+%[a-z]|^\s+call |^\s+ret |^\s+br |^\s+store |^\s+load ' "$ir_file" 2>/dev/null || echo 0)
  local allocas=$(grep -c 'alloca' "$ir_file" 2>/dev/null || echo 0)
  local calls=$(grep -c 'call ' "$ir_file" 2>/dev/null || echo 0)

  echo "  $label: ${lines}L ${functions}F ${blocks}B ${instructions}I ${allocas}A ${calls}C"
}

# ── Compilation Time Measurement ───────────────────────────────────

measure_compile() {
  local source="$1"
  local target="$2"
  local label="$3"

  local start_ns=$(date +%s%N)
  "$STAGE0" build "$source" \
    --target "$target" \
    --workspace "$REPO_ROOT" >/dev/null 2>&1 || true
  local end_ns=$(date +%s%N)

  local elapsed_ms=$(( (end_ns - start_ns) / 1000000 ))
  echo "  $label: ${elapsed_ms}ms"
}

# ── Main ───────────────────────────────────────────────────────────

echo "=== D8 Compiler Performance Benchmark ==="
echo ""
echo "Date: $(date -Iseconds)"
echo "Stage0: $STAGE0"
echo ""

# Compilation time for each program on each target
echo "--- Compilation Time (wall clock) ---"
echo ""

for target in linux-x86_64 linux-aarch64 windows-x86_64 freebsd-x86_64; do
  echo "Target: $target"
  for prog in simple arith control strings functions arrays; do
    measure_compile "$TMPDIR/$prog.pas" "$target" "$prog"
  done
  echo ""
done

# IR quality analysis
echo "--- LLVM IR Quality Metrics ---"
echo ""
echo "Format: Lines Functions Blocks Instructions Allocas Calls"
echo ""

for target in linux-aarch64 windows-x86_64 freebsd-x86_64; do
  echo "Target: $target"
  for prog in simple arith control strings functions arrays; do
    ir_file="$REPO_ROOT/.nextpas/cache/backend/$target/$prog.ll"
    if [ -f "$ir_file" ]; then
      analyze_ir "$ir_file" "$prog"
    else
      echo "  $prog: no IR (may need recompilation)"
    fi
  done
  echo ""
done

# Cross-target IR comparison for the most complex program
echo "--- Cross-target IR Comparison (functions.pas) ---"
echo ""

for target in linux-aarch64 windows-x86_64 freebsd-x86_64; do
  ir_file="$REPO_ROOT/.nextpas/cache/backend/$target/functions.ll"
  if [ -f "$ir_file" ]; then
    echo "=== $target ==="
    cat "$ir_file"
    echo ""
  fi
done

echo "=== Benchmark Complete ==="
