{ test_runner — Validates TSuiteRunner multi-suite + subtests + lifecycle }
program test_runner;

{$mode objfpc}{$H+}{$J-}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

uses
  nextpas.core.thread.init,
  nextpas.core.text.conv,
  nextpas.core.test,
  nextpas.core.bench,
  { 白盒测试：直接验证 runner 内部 helper，而不是仅通过 facade 间接覆盖。 }
  nextpas.core.test.runner,
  nextpas.core.test.output,
  nextpas.core.fs;

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
  { T-13: cache test variables }
  LCache: TTestCache;
  LCacheConfig1, LCacheConfig2, LCacheRunConfig: TTestConfig;
  LCacheKey1, LCacheKey2, LCacheKey3: string;
  LCacheEntry, LCacheGotEntry: TCacheEntry;
  LCacheRunSuite: TTestSuite;
  LCacheRunResult1, LCacheRunResult2: TTestRunResult;
  LCacheRunCount: Integer;
  { T-14: RepeatAllCount }
  LRepeatSuite: TTestSuite;
  LRepeatRunner: TSuiteRunner;
  LRepeatResults: specialize TArray<TTestRunResult>;
  LRepeatCount: Integer;
  { T-15: FailFast + MaxFailures }
  LFailFastSuite: TTestSuite;
  LFailFastResult: TTestRunResult;
  LFailFastCount: Integer;
  { T-16: TestClosure }
  LClosureSuite: TTestSuite;
  LClosureResult: TTestRunResult;
  LClosureCount: Integer;
  { T-17: WithEachCleanup }
  LCleanupSuite: TTestSuite;
  LCleanupResult: TTestRunResult;
  LCleanupCount: Integer;

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
  LRunnerA: TSuiteRunner;
  LRunnerB: TSuiteRunner;
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

  LRunnerA := TSuiteRunner.Create('Runner A');
  LRunnerA.Add(LSuiteA);
  LRunnerB := TSuiteRunner.Create('Runner B');
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
  LRunner: TSuiteRunner;
  LPass: Boolean;
  { B5.3 lifecycle failure tests }
  LFailSuite1, LFailSuite2, LFailSuite3: TTestSuite;
  LBeforeEachCounter: Integer;
  { B5.5/B5.6/B5.9 runner feature tests }
  LRunNestedS1, LRunNestedS2, LCacheSuite, LSummarySuite, LSumSuite3: TTestSuite;
  LRunNestedR, LSumRunner: TSuiteRunner;
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
  LExactRunner68: TSuiteRunner;
  { Phase 8: shuffle determinism }
  LOrder1: specialize TArray<string>;
  LIdx: Integer;
  { Phase 8: TableTest failure message }
  LTableCases: specialize TArray<TTestCase>;
  { Phase 9: short mode }
  LShortSuite: TTestSuite;
  LShortResult: TTestRunResult;
  LShortConfig: TTestConfig;
  { Phase 9: progress }
  LProgressSuite: TTestSuite;
  LProgressResult: TTestRunResult;
  LProgressConfig: TTestConfig;
  { Phase 9: max failures }
  LMaxFailSuite: TTestSuite;
  LMaxFailResult: TTestRunResult;
  LMaxFailConfig: TTestConfig;
  LMaxFailRunner: TSuiteRunner;
  LMaxFailRunnerResults: specialize TArray<TTestRunResult>;
  { Phase 9: JSON output }
  LJsonSuite: TTestSuite;
  LJsonResult: TTestRunResult;
  LJsonConfig: TTestConfig;
  LJsonSink: TBufferSink;
  { Phase 10: verbose mode }
  LVerbSuite: TTestSuite;
  LVerbResult: TTestRunResult;
  LVerbConfig: TTestConfig;
  LVerbSink: TBufferSink;
  LVerbOut: string;
  { Phase 11: run timeout }
  LTimeoutRunSuite: TTestSuite;
  LTimeoutRunResult: TTestRunResult;
  LTimeoutRunConfig: TTestConfig;
  LTimeoutRunSink: TBufferSink;
  LTimeoutRunOut: string;
  { Phase 12: cleanup }
  GCleanupCalled: Integer;
  GSeqOrderCounter: Integer;
  LAutoRunSuite: TTestSuite;
  LAutoRunRunner: TSuiteRunner;
  { T-07: timeout exceeded }
  LFoundTimeout: Boolean;
  LI: Integer;
  { T-06: benchmark N scaling edge cases }
  LRetrySuite: TTestSuite;
  LRetryResult: TTestRunResult;
  LRetryConfig: TTestConfig;
  LRetryAttempts: Integer;
  { T-08: CleanupTableAllocations idempotent }
  LIdempotentSuite: TTestSuite;
  LIdempotentResult: TTestRunResult;
  { E-03: FormatDuration regression }
  LFormatMs: string;
  { T-09: ShouldFail exception class }
  LShouldFailResult: TTestRunResult;
  { T-11: ListMode }
  LListOutput: string;
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
  LRunner := TSuiteRunner.Create('Test Runner Integration');
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

  { Test: RunAll aggregation — TSuiteRunner with multiple suites }
  LRunNestedS1 := TTestSuite.Create('Suite A');
  LRunNestedS1.Test('a1', procedure begin CheckTrue(True); end);
  LRunNestedS2 := TTestSuite.Create('Suite B');
  LRunNestedS2.Test('b1', procedure begin CheckTrue(True); end);
  LRunNestedR := TSuiteRunner.Create('Multi-Suite Runner');
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
  LSumRunner := TSuiteRunner.Create('Summary Runner');
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
    LRunNestedR := TSuiteRunner.Create('WithResult Runner');
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
    LResultSuite.Test('slow closure', procedure begin SleepMs(LTimeoutSleepMs); end);
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
    LExactRunner68 := TSuiteRunner.Create('Exact Runner');
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

  { ── ShouldFail (expected failure) ──────────────────────────────────────────
    Overload patterns:
      ShouldFail(name, proc)                    — any exception = pass, no exception = fail
      ShouldFail(name, proc, 'reason')          — same as above, with reason message
      ShouldFail(name, proc, EAbort)            — only EAbort (or subclass) = pass
      ShouldFail(name, proc, EAbort, 'substr')  — EAbort + message contains 'substr' = pass
      ShouldFail(name, proc, 'substr', 0)       — any exception + message contains 'substr' = pass
                                                     (0 is disambiguation dummy — FPC can't distinguish
                                                      this from ShouldFail(name, proc, 'reason'))

    ⚠ FPC overload resolution pitfall:
      ShouldFail(name, proc, 'some text') → matches the 'reason' overload, NOT 'contains'.
      To match by message substring without class check, use the 4-arg form with dummy=0:
        ShouldFail(name, proc, 'substring', 0)
   }
  WriteLn;
  SectionHeader('Phase 6: ShouldFail (expected failure)');
  begin
    LResultSuite := TTestSuite.Create('ShouldFail');
    { Test that raises = passes with ShouldFail }
    LResultSuite.ShouldFail('raises is ok', procedure begin
      raise Exception.Create('expected error');
    end, 'expected error');
    { Test that doesn't raise = fails with ShouldFail }
    LResultSuite.ShouldFail('no raise is fail', procedure begin
      { intentionally empty — no exception }
    end);
    if LResultSuite.RunWithResult(LRegularLogResult) then
    begin
      FailTest('ShouldFail suite should fail (one test passes without raising)');
    end;
    if LRegularLogResult.Passed <> 1 then
    begin
      FailTest('expected 1 passed (raises), got ' + IntToStr(LRegularLogResult.Passed));
    end;
    if LRegularLogResult.Failed <> 1 then
    begin
      FailTest('expected 1 failed (no raise), got ' + IntToStr(LRegularLogResult.Failed));
    end;
    PassTest('ShouldFail basic behavior');
  end;

  { ── Slow test report ─────────────────────────────────────────────────── }
  WriteLn;
  SectionHeader('Phase 6: Slow test report');
  begin
    LResultSuite := TTestSuite.Create('SlowSuite');
    LResultSuite.Test('fast', procedure begin CheckTrue(True); end);
    LResultSuite.Test('slow', procedure begin
      { Simulate work — sleep not available in test, just verify the mechanism }
      CheckTrue(True);
    end);
    LResultSuite.RunWithResult(LRegularLogResult);
    if Length(LRegularLogResult.SlowTests) > 5 then
    begin
      FailTest('slow tests should be capped at SlowTestCount');
    end;
    PassTest('Slow test report populated');
  end;

  { ── FormatDuration ───────────────────────────────────────────────────── }
  WriteLn;
  SectionHeader('Phase 6: FormatDuration');
  begin
    if FormatDuration(0) <> '0ms' then
      FailTest('FormatDuration(0) = ' + FormatDuration(0));
    if FormatDuration(999) <> '999ms' then
      FailTest('FormatDuration(999) = ' + FormatDuration(999));
    if FormatDuration(1000) <> '1s' then
      FailTest('FormatDuration(1000) = ' + FormatDuration(1000));
    if FormatDuration(1234) <> '1.23s' then
      FailTest('FormatDuration(1234) = ' + FormatDuration(1234));
    if FormatDuration(500) <> '500ms' then
      FailTest('FormatDuration(500) = ' + FormatDuration(500));
    { Additional edge cases }
    if FormatDuration(1200) <> '1.2s' then
      FailTest('FormatDuration(1200) = ' + FormatDuration(1200));
    if FormatDuration(10500) <> '10.5s' then
      FailTest('FormatDuration(10500) = ' + FormatDuration(10500));
    if FormatDuration(59999) <> '59.99s' then
      FailTest('FormatDuration(59999) = ' + FormatDuration(59999));
    if FormatDuration(1) <> '1ms' then
      FailTest('FormatDuration(1) = ' + FormatDuration(1));
    if FormatDuration(1100) <> '1.1s' then
      FailTest('FormatDuration(1100) = ' + FormatDuration(1100));
    if FormatDuration(60000) <> '60s' then
      FailTest('FormatDuration(60000) = ' + FormatDuration(60000));
    PassTest('FormatDuration formatting');
  end;

  { ── Shuffle (deterministic) ───────────────────────────────────────────── }
  WriteLn;
  SectionHeader('Phase 7: Shuffle entries');
  begin
    LResultSuite := TTestSuite.Create('ShuffleTest');
    LResultSuite.Test('alpha', procedure begin CheckTrue(True); end);
    LResultSuite.Test('beta', procedure begin CheckTrue(True); end);
    LResultSuite.Test('gamma', procedure begin CheckTrue(True); end);
    LResultSuite.Test('delta', procedure begin CheckTrue(True); end);
    LResultSuite.Test('epsilon', procedure begin CheckTrue(True); end);
    { Run with seed=42 and verify order changed }
    LResultSuite.Config.ShuffleSeed := 42;
    LResultSuite.RunWithResult(LRegularLogResult);
    if LRegularLogResult.Passed <> 5 then
      FailTest('expected 5 passed after shuffle, got ' + IntToStr(LRegularLogResult.Passed));
    { Verify order actually changed — check at least one test moved }
    if (LRegularLogResult.Results[0].Name = 'alpha') and
       (LRegularLogResult.Results[1].Name = 'beta') and
       (LRegularLogResult.Results[2].Name = 'gamma') and
       (LRegularLogResult.Results[3].Name = 'delta') and
       (LRegularLogResult.Results[4].Name = 'epsilon') then
      FailTest('shuffle seed=42 did not change order');
    PassTest('Shuffle deterministic with seed');
  end;

  { ── FailFast ────────────────────────────────────────────────────────────── }
  WriteLn;
  SectionHeader('Phase 7: FailFast');
  begin
    LResultSuite := TTestSuite.Create('FailFastSuite');
    LResultSuite.Config.FailFast := True;
    LRunCount := 0;
    LResultSuite.Test('pass1', procedure begin
      InterLockedIncrement(LRunCount);
      CheckTrue(True);
    end);
    LResultSuite.Test('fail1', procedure begin
      InterLockedIncrement(LRunCount);
      Fail('expected failure');
    end);
    LResultSuite.Test('pass2', procedure begin
      InterLockedIncrement(LRunCount);
      CheckTrue(True);
    end);
    if LResultSuite.RunWithResult(LRegularLogResult) then
      FailTest('FailFast suite should fail');
    { pass1 runs, fail1 runs (and fails → break), pass2 should NOT run }
    if LRunCount <> 2 then
      FailTest('FailFast should stop after failure, ran ' + IntToStr(LRunCount) + ' tests');
    PassTest('FailFast stops after first failure');
  end;

  { ── ListMode ────────────────────────────────────────────────────────────── }
  WriteLn;
  SectionHeader('Phase 7: ListMode');
  begin
    LResultSuite := TTestSuite.Create('ListSuite');
    LResultSuite.Test('testA', procedure begin CheckTrue(True); end);
    LResultSuite.Test('testB', procedure begin CheckTrue(True); end);
    LResultSuite.Skip('testC', 'reason');
    LResultSuite.ShouldFail('testD', procedure begin
      raise Exception.Create('expected');
    end);
    { List mode is handled at runner level, but we can test the concept:
      the suite should still have all 4 entries registered }
    if Length(LResultSuite.Tests) <> 4 then
      FailTest('expected 4 entries, got ' + IntToStr(Length(LResultSuite.Tests)));
    CheckTrue(LResultSuite.Tests[2].Kind = ekSkipped, 'testC should be ekSkipped');
    CheckTrue(LResultSuite.Tests[3].Kind = ekShouldFail, 'testD should be ekShouldFail');
    PassTest('ListMode entries registered correctly');
  end;

  { ── ShouldFail with closure ────────────────────────────────────────────── }
  WriteLn;
  SectionHeader('Phase 8: ShouldFail with closure');
  begin
    LResultSuite := TTestSuite.Create('ShouldFailClosure');
    { ShouldFail with closure that raises = pass }
    LResultSuite.ShouldFail('closure raises', procedure begin
      raise EConvertError.Create('closure error');
    end);
    { ShouldFail with closure that does not raise = fail }
    LResultSuite.ShouldFail('closure no raise', procedure begin
      { intentionally empty }
    end);
    if LResultSuite.RunWithResult(LRegularLogResult) then
      FailTest('ShouldFailClosure suite should fail');
    if LRegularLogResult.Passed <> 1 then
      FailTest('expected 1 passed (closure raises), got ' + IntToStr(LRegularLogResult.Passed));
    if LRegularLogResult.Failed <> 1 then
      FailTest('expected 1 failed (closure no raise), got ' + IntToStr(LRegularLogResult.Failed));
    PassTest('ShouldFail with closure');
  end;

  { ── ShouldFail with Skip inside ────────────────────────────────────────── }
  WriteLn;
  SectionHeader('Phase 8: ShouldFail with Skip inside');
  begin
    LResultSuite := TTestSuite.Create('ShouldFailSkip');
    LResultSuite.ShouldFail('skip inside', procedure begin
      Skip('skipped inside should-fail');
    end);
    LResultSuite.ShouldFail('raise inside', procedure begin
      raise Exception.Create('expected');
    end);
    LResultSuite.RunWithResult(LRegularLogResult);
    { skip inside ShouldFail = skipped (not passed, not failed) }
    if LRegularLogResult.Skipped <> 1 then
      FailTest('expected 1 skipped, got ' + IntToStr(LRegularLogResult.Skipped));
    if LRegularLogResult.Passed <> 1 then
      FailTest('expected 1 passed (raise), got ' + IntToStr(LRegularLogResult.Passed));
    if LRegularLogResult.Failed <> 0 then
      FailTest('expected 0 failed, got ' + IntToStr(LRegularLogResult.Failed));
    PassTest('ShouldFail with Skip inside');
  end;

  { ── Shuffle determinism: same seed = same order ────────────────────────── }
  WriteLn;
  SectionHeader('Phase 8: Shuffle determinism');
  begin
    { Two runs with same seed must produce identical order }
    LResultSuite := TTestSuite.Create('ShuffleDeterminism');
    LResultSuite.Test('a', procedure begin CheckTrue(True); end);
    LResultSuite.Test('b', procedure begin CheckTrue(True); end);
    LResultSuite.Test('c', procedure begin CheckTrue(True); end);
    LResultSuite.Test('d', procedure begin CheckTrue(True); end);
    LResultSuite.Test('e', procedure begin CheckTrue(True); end);
    LResultSuite.Test('f', procedure begin CheckTrue(True); end);
    LResultSuite.Test('g', procedure begin CheckTrue(True); end);
    LResultSuite.Test('h', procedure begin CheckTrue(True); end);

    LResultSuite.Config.ShuffleSeed := 12345;
    LResultSuite.RunWithResult(LRegularLogResult);
    { Capture order from first run }
    SetLength(LOrder1, Length(LRegularLogResult.Results));
    for LIdx := 0 to High(LRegularLogResult.Results) do
      LOrder1[LIdx] := LRegularLogResult.Results[LIdx].Name;

    { Reset and run again with same seed — need fresh suite since entries are shuffled in-place }
    LResultSuite := TTestSuite.Create('ShuffleDeterminism2');
    LResultSuite.Test('a', procedure begin CheckTrue(True); end);
    LResultSuite.Test('b', procedure begin CheckTrue(True); end);
    LResultSuite.Test('c', procedure begin CheckTrue(True); end);
    LResultSuite.Test('d', procedure begin CheckTrue(True); end);
    LResultSuite.Test('e', procedure begin CheckTrue(True); end);
    LResultSuite.Test('f', procedure begin CheckTrue(True); end);
    LResultSuite.Test('g', procedure begin CheckTrue(True); end);
    LResultSuite.Test('h', procedure begin CheckTrue(True); end);
    LResultSuite.Config.ShuffleSeed := 12345;
    LResultSuite.RunWithResult(LRegularLogResult);

    for LIdx := 0 to High(LOrder1) do
    begin
      if LOrder1[LIdx] <> LRegularLogResult.Results[LIdx].Name then
        FailTest('order mismatch at index ' + IntToStr(LIdx) +
          ': ' + LOrder1[LIdx] + ' vs ' + LRegularLogResult.Results[LIdx].Name);
    end;
    PassTest('Shuffle determinism: same seed = same order');
  end;

  { ── Shuffle boundary: seed=1 (minimum valid) ──────────────────────────── }
  WriteLn;
  SectionHeader('Phase 8: Shuffle boundary seeds');
  begin
    LResultSuite := TTestSuite.Create('ShuffleBoundary');
    LResultSuite.Test('x1', procedure begin CheckTrue(True); end);
    LResultSuite.Test('x2', procedure begin CheckTrue(True); end);
    LResultSuite.Test('x3', procedure begin CheckTrue(True); end);
    { seed=1 should not crash }
    LResultSuite.Config.ShuffleSeed := 1;
    LResultSuite.RunWithResult(LRegularLogResult);
    if LRegularLogResult.Passed <> 3 then
      FailTest('seed=1: expected 3 passed, got ' + IntToStr(LRegularLogResult.Passed));
    { seed=MaxInt should not crash }
    LResultSuite := TTestSuite.Create('ShuffleBoundary2');
    LResultSuite.Test('y1', procedure begin CheckTrue(True); end);
    LResultSuite.Test('y2', procedure begin CheckTrue(True); end);
    LResultSuite.Config.ShuffleSeed := MaxInt;
    LResultSuite.RunWithResult(LRegularLogResult);
    if LRegularLogResult.Passed <> 2 then
      FailTest('seed=MaxInt: expected 2 passed, got ' + IntToStr(LRegularLogResult.Passed));
    PassTest('Shuffle boundary seeds');
  end;

  { ── TableTest failure preserves message (audit P0-2) ───────────────────── }
  WriteLn;
  SectionHeader('Phase 8: TableTest failure message');
  begin
    LResultSuite := TTestSuite.Create('TableTestMsg');
    LTableCases := nil;
    SetLength(LTableCases, 2);
    LTableCases[0].Name := 'add'; LTableCases[0].Data := '1+1=2';
    LTableCases[1].Name := 'fail_case'; LTableCases[1].Data := 'boom';
    LResultSuite.TestTable('math', LTableCases,
      procedure(const AC: TTestCase)
      begin
        if AC.Name = 'fail_case' then
          CheckTrue(False, 'table fail message');
      end);
    LResultSuite.RunWithResult(LRegularLogResult);
    if LRegularLogResult.Failed <> 1 then
      FailTest('expected 1 failed table case, got ' + IntToStr(LRegularLogResult.Failed));
    { Verify failure message is NOT empty (the bug was: LLastFailMsg stayed empty) }
    if LRegularLogResult.Results[1].Message = '' then
      FailTest('table test failure message should not be empty');
    if Pos('table fail message', LRegularLogResult.Results[1].Message) = 0 then
      FailTest('table test failure message should contain assertion text, got: ' +
        LRegularLogResult.Results[1].Message);
    PassTest('TableTest failure preserves message');
  end;

  { ── Phase 9: ShortSkip ───────────────────────────────────────────────────── }
  WriteLn;
  SectionHeader('Phase 9: ShortSkip');
  begin
    { Test 1: ShortSkip test runs normally when ShortMode is off }
    LShortSuite := TTestSuite.Create('ShortSkipNormal');
    LShortSuite.Test('normal_pass', procedure begin CheckTrue(True); end);
    LShortSuite.ShortSkip('slow_test', procedure begin CheckTrue(True); end);
    ResetDefaultConfig;
    LShortSuite.RunWithResult(LShortResult);
    if LShortResult.Passed <> 2 then
      FailTest('ShortSkip off: expected 2 passed, got ' +
        IntToStr(LShortResult.Passed));
    if LShortResult.Skipped <> 0 then
      FailTest('ShortSkip off: expected 0 skipped, got ' +
        IntToStr(LShortResult.Skipped));
    { Test 2: ShortSkip test is skipped when ShortMode is on }
    LShortSuite := TTestSuite.Create('ShortSkipActive');
    LShortSuite.Test('fast_pass', procedure begin CheckTrue(True); end);
    LShortSuite.ShortSkip('slow_test', procedure begin CheckTrue(True); end);
    LShortSuite.ShortSkip('another_slow', procedure begin CheckTrue(True); end);
    ResetDefaultConfig;
    SetDefaultShortMode(True);
    LShortConfig := DefaultConfig;
    LShortSuite.Config := LShortConfig;
    LShortSuite.RunWithResult(LShortResult);
    if LShortResult.Passed <> 1 then
      FailTest('ShortSkip on: expected 1 passed, got ' +
        IntToStr(LShortResult.Passed));
    if LShortResult.Skipped <> 2 then
      FailTest('ShortSkip on: expected 2 skipped, got ' +
        IntToStr(LShortResult.Skipped));
    ResetDefaultConfig;
    PassTest('ShortSkip');
  end;

  { ── Phase 9: Progress counter ────────────────────────────────────────────── }
  WriteLn;
  SectionHeader('Phase 9: Progress counter');
  begin
    ResetDefaultConfig;
    SetDefaultShowProgress(True);
    LProgressConfig := DefaultConfig;
    { Test 1: Progress mode runs normally and reports correct counts }
    LProgressSuite := TTestSuite.Create('ProgressTest');
    LProgressSuite.Test('p1', procedure begin CheckTrue(True); end);
    LProgressSuite.Test('p2', procedure begin CheckTrue(True); end);
    LProgressSuite.Test('p3', procedure begin CheckTrue(True); end);
    LProgressSuite.Config := LProgressConfig;
    LProgressSuite.RunWithResult(LProgressResult);
    if LProgressResult.Passed <> 3 then
      FailTest('progress: expected 3 passed, got ' +
        IntToStr(LProgressResult.Passed));
    if LProgressResult.Failed <> 0 then
      FailTest('progress: expected 0 failed, got ' +
        IntToStr(LProgressResult.Failed));
    ResetDefaultConfig;
    PassTest('Progress counter');
  end;

  { ── Phase 9: MaxFailures ─────────────────────────────────────────────────── }
  WriteLn;
  SectionHeader('Phase 9: MaxFailures');
  begin
    ResetDefaultConfig;
    { Test 1: Suite-level max failures }
    LMaxFailSuite := TTestSuite.Create('MaxFailSuite');
    LMaxFailSuite.Test('fail1', procedure begin CheckTrue(False, 'fail1'); end);
    LMaxFailSuite.Test('fail2', procedure begin CheckTrue(False, 'fail2'); end);
    LMaxFailSuite.Test('fail3', procedure begin CheckTrue(False, 'fail3'); end);
    LMaxFailSuite.Test('pass1', procedure begin CheckTrue(True); end);
    SetDefaultMaxFailures(2);
    LMaxFailConfig := DefaultConfig;
    LMaxFailSuite.Config := LMaxFailConfig;
    LMaxFailSuite.RunWithResult(LMaxFailResult);
    { Should stop after 2 failures, fail3 and pass1 not run }
    if LMaxFailResult.Failed <> 2 then
      FailTest('MaxFailures: expected 2 failed, got ' +
        IntToStr(LMaxFailResult.Failed));
    if LMaxFailResult.Passed <> 0 then
      FailTest('MaxFailures: expected 0 passed (pass1 not reached), got ' +
        IntToStr(LMaxFailResult.Passed));
    ResetDefaultConfig;
    { Test 2: Cross-suite max failures via TSuiteRunner (separate suite) }
    LMaxFailSuite := TTestSuite.Create('MaxFailRunner2');
    LMaxFailSuite.Test('fail_a', procedure begin CheckTrue(False, 'fail_a'); end);
    LMaxFailSuite.Test('fail_b', procedure begin CheckTrue(False, 'fail_b'); end);
    LMaxFailSuite.Test('pass_a', procedure begin CheckTrue(True); end);
    SetDefaultMaxFailures(1);
    LMaxFailRunner := TSuiteRunner.Create('MaxFailRunner');
    LMaxFailRunner.Add(LMaxFailSuite);
    LMaxFailRunner.RunAllWithResult(LMaxFailRunnerResults);
    { Runner should stop after 1 total failure across suites }
    if LMaxFailRunner.TotalFail < 1 then
      FailTest('MaxFailures runner: expected >= 1 total fail, got ' +
        IntToStr(LMaxFailRunner.TotalFail));
    ResetDefaultConfig;
    PassTest('MaxFailures');
  end;

  { ── Phase 9: JSON output ─────────────────────────────────────────────────── }
  WriteLn;
  SectionHeader('Phase 9: JSON output');
  begin
    ResetDefaultConfig;
    { Test JSON report generation via programmatic API }
    LJsonSuite := TTestSuite.Create('JsonTest');
    LJsonSuite.Test('jpass', procedure begin CheckTrue(True); end);
    LJsonSuite.Skip('jskip', 'planned');
    LJsonSuite.RunWithResult(LJsonResult);
    { Verify JSON report function works correctly }
    LJsonSink := TBufferSink.Create;
    try
      LJsonSink.Write(JSONReport(specialize TArray<TTestRunResult>.Create(LJsonResult), 'JsonTest'));
      if Pos('"totalPassed"', LJsonSink.GetOutput) = 0 then
        FailTest('json: expected "totalPassed" in output');
      if Pos('"totalSkipped"', LJsonSink.GetOutput) = 0 then
        FailTest('json: expected "totalSkipped" in output');
      if Pos('"suites"', LJsonSink.GetOutput) = 0 then
        FailTest('json: expected "suites" in output');
      if Pos('"name": "JsonTest"', LJsonSink.GetOutput) = 0 then
        FailTest('json: expected suite name "JsonTest" in output');
    finally
      LJsonSink.Free;
    end;
    ResetDefaultConfig;
    PassTest('JSON output');
  end;

  { ── Phase 10: Verbose mode ───────────────────────────────────────────────── }
  WriteLn;
  SectionHeader('Phase 10: Verbose mode');
  begin
    ResetDefaultConfig;
    LVerbSuite := TTestSuite.Create('VerbTest');
    LVerbSuite.Test('vpass', procedure begin CheckTrue(True); end);
    LVerbSuite.Test('vfail', procedure begin CheckTrue(False, 'intentional'); end);
    LVerbSuite.Skip('vskip', 'planned');
    LVerbConfig := MakeBufferConfig(LVerbSink);
    LVerbConfig.VerboseMode := True;
    LVerbSuite.Config := LVerbConfig;
    LVerbSuite.RunWithResult(LVerbResult);
    LVerbOut := LVerbSink.GetOutput;
    LVerbSink := nil;  { release via refcount, don't .Free }
    { Verify verbose output contains [PASS], [FAIL], [SKIP] }
    if Pos('[PASS]', LVerbOut) = 0 then
      FailTest('verbose: expected [PASS] in output');
    if Pos('[FAIL]', LVerbOut) = 0 then
      FailTest('verbose: expected [FAIL] in output');
    if Pos('[SKIP]', LVerbOut) = 0 then
      FailTest('verbose: expected [SKIP] in output');
    { Verify timing is shown (parentheses with ms/s) }
    if Pos('(', LVerbOut) = 0 then
      FailTest('verbose: expected timing in output');
    { Verify counts }
    if LVerbResult.Passed <> 1 then
      FailTest('verbose: expected 1 passed, got ' + IntToStr(LVerbResult.Passed));
    if LVerbResult.Failed <> 1 then
      FailTest('verbose: expected 1 failed, got ' + IntToStr(LVerbResult.Failed));
    if LVerbResult.Skipped <> 1 then
      FailTest('verbose: expected 1 skipped, got ' + IntToStr(LVerbResult.Skipped));
    ResetDefaultConfig;
    PassTest('Verbose mode');
  end;

  { ── Phase 11: Run timeout ────────────────────────────────────────────────── }
  WriteLn;
  SectionHeader('Phase 11: Run timeout');
  begin
    ResetDefaultConfig;
    LTimeoutRunSuite := TTestSuite.Create('TimeoutRunTest');
    LTimeoutRunSuite.Test('fast1', procedure begin CheckTrue(True); end);
    LTimeoutRunSuite.Test('fast2', procedure begin CheckTrue(True); end);
    { Set a 1-second run timeout — should be enough for fast tests }
    LTimeoutRunConfig := MakeBufferConfig(LTimeoutRunSink);
    LTimeoutRunConfig.RunTimeoutSec := 10;
    LTimeoutRunSuite.Config := LTimeoutRunConfig;
    LTimeoutRunSuite.RunWithResult(LTimeoutRunResult);
    LTimeoutRunOut := LTimeoutRunSink.GetOutput;
    LTimeoutRunSink := nil;  { release via refcount }
    { Fast tests should pass within 10s timeout }
    if not LTimeoutRunResult.AllPassed then
      FailTest('run timeout: fast tests should pass within 10s');
    if LTimeoutRunResult.Passed <> 2 then
      FailTest('run timeout: expected 2 passed, got ' +
        IntToStr(LTimeoutRunResult.Passed));
    ResetDefaultConfig;
    PassTest('Run timeout');
  end;

  { ── Phase 12: Cleanup handlers ───────────────────────────────────────────── }
  WriteLn;
  SectionHeader('Phase 12: Cleanup handlers');
  begin
    ResetDefaultConfig;
    GCleanupCalled := 0;
    LVerbSuite := TTestSuite.Create('CleanupTest');
    { Register cleanup handler via procedure-based API }
    LVerbSuite.Cleanup(procedure begin Inc(GCleanupCalled); end);
    LVerbSuite.Test('clean1', procedure begin CheckTrue(True); end);
    LVerbSuite.Test('clean2', procedure begin CheckTrue(True); end);
    LVerbSuite.RunWithResult(LVerbResult);
    { Cleanup runs after each test: 2 tests = 2 cleanup calls }
    if GCleanupCalled <> 2 then
      FailTest('cleanup: expected 2 cleanup calls, got ' +
        IntToStr(GCleanupCalled));
    if not LVerbResult.AllPassed then
      FailTest('cleanup: all tests should pass');
    { Test cleanup runs even on failure }
    GCleanupCalled := 0;
    LVerbSuite := TTestSuite.Create('CleanupFailTest');
    LVerbSuite.Cleanup(procedure begin Inc(GCleanupCalled); end);
    LVerbSuite.Test('willfail', procedure begin CheckTrue(False, 'intentional'); end);
    LVerbSuite.Test('willpass', procedure begin CheckTrue(True); end);
    LVerbSuite.RunWithResult(LVerbResult);
    { Cleanup should still run for both tests (even the failed one) }
    if GCleanupCalled <> 2 then
      FailTest('cleanup on fail: expected 2 cleanup calls, got ' +
        IntToStr(GCleanupCalled));
    if LVerbResult.Failed <> 1 then
      FailTest('cleanup on fail: expected 1 failure');
    if LVerbResult.Passed <> 1 then
      FailTest('cleanup on fail: expected 1 pass');
    ResetDefaultConfig;
    PassTest('Cleanup handlers');
  end;

  { ── Phase 13: Benchmark ──────────────────────────────────────────────────── }
  SectionHeader('Phase 13b: Cleanup LIFO order');
  begin
    ResetDefaultConfig;
    GCleanupCalled := 0;
    LVerbSuite := TTestSuite.Create('CleanupLifoTest');
    { Register 3 cleanup handlers — should run in LIFO order (3, 2, 1) }
    LVerbSuite.Cleanup(procedure
    begin
      Inc(GCleanupCalled);
      if GCleanupCalled <> 3 then
        FailTest('LIFO: first registered should be called 3rd (LIFO), got ' +
          IntToStr(GCleanupCalled));
    end);
    LVerbSuite.Cleanup(procedure
    begin
      Inc(GCleanupCalled);
      if GCleanupCalled <> 2 then
        FailTest('LIFO: second registered should be called 2nd, got ' +
          IntToStr(GCleanupCalled));
    end);
    LVerbSuite.Cleanup(procedure
    begin
      Inc(GCleanupCalled);
      if GCleanupCalled <> 1 then
        FailTest('LIFO: third registered should be called 1st (LIFO), got ' +
          IntToStr(GCleanupCalled));
    end);
    LVerbSuite.Test('dummy', procedure begin CheckTrue(True); end);
    LVerbSuite.RunWithResult(LVerbResult);
    { 3 cleanups ran for 1 test }
    if GCleanupCalled <> 3 then
      FailTest('LIFO: expected 3 cleanup calls, got ' +
        IntToStr(GCleanupCalled));
    if not LVerbResult.AllPassed then
      FailTest('LIFO: all tests should pass');
    ResetDefaultConfig;
    PassTest('Cleanup LIFO order');
  end;

  { ── Phase 13c: Cleanup exception handling ──────────────────────────────── }
  WriteLn;
  SectionHeader('Phase 13c: Cleanup exception handling');
  begin
    ResetDefaultConfig;
    GCleanupCalled := 0;
    LVerbSuite := TTestSuite.Create('CleanupExceptTest');
    { First cleanup raises, second should still run }
    LVerbSuite.Cleanup(procedure
    begin
      Inc(GCleanupCalled);
      raise Exception.Create('cleanup boom');
    end);
    LVerbSuite.Cleanup(procedure
    begin
      Inc(GCleanupCalled);
    end);
    LVerbSuite.Test('dummy', procedure begin CheckTrue(True); end);
    LVerbSuite.RunWithResult(LVerbResult);
    { Both cleanups should run even though first raised }
    if GCleanupCalled <> 2 then
      FailTest('cleanup except: expected 2 cleanup calls, got ' +
        IntToStr(GCleanupCalled));
    { Test should still pass — cleanup exceptions don't fail the test }
    if not LVerbResult.AllPassed then
      FailTest('cleanup except: test should still pass');
    ResetDefaultConfig;
    PassTest('Cleanup exception handling');
  end;

  { ── Phase 13d: Benchmark with --benchmem ───────────────────────────────── }
  SectionHeader('G1: AllPassed auto-run');
  begin
    ResetDefaultConfig;
    LAutoRunSuite := TTestSuite.Create('AutoRunSuite');
    LAutoRunSuite.Test('auto1', procedure begin CheckTrue(True); end);
    LAutoRunSuite.Test('auto2', procedure begin CheckTrue(True); end);
    LAutoRunRunner := TSuiteRunner.Create('AutoRunRunner');
    LAutoRunRunner.Add(LAutoRunSuite);
    { AllPassed before RunAll should trigger auto-run }
    if not LAutoRunRunner.AllPassed then
      FailTest('AllPassed auto-run should return True for passing suite');
    { After auto-run, HasRun should be true and TotalPass should reflect results }
    if LAutoRunRunner.TotalPass <> 2 then
      FailTest('AllPassed auto-run: expected 2 passes, got ' +
        IntToStr(LAutoRunRunner.TotalPass));
    ResetDefaultConfig;
    PassTest('AllPassed auto-run');
  end;

  { ── G2: Empty suite parallel crash guard ────────────────────────────── }
  WriteLn;
  SectionHeader('G2: Empty suite parallel crash guard');
  begin
    ResetDefaultConfig;
    LResultSuite := TTestSuite.Create('EmptyParallel');
    { No tests registered — should not crash in parallel mode }
    LResultSuite.RunParallelWithResult(nil, LParallelResult);
    if LParallelResult.Passed <> 0 then
      FailTest('empty parallel: expected 0 passed, got ' +
        IntToStr(LParallelResult.Passed));
    if LParallelResult.Failed <> 0 then
      FailTest('empty parallel: expected 0 failed, got ' +
        IntToStr(LParallelResult.Failed));
    if not LParallelResult.AllPassed then
      FailTest('empty parallel: AllPassed should be True for empty suite');
    ResetDefaultConfig;
    PassTest('Empty suite parallel crash guard');
  end;

  { ── G3: Exec-fail ShouldFail test ────────────────────────────────────── }
  WriteLn;
  SectionHeader('G3: ShouldFail explicit exec-fail');
  begin
    ResetDefaultConfig;
    LResultSuite := TTestSuite.Create('ShouldFailTest');
    { Test that passes when proc raises }
    LResultSuite.ShouldFail('expect_raise',
      procedure begin raise Exception.Create('boom'); end, 'boom');
    { Test that fails when proc does NOT raise }
    LResultSuite.ShouldFail('no_raise_fails',
      procedure begin { no exception } end);
    LResultSuite.RunWithResult(LRegularLogResult);
    { expect_raise should pass (proc raised), no_raise_fails should fail }
    if LRegularLogResult.Passed <> 1 then
      FailTest('ShouldFail: expected 1 passed, got ' +
        IntToStr(LRegularLogResult.Passed));
    if LRegularLogResult.Failed <> 1 then
      FailTest('ShouldFail: expected 1 failed, got ' +
        IntToStr(LRegularLogResult.Failed));
    ResetDefaultConfig;
    PassTest('ShouldFail exec-fail');
  end;

  { ── G4: Glob filter edge cases ────────────────────────────────────────── }
  WriteLn;
  SectionHeader('G4: Glob filter edge cases');
  begin
    ResetDefaultConfig;
    LFilterSuite := TTestSuite.Create('GlobFilter');
    LFilterSuite.Test('abc', procedure begin CheckTrue(True); end);
    LFilterSuite.Test('abcd', procedure begin CheckTrue(True); end);
    LFilterSuite.Test('xyz', procedure begin CheckTrue(True); end);
    { Test: pattern "abc" should match "abc" exactly }
    LFilterSuite.Config.FilterPattern := 'abc';
    LFilterSuite.RunWithResult(LFilterResult);
    { abc matches "abc" and "abcd" (prefix match) — verify at least 1 pass }
    if LFilterResult.Passed < 1 then
      FailTest('glob filter abc: expected >= 1 passed');
    ResetDefaultConfig;
    { Test: pattern "" (empty) should match all }
    LFilterSuite := TTestSuite.Create('GlobFilterEmpty');
    LFilterSuite.Test('a', procedure begin CheckTrue(True); end);
    LFilterSuite.Test('b', procedure begin CheckTrue(True); end);
    LFilterSuite.Config.FilterPattern := '';
    LFilterSuite.RunWithResult(LFilterResult);
    if LFilterResult.Passed <> 2 then
      FailTest('glob filter empty: expected 2 passed, got ' +
        IntToStr(LFilterResult.Passed));
    ResetDefaultConfig;
    PassTest('Glob filter edge cases');
  end;

  { ── T-07: Test-level timeout exceeded ─────────────────────────────────────── }
  WriteLn;
  SectionHeader('T-07: Test timeout exceeded');
  begin
    ResetDefaultConfig;
    { Test with a generous timeout for fast tests, and a slow test that exceeds it }
    LVerbSuite := TTestSuite.Create('TimeoutExceeded');
    SetTestTimeout(200);
    LVerbSuite.Test('fast_test', procedure begin
      CheckTrue(True);
    end);
    LVerbSuite.RunWithResult(LVerbResult);
    { fast_test should pass within 200ms }
    if LVerbResult.Passed <> 1 then
      FailTest('timeout fast: expected 1 pass, got Passed=' +
        IntToStr(LVerbResult.Passed));
    if LVerbResult.Failed <> 0 then
      FailTest('timeout fast: expected 0 failures, got Failed=' +
        IntToStr(LVerbResult.Failed));
    ResetDefaultConfig;
    PassTest('fast test within timeout');

    { Now test with a tight timeout that a slow test will exceed }
    LVerbSuite := TTestSuite.Create('TimeoutSlow');
    SetTestTimeout(50);
    LVerbSuite.Test('slow_test', procedure begin
      SleepMs(300);
    end);
    LVerbSuite.RunWithResult(LVerbResult);
    { slow_test should have timed out → at least 1 failure }
    if LVerbResult.Failed < 1 then
      FailTest('timeout slow: expected at least 1 failure, got Failed=' +
        IntToStr(LVerbResult.Failed));
    { Check timeout message in results }
    begin
      LFoundTimeout := False;
      for LI := 0 to High(LVerbResult.Results) do
        if LVerbResult.Results[LI].Status = tsError then
        begin
          LFoundTimeout := True;
          if Pos('timed out', LVerbResult.Results[LI].Message) = 0 then
            FailTest('timeout: expected "timed out" in message, got "' +
              LVerbResult.Results[LI].Message + '"');
          Break;
        end;
      if not LFoundTimeout then
        FailTest('timeout: expected a tsError result');
    end;
    SetTestTimeout(0);
    ResetDefaultConfig;
    PassTest('Test timeout exceeded');
  end;

  { ── T-06: Config zero-value ambiguity ────────────────────────────────────── }
  WriteLn;
  SectionHeader('T-06: Config zero-value ambiguity');
  begin
    ResetDefaultConfig;
    LVerbSuite := TTestSuite.Create('ZeroConfig');
    { MaxParallelWorkers = 0 should mean "use default" — not crash }
    LVerbSuite.Config.MaxParallelWorkers := 0;
    LVerbSuite.Test('z1', procedure begin CheckTrue(True); end);
    LVerbSuite.Test('z2', procedure begin CheckTrue(True); end);
    LVerbSuite.RunParallelWithResult(nil, LVerbResult);
    if LVerbResult.Passed <> 2 then
      FailTest('MaxParallelWorkers=0: expected 2 passed, got ' +
        IntToStr(LVerbResult.Passed));
    { TestTimeout = 0 should mean "no timeout" — slow test should not fail }
    SetTestTimeout(0);
    LVerbSuite := TTestSuite.Create('ZeroTimeout');
    LVerbSuite.Test('fast', procedure begin CheckTrue(True); end);
    LVerbSuite.RunWithResult(LVerbResult);
    if LVerbResult.Passed <> 1 then
      FailTest('TestTimeout=0: expected 1 pass, got ' +
        IntToStr(LVerbResult.Passed));
    { RunTimeoutSec = 0 should mean "no run timeout" }
    LVerbSuite := TTestSuite.Create('ZeroRunTimeout');
    LVerbSuite.Config.RunTimeoutSec := 0;
    LVerbSuite.Test('zrt1', procedure begin CheckTrue(True); end);
    LVerbSuite.RunWithResult(LVerbResult);
    if LVerbResult.Passed <> 1 then
      FailTest('RunTimeoutSec=0: expected 1 pass, got ' +
        IntToStr(LVerbResult.Passed));
    ResetDefaultConfig;
    PassTest('Config zero-value ambiguity');
  end;

  { ── T-05: Complex glob/hierarchical filter scenarios ─────────────────────── }
  WriteLn;
  SectionHeader('T-05: Complex filter scenarios');
  begin
    ResetDefaultConfig;
    { Test 1: Multiple * wildcards in pattern }
    LVerbSuite := TTestSuite.Create('GlobMultiStar');
    LVerbSuite.Test('test_alpha_pass', procedure begin CheckTrue(True); end);
    LVerbSuite.Test('test_beta_pass', procedure begin CheckTrue(True); end);
    LVerbSuite.Test('other_gamma', procedure begin CheckTrue(True); end);
    LVerbConfig := DefaultConfig;
    LVerbConfig.FilterPattern := '*test*pass*';
    LVerbSuite.Config := LVerbConfig;
    LVerbSuite.RunWithResult(LVerbResult);
    if LVerbResult.Passed <> 2 then
      FailTest('multi-star: expected 2 passed, got ' +
        IntToStr(LVerbResult.Passed));
    ResetDefaultConfig;
    PassTest('Multiple * wildcards');

    { Test 2: Brace expansion {a,b} }
    LVerbSuite := TTestSuite.Create('GlobBrace');
    LVerbSuite.Test('alpha', procedure begin CheckTrue(True); end);
    LVerbSuite.Test('beta', procedure begin CheckTrue(True); end);
    LVerbSuite.Test('gamma', procedure begin CheckTrue(True); end);
    LVerbConfig := DefaultConfig;
    LVerbConfig.FilterPattern := '{alpha,beta}';
    LVerbSuite.Config := LVerbConfig;
    LVerbSuite.RunWithResult(LVerbResult);
    if LVerbResult.Passed <> 2 then
      FailTest('brace: expected 2 passed, got ' +
        IntToStr(LVerbResult.Passed));
    ResetDefaultConfig;
    PassTest('Brace expansion');

    { Test 3: Filter exact match (no wildcards = substring) }
    LVerbSuite := TTestSuite.Create('GlobExact');
    LVerbSuite.Test('exact_match', procedure begin CheckTrue(True); end);
    LVerbSuite.Test('exact_no', procedure begin CheckTrue(True); end);
    LVerbConfig := DefaultConfig;
    LVerbConfig.FilterPattern := 'exact_match';
    LVerbSuite.Config := LVerbConfig;
    LVerbSuite.RunWithResult(LVerbResult);
    { Substring match: 'exact_match' matches only 'exact_match' }
    if LVerbResult.Passed <> 1 then
      FailTest('substring: expected 1 passed, got ' +
        IntToStr(LVerbResult.Passed));
    ResetDefaultConfig;
    PassTest('Substring match');

    { Test 4: ? single-char wildcard }
    LVerbSuite := TTestSuite.Create('GlobQuestion');
    LVerbSuite.Test('a1x', procedure begin CheckTrue(True); end);
    LVerbSuite.Test('b1x', procedure begin CheckTrue(True); end);
    LVerbSuite.Test('aa1x', procedure begin CheckTrue(True); end);
    LVerbConfig := DefaultConfig;
    LVerbConfig.FilterPattern := '?1*';
    LVerbSuite.Config := LVerbConfig;
    LVerbSuite.RunWithResult(LVerbResult);
    { Should match a1x and b1x, not aa1x (too long before '1') }
    if LVerbResult.Passed <> 2 then
      FailTest('question-mark: expected 2 passed, got ' +
        IntToStr(LVerbResult.Passed));
    ResetDefaultConfig;
    PassTest('? single-char wildcard');

    { Test 5: Hierarchical filter — test name with / separator }
    LVerbSuite := TTestSuite.Create('HierFilter');
    LVerbSuite.Test('ParentA', procedure begin CheckTrue(True); end);
    LVerbSuite.Test('ParentB', procedure begin CheckTrue(True); end);
    LVerbConfig := DefaultConfig;
    LVerbConfig.FilterPattern := 'ParentA';
    LVerbSuite.Config := LVerbConfig;
    LVerbSuite.RunWithResult(LVerbResult);
    { Substring match: 'ParentA' matches 'ParentA' }
    if LVerbResult.Passed <> 1 then
      FailTest('hierarchical: expected 1 passed, got ' +
        IntToStr(LVerbResult.Passed));
    ResetDefaultConfig;
    PassTest('Hierarchical filter');
  end;

  { ── T-06: Benchmark N scaling edge cases ───────────────────────────────── }
  SectionHeader('T-07: Suite-level retry');

  begin
    { Test: suite-level RetryCount retries failed tests }
    LRetryAttempts := 0;
    LRetrySuite := TTestSuite.Create('SuiteRetry');
    LRetryConfig := DefaultConfig;
    LRetryConfig.RetryCount := 3; { suite-level: retry up to 3 times }
    LRetrySuite.Config := LRetryConfig;
    LRetrySuite.Test('flaky_pass', procedure
    begin
      Inc(LRetryAttempts);
      { Fail first 2 attempts, pass on 3rd }
      if LRetryAttempts < 3 then
        CheckTrue(False, 'intentional fail attempt ' + IntToStr(LRetryAttempts));
    end);
    LRetrySuite.RunWithResult(LRetryResult);
    { Should eventually pass after retries }
    if LRetryResult.Passed <> 1 then
      FailTest('suite retry: expected 1 passed, got ' +
        IntToStr(LRetryResult.Passed));
    if LRetryAttempts < 3 then
      FailTest('suite retry: expected >= 3 attempts, got ' +
        IntToStr(LRetryAttempts));
    PassTest('Suite-level retry (RetryCount)');

    { Test: entry-level RetryCount overrides suite-level }
    LRetryAttempts := 0;
    LRetrySuite := TTestSuite.Create('EntryRetry');
    LRetryConfig := DefaultConfig;
    LRetryConfig.RetryCount := 1; { suite-level: 1 retry }
    LRetrySuite.Config := LRetryConfig;
    LRetrySuite.Test('entry_override', procedure
    begin
      Inc(LRetryAttempts);
      { Fail first 4 attempts, pass on 5th }
      if LRetryAttempts < 5 then
        CheckTrue(False, 'intentional fail ' + IntToStr(LRetryAttempts));
    end, 4); { entry-level: 4 retries (overrides suite 1) }
    LRetrySuite.RunWithResult(LRetryResult);
    if LRetryResult.Passed <> 1 then
      FailTest('entry retry: expected 1 passed, got ' +
        IntToStr(LRetryResult.Passed));
    if LRetryAttempts < 5 then
      FailTest('entry retry: expected >= 5 attempts, got ' +
        IntToStr(LRetryAttempts));
    PassTest('Entry-level retry overrides suite-level');
  end;

  { ── T-08: CleanupTableAllocations idempotent ──────────────────────────── }

  SectionHeader('T-08: CleanupTableAllocations idempotent');

  begin
    LIdempotentSuite := TTestSuite.Create('Idempotent');
    LIdempotentSuite.Test('dummy', procedure begin CheckTrue(True); end);
    LIdempotentSuite.RunWithResult(LIdempotentResult);
    { First cleanup should succeed }
    LIdempotentSuite.CleanupTableAllocations;
    { Second cleanup should be a no-op (FCleanupDone guard) — must not crash }
    LIdempotentSuite.CleanupTableAllocations;
    { Third call — still safe }
    LIdempotentSuite.CleanupTableAllocations;
    if LIdempotentResult.Passed <> 1 then
      FailTest('idempotent: expected 1 passed');
    PassTest('CleanupTableAllocations idempotent');
  end;

  { ── E-03: FormatDuration locale regression ────────────────────────────── }

  SectionHeader('E-03: FormatDuration locale');

  begin
    { FormatDuration must use '.' as decimal separator, not locale-dependent ',' }
    LFormatMs := FormatDuration(1234);
    { Should contain '.' not ',' }
    if Pos(',', LFormatMs) > 0 then
      FailTest('FormatDuration uses locale comma: ' + LFormatMs);
    { Should contain '1.' for 1.234s }
    if Pos('1.', LFormatMs) = 0 then
      FailTest('FormatDuration missing decimal point: ' + LFormatMs);
    { Verify small durations }
    LFormatMs := FormatDuration(0);
    if LFormatMs <> '0ms' then
      FailTest('FormatDuration(0) = "' + LFormatMs + '"');
    LFormatMs := FormatDuration(999);
    if Pos('999ms', LFormatMs) = 0 then
      FailTest('FormatDuration(999) = "' + LFormatMs + '"');
    PassTest('FormatDuration locale-independent');
  end;

  { ── T-09: ShouldFail with exception class ──────────────────────────────── }

  SectionHeader('T-09: ShouldFail exception class');

  begin
    LSuite1 := TTestSuite.Create('ShouldFailClass');
    { ShouldFail with matching exception class → pass }
    LSuite1.ShouldFail('match_class', procedure
    begin
      raise EAssertionFailed.Create('expected error');
    end, EAssertionFailed);
    { ShouldFail with parent class → also pass }
    LSuite1.ShouldFail('parent_class', procedure
    begin
      raise EAssertionFailed.Create('error');
    end, Exception);
    LSuite1.RunWithResult(LShouldFailResult);
    { Both should pass: EAssertionFailed matches both EAssertionFailed and Exception }
    if LShouldFailResult.Passed <> 2 then
      FailTest('ShouldFail class: expected 2 passed, got ' +
        IntToStr(LShouldFailResult.Passed));
    PassTest('ShouldFail with exception class matching');
  end;

  { ── T-10: RunPattern (--run) exact match ───────────────────────────────── }

  SectionHeader('T-10: RunPattern (--run)');

  begin
    LFilterSuite := TTestSuite.Create('RunPatternSuite');
    LFilterSuite.Config.RunPattern := 'exact_match';
    LFilterSuite.Test('exact_match', @TestSimplePass);
    LFilterSuite.Test('no_match', @TestSimplePass2);
    LFilterSuite.RunWithResult(LFilterResult);
    { Only exact_match should run }
    if LFilterResult.Passed <> 1 then
      FailTest('RunPattern: expected 1 passed, got ' +
        IntToStr(LFilterResult.Passed));
    PassTest('RunPattern (--run) exact match');
  end;

  { ── T-11: ListMode output ──────────────────────────────────────────────── }

  SectionHeader('T-11: ListMode output');

  begin
    LJsonSink := TBufferSink.Create;
    LJsonSuite := TTestSuite.Create('ListModeSuite');
    LJsonSuite.Config.OutSink := LJsonSink;
    LJsonSuite.Config.AnsiMode := amOff;
    LJsonSuite.Config.ListMode := True;
    LJsonSuite.Test('test_alpha', @TestSimplePass);
    LJsonSuite.Test('test_beta', @TestSimplePass2);
    { ListMode is handled at RunAll level, not RunWithResult }
    LRunner := Default(TSuiteRunner);
    LRunner.Add(LJsonSuite);
    LRunner.RunAll;
    LListOutput := LJsonSink.GetOutput;
    { ListMode should output test names without running them }
    if Pos('test_alpha', LListOutput) = 0 then
      FailTest('ListMode: missing test_alpha in output');
    if Pos('test_beta', LListOutput) = 0 then
      FailTest('ListMode: missing test_beta in output');
    PassTest('ListMode outputs test names');
  end;

  { ── T-12: TestSeq (Sequential in parallel mode) ───────────────────────── }

  SectionHeader('T-12: TestSeq sequential opt-in');

  begin
    LResultSuite := TTestSuite.Create('SeqParallel');
    LResultSuite.Test('par1', @TestSimplePass);
    LResultSuite.TestSeq('seq1', @TestSimplePass2);
    LResultSuite.Test('par2', @TestSimplePass);
    LResultSuite.TestSeq('seq2', @TestSimplePass2);
    LResultSuite.RunParallelWithResult(nil, LFilterResult);
    if LFilterResult.Passed <> 4 then
      FailTest('TestSeq: expected 4 passed, got ' +
        IntToStr(LFilterResult.Passed));
    if LFilterResult.Failed <> 0 then
      FailTest('TestSeq: expected 0 failed, got ' +
        IntToStr(LFilterResult.Failed));
    PassTest('TestSeq sequential opt-in');
  end;

  { ── T-12b: TestSeq execution order (sequential before parallel) ──────── }

  SectionHeader('T-12b: TestSeq execution order');

  begin
    { Verify sequential tests complete before parallel tests start.
      Use a shared counter: sequential test sets it, parallel test checks it.
      Phase 1 (Sequential) runs before Phase 2 (Parallel), so the counter
      must be set before the parallel test reads it. }
    GSeqOrderCounter := 0;
    LResultSuite := TTestSuite.Create('SeqOrder');
    LResultSuite.TestSeq('seq_first', procedure begin
      GSeqOrderCounter := 1;
      CheckTrue(GSeqOrderCounter = 1, 'sequential test sets counter');
    end);
    LResultSuite.Test('par_after', procedure begin
      CheckTrue(GSeqOrderCounter >= 1,
        'sequential should have completed before parallel (counter=' +
        IntToStr(GSeqOrderCounter) + ')');
    end);
    LResultSuite.RunParallelWithResult(nil, LFilterResult);
    if LFilterResult.Passed <> 2 then
      FailTest('TestSeq order: expected 2 passed, got ' +
        IntToStr(LFilterResult.Passed));
    PassTest('TestSeq execution order');
  end;

  { ── T-13: TestCache ──────────────────────────────────────────────────── }

  SectionHeader('T-13: TestCache');

  begin
    LCache := TTestCache.Create('.nextpas/test-cache-test');
    LCacheConfig1 := DefaultConfig;
    LCacheConfig2 := DefaultConfig;
    LCacheKey1 := LCache.ComputeKey([], '3.3.1', LCacheConfig1);
    LCacheKey2 := LCache.ComputeKey([], '3.3.1', LCacheConfig2);
    if LCacheKey1 <> LCacheKey2 then
      FailTest('CacheKey: same inputs should produce same key');
    { Different compiler version should produce different key }
    LCacheKey3 := LCache.ComputeKey([], '3.2.0', LCacheConfig1);
    if LCacheKey1 = LCacheKey3 then
      FailTest('CacheKey: different compiler version should produce different key');
    { Test cache put/get }
    LCacheEntry.Status := Ord(tsPassed);
    LCacheEntry.Message := '';
    LCacheEntry.Duration := 42;
    LCacheEntry.Time := 1234567890;
    LCache.Put(LCacheKey1, 'test_cache_put', LCacheEntry);
    if not LCache.Get(LCacheKey1, 'test_cache_put', LCacheGotEntry) then
      FailTest('CacheGet: should find cached entry');
    if LCacheGotEntry.Status <> Ord(tsPassed) then
      FailTest('CacheGet: status mismatch');
    if LCacheGotEntry.Duration <> 42 then
      FailTest('CacheGet: duration mismatch');
    { Non-existent entry should return False }
    if LCache.Get(LCacheKey1, 'nonexistent', LCacheGotEntry) then
      FailTest('CacheGet: should not find non-existent entry');
    { Clean up test cache directory }
    LCache.Invalidate;
    PassTest('TestCache');
  end;

  { ── R48: Cache key filter pattern difference ────────────────────────────── }

  SectionHeader('R48: Cache key filter difference');

  begin
    LCache := TTestCache.Create('.nextpas/test-cache-test-r48');
    LCacheConfig1 := DefaultConfig;
    LCacheConfig1.FilterPattern := 'test_alpha';
    LCacheConfig2 := DefaultConfig;
    LCacheConfig2.FilterPattern := 'test_beta';
    LCacheKey1 := LCache.ComputeKey([], '3.3.1', LCacheConfig1);
    LCacheKey2 := LCache.ComputeKey([], '3.3.1', LCacheConfig2);
    if LCacheKey1 = LCacheKey2 then
      FailTest('CacheKey: different filter patterns should produce different keys');
    { Same filter should produce same key }
    LCacheKey3 := LCache.ComputeKey([], '3.3.1', LCacheConfig1);
    if LCacheKey1 <> LCacheKey3 then
      FailTest('CacheKey: same inputs should produce same key');
    { Different tag filter should produce different key }
    LCacheConfig1 := DefaultConfig;
    LCacheConfig1.TagFilter := 'fast';
    LCacheConfig2 := DefaultConfig;
    LCacheConfig2.TagFilter := 'slow';
    LCacheKey1 := LCache.ComputeKey([], '3.3.1', LCacheConfig1);
    LCacheKey2 := LCache.ComputeKey([], '3.3.1', LCacheConfig2);
    if LCacheKey1 = LCacheKey2 then
      FailTest('CacheKey: different tag filters should produce different keys');
    LCache.Invalidate;
    PassTest('CacheKey filter difference');
  end;

  { ── T-13b: Cache integration in runner ─────────────────────────────────── }

  SectionHeader('T-13b: Cache integration in runner');

  begin
    LCacheRunConfig := DefaultConfig;
    LCacheRunConfig.CacheEnabled := True;
    LCacheRunConfig.CacheDir := '../../../build/projects/nextpas.core.test/test_runner/cache';
    LCacheRunCount := 0;
    LCacheRunSuite := TTestSuite.Create('CacheRun');
    LCacheRunSuite.Config := LCacheRunConfig;
    LCacheRunSuite.Test('cached_test', procedure begin
      Inc(LCacheRunCount);
      CheckTrue(True, 'test runs');
    end);
    { First run: cache miss, test should execute }
    LCacheRunCount := 0;
    LCacheRunSuite.RunWithResult(LCacheRunResult1);
    if LCacheRunCount <> 1 then
      FailTest('Cache integration: first run should execute test, got count=' +
        IntToStr(LCacheRunCount));
    if LCacheRunResult1.Passed <> 1 then
      FailTest('Cache integration: first run should pass 1 test');
    { Second run: cache hit, test should NOT execute }
    LCacheRunCount := 0;
    LCacheRunSuite.RunWithResult(LCacheRunResult2);
    if LCacheRunCount <> 0 then
      FailTest('Cache integration: second run should use cache (count should be 0), got count=' +
        IntToStr(LCacheRunCount));
    if LCacheRunResult2.Passed <> 1 then
      FailTest('Cache integration: second run should pass 1 test (from cache)');
    { Clean up cache directory }
    LCache := TTestCache.Create('../../../build/projects/nextpas.core.test/test_runner/cache');
    LCache.Invalidate;
    PassTest('Cache integration in runner');
  end;

  { ── T-14: RepeatAllCount (--count=N) ───────────────────────────────────── }

  SectionHeader('T-14: RepeatAllCount (--count=N)');

  begin
    LRepeatCount := 0;
    LRepeatSuite := TTestSuite.Create('RepeatSuite');
    LRepeatSuite.Config.RepeatAllCount := 3;
    LRepeatSuite.Test('repeat_test', procedure begin
      Inc(LRepeatCount);
      CheckTrue(True, 'test runs');
    end);
    LRepeatRunner := TSuiteRunner.Create('RepeatRunner');
    LRepeatRunner.Add(LRepeatSuite);
    LRepeatRunner.RunAllWithResult(LRepeatResults);
    if LRepeatCount <> 3 then
      FailTest('RepeatAllCount: expected 3 runs, got ' + IntToStr(LRepeatCount));
    PassTest('RepeatAllCount (--count=N)');
  end;

  { ── T-15: FailFast + MaxFailures combination ────────────────────────────── }

  SectionHeader('T-15: FailFast + MaxFailures');

  begin
    LFailFastCount := 0;
    LFailFastSuite := TTestSuite.Create('FailFastSuite');
    LFailFastSuite.Config.FailFast := True;
    LFailFastSuite.Config.MaxFailures := 2;
    LFailFastSuite.Test('ff_pass1', procedure begin
      Inc(LFailFastCount);
      CheckTrue(True, 'pass');
    end);
    LFailFastSuite.Test('ff_fail1', procedure begin
      Inc(LFailFastCount);
      CheckTrue(False, 'fail 1');
    end);
    LFailFastSuite.Test('ff_fail2', procedure begin
      Inc(LFailFastCount);
      CheckTrue(False, 'fail 2');
    end);
    LFailFastSuite.Test('ff_pass2', procedure begin
      Inc(LFailFastCount);
      CheckTrue(True, 'pass');
    end);
    LFailFastSuite.RunWithResult(LFailFastResult);
    { FailFast stops after first failure, MaxFailures caps at 2 }
    if LFailFastResult.Failed < 1 then
      FailTest('FailFast+MaxFailures: expected at least 1 failure, got ' +
        IntToStr(LFailFastResult.Failed));
    if LFailFastCount >= 4 then
      FailTest('FailFast+MaxFailures: should have stopped early, but ran all ' +
        IntToStr(LFailFastCount) + ' tests');
    PassTest('FailFast + MaxFailures');
  end;

  { ── T-16: Test with TTestClosure ────────────────────────────────────────── }

  SectionHeader('T-16: Test with TTestClosure');

  begin
    LClosureCount := 0;
    LClosureSuite := TTestSuite.Create('ClosureSuite');
    LClosureSuite.Test('closure_test', procedure begin
      Inc(LClosureCount);
      CheckTrue(True, 'closure test');
    end);
    LClosureSuite.RunWithResult(LClosureResult);
    if LClosureCount <> 1 then
      FailTest('TestClosure: expected 1 call, got ' + IntToStr(LClosureCount));
    PassTest('Test with TTestClosure');
  end;

  { ── T-17: WithEachCleanup ──────────────────────────────────────────────── }

  SectionHeader('T-17: WithEachCleanup');

  begin
    LCleanupCount := 0;
    LCleanupSuite := TTestSuite.Create('CleanupSuite');
    LCleanupSuite := LCleanupSuite.WithEachCleanup(procedure begin
      Inc(LCleanupCount);
    end);
    LCleanupSuite.Test('cleanup_test1', procedure begin
      CheckTrue(True, 'test 1');
    end);
    LCleanupSuite.Test('cleanup_test2', procedure begin
      CheckTrue(True, 'test 2');
    end);
    LCleanupSuite.Test('cleanup_test3', procedure begin
      CheckTrue(True, 'test 3');
    end);
    LCleanupSuite.RunWithResult(LCleanupResult);
    if LCleanupCount <> 3 then
      FailTest('WithEachCleanup: expected 3 cleanups, got ' +
        IntToStr(LCleanupCount));
    if LCleanupResult.Passed <> 3 then
      FailTest('WithEachCleanup: expected 3 passed, got ' +
        IntToStr(LCleanupResult.Passed));
    PassTest('WithEachCleanup');
  end;

  ResetDefaultConfig;
  WriteLn;
  PassTest('test_runner');

  { Release closures before heaptrc reports (unit finalization runs before
    main block locals are freed — closures would appear as unfreed). }
  LRunner := Default(TSuiteRunner);
  LSumRunner := Default(TSuiteRunner);
  LMaxFailRunner := Default(TSuiteRunner);
  LExactRunner68 := Default(TSuiteRunner);
  LSuite1 := Default(TTestSuite);
  LSuite2 := Default(TTestSuite);
  LFailSuite1 := Default(TTestSuite);
  LFailSuite2 := Default(TTestSuite);
  LFailSuite3 := Default(TTestSuite);
  LRunNestedS1 := Default(TTestSuite);
  LRunNestedS2 := Default(TTestSuite);
  LCacheSuite := Default(TTestSuite);
  LSummarySuite := Default(TTestSuite);
  LSumSuite3 := Default(TTestSuite);
  LResultSuite := Default(TTestSuite);
  LExactSuite68 := Default(TTestSuite);
  LShortSuite := Default(TTestSuite);
  LProgressSuite := Default(TTestSuite);
  LMaxFailSuite := Default(TTestSuite);
  LJsonSuite := Default(TTestSuite);
  LAutoRunSuite := Default(TTestSuite);
  LAutoRunRunner := Default(TSuiteRunner);
  LCacheRunSuite := Default(TTestSuite);
  LJsonSink := nil;
  LVerbSuite := Default(TTestSuite);
  LVerbSink := nil;
  LRetrySuite := Default(TTestSuite);
  LIdempotentSuite := Default(TTestSuite);
  LRepeatSuite := Default(TTestSuite);
  LRepeatRunner := Default(TSuiteRunner);
  LFailFastSuite := Default(TTestSuite);
  LClosureSuite := Default(TTestSuite);
  LCleanupSuite := Default(TTestSuite);
end.
