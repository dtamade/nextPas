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
  out AStatus: TTestStatus; out AMsg: string): Boolean;
function RunTestWithTimeout(AClosure: TTestClosure; ATimeoutMs: Integer;
  out AStatus: TTestStatus; out AMsg: string): Boolean;

{ ── Parallel thread worker (internal) ──────────────────────────────────────── }

type
  TThreadRec = record
    Entry          : TTestEntry;
    SuiteName      : string;
    Mtx            : IMutex;
    Before         : TTestProc;
    BeforeClosure  : TTestClosure;
    After          : TTestProc;
    AfterClosure   : TTestClosure;
    Pass           : PInteger;
    Fail           : PInteger;
    Skip           : PInteger;
    Res            : ^TTestResult; { non-nil -> write per-test result here }
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
      R^.ErrorMsg := E.ClassName + ': ' + E.Message;
      WriteBarrier;
      R^.Done := True;
    end;
  end;
  { Main thread always joins and disposes the record — no dispose here. }
end;

function RunTestWithTimeout_internal(AProc: TTestProc; AClosure: TTestClosure;
  ATimeoutMs: Integer;
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
    WriteLn(StdErr, 'WARNING: timed-join failed after worker completed — handle detached');
  end
  else
  begin
    { Truly stuck worker — timed join also expired. Detach and warn.
      LRec will leak because we can't safely access it after detach. }
    AStatus := tsError;
    AMsg := 'test timed out after ' + IntToStr(ATimeoutMs) + 'ms';
    Result := False;
    platform_thread_detach(LHandle);
    WriteLn('  ', AnsiYellow('WARNING'), ': test timed out after ',
      ATimeoutMs, 'ms — worker thread stuck, detached (LRec leaked)');
  end;
  if LJoinResult = 0 then
    Dispose(LRec);
end;

function RunTestWithTimeout(AProc: TTestProc; ATimeoutMs: Integer;
  out AStatus: TTestStatus; out AMsg: string): Boolean;
begin
  Result := RunTestWithTimeout_internal(AProc, nil, ATimeoutMs, AStatus, AMsg);
end;

function RunTestWithTimeout(AClosure: TTestClosure; ATimeoutMs: Integer;
  out AStatus: TTestStatus; out AMsg: string): Boolean;
begin
  Result := RunTestWithTimeout_internal(nil, AClosure, ATimeoutMs, AStatus, AMsg);
end;

{ ═════════════════════════════════════════════════════════════════════════════ }
{ Parallel thread worker                                                        }
{ ═════════════════════════════════════════════════════════════════════════════ }

{ Safe mutex release — suppresses intermittent EPERM from ERRORCHECK mutex
  under heavy thread contention. The test result is already committed before
  Release, so swallowing this error is safe. }
procedure SafeRelease(const AMtx: IMutex);
begin
  try
    AMtx.Release;
  except
    on E: Exception do
    begin
      { Suppress: ERRORCHECK mutex may return EPERM under rare contention.
        The critical section data is already committed. }
      WriteLn(StdErr, 'SafeRelease: ', E.Message);
    end;
  end;
end;

function ParallelWorkerProc(AArg: Pointer): Pointer; cdecl;
var
  R: PThreadRec;
  LStatus: TTestStatus;
  LFailMsg: string;
  LSkipReason: string;
  LStartMs: Int64;
  LResultWritten: Boolean;
  LRetriesLeft: Integer;
  LSkippedByBeforeEach: Boolean;
  LTimeoutMs: Integer;
begin
  Result := nil;
  R := PThreadRec(AArg);
  LStatus := tsPassed;
  LFailMsg := '';
  LSkipReason := '';
  LStartMs := 0;
  LResultWritten := False;
  LSkippedByBeforeEach := False;
  LTimeoutMs := GetTestTimeout;
  try
  SetTestContext(R^.SuiteName, R^.Entry.Name);
  try

  { Subtests are not supported in parallel mode — skip gracefully }
  if R^.Entry.Kind = ekSubtest then
  begin
    R^.Mtx.Acquire;
    try
      R^.Skip^ := R^.Skip^ + 1;
      WriteLn('  ', StatusDot(tsSkipped), ' ', AnsiDim(R^.Entry.Name),
        ' -- subtests not supported in parallel mode');
    finally
      SafeRelease(R^.Mtx);
    end;
    if R^.Res <> nil then
    begin
      R^.Res^.Name     := R^.Entry.Name;
      R^.Res^.Status   := tsSkipped;
      R^.Res^.Message  := 'subtests not supported in parallel mode';
      R^.Res^.Duration := 0;
    end;
    Exit;
  end;

  if R^.Entry.Kind = ekSkipped then
  begin
    R^.Mtx.Acquire;
    try
      R^.Skip^ := R^.Skip^ + 1;
      WriteLn('  ', StatusDot(tsSkipped), ' ', AnsiDim(R^.Entry.Name));
    finally
      SafeRelease(R^.Mtx);
    end;
    if R^.Res <> nil then
    begin
      R^.Res^.Name     := R^.Entry.Name;
      R^.Res^.Status   := tsSkipped;
      R^.Res^.Message  := R^.Entry.SkipReason;
      R^.Res^.Duration := 0;
    end;
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
          WriteLn('  ', StatusDot(tsError), ' ', R^.Entry.Name,
            ' -- beforeEach failed: ', E.Message);
          { Set Duration to 0 directly — no test ran, don't use GetTickCount64 }
          if R^.Res <> nil then
          begin
            R^.Res^.Name     := R^.Entry.Name;
            R^.Res^.Status   := tsError;
            R^.Res^.Duration := 0;
            R^.Res^.Message  := E.Message;
            LResultWritten := True;
          end;
        finally
          SafeRelease(R^.Mtx);
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
          begin
            if RunTestWithTimeout(R^.Entry.Closure, LTimeoutMs,
              LStatus, LFailMsg) then
            begin
              if LStatus = tsPassed then { ok }
              else { LStatus already set }
            end
            else
              { Timed out — LStatus already set to tsError };
          end
          else
          begin
            if RunTestWithTimeout(R^.Entry.Proc, LTimeoutMs,
              LStatus, LFailMsg) then
            begin
              if LStatus = tsPassed then { ok }
              else { LStatus already set }
            end
            else
              { Timed out — LStatus already set to tsError };
          end;
        end
        else if R^.Entry.Kind = ekTableTest then
          PTestCaseProc(R^.Entry.TableProc)^(PTestCase(R^.Entry.TableCase)^)
        else if Assigned(R^.Entry.Closure) then
          R^.Entry.Closure()
        else
          R^.Entry.Proc;
      except
        on E: ETestSkipped do
        begin
          LStatus := tsSkipped;
          LSkipReason := E.Message;
        end;
        on E: EAssertionFailed do
        begin
          LStatus := tsFailed;
          LFailMsg := E.Message;
        end;
        on E: Exception do
        begin
          LStatus := tsError;
          LFailMsg := E.ClassName + ': ' + E.Message;
        end;
      end;

      if (LStatus = tsPassed) or (LStatus = tsSkipped) or (LRetriesLeft <= 0) then
        Break;

      { Retry: print hint (within mutex) and loop }
      Dec(LRetriesLeft);
      R^.Mtx.Acquire;
      try
        WriteLn('  ', AnsiYellow('retrying'), ' (',
          R^.Entry.RetryCount - LRetriesLeft, '/', R^.Entry.RetryCount, ')...');
      finally
        SafeRelease(R^.Mtx);
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
          WriteLn('  ', AnsiYellow('WARNING afterEach failed: '), E.Message);
        finally
          SafeRelease(R^.Mtx);
        end;
        if LStatus = tsPassed then
        begin
          LStatus := tsError;
          LFailMsg := 'afterEach failed: ' + E.Message;
        end;
      end;
    end;
  end;

  R^.Mtx.Acquire;
  try
    case LStatus of
      tsPassed:
        begin
          R^.Pass^ := R^.Pass^ + 1;
          WriteLn('  ', StatusDot(tsPassed), ' ', R^.Entry.Name);
        end;
      tsFailed:
        begin
          R^.Fail^ := R^.Fail^ + 1;
          WriteLn('  ', StatusDot(tsFailed), ' ', AnsiRed(R^.Entry.Name));
          if LFailMsg <> '' then
            WriteLn('    ', AnsiDim(LFailMsg))
          else
            WriteLn('    ', AnsiDim('(assertion failed)'));
        end;
      tsSkipped:
        begin
          R^.Skip^ := R^.Skip^ + 1;
          if LSkipReason <> '' then
            WriteLn('  ', StatusDot(tsSkipped), ' ', AnsiDim(R^.Entry.Name),
              ' -- ', LSkipReason)
          else
            WriteLn('  ', StatusDot(tsSkipped), ' ', AnsiDim(R^.Entry.Name));
        end;
      tsError:
        begin
          R^.Fail^ := R^.Fail^ + 1;
          WriteLn('  ', StatusDot(tsError), ' ', AnsiRed(R^.Entry.Name));
          if LFailMsg <> '' then
            WriteLn('    ', AnsiDim(LFailMsg));
        end;
    end;
    { Write per-test result inside mutex for safety (skip if already written
      by beforeEach failure path, which sets Duration = 0 directly) }
    if (R^.Res <> nil) and (not LResultWritten) then
    begin
      R^.Res^.Name     := R^.Entry.Name;
      R^.Res^.Status   := LStatus;
      R^.Res^.Duration := GetTickCount64 - LStartMs;
      case LStatus of
        tsSkipped: R^.Res^.Message := LSkipReason;
        tsFailed:  R^.Res^.Message := LFailMsg;
        tsError:   R^.Res^.Message := LFailMsg;
      else
        R^.Res^.Message := '';
      end;
    end;
  finally
    SafeRelease(R^.Mtx);
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
          WriteLn('  ', StatusDot(tsError), ' ', AnsiRed(R^.Entry.Name));
          WriteLn('    ', AnsiDim('worker exception: ' + E.ClassName + ': ' + E.Message));
        finally
          SafeRelease(R^.Mtx);
        end;
        if R^.Res <> nil then
        begin
          R^.Res^.Name     := R^.Entry.Name;
          R^.Res^.Status   := tsError;
          R^.Res^.Message  := 'worker exception: ' + E.ClassName + ': ' + E.Message;
          R^.Res^.Duration := 0;
        end;
      end;
    end;
  end;
end;

end.
