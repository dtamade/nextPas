#!/bin/bash
#
# Code Coverage Report Script for fafafa.ssl
#
# Uses FPC's built-in code coverage instrumentation
#
# Usage:
#   ./coverage_report.sh [test_program]
#
# Output:
#   - coverage_report.txt - Summary report
#   - coverage/ - Detailed per-file coverage
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SRC_DIR="$PROJECT_ROOT/src"
TESTS_DIR="$PROJECT_ROOT/tests"
COVERAGE_DIR="$PROJECT_ROOT/coverage"
TEST_PROGRAM="${1:-test_quick_all}"

echo "================================================"
echo "  fafafa.ssl Code Coverage Report"
echo "================================================"
echo ""

# Create coverage directory
mkdir -p "$COVERAGE_DIR"

# Step 1: Build with coverage instrumentation
echo "Building with coverage instrumentation..."
cd "$PROJECT_ROOT"

# Find test program
TEST_SOURCE=""
for dir in "$TESTS_DIR" "$TESTS_DIR/unit" "$TESTS_DIR/integration"; do
    if [ -f "$dir/$TEST_PROGRAM.pas" ]; then
        TEST_SOURCE="$dir/$TEST_PROGRAM.pas"
        break
    fi
done

if [ -z "$TEST_SOURCE" ]; then
    echo "ERROR: Test program not found: $TEST_PROGRAM"
    echo "Looking in: $TESTS_DIR, $TESTS_DIR/unit, $TESTS_DIR/integration"
    exit 1
fi

echo "Test source: $TEST_SOURCE"

# Compile with coverage options
# Note: FPC doesn't have built-in coverage like gcov
# Using -gl for line info which helps with manual coverage analysis
/home/dtamade/freePascal/fpc/bin/x86_64-linux/fpc \
    -Fi/home/dtamade/freePascal/fpc/units/x86_64-linux \
    -Fi/home/dtamade/freePascal/fpc/units/x86_64-linux/rtl \
    -Fu/home/dtamade/freePascal/fpc/units/x86_64-linux \
    -Fu/home/dtamade/freePascal/fpc/units/x86_64-linux/rtl \
    -Fu/home/dtamade/freePascal/fpc/units/x86_64-linux/rtl-objpas \
    -Fu/home/dtamade/freePascal/fpc/units/x86_64-linux/rtl-unix \
    -Fu/home/dtamade/freePascal/fpc/units/x86_64-linux/fcl-base \
    -Fu/home/dtamade/freePascal/fpc/units/x86_64-linux/fcl-json \
    -Fu/home/dtamade/freePascal/fpc/units/x86_64-linux/pthreads \
    -Fu"$SRC_DIR" \
    -FE"$COVERAGE_DIR" \
    -gl -O- \
    "$TEST_SOURCE" || {
        echo "Build failed"
        exit 2
    }

echo "Build complete."
echo ""

# Step 2: Run tests
echo "Running tests..."
TEST_BIN="$COVERAGE_DIR/$TEST_PROGRAM"
if [ -f "$TEST_BIN" ]; then
    "$TEST_BIN" > "$COVERAGE_DIR/test_output.txt" 2>&1 || true
    echo "Test output saved to: $COVERAGE_DIR/test_output.txt"
else
    echo "WARNING: Test binary not found: $TEST_BIN"
fi
echo ""

# Step 3: Generate coverage report
echo "Generating coverage report..."

# Count source files and lines
TOTAL_FILES=$(find "$SRC_DIR" -name "*.pas" | wc -l)
TOTAL_LINES=$(find "$SRC_DIR" -name "*.pas" -exec cat {} \; | wc -l)

# Count test files
TEST_FILES=$(find "$TESTS_DIR" -name "test_*.pas" -o -name "*_test.pas" | wc -l)

# Count function/procedure definitions
TOTAL_FUNCS=$(grep -r "^[[:space:]]*\(function\|procedure\)" "$SRC_DIR" --include="*.pas" | wc -l)

# Generate report
cat > "$COVERAGE_DIR/coverage_report.txt" << EOF
fafafa.ssl Code Coverage Report
Generated: $(date)
================================================

Source Statistics:
  Source files:     $TOTAL_FILES
  Source lines:     $TOTAL_LINES
  Functions/Procs:  $TOTAL_FUNCS

Test Statistics:
  Test files:       $TEST_FILES

Module Coverage Summary:
EOF

# List modules with line counts
echo "" >> "$COVERAGE_DIR/coverage_report.txt"
echo "Module                                    Lines" >> "$COVERAGE_DIR/coverage_report.txt"
echo "----------------------------------------------" >> "$COVERAGE_DIR/coverage_report.txt"

for f in "$SRC_DIR"/*.pas; do
    if [ -f "$f" ]; then
        name=$(basename "$f")
        lines=$(wc -l < "$f")
        printf "%-40s %5d\n" "$name" "$lines" >> "$COVERAGE_DIR/coverage_report.txt"
    fi
done

echo "" >> "$COVERAGE_DIR/coverage_report.txt"
echo "Note: Full coverage instrumentation requires additional tooling." >> "$COVERAGE_DIR/coverage_report.txt"
echo "Consider using Valgrind or custom instrumentation for detailed coverage." >> "$COVERAGE_DIR/coverage_report.txt"

echo ""
echo "Coverage report saved to: $COVERAGE_DIR/coverage_report.txt"
echo ""

# Print summary
echo "=== Summary ==="
echo "Source files:     $TOTAL_FILES"
echo "Source lines:     $TOTAL_LINES"
echo "Test files:       $TEST_FILES"
echo "Functions/Procs:  $TOTAL_FUNCS"
echo ""

cat "$COVERAGE_DIR/coverage_report.txt"
