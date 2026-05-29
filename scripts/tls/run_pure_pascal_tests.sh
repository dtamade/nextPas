#!/bin/bash
#
# run_pure_pascal_tests.sh - Run all pure Pascal module tests
#
# These tests do not depend on OpenSSL or WinSSL and should work on any platform.
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
TESTS_DIR="$PROJECT_DIR/tests"
BIN_DIR="$TESTS_DIR/bin"

echo "========================================"
echo "Running Pure Pascal Module Tests"
echo "========================================"
echo ""

PASSED=0
FAILED=0
TOTAL=0

run_test() {
    local test_name=$1
    local test_path="$BIN_DIR/$test_name"

    if [ -x "$test_path" ]; then
        echo "--- $test_name ---"
        if "$test_path"; then
            PASSED=$((PASSED + 1))
        else
            FAILED=$((FAILED + 1))
        fi
        TOTAL=$((TOTAL + 1))
        echo ""
    elif [ -x "${test_path}.exe" ]; then
        echo "--- $test_name ---"
        if "${test_path}.exe"; then
            PASSED=$((PASSED + 1))
        else
            FAILED=$((FAILED + 1))
        fi
        TOTAL=$((TOTAL + 1))
        echo ""
    else
        echo "WARNING: $test_name not found, skipping"
    fi
}

# Run pure Pascal module tests
run_test "test_asn1"
run_test "test_x509"
run_test "test_pem"
run_test "test_hash"
run_test "test_ocsp"
run_test "test_crl"

# Summary
echo "========================================"
echo "Test Summary"
echo "========================================"
echo "Total:  $TOTAL"
echo "Passed: $PASSED"
echo "Failed: $FAILED"
echo ""

if [ $FAILED -gt 0 ]; then
    echo "RESULT: FAILED"
    exit 1
else
    echo "RESULT: ALL PASSED"
    exit 0
fi
