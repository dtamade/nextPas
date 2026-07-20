{ test_parallel — Validates parallel test execution }
program test_parallel;

{$mode objfpc}{$H+}{$J-}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

uses
  nextpas.core.thread.init,
  nextpas.core.text.conv,
  nextpas.core.test,
  nextpas.core.test.runner;

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
  { B4 v8.8d: race-intent counters }
  GAtomicCounter: LongInt = 0;
  GSeqDone: LongInt = 0;

{ Named procedures for closures stored in global TTestSuite variables.
  Anonymous closures in global records leak because FPC finalizes global
  managed types after heaptrc's DumpHeap. }
procedure ShouldFailRaises;
begin
  raise Exception.Create('expected error');
end;

procedure ShouldFailNoRaise;
begin
  { intentionally empty }
end;

procedure ShortSkipSlow;
begin
  CheckTrue(True);
end;

procedure ShortSkipSlow1;
begin
  CheckTrue(True);
end;

procedure CleanupIncrement;
begin
  InterLockedIncrement(GCleanupCounter);
end;

{ ── B4: race-intent helpers ──────────────────────────────────────────────── }

procedure AtomicIncBody;
var
  I: Integer;
begin
  for I := 1 to 1000 do
    InterLockedIncrement(GAtomicCounter);
  CheckTrue(True, 'atomic body done');
end;

procedure SeqMarkerBody;
begin
  SleepMs(30);
  { Phase 1 is serial — single writer before parallel workers start. }
  GSeqDone := 1;
  CheckTrue(True, 'seq marker');
end;

procedure ParSeesSeqDone;
begin
  { Phase-1 TestSeq finishes before Phase-2 parallel workers start. }
  CheckTrue(GSeqDone = 1, 'TestSeq must complete before parallel tests');
end;

procedure ExpectStormBody;
var
  I: Integer;
begin
  for I := 1 to 500 do
  begin
    ExpectInt(I).ToEqualInt(I);
    CheckEqual(I, I);
  end;
end;

{ ── B9: RegisterStub/Fixture main-thread-only contracts ─────────────────── }

type
  PRegThreadCtx = ^TRegThreadCtx;
  TRegThreadCtx = record
    Suite: TTestSuite;
    OpStub: Boolean;
    Caught: Boolean;
    Msg: string;
  end;

function RegisterCrossThreadWorker(P: Pointer): PtrInt;
var
  C: PRegThreadCtx;
  LPtr: Pointer;
  LObj: TObject;
begin
  C := PRegThreadCtx(P);
  C^.Caught := False;
  C^.Msg := '';
  try
    if C^.OpStub then
    begin
      GetMem(LPtr, 8);
      try
        RegisterStub(C^.Suite, LPtr);
      except
        FreeMem(LPtr);
        raise;
      end;
    end
    else
    begin
      LObj := TObject.Create;
      try
        RegisterFixture(C^.Suite, LObj);
      except
        LObj.Free;
        raise;
      end;
    end;
  except
    on E: Exception do
    begin
      C^.Caught := True;
      C^.Msg := E.Message;
    end;
  end;
  Result := 0;
end;

procedure TestRegisterStubMustBeMainThread;
var
  LSuite: TTestSuite;
  Ctx: TRegThreadCtx;
  TID: TThreadID;
begin
  LSuite := TTestSuite.Create('reg-stub');
  Ctx.Suite := LSuite;
  Ctx.OpStub := True;
  Ctx.Caught := False;
  Ctx.Msg := '';
  TID := BeginThread(@RegisterCrossThreadWorker, @Ctx);
  CheckTrue(TID <> TThreadID(0));
  WaitForThreadTerminate(TID, 10000);
  CheckTrue(Ctx.Caught, 'RegisterStub from worker must raise');
  CheckContains(Ctx.Msg, 'main thread');
  LSuite := Default(TTestSuite);
end;

procedure TestRegisterFixtureMustBeMainThread;
var
  LSuite: TTestSuite;
  Ctx: TRegThreadCtx;
  TID: TThreadID;
begin
  LSuite := TTestSuite.Create('reg-fix');
  Ctx.Suite := LSuite;
  Ctx.OpStub := False;
  Ctx.Caught := False;
  Ctx.Msg := '';
  TID := BeginThread(@RegisterCrossThreadWorker, @Ctx);
  CheckTrue(TID <> TThreadID(0));
  WaitForThreadTerminate(TID, 10000);
  CheckTrue(Ctx.Caught, 'RegisterFixture from worker must raise');
  CheckContains(Ctx.Msg, 'main thread');
  LSuite := Default(TTestSuite);
end;

procedure TestRegisterStubMainThreadOk;
var
  LSuite: TTestSuite;
  LPtr: Pointer;
begin
  LSuite := TTestSuite.Create('reg-stub-ok');
  GetMem(LPtr, 8);
  try
    RegisterStub(LSuite, LPtr);
    CheckTrue(True, 'main-thread RegisterStub ok');
  finally
    { CleanupTableAllocations will FreeMem stubs registered on suite }
    LSuite.CleanupTableAllocations;
    LSuite := Default(TTestSuite);
  end;
end;

procedure TestParallelSoftFail;
var
  LSuite: TTestSuite;
  LResult: TTestRunResult;
  I: Integer;
  LFound: Boolean;
begin
  LSuite := TTestSuite.Create('par-soft');
  LSuite.Test('soft_a', procedure
    begin
      SoftFail('par soft a');
      SoftFail('par soft b');
    end);
  LSuite.Test('ok_b', procedure
    begin
      CheckTrue(True);
    end);
  CheckFalse(LSuite.RunParallelWithResult(nil, LResult), 'soft fails suite');
  CheckTrue(LResult.Failed >= 1);
  CheckTrue(LResult.Passed >= 1, 'other parallel tests still pass');
  LFound := False;
  for I := 0 to High(LResult.Results) do
    if (LResult.Results[I].Name = 'soft_a') and
       (LResult.Results[I].Status = tsFailed) then
    begin
      LFound := True;
      { v8.19 exact join under RunParallel }
      CheckEqual('par soft a; par soft b', LResult.Results[I].Message);
    end;
  CheckTrue(LFound, 'soft_a failed with both messages');
  LSuite := Default(TTestSuite);
end;

procedure TestB30ParallelSoftFailPathCase(const AC: TTestCase);
{ Data: single soft message. RunParallel: that test fails exact, peer passes. }
var
  LSuite: TTestSuite;
  LResult: TTestRunResult;
  I: Integer;
  LFound: Boolean;
begin
  LSuite := TTestSuite.Create('par-fp-' + AC.Name);
  LSuite.Test('soft', procedure
    begin
      SoftFail(AC.Data);
    end);
  LSuite.Test('peer', procedure
    begin
      CheckTrue(True);
    end);
  CheckFalse(LSuite.RunParallelWithResult(nil, LResult));
  CheckEqual(1, LResult.Failed);
  CheckEqual(1, LResult.Passed);
  LFound := False;
  for I := 0 to High(LResult.Results) do
    if LResult.Results[I].Name = 'soft' then
    begin
      LFound := True;
      CheckEqual(Ord(tsFailed), Ord(LResult.Results[I].Status));
      CheckEqual(AC.Data, LResult.Results[I].Message);
    end;
  CheckTrue(LFound, 'soft result present ' + AC.Name);
  LSuite := Default(TTestSuite);
end;

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
  LSuite := Default(TTestSuite);
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
  LSuite := Default(TTestSuite);
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
  LSuite := Default(TTestSuite);
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
  LSuite := Default(TTestSuite);
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
  LSuite := Default(TTestSuite);
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
  LSuite := Default(TTestSuite);
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
  LSuite := Default(TTestSuite);
end;

{ ── B10: Parallel mixed suite — normal run + subtest skipped count ───────── }

procedure TestParallelMixedSubtestCounts;
var
  LSuite: TTestSuite;
  LResult: TTestRunResult;
  I: Integer;
  LSkippedSub: Integer;
  LPassedNormal: Integer;
begin
  LSuite := TTestSuite.Create('ParMixedSub');
  LSuite.Test('n1', @TestParallelPassA);
  LSuite.Test('n2', @TestParallelPassA);
  LSuite.TestSubtest('s1',
    procedure(constref Ctx: ITestContext)
    begin
      Ctx.Run('leaf', procedure begin CheckTrue(False, 'must not run'); end);
    end);
  LSuite.TestSubtest('s2',
    procedure(constref Ctx: ITestContext)
    begin
      Ctx.Run('leaf2', procedure begin CheckTrue(False, 'must not run'); end);
    end);
  LSuite.RunParallelWithResult(nil, LResult);
  LSkippedSub := 0;
  LPassedNormal := 0;
  for I := 0 to High(LResult.Results) do
  begin
    if (LResult.Results[I].Status = tsSkipped) and
       ((LResult.Results[I].Name = 's1') or (LResult.Results[I].Name = 's2')) then
    begin
      Inc(LSkippedSub);
      CheckTrue(Pos('subtests not supported', LResult.Results[I].Message) > 0,
        'skip message for ' + LResult.Results[I].Name);
    end;
    if (LResult.Results[I].Status = tsPassed) and
       ((LResult.Results[I].Name = 'n1') or (LResult.Results[I].Name = 'n2')) then
      Inc(LPassedNormal);
  end;
  CheckEqual(LPassedNormal, 2, 'two normal tests pass in parallel');
  CheckEqual(LSkippedSub, 2, 'two subtests skipped in parallel');
  CheckTrue(LResult.Failed = 0, 'mixed suite no failures');
  CheckTrue(LResult.Skipped >= 2, 'Skipped counter >= 2');
  PassTest('✓ B10 parallel mixed subtest counts');
  LSuite := Default(TTestSuite);
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
  LSuite := Default(TTestSuite);
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
  LSuite := Default(TTestSuite);
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
  LRunner: TSuiteRunner;
  LResults: specialize TArray<TTestRunResult>;
  I: Integer;
begin
  GConcurrentCount := 0;
  GMaxConcurrent := 0;
  LSuite := TTestSuite.Create('BatchDispatch');
  LSuite.Config.MaxParallelWorkers := 2;
  for I := 1 to 8 do
    LSuite.Test('batch_' + IntToStr(I), @TestBatchedWorkerProc);
  LRunner := TSuiteRunner.Create('batch_test');
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
  LRunner := Default(TSuiteRunner);
  LSuite := Default(TTestSuite);
end;

var
  LSuite: TTestSuite;
  LFailSuite, LSkipSuite: TTestSuite;
  LRunner: TSuiteRunner;
  LResults: specialize TArray<TTestRunResult>;
  LB30Suite: TTestSuite;
  LB30Cases: specialize TArray<TTestCase>;
  LB30I: Integer;
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
  LRunner := TSuiteRunner.Create('Parallel Runner');
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
    LRunner := TSuiteRunner.Create('Aggregation Runner');
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
  TestParallelMixedSubtestCounts;
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
    GShouldFailSuite.ShouldFail('raises_ok', @ShouldFailRaises);
    { ShouldFail that does NOT raise = should fail in parallel mode }
    GShouldFailSuite.ShouldFail('no_raise_fail', @ShouldFailNoRaise);
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
    GShortSkipSuite.ShortSkip('slow_skip', @ShortSkipSlow);
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
    GShortSkipSuite.ShortSkip('slow1', @ShortSkipSlow1);
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
    GVerbSuite.Cleanup(@CleanupIncrement);
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
    LRunner := TSuiteRunner.Create('ParResultRunner');
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

  { ── B4 v8.8d: race-intent pressure (Go -race substitute) ───────────── }
  WriteLn;
  SectionHeader('B4: Atomic counter under RunParallel');
  begin
    ResetDefaultConfig;
    GAtomicCounter := 0;
    LSuite := TTestSuite.Create('AtomicRace');
    LSuite.Test('a1', @AtomicIncBody);
    LSuite.Test('a2', @AtomicIncBody);
    LSuite.Test('a3', @AtomicIncBody);
    LSuite.Test('a4', @AtomicIncBody);
    LSuite.Test('a5', @AtomicIncBody);
    LSuite.Test('a6', @AtomicIncBody);
    LSuite.Test('a7', @AtomicIncBody);
    LSuite.Test('a8', @AtomicIncBody);
    LSuite.RunParallelWithResult(nil, GVerbResult);
    if GVerbResult.Passed <> 8 then
      FailTest('atomic race: expected 8 passed, got ' + IntToStr(GVerbResult.Passed));
    if GAtomicCounter <> 8 * 1000 then
      FailTest('atomic race: expected counter 8000, got ' + IntToStr(GAtomicCounter));
    ResetDefaultConfig;
    PassTest('B4 atomic counter');
  end;

  WriteLn;
  SectionHeader('B4: TestSeq runs before parallel batch');
  begin
    ResetDefaultConfig;
    GSeqDone := 0;
    LSuite := TTestSuite.Create('SeqThenParallel');
    LSuite.TestSeq('seq-first', @SeqMarkerBody);
    LSuite.Test('par-a', @ParSeesSeqDone);
    LSuite.Test('par-b', @ParSeesSeqDone);
    LSuite.Test('par-c', @ParSeesSeqDone);
    LSuite.RunParallelWithResult(nil, GVerbResult);
    if GVerbResult.Passed <> 4 then
      FailTest('TestSeq mix: expected 4 passed, got ' + IntToStr(GVerbResult.Passed));
    if GSeqDone <> 1 then
      FailTest('TestSeq mix: GSeqDone not set');
    ResetDefaultConfig;
    PassTest('B4 TestSeq before parallel');
  end;

  WriteLn;
  SectionHeader('B4: Expect/Check storm in parallel');
  begin
    ResetDefaultConfig;
    LSuite := TTestSuite.Create('ExpectStorm');
    LSuite.Test('e1', @ExpectStormBody);
    LSuite.Test('e2', @ExpectStormBody);
    LSuite.Test('e3', @ExpectStormBody);
    LSuite.Test('e4', @ExpectStormBody);
    LSuite.RunParallelWithResult(nil, GVerbResult);
    if GVerbResult.Passed <> 4 then
      FailTest('expect storm: expected 4 passed, got ' + IntToStr(GVerbResult.Passed));
    if GVerbResult.Failed <> 0 then
      FailTest('expect storm: unexpected failures');
    ResetDefaultConfig;
    PassTest('B4 expect storm');
  end;

  WriteLn;
  SectionHeader('B4: Parallel result aggregation totals');
  begin
    ResetDefaultConfig;
    LSuite := TTestSuite.Create('AggTotals');
    LSuite.Test('ok1', @TestParallelPassA);
    LSuite.Test('ok2', @TestParallelPassB);
    LSuite.Test('ok3', @TestParallelPassA);
    LSuite.Test('bad', @TestParallelFail);
    LSuite.Test('skp', @TestParallelSkip);
    LSuite.RunParallelWithResult(nil, GVerbResult);
    if GVerbResult.Passed + GVerbResult.Failed + GVerbResult.Skipped <> 5 then
      FailTest('aggregation: P+F+S expected 5, got ' +
        IntToStr(GVerbResult.Passed + GVerbResult.Failed + GVerbResult.Skipped));
    if GVerbResult.Passed <> 3 then
      FailTest('aggregation: expected 3 passed');
    if GVerbResult.Failed <> 1 then
      FailTest('aggregation: expected 1 failed');
    if GVerbResult.Skipped <> 1 then
      FailTest('aggregation: expected 1 skipped');
    ResetDefaultConfig;
    PassTest('B4 result aggregation');
  end;

  WriteLn;
  SectionHeader('B9: RegisterStub/Fixture main-thread only');
  begin
    TestRegisterStubMustBeMainThread;
    PassTest('B9 RegisterStub worker fails');
    TestRegisterFixtureMustBeMainThread;
    PassTest('B9 RegisterFixture worker fails');
    TestRegisterStubMainThreadOk;
    PassTest('B9 RegisterStub main ok');
  end;

  WriteLn;
  SectionHeader('B23: SoftFail in parallel');
  begin
    TestParallelSoftFail;
    PassTest('B23 parallel SoftFail');
  end;

  WriteLn;
  SectionHeader('B30: parallel SoftFail fail-path table');
  begin
    SetLength(LB30Cases, 48);
    for LB30I := 0 to High(LB30Cases) do
    begin
      LB30Cases[LB30I].Name := 'p' + IntToStr(LB30I);
      LB30Cases[LB30I].Data := 'par-soft-msg-' + IntToStr(LB30I);
    end;
    LB30Suite := TTestSuite.Create('par-b30');
    LB30Suite.TestTable('B30 parallel soft fail-path', LB30Cases,
      @TestB30ParallelSoftFailPathCase);
    if not LB30Suite.Run then
      FailTest('B30 parallel soft fail-path table failed');
    PassTest('B30 parallel soft fail-path table');
    LB30Suite := Default(TTestSuite);
  end;

  WriteLn;
  PassTest('ALL PARALLEL TESTS PASSED');
  { Release global managed records before heaptrc tally.
    FPC global finalization runs after heaptrc DumpHeap. }
  GShouldFailSuite := Default(TTestSuite);
  GShouldFailResult := Default(TTestRunResult);
  GShortSkipSuite := Default(TTestSuite);
  GShortSkipResult := Default(TTestRunResult);
  GVerbSuite := Default(TTestSuite);
  GVerbResult := Default(TTestRunResult);
  { Release main block local variables }
  LSuite := Default(TTestSuite);
  LFailSuite := Default(TTestSuite);
  LSkipSuite := Default(TTestSuite);
  LRunner := Default(TSuiteRunner);
  LResults := nil;
end.
