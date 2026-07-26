{ test_advanced — RTTI discovery, retry, TAP/JSON output, mock
  ========================================================= }

program test_advanced;

{$mode objfpc}{$H+}{$J-}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}
{$M+}

uses
  nextpas.core.thread.init,
  nextpas.core.text.conv,
  nextpas.core.test,
  nextpas.core.test.helpers;

{ ── Fixtures and globals ──────────────────────────────────────────────────── }

type
  TDiscoveryFixture = class(TTestFixture)
  published
    procedure TestAlpha;
    procedure TestBeta;
  end;

  TEmptyFixture = class(TTestFixture)
  public
    procedure NotPublished;
  end;

  TTeardownFixture = class(TTestFixture)
  published
    procedure TestOne;
  end;

  TReportOutcome = (roPass, roFail, roSkip, roError);

var
  GDiscoveryAlphaCalled: Boolean = False;
  GDiscoveryBetaCalled: Boolean = False;
  GRetryCount: Integer = 0;
  GReportFailureMessage: string = '';
  GReportErrorMessage: string = '';

procedure TDiscoveryFixture.TestAlpha;
begin
  GDiscoveryAlphaCalled := True;
end;

procedure TDiscoveryFixture.TestBeta;
begin
  GDiscoveryBetaCalled := True;
end;

procedure TEmptyFixture.NotPublished;
begin
  { intentionally empty — should NOT be discovered }
end;

procedure TTeardownFixture.TestOne;
begin
  CheckTrue(True);
end;

procedure ReportPassProc;
begin
  CheckTrue(True);
end;

procedure ReportFailProc;
begin
  CheckTrue(False, GReportFailureMessage);
end;

procedure ReportErrorProc;
begin
  raise Exception.Create(GReportErrorMessage);
end;

{ ── RTTI Discovery Tests ──────────────────────────────────────────────────── }

procedure TestDiscoverFindsPublishedMethods;
var
  LFixture: TDiscoveryFixture;
  LSuite: TTestSuite;
  LRunner: TSuiteRunner;
  LResults: specialize TArray<TTestRunResult>;
  LFoundAlpha, LFoundBeta: Boolean;
  I: Integer;
begin
  LFixture := TDiscoveryFixture.Create;
  LSuite := DiscoverTests(LFixture, 'DiscoveryTest');
  CheckEqual(2, Length(LSuite.Tests));

  { Verify both methods discovered (order-independent — VMT table ordering
    is an FPC implementation detail, not a language guarantee) }
  LFoundAlpha := False;
  LFoundBeta  := False;
  for I := 0 to High(LSuite.Tests) do
  begin
    if LSuite.Tests[I].Name = 'TestAlpha' then LFoundAlpha := True;
    if LSuite.Tests[I].Name = 'TestBeta'  then LFoundBeta  := True;
  end;
  CheckTrue(LFoundAlpha, 'TestAlpha not discovered');
  CheckTrue(LFoundBeta,  'TestBeta not discovered');

  { Actually run them to verify dispatch works }
  LRunner := TSuiteRunner.Create('DiscoveryRunner');
  LRunner.Add(LSuite);
  LRunner.RunAllWithResult(LResults);
  CheckTrue(Length(LResults) > 0);
  CheckTrue(LResults[0].AllPassed);
  CheckTrue(GDiscoveryAlphaCalled);
  CheckTrue(GDiscoveryBetaCalled);
end;

procedure TestDiscoverDefaultSuiteName;
var
  LFixture: TDiscoveryFixture;
  LSuite: TTestSuite;
begin
  LFixture := TDiscoveryFixture.Create;
  LSuite := DiscoverTests(LFixture);  { default name = ClassName }
  CheckEqual('TDiscoveryFixture', LSuite.Name);
  { DiscoverTests always RegisterFixture (+ stubs for published methods).
    Suite owns them via registry; never Free the fixture manually. }
  LSuite.CleanupTableAllocations;
end;

procedure TestDiscoverNoPublished;
var
  LFixture: TEmptyFixture;
  LSuite: TTestSuite;
begin
  LFixture := TEmptyFixture.Create;
  LSuite := DiscoverTests(LFixture);
  CheckEqual(0, Length(LSuite.Tests));
  { DiscoverTests still RegisterFixture even when zero published methods.
    Manual Free would leave a dangling GFixtureRegistry entry and cause
    finalization double-free AV + heaptrc leaks for later safety-net frees. }
  LSuite.CleanupTableAllocations;
end;

{ ── Retry Tests ───────────────────────────────────────────────────────────── }

procedure FlakyThenPass;
begin
  Inc(GRetryCount);
  if GRetryCount < 3 then
    CheckTrue(False, 'intentional failure ' + IntToStr(GRetryCount));
end;

procedure TestRetryEventuallyPasses;
var
  LSuite: TTestSuite;
  LRunner: TSuiteRunner;
  LResults: specialize TArray<TTestRunResult>;
begin
  GRetryCount := 0;
  LSuite := TTestSuite.Create('RetryTest');
  LSuite.Test('flaky', @FlakyThenPass, 5);  { retry up to 5 times }
  LRunner := TSuiteRunner.Create('RetryRunner');
  LRunner.Add(LSuite);
  LRunner.RunAllWithResult(LResults);
  CheckTrue(LResults[0].AllPassed);
  CheckEqual(3, GRetryCount);  { failed 2 times, passed on 3rd }
end;

procedure AlwaysFail;
begin
  CheckTrue(False, 'always fails');
end;

procedure TestRetryExhausted;
var
  LSuite: TTestSuite;
  LRunner: TSuiteRunner;
  LResults: specialize TArray<TTestRunResult>;
begin
  LSuite := TTestSuite.Create('RetryExhaust');
  LSuite.Test('always_fail', @AlwaysFail, 2);  { retry 2 times, still fails }
  LRunner := TSuiteRunner.Create('RetryExhaustRunner');
  LRunner.Add(LSuite);
  LRunner.RunAllWithResult(LResults);
  CheckFalse(LResults[0].AllPassed);
  CheckEqual(1, LResults[0].Failed);
end;

procedure TestRetryZeroMeansNoRetry;
var
  LSuite: TTestSuite;
  LRunner: TSuiteRunner;
  LResults: specialize TArray<TTestRunResult>;
begin
  LSuite := TTestSuite.Create('RetryZero');
  LSuite.Test('simple', @AlwaysFail, 0);  { no retry }
  LRunner := TSuiteRunner.Create('RetryZeroRunner');
  LRunner.Add(LSuite);
  LRunner.RunAllWithResult(LResults);
  CheckFalse(LResults[0].AllPassed);
  CheckEqual(1, LResults[0].Failed);
end;

function RunSuiteAndGetResults(const ASuiteName, ATestName: string;
  AOutcome: TReportOutcome; const AMessage: string = ''): specialize TArray<TTestRunResult>;
var
  LSuite: TTestSuite;
  LRunner: TSuiteRunner;
begin
  LSuite := TTestSuite.Create(ASuiteName);
  case AOutcome of
    roPass:
      LSuite.Test(ATestName, @ReportPassProc);
    roFail:
      begin
        GReportFailureMessage := AMessage;
        LSuite.Test(ATestName, @ReportFailProc);
      end;
    roSkip:
      LSuite.Skip(ATestName, AMessage);
    roError:
      begin
        GReportErrorMessage := AMessage;
        LSuite.Test(ATestName, @ReportErrorProc);
      end;
  end;
  LRunner := TSuiteRunner.Create(ASuiteName + 'Runner');
  LRunner.Add(LSuite);
  LRunner.RunAllWithResult(Result);
end;

{ ── TAP Output Tests ──────────────────────────────────────────────────────── }

procedure TestTAPAllPassed;
var
  LResults: specialize TArray<TTestRunResult>;
  LTAP: string;
begin
  LResults := RunSuiteAndGetResults('MySuite', 'TestFoo', roPass);
  LTAP := TAPReport(LResults, 'MyTests');
  CheckContains(LTAP, 'TAP version 13');
  CheckContains(LTAP, '1..1');
  CheckContains(LTAP, 'ok 1 - MyTests / TestFoo');
  CheckContains(LTAP, '# total: 1');
  CheckContains(LTAP, '# passed: 1');
end;

procedure TestTAPWithFailure;
var
  LResults: specialize TArray<TTestRunResult>;
  LTAP: string;
begin
  LResults := RunSuiteAndGetResults('FailSuite', 'TestBar', roFail,
    'expected 5 got 3');
  LTAP := TAPReport(LResults);
  CheckContains(LTAP, 'not ok 1 - FailSuite / TestBar');
  CheckContains(LTAP, 'message: |-');
  CheckContains(LTAP, '    expected 5 got 3');
  CheckContains(LTAP, 'severity: fail');
end;

procedure TestTAPWithSkipped;
var
  LResults: specialize TArray<TTestRunResult>;
  LTAP: string;
begin
  LResults := RunSuiteAndGetResults('SkipSuite', 'TestSkipped', roSkip,
    'platform not supported');
  LTAP := TAPReport(LResults);
  CheckContains(LTAP, 'ok 1 - SkipSuite / TestSkipped # skip platform not supported');
  CheckContains(LTAP, '# skipped: 1');
end;

{ ── JSON Output Tests ─────────────────────────────────────────────────────── }

procedure TestJSONAllPassed;
var
  LResults: specialize TArray<TTestRunResult>;
  LJSON: string;
begin
  LResults := RunSuiteAndGetResults('JsonSuite', 'TestX', roPass);
  LJSON := JSONReport(LResults, 'JsonTests');
  CheckContains(LJSON, '"totalPassed": 1');
  CheckContains(LJSON, '"totalFailed": 0');
  CheckContains(LJSON, '"name": "JsonSuite"');
  CheckContains(LJSON, '"name": "TestX"');
  CheckContains(LJSON, '"status": "passed"');
  CheckContains(LJSON, '"allPassed": true');
end;

procedure TestJSONWithFailure;
var
  LResults: specialize TArray<TTestRunResult>;
  LJSON: string;
begin
  LResults := RunSuiteAndGetResults('JsonFail', 'TestFail', roFail,
    'assert failed');
  LJSON := JSONReport(LResults);
  CheckContains(LJSON, '"status": "failed"');
  CheckContains(LJSON, '"message": "assert failed"');
  CheckContains(LJSON, '"allPassed": false');
  CheckContains(LJSON, '"totalFailed": 1');
end;

procedure TestJSONEscapesQuotes;
var
  LResults: specialize TArray<TTestRunResult>;
  LJSON: string;
begin
  LResults := RunSuiteAndGetResults('Esc"ape', 'Test"Quote', roError,
    'line1' + #10 + 'line2');
  LJSON := JSONReport(LResults);
  CheckContains(LJSON, 'Esc\"ape');
  CheckContains(LJSON, 'Test\"Quote');
  CheckContains(LJSON, '\n');
end;

{ ── R6-53: Discovery fixture teardown verification ───────────────────────── }

procedure TestDiscoveryFixtureTeardown;
var
  LFixture: TTeardownFixture;
  LSuite: TTestSuite;
  LRunner: TSuiteRunner;
  LResults: specialize TArray<TTestRunResult>;
begin
  { R6-53: RTTI discovery + run, verifying fixture method dispatch works.
    White-box ownership note: the suite/runner cleanup path owns the fixture
    after DiscoverTests registration; never-run cases fall back to finalization.
    Teardown hook support is not yet in DiscoverTests API; this test verifies
    dispatch correctness only. }
  LFixture := TTeardownFixture.Create;
  LSuite := DiscoverTests(LFixture, 'TeardownTest');
  CheckTrue(Length(LSuite.Tests) > 0, 'Should discover at least 1 test');
  CheckEqual('TestOne', LSuite.Tests[0].Name);
  LRunner := TSuiteRunner.Create('TeardownRunner');
  LRunner.Add(LSuite);
  LRunner.RunAllWithResult(LResults);
  CheckTrue(Length(LResults) > 0);
  CheckTrue(LResults[0].AllPassed);
  CheckEqual(1, LResults[0].Passed);
end;

{ ── B12: advanced depth ───────────────────────────────────────────────────── }

type
  TFailDiscoverFixture = class(TTestFixture)
  published
    procedure TestBoom;
  end;

procedure TFailDiscoverFixture.TestBoom;
begin
  Fail('discover-fail-body');
end;

procedure TestB12DiscoverAndFail;
var
  LFixture: TFailDiscoverFixture;
  LSuite: TTestSuite;
  LRunner: TSuiteRunner;
  LResults: specialize TArray<TTestRunResult>;
begin
  LFixture := TFailDiscoverFixture.Create;
  LSuite := DiscoverTests(LFixture, 'FailDiscover');
  LRunner := TSuiteRunner.Create('FailDiscoverRunner');
  LRunner.Add(LSuite);
  LRunner.RunAllWithResult(LResults);
  CheckFalse(LResults[0].AllPassed);
  CheckEqual(1, LResults[0].Failed);
end;

procedure TestB12JSONErrorStatus;
var
  LResults: specialize TArray<TTestRunResult>;
  LJSON: string;
begin
  LResults := RunSuiteAndGetResults('ErrSuite', 'TestErr', roError, 'boom-err');
  LJSON := JSONReport(LResults);
  CheckContains(LJSON, '"status": "error"');
  CheckContains(LJSON, 'boom-err');
  CheckContains(LJSON, '"allPassed": false');
end;

procedure TestB12TAPErrorSeverity;
var
  LResults: specialize TArray<TTestRunResult>;
  LTAP: string;
begin
  LResults := RunSuiteAndGetResults('ErrTap', 'TestErr', roError, 'eav');
  LTAP := TAPReport(LResults);
  CheckContains(LTAP, 'not ok');
  CheckContains(LTAP, 'severity: error');
  CheckContains(LTAP, 'eav');
end;

procedure TestB12DiscoverRunCleanupIdempotent;
var
  LFixture: TTeardownFixture;
  LSuite: TTestSuite;
  LResult: TTestRunResult;
begin
  LFixture := TTeardownFixture.Create;
  LSuite := DiscoverTests(LFixture, 'CleanupIdem');
  LSuite.RunWithResult(LResult, True);
  CheckTrue(LResult.AllPassed);
  LSuite.CleanupTableAllocations;
  LSuite.CleanupTableAllocations;
  LSuite := Default(TTestSuite);
end;

procedure TestB12RetryExhaustedMessage;
var
  LSuite: TTestSuite;
  LResult: TTestRunResult;
  I: Integer;
  LFound: Boolean;
begin
  LSuite := TTestSuite.Create('RetryMsg');
  LSuite.Test('always_fail', @AlwaysFail, 1);
  LSuite.RunWithResult(LResult);
  CheckEqual(1, LResult.Failed);
  LFound := False;
  for I := 0 to High(LResult.Results) do
    if LResult.Results[I].Status = tsFailed then
    begin
      LFound := True;
      CheckContains(LResult.Results[I].Message, 'always fails');
    end;
  CheckTrue(LFound, 'failed result present');
  LSuite := Default(TTestSuite);
end;

procedure TestB26SoftFailAdvanced;
var
  LSuite: TTestSuite;
  LResult: TTestRunResult;
begin
  LSuite := TTestSuite.Create('adv-soft');
  LSuite.Test('soft', procedure
    begin
      SoftFail('adv soft');
      SoftCheckEqual(1, 2);
    end);
  CheckFalse(LSuite.RunWithResult(LResult));
  CheckEqual(LResult.Failed, 1);
  CheckContains(LResult.Results[0].Message, 'adv soft');
  LSuite := Default(TTestSuite);
end;

procedure TestB39SoftFailAdvancedExact;
var
  LSuite: TTestSuite;
  LResult: TTestRunResult;
begin
  LSuite := TTestSuite.Create('adv-soft-exact');
  LSuite.Test('soft', procedure
    begin
      SoftFail('x');
      SoftFail('y');
      SoftFail('z');
    end);
  CheckFalse(LSuite.RunWithResult(LResult));
  CheckEqual('x; y; z', LResult.Results[0].Message, 'advanced SoftFail join exact');
  LSuite := Default(TTestSuite);
end;

procedure TestB43SoftFailTAPMessage;
var
  LResults: specialize TArray<TTestRunResult>;
  LTAP: string;
begin
  SetLength(LResults, 1);
  LResults[0] := TTestRunResult.Create('soft-tap');
  LResults[0].Failed := 1;
  SetLength(LResults[0].Results, 1);
  LResults[0].Results[0].Name := 's';
  LResults[0].Results[0].Status := tsFailed;
  LResults[0].Results[0].Message := 'a; b; c';
  LTAP := TAPReport(LResults);
  CheckContains(LTAP, 'a; b; c');
  CheckContains(LTAP, 'not ok');
end;

procedure TestB26TAPMultiSuite;
var
  LResults: specialize TArray<TTestRunResult>;
  LTAP: string;
begin
  SetLength(LResults, 2);
  LResults[0] := TTestRunResult.Create('S1');
  LResults[0].Passed := 1;
  SetLength(LResults[0].Results, 1);
  LResults[0].Results[0].Name := 'a';
  LResults[0].Results[0].Status := tsPassed;
  LResults[1] := TTestRunResult.Create('S2');
  LResults[1].Failed := 1;
  SetLength(LResults[1].Results, 1);
  LResults[1].Results[0].Name := 'b';
  LResults[1].Results[0].Status := tsFailed;
  LResults[1].Results[0].Message := 'nope';
  LTAP := TAPReport(LResults);
  CheckContains(LTAP, 'TAP version 13');
  CheckContains(LTAP, '# suites: 2');
  CheckContains(LTAP, 'not ok');
end;

{ ── F-13: fail-path density for thin suite ────────────────────────────────── }

procedure TestAdvancedFailPathCase(const AC: TTestCase);
begin
  ExpectFail(procedure
    begin
      CheckEqual(Int64(0), Int64(StrToInt(AC.Data)));
    end, 'expected');
end;

{ ── v8.37: retry/repeat 执行语义矩阵 ──────────────────────────────────────────
  锁定 runner 三个隐蔽契约：
  1. entry RetryCount=0 视为未设置，回退 config.RetryCount（无法用 0 显式禁用）；
  2. 负 RetryCount 是唯一 opt-out：非 0 不回退 config，且首轮后立即停止；
  3. retry 循环仅对 tsPassed/tsSkipped 提前 Break —— tsError 也会重试。
  repeat：fail 不中断轮次、报告最后一轮结果、entry.RetryCount 恒 0 故
  config.RetryCount 在每轮内嵌套生效（execs = N × (1 + configR)）。
  flag 自校验：'0' ⟺ wantStatus <> 'pass'（负路径行），防灌水。 }

var
  GProbeExecs: Integer = 0;
  GProbeFailUntil: Integer = 0;  { fail while exec# <= this (999 = always) }
  GProbeMode: Integer = 0;       { 0=assert-fail, 1=skip, 2=error }

procedure RetryProbe;
begin
  Inc(GProbeExecs);
  if GProbeExecs <= GProbeFailUntil then
    case GProbeMode of
      1: raise ETestSkipped.Create('probe skip');
      2: raise Exception.Create('probe error');
    else
      CheckTrue(False, 'probe fail ' + IntToStr(GProbeExecs));
    end;
end;

function NextSeg(var ARest: string): string;
var
  LP: Integer;
begin
  LP := Pos('|', ARest);
  if LP = 0 then
  begin
    Result := ARest;
    ARest := '';
  end
  else
  begin
    Result := Copy(ARest, 1, LP - 1);
    ARest := Copy(ARest, LP + 1, Length(ARest));
  end;
end;

function StatusWord(AStatus: TTestStatus): string;
begin
  case AStatus of
    tsPassed:  Result := 'pass';
    tsFailed:  Result := 'fail';
    tsSkipped: Result := 'skip';
    tsError:   Result := 'error';
  else
    Result := 'unknown';
  end;
end;

procedure AppendRRCase(var ACases: specialize TArray<TTestCase>;
  const AName, AData, AFlag: string);
var
  LN: Integer;
begin
  LN := Length(ACases);
  SetLength(ACases, LN + 1);
  ACases[LN].Name := AName;
  ACases[LN].Data := AData + '|' + AFlag;
end;

{ Data: countParam|configR|mode|failUntil|wantStatus|wantExecs|flag.
  ARepeatMode=False → countParam 是 entry RetryCount（Test overload）；
  True → countParam 是 TestRepeat 的 RepeatCount。 }
procedure RunRetryRepeatCase(const AC: TTestCase; ARepeatMode: Boolean);
var
  LRest, LWantStatus, LFlag: string;
  LCountParam, LConfigR, LWantExecs: Integer;
  LSub: TTestSuite;
  LSubRunner: TSuiteRunner;
  LSubResults: specialize TArray<TTestRunResult>;
  LSink: TBufferSink;
begin
  LRest := AC.Data;
  LCountParam := StrToIntDef(NextSeg(LRest), 0);
  LConfigR := StrToIntDef(NextSeg(LRest), 0);
  GProbeMode := StrToIntDef(NextSeg(LRest), 0);
  GProbeFailUntil := StrToIntDef(NextSeg(LRest), 0);
  LWantStatus := NextSeg(LRest);
  LWantExecs := StrToIntDef(NextSeg(LRest), -1);
  LFlag := LRest;
  GProbeExecs := 0;

  LSink := TBufferSink.Create;
  LSub := TTestSuite.Create('rr-probe');
  LSub.Config.OutSink := LSink;
  LSub.Config.ErrSink := LSink;
  LSub.Config.AnsiMode := amOff;
  LSub.Config.RetryCount := LConfigR;
  if ARepeatMode then
    LSub.TestRepeat('probe', @RetryProbe, LCountParam)
  else
    LSub.Test('probe', @RetryProbe, LCountParam);
  LSubRunner := TSuiteRunner.Create('rr-runner');
  LSubRunner.Add(LSub);
  LSubRunner.RunAllWithResult(LSubResults);

  CheckEqual(LWantStatus, StatusWord(LSubResults[0].Results[0].Status),
    AC.Name + ' status');
  CheckEqual(Int64(LWantExecs), Int64(GProbeExecs), AC.Name + ' execs');
  if LFlag = '0' then
    CheckTrue(LWantStatus <> 'pass',
      AC.Name + ': flag 0 requires non-pass status')
  else
    CheckTrue(LWantStatus = 'pass',
      AC.Name + ': flag 1 requires pass status');

  LSub.Config.OutSink := nil;
  LSub.Config.ErrSink := nil;
  LSink := nil;
  LSubRunner := Default(TSuiteRunner);
  LSub := Default(TTestSuite);
  LSubResults := nil;
end;

procedure TestRetryMatrixCase(const AC: TTestCase);
begin
  RunRetryRepeatCase(AC, False);
end;

procedure TestRepeatMatrixCase(const AC: TTestCase);
begin
  RunRetryRepeatCase(AC, True);
end;

{ ── Main ──────────────────────────────────────────────────────────────────── }

var
  LSuite: TTestSuite;
  LRunner: TSuiteRunner;
  LResults: specialize TArray<TTestRunResult>;
  LFpCases: specialize TArray<TTestCase>;
  LFpI: Integer;
  LRRCases: specialize TArray<TTestCase>;
begin
  WriteLn('=== test_advanced ===');
  LSuite := TTestSuite.Create('advanced');

  { RTTI Discovery }
  LSuite.Test('DiscoverFindsPublishedMethods', @TestDiscoverFindsPublishedMethods);
  LSuite.Test('DiscoverDefaultSuiteName', @TestDiscoverDefaultSuiteName);
  LSuite.Test('DiscoverNoPublished', @TestDiscoverNoPublished);

  { Retry }
  LSuite.Test('RetryEventuallyPasses', @TestRetryEventuallyPasses);
  LSuite.Test('RetryExhausted', @TestRetryExhausted);
  LSuite.Test('RetryZeroMeansNoRetry', @TestRetryZeroMeansNoRetry);

  { TAP Output }
  LSuite.Test('TAPAllPassed', @TestTAPAllPassed);
  LSuite.Test('TAPWithFailure', @TestTAPWithFailure);
  LSuite.Test('TAPWithSkipped', @TestTAPWithSkipped);

  { JSON Output }
  LSuite.Test('JSONAllPassed', @TestJSONAllPassed);
  LSuite.Test('JSONWithFailure', @TestJSONWithFailure);
  LSuite.Test('JSONEscapesQuotes', @TestJSONEscapesQuotes);

  { R6-53: Discovery fixture teardown }
  LSuite.Test('DiscoveryFixtureTeardown', @TestDiscoveryFixtureTeardown);

  { B12 }
  LSuite.Test('B12 DiscoverAndFail', @TestB12DiscoverAndFail);
  LSuite.Test('B12 JSONErrorStatus', @TestB12JSONErrorStatus);
  LSuite.Test('B12 TAPErrorSeverity', @TestB12TAPErrorSeverity);
  LSuite.Test('B12 DiscoverRunCleanupIdempotent', @TestB12DiscoverRunCleanupIdempotent);
  LSuite.Test('B12 RetryExhaustedMessage', @TestB12RetryExhaustedMessage);
  LSuite.Test('B26 SoftFail in advanced', @TestB26SoftFailAdvanced);
  LSuite.Test('B26 TAP multi suite header', @TestB26TAPMultiSuite);
  LSuite.Test('B39 SoftFail join exact', @TestB39SoftFailAdvancedExact);
  LSuite.Test('B43 SoftFail TAP multi soft msg', @TestB43SoftFailTAPMessage);

  SetLength(LFpCases, 40);
  for LFpI := 0 to High(LFpCases) do
  begin
    LFpCases[LFpI].Name := 'adv-fp-' + IntToStr(LFpI);
    LFpCases[LFpI].Data := IntToStr(LFpI + 1);
  end;
  LSuite.TestTable('advanced fail-path ExpectFail', LFpCases,
    @TestAdvancedFailPathCase);

  { v8.37: retry 执行语义矩阵 — entryR|configR|mode|failUntil|wantStatus|wantExecs }
  SetLength(LRRCases, 0);
  AppendRRCase(LRRCases, 'a-pass-noretry',   '0|0|0|0|pass|1', '1');
  AppendRRCase(LRRCases, 'a-pass-retry2',    '2|0|0|0|pass|1', '1');
  AppendRRCase(LRRCases, 'a-pass-cfg2',      '0|2|0|0|pass|1', '1');
  AppendRRCase(LRRCases, 'a-fail-noretry',   '0|0|0|999|fail|1', '0');
  AppendRRCase(LRRCases, 'a-fail-r1',        '1|0|0|999|fail|2', '0');
  AppendRRCase(LRRCases, 'a-fail-r2',        '2|0|0|999|fail|3', '0');
  AppendRRCase(LRRCases, 'a-fail-r3',        '3|0|0|999|fail|4', '0');
  AppendRRCase(LRRCases, 'a-flaky1-r1',      '1|0|0|1|pass|2', '1');
  AppendRRCase(LRRCases, 'a-flaky1-r2',      '2|0|0|1|pass|2', '1');
  AppendRRCase(LRRCases, 'a-flaky2-r2',      '2|0|0|2|pass|3', '1');
  AppendRRCase(LRRCases, 'a-flaky2-r3',      '3|0|0|2|pass|3', '1');
  AppendRRCase(LRRCases, 'a-flaky2-r1',      '1|0|0|2|fail|2', '0');
  AppendRRCase(LRRCases, 'a-flaky3-r2',      '2|0|0|3|fail|3', '0');
  AppendRRCase(LRRCases, 'a-cfgfb-fail',     '0|2|0|999|fail|3', '0');
  AppendRRCase(LRRCases, 'a-cfgfb-flaky1',   '0|1|0|1|pass|2', '1');
  AppendRRCase(LRRCases, 'a-cfgfb-flaky2',   '0|3|0|2|pass|3', '1');
  AppendRRCase(LRRCases, 'a-entrywin-r1',    '1|3|0|999|fail|2', '0');
  AppendRRCase(LRRCases, 'a-entrywin-r2',    '2|1|0|2|pass|3', '1');
  AppendRRCase(LRRCases, 'a-neg-shield',     '-1|2|0|999|fail|1', '0');
  AppendRRCase(LRRCases, 'a-neg-pass',       '-1|0|0|0|pass|1', '1');
  AppendRRCase(LRRCases, 'a-neg5-shield',    '-5|3|0|999|fail|1', '0');
  AppendRRCase(LRRCases, 'a-skip-r2',        '2|0|1|999|skip|1', '0');
  AppendRRCase(LRRCases, 'a-skip-cfg2',      '0|2|1|999|skip|1', '0');
  AppendRRCase(LRRCases, 'a-error-noretry',  '0|0|2|999|error|1', '0');
  AppendRRCase(LRRCases, 'a-error-r2',       '2|0|2|999|error|3', '0');
  AppendRRCase(LRRCases, 'a-error1-r1',      '1|0|2|1|pass|2', '1');
  LSuite.TestTable('v8.37 retry execution matrix', LRRCases,
    @TestRetryMatrixCase);

  { v8.37: repeat 执行语义矩阵 — repeatN|configR|mode|failUntil|wantStatus|wantExecs }
  SetLength(LRRCases, 0);
  AppendRRCase(LRRCases, 'r-zero',           '0|0|0|0|pass|1', '1');
  AppendRRCase(LRRCases, 'r-one',            '1|0|0|0|pass|1', '1');
  AppendRRCase(LRRCases, 'r-three-pass',     '3|0|0|0|pass|3', '1');
  AppendRRCase(LRRCases, 'r-three-fail',     '3|0|0|999|fail|3', '0');
  AppendRRCase(LRRCases, 'r-lastwin',        '2|0|0|1|pass|2', '1');
  AppendRRCase(LRRCases, 'r-rep2-cfg1-fail', '2|1|0|999|fail|4', '0');
  AppendRRCase(LRRCases, 'r-rep2-cfg1-flaky','2|1|0|1|pass|3', '1');
  AppendRRCase(LRRCases, 'r-rep3-cfg2-fail', '3|2|0|999|fail|9', '0');
  AppendRRCase(LRRCases, 'r-rep2-skip',      '2|0|1|999|skip|2', '0');
  AppendRRCase(LRRCases, 'r-rep2-error',     '2|0|2|999|error|2', '0');
  LSuite.TestTable('v8.37 repeat execution matrix', LRRCases,
    @TestRepeatMatrixCase);

  LRunner := TSuiteRunner.Create('main');
  LRunner.Add(LSuite);
  LRunner.RunAllWithResult(LResults);
  WriteLn;
  LRunner.Summary;

  if LRunner.AllPassed then
    PassTest('ALL PASSED')
  else
    FailTest('SOME FAILED');

  { Release stubs/fixtures before unit finalization (avoids double-free AV). }
  LSuite.CleanupTableAllocations;
  LSuite.Config.OutSink := nil;
  LSuite.Config.ErrSink := nil;
  LRunner := Default(TSuiteRunner);
  LSuite := Default(TTestSuite);
  LResults := nil;
end.
