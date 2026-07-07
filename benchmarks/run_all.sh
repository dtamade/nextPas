#!/bin/bash
# Cross-language benchmark runner

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_DIR="$SCRIPT_DIR/results"
mkdir -p "$RESULTS_DIR"

echo "=== Cross-Language Benchmark Suite ==="
echo "Date: $(date)"
echo ""

# Pascal
echo ">>> Building and running Pascal benchmark..."
cd "$SCRIPT_DIR/pascal"
fpc -O2 -o../build/pascal_bench bench_cross_language.lpr 2>/dev/null
./../build/pascal_bench > "$RESULTS_DIR/pascal.txt" 2>&1
echo "Pascal: OK"

# Go
echo ">>> Building and running Go benchmark..."
cd "$SCRIPT_DIR/go"
go build -o ../build/go_bench main.go
./../build/go_bench > "$RESULTS_DIR/go.txt" 2>&1
echo "Go: OK"

# Rust
echo ">>> Building and running Rust benchmark..."
cd "$SCRIPT_DIR/rust"
cargo build --release 2>/dev/null
./target/release/benchmarks > "$RESULTS_DIR/rust.txt" 2>&1
echo "Rust: OK"

# C
echo ">>> Building and running C benchmark..."
cd "$SCRIPT_DIR/c"
gcc -O2 -o ../build/c_bench main.c -lm
./../build/c_bench > "$RESULTS_DIR/c.txt" 2>&1
echo "C: OK"

echo ""
echo "=== Results ==="
for lang in pascal go rust c; do
    if [ -f "$RESULTS_DIR/$lang.txt" ]; then
        echo ""
        echo "--- $lang ---"
        cat "$RESULTS_DIR/$lang.txt"
    fi
done

echo ""
echo "=== Comparison Table ==="
echo ""
printf "%-20s | %-15s | %-15s | %-15s | %-15s\n" "Benchmark" "Pascal" "Go" "Rust" "C"
printf "%-20s-+-%-15s-+-%-15s-+-%-15s-+-%-15s\n" "--------------------" "---------------" "---------------" "---------------" "---------------"

for bench in "Fibonacci(20)" "Sorting(1000)" "StringConcat(100)" "MemoryAlloc(100)"; do
    pascal_ns=$(grep "$bench" "$RESULTS_DIR/pascal.txt" 2>/dev/null | grep -oP 'Mean=\K[0-9]+' || echo "N/A")
    go_ns=$(grep "$bench" "$RESULTS_DIR/go.txt" 2>/dev/null | grep -oP 'Mean=\K[0-9]+' || echo "N/A")
    rust_ns=$(grep "$bench" "$RESULTS_DIR/rust.txt" 2>/dev/null | grep -oP 'Mean=\K[0-9]+' || echo "N/A")
    c_ns=$(grep "$bench" "$RESULTS_DIR/c.txt" 2>/dev/null | grep -oP 'Mean=\K[0-9]+' || echo "N/A")
    printf "%-20s | %-15s | %-15s | %-15s | %-15s\n" "$bench" "${pascal_ns} ns" "${go_ns} ns" "${rust_ns} ns" "${c_ns} ns"
done

echo ""
echo "Done."
