{ test_runner — Validates TTestRunner multi-suite + subtests + lifecycle }
program test_runner;

{$mode objfpc}{$H+}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

uses
  cthreads,
  SysUtils,
  nextpas.core.test,
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
          Check(Pos('sub-assertion', E.Message) > 0);
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

{ ── R2-F12: BeforeEach Skip test ───────────────────────────────────────────── }

procedure TestBeforeEachSkip;
var
  LSuite: TTestSuite;
  LResult: TTestRunResult;
begin
  LSuite := TTestSuite.Create('BeforeEachSkip');
  LSuite.OnBeforeEach(procedure begin Skip('skip from beforeEach'); end);
  LSuite.Test('t1', @TestSimplePass);
  LSuite.Test('t2', @TestSimplePass2);
  { Both tests should be skipped, not errored }
  LSuite.RunWithResult(LResult);
  if LResult.Skipped <> 2 then
  begin
    WriteLn(AnsiRed('FAIL: expected 2 skipped, got '), LResult.Skipped);
    Halt(1);
  end;
  if LResult.Failed <> 0 then
  begin
    WriteLn(AnsiRed('FAIL: expected 0 failed, got '), LResult.Failed);
    Halt(1);
  end;
  WriteLn(AnsiGreen('  ✓ BeforeEach Skip'));
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
  LResult: TTestRunResult;
  LRunAllResults: specialize TArray<TTestRunResult>;
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
  WriteLn(AnsiBold('─── Lifecycle Counters ───'));
  WriteLn('  Setup called:     ', GSetupCalled);
  WriteLn('  Teardown called:  ', GTeardownCalled);
  WriteLn('  BeforeEach called:', GBeforeEachCalled);
  WriteLn('  AfterEach called: ', GAfterEachCalled);

  if GSetupCalled <> 1 then
  begin
    WriteLn(AnsiRed('FAIL: Setup not called exactly once, got ' + IntToStr(GSetupCalled)));
    Halt(1);
  end;
  if GTeardownCalled <> 1 then
  begin
    WriteLn(AnsiRed('FAIL: Teardown not called exactly once, got ' + IntToStr(GTeardownCalled)));
    Halt(1);
  end;
  if GBeforeEachCalled <> 4 then
  begin
    WriteLn(AnsiRed('FAIL: BeforeEach not called exactly 4 times, got ' + IntToStr(GBeforeEachCalled)));
    Halt(1);
  end;
  if GAfterEachCalled <> 4 then
  begin
    WriteLn(AnsiRed('FAIL: AfterEach not called exactly 4 times, got ' + IntToStr(GAfterEachCalled)));
    Halt(1);
  end;

  if not LPass then
  begin
    WriteLn;
    WriteLn(AnsiRed('SOME TESTS FAILED'));
    Halt(1);
  end;

  { ── B5.3: Lifecycle failure path tests ───────────────────────────────── }

  { Test: Setup failure → Run returns False, all tests skipped }
  WriteLn;
  WriteLn(AnsiBold('─── B5.3: Lifecycle Failure Tests ───'));
  LFailSuite1 := TTestSuite.Create('Setup Failure');
  LFailSuite1.SetSetup(procedure begin
    raise EConvertError.Create('setup boom');
  end);
  LFailSuite1.Test('test after bad setup', procedure begin
    Halt(1); { should never run }
  end);
  if LFailSuite1.Run then
  begin
    WriteLn(AnsiRed('FAIL: Setup failure should cause Run=False'));
    Halt(1);
  end;
  if LFailSuite1.LastPass <> 0 then
  begin
    WriteLn(AnsiRed('FAIL: No tests should pass after setup failure'));
    Halt(1);
  end;
  if not LFailSuite1.HasRun then
  begin
    WriteLn(AnsiRed('FAIL: HasRun should be True after Run'));
    Halt(1);
  end;
  if LFailSuite1.LastFail < 1 then
  begin
    WriteLn(AnsiRed('FAIL: Setup failure should count as failure'));
    Halt(1);
  end;
  WriteLn(AnsiGreen('  ✓ Setup failure path'));

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
    WriteLn(AnsiRed('FAIL: BeforeEach failure should cause Run=False'));
    Halt(1);
  end;
  if LFailSuite2.LastFail < 1 then
  begin
    WriteLn(AnsiRed('FAIL: At least 1 failure expected'));
    Halt(1);
  end;
  WriteLn(AnsiGreen('  ✓ BeforeEach failure path'));

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
    WriteLn(AnsiRed('FAIL: Teardown failure should not fail tests'));
    Halt(1);
  end;
  WriteLn(AnsiGreen('  ✓ Teardown failure path'));

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
    WriteLn(AnsiRed('FAIL: RunAll aggregation should pass'));
    Halt(1);
  end;
  if LRunNestedR.TotalPass <> 2 then
  begin
    WriteLn(AnsiRed('FAIL: Expected 2 passes, got '), LRunNestedR.TotalPass);
    Halt(1);
  end;
  WriteLn(AnsiGreen('  ✓ RunAll aggregation'));

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
    WriteLn(AnsiRed('FAIL: Expected 1 run, got '), LRunCount);
    Halt(1);
  end;
  LCacheSuite.AllPassed; { should NOT re-run }
  if LRunCount <> 1 then
  begin
    WriteLn(AnsiRed('FAIL: AllPassed should not re-run (count='), LRunCount, ')');
    Halt(1);
  end;
  WriteLn(AnsiGreen('  ✓ AllPassed caching'));

  { Test: Summary smoke }
  LSummarySuite := TTestSuite.Create('Summary Smoke');
  LSummarySuite.Test('pass', procedure begin CheckTrue(True); end);
  LSummarySuite.Run;
  LSummarySuite.Summary; { should not raise }
  WriteLn(AnsiGreen('  ✓ Summary smoke'));

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
    WriteLn(AnsiRed('FAIL: Expected 1 pass, got '), LSumRunner.TotalPass);
    Halt(1);
  end;
  if LSumRunner.TotalSkip <> 1 then
  begin
    WriteLn(AnsiRed('FAIL: Expected 1 skip, got '), LSumRunner.TotalSkip);
    Halt(1);
  end;
  WriteLn(AnsiGreen('  ✓ Runner Summary'));

  { Test: RunWithResult }
  LResultSuite := TTestSuite.Create('Result Test');
  LResultSuite.Test('will pass', procedure begin CheckTrue(True); end);
  LResultSuite.Skip('will skip', 'reason');
  LResultSuite.Test('will pass 2', procedure begin CheckTrue(True); end);
  if not LResultSuite.RunWithResult(LResult) then
  begin
    WriteLn(AnsiRed('FAIL: RunWithResult should return True'));
    Halt(1);
  end;
  if LResult.SuiteName <> 'Result Test' then
  begin
    WriteLn(AnsiRed('FAIL: SuiteName mismatch'));
    Halt(1);
  end;
  if Length(LResult.Results) <> 3 then
  begin
    WriteLn(AnsiRed('FAIL: Expected 3 results, got '), Length(LResult.Results));
    Halt(1);
  end;
  if LResult.Passed <> 2 then
  begin
    WriteLn(AnsiRed('FAIL: Expected 2 passed, got '), LResult.Passed);
    Halt(1);
  end;
  if LResult.Skipped <> 1 then
  begin
    WriteLn(AnsiRed('FAIL: Expected 1 skipped, got '), LResult.Skipped);
    Halt(1);
  end;
  if LResult.Failed <> 0 then
  begin
    WriteLn(AnsiRed('FAIL: Expected 0 failed, got '), LResult.Failed);
    Halt(1);
  end;
  if not LResult.AllPassed then
  begin
    WriteLn(AnsiRed('FAIL: AllPassed should be True'));
    Halt(1);
  end;
  if LResult.Results[0].Status <> tsPassed then
  begin
    WriteLn(AnsiRed('FAIL: Result[0] should be tsPassed'));
    Halt(1);
  end;
  if LResult.Results[1].Status <> tsSkipped then
  begin
    WriteLn(AnsiRed('FAIL: Result[1] should be tsSkipped'));
    Halt(1);
  end;
  if LResult.Results[1].Message <> 'reason' then
  begin
    WriteLn(AnsiRed('FAIL: Result[1] message should be "reason"'));
    Halt(1);
  end;
  if LResult.Results[2].Status <> tsPassed then
  begin
    WriteLn(AnsiRed('FAIL: Result[2] should be tsPassed'));
    Halt(1);
  end;
  WriteLn(AnsiGreen('  ✓ RunWithResult'));

  { ── m15: Summary smoke test ───────────────────────────────────────────────── }
  WriteLn;
  WriteLn(AnsiBold('─── m15: Summary Smoke Test ───'));
  LResultSuite := TTestSuite.Create('Summary Smoke');
  LResultSuite.Test('pass', @TestSimplePass);
  LResultSuite.Skip('skip', 'planned');
  LResultSuite.Run;
  LResultSuite.Summary;  { Should not crash }
  WriteLn(AnsiGreen('  ✓ Summary'));

  { ── M20: AllPassed caching ────────────────────────────────────────────────── }
  WriteLn;
  WriteLn(AnsiBold('─── M20: AllPassed Caching ───'));
  LResultSuite := TTestSuite.Create('Cache Test');
  LResultSuite.Test('pass1', @TestSimplePass);
  LResultSuite.Test('pass2', @TestSimplePass2);
  { First call triggers Run }
  if not LResultSuite.AllPassed then
  begin
    WriteLn(AnsiRed('FAIL: AllPassed should be True on first call'));
    Halt(1);
  end;
  { Second call should use cached result }
  if not LResultSuite.AllPassed then
  begin
    WriteLn(AnsiRed('FAIL: AllPassed should be True on second call'));
    Halt(1);
  end;
  WriteLn(AnsiGreen('  ✓ AllPassed caching'));

  { ── R2-F12: BeforeEach Skip ────────────────────────────────────────────────── }
  WriteLn;
  WriteLn(AnsiBold('─── R2-F12: BeforeEach Skip ───'));
  TestBeforeEachSkip;

  { ── R2-F03: Subtest-level results ────────────────────────────────────────── }
  WriteLn;
  WriteLn(AnsiBold('─── R2-F03: Subtest Results ───'));
  begin
    LResultSuite := TTestSuite.Create('Subtest Results');
    LResultSuite.TestSubtest('subtests', @TestSubtests);
    LResultSuite.Test('plain pass', @TestSimplePass);
    LResultSuite.RunWithResult(LResult);
    { TestSubtests registers 3 subtests + 1 plain = 5 results total
      (3 sub + 1 subtest parent entry + 1 plain) }
    if Length(LResult.Results) <> 5 then
    begin
      WriteLn(AnsiRed('FAIL: Expected 5 results (3 sub + 1 parent + 1 plain), got '),
        Length(LResult.Results));
      Halt(1);
    end;
    { Check subtest results are individually tracked
      Order: [0]=subtests(parent), [1]=plain pass, [2..4]=sub results }
    if LResult.Results[0].Name <> 'subtests' then
    begin
      WriteLn(AnsiRed('FAIL: Result[0] name should be "subtests", got '),
        LResult.Results[0].Name);
      Halt(1);
    end;
    if LResult.Results[2].Status <> tsPassed then
    begin
      WriteLn(AnsiRed('FAIL: Subtest result[2] should be tsPassed, got '),
        Ord(LResult.Results[2].Status));
      Halt(1);
    end;
    if Pos('subtests/', LResult.Results[2].Name) = 0 then
    begin
      WriteLn(AnsiRed('FAIL: Subtest result name should contain "subtests/", got '),
        LResult.Results[2].Name);
      Halt(1);
    end;
    WriteLn(AnsiGreen('  ✓ Subtest results collected'));
  end;

  { ── R2-F02: RunParallelWithResult ────────────────────────────────────────── }
  WriteLn;
  WriteLn(AnsiBold('─── R2-F02: RunParallelWithResult ───'));
  begin
    LResultSuite := TTestSuite.Create('Parallel Result');
    LResultSuite.Test('p1', @TestSimplePass);
    LResultSuite.Test('p2', @TestSimplePass2);
    LResultSuite.Skip('sk1', 'reason');
    LResultSuite.RunParallelWithResult(nil, LResult);
    if Length(LResult.Results) <> 3 then
    begin
      WriteLn(AnsiRed('FAIL: Expected 3 results, got '), Length(LResult.Results));
      Halt(1);
    end;
    if LResult.Passed <> 2 then
    begin
      WriteLn(AnsiRed('FAIL: Expected 2 passed, got '), LResult.Passed);
      Halt(1);
    end;
    if LResult.Skipped <> 1 then
    begin
      WriteLn(AnsiRed('FAIL: Expected 1 skipped, got '), LResult.Skipped);
      Halt(1);
    end;
    if not LResult.AllPassed then
    begin
      WriteLn(AnsiRed('FAIL: AllPassed should be True'));
      Halt(1);
    end;
    WriteLn(AnsiGreen('  ✓ RunParallelWithResult'));
  end;

  { ── R2-F02: RunAllWithResult ─────────────────────────────────────────────── }
  WriteLn;
  WriteLn(AnsiBold('─── R2-F02: RunAllWithResult ───'));
  begin
    LRunNestedS1 := TTestSuite.Create('SuiteX');
    LRunNestedS1.Test('x1', procedure begin CheckTrue(True); end);
    LRunNestedS1.Skip('x2', 'planned');
    LRunNestedS2 := TTestSuite.Create('SuiteY');
    LRunNestedS2.Test('y1', procedure begin CheckTrue(True); end);
    LRunNestedR := TTestRunner.Create('WithResult Runner');
    LRunNestedR.Add(LRunNestedS1);
    LRunNestedR.Add(LRunNestedS2);
    if not LRunNestedR.RunAllWithResult(LRunAllResults) then
    begin
      WriteLn(AnsiRed('FAIL: RunAllWithResult should return True'));
      Halt(1);
    end;
    if Length(LRunAllResults) <> 2 then
    begin
      WriteLn(AnsiRed('FAIL: Expected 2 suite results, got '), Length(LRunAllResults));
      Halt(1);
    end;
    if LRunAllResults[0].SuiteName <> 'SuiteX' then
    begin
      WriteLn(AnsiRed('FAIL: First suite name should be SuiteX'));
      Halt(1);
    end;
    if LRunAllResults[1].Passed <> 1 then
    begin
      WriteLn(AnsiRed('FAIL: SuiteY should have 1 pass, got '), LRunAllResults[1].Passed);
      Halt(1);
    end;
    WriteLn(AnsiGreen('  ✓ RunAllWithResult'));
  end;

  { ── R3-F17: Timeout trigger (watchdog actually fires) ───────────────────── }
  WriteLn;
  WriteLn(AnsiBold('─── R3-F17: Timeout Trigger ───'));
  begin
    LResultSuite := TTestSuite.Create('Timeout Trigger');
    LResultSuite.Test('slow', procedure begin Sleep(500); end);
    SetTestTimeout(10); { 10ms — much less than the 500ms Sleep }
    LResultSuite.RunWithResult(LResult);
    SetTestTimeout(0);
    if LResult.AllPassed then
    begin
      WriteLn(AnsiRed('FAIL: timed-out test should not be AllPassed'));
      Halt(1);
    end;
    if Length(LResult.Results) <> 1 then
    begin
      WriteLn(AnsiRed('FAIL: Expected 1 result, got '), Length(LResult.Results));
      Halt(1);
    end;
    if LResult.Results[0].Status <> tsError then
    begin
      WriteLn(AnsiRed('FAIL: Expected tsError status, got '), Ord(LResult.Results[0].Status));
      Halt(1);
    end;
    WriteLn(AnsiGreen('  ✓ Timeout trigger verified'));
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
      WriteLn(AnsiRed('FAIL: filter match should pass'));
      Halt(1);
    end;
    if LFilterResult.Passed <> 1 then
    begin
      WriteLn(AnsiRed('FAIL: filter match expected 1 passed, got '), LFilterResult.Passed);
      Halt(1);
    end;
    if LFilterResult.Skipped <> 0 then
    begin
      WriteLn(AnsiRed('FAIL: filter match expected 0 skipped (filtered=invisible), got '), LFilterResult.Skipped);
      Halt(1);
    end;
    SetTestFilter('');
    WriteLn(AnsiGreen('  ✓ Filter matches specific test'));
  end;

  begin
    { Test 2: filter matches nothing — all tests invisible, 0/0/0 }
    LFilterSuite := TTestSuite.Create('FilterNone');
    LFilterSuite.Test('aaa', @TestSimplePass);
    LFilterSuite.Test('bbb', @TestSimplePass);
    SetTestFilter('zzz_nonexistent');
    if not LFilterSuite.RunWithResult(LFilterResult) then
    begin
      WriteLn(AnsiRed('FAIL: filter no-match should still return True'));
      Halt(1);
    end;
    if LFilterResult.Passed <> 0 then
    begin
      WriteLn(AnsiRed('FAIL: filter no-match expected 0 passed, got '), LFilterResult.Passed);
      Halt(1);
    end;
    if LFilterResult.Skipped <> 0 then
    begin
      WriteLn(AnsiRed('FAIL: filter no-match expected 0 skipped, got '), LFilterResult.Skipped);
      Halt(1);
    end;
    SetTestFilter('');
    WriteLn(AnsiGreen('  ✓ Filter matches nothing → all invisible'));
  end;

  begin
    { Test 3: empty filter runs everything (no filtering) }
    LFilterSuite := TTestSuite.Create('FilterEmpty');
    LFilterSuite.Test('aaa', @TestSimplePass);
    LFilterSuite.Test('bbb', @TestSimplePass);
    SetTestFilter('');
    if not LFilterSuite.RunWithResult(LFilterResult) then
    begin
      WriteLn(AnsiRed('FAIL: empty filter should pass'));
      Halt(1);
    end;
    if LFilterResult.Passed <> 2 then
    begin
      WriteLn(AnsiRed('FAIL: empty filter expected 2 passed, got '), LFilterResult.Passed);
      Halt(1);
    end;
    if LFilterResult.Skipped <> 0 then
    begin
      WriteLn(AnsiRed('FAIL: empty filter expected 0 skipped, got '), LFilterResult.Skipped);
      Halt(1);
    end;
    WriteLn(AnsiGreen('  ✓ Empty filter runs everything'));
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
      WriteLn(AnsiRed('FAIL: glob filter should pass'));
      Halt(1);
    end;
    if LFilterResult.Passed <> 1 then
    begin
      WriteLn(AnsiRed('FAIL: glob b* expected 1 passed, got '), LFilterResult.Passed);
      Halt(1);
    end;
    if LFilterResult.Skipped <> 0 then
    begin
      WriteLn(AnsiRed('FAIL: glob b* expected 0 skipped, got '), LFilterResult.Skipped);
      Halt(1);
    end;
    SetTestFilter('');
    WriteLn(AnsiGreen('  ✓ Glob filter (b* matches beta)'));
  end;

  { ── R4-08: Empty suite run ───────────────────────────────────────────────── }
  begin
    LEmptySuite := TTestSuite.Create('Empty');
    if not LEmptySuite.RunWithResult(LEmptyResult) then
    begin
      WriteLn(AnsiRed('FAIL: Empty suite should return True (AllPassed)'));
      Halt(1);
    end;
    if not LEmptyResult.AllPassed then
    begin
      WriteLn(AnsiRed('FAIL: Empty suite AllPassed should be True'));
      Halt(1);
    end;
    if LEmptyResult.Passed <> 0 then
    begin
      WriteLn(AnsiRed('FAIL: Empty suite Passed should be 0'));
      Halt(1);
    end;
    if LEmptyResult.Skipped <> 0 then
    begin
      WriteLn(AnsiRed('FAIL: Empty suite Skipped should be 0'));
      Halt(1);
    end;
    WriteLn(AnsiGreen('  ✓ Empty suite run'));
  end;

  { ── R6-58: ParseFilter helper (white-box) ─────────────────────────────────── }
  WriteLn;
  WriteLn(AnsiBold('─── R6-58: ParseFilter helper ───'));
  begin
    { 白盒测试：直接验证 runner 内部命令行解析 helper。 }
    if nextpas.core.test.runner.ParseFilter('--filter=alpha') <> 'alpha' then
    begin
      WriteLn(AnsiRed('FAIL: ParseFilter should extract alpha'));
      Halt(1);
    end;
    if nextpas.core.test.runner.ParseFilter('--other=beta') <> '' then
    begin
      WriteLn(AnsiRed('FAIL: ParseFilter should ignore unrelated args'));
      Halt(1);
    end;
    if nextpas.core.test.runner.ParseFilter('--filter=foo=bar') <> 'foo=bar' then
    begin
      WriteLn(AnsiRed('FAIL: ParseFilter should preserve embedded equals'));
      Halt(1);
    end;
    WriteLn(AnsiGreen('  ✓ ParseFilter helper'));
  end;

  { ── R6-59: AddLine / JoinLines helpers ────────────────────────────────────── }
  WriteLn;
  WriteLn(AnsiBold('─── R6-59: AddLine / JoinLines ───'));
  begin
    SetLength(LLines59, 0);
    AddLine(LLines59, 'first');
    AddLine(LLines59, 'second');
    AddLine(LLines59, 'third');
    if Length(LLines59) <> 3 then
    begin
      WriteLn(AnsiRed('FAIL: expected 3 lines after AddLine, got '), Length(LLines59));
      Halt(1);
    end;
    if LLines59[0] <> 'first' then
    begin
      WriteLn(AnsiRed('FAIL: expected "first", got "'), LLines59[0], '"');
      Halt(1);
    end;
    if LLines59[2] <> 'third' then
    begin
      WriteLn(AnsiRed('FAIL: expected "third", got "'), LLines59[2], '"');
      Halt(1);
    end;

    LJoined59 := JoinLines(LLines59);
    if Pos('first', LJoined59) = 0 then
    begin
      WriteLn(AnsiRed('FAIL: JoinLines should contain "first"'));
      Halt(1);
    end;
    if Pos('second', LJoined59) = 0 then
    begin
      WriteLn(AnsiRed('FAIL: JoinLines should contain "second"'));
      Halt(1);
    end;
    if Pos('third', LJoined59) = 0 then
    begin
      WriteLn(AnsiRed('FAIL: JoinLines should contain "third"'));
      Halt(1);
    end;
    WriteLn(AnsiGreen('  ✓ AddLine / JoinLines'));
  end;

  { ── R6-59: JoinLines empty ────────────────────────────────────────────────── }
  begin
    SetLength(LEmpty59, 0);
    if JoinLines(LEmpty59) <> '' then
    begin
      WriteLn(AnsiRed('FAIL: JoinLines on empty array should return empty string'));
      Halt(1);
    end;
    WriteLn(AnsiGreen('  ✓ JoinLines empty'));
  end;

  { ── R6-60: TTestRunResult default values ─────────────────────────────────── }
  WriteLn;
  WriteLn(AnsiBold('─── R6-60: TTestRunResult defaults ───'));
  begin
    LDefaults60 := TTestRunResult.Create('my_suite');
    if LDefaults60.SuiteName <> 'my_suite' then
    begin
      WriteLn(AnsiRed('FAIL: SuiteName should be my_suite'));
      Halt(1);
    end;
    if LDefaults60.Passed <> 0 then
    begin
      WriteLn(AnsiRed('FAIL: Passed should be 0, got '), LDefaults60.Passed);
      Halt(1);
    end;
    if LDefaults60.Failed <> 0 then
    begin
      WriteLn(AnsiRed('FAIL: Failed should be 0, got '), LDefaults60.Failed);
      Halt(1);
    end;
    if LDefaults60.Skipped <> 0 then
    begin
      WriteLn(AnsiRed('FAIL: Skipped should be 0, got '), LDefaults60.Skipped);
      Halt(1);
    end;
    if not LDefaults60.AllPassed then
    begin
      WriteLn(AnsiRed('FAIL: AllPassed should be True for fresh TTestRunResult'));
      Halt(1);
    end;
    if Length(LDefaults60.Results) <> 0 then
    begin
      WriteLn(AnsiRed('FAIL: Results should be empty'));
      Halt(1);
    end;
    WriteLn(AnsiGreen('  ✓ TTestRunResult defaults'));
  end;

  { ── R6-68: Strong assertions replacing Count > 0 ─────────────────────────── }
  { The existing lifecycle counter tests already use exact equality (GSetupCalled <> 1).
    This test confirms TotalPass/TotalFail exactness after a known run. }
  WriteLn;
  WriteLn(AnsiBold('─── R6-68: Strong exact-value assertions ───'));
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
      WriteLn(AnsiRed('FAIL: expected exactly 2 passes, got '), LExactRunner68.TotalPass);
      Halt(1);
    end;
    if LExactRunner68.TotalFail <> 0 then
    begin
      WriteLn(AnsiRed('FAIL: expected exactly 0 failures, got '), LExactRunner68.TotalFail);
      Halt(1);
    end;
    if LExactRunner68.TotalSkip <> 1 then
    begin
      WriteLn(AnsiRed('FAIL: expected exactly 1 skip, got '), LExactRunner68.TotalSkip);
      Halt(1);
    end;
    WriteLn(AnsiGreen('  ✓ Exact-value assertions'));
  end;

  WriteLn;
  WriteLn(AnsiGreen('ALL PASSED'));
end.
