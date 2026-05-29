#!/bin/bash
# Run all compiled tests and generate summary report

echo "========================================="
echo "fafafa.ssl Test Suite Runner"
echo "========================================="
echo ""

TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Find all test binaries
TEST_BINARIES=$(find bin -name "test_*" -type f -executable 2>/dev/null)

if [ -z "$TEST_BINARIES" ]; then
    echo "No test binaries found in bin/"
    exit 1
fi

echo "Found $(echo "$TEST_BINARIES" | wc -l) test binaries"
echo ""

# Run each test
for TEST in $TEST_BINARIES; do
    TEST_NAME=$(basename "$TEST")
    echo "Running: $TEST_NAME"
    echo "----------------------------------------"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    if timeout 30s "$TEST" > /tmp/test_output_$$.txt 2>&1; then
        echo "✓ PASSED"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        EXIT_CODE=$?
        echo "✗ FAILED (exit code: $EXIT_CODE)"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        echo "Output:"
        tail -20 /tmp/test_output_$$.txt
    fi
    
    echo ""
    rm -f /tmp/test_output_$$.txt
done

# Print summary
echo "========================================="
echo "Test Summary"
echo "========================================="
echo "Total tests:  $TOTAL_TESTS"
echo "Passed:       $PASSED_TESTS"
echo "Failed:       $FAILED_TESTS"
echo "Pass rate:    $(awk "BEGIN {printf \"%.1f%%\", ($PASSED_TESTS/$TOTAL_TESTS)*100}")"
echo "========================================="

if [ $FAILED_TESTS -gt 0 ]; then
    exit 1
fi

exit 0
