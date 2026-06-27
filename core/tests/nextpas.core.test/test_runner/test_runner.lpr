{ test_runner — Validates TTestRunner multi-suite + subtests + lifecycle }
program test_runner;

{$mode objfpc}{$H+}{$J-}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

uses
  cthreads,
  SysUtils,
  nextpas.core.test,
  nextpas.core.test.config,
  { 白盒测试：直接验证 runner 内部 helper，而不是仅通过 facade 间接覆盖。 }
  nextpas.core.test.runner,
  nextpas.core.test.output;

var
  GSetupCalled: Integer = 0;
  GTeardownCalled: Integer = 0;
  GBeforeEachCalled: Integer = 0;
  GAfterEachCalled: Integer = 0;
  { R4-08: empty suite test variables }
  LEmptySuite: TTestSuite;
  LEmptyResult: TTestRunResult;
  { R5-08: filter test variables }
  LFilterSuite: TTestSuite;
  LFilterResult: TTestRunResult;

{ ── Lifecycle tests ──────────────────────────────────────────────────────── }

procedure TestSetup;
begin
  CheckTrue(GSetupCalled > 0, 'Setup should have been called');
end;

procedure TestBeforeEach;
begin
  CheckTrue(GBeforeEachCalled > 0, 'BeforeEach should have been called');
end;

procedure TestAfterEach1;
begin
  { AfterEach is checked after each test via counters }
  CheckTrue(True);
end;

procedure TestAfterEach2;
begin
  CheckTrue(True);
end;

{ ── Subtest tests ────────────────────────────────────────────────────────── }

procedure TestSubtests(constref Ctx: ITestContext);
begin
  Ctx.Run('sub 1',
    procedure
    begin
      CheckEqual(Int64(1), Int64(1));
    end);

  Ctx.Run('sub 2',
    procedure
    begin
      CheckTrue(True);
    end);

  Ctx.Run('sub 3: deeper',
    procedure
    begin
      CheckContains('hello world', 'world');
    end);
end;

procedure TestSubtestWithCaughtAssertion(constref Ctx: ITestContext);
begin
  Ctx.Run('pass',
    procedure
    begin
      Check(True);
    end);

  Ctx.Run('caught assertion',
    procedure
    begin
      try
        Check(False, 'sub-assertion');
        Halt(1);
      except
        on E: EAssertionFailed do
          CheckContains(E.Message, 'sub-assertion');
      end;
    end);
end;

{ ── Skip test ────────────────────────────────────────────────────────────── }

procedure TestSkipInSuite;
begin
  Skip('intentionally skipped for testing');
  Halt(1); { Should never reach }
end;

procedure TestSimplePass;
begin
  Check(True);
end;

procedure TestSimplePass2;
begin
  Check(True);
end;

procedure TestRegularLogFailure;
begin
  nextpas.core.test.runner.Ctx.Log('hello');
  Fail('regular test failure');
end;

{ ── R2-F12: BeforeEach Skip test ───────────────────────────────────────────── }

procedure TestBeforeEachSkip;
var
  LSuite: TTestSuite;
  LSkipResult: TTestRunResult;
begin
  LSuite := TTestSuite.Create('BeforeEachSkip');
  LSuite.OnBeforeEach(procedure begin Skip('skip from beforeEach'); end);
  LSuite.Test('t1', @TestSimplePass);
  LSuite.Test('t2', @TestSimplePass2);
  { Both tests should be skipped, not errored }
  LSuite.RunWithResult(LSkipResult);
  if LSkipResult.Skipped <> 2 then
  begin
    FailTest('expected 2 skipped, got ' + IntToStr(LSkipResult.Skipped));
  end;
  if LSkipResult.Failed <> 0 then
  begin
    FailTest('expected 0 failed, got ' + IntToStr(LSkipResult.Failed));
  end;
  PassTest('BeforeEach Skip');
end;

procedure TestRunnerConfigIsolation;
var
  LSuiteA: TTestSuite;
  LSuiteB: TTestSuite;
  LRunnerA: TTestRunner;
  LRunnerB: TTestRunner;
  LResultsA: specialize TArray<TTestRunResult>;
  LResultsB: specialize TArray<TTestRunResult>;
  LOutA: TBufferSink;
  LOutB: TBufferSink;
  LOutputA: string;
  LOutputB: string;
begin
  LOutA := TBufferSink.Create;
  LOutB := TBufferSink.Create;

  LSuiteA := TTestSuite.Create('Suite A');
  LSuiteA.Config.OutSink := LOutA;
  LSuiteA.Config.ErrSink := LOutA;
  LSuiteA.Config.AnsiMode := amOff;
  LSuiteA.Config.FilterPattern := 'alpha-only';
  LSuiteA.Test('alpha-only', @TestSimplePass);
  LSuiteA.Test('alpha-hidden', @TestSimplePass2);

  LSuiteB := TTestSuite.Create('Suite B');
  LSuiteB.Config.OutSink := LOutB;
  LSuiteB.Config.ErrSink := LOutB;
  LSuiteB.Config.AnsiMode := amOff;
  LSuiteB.Config.FilterPattern := 'beta-only';
  LSuiteB.Test('beta-hidden', @TestSimplePass);
  LSuiteB.Test('beta-only', @TestSimplePass2);

  LRunnerA := TTestRunner.Create('Runner A');
  LRunnerA.Add(LSuiteA);
  LRunnerB := TTestRunner.Create('Runner B');
  LRunnerB.Add(LSuiteB);

  if not LRunnerA.RunAllWithResult(LResultsA) then
  begin
    FailTest('runner A should pass');
  end;
  if not LRunnerB.RunAllWithResult(LResultsB) then
  begin
    FailTest('runner B should pass');
  end;

  if (Length(LResultsA) <> 1) or (LResultsA[0].Passed <> 1) then
  begin
    FailTest('runner A should record exactly one passed test');
  end;
  if (Length(LResultsB) <> 1) or (LResultsB[0].Passed <> 1) then
  begin
    FailTest('runner B should record exactly one passed test');
  end;

  LOutputA := LOutA.GetOutput;
  LOutputB := LOutB.GetOutput;
  if Pos('alpha-only', LOutputA) = 0 then
  begin
    FailTest('runner A output should contain alpha-only');
  end;
  if Pos('alpha-hidden', LOutputA) > 0 then
  begin
    FailTest('runner A output should not contain alpha-hidden');
  end;
  if Pos('beta-only', LOutputA) > 0 then
  begin
    FailTest('runner A output should not contain runner B tests');
  end;

  if Pos('beta-only', LOutputB) = 0 then
  begin
    FailTest('runner B output should contain beta-only');
  end;
  if Pos('beta-hidden', LOutputB) > 0 then
  begin
    FailTest('runner B output should not contain beta-hidden');
  end;
  if Pos('alpha-only', LOutputB) > 0 then
  begin
    FailTest('runner B output should not contain runner A tests');
  end;

  PassTest('Runner config isolation');
end;

{ ── Main ──────────────────────────────────────────────────────────────────── }

var
  LSuite1, LSuite2: TTestSuite;
  LRunner: TTestRunner;
  LPass: Boolean;
  { B5.3 lifecycle failure tests }
  LFailSuite1, LFailSuite2, LFailSuite3: TTestSuite;
  LBeforeEachCounter: Integer;
  { B5.5/B5.6/B5.9 runner feature tests }
  LRunNestedS1, LRunNestedS2, LCacheSuite, LSummarySuite, LSumSuite3: TTestSuite;
  LRunNestedR, LSumRunner: TTestRunner;
  LRunCount: Integer;
  { RunWithResult test }
  LResultSuite: TTestSuite;
  LRunWithResultResult: TTestRunResult;
  LSubtestResults: TTestRunResult;
  LParallelResult: TTestRunResult;
  LTimeoutResult: TTestRunResult;
  LRegularLogResult: TTestRunResult;
  LRunAllSuiteResults: specialize TArray<TTestRunResult>;
  LTimeoutSleepMs: Integer;
  { R6-59: AddLine/JoinLines test variables }
  LLines59: specialize TArray<string>;
  LJoined59: string;
  LEmpty59: specialize TArray<string>;
  { R6-60: TTestRunResult defaults }
  LDefaults60: TTestRunResult;
  { R6-68: Strong exact-value assertions }
  LExactSuite68: TTestSuite;
  LExactRunner68: TTestRunner;
begin
  WriteLn('=== test_runner ===');
  { Suite 1: lifecycle }
  LSuite1 := TTestSuite.Create('Lifecycle');
  LSuite1.SetSetup(procedure begin Inc(GSetupCalled); end);
  LSuite1.SetTeardown(procedure begin Inc(GTeardownCalled); end);
  LSuite1.OnBeforeEach(procedure begin Inc(GBeforeEachCalled); end);
  LSuite1.OnAfterEach(procedure begin Inc(GAfterEachCalled); end);

  LSuite1.Test('setup was called',    @TestSetup);
  LSuite1.Test('beforeEach called',   @TestBeforeEach);
  LSuite1.Test('afterEach test 1',    @TestAfterEach1);
  LSuite1.Test('afterEach test 2',    @TestAfterEach2);

  { Suite 2: subtests + skip }
  LSuite2 := TTestSuite.Create('Subtests');
  LSuite2.TestSubtest('nested subtests',       @TestSubtests);
  LSuite2.TestSubtest('subtests with failure',  @TestSubtestWithCaughtAssertion);
  LSuite2.Skip('planned feature', 'not yet implemented');
  LSuite2.Test('skip in suite',      @TestSkipInSuite);

  { Multi-suite runner }
  LRunner := TTestRunner.Create('Test Runner Integration');
  LRunner.Add(LSuite1);
  LRunner.Add(LSuite2);

  LPass := LRunner.RunAll;

  { Verify lifecycle counters }
  WriteLn;
  SectionHeader('Lifecycle Counters');
  WriteLn('  Setup called:     ', GSetupCalled);
  WriteLn('  Teardown called:  ', GTeardownCalled);
  WriteLn('  BeforeEach called:', GBeforeEachCalled);
  WriteLn('  AfterEach called: ', GAfterEachCalled);

  if GSetupCalled <> 1 then
  begin
    FailTest('Setup not called exactly once, got ' + IntToStr(GSetupCalled));
  end;
  if GTeardownCalled <> 1 then
  begin
    FailTest('Teardown not called exactly once, got ' + IntToStr(GTeardownCalled));
  end;
  if GBeforeEachCalled <> 4 then
  begin
    FailTest('BeforeEach not called exactly 4 times, got ' + IntToStr(GBeforeEachCalled));
  end;
  if GAfterEachCalled <> 4 then
  begin
    FailTest('AfterEach not called exactly 4 times, got ' + IntToStr(GAfterEachCalled));
  end;

  if not LPass then
  begin
    WriteLn;
    FailTest('SOME TESTS FAILED');
  end;

  { ── B5.3: Lifecycle failure path tests ───────────────────────────────── }

  { Test: Setup failure → Run returns False, all tests skipped }
  WriteLn;
  SectionHeader('B5.3: Lifecycle Failure Tests');
  LFailSuite1 := TTestSuite.Create('Setup Failure');
  LFailSuite1.SetSetup(procedure begin
    raise EConvertError.Create('setup boom');
  end);
  LFailSuite1.Test('test after bad setup', procedure begin
    Halt(1); { should never run }
  end);
  if LFailSuite1.Run then
  begin
    FailTest('Setup failure should cause Run=False');
  end;
  if LFailSuite1.LastPass <> 0 then
  begin
    FailTest('No tests should pass after setup failure');
  end;
  if not LFailSuite1.HasRun then
  begin
    FailTest('HasRun should be True after Run');
  end;
  if LFailSuite1.LastFail < 1 then
  begin
    FailTest('Setup failure should count as failure');
  end;
  PassTest('Setup failure path');

  { Test: BeforeEach failure → test marked error }
  LBeforeEachCounter := 0;
  LFailSuite2 := TTestSuite.Create('BeforeEach Failure');
  LFailSuite2.OnBeforeEach(procedure begin
    Inc(LBeforeEachCounter);
    if LBeforeEachCounter = 2 then
      raise EConvertError.Create('beforeEach boom on test 2');
  end);
  LFailSuite2.Test('test 1 passes', procedure begin
    CheckTrue(True);
  end);
  LFailSuite2.Test('test 2 fails (bad beforeEach)', procedure begin
    Halt(1); { should never run — beforeEach raises first }
  end);
  LFailSuite2.Test('test 3 passes', procedure begin
    CheckTrue(True);
  end);
  if LFailSuite2.Run then
  begin
    FailTest('BeforeEach failure should cause Run=False');
  end;
  if LFailSuite2.LastFail < 1 then
  begin
    FailTest('At least 1 failure expected');
  end;
  PassTest('BeforeEach failure path');

  { Test: Teardown failure → warning output, test results preserved }
  LFailSuite3 := TTestSuite.Create('Teardown Failure');
  LFailSuite3.SetTeardown(procedure begin
    raise EConvertError.Create('teardown boom');
  end);
  LFailSuite3.Test('passing test', procedure begin
    CheckTrue(True);
  end);
  if not LFailSuite3.Run then
  begin
    FailTest('Teardown failure should not fail tests');
  end;
  PassTest('Teardown failure path');

  { ── B5.5/B5.6/B5.9: Runner feature tests ────────────────────────────── }

  { Test: RunAll aggregation — TTestRunner with multiple suites }
  LRunNestedS1 := TTestSuite.Create('Suite A');
  LRunNestedS1.Test('a1', procedure begin CheckTrue(True); end);
  LRunNestedS2 := TTestSuite.Create('Suite B');
  LRunNestedS2.Test('b1', procedure begin CheckTrue(True); end);
  LRunNestedR := TTestRunner.Create('Multi-Suite Runner');
  LRunNestedR.Add(LRunNestedS1);
  LRunNestedR.Add(LRunNestedS2);
  if not LRunNestedR.RunAll then
  begin
    FailTest('RunAll aggregation should pass');
  end;
  if LRunNestedR.TotalPass <> 2 then
  begin
    FailTest('Expected 2 passes, got ' + IntToStr(LRunNestedR.TotalPass));
  end;
  PassTest('RunAll aggregation');

  { Test: AllPassed caching — second call should not re-run }
  LRunCount := 0;
  LCacheSuite := TTestSuite.Create('Cache Test');
  LCacheSuite.Test('counter', procedure begin
    InterLockedIncrement(LRunCount);
    CheckTrue(True);
  end);
  LCacheSuite.Run; { first run }
  if LRunCount <> 1 then
  begin
    FailTest('Expected 1 run, got ' + IntToStr(LRunCount));
  end;
  LCacheSuite.AllPassed; { should NOT re-run }
  if LRunCount <> 1 then
  begin
    FailTest('AllPassed should not re-run (count=' + IntToStr(LRunCount) + ')');
  end;
  PassTest('AllPassed caching');

  { Test: Summary smoke }
  LSummarySuite := TTestSuite.Create('Summary Smoke');
  LSummarySuite.Test('pass', procedure begin CheckTrue(True); end);
  LSummarySuite.Run;
  LSummarySuite.Summary; { should not raise }
  PassTest('Summary smoke');

  { Test: Runner Summary }
  LSumSuite3 := TTestSuite.Create('Summary Suite');
  LSumSuite3.Test('pass', procedure begin CheckTrue(True); end);
  LSumSuite3.Skip('skipped', 'reason');
  LSumRunner := TTestRunner.Create('Summary Runner');
  LSumRunner.Add(LSumSuite3);
  LSumRunner.RunAll;
  LSumRunner.Summary; { should not raise }
  if LSumRunner.TotalPass <> 1 then
  begin
    FailTest('Expected 1 pass, got ' + IntToStr(LSumRunner.TotalPass));
  end;
  if LSumRunner.TotalSkip <> 1 then
  begin
    FailTest('Expected 1 skip, got ' + IntToStr(LSumRunner.TotalSkip));
  end;
  PassTest('Runner Summary');

  { Test: RunWithResult }
  LResultSuite := TTestSuite.Create('Result Test');
  LResultSuite.Test('will pass', procedure begin CheckTrue(True); end);
  LResultSuite.Skip('will skip', 'reason');
  LResultSuite.Test('will pass 2', procedure begin CheckTrue(True); end);
  if not LResultSuite.RunWithResult(LRunWithResultResult) then
  begin
    FailTest('RunWithResult should return True');
  end;
  if LRunWithResultResult.SuiteName <> 'Result Test' then
  begin
    FailTest('SuiteName mismatch');
  end;
  if Length(LRunWithResultResult.Results) <> 3 then
  begin
    FailTest('Expected 3 results, got ' + IntToStr(Length(LRunWithResultResult.Results)));
  end;
  if LRunWithResultResult.Passed <> 2 then
  begin
    FailTest('Expected 2 passed, got ' + IntToStr(LRunWithResultResult.Passed));
  end;
  if LRunWithResultResult.Skipped <> 1 then
  begin
    FailTest('Expected 1 skipped, got ' + IntToStr(LRunWithResultResult.Skipped));
  end;
  if LRunWithResultResult.Failed <> 0 then
  begin
    FailTest('Expected 0 failed, got ' + IntToStr(LRunWithResultResult.Failed));
  end;
  if not LRunWithResultResult.AllPassed then
  begin
    FailTest('AllPassed should be True');
  end;
  if LRunWithResultResult.Results[0].Status <> tsPassed then
  begin
    FailTest('Result[0] should be tsPassed');
  end;
  if LRunWithResultResult.Results[1].Status <> tsSkipped then
  begin
    FailTest('Result[1] should be tsSkipped');
  end;
  if LRunWithResultResult.Results[1].Message <> 'reason' then
  begin
    FailTest('Result[1] message should be "reason"');
  end;
  if LRunWithResultResult.Results[2].Status <> tsPassed then
  begin
    FailTest('Result[2] should be tsPassed');
  end;
  PassTest('RunWithResult');

  { ── m15: Summary smoke test ───────────────────────────────────────────────── }
  WriteLn;
  SectionHeader('m15: Summary Smoke Test');
  LResultSuite := TTestSuite.Create('Summary Smoke');
  LResultSuite.Test('pass', @TestSimplePass);
  LResultSuite.Skip('skip', 'planned');
  LResultSuite.Run;
  LResultSuite.Summary;  { Should not crash }
  PassTest('Summary');

  { ── M20: AllPassed caching ────────────────────────────────────────────────── }
  WriteLn;
  SectionHeader('M20: AllPassed Caching');
  LResultSuite := TTestSuite.Create('Cache Test');
  LResultSuite.Test('pass1', @TestSimplePass);
  LResultSuite.Test('pass2', @TestSimplePass2);
  { First call triggers Run }
  if not LResultSuite.AllPassed then
  begin
    FailTest('AllPassed should be True on first call');
  end;
  { Second call should use cached result }
  if not LResultSuite.AllPassed then
  begin
    FailTest('AllPassed should be True on second call');
  end;
  PassTest('AllPassed caching');

  { ── R2-F12: BeforeEach Skip ────────────────────────────────────────────────── }
  WriteLn;
  SectionHeader('R2-F12: BeforeEach Skip');
  TestBeforeEachSkip;

  { ── R2-F03: Subtest-level results ────────────────────────────────────────── }
  WriteLn;
  SectionHeader('R2-F03: Subtest Results');
  begin
    LResultSuite := TTestSuite.Create('Subtest Results');
    LResultSuite.TestSubtest('subtests', @TestSubtests);
    LResultSuite.Test('plain pass', @TestSimplePass);
    LResultSuite.RunWithResult(LSubtestResults);
    { TestSubtests registers 3 subtests + 1 plain = 5 results total
      (3 sub + 1 subtest parent entry + 1 plain) }
    if Length(LSubtestResults.Results) <> 5 then
    begin
      FailTest('Expected 5 results (3 sub + 1 parent + 1 plain), got ' + IntToStr(Length(LSubtestResults.Results)));
    end;
    { Check subtest results are individually tracked
      Order: [0]=subtests(parent), [1]=plain pass, [2..4]=sub results }
    if LSubtestResults.Results[0].Name <> 'subtests' then
    begin
      FailTest('Result[0] name should be "subtests", got ' + LSubtestResults.Results[0].Name);
    end;
    if LSubtestResults.Results[2].Status <> tsPassed then
    begin
      FailTest('Subtest result[2] should be tsPassed, got ' + IntToStr(Ord(LSubtestResults.Results[2].Status)));
    end;
    if Pos('subtests/', LSubtestResults.Results[2].Name) = 0 then
    begin
      FailTest('Subtest result name should contain "subtests/", got ' + LSubtestResults.Results[2].Name);
    end;
    PassTest('Subtest results collected');
  end;

  { ── R2-F02: RunParallelWithResult ────────────────────────────────────────── }
  WriteLn;
  SectionHeader('R2-F02: RunParallelWithResult');
  begin
    LResultSuite := TTestSuite.Create('Parallel Result');
    LResultSuite.Test('p1', @TestSimplePass);
    LResultSuite.Test('p2', @TestSimplePass2);
    LResultSuite.Skip('sk1', 'reason');
    LResultSuite.RunParallelWithResult(nil, LParallelResult);
    if Length(LParallelResult.Results) <> 3 then
    begin
      FailTest('Expected 3 results, got ' + IntToStr(Length(LParallelResult.Results)));
    end;
    if LParallelResult.Passed <> 2 then
    begin
      FailTest('Expected 2 passed, got ' + IntToStr(LParallelResult.Passed));
    end;
    if LParallelResult.Skipped <> 1 then
    begin
      FailTest('Expected 1 skipped, got ' + IntToStr(LParallelResult.Skipped));
    end;
    if not LParallelResult.AllPassed then
    begin
      FailTest('AllPassed should be True');
    end;
    PassTest('RunParallelWithResult');
  end;

  { ── R2-F02: RunAllWithResult ─────────────────────────────────────────────── }
  WriteLn;
  SectionHeader('R2-F02: RunAllWithResult');
  begin
    LRunNestedS1 := TTestSuite.Create('SuiteX');
    LRunNestedS1.Test('x1', procedure begin CheckTrue(True); end);
    LRunNestedS1.Skip('x2', 'planned');
    LRunNestedS2 := TTestSuite.Create('SuiteY');
    LRunNestedS2.Test('y1', procedure begin CheckTrue(True); end);
    LRunNestedR := TTestRunner.Create('WithResult Runner');
    LRunNestedR.Add(LRunNestedS1);
    LRunNestedR.Add(LRunNestedS2);
    if not LRunNestedR.RunAllWithResult(LRunAllSuiteResults) then
    begin
      FailTest('RunAllWithResult should return True');
    end;
    if Length(LRunAllSuiteResults) <> 2 then
    begin
      FailTest('Expected 2 suite results, got ' + IntToStr(Length(LRunAllSuiteResults)));
    end;
    if LRunAllSuiteResults[0].SuiteName <> 'SuiteX' then
    begin
      FailTest('First suite name should be SuiteX');
    end;
    if LRunAllSuiteResults[1].Passed <> 1 then
    begin
      FailTest('SuiteY should have 1 pass, got ' + IntToStr(LRunAllSuiteResults[1].Passed));
    end;
    PassTest('RunAllWithResult');
  end;

  { ── R3-F17: Timeout trigger (watchdog actually fires) ───────────────────── }
  WriteLn;
  SectionHeader('R3-F17: Timeout Trigger (Closure)');
  begin
    LResultSuite := TTestSuite.Create('Timeout Trigger');
    LTimeoutSleepMs := 500;
    LResultSuite.Test('slow closure', procedure begin Sleep(LTimeoutSleepMs); end);
    SetTestTimeout(10); { 10ms — much less than the 500ms Sleep }
    LResultSuite.RunWithResult(LTimeoutResult);
    SetTestTimeout(0);
    if LTimeoutResult.AllPassed then
    begin
      FailTest('timed-out test should not be AllPassed');
    end;
    if Length(LTimeoutResult.Results) <> 1 then
    begin
      FailTest('Expected 1 result, got ' + IntToStr(Length(LTimeoutResult.Results)));
    end;
    if LTimeoutResult.Results[0].Status <> tsError then
    begin
      FailTest('Expected tsError status, got ' + IntToStr(Ord(LTimeoutResult.Results[0].Status)));
    end;
    if Pos('timed out', LowerCase(LTimeoutResult.Results[0].Message)) = 0 then
    begin
      FailTest('Expected timeout message, got ' + LTimeoutResult.Results[0].Message);
    end;
    PassTest('Timeout trigger verified');
  end;

  { ── R5-08/R5-09: Test filter coverage ──────────────────────────────────────── }
  begin
    { Test 1: filter matches a specific test — only that test runs.
      Filtered tests are invisible (not counted as pass/fail/skip). }
    LFilterSuite := TTestSuite.Create('FilterMatch');
    LFilterSuite.Test('aaa', @TestSimplePass);
    LFilterSuite.Test('bbb', @TestSimplePass);
    LFilterSuite.Test('ccc', @TestSimplePass);
    SetTestFilter('bbb');
    if not LFilterSuite.RunWithResult(LFilterResult) then
    begin
      FailTest('filter match should pass');
    end;
    if LFilterResult.Passed <> 1 then
    begin
      FailTest('filter match expected 1 passed, got ' + IntToStr(LFilterResult.Passed));
    end;
    if LFilterResult.Skipped <> 0 then
    begin
      FailTest('filter match expected 0 skipped (filtered=invisible), got ' + IntToStr(LFilterResult.Skipped));
    end;
    SetTestFilter('');
    PassTest('Filter matches specific test');
  end;

  begin
    { Test 2: filter matches nothing — all tests invisible, 0/0/0 }
    LFilterSuite := TTestSuite.Create('FilterNone');
    LFilterSuite.Test('aaa', @TestSimplePass);
    LFilterSuite.Test('bbb', @TestSimplePass);
    SetTestFilter('zzz_nonexistent');
    if not LFilterSuite.RunWithResult(LFilterResult) then
    begin
      FailTest('filter no-match should still return True');
    end;
    if LFilterResult.Passed <> 0 then
    begin
      FailTest('filter no-match expected 0 passed, got ' + IntToStr(LFilterResult.Passed));
    end;
    if LFilterResult.Skipped <> 0 then
    begin
      FailTest('filter no-match expected 0 skipped, got ' + IntToStr(LFilterResult.Skipped));
    end;
    SetTestFilter('');
    PassTest('Filter matches nothing -> all invisible');
  end;

  begin
    { Test 3: empty filter runs everything (no filtering) }
    LFilterSuite := TTestSuite.Create('FilterEmpty');
    LFilterSuite.Test('aaa', @TestSimplePass);
    LFilterSuite.Test('bbb', @TestSimplePass);
    SetTestFilter('');
    if not LFilterSuite.RunWithResult(LFilterResult) then
    begin
      FailTest('empty filter should pass');
    end;
    if LFilterResult.Passed <> 2 then
    begin
      FailTest('empty filter expected 2 passed, got ' + IntToStr(LFilterResult.Passed));
    end;
    if LFilterResult.Skipped <> 0 then
    begin
      FailTest('empty filter expected 0 skipped, got ' + IntToStr(LFilterResult.Skipped));
    end;
    PassTest('Empty filter runs everything');
  end;

  begin
    { Test 4: glob filter — asterisk wildcard }
    LFilterSuite := TTestSuite.Create('FilterGlob');
    LFilterSuite.Test('alpha', @TestSimplePass);
    LFilterSuite.Test('beta',  @TestSimplePass);
    LFilterSuite.Test('gamma', @TestSimplePass);
    SetTestFilter('b*');
    if not LFilterSuite.RunWithResult(LFilterResult) then
    begin
      FailTest('glob filter should pass');
    end;
    if LFilterResult.Passed <> 1 then
    begin
      FailTest('glob b* expected 1 passed, got ' + IntToStr(LFilterResult.Passed));
    end;
    if LFilterResult.Skipped <> 0 then
    begin
      FailTest('glob b* expected 0 skipped, got ' + IntToStr(LFilterResult.Skipped));
    end;
    SetTestFilter('');
    PassTest('Glob filter (b* matches beta)');
  end;

  { ── R4-08: Empty suite run ───────────────────────────────────────────────── }
  begin
    LEmptySuite := TTestSuite.Create('Empty');
    if not LEmptySuite.RunWithResult(LEmptyResult) then
    begin
      FailTest('Empty suite should return True (AllPassed)');
    end;
    if not LEmptyResult.AllPassed then
    begin
      FailTest('Empty suite AllPassed should be True');
    end;
    if LEmptyResult.Passed <> 0 then
    begin
      FailTest('Empty suite Passed should be 0');
    end;
    if LEmptyResult.Skipped <> 0 then
    begin
      FailTest('Empty suite Skipped should be 0');
    end;
    PassTest('Empty suite run');
  end;

  { ── R6-58: ParseFilter helper (white-box) ─────────────────────────────────── }
  WriteLn;
  SectionHeader('R6-58: ParseFilter helper');
  begin
    { 白盒测试：直接验证 runner 内部命令行解析 helper。 }
    if nextpas.core.test.runner.ParseFilter('--filter=alpha') <> 'alpha' then
    begin
      FailTest('ParseFilter should extract alpha');
    end;
    if nextpas.core.test.runner.ParseFilter('--other=beta') <> '' then
    begin
      FailTest('ParseFilter should ignore unrelated args');
    end;
    if nextpas.core.test.runner.ParseFilter('--filter=foo=bar') <> 'foo=bar' then
    begin
      FailTest('ParseFilter should preserve embedded equals');
    end;
    PassTest('ParseFilter helper');
  end;

  WriteLn;
  SectionHeader('R6-58b: ParseTag helper');
  begin
    if nextpas.core.test.runner.ParseTag('--tag=fast') <> 'fast' then
    begin
      FailTest('ParseTag should extract fast');
    end;
    if nextpas.core.test.runner.ParseTag('--other=fast') <> '' then
    begin
      FailTest('ParseTag should ignore unrelated args');
    end;
    if nextpas.core.test.runner.ParseTag('--tag=core-http') <> 'core-http' then
    begin
      FailTest('ParseTag should preserve hyphenated values');
    end;
    PassTest('ParseTag helper');
  end;

  { ── R6-59: AddLine / JoinLines helpers ────────────────────────────────────── }
  WriteLn;
  SectionHeader('R6-59: AddLine / JoinLines');
  begin
    SetLength(LLines59, 0);
    AddLine(LLines59, 'first');
    AddLine(LLines59, 'second');
    AddLine(LLines59, 'third');
    if Length(LLines59) <> 3 then
    begin
      FailTest('expected 3 lines after AddLine, got ' + IntToStr(Length(LLines59)));
    end;
    if LLines59[0] <> 'first' then
    begin
      FailTest('expected "first", got "' + LLines59[0] + '"');
    end;
    if LLines59[2] <> 'third' then
    begin
      FailTest('expected "third", got "' + LLines59[2] + '"');
    end;

    LJoined59 := JoinLines(LLines59);
    if Pos('first', LJoined59) = 0 then
    begin
      FailTest('JoinLines should contain "first"');
    end;
    if Pos('second', LJoined59) = 0 then
    begin
      FailTest('JoinLines should contain "second"');
    end;
    if Pos('third', LJoined59) = 0 then
    begin
      FailTest('JoinLines should contain "third"');
    end;
    PassTest('AddLine / JoinLines');
  end;

  { ── R6-59: JoinLines empty ────────────────────────────────────────────────── }
  begin
    SetLength(LEmpty59, 0);
    if JoinLines(LEmpty59) <> '' then
    begin
      FailTest('JoinLines on empty array should return empty string');
    end;
    PassTest('JoinLines empty');
  end;

  { ── R6-60: TTestRunResult default values ─────────────────────────────────── }
  WriteLn;
  SectionHeader('R6-60: TTestRunResult defaults');
  begin
    LDefaults60 := TTestRunResult.Create('my_suite');
    if LDefaults60.SuiteName <> 'my_suite' then
    begin
      FailTest('SuiteName should be my_suite');
    end;
    if LDefaults60.Passed <> 0 then
    begin
      FailTest('Passed should be 0, got ' + IntToStr(LDefaults60.Passed));
    end;
    if LDefaults60.Failed <> 0 then
    begin
      FailTest('Failed should be 0, got ' + IntToStr(LDefaults60.Failed));
    end;
    if LDefaults60.Skipped <> 0 then
    begin
      FailTest('Skipped should be 0, got ' + IntToStr(LDefaults60.Skipped));
    end;
    if not LDefaults60.AllPassed then
    begin
      FailTest('AllPassed should be True for fresh TTestRunResult');
    end;
    if Length(LDefaults60.Results) <> 0 then
    begin
      FailTest('Results should be empty');
    end;
    PassTest('TTestRunResult defaults');
  end;

  { ── R6-68: Strong assertions replacing Count > 0 ─────────────────────────── }
  { The existing lifecycle counter tests already use exact equality (GSetupCalled <> 1).
    This test confirms TotalPass/TotalFail exactness after a known run. }
  WriteLn;
  SectionHeader('R6-68: Strong exact-value assertions');
  begin
    LExactSuite68 := TTestSuite.Create('Exact Suite');
    LExactSuite68.Test('p1', @TestSimplePass);
    LExactSuite68.Test('p2', @TestSimplePass2);
    LExactSuite68.Skip('s1', 'planned');
    LExactRunner68 := TTestRunner.Create('Exact Runner');
    LExactRunner68.Add(LExactSuite68);
    LExactRunner68.RunAll;
    { R6-68: Use exact value checks, not weak "Count > 0" }
    if LExactRunner68.TotalPass <> 2 then
    begin
      FailTest('expected exactly 2 passes, got ' + IntToStr(LExactRunner68.TotalPass));
    end;
    if LExactRunner68.TotalFail <> 0 then
    begin
      FailTest('expected exactly 0 failures, got ' + IntToStr(LExactRunner68.TotalFail));
    end;
    if LExactRunner68.TotalSkip <> 1 then
    begin
      FailTest('expected exactly 1 skip, got ' + IntToStr(LExactRunner68.TotalSkip));
    end;
    PassTest('Exact-value assertions');
  end;

  WriteLn;
  SectionHeader('R2-F23: Runner config isolation');
  TestRunnerConfigIsolation;

  { ── Phase 2: With* builder pattern ───────────────────────────────────────── }
  WriteLn;
  SectionHeader('Phase 2: With* Builder Pattern');
  begin
    LRunCount := 0;
    LBeforeEachCounter := 0;
    LResultSuite := TTestSuite.Create('WithChain')
      .WithSetup(procedure begin Inc(GSetupCalled); end)
      .WithTeardown(procedure begin Inc(GTeardownCalled); end)
      .WithBeforeEach(procedure begin Inc(LBeforeEachCounter); end)
      .WithAfterEach(procedure begin Inc(GAfterEachCalled); end);
    LResultSuite.Test('chained pass', procedure begin
      InterLockedIncrement(LRunCount);
      CheckTrue(True);
    end);
    LResultSuite.Test('chained pass 2', procedure begin
      InterLockedIncrement(LRunCount);
      CheckTrue(True);
    end);
    if not LResultSuite.Run then
    begin
      FailTest('With* chain should pass');
    end;
    if LRunCount <> 2 then
    begin
      FailTest('expected 2 tests run, got ' + IntToStr(LRunCount));
    end;
    PassTest('With* builder pattern');
  end;

  { ── Phase 2: With* preserves existing API ────────────────────────────────── }
  WriteLn;
  SectionHeader('Phase 2: SetSetup + WithConfig');
  begin
    LRunCount := 0;
    LResultSuite := TTestSuite.Create('Mixed API');
    LResultSuite.SetSetup(procedure begin Inc(GSetupCalled); end);
    LResultSuite.Test('mixed test', procedure begin
      InterLockedIncrement(LRunCount);
      CheckTrue(True);
    end);
    if not LResultSuite.Run then
    begin
      FailTest('mixed API should pass');
    end;
    if LRunCount <> 1 then
    begin
      FailTest('expected 1 test run, got ' + IntToStr(LRunCount));
    end;
    PassTest('Mixed API compatibility');
  end;

  WriteLn;
  SectionHeader('R6-69: Regular Test CapturedLog');
  begin
    LResultSuite := TTestSuite.Create('Regular Log');
    LResultSuite.Test('log and fail', @TestRegularLogFailure);
    if LResultSuite.RunWithResult(LRegularLogResult) then
    begin
      FailTest('logged failure test should return False');
    end;
    if Length(LRegularLogResult.Results) <> 1 then
    begin
      FailTest('expected 1 logged result, got ' + IntToStr(Length(LRegularLogResult.Results)));
    end;
    if LRegularLogResult.Results[0].Status <> tsFailed then
    begin
      FailTest('logged result should be tsFailed, got ' + IntToStr(Ord(LRegularLogResult.Results[0].Status)));
    end;
    if Length(LRegularLogResult.Results[0].CapturedLog) <> 1 then
    begin
      FailTest('expected exactly 1 captured log line, got ' + IntToStr(Length(LRegularLogResult.Results[0].CapturedLog)));
    end;
    if LRegularLogResult.Results[0].CapturedLog[0] <> 'hello' then
    begin
      FailTest('captured log mismatch, got ' + LRegularLogResult.Results[0].CapturedLog[0]);
    end;
    PassTest('Regular test captured log');
  end;

  WriteLn;
  PassTest('test_runner');
end.
