#!/bin/bash
#
# run_security_tests.sh - Run all security tests
#
# These tests verify security properties of the SSL/TLS implementation.
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
TESTS_DIR="$PROJECT_DIR/tests/security"
BIN_DIR="$TESTS_DIR/bin"

echo "========================================"
echo "Running Security Tests"
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
        if timeout 120 "$test_path"; then
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

# Run security tests
run_test "test_certificate_pinning"
run_test "test_input_validation"
run_test "test_key_derivation_security"
run_test "test_memory_safety"
run_test "test_protocol_downgrade_prevention"
run_test "test_session_security"
run_test "test_tls_protocol_security"
run_test "test_weak_algorithm_detection"

# Summary
echo "========================================"
echo "Security Test Summary"
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
