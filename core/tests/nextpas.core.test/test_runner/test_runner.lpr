{ test_runner — Validates TTestRunner multi-suite + subtests + lifecycle }
program test_runner;

{$mode objfpc}{$H+}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

uses
  SysUtils,
  nextpas.core.test;

var
  GSetupCalled: Integer = 0;
  GTeardownCalled: Integer = 0;
  GBeforeEachCalled: Integer = 0;
  GAfterEachCalled: Integer = 0;

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

procedure TestSubtestsWithFailure(constref Ctx: ITestContext);
begin
  Ctx.Run('pass',
    procedure
    begin
      Check(True);
    end);

  Ctx.Run('expected fail',
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
  LSuite2.TestSubtest('subtests with failure',  @TestSubtestsWithFailure);
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

  if GSetupCalled < 1 then
  begin
    WriteLn(AnsiRed('FAIL: Setup not called enough'));
    Halt(1);
  end;
  if GTeardownCalled < 1 then
  begin
    WriteLn(AnsiRed('FAIL: Teardown not called enough'));
    Halt(1);
  end;
  if GBeforeEachCalled < 4 then
  begin
    WriteLn(AnsiRed('FAIL: BeforeEach not called for each test'));
    Halt(1);
  end;
  if GAfterEachCalled < 4 then
  begin
    WriteLn(AnsiRed('FAIL: AfterEach not called for each test'));
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
  if LFailSuite1.FLastPass <> 0 then
  begin
    WriteLn(AnsiRed('FAIL: No tests should pass after setup failure'));
    Halt(1);
  end;
  if not LFailSuite1.FHasRun then
  begin
    WriteLn(AnsiRed('FAIL: FHasRun should be True after Run'));
    Halt(1);
  end;
  if LFailSuite1.FLastFail < 1 then
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
  if LFailSuite2.FLastFail < 1 then
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

  WriteLn;
  WriteLn(AnsiGreen('ALL PASSED'));
end.
