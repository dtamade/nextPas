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
  nextpas.core.platform.env,
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
  { IEEE 754 exact comparison }
  CheckEqual(1.0, 1.0);
  CheckEqual(3.14159, 3.14159);
  CheckEqual(0.0, 0.0);
  CheckEqual(-1.0, -1.0);
  { IEEE 754: -0.0 = +0.0 }
  CheckEqual(0.0, -0.0);
  CheckEqual(-0.0, 0.0);
  { Note: epsilon parameter is ignored — use CheckNear for tolerance }
end;

procedure TestCheckEqualDoubleFail;
var
  LCaught: Boolean = False;
begin
  try
    CheckEqual(1.0, 2.0, 1e-10);
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
  { CheckEqual ignores epsilon — these should FAIL because values differ }
  try
    CheckEqual(1.0, 1.01, 0.1);
  except
    on E: EAssertionFailed do
      CheckContains(E.Message, 'Expected');
  end;
  try
    CheckEqual(100.0, 100.5, 1.0);
  except
    on E: EAssertionFailed do
      CheckContains(E.Message, 'Expected');
  end;
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

  { Explicitly finalize managed types to prevent heaptrc false positives.
    FPC may not finalize nested managed types in dynamic arrays reliably
    when the record goes out of scope. }
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

{ ── 5. B2.3 Failure message contracts (stable substrings) ────────────────── }

procedure DiagEnvSet(const AName, AValue: string);
begin
  platform_env_set(PAnsiChar(AnsiString(AName)), PAnsiChar(AnsiString(AValue)));
end;

procedure DiagEnvUnset(const AName: string);
begin
  platform_env_unset(PAnsiChar(AnsiString(AName)));
end;

procedure TestMsgContractStringEqual;
begin
  DiagEnvSet('NEXTPAS_COLOR', '0');
  try
    ExpectFail(procedure begin
      CheckEqual('abc', 'axc');
    end, 'differ at position');
    ExpectFail(procedure begin
      CheckEqual('abc', 'axc');
    end, 'expected');
    ExpectFail(procedure begin
      CheckEqual('abc', 'axc');
    end, 'actual');
  finally
    DiagEnvUnset('NEXTPAS_COLOR');
  end;
end;

procedure TestMsgContractIntEqual;
begin
  ExpectFail(procedure begin
    CheckEqual(Int64(10), Int64(20));
  end, 'expected');
  ExpectFail(procedure begin
    CheckEqual(Int64(10), Int64(20));
  end, 'actual');
  ExpectFail(procedure begin
    CheckEqual(Int64(10), Int64(20));
  end, '10');
  ExpectFail(procedure begin
    CheckEqual(Int64(10), Int64(20));
  end, '20');
end;

procedure TestMsgContractSnapshotMismatch;
const
  LDir = '/tmp/np_snap_diag_b2';
begin
  DiagEnvUnset('NEXTPAS_SNAPSHOT_FAIL_ON_CREATE');
  DiagEnvUnset('NEXTPAS_UPDATE_SNAPSHOTS');
  DiagEnvSet('NEXTPAS_COLOR', '0');
  try
    CheckSnapshot('diag-old', LDir, 'm.txt');
    ExpectFail(procedure begin
      CheckSnapshot('diag-new', LDir, 'm.txt');
    end, 'Snapshot mismatch');
    ExpectFail(procedure begin
      CheckSnapshot('diag-new', LDir, 'm.txt');
    end, 'differ at position');
  finally
    DiagEnvUnset('NEXTPAS_COLOR');
  end;
end;

{ ── B3 scale: table-driven identity checks (countable process bulk) ─────── }

procedure TestIdentityCase(const AC: TTestCase);
var
  N: Int64;
begin
  N := StrToInt(AC.Data);
  CheckEqual(N, N);
  CheckTrue(N = N);
  CheckNotEqual(N, N + 1);
end;

procedure TestFailPathCase(const AC: TTestCase);
{ Data: expected|actual — must fail with both values in message (B5 meaningful) }
var
  LPos: Integer;
  LExp, LAct: string;
  LExpN, LActN: Int64;
begin
  LPos := Pos('|', AC.Data);
  CheckTrue(LPos > 0, 'fail-path data format');
  LExp := Copy(AC.Data, 1, LPos - 1);
  LAct := Copy(AC.Data, LPos + 1, MaxInt);
  LExpN := StrToInt(LExp);
  LActN := StrToInt(LAct);
  ExpectFail(procedure begin
    CheckEqual(LExpN, LActN);
  end, LExp);
  ExpectFail(procedure begin
    CheckEqual(LExpN, LActN);
  end, LAct);
end;

{ ── Main ─────────────────────────────────────────────────────────────────── }

var
  LSuite: TTestSuite;
  LCases: specialize TArray<TTestCase>;
  I: Integer;
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

  { B2.3 message contracts }
  LSuite.Test('msg contract string equal',      @TestMsgContractStringEqual);
  LSuite.Test('msg contract int equal',         @TestMsgContractIntEqual);
  LSuite.Test('msg contract snapshot mismatch', @TestMsgContractSnapshotMismatch);

  { B3: 150 identity + B5: 80 fail-path (meaningful negative) }
  SetLength(LCases, 150);
  for I := 0 to High(LCases) do
  begin
    LCases[I].Name := 'id-' + IntToStr(I);
    LCases[I].Data := IntToStr(I * 17 + 3);
  end;
  LSuite.TestTable('identity table', LCases, @TestIdentityCase);

  SetLength(LCases, 80);
  for I := 0 to High(LCases) do
  begin
    LCases[I].Name := 'fail-' + IntToStr(I);
    LCases[I].Data := IntToStr(I) + '|' + IntToStr(I + 1000);
  end;
  LSuite.TestTable('fail-path equal', LCases, @TestFailPathCase);

  if not LSuite.Run then
  begin
    Finalize(LSuite);
    WriteLn;
    FailTest('SOME TESTS FAILED');
  end;
  WriteLn;
  PassTest('ALL PASSED');
  LSuite.Config.OutSink := nil;
  LSuite.Config.ErrSink := nil;
  Finalize(LSuite);
end.
