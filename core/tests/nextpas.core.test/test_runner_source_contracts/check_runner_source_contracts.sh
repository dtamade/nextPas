#!/usr/bin/env bash
# Go/Rust maintainability bar: key TTestSuite / runner / CLI names must
# appear in self-tests (prevents dead public surface).
# Also locks Windows/Darwin ABI choices that platform CI depends on.
set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
CORE_ROOT="$(CDPATH= cd -- "$SCRIPT_DIR/../../.." && pwd)"
TESTS="$CORE_ROOT/tests/nextpas.core.test"
RUNNER="$CORE_ROOT/src/nextpas.core.test.runner.pas"
EXPECT="$CORE_ROOT/src/nextpas.core.test.expect.pas"

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
  ApplyCLIArgsFrom
  Prop
  Fuzz
  SoftFail
  SoftCheckTrue
  SoftCheckEqual
  SoftCheckNear
  SoftFailOnly
)

echo "=== ComputeKey must hash stop-semantic config fields (v8.22+) ==="
CFG="$CORE_ROOT/src/nextpas.core.test.config.pas"
# Restrict to ComputeKey body: from function TTestCache.ComputeKey to next function
ck_body="$(awk '
  /function TTestCache\.ComputeKey/ { p=1 }
  p { print }
  p && /^function TTestCache\./ && !/ComputeKey/ { exit }
  p && /^procedure TTestCache\./ { exit }
' "$CFG")"
for field in ShuffleSeed FailFast MaxFailures ShortMode VerboseMode RetryCount \
  TimeoutMs FilterPattern TagFilter RunPattern; do
  if ! printf '%s\n' "$ck_body" | rg -q --fixed-strings "AConfig.$field"; then
    # SuiteName is a separate parameter, not AConfig
    if [[ "$field" == "SuiteName" ]]; then
      continue
    fi
    echo "MISSING in ComputeKey: AConfig.$field"
    fail=1
  else
    echo "OK: ComputeKey hashes AConfig.$field"
  fi
done
if ! printf '%s\n' "$ck_body" | rg -q --fixed-strings 'ASuiteName'; then
  echo "MISSING in ComputeKey: ASuiteName"
  fail=1
else
  echo "OK: ComputeKey hashes ASuiteName"
fi

echo "=== Nested SoftFail Push/Pop must appear in runner.context ==="
CTX="$CORE_ROOT/src/nextpas.core.test.runner.context.pas"
if ! rg -q --fixed-strings 'PushSoftFailState' "$CTX"; then
  echo "MISSING in runner.context: PushSoftFailState"
  fail=1
else
  echo "OK: PushSoftFailState in runner.context"
fi
if ! rg -q --fixed-strings 'PopSoftFailState' "$CTX"; then
  echo "MISSING in runner.context: PopSoftFailState"
  fail=1
else
  echo "OK: PopSoftFailState in runner.context"
fi

echo "=== Runner/public API name presence in self-tests ==="
for name in "${must_have[@]}"; do
  if ! rg -q --fixed-strings "$name" "$TESTS" --glob '*.lpr' --glob '*.pas' --glob '*.sh'; then
    echo "MISSING: $name"
    fail=1
  else
    echo "OK: $name"
  fi
done

echo "=== Darwin TThreadID + Windows IUnknown calling convention guards ==="
# Bare 0 vs TThreadID is ShortInt-incompatible on Darwin aarch64.
if rg -n 'LThreads\[I\]\s*(:=|=|<>)\s*0\b' "$RUNNER" >/dev/null; then
  echo "FAIL: bare 0 used with LThreads[] — use TThreadID(0) (Darwin aarch64)"
  fail=1
else
  echo "OK: LThreads uses TThreadID(0)"
fi
# Windows COM IUnknown methods must be stdcall; bare {$IFNDEF WINDOWS}cdecl
# leaves no convention on Windows and fails syntax.
if ! rg -q '\$IFDEF WINDOWS\}stdcall' "$EXPECT"; then
  echo "FAIL: TExpectationBase IUnknown must use stdcall on Windows"
  fail=1
else
  echo "OK: expect IUnknown stdcall on Windows"
fi
if rg -q '\$IFNDEF WINDOWS\}cdecl\{\$ENDIF\}' "$EXPECT"; then
  echo "FAIL: expect still has IFNDEF WINDOWS cdecl-only form (empty on Win)"
  fail=1
fi

if [[ "$fail" -ne 0 ]]; then
  echo "FAIL: runner/expect ABI source contracts"
  exit 1
fi
echo "PASS: runner/public source contracts"
exit 0
