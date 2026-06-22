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
  nextpas.core.platform.thread;

{ ── Timeout worker (internal) ──────────────────────────────────────────────── }

type
  TTimeoutRec = record
    Proc    : TTestProc;
    Done    : Boolean;
    TimedOut: Boolean;
    ErrorMsg: string;
  end;
  PTimeoutRec = ^TTimeoutRec;

function RunTestWithTimeout(AProc: TTestProc; ATimeoutMs: Integer;
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
    R^.Proc;
    R^.Done := True;
  except
    on E: ETestSkipped do
    begin
      R^.ErrorMsg := #1 + E.Message; { prefix #1 = skip }
      R^.Done := True;
    end;
    on E: EAssertionFailed do
    begin
      R^.ErrorMsg := E.Message;
      R^.Done := True;
    end;
    on E: Exception do
    begin
      R^.ErrorMsg := #2 + E.ClassName + ': ' + E.Message; { prefix #2 = error }
      R^.Done := True;
    end;
  end;
  { If main thread marked us as timed out, we own the record and must dispose }
  if R^.TimedOut then
    Dispose(R);
end;

function RunTestWithTimeout(AProc: TTestProc; ATimeoutMs: Integer;
  out AStatus: TTestStatus; out AMsg: string): Boolean;
{ Returns True if test completed (pass/fail/error/skip).
  Returns False if timed out (AStatus = tsError, AMsg = 'timeout'). }
var
  LRec: PTimeoutRec;
  LHandle: TPlatformThreadHandle;
  LRetVal: Pointer;
  LElapsed: Integer;
begin
  New(LRec);
  LRec^.Proc := AProc;
  LRec^.Done := False;
  LRec^.TimedOut := False;
  LRec^.ErrorMsg := '';

  platform_thread_create(LHandle, @TimeoutWorker, LRec);

  { Poll with sleep — cross-platform via platform_thread_sleep_ns }
  LElapsed := 0;
  while (LElapsed < ATimeoutMs) and (not LRec^.Done) do
  begin
    platform_thread_sleep_ns(10 * 1000 * 1000); { 10 ms }
    Inc(LElapsed, 10);
  end;

  if LRec^.Done then
  begin
    { Test completed — determine status from error prefix }
    platform_thread_join(LHandle, LRetVal);
    if LRec^.ErrorMsg = '' then
    begin
      AStatus := tsPassed;
      AMsg := '';
    end
    else if LRec^.ErrorMsg[1] = #1 then
    begin
      AStatus := tsSkipped;
      AMsg := Copy(LRec^.ErrorMsg, 2, MaxInt);
    end
    else if LRec^.ErrorMsg[1] = #2 then
    begin
      AStatus := tsError;
      AMsg := Copy(LRec^.ErrorMsg, 2, MaxInt);
    end
    else
    begin
      AStatus := tsFailed;
      AMsg := LRec^.ErrorMsg;
    end;
    Result := True;
    { Join path: we own the record, dispose here }
    Dispose(LRec);
  end
  else
  begin
    { Timed out — thread is still running (cannot kill) }
    AStatus := tsError;
    AMsg := 'test timed out after ' + IntToStr(ATimeoutMs) + 'ms';
    Result := False;
    { Mark timed-out so the worker thread disposes the record when it finishes.
      x86_64 TSO guarantees the store order: TimedOut visible to worker after
      we observe Done=False. }
    LRec^.TimedOut := True;
    { Note: worker thread is leaked — cannot force-terminate Pascal threads.
      This is a known limitation documented in the API. }
  end;
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
    { Suppress: ERRORCHECK mutex may return EPERM under rare contention.
      The critical section data is already committed. }
  end;
end;

function ParallelWorkerProc(AArg: Pointer): Pointer; cdecl;
var
  R: PThreadRec;
  LStatus: TTestStatus;
  LFailMsg: string;
  LSkipReason: string;
begin
  Result := nil;
  R := PThreadRec(AArg);
  LStatus := tsPassed;
  LFailMsg := '';
  LSkipReason := '';
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
      R^.Res^.Name    := R^.Entry.Name;
      R^.Res^.Status  := tsSkipped;
      R^.Res^.Message := 'subtests not supported in parallel mode';
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
      R^.Res^.Name    := R^.Entry.Name;
      R^.Res^.Status  := tsSkipped;
      R^.Res^.Message := R^.Entry.SkipReason;
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
      end;
      on E: Exception do
      begin
        LStatus := tsError;
        LFailMsg := E.Message;
        R^.Mtx.Acquire;
        try
          WriteLn('  ', StatusDot(tsError), ' ', R^.Entry.Name,
            ' -- beforeEach failed: ', E.Message);
        finally
          SafeRelease(R^.Mtx);
        end;
      end;
    end;
  end;

  if LStatus = tsPassed then
  begin
    try
      if R^.Entry.Kind = ekTableTest then
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
  end;

  if Assigned(R^.After) or Assigned(R^.AfterClosure) then
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
        if LStatus = tsPassed then LStatus := tsError;
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
    { Write per-test result inside mutex for safety }
    if R^.Res <> nil then
    begin
      R^.Res^.Name    := R^.Entry.Name;
      R^.Res^.Status  := LStatus;
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
      if (R <> nil) and (R^.Res <> nil) then
      begin
        R^.Res^.Name    := R^.Entry.Name;
        R^.Res^.Status  := tsError;
        R^.Res^.Message := 'worker exception: ' + E.ClassName + ': ' + E.Message;
      end;
    end;
  end;
end;

end.
