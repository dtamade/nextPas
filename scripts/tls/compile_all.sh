#!/bin/bash
#
# compile_all.sh - Compile all fafafa.ssl Pascal sources
#
# Usage: ./scripts/compile_all.sh
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
SRC_DIR="$PROJECT_DIR/src"
TESTS_DIR="$PROJECT_DIR/tests"
OUTPUT_DIR="$TESTS_DIR/bin"

# Create output directories
mkdir -p "$OUTPUT_DIR"
mkdir -p "$TESTS_DIR/security/bin"
mkdir -p "$TESTS_DIR/integration/bin"
mkdir -p "$TESTS_DIR/http/bin"
mkdir -p "$TESTS_DIR/framework/bin"

# Verbose mode
VERBOSE=${VERBOSE:-0}

# Find FPC
FPC=$(which fpc 2>/dev/null || echo "/home/dtamade/freePascal/fpc/bin/x86_64-linux/fpc")

if [ ! -x "$FPC" ]; then
    echo "ERROR: Free Pascal compiler not found"
    exit 1
fi

echo "Using FPC: $FPC"
echo "FPC Version: $($FPC -iV)"
echo ""

# FPC unit paths
FPC_UNITS="/home/dtamade/freePascal/fpc/units/x86_64-linux"

# Compiler flags with full unit paths
FPC_FLAGS="-Fu$SRC_DIR -Fu$OUTPUT_DIR"
FPC_FLAGS="$FPC_FLAGS -Fi$FPC_UNITS -Fi$FPC_UNITS/rtl -Fi$FPC_UNITS/rtl-objpas"
FPC_FLAGS="$FPC_FLAGS -Fu$FPC_UNITS -Fu$FPC_UNITS/rtl -Fu$FPC_UNITS/rtl-objpas"
FPC_FLAGS="$FPC_FLAGS -Fu$FPC_UNITS/fcl-base -Fu$FPC_UNITS/rtl-console -Fu$FPC_UNITS/rtl-extra"
FPC_FLAGS="$FPC_FLAGS -Fu$FPC_UNITS/pthreads -Fu$FPC_UNITS/fcl-json -Fu$FPC_UNITS/fcl-fpcunit"
FPC_FLAGS="$FPC_FLAGS -Fu$FPC_UNITS/rtl-generics -Fu$FPC_UNITS/hash"
FPC_FLAGS="$FPC_FLAGS -FE$OUTPUT_DIR -O2"

# Track results
COMPILED=0
FAILED=0

# Compile source files
echo "=== Compiling source files ==="
for file in "$SRC_DIR"/*.pas; do
    if [ -f "$file" ]; then
        basename=$(basename "$file")
        echo -n "  Compiling $basename... "
        if $FPC $FPC_FLAGS "$file" > /dev/null 2>&1; then
            echo "OK"
            COMPILED=$((COMPILED + 1))
        else
            echo "FAILED"
            FAILED=$((FAILED + 1))
        fi
    fi
done

# Function to compile a test file
compile_test() {
    local file="$1"
    local outdir="$2"
    local basename=$(basename "$file")
    local TEST_FLAGS="-Fu$SRC_DIR -Fu$OUTPUT_DIR -Fu$TESTS_DIR/framework -Fu$TESTS_DIR/framework/bin"
    TEST_FLAGS="$TEST_FLAGS -Fi$FPC_UNITS -Fi$FPC_UNITS/rtl -Fi$FPC_UNITS/rtl-objpas"
    TEST_FLAGS="$TEST_FLAGS -Fu$FPC_UNITS -Fu$FPC_UNITS/rtl -Fu$FPC_UNITS/rtl-objpas"
    TEST_FLAGS="$TEST_FLAGS -Fu$FPC_UNITS/fcl-base -Fu$FPC_UNITS/rtl-console -Fu$FPC_UNITS/rtl-extra"
    TEST_FLAGS="$TEST_FLAGS -Fu$FPC_UNITS/pthreads -Fu$FPC_UNITS/fcl-json -Fu$FPC_UNITS/fcl-fpcunit"
    TEST_FLAGS="$TEST_FLAGS -Fu$FPC_UNITS/rtl-generics -Fu$FPC_UNITS/hash"
    TEST_FLAGS="$TEST_FLAGS -FE$outdir -O2"

    mkdir -p "$outdir"
    echo -n "  Compiling $basename... "
    if [ "$VERBOSE" = "1" ]; then
        if $FPC $TEST_FLAGS "$file"; then
            echo "OK"
            COMPILED=$((COMPILED + 1))
        else
            echo "FAILED"
            FAILED=$((FAILED + 1))
        fi
    else
        if $FPC $TEST_FLAGS "$file" > /dev/null 2>&1; then
            echo "OK"
            COMPILED=$((COMPILED + 1))
        else
            echo "FAILED"
            FAILED=$((FAILED + 1))
        fi
    fi
}

# Compile test framework first
echo ""
echo "=== Compiling test framework ==="
for file in "$TESTS_DIR"/framework/*.pas; do
    [ -f "$file" ] && compile_test "$file" "$TESTS_DIR/framework/bin"
done

# Compile test files
echo ""
echo "=== Compiling test files ==="
for file in "$TESTS_DIR"/*.pas; do
    [ -f "$file" ] && compile_test "$file" "$OUTPUT_DIR"
done

# Compile security tests
echo ""
echo "=== Compiling security tests ==="
for file in "$TESTS_DIR"/security/*.pas; do
    [ -f "$file" ] && compile_test "$file" "$TESTS_DIR/security/bin"
done

# Compile integration tests
echo ""
echo "=== Compiling integration tests ==="
for file in "$TESTS_DIR"/integration/*.pas; do
    [ -f "$file" ] && compile_test "$file" "$TESTS_DIR/integration/bin"
done

# Compile HTTP tests
echo ""
echo "=== Compiling HTTP tests ==="
for file in "$TESTS_DIR"/http/*.pas; do
    [ -f "$file" ] && compile_test "$file" "$TESTS_DIR/http/bin"
done

# Summary
echo ""
echo "=== Compilation Summary ==="
echo "Compiled: $COMPILED"
echo "Failed:   $FAILED"

# In CI mode, don't fail on compilation errors (some files need platform-specific libs)
if [ -n "$CI" ]; then
    echo ""
    echo "CI mode: Compilation errors are non-fatal"
    exit 0
fi

if [ $FAILED -gt 0 ]; then
    exit 1
fi

exit 0
