#!/usr/bin/env bash
# Go/Rust maintainability bar: key TTestSuite / runner / CLI names must
# appear in self-tests (prevents dead public surface).
set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
CORE_ROOT="$(CDPATH= cd -- "$SCRIPT_DIR/../../.." && pwd)"
TESTS="$CORE_ROOT/tests/nextpas.core.test"

fail=0
must_have=(
  TestSeq
  RunParallel
  RunParallelWithResult
  RunWithResult
  TestTable
  TestSubtest
  ShouldFail
  Cleanup
  OnBeforeEach
  OnAfterEach
  SetTestFilter
  SetTestTimeout
  MatchesFilter
  DiscoverTests
  TSuiteRunner
  RunAllWithResult
  RunAllParallel
  WriteJUnitXML
  JSONReport
  TAPReport
  CheckSnapshot
  Prop
  Fuzz
)

echo "=== Runner/public API name presence in self-tests ==="
for name in "${must_have[@]}"; do
  if ! rg -q --fixed-strings "$name" "$TESTS" --glob '*.lpr' --glob '*.pas' --glob '*.sh'; then
    echo "MISSING: $name"
    fail=1
  else
    echo "OK: $name"
  fi
done

if [[ "$fail" -ne 0 ]]; then
  echo "FAIL: runner/public surface not referenced in self-tests"
  exit 1
fi
echo "PASS: runner/public source contracts"
exit 0
