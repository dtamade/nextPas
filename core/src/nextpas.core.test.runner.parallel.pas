{ nextpas.core.test.runner.parallel — Timeout worker + parallel thread worker
  =========================================================
  Depends on: nextpas.core.test.base, nextpas.core.test.output,
              nextpas.core.platform.thread }

unit nextpas.core.test.runner.parallel;

{$I nextpas.core.settings.inc}

interface

uses
  SysUtils,          { Exception, EAbort, EAssertionFailed — FPC built-in }
  nextpas.core.text.conv,
  nextpas.core.test.base,
  nextpas.core.test.config,
  nextpas.core.test.output,
  nextpas.core.sync.intf,
  nextpas.core.platform.thread,
  nextpas.core.time.cpu;

{ ── Timeout worker (internal) ──────────────────────────────────────────────── }

type
  TTimeoutRec = record
    Proc    : TTestProc;
    Closure : TTestClosure;
    Done    : Boolean;
    ErrorMsg: string;
    Status  : TTestStatus;
  end;
  PTimeoutRec = ^TTimeoutRec;

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
    Mtx            : IMutex;
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

implementation

{ ═════════════════════════════════════════════════════════════════════════════ }
{ Timeout worker                                                                }
{ ═════════════════════════════════════════════════════════════════════════════ }

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
  Returns False if timed out (AStatus = tsError, AMsg = 'timeout'). }
var
  LRec: PTimeoutRec;
  LHandle: TPlatformThreadHandle;
  LRetVal: Pointer;
  LElapsed: Integer;
  LJoinTimeoutMs: Int64;
  LJoinResult: Int32;
begin
  New(LRec);
  LRec^.Proc := AProc;
  LRec^.Closure := AClosure;
  LRec^.Done := False;
  LRec^.ErrorMsg := '';
  LRec^.Status := tsPassed;

  platform_thread_create(LHandle, @TimeoutWorker, LRec);

  { Poll with sleep — cross-platform via platform_thread_sleep_ns }
  LElapsed := 0;
  repeat
    platform_thread_sleep_ns(10 * 1000 * 1000); { 10 ms }
    Inc(LElapsed, 10);
    { R6-07: ReadBarrier ensures we see the worker's writes to Status/ErrorMsg
      when Done becomes true. On weakly-ordered architectures (ARM/AArch64)
      the worker's WriteBarrier pairs with this ReadBarrier. }
    ReadBarrier;
  until (LElapsed >= ATimeoutMs) or LRec^.Done;

  { Secondary join timeout: after detecting a timeout, give the worker extra
    time to finish cleanup. Use max(2x original, 5s) to handle short timeouts
    where the worker might just be slow, not truly stuck. }
  if LRec^.Done then
    LJoinTimeoutMs := 5000  { normal path: 5s grace for thread teardown }
  else
  begin
    LJoinTimeoutMs := Int64(ATimeoutMs) * 2;
    if LJoinTimeoutMs < 5000 then
      LJoinTimeoutMs := 5000;
  end;

  LJoinResult := platform_thread_timedjoin(LHandle, LJoinTimeoutMs, LRetVal);

  { R6-07: ReadBarrier before reading results — join provides happens-before
    on success path, but on failure path we need an explicit barrier to see
    the worker's writes to Status/ErrorMsg/Done. }
  ReadBarrier;

  if LJoinResult = 0 then
  begin
    { Thread finished — read results and dispose }
    AStatus := LRec^.Status;
    AMsg := LRec^.ErrorMsg;
    if not LRec^.Done then
    begin
      { Worker finished but didn't set Done — unusual, treat as error }
      AStatus := tsError;
      AMsg := 'worker exited without completing';
      Result := False;
    end
    else if LElapsed >= ATimeoutMs then
    begin
      { Worker finished, but we detected a timeout first.
        Report as timeout — the test was too slow. }
      AStatus := tsError;
      AMsg := 'test timed out after ' + IntToStr(ATimeoutMs) + 'ms';
      Result := False;
    end
    else
      Result := True;
  end
  else if LRec^.Done then
  begin
    { Worker finished (Done=True) but timed join didn't complete —
      extremely unlikely; treat as success with potential stale data.
      Dispose LRec here: worker is done so no concurrent access,
      and LJoinResult ≠ 0 means the Dispose below won't run. }
    AStatus := LRec^.Status;
    AMsg := LRec^.ErrorMsg;
    Result := True;
    Dispose(LRec);
    { Detach to prevent handle leak — worker is done, thread is exiting }
    platform_thread_detach(LHandle);
    ResolveErrSink(AConfig).WriteLn(
      'WARNING: timed-join failed after worker completed - handle detached');
  end
  else
  begin
    { Truly stuck worker — timed join also expired. Detach and warn.
      LRec will leak because we can't safely access it after detach. }
    AStatus := tsError;
    AMsg := 'test timed out after ' + IntToStr(ATimeoutMs) + 'ms';
    Result := False;
    platform_thread_detach(LHandle);
    ResolveErrSink(AConfig).WriteLn(
      '  ' + AnsiYellow('WARNING', AConfig) + ': test timed out after ' +
      IntToStr(ATimeoutMs) +
      'ms - worker thread stuck, detached (LRec leaked)');
  end;
  if LJoinResult = 0 then
    Dispose(LRec);
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

function ParallelWorkerProc(AArg: Pointer): Pointer; cdecl;
var
  R: PThreadRec;
  LConfig: TTestConfig;
  LStatus: TTestStatus;
  LFailMsg: string;
  LSkipReason: string;
  LStartMs: Int64;
  LResultWritten: Boolean;
  LRetriesLeft: Integer;
  LSkippedByBeforeEach: Boolean;
  LTimeoutMs: Integer;
  LOutSink: IOutputSink;
  LErrSink: IOutputSink;
  LCIdx: Integer;
  LDurMs: Int64;
begin
  Result := nil;
  R := PThreadRec(AArg);
  LConfig := ResolveConfig(R^.Config);
  LOutSink := ResolveOutSink(LConfig);
  LErrSink := ResolveErrSink(LConfig);
  LStatus := tsPassed;
  LFailMsg := '';
  LSkipReason := '';
  LStartMs := 0;
  LResultWritten := False;
  LSkippedByBeforeEach := False;
  LTimeoutMs := GetTestTimeout(LConfig);
  try
  SetTestContext(R^.SuiteName, R^.Entry.Name);
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

  { Benchmarks: not supported in parallel mode — skip gracefully }
  if R^.Entry.Kind = ekBench then
  begin
    EmitParallelSkip(R, 'benchmarks not supported in parallel mode',
      LOutSink, LConfig);
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
        LSkippedByBeforeEach := True;
      end;
      on E: Exception do
      begin
        LStatus := tsError;
        LFailMsg := E.Message;
        R^.Mtx.Acquire;
        try
          LOutSink.WriteLn(
            '  ' + FormatStatusLine(tsError, R^.Entry.Name,
              'beforeEach failed: ' + E.Message, LConfig));
          { Set Duration to 0 directly — no test ran, don't use GetTickCount64 }
          if R^.Res <> nil then
          begin
            R^.Res^ := MakeTestResult(R^.Entry.Name, tsError, E.Message, 0);
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
    { R4-04: Retry loop — mirrors serial RunWithResult retry logic }
    LRetriesLeft := R^.Entry.RetryCount;
    repeat
      LStatus := tsPassed;
      LFailMsg := '';
      LStartMs := GetTickCount64;
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
        WriteRetryHint(R^.Entry.RetryCount - LRetriesLeft,
          R^.Entry.RetryCount, LOutSink, LConfig);
      finally
        SafeRelease(R^.Mtx, LConfig);
      end;
    until False;
  end;

  if (not LSkippedByBeforeEach) and
     (Assigned(R^.After) or Assigned(R^.AfterClosure)) then
  begin
    try
      if Assigned(R^.After) then R^.After else R^.AfterClosure();
    except
      on E: Exception do
      begin
        R^.Mtx.Acquire;
        try
          WriteWarning('afterEach failed: ' + E.Message, LErrSink, LConfig);
        finally
          SafeRelease(R^.Mtx, LConfig);
        end;
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
          R^.Mtx.Acquire;
          try
            WriteWarning('cleanup failed: ' + E.Message, LErrSink, LConfig);
          finally
            SafeRelease(R^.Mtx, LConfig);
          end;
        end;
      end;
    end;
  end;

  R^.Mtx.Acquire;
  try
    case LStatus of
      tsPassed:
        R^.Pass^ := R^.Pass^ + 1;
      tsFailed:
        R^.Fail^ := R^.Fail^ + 1;
      tsSkipped:
        R^.Skip^ := R^.Skip^ + 1;
      tsError:
        R^.Fail^ := R^.Fail^ + 1;
    end;
    { Progress counter — increment and format prefix }
    LDurMs := GetTickCount64 - LStartMs;
    if R^.ProgressCounter <> nil then
    begin
      R^.ProgressCounter^ := R^.ProgressCounter^ + 1;
      if R^.ProgressTotal > 0 then
        WriteTestOutput(LStatus,
          '[' + IntToStr(R^.ProgressCounter^) + '/' +
          IntToStr(R^.ProgressTotal) + '] ' + R^.Entry.Name,
          LFailMsg, LSkipReason, LDurMs, LOutSink, LConfig)
      else
        WriteTestOutput(LStatus, R^.Entry.Name, LFailMsg,
          LSkipReason, LDurMs, LOutSink, LConfig);
    end
    else
      WriteTestOutput(LStatus, R^.Entry.Name, LFailMsg,
        LSkipReason, LDurMs, LOutSink, LConfig);
    { Write per-test result inside mutex for safety (skip if already written
      by beforeEach failure path, which sets Duration = 0 directly) }
    if (R^.Res <> nil) and (not LResultWritten) then
    begin
      if LStatus = tsSkipped then
        R^.Res^ := MakeTestResult(R^.Entry.Name, LStatus,
          LSkipReason, LDurMs)
      else if LStatus in [tsFailed, tsError] then
        R^.Res^ := MakeTestResult(R^.Entry.Name, LStatus,
          LFailMsg, LDurMs)
      else
        R^.Res^ := MakeTestResult(R^.Entry.Name, LStatus,
          '', LDurMs);
    end;
  finally
    SafeRelease(R^.Mtx, LConfig);
  end;

  finally
    { Always dispose thread-local GExecState — even on early Exit paths
      (ekSubtest, ekSkipped) that skip the normal cleanup below. }
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
