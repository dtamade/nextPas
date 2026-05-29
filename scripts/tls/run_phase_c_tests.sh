#!/bin/bash
# Run Phase C Week 3-4 tests specifically

echo "========================================="
echo "Phase C Week 3-4 Test Suite"
echo "========================================="
echo ""

TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Define Phase C tests
TESTS=(
    "bin/test_security_attacks"
    "bin/test_phase5_complete_handshake"
    "bin/test_concurrent_connections"
)

for TEST in "${TESTS[@]}"; do
    if [ ! -f "$TEST" ]; then
        echo "⚠ Test not found: $TEST"
        continue
    fi
    
    if [ ! -x "$TEST" ]; then
        echo "⚠ Test not executable: $TEST"
        continue
    fi
    
    TEST_NAME=$(basename "$TEST")
    echo "Running: $TEST_NAME"
    echo "----------------------------------------"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    if timeout 30s "$TEST" > /tmp/test_output_$$.txt 2>&1; then
        EXIT_CODE=$?
        if [ $EXIT_CODE -eq 0 ]; then
            echo "✓ PASSED"
            PASSED_TESTS=$((PASSED_TESTS + 1))
        else
            echo "✗ FAILED (exit code: $EXIT_CODE)"
            FAILED_TESTS=$((FAILED_TESTS + 1))
            echo "Last 20 lines of output:"
            tail -20 /tmp/test_output_$$.txt
        fi
    else
        EXIT_CODE=$?
        echo "✗ FAILED (exit code: $EXIT_CODE)"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        echo "Last 20 lines of output:"
        tail -20 /tmp/test_output_$$.txt
    fi
    
    echo ""
    rm -f /tmp/test_output_$$.txt
done

# Print summary
echo "========================================="
echo "Phase C Test Summary"
echo "========================================="
echo "Total tests:  $TOTAL_TESTS"
echo "Passed:       $PASSED_TESTS"
echo "Failed:       $FAILED_TESTS"
if [ $TOTAL_TESTS -gt 0 ]; then
    echo "Pass rate:    $(awk "BEGIN {printf \"%.1f%%\", ($PASSED_TESTS/$TOTAL_TESTS)*100}")"
fi
echo "========================================="

if [ $FAILED_TESTS -gt 0 ]; then
    exit 1
fi

exit 0
