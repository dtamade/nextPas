{ test_advanced — Tests for: RTTI discovery, retry, TAP/JSON output, mock
  ========================================================= }

program test_advanced;

{$mode objfpc}{$H+}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}
{$M+}

uses
  cthreads,
  SysUtils,
  nextpas.core.test.base,
  nextpas.core.test.check,
  nextpas.core.test.output,
  nextpas.core.test.output.tap,
  nextpas.core.test.output.json,
  nextpas.core.test.runner,
  nextpas.core.test.discovery;

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

var
  GDiscoveryAlphaCalled: Boolean = False;
  GDiscoveryBetaCalled: Boolean = False;
  GRetryCount: Integer = 0;
  GTeardownFixtureFreeCalled: Boolean = False;

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

{ ── RTTI Discovery Tests ──────────────────────────────────────────────────── }

procedure TestDiscoverFindsPublishedMethods;
var
  LFixture: TDiscoveryFixture;
  LSuite: TTestSuite;
  LRunner: TTestRunner;
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
  LRunner := TTestRunner.Create('DiscoveryRunner');
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
  LFixture.Free;  { teardown hasn't run, free manually }
end;

procedure TestDiscoverNoPublished;
var
  LFixture: TEmptyFixture;
  LSuite: TTestSuite;
begin
  LFixture := TEmptyFixture.Create;
  LSuite := DiscoverTests(LFixture);
  CheckEqual(0, Length(LSuite.Tests));
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
  LRunner: TTestRunner;
  LResults: specialize TArray<TTestRunResult>;
begin
  GRetryCount := 0;
  LSuite := TTestSuite.Create('RetryTest');
  LSuite.Test('flaky', @FlakyThenPass, 5);  { retry up to 5 times }
  LRunner := TTestRunner.Create('RetryRunner');
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
  LRunner: TTestRunner;
  LResults: specialize TArray<TTestRunResult>;
begin
  LSuite := TTestSuite.Create('RetryExhaust');
  LSuite.Test('always_fail', @AlwaysFail, 2);  { retry 2 times, still fails }
  LRunner := TTestRunner.Create('RetryExhaustRunner');
  LRunner.Add(LSuite);
  LRunner.RunAllWithResult(LResults);
  CheckFalse(LResults[0].AllPassed);
  CheckEqual(1, LResults[0].Failed);
end;

procedure TestRetryZeroMeansNoRetry;
var
  LSuite: TTestSuite;
  LRunner: TTestRunner;
  LResults: specialize TArray<TTestRunResult>;
begin
  LSuite := TTestSuite.Create('RetryZero');
  LSuite.Test('simple', @AlwaysFail, 0);  { no retry }
  LRunner := TTestRunner.Create('RetryZeroRunner');
  LRunner.Add(LSuite);
  LRunner.RunAllWithResult(LResults);
  CheckFalse(LResults[0].AllPassed);
  CheckEqual(1, LResults[0].Failed);
end;

{ ── TAP Output Tests ──────────────────────────────────────────────────────── }

procedure TestTAPAllPassed;
var
  LResults: specialize TArray<TTestRunResult>;
  LSuite: TTestRunResult;
  LRes: TTestResult;
  LTAP: string;
begin
  LSuite := TTestRunResult.Create('MySuite');
  LRes.Name := 'TestFoo';
  LRes.Status := tsPassed;
  LRes.Message := '';
  SetLength(LSuite.Results, 1);
  LSuite.Results[0] := LRes;
  LSuite.Passed := 1;
  LSuite.AllPassed := True;
  SetLength(LResults, 1);
  LResults[0] := LSuite;

  LTAP := TAPReport(LResults, 'MyTests');
  CheckContains(LTAP, 'TAP version 13');
  CheckContains(LTAP, '1..1');
  CheckContains(LTAP, 'ok 1 - MySuite / TestFoo');
  CheckContains(LTAP, '# total: 1');
  CheckContains(LTAP, '# passed: 1');
end;

procedure TestTAPWithFailure;
var
  LResults: specialize TArray<TTestRunResult>;
  LSuite: TTestRunResult;
  LRes: TTestResult;
  LTAP: string;
begin
  LSuite := TTestRunResult.Create('FailSuite');
  LRes.Name := 'TestBar';
  LRes.Status := tsFailed;
  LRes.Message := 'expected 5 got 3';
  SetLength(LSuite.Results, 1);
  LSuite.Results[0] := LRes;
  LSuite.Failed := 1;
  LSuite.AllPassed := False;
  SetLength(LResults, 1);
  LResults[0] := LSuite;

  LTAP := TAPReport(LResults);
  CheckContains(LTAP, 'not ok 1 - FailSuite / TestBar');
  CheckContains(LTAP, 'message: |-');
  CheckContains(LTAP, '    expected 5 got 3');
  CheckContains(LTAP, 'severity: fail');
end;

procedure TestTAPWithSkipped;
var
  LResults: specialize TArray<TTestRunResult>;
  LSuite: TTestRunResult;
  LRes: TTestResult;
  LTAP: string;
begin
  LSuite := TTestRunResult.Create('SkipSuite');
  LRes.Name := 'TestSkipped';
  LRes.Status := tsSkipped;
  LRes.Message := 'platform not supported';
  SetLength(LSuite.Results, 1);
  LSuite.Results[0] := LRes;
  LSuite.Skipped := 1;
  SetLength(LResults, 1);
  LResults[0] := LSuite;

  LTAP := TAPReport(LResults);
  CheckContains(LTAP, 'ok 1 - SkipSuite / TestSkipped # skip platform not supported');
  CheckContains(LTAP, '# skipped: 1');
end;

{ ── JSON Output Tests ─────────────────────────────────────────────────────── }

procedure TestJSONAllPassed;
var
  LResults: specialize TArray<TTestRunResult>;
  LSuite: TTestRunResult;
  LRes: TTestResult;
  LJSON: string;
begin
  LSuite := TTestRunResult.Create('JsonSuite');
  LRes.Name := 'TestX';
  LRes.Status := tsPassed;
  LRes.Message := '';
  SetLength(LSuite.Results, 1);
  LSuite.Results[0] := LRes;
  LSuite.Passed := 1;
  LSuite.AllPassed := True;
  SetLength(LResults, 1);
  LResults[0] := LSuite;

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
  LSuite: TTestRunResult;
  LRes: TTestResult;
  LJSON: string;
begin
  LSuite := TTestRunResult.Create('JsonFail');
  LRes.Name := 'TestFail';
  LRes.Status := tsFailed;
  LRes.Message := 'assert failed';
  SetLength(LSuite.Results, 1);
  LSuite.Results[0] := LRes;
  LSuite.Failed := 1;
  LSuite.AllPassed := False;
  SetLength(LResults, 1);
  LResults[0] := LSuite;

  LJSON := JSONReport(LResults);
  CheckContains(LJSON, '"status": "failed"');
  CheckContains(LJSON, '"message": "assert failed"');
  CheckContains(LJSON, '"allPassed": false');
  CheckContains(LJSON, '"totalFailed": 1');
end;

procedure TestJSONEscapesQuotes;
var
  LResults: specialize TArray<TTestRunResult>;
  LSuite: TTestRunResult;
  LRes: TTestResult;
  LJSON: string;
begin
  LSuite := TTestRunResult.Create('Esc"ape');
  LRes.Name := 'Test"Quote';
  LRes.Status := tsError;
  LRes.Message := 'line1' + #10 + 'line2';
  SetLength(LSuite.Results, 1);
  LSuite.Results[0] := LRes;
  SetLength(LResults, 1);
  LResults[0] := LSuite;

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
  LRunner: TTestRunner;
  LResults: specialize TArray<TTestRunResult>;
begin
  { R6-53: RTTI discovery + run, verifying fixture method dispatch works.
    NOTE: DiscoverTests does NOT auto-free the fixture; caller owns it.
    TODO: verify teardown hook is called when DiscoverTests supports it. }
  LFixture := TTeardownFixture.Create;
  LSuite := DiscoverTests(LFixture, 'TeardownTest');
  CheckTrue(Length(LSuite.Tests) > 0, 'Should discover at least 1 test');
  CheckEqual('TestOne', LSuite.Tests[0].Name);
  LRunner := TTestRunner.Create('TeardownRunner');
  LRunner.Add(LSuite);
  LRunner.RunAllWithResult(LResults);
  CheckTrue(Length(LResults) > 0);
  CheckTrue(LResults[0].AllPassed);
  CheckEqual(1, LResults[0].Passed);
end;

{ ── Main ──────────────────────────────────────────────────────────────────── }

var
  LSuite: TTestSuite;
  LRunner: TTestRunner;
  LResults: specialize TArray<TTestRunResult>;
begin
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

  LRunner := TTestRunner.Create('main');
  LRunner.Add(LSuite);
  LRunner.RunAllWithResult(LResults);

  if (Length(LResults) = 0) or (not LResults[0].AllPassed) then
    Halt(1);
end.
