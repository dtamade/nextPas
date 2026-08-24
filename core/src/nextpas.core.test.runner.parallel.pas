{ nextpas.core.test.runner.parallel — Timeout worker + parallel thread worker
  =========================================================
  Depends on: nextpas.core.test.base, nextpas.core.test.output,
              nextpas.core.platform.thread }

unit nextpas.core.test.runner.parallel;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.system,
  nextpas.core.text.conv,
  nextpas.core.test.base,
  nextpas.core.test.config,
  nextpas.core.test.output,
  nextpas.core.test.runner.context,
  nextpas.core.sync.intf,
  nextpas.core.platform.thread,
  nextpas.core.time,
  nextpas.core.time.cpu;

{ ── Timeout worker (internal) ──────────────────────────────────────────────── }

function RunTestWithTimeout(AProc: TTestProc; ATimeoutMs: Integer;
  const AConfig: TTestConfig; out AStatus: TTestStatus;
  out AMsg: string): Boolean;
function RunTestWithTimeout(AClosure: TTestClosure; ATimeoutMs: Integer;
  const AConfig: TTestConfig; out AStatus: TTestStatus;
  out AMsg: string): Boolean;

{ ── Parallel thread worker (internal) ──────────────────────────────────────── }

type
  TThreadRec = record
    Entry          : TTestEntry;
    SuiteName      : string;
    Config         : TTestConfig;
    Mtx            : IMutex;  { protects Pass/Fail/Skip counters + result output }
    Before         : TTestProc;
    BeforeClosure  : TTestClosure;
    After          : TTestProc;
    AfterClosure   : TTestClosure;
    EachCleanups   : specialize TArray<TTestClosure>;  { LIFO cleanup after each test }
    Pass           : PInteger;
    Fail           : PInteger;
    Skip           : PInteger;
    Res            : ^TTestResult; { non-nil -> write per-test result here }
    ProgressCounter: PInteger;     { shared counter for [N/Total] display }
    ProgressTotal  : Integer;      { total eligible tests for progress }
  end;
  PThreadRec = ^TThreadRec;

function ParallelWorkerProc(AArg: Pointer): Pointer; cdecl;

{ ── Monitoring ───────────────────────────────────────────────────────────── }

{ Counter: how many timeout-worker LRec records were leaked (truly stuck
  threads where both poll and timed-join expired). Exposed for test diagnostics.
  A non-zero value after a full test run means at least one test deadlocked. }
var
  GTimeoutLeakCount: Integer;

{ v8.25: public accessors for suite-level observability (TimeoutWorkerLeaks). }
function GetTimeoutWorkerLeakCount: Integer;
procedure ResetTimeoutWorkerLeakCount;

implementation

function GetTimeoutWorkerLeakCount: Integer;
begin
  Result := GTimeoutLeakCount;
end;

procedure ResetTimeoutWorkerLeakCount;
begin
  GTimeoutLeakCount := 0;
end;

{ ═════════════════════════════════════════════════════════════════════════════ }
{ Timeout worker                                                                }
{ ═════════════════════════════════════════════════════════════════════════════ }

type
  TTimeoutRec = record
    Proc    : TTestProc;
    Closure : TTestClosure;
    Done    : Boolean;
    ErrorMsg: string;
    Status  : TTestStatus;
  end;
  PTimeoutRec = ^TTimeoutRec;

function TimeoutWorker(AArg: Pointer): Pointer; cdecl;
var
  R: PTimeoutRec;
begin
  Result := nil;
  R := PTimeoutRec(AArg);
  try
    if Assigned(R^.Closure) then
      R^.Closure()
    else
      R^.Proc;
    WriteBarrier;
    R^.Done := True;
  except
    on E: ETestSkipped do
    begin
      R^.Status := tsSkipped;
      R^.ErrorMsg := E.Message;
      WriteBarrier;
      R^.Done := True;
    end;
    on E: EAssertionFailed do
    begin
      R^.Status := tsFailed;
      R^.ErrorMsg := E.Message;
      WriteBarrier;
      R^.Done := True;
    end;
    on E: Exception do
    begin
      R^.Status := tsError;
      R^.ErrorMsg := FormatExceptionMsg(E);
      WriteBarrier;
      R^.Done := True;
    end;
  end;
  { Main thread always joins and disposes the record — no dispose here. }
end;

function RunTestWithTimeout_internal(AProc: TTestProc; AClosure: TTestClosure;
  ATimeoutMs: Integer; const AConfig: TTestConfig;
  out AStatus: TTestStatus; out AMsg: string): Boolean;
{ Returns True if test completed (pass/fail/error/skip).
  Returns False if timed out (AStatus = tsError, AMsg = 'timeout').
  C-02: Uses platform_thread_timedjoin instead of polling for zero CPU waste. }
var
  LRec: PTimeoutRec;
  LHandle: TPlatformThreadHandle;
  LRetVal: Pointer;
  LJoinTimeoutMs: Int64;
  LJoinResult: Int32;
begin
  New(LRec);
  LRec^ := Default(TTimeoutRec);
  LRec^.Proc := AProc;
  LRec^.Closure := AClosure;
  LRec^.Done := False;
  LRec^.ErrorMsg := '';
  LRec^.Status := tsPassed;

  { P1 fix: check thread creation result — invalid handle would cause
    undefined behavior in timed-join and detach. }
  if platform_thread_create(LHandle, @TimeoutWorker, LRec) <> 0 then
  begin
    AStatus := tsError;
    AMsg := 'failed to create timeout worker thread';
    Dispose(LRec);
    Result := False;
    Exit;
  end;

  { C-02: Use timed-join instead of poll loop — blocks efficiently via
    pthread_timedjoin_np, no CPU waste, instant detection on completion. }
  LJoinResult := platform_thread_timedjoin(LHandle, ATimeoutMs, LRetVal);

  { ReadBarrier before reading results — join provides happens-before on
    success path, but on timeout path we need an explicit barrier to see
    the worker's writes to Status/ErrorMsg/Done. }
  ReadBarrier;

  if LJoinResult = 0 then
  begin
    { Thread finished within timeout — read results and dispose }
    AStatus := LRec^.Status;
    AMsg := LRec^.ErrorMsg;
    if not LRec^.Done then
    begin
      { Worker finished but didn't set Done — unusual, treat as error }
      AStatus := tsError;
      AMsg := 'worker exited without completing';
      Result := False;
    end
    else
      Result := True;
    Dispose(LRec);
  end
  else
  begin
    { Timed out — give worker extra time to finish cleanup.
      Use max(2x original, 5s) for short timeouts. }
    LJoinTimeoutMs := Int64(ATimeoutMs) * 2;
    if LJoinTimeoutMs < 5000 then
      LJoinTimeoutMs := 5000;

    LJoinResult := platform_thread_timedjoin(LHandle, LJoinTimeoutMs, LRetVal);
    ReadBarrier;

    if (LJoinResult = 0) or LRec^.Done then
    begin
      { Worker finished during grace period — test was too slow }
      AStatus := tsError;
      AMsg := 'test timed out after ' + IntToStr(ATimeoutMs) + 'ms';
      Result := False;
      Dispose(LRec);
    end
    else
    begin
      { Truly stuck worker — timed join also expired. Detach and warn.
        LRec will leak because we can't safely access it after detach. }
      AStatus := tsError;
      AMsg := 'test timed out after ' + IntToStr(ATimeoutMs) + 'ms';
      Result := False;
      Inc(GTimeoutLeakCount);
      platform_thread_detach(LHandle);
      ResolveErrSink(AConfig).WriteLn(
        '  ' + AnsiYellow('WARNING', AConfig) + ': test timed out after ' +
        IntToStr(ATimeoutMs) +
        'ms - worker thread stuck, detached (LRec leaked)');
    end;
  end;
end;

function RunTestWithTimeout(AProc: TTestProc; ATimeoutMs: Integer;
  const AConfig: TTestConfig; out AStatus: TTestStatus;
  out AMsg: string): Boolean;
begin
  Result := RunTestWithTimeout_internal(
    AProc, nil, ATimeoutMs, AConfig, AStatus, AMsg);
end;

function RunTestWithTimeout(AClosure: TTestClosure; ATimeoutMs: Integer;
  const AConfig: TTestConfig; out AStatus: TTestStatus;
  out AMsg: string): Boolean;
begin
  Result := RunTestWithTimeout_internal(
    nil, AClosure, ATimeoutMs, AConfig, AStatus, AMsg);
end;

{ ═════════════════════════════════════════════════════════════════════════════ }
{ Parallel thread worker                                                        }
{ ═════════════════════════════════════════════════════════════════════════════ }

{ Safe mutex release — suppresses intermittent EPERM from ERRORCHECK mutex
  under heavy thread contention. The test result is already committed before
  Release, so swallowing this error is safe. }
procedure SafeRelease(const AMtx: IMutex; const AConfig: TTestConfig);
begin
  try
    AMtx.Release;
  except
    on E: Exception do
    begin
      { Suppress: ERRORCHECK mutex may return EPERM under rare contention.
        The critical section data is already committed. }
      ResolveErrSink(AConfig).WriteLn('SafeRelease: ' + E.Message);
    end;
  end;
end;

procedure EmitParallelSkip(const R: PThreadRec; const ASkipReason: string;
  const AOutSink: IOutputSink; const AConfig: TTestConfig);
{ Shared early-exit for parallel skip paths: acquire mutex, increment skip
  counter, write output, release mutex, set result. }
begin
  R^.Mtx.Acquire;
  try
    R^.Skip^ := R^.Skip^ + 1;
    WriteTestOutput(tsSkipped, R^.Entry.Name, '', ASkipReason,
      0, AOutSink, AConfig);
  finally
    SafeRelease(R^.Mtx, AConfig);
  end;
  if R^.Res <> nil then
    R^.Res^ := MakeTestResult(R^.Entry.Name, tsSkipped, ASkipReason, 0);
end;

procedure MutexWarn(const R: PThreadRec; const AMsg: string;
  const AErrSink: IOutputSink; const AConfig: TTestConfig);
{ Acquire mutex, write warning, release. Shared by afterEach/cleanup paths. }
begin
  R^.Mtx.Acquire;
  try
    WriteWarning(AMsg, AErrSink, AConfig);
  finally
    SafeRelease(R^.Mtx, AConfig);
  end;
end;

function ParallelWorkerProc(AArg: Pointer): Pointer; cdecl;
var
  R: PThreadRec;
  LConfig: TTestConfig;
  LStatus: TTestStatus;
  LFailMsg: string;
  LSkipReason: string;
  LStart: TInstant;
  LResultWritten: Boolean;
  LTotalRetries: Integer;
  LRetriesLeft: Integer;
  LTimeoutMs: Integer;
  LOutSink: IOutputSink;
  LErrSink: IOutputSink;
  LCIdx: Integer;
  LDurMs: Int64;
  LProgressPrefix: string;
  LSubCtx: TTestContext;
  LRepeatCount, LRepeatI: Integer;
begin
  Result := nil;
  LSubCtx := nil;  { Explicit init — prevents EAccessViolation in cleanup for ekTableTest }
  R := PThreadRec(AArg);
  LConfig := ResolveConfig(R^.Config);
  LOutSink := ResolveOutSink(LConfig);
  LErrSink := ResolveErrSink(LConfig);
  LStatus := tsPassed;
  LFailMsg := '';
  LSkipReason := '';
  LStart := TInstant.Now; { set before BeforeEach so duration is correct on skip }
  LResultWritten := False;
  LTimeoutMs := GetTestTimeout(LConfig);
  try
  SetTestContext(R^.SuiteName, R^.Entry.Name);
  NoteHeapBaseline;
  { P1 fix: install TTestContext in parallel workers so Ctx.Log, Ctx.OnCleanup,
    Ctx.TempDir, and Ctx.SetEnv work for regular tests under RunParallel. }
  if R^.Entry.Kind = ekTest then
  begin
    LSubCtx := TTestContext.Create(R^.Entry.Name, LConfig);
    SetCurrentTestContext(LSubCtx);
  end;
  try

  { Subtests are not supported in parallel mode — skip gracefully }
  if R^.Entry.Kind = ekSubtest then
  begin
    EmitParallelSkip(R, 'subtests not supported in parallel mode',
      LOutSink, LConfig);
    Exit;
  end;

  if R^.Entry.Kind = ekSkipped then
  begin
    EmitParallelSkip(R, R^.Entry.SkipReason, LOutSink, LConfig);
    Exit;
  end;

  if Assigned(R^.Before) or Assigned(R^.BeforeClosure) then
  begin
    try
      if Assigned(R^.Before) then R^.Before else R^.BeforeClosure();
    except
      on E: ETestSkipped do
      begin
        LStatus := tsSkipped;
        LSkipReason := E.Message;
      end;
      on E: Exception do
      begin
        LStatus := tsError;
        LFailMsg := 'beforeEach failed: ' + E.Message;
        R^.Mtx.Acquire;
        try
          { Write result inside mutex; output will be written by the final block
            below — don't write here to avoid duplicate output lines. }
          if R^.Res <> nil then
          begin
            R^.Res^ := MakeTestResult(R^.Entry.Name, tsError,
              LFailMsg, 0);
            LResultWritten := True;
          end;
        finally
          SafeRelease(R^.Mtx, LConfig);
        end;
      end;
    end;
  end;

  if LStatus = tsPassed then
  begin
    { P2 fix: add RepeatCount support to parallel workers.
      Mirrors serial RunWithResult repeat logic — run test N times,
      report the last result. }
    if R^.Entry.RepeatCount > 1 then
      LRepeatCount := R^.Entry.RepeatCount
    else
      LRepeatCount := 1;
    for LRepeatI := 1 to LRepeatCount do
    begin
    { R4-04: Retry loop — mirrors serial RunWithResult retry logic }
    LTotalRetries := R^.Entry.RetryCount;
    if LTotalRetries = 0 then
      LTotalRetries := LConfig.RetryCount;
    LRetriesLeft := LTotalRetries;
    repeat
      LStatus := tsPassed;
      LFailMsg := '';
      LStart := TInstant.Now;
      try
        if (LTimeoutMs > 0) and (R^.Entry.Kind = ekTest) and
           (Assigned(R^.Entry.Proc) or Assigned(R^.Entry.Closure)) then
        begin
          { Timeout-enabled path — spawns watchdog sub-thread }
          if Assigned(R^.Entry.Closure) then
            RunTestWithTimeout(R^.Entry.Closure, LTimeoutMs,
              LConfig, LStatus, LFailMsg)
          else
            RunTestWithTimeout(R^.Entry.Proc, LTimeoutMs,
              LConfig, LStatus, LFailMsg);
        end
        else if R^.Entry.Kind = ekTableTest then
        begin
          { Table-driven test: invoke the stored proc with case data.
            Nil guard: --count=N re-runs the suite after CleanupTableAllocations
            has disposed TableCase/TableProc. Skip gracefully on re-run. }
          if (R^.Entry.TableCase = nil) or (R^.Entry.TableProc = nil) then
          begin
            LStatus := tsSkipped;
            LSkipReason := 'table data already disposed (--count re-run)';
          end
          else
            PTestCaseProc(R^.Entry.TableProc)^(PTestCase(R^.Entry.TableCase)^);
        end
        else if R^.Entry.Kind = ekShouldFail then
        begin
          RunShouldFailEntry(R^.Entry, LStatus, LFailMsg);
          if LStatus = tsSkipped then
            LSkipReason := LFailMsg;
        end
        else if Assigned(R^.Entry.Closure) then
          R^.Entry.Closure()
        else
          R^.Entry.Proc;
      except
        on E: Exception do
        begin
          ClassifyTestException(E, LStatus, LFailMsg);
          if LStatus = tsSkipped then
            LSkipReason := LFailMsg;
        end;
      end;

      if (LStatus = tsPassed) or (LStatus = tsSkipped) or (LRetriesLeft <= 0) then
        Break;

      { Retry: print hint (within mutex) and loop }
      Dec(LRetriesLeft);
      R^.Mtx.Acquire;
      try
        WriteRetryHint(LTotalRetries - LRetriesLeft,
          LTotalRetries, LOutSink, LConfig);
      finally
        SafeRelease(R^.Mtx, LConfig);
      end;
    until False;
    end; { end repeat loop }
  end;

  { R4-03: AfterEach always runs, even when BeforeEach skipped/failed }
  if Assigned(R^.After) or Assigned(R^.AfterClosure) then
  begin
    try
      if Assigned(R^.After) then R^.After else R^.AfterClosure();
    except
      on E: Exception do
      begin
        MutexWarn(R, 'afterEach failed: ' + E.Message, LErrSink, LConfig);
        if LStatus = tsPassed then
        begin
          LStatus := tsError;
          LFailMsg := 'afterEach failed: ' + E.Message;
        end;
      end;
    end;
  end;

  { EachCleanups: LIFO cleanup, runs even on failure }
  if Length(R^.EachCleanups) > 0 then
  begin
    for LCIdx := High(R^.EachCleanups) downto 0 do
    begin
      try
        R^.EachCleanups[LCIdx]();
      except
        on E: Exception do
        begin
          MutexWarn(R, 'cleanup failed: ' + E.Message, LErrSink, LConfig);
        end;
      end;
    end;
  end;

  { SoftFail: flip pass→fail before mutex counter update }
  ApplySoftFails(LStatus, LFailMsg);

  R^.Mtx.Acquire;
  try
    IncByStatus(LStatus, R^.Pass^, R^.Fail^, R^.Skip^);
    { Progress counter — increment and format prefix }
    LDurMs := LStart.Elapsed.AsMilliseconds;
    LProgressPrefix := '';
    if R^.ProgressCounter <> nil then
    begin
      R^.ProgressCounter^ := R^.ProgressCounter^ + 1;
      if R^.ProgressTotal > 0 then
        LProgressPrefix := '[' + IntToStr(R^.ProgressCounter^) + '/' +
          IntToStr(R^.ProgressTotal) + '] ';
    end;
    WriteTestOutput(LStatus, LProgressPrefix + R^.Entry.Name,
      LFailMsg, LSkipReason, LDurMs, LOutSink, LConfig);
    { P2 #11 fix: auto-print captured log on failure/error in parallel mode.
      Matches serial runner behavior (runner.pas:1363-1365). }
    if (LSubCtx <> nil) and (Length(LSubCtx.FLogLines) > 0) and
       (LStatus in [tsFailed, tsError]) then
      WriteCapturedLog(LSubCtx.FLogLines, LOutSink, LConfig);
    { Write per-test result inside mutex for safety (skip if already written
      by beforeEach failure path, which sets Duration = 0 directly) }
    if (R^.Res <> nil) and (not LResultWritten) then
    begin
      if LStatus = tsSkipped then
        R^.Res^ := MakeTestResult(R^.Entry.Name, LStatus,
          LSkipReason, LDurMs)
      else if LStatus in [tsFailed, tsError] then
      begin
        R^.Res^ := MakeTestResult(R^.Entry.Name, LStatus,
          LFailMsg, LDurMs);
        { P2 #11 fix: populate CapturedLog for parallel tests on failure/error.
          Without this, parallel test failures lose all diagnostic output from Ctx.Log. }
        if (LSubCtx <> nil) and (Length(LSubCtx.FLogLines) > 0) then
          R^.Res^.CapturedLog := LSubCtx.FLogLines;
      end
      else
        R^.Res^ := MakeTestResult(R^.Entry.Name, LStatus,
          '', LDurMs);
      LResultWritten := True;
    end;
  finally
    SafeRelease(R^.Mtx, LConfig);
  end;

  finally
    { P0 #1 fix: release TTestContext BEFORE GExecState.
      TTestContext destructor calls RunCleanups, which may indirectly
      access GExecState via InternalFail/SetTestContext.

      P2 fix: wrap in try-except to prevent cleanup EAccessViolation from
      propagating to the outer except handler, which would double-count the
      test as both pass and fail. For ekTableTest, LSubCtx stays nil
      (explicitly initialized at function entry). }
    try
      SetCurrentTestContext(nil);
      { FIX-A1: the context lives only in a plain object var here — no
        interface reference was ever taken, so `LSubCtx := nil` cannot free
        it. Destroy explicitly (refcount is 0, no interface owner). }
      LSubCtx.Free;
      LSubCtx := nil;
    except
      { Swallow cleanup errors — the test result is already committed. }
    end;
    { FIX-A2: dispose GExecState INSIDE this finally. Statements placed
      after this finally's `end` do NOT run during exception unwinding,
      so every raising test leaked its GExecState here. }
    if GExecState <> nil then
    begin
      Dispose(GExecState);
      GExecState := nil;
    end;
  end;
  except
    { Top-level catch: prevent worker thread exceptions from crashing the process.
      This is a safety net for intermittent race conditions in thread teardown. }
    on E: Exception do
    begin
      if R <> nil then
      begin
        R^.Mtx.Acquire;
        try
          R^.Fail^ := R^.Fail^ + 1;
          LOutSink.WriteLn(
            '  ' + FormatStatusLine(tsError, R^.Entry.Name, LConfig));
          LOutSink.WriteLn('    ' + AnsiDim(
            'worker exception: ' + FormatExceptionMsg(E), LConfig));
        finally
          SafeRelease(R^.Mtx, LConfig);
        end;
        if R^.Res <> nil then
          R^.Res^ := MakeTestResult(R^.Entry.Name, tsError,
            'worker exception: ' + FormatExceptionMsg(E), 0);
      end;
    end;
  end;
end;

end.
