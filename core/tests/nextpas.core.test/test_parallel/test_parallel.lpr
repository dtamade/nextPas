{ test_parallel — Validates parallel test execution }
program test_parallel;

{$mode objfpc}{$H+}{$J-}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

uses
  nextpas.core.thread.init,
  nextpas.core.text.conv,
  nextpas.core.test;

var
  GTestCounter: Integer = 0;
  GParallelRetryCount: Integer = 0;
  GConcurrentCount: Integer = 0;
  GMaxConcurrent: Integer = 0;
  { v3.12: ShouldFail in parallel }
  GShouldFailSuite: TTestSuite;
  GShouldFailResult: TTestRunResult;
  { Phase 9: ShortSkip in parallel }
  GShortSkipSuite: TTestSuite;
  GShortSkipResult: TTestRunResult;
  { Phase 10: Verbose in parallel }
  GVerbSuite: TTestSuite;
  GVerbResult: TTestRunResult;
  { Phase 10: Cleanup in parallel }
  GCleanupCounter: Integer = 0;

procedure TestParallelSimple;
begin
  Check(True, 'simple parallel pass');
  InterLockedIncrement(GTestCounter);
end;

{ ── B5.10: Additional parallel tests ─────────────────────────────────────── }

procedure TestParallelFail;
begin
  Check(False, 'intentional parallel failure');
end;

procedure TestParallelSkip;
begin
  Skip('intentionally skipped in parallel');
end;

procedure TestParallelPassA;
begin
  Check(True);
end;

procedure TestParallelPassB;
begin
  Check(True);
end;

{ ── F09: Parallel lifecycle failure tests ─────────────────────────────────── }

procedure TestParallelBeforeEachFail;
var
  LSuite: TTestSuite;
begin
  LSuite := TTestSuite.Create('ParBeforeEachFail');
  LSuite.OnBeforeEach(procedure begin raise Exception.Create('beforeEach boom'); end);
  LSuite.Test('t1', @TestParallelPassA);
  LSuite.Test('t2', @TestParallelPassB);
  { RunParallel should handle beforeEach failure gracefully }
  LSuite.RunParallel(nil);
  if LSuite.LastFail < 1 then
  begin
    FailTest('expected at least 1 failure from beforeEach');
  end;
  PassTest('✓ Parallel beforeEach failure');
end;

procedure TestParallelSetupFail;
var
  LSuite: TTestSuite;
begin
  LSuite := TTestSuite.Create('ParSetupFail');
  LSuite.SetSetup(procedure begin raise Exception.Create('setup boom'); end);
  LSuite.Test('t1', @TestParallelPassA);
  LSuite.Test('t2', @TestParallelPassB);
  { Setup failure should skip all tests }
  LSuite.RunParallel(nil);
  if LSuite.LastSkip < 2 then
  begin
    FailTest('expected 2 skips from setup failure, got ' + IntToStr(LSuite.LastSkip));
  end;
  if LSuite.LastFail <> 1 then
  begin
    FailTest('expected LastFail=1 for setup failure, got ' + IntToStr(LSuite.LastFail));
  end;
  PassTest('✓ Parallel setup failure');
end;

{ ── R2-F22: Timeout + Retry + Skip in Parallel ──────────────────────────── }

procedure ParallelFlakyThenPass;
begin
  { R4-05: Use InterLockedIncrement return value (atomic read) instead of
    non-atomic re-read of GParallelRetryCount — safe on ARM weak memory. }
  if InterLockedIncrement(GParallelRetryCount) < 3 then
    CheckTrue(False, 'intentional flaky');
end;

procedure TestParallelTimeout;
var
  LSuite: TTestSuite;
begin
  LSuite := TTestSuite.Create('ParTimeout');
  { Set a very short timeout }
  SetTestTimeout(100);
  LSuite.Test('fast_pass', @TestParallelPassA);
  { A slow test that should timeout — but since we can't easily add
    a sleep-based slow test in CI, we test with fast tests + short timeout.
    The timeout mechanism should not interfere with fast tests. }
  LSuite.RunParallel(nil);
  SetTestTimeout(0); { reset }
  if LSuite.LastPass < 1 then
  begin
    FailTest('fast test should pass even with short timeout');
  end;
  PassTest('✓ Parallel timeout (fast tests pass)');
end;

procedure TestRetryInParallel;
var
  LSuite: TTestSuite;
begin
  GParallelRetryCount := 0;
  LSuite := TTestSuite.Create('RetryParallel');
  LSuite.Test('flaky', @ParallelFlakyThenPass, 5);
  LSuite.Test('stable', @TestParallelPassA);
  { R4-04: RunParallel now supports retries }
  LSuite.RunParallel(nil);
  { flaky should eventually pass on 3rd try }
  if LSuite.LastFail > 0 then
  begin
    FailTest('flaky test should have passed after retries');
  end;
  PassTest('✓ Retry in parallel');
end;

procedure TestSubtestSkipInParallel;
var
  LSuite: TTestSuite;
begin
  LSuite := TTestSuite.Create('SubtestSkipParallel');
  LSuite.Skip('static_skip', 'deferred');
  LSuite.Test('pass1', @TestParallelPassA);
  LSuite.Test('pass2', @TestParallelPassB);
  LSuite.RunParallel(nil);
  if LSuite.LastSkip < 1 then
  begin
    FailTest('expected at least 1 skip');
  end;
  if LSuite.LastPass < 2 then
  begin
    FailTest('expected at least 2 passes');
  end;
  PassTest('✓ Subtest skip in parallel');
end;

{ ── R3-F16: Closure + Retry ────────────────────────────────────────────────── }

var
  GClosureRetryCount: Integer = 0;

procedure TestClosureRetry;
var
  LSuite: TTestSuite;
begin
  GClosureRetryCount := 0;
  LSuite := TTestSuite.Create('ClosureRetry');
  LSuite.Test('flaky-closure',
    procedure
    begin
      { R4-05: atomic read via return value }
      if InterLockedIncrement(GClosureRetryCount) < 3 then
        Check(False, 'not yet');
    end,
    5);
  LSuite.Run;
  if not LSuite.LastRunPassed then
  begin
    FailTest('closure retry should eventually pass');
  end;
  PassTest('✓ Closure + Retry');
end;

{ ── R6-54: Parallel subtest skip behavior ────────────────────────────────── }

procedure TestParallelSubtestSkip;
var
  LSuite: TTestSuite;
  LResult: TTestRunResult;
  I: Integer;
  LFoundSubtestSkip: Boolean;
begin
  { In parallel mode, subtests (TestSubtest) should get tsSkipped
    since they cannot run in parallel workers. }
  LSuite := TTestSuite.Create('ParSubtestSkip');
  LSuite.Test('normal_pass', @TestParallelPassA);
  LSuite.TestSubtest('subtest_entry',
    procedure(constref Ctx: ITestContext)
    begin
      Ctx.Run('sub1', procedure begin CheckTrue(True); end);
    end);
  LSuite.RunParallelWithResult(nil, LResult);
  { The normal test should pass }
  CheckTrue(LResult.Passed >= 1, 'At least 1 normal test should pass');
  { Subtests in parallel mode get skipped — verify they don't crash the suite }
  CheckTrue(LResult.Failed = 0, 'No tests should fail');
  { T-03: Verify skip message mentions parallel mode }
  LFoundSubtestSkip := False;
  for I := 0 to High(LResult.Results) do
    if (LResult.Results[I].Status = tsSkipped) and
       (LResult.Results[I].Name = 'subtest_entry') then
    begin
      LFoundSubtestSkip := True;
      CheckTrue(
        Pos('subtests not supported', LResult.Results[I].Message) > 0,
        'Skip message should mention parallel mode');
      Break;
    end;
  CheckTrue(LFoundSubtestSkip, 'subtest_entry should be skipped');
  PassTest('✓ Parallel subtest skip');
end;

{ ── R6-56: Table test parallel result name uniqueness ────────────────────── }

procedure R656TableProc(const ACase: TTestCase);
begin
  CheckTrue(True);
end;

procedure TestTableParallelNameUniqueness;
var
  LSuite: TTestSuite;
  LResult: TTestRunResult;
  LSuccess: Boolean;
  LCases: specialize TArray<TTestCase>;
  I, J: Integer;
begin
  LSuite := TTestSuite.Create('TableParallelUnique');
  SetLength(LCases, 4);
  LCases[0].Name := 'case_a'; LCases[0].Data := '1';
  LCases[1].Name := 'case_b'; LCases[1].Data := '2';
  LCases[2].Name := 'case_c'; LCases[2].Data := '3';
  LCases[3].Name := 'case_d'; LCases[3].Data := '4';
  LSuite.TestTable('params', LCases, @R656TableProc);
  LSuccess := LSuite.RunParallelWithResult(nil, LResult);
  CheckTrue(LSuccess, 'Table parallel should pass');
  CheckTrue(LResult.Passed = 4, 'Expected 4 table cases to pass');
  { Verify result names are unique }
  for I := 0 to High(LResult.Results) do
    for J := I + 1 to High(LResult.Results) do
      if LResult.Results[I].Name = LResult.Results[J].Name then
        Fail('Duplicate result name: ' + LResult.Results[I].Name);
  PassTest('✓ Table parallel result name uniqueness');
end;

procedure TestParallelSinkInjection;
var
  LSuite: TTestSuite;
  LResult: TTestRunResult;
  LOutSink: TBufferSink;
  LErrSink: TBufferSink;
  LOutput: string;
begin
  LOutSink := TBufferSink.Create;
  LErrSink := TBufferSink.Create;
  LSuite := TTestSuite.Create('Parallel Sink');
  LSuite.Config.OutSink := LOutSink;
  LSuite.Config.ErrSink := LErrSink;
  LSuite.Config.AnsiMode := amOff;
  LSuite.Test('sink_pass', @TestParallelPassA);
  LSuite.Skip('sink_skip', 'planned');
  LSuite.RunParallelWithResult(nil, LResult);
  LOutput := LOutSink.GetOutput;
  if Pos('sink_pass', LOutput) = 0 then
  begin
    FailTest('parallel sink should capture sink_pass output');
  end;
  if Pos('sink_skip', LOutput) = 0 then
  begin
    FailTest('parallel sink should capture sink_skip output');
  end;
  if LErrSink.GetOutput <> '' then
  begin
    FailTest('parallel sink error output should stay empty for clean run');
  end;
  PassTest('✓ Parallel sink injection');
end;

{ ── v3.1: MaxParallelWorkers batch dispatch ────────────────────────────────── }

procedure TestBatchedWorkerProc;
var
  LCount: Integer;
begin
  LCount := InterLockedIncrement(GConcurrentCount);
  { Update max concurrent — InterlockedExchange if new max }
  if LCount > GMaxConcurrent then
    InterlockedExchange(GMaxConcurrent, LCount);
  SleepMs(50); { hold the slot briefly to ensure overlap detection }
  InterLockedDecrement(GConcurrentCount);
end;

procedure TestMaxParallelWorkers;
var
  LSuite: TTestSuite;
  LRunner: TTestRunner;
  LResults: specialize TArray<TTestRunResult>;
  I: Integer;
begin
  GConcurrentCount := 0;
  GMaxConcurrent := 0;
  LSuite := TTestSuite.Create('BatchDispatch');
  LSuite.Config.MaxParallelWorkers := 2;
  for I := 1 to 8 do
    LSuite.Test('batch_' + IntToStr(I), @TestBatchedWorkerProc);
  LRunner := TTestRunner.Create('batch_test');
  LRunner.Add(LSuite);
  LRunner.RunAllWithResult(LResults);
  if Length(LResults) = 0 then
  begin
    FailTest('no results from batch dispatch');
  end;
  if not LResults[0].AllPassed then
  begin
    FailTest('batch dispatch tests failed');
  end;
  { MaxConcurrent should be <= 2 (the configured limit).
    Due to timing, it could occasionally be 1 if a batch finishes
    before the next starts, but never >2. }
  if GMaxConcurrent > 2 then
  begin
    FailTest('MaxConcurrent=' + IntToStr(GMaxConcurrent) + ', expected <= 2');
  end;
  PassTest('✓ MaxParallelWorkers batch dispatch');
end;

var
  LSuite: TTestSuite;
  LFailSuite, LSkipSuite: TTestSuite;
  LRunner: TTestRunner;
  LResults: specialize TArray<TTestRunResult>;
begin
  WriteLn('=== test_parallel ===');
  LSuite := TTestSuite.Create('Parallel Tests');
  LSuite.Test('p1', @TestParallelSimple);
  LSuite.Test('p2', @TestParallelSimple);
  LSuite.Test('p3', @TestParallelSimple);
  LSuite.Test('p4', @TestParallelSimple);
  LSuite.Test('p5', @TestParallelSimple);
  LSuite.Test('p6', @TestParallelSimple);
  LSuite.Test('p7', @TestParallelSimple);
  LSuite.Test('p8', @TestParallelSimple);

  if not LSuite.RunParallel(nil) then
  begin
    WriteLn;
    FailTest('PARALLEL TESTS FAILED');
  end;

  WriteLn;
  WriteLn(AnsiBold('Test counter: '), GTestCounter);
  if GTestCounter <> 8 then
  begin
    FailTest('expected 8 tests run, got ' + IntToStr(GTestCounter));
  end;
  WriteLn;
  PassTest('ALL PASSED');

  { ── B5.10: Parallel with failure ───────────────────────────────────────── }
  WriteLn;
  SectionHeader('B5.10: Parallel Failure/Skip Tests');
  LFailSuite := TTestSuite.Create('Parallel Failure');
  LFailSuite.Test('pass', @TestParallelPassA);
  LFailSuite.Test('fail', @TestParallelFail);
  if LFailSuite.RunParallel(nil) then
  begin
    FailTest('suite with failing test should return False');
  end;
  if LFailSuite.LastFail < 1 then
  begin
    FailTest('expected at least 1 failure');
  end;
  PassTest('✓ Parallel with failure');

  { ── B5.10: Parallel with skip ─────────────────────────────────────────── }
  LSkipSuite := TTestSuite.Create('Parallel Skip');
  LSkipSuite.Test('pass', @TestParallelPassB);
  LSkipSuite.Skip('skip me', 'reason');
  LSkipSuite.Test('skip in worker', @TestParallelSkip);
  if not LSkipSuite.RunParallel(nil) then
  begin
    FailTest('suite with skip should still return True');
  end;
  if LSkipSuite.LastSkip < 2 then
  begin
    FailTest('expected at least 2 skips (static + worker), got ' + IntToStr(LSkipSuite.LastSkip));
  end;
  PassTest('✓ Parallel with skip');

  { ── B5.10: RunAllParallel ─────────────────────────────────────────────── }
  LRunner := TTestRunner.Create('Parallel Runner');
  LRunner.Add(LSkipSuite);
  LRunner.Add(LFailSuite);
  if LRunner.RunAllParallel(nil) then
  begin
    FailTest('RunAllParallel with failure suite should return False');
  end;
  PassTest('✓ RunAllParallel');

  { ── F08: RunAllParallel aggregation ───────────────────────────────────── }
  WriteLn;
  SectionHeader('F08: RunAllParallel Aggregation');
  begin
    LRunner := TTestRunner.Create('Aggregation Runner');
    { Suite A: 3 pass + 1 skip + 1 fail = 5 }
    LSkipSuite := TTestSuite.Create('Suite A');
    LSkipSuite.Test('a1', @TestParallelPassA);
    LSkipSuite.Test('a2', @TestParallelPassB);
    LSkipSuite.Test('a3', @TestParallelSimple);
    LSkipSuite.Skip('a4', 'deferred');
    LSkipSuite.Test('a5', @TestParallelFail);
    LRunner.Add(LSkipSuite);
    { Suite B: 2 pass = 2 }
    LFailSuite := TTestSuite.Create('Suite B');
    LFailSuite.Test('b1', @TestParallelSimple);
    LFailSuite.Test('b2', @TestParallelSimple);
    LRunner.Add(LFailSuite);
    if LRunner.RunAllParallel(nil) then
    begin
      FailTest('RunAllParallel should return False (suite A has failure)');
    end;
    { TotalPass should be 5 (3 from A + 2 from B) }
    if LRunner.TotalPass <> 5 then
    begin
      FailTest('Expected TotalPass=5, got ' + IntToStr(LRunner.TotalPass));
    end;
    { TotalFail should be 1 (from A) }
    if LRunner.TotalFail <> 1 then
    begin
      FailTest('Expected TotalFail=1, got ' + IntToStr(LRunner.TotalFail));
    end;
    { TotalSkip should be 1 (from A) }
    if LRunner.TotalSkip <> 1 then
    begin
      FailTest('Expected TotalSkip=1, got ' + IntToStr(LRunner.TotalSkip));
    end;
    PassTest('✓ RunAllParallel aggregation');
  end;

  WriteLn;
  PassTest('ALL PARALLEL TESTS PASSED');

  { ── F09: Parallel lifecycle failures ───────────────────────────────────── }
  WriteLn;
  SectionHeader('F09: Parallel Lifecycle Failure Tests');
  TestParallelBeforeEachFail;
  TestParallelSetupFail;

  { ── R2-F22: Timeout + Retry + Skip in Parallel ──────────────────────────── }
  WriteLn;
  SectionHeader('R2-F22: Timeout/Retry/Skip Tests');
  TestParallelTimeout;
  TestRetryInParallel;
  TestSubtestSkipInParallel;
  TestClosureRetry;

  { ── R6-54/R6-56: New parallel coverage tests ───────────────────────────── }
  WriteLn;
  SectionHeader('R6-54/R6-56: Parallel Coverage');
  TestParallelSubtestSkip;
  TestTableParallelNameUniqueness;
  TestParallelSinkInjection;

  WriteLn;
  PassTest('ALL LIFECYCLE TESTS PASSED');

  { ── v3.1: MaxParallelWorkers batch dispatch ──────────────────────────────── }
  WriteLn;
  SectionHeader('v3.1: MaxParallelWorkers Batch Dispatch');
  TestMaxParallelWorkers;

  { ── v3.12: ShouldFail in parallel mode ────────────────────────────────────── }
  WriteLn;
  SectionHeader('v3.12: ShouldFail in Parallel');
  begin
    GShouldFailSuite := TTestSuite.Create('ShouldFailParallel');
    { ShouldFail that raises = should pass in parallel mode }
    GShouldFailSuite.ShouldFail('raises_ok', procedure begin
      raise Exception.Create('expected error');
    end);
    { ShouldFail that does NOT raise = should fail in parallel mode }
    GShouldFailSuite.ShouldFail('no_raise_fail', procedure begin
      { intentionally empty }
    end);
    { Regular test alongside ShouldFail }
    GShouldFailSuite.Test('regular_pass', @TestParallelPassA);
    GShouldFailSuite.RunParallelWithResult(nil, GShouldFailResult);
    if GShouldFailResult.Passed <> 2 then
      FailTest('expected 2 passed (raises_ok + regular_pass), got ' +
        IntToStr(GShouldFailResult.Passed));
    if GShouldFailResult.Failed <> 1 then
      FailTest('expected 1 failed (no_raise_fail), got ' +
        IntToStr(GShouldFailResult.Failed));
    PassTest('✓ ShouldFail in parallel mode');
  end;

  { ── Phase 9: ShortSkip in parallel mode ───────────────────────────────────── }
  WriteLn;
  SectionHeader('Phase 9: ShortSkip in Parallel');
  begin
    ResetDefaultConfig;
    { Test 1: ShortSkip test runs normally when ShortMode is off }
    GShortSkipSuite := TTestSuite.Create('ShortSkipOff');
    GShortSkipSuite.Test('fast_pass', @TestParallelPassA);
    GShortSkipSuite.ShortSkip('slow_skip', procedure begin
      CheckTrue(True);
    end);
    GShortSkipSuite.Test('fast_pass2', @TestParallelPassA);
    GShortSkipSuite.RunParallelWithResult(nil, GShortSkipResult);
    if GShortSkipResult.Passed <> 3 then
      FailTest('ShortSkip off: expected 3 passed, got ' +
        IntToStr(GShortSkipResult.Passed));
    if GShortSkipResult.Skipped <> 0 then
      FailTest('ShortSkip off: expected 0 skipped, got ' +
        IntToStr(GShortSkipResult.Skipped));
    ResetDefaultConfig;
    PassTest('ShortSkip off in parallel');
    { Test 2: ShortSkip test is skipped in parallel when ShortMode is on }
    GShortSkipSuite := TTestSuite.Create('ShortSkipOn');
    GShortSkipSuite.Test('fast1', @TestParallelPassA);
    GShortSkipSuite.ShortSkip('slow1', procedure begin
      CheckTrue(True);
    end);
    GShortSkipSuite.Test('fast2', @TestParallelPassA);
    SetDefaultShortMode(True);
    GShortSkipSuite.Config := DefaultConfig;
    GShortSkipSuite.RunParallelWithResult(nil, GShortSkipResult);
    if GShortSkipResult.Passed <> 2 then
      FailTest('ShortSkip on: expected 2 passed, got ' +
        IntToStr(GShortSkipResult.Passed));
    if GShortSkipResult.Skipped <> 1 then
      FailTest('ShortSkip on: expected 1 skipped, got ' +
        IntToStr(GShortSkipResult.Skipped));
    ResetDefaultConfig;
    PassTest('ShortSkip on in parallel');
  end;

  { ── Phase 10: Verbose mode in parallel ──────────────────────────────────── }
  WriteLn;
  SectionHeader('Phase 10: Verbose in Parallel');
  begin
    ResetDefaultConfig;
    SetDefaultVerboseMode(True);
    GVerbSuite := TTestSuite.Create('VerbParallel');
    GVerbSuite.Test('vp1', @TestParallelPassA);
    GVerbSuite.Test('vp2', @TestParallelPassA);
    GVerbSuite.Test('vp3', @TestParallelPassA);
    GVerbSuite.Config := DefaultConfig;
    GVerbSuite.RunParallelWithResult(nil, GVerbResult);
    if GVerbResult.Passed <> 3 then
      FailTest('verbose parallel: expected 3 passed, got ' +
        IntToStr(GVerbResult.Passed));
    ResetDefaultConfig;
    PassTest('Verbose in parallel');
  end;

  { ── Phase 10: Cleanup in parallel ───────────────────────────────────────── }
  WriteLn;
  SectionHeader('Phase 10: Cleanup in Parallel');
  begin
    ResetDefaultConfig;
    GCleanupCounter := 0;
    GVerbSuite := TTestSuite.Create('CleanupParallel');
    GVerbSuite.Cleanup(procedure begin InterLockedIncrement(GCleanupCounter); end);
    GVerbSuite.Test('cp1', @TestParallelPassA);
    GVerbSuite.Test('cp2', @TestParallelPassA);
    GVerbSuite.Test('cp3', @TestParallelPassA);
    GVerbSuite.RunParallelWithResult(nil, GVerbResult);
    { Cleanup should run after each test: 3 tests = 3 cleanup calls }
    if GCleanupCounter <> 3 then
      FailTest('cleanup parallel: expected 3 cleanup calls, got ' +
        IntToStr(GCleanupCounter));
    if GVerbResult.Passed <> 3 then
      FailTest('cleanup parallel: expected 3 passed, got ' +
        IntToStr(GVerbResult.Passed));
    ResetDefaultConfig;
    PassTest('Cleanup in parallel');
  end;

  { ── Phase 10b: Cleanup exception in parallel ───────────────────────────── }
  WriteLn;
  SectionHeader('Phase 10b: Cleanup Exception in Parallel');
  begin
    ResetDefaultConfig;
    GCleanupCounter := 0;
    GVerbSuite := TTestSuite.Create('CleanupExceptParallel');
    { First cleanup raises, second should still run }
    GVerbSuite.Cleanup(procedure
    begin
      InterLockedIncrement(GCleanupCounter);
      raise Exception.Create('cleanup boom');
    end);
    GVerbSuite.Cleanup(procedure
    begin
      InterLockedIncrement(GCleanupCounter);
    end);
    GVerbSuite.Test('ce1', @TestParallelPassA);
    GVerbSuite.Test('ce2', @TestParallelPassA);
    GVerbSuite.RunParallelWithResult(nil, GVerbResult);
    { Both cleanups should run for each test: 2 tests * 2 cleanups = 4 }
    if GCleanupCounter <> 4 then
      FailTest('cleanup except parallel: expected 4 cleanup calls, got ' +
        IntToStr(GCleanupCounter));
    { Tests should still pass — cleanup exceptions don't fail the test }
    if GVerbResult.Passed <> 2 then
      FailTest('cleanup except parallel: expected 2 passed, got ' +
        IntToStr(GVerbResult.Passed));
    ResetDefaultConfig;
    PassTest('Cleanup exception in parallel');
  end;

  { ── G1: RunAllParallelWithResult at runner level ───────────────── }
  WriteLn;
  SectionHeader('G1: RunAllParallelWithResult');
  begin
    ResetDefaultConfig;
    GTestCounter := 0;
    LRunner := TTestRunner.Create('ParResultRunner');
    LSuite := TTestSuite.Create('ParResSuiteA');
    LSuite.Test('pra1', @TestParallelPassA);
    LSuite.Test('pra2', @TestParallelPassA);
    LRunner.Add(LSuite);
    LFailSuite := TTestSuite.Create('ParResSuiteB');
    LFailSuite.Test('prb1', @TestParallelPassA);
    LRunner.Add(LFailSuite);
    LRunner.RunAllParallelWithResult(nil, LResults);
    { Verify results are populated }
    if Length(LResults) < 2 then
      FailTest('RunAllParallelWithResult: expected >= 2 suite results, got ' +
        IntToStr(Length(LResults)));
    ResetDefaultConfig;
    PassTest('RunAllParallelWithResult');
  end;

  WriteLn;
  PassTest('ALL PARALLEL TESTS PASSED');
end.
