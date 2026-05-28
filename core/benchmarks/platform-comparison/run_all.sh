#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CORE_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
RESULTS="$SCRIPT_DIR/results.tsv"

echo "=== Platform Comparison Benchmark ==="
echo "Building all implementations..."
echo ""

# Setup test files
echo "x" > /tmp/bench_exists_test.txt
dd if=/dev/zero of=/tmp/bench_mmap_1mb.dat bs=4096 count=256 2>/dev/null

# Build nextpas
echo "[1/4] Building nextPas platform..."
mkdir -p "$SCRIPT_DIR/nextpas/build"
fpc -MObjFPC -Sh -O2 \
  -FU"$SCRIPT_DIR/nextpas/build" -FE"$SCRIPT_DIR/nextpas/build" \
  -Fu"$CORE_ROOT/src" -Fi"$CORE_ROOT/src" \
  "$SCRIPT_DIR/nextpas/bench_compare.lpr" >/dev/null 2>&1

# Build FPC RTL
echo "[2/4] Building FPC RTL..."
mkdir -p "$SCRIPT_DIR/fpc_rtl/build"
fpc -MObjFPC -Sh -O2 \
  -FU"$SCRIPT_DIR/fpc_rtl/build" -FE"$SCRIPT_DIR/fpc_rtl/build" \
  "$SCRIPT_DIR/fpc_rtl/bench_compare.lpr" >/dev/null 2>&1

# Build Go
echo "[3/4] Building Go..."
cd "$SCRIPT_DIR/go"
go build -o bench_compare bench_compare.go >/dev/null 2>&1
cd "$SCRIPT_DIR"

# Build Rust
echo "[4/4] Building Rust..."
cd "$SCRIPT_DIR/rust"
cargo build --release --quiet 2>/dev/null
cd "$SCRIPT_DIR"

echo ""
echo "Running benchmarks..."
echo ""

# Run all and collect results
> "$RESULTS"
echo "operation	impl	iterations	ns_per_op" >> "$RESULTS"

"$SCRIPT_DIR/nextpas/build/bench_compare" | tail -n +2 >> "$RESULTS"
"$SCRIPT_DIR/fpc_rtl/build/bench_compare" | tail -n +2 >> "$RESULTS"
"$SCRIPT_DIR/go/bench_compare" | tail -n +2 >> "$RESULTS"
"$SCRIPT_DIR/rust/target/release/bench_compare" | tail -n +2 >> "$RESULTS" 2>/dev/null || true

# Cleanup
rm -f /tmp/bench_exists_test.txt /tmp/bench_mmap_1mb.dat

# Print formatted results
echo "=== Results (ns/op, lower is better) ==="
echo ""
printf "%-16s %10s %10s %10s %10s\n" "operation" "nextpas" "fpc_rtl" "go" "rust"
printf "%-16s %10s %10s %10s %10s\n" "--------" "-------" "-------" "--" "----"

for op in path_join path_basename file_exists mmap_open_close random_32B; do
  np=$(grep "^${op}	nextpas" "$RESULTS" | cut -f4)
  fpc=$(grep "^${op}	fpc_rtl" "$RESULTS" | cut -f4)
  go_v=$(grep "^${op}	go" "$RESULTS" | cut -f4)
  rs=$(grep "^${op}	rust" "$RESULTS" | cut -f4)
  printf "%-16s %10s %10s %10s %10s\n" "$op" "${np:-n/a}" "${fpc:-n/a}" "${go_v:-n/a}" "${rs:-n/a}"
done

echo ""
echo "Raw data: $RESULTS"
