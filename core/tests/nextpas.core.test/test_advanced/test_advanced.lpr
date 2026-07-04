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
  nextpas.core.test;

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
  { White-box ownership note: published-method fixtures are registered for
    discovery cleanup, so this test must not free manually. }
end;

procedure TestDiscoverNoPublished;
var
  LFixture: TEmptyFixture;
  LSuite: TTestSuite;
begin
  LFixture := TEmptyFixture.Create;
  LSuite := DiscoverTests(LFixture);
  CheckEqual(0, Length(LSuite.Tests));
  { White-box ownership note: the zero-published-method early-exit happens
    before RegisterFixture, so caller ownership remains here. }
  LFixture.Free;
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

{ ── Main ──────────────────────────────────────────────────────────────────── }

var
  LSuite: TTestSuite;
  LRunner: TSuiteRunner;
  LResults: specialize TArray<TTestRunResult>;
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

  LRunner := TSuiteRunner.Create('main');
  LRunner.Add(LSuite);
  LRunner.RunAllWithResult(LResults);
  WriteLn;
  LRunner.Summary;

  if LRunner.AllPassed then
    PassTest('ALL PASSED')
  else
    FailTest('SOME FAILED');
end.
