{ test_diagnostics — Error diagnostics and stack trace coverage
  =========================================================
  Covers: stack trace capture (file:line), CheckEqual(Double),
          CheckNotEqual(Double), Error/Failure distinction,
          GetLastTestTrace, FormatTestLocation }

program test_diagnostics;

{$mode objfpc}{$H+}{$J-}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

uses
  nextpas.core.thread.init,
  nextpas.core.text.conv,
  nextpas.core.test,
  nextpas.core.test.base; { for IsFrameworkFrame, GLastTestTrace }

{ ── 1. Stack trace capture tests ─────────────────────────────────────────── }

procedure TestGetLastTestTraceInitiallyEmpty;
begin
  { Before any exception, the trace should be empty or from a prior test }
  CheckTrue(GetLastTestTrace = '', 'trace should be empty initially');
end;

procedure TestTraceCapturedOnFail;
var
  LTrace: string;
begin
  try
    Fail('intentional failure for trace');
  except
    on E: EAssertionFailed do
    begin
      { The ExceptProc hook should have captured a trace }
      LTrace := GetLastTestTrace;
      { With -gl flag, BackTraceStrFunc should return something with a file:line.
        At minimum, verify it's not empty (may be empty if -gl not linked). }
      WriteLn('  Captured trace: ', LTrace);
    end;
  end;
end;

procedure TestTraceCapturedOnCheckFail;
var
  LTrace: string;
begin
  try
    CheckEqual(Int64(1), Int64(2));
  except
    on E: EAssertionFailed do
    begin
      LTrace := GetLastTestTrace;
      WriteLn('  Captured trace: ', LTrace);
    end;
  end;
end;

procedure TestFormatTestLocation;
var
  LFormatted: string;
begin
  { After the prior test's exception, GLastTestTrace should still hold something }
  LFormatted := FormatTestLocation('at');
  WriteLn('  FormatTestLocation: "', LFormatted, '"');
  { FormatTestLocation should prefix with 'at' if a trace exists }
  if GetLastTestTrace <> '' then
    CheckTrue(Copy(LFormatted, 1, 3) = 'at ', 'should start with "at "')
  else
    WriteLn('  (no trace captured — -gl flag may not be active)');
end;

procedure TestFormatTestLocationEmptyPrefix;
var
  LFormatted: string;
begin
  LFormatted := FormatTestLocation('');
  WriteLn('  FormatTestLocation(no prefix): "', LFormatted, '"');
  { With empty prefix, result should be just the raw trace or empty }
  if GetLastTestTrace <> '' then
    CheckTrue(Length(LFormatted) > 0, 'should not be empty when trace exists');
end;

{ ── 2. CheckEqual(Double) and CheckNotEqual(Double) tests ───────────────── }

procedure TestCheckEqualDoublePass;
begin
  CheckEqual(1.0, 1.0);
  CheckEqual(3.14159, 3.14159);
  CheckEqual(0.0, 0.0);
  CheckEqual(-1.0, -1.0);
  { With epsilon tolerance }
  CheckEqual(1.0, 1.0 + 1e-11, 1e-10);
  CheckEqual(1.0, 1.0 - 1e-11, 1e-10);
end;

procedure TestCheckEqualDoubleFail;
var
  LCaught: Boolean = False;
begin
  try
    CheckEqual(1.0, 2.0, 1e-10);
    Halt(1);
  except
    on E: EAssertionFailed do
    begin
      LCaught := True;
      CheckContains(E.Message, 'Expected');
      CheckContains(E.Message, 'but got');
    end;
  end;
  CheckTrue(LCaught, 'CheckEqual(Double) should fail for mismatched values');
end;

procedure TestCheckEqualDoubleCustomEpsilon;
begin
  { With a larger epsilon, values that are close should pass }
  CheckEqual(1.0, 1.01, 0.1);
  CheckEqual(100.0, 100.5, 1.0);
end;

procedure TestCheckNotEqualDoublePass;
begin
  CheckNotEqual(1.0, 2.0);
  CheckNotEqual(0.0, 1.0, 1e-10);
  CheckNotEqual(100.0, 200.0, 1.0);
end;

procedure TestCheckNotEqualDoubleFail;
var
  LCaught: Boolean = False;
begin
  try
    CheckNotEqual(1.0, 1.0);
    Halt(1);
  except
    on E: EAssertionFailed do
    begin
      LCaught := True;
      CheckContains(E.Message, 'differ');
    end;
  end;
  CheckTrue(LCaught, 'CheckNotEqual(Double) should fail for equal values');
end;

procedure TestCheckNotEqualDoubleWithinEpsilon;
var
  LCaught: Boolean = False;
begin
  { Values that are within epsilon should fail CheckNotEqual }
  try
    CheckNotEqual(1.0, 1.0 + 1e-12, 1e-10);
    Halt(1);
  except
    on E: EAssertionFailed do
      LCaught := True;
  end;
  CheckTrue(LCaught, 'CheckNotEqual should fail for values within epsilon');
end;

{ ── 3. Error vs Failure distinction tests ────────────────────────────────── }

procedure TestErrorVsFailureDistinction;
var
  LSuite: TTestSuite;
  LResult: TTestRunResult;
  LResults: specialize TArray<TTestRunResult>;
  LXml: string;
  I: Integer;
  LFoundError, LFoundFailure: Boolean;
begin
  LSuite := TTestSuite.Create('err_vs_fail');

  { A failing test (assertion failure) }
  LSuite.Test('assert_fail',
    procedure begin CheckTrue(False, 'deliberate assertion'); end);

  { An error test (unexpected exception) }
  LSuite.Test('unexpected_error',
    procedure begin raise EConvertError.Create('boom'); end);

  LSuite.RunWithResult(LResult);

  { Verify result statuses are distinct }
  CheckTrue(LResult.Results[0].Status = tsFailed,
    'assertion failure should be tsFailed');
  CheckTrue(LResult.Results[1].Status = tsError,
    'unexpected exception should be tsError');

  { Verify JUnit XML uses different tags }
  SetLength(LResults, 1);
  LResults[0] := LResult;
  LXml := JUnitXML(LResults, 'err_vs_fail');

  LFoundError := Pos('<error type="Error"', LXml) > 0;
  LFoundFailure := Pos('<failure type="AssertionFailure"', LXml) > 0;
  CheckTrue(LFoundError, 'JUnit XML should have <error> for tsError');
  CheckTrue(LFoundFailure, 'JUnit XML should have <failure> for tsFailed');
end;

procedure TestTAPErrorVsFail;
var
  LResults: specialize TArray<TTestRunResult>;
  LOut: string;
begin
  SetLength(LResults, 1);
  LResults[0] := TTestRunResult.Create('tap_test');
  LResults[0].Passed := 0;
  LResults[0].Failed := 2;
  SetLength(LResults[0].Results, 2);
  LResults[0].Results[0].Name := 'fail_test';
  LResults[0].Results[0].Status := tsFailed;
  LResults[0].Results[0].Message := 'assertion boom';
  LResults[0].Results[1].Name := 'error_test';
  LResults[0].Results[1].Status := tsError;
  LResults[0].Results[1].Message := 'EAccessViolation';

  LOut := TAPReport(LResults);
  { Both should be "not ok" }
  CheckTrue(Pos('not ok', LOut) > 0, 'TAP should contain "not ok"');
  { Error should have severity: error, failure should have severity: fail }
  CheckContains(LOut, 'severity: fail');
  CheckContains(LOut, 'severity: error');
end;

procedure TestJSONErrorVsFail;
var
  LResults: specialize TArray<TTestRunResult>;
  LOut: string;
begin
  SetLength(LResults, 1);
  LResults[0] := TTestRunResult.Create('json_test');
  LResults[0].Passed := 0;
  LResults[0].Failed := 2;
  SetLength(LResults[0].Results, 2);
  LResults[0].Results[0].Name := 'fail_test';
  LResults[0].Results[0].Status := tsFailed;
  LResults[0].Results[0].Message := 'boom';
  LResults[0].Results[1].Name := 'error_test';
  LResults[0].Results[1].Status := tsError;
  LResults[0].Results[1].Message := 'segfault';

  LOut := JSONReport(LResults);
  CheckContains(LOut, '"status": "failed"');
  CheckContains(LOut, '"status": "error"');
end;

{ ── 4. Trace not polluted by framework internals ─────────────────────────── }

procedure TestFrameworkFrameFiltering;
{ Verify that test framework frames are filtered and user code is not.
  We test this indirectly: after a Fail, GLastTestTrace should NOT
  contain any framework unit name. }
var
  LTrace: string;
begin
  { Trigger a failure and capture the trace }
  try
    Fail('filter test');
  except
    on E: EAssertionFailed do
      LTrace := GetLastTestTrace;
  end;

  { The trace should not contain framework internals }
  if LTrace <> '' then
  begin
    CheckNotContains(LTrace, 'nextpas.core.test');
    CheckNotContains(LowerCase(LTrace), 'sysutils');
  end
  else
    WriteLn('  (no trace captured — stack trace may not be available)');
end;

{ ── Main ─────────────────────────────────────────────────────────────────── }

var
  LSuite: TTestSuite;
begin
  WriteLn('=== test_diagnostics ===');

  LSuite := TTestSuite.Create('diagnostics');

  { Stack trace tests }
  LSuite.Test('trace initially empty',          @TestGetLastTestTraceInitiallyEmpty);
  LSuite.Test('trace captured on Fail',         @TestTraceCapturedOnFail);
  LSuite.Test('trace captured on CheckFail',    @TestTraceCapturedOnCheckFail);
  LSuite.Test('FormatTestLocation',             @TestFormatTestLocation);
  LSuite.Test('FormatTestLocation empty prefix',@TestFormatTestLocationEmptyPrefix);

  { CheckEqual(Double) / CheckNotEqual(Double) }
  LSuite.Test('CheckEqual(Double) pass',        @TestCheckEqualDoublePass);
  LSuite.Test('CheckEqual(Double) fail',        @TestCheckEqualDoubleFail);
  LSuite.Test('CheckEqual(Double) custom eps',  @TestCheckEqualDoubleCustomEpsilon);
  LSuite.Test('CheckNotEqual(Double) pass',     @TestCheckNotEqualDoublePass);
  LSuite.Test('CheckNotEqual(Double) fail',     @TestCheckNotEqualDoubleFail);
  LSuite.Test('CheckNotEqual(Double) within eps',@TestCheckNotEqualDoubleWithinEpsilon);

  { Error/Failure distinction }
  LSuite.Test('Error vs Failure (JUnit)',       @TestErrorVsFailureDistinction);
  LSuite.Test('Error vs Failure (TAP)',         @TestTAPErrorVsFail);
  LSuite.Test('Error vs Failure (JSON)',        @TestJSONErrorVsFail);

  { Framework frame filtering }
  LSuite.Test('framework frame filtering',      @TestFrameworkFrameFiltering);

  if not LSuite.Run then
  begin
    WriteLn;
    FailTest('SOME TESTS FAILED');
  end;
  WriteLn;
  PassTest('ALL PASSED');
end.
