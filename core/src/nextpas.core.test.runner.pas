{ nextpas.core.test.runner — TTestSuite, TTestRunner, parallel execution
  =========================================================
  Depends on: nextpas.core.test.types, nextpas.core.test.check, nextpas.core.test.output }

unit nextpas.core.test.runner;

{$I nextpas.core.settings.inc}

interface

uses
  SysUtils,
  Classes,
  nextpas.core.test.types,
  nextpas.core.test.check,
  nextpas.core.test.output,
  nextpas.core.atomic,
  nextpas.core.sync,
  nextpas.core.thread.base,
  nextpas.core.thread.intf,
  nextpas.core.collections.base,
  nextpas.core.platform.thread;

{ ── Test Suite ────────────────────────────────────────────────────────────── }

type
  TTestSuite = record
    Name      : string;
    Tests     : specialize TArray<TTestEntry>;
    Setup     : TTestProc;
    Teardown  : TTestProc;
    BeforeEach: TTestProc;
    AfterEach : TTestProc;
    { Cached run results — set by Run/RunParallel }
    LastRunPassed: Boolean;
    HasRun       : Boolean;
    LastPass     : Integer;
    LastFail     : Integer;
    LastSkip     : Integer;

    class function Create(const AName: string): TTestSuite; static;
    procedure Test(const AName: string; AProc: TTestProc);
    procedure TestSubtest(const AName: string; AProc: TSubtestProc);
    procedure Skip(const AName: string; const AReason: string = '');
    procedure SetSetup(AProc: TTestProc);
    procedure SetTeardown(AProc: TTestProc);
    procedure OnBeforeEach(AProc: TTestProc);
    procedure OnAfterEach(AProc: TTestProc);
    function  Run: Boolean;
    function  RunWithResult(out AResult: TTestRunResult): Boolean;
    function  RunParallel(APool: IThreadPool): Boolean;
      { Note: APool is currently unused — parallel mode uses direct platform_thread_create
        to work around FPC closure capture semantics. Reserved for future thread pool integration. }
    function  RunParallelWithResult(APool: IThreadPool;
      out AResult: TTestRunResult): Boolean;
    procedure Summary;
    function  AllPassed: Boolean;
  end;

{ ── Test Runner (multi-suite) ─────────────────────────────────────────────── }

  TTestRunner = record
    Name     : string;
    Suites   : specialize TArray<TTestSuite>;
    TotalPass: Integer;
    TotalFail: Integer;
    TotalSkip: Integer;
    HasRun   : Boolean;

    class function Create(const AName: string): TTestRunner; static;
    procedure Add(var ASuite: TTestSuite);
    function  RunAll: Boolean;
    function  RunAllWithResult(
      out AResults: specialize TArray<TTestRunResult>): Boolean;
    function  RunAllParallel(APool: IThreadPool): Boolean;
    function  RunAllParallelWithResult(APool: IThreadPool;
      out AResults: specialize TArray<TTestRunResult>): Boolean;
    procedure Summary;
    function  AllPassed: Boolean;
  end;

implementation

{ ═════════════════════════════════════════════════════════════════════════════ }
{ TTestResultAppender (for subtest result collection)                          }
{ ═════════════════════════════════════════════════════════════════════════════ }

type
  TTestResultAppender = class
  private
    FResults: specialize TArray<TTestResult>;
  public
    procedure Append(const AResult: TTestResult);
  end;

procedure TTestResultAppender.Append(const AResult: TTestResult);
begin
  SetLength(FResults, Length(FResults) + 1);
  FResults[High(FResults)] := AResult;
end;

{ ═════════════════════════════════════════════════════════════════════════════ }
{ TTestContext (internal, for subtests)                                        }
{ ═════════════════════════════════════════════════════════════════════════════ }

type
  TTestContext = class;

  TOnSubtestResult = procedure(const AResult: TTestResult) of object;

  TTestContext = class(TInterfacedObject, ITestContext)
  private
    FTestName : string;
    FSubtests : specialize TArray<TTestEntry>;
    FSubPass  : Integer;
    FSubFail  : Integer;
    FSubSkip  : Integer;
    FOnResult : TOnSubtestResult;
  public
    constructor Create(const ATestName: string);
    procedure Run(const AName: string; AProc: TTestProc);
    procedure RunNested(const AName: string; AProc: Pointer);
    procedure Fail(const AMessage: string);
    procedure Skip(const AReason: string = '');
    function  GetTestName: string;
    procedure ExecuteSubtests;
  end;

constructor TTestContext.Create(const ATestName: string);
begin
  inherited Create;
  FTestName := ATestName;
  FSubPass  := 0;
  FSubFail  := 0;
  FSubSkip  := 0;
  FOnResult := nil;
end;

procedure TTestContext.Run(const AName: string; AProc: TTestProc);
var
  LEntry: TTestEntry;
begin
  LEntry.Name        := FTestName + '/' + AName;
  LEntry.Proc        := AProc;
  LEntry.SubtestProc := nil;
  LEntry.Kind        := ekTest;
  LEntry.SkipReason  := '';
  SetLength(FSubtests, Length(FSubtests) + 1);
  FSubtests[High(FSubtests)] := LEntry;
end;

procedure TTestContext.RunNested(const AName: string; AProc: Pointer);
var
  LEntry: TTestEntry;
begin
  LEntry.Name        := FTestName + '/' + AName;
  LEntry.Proc        := nil;
  LEntry.SubtestProc := TSubtestProc(AProc);
  LEntry.Kind        := ekSubtest;
  LEntry.SkipReason  := '';
  SetLength(FSubtests, Length(FSubtests) + 1);
  FSubtests[High(FSubtests)] := LEntry;
end;

procedure TTestContext.Fail(const AMessage: string);
begin
  InternalFail(AMessage);
end;

procedure TTestContext.Skip(const AReason: string);
begin
  InternalSkip(AReason);
end;

function TTestContext.GetTestName: string;
begin
  Result := FTestName;
end;

procedure TTestContext.ExecuteSubtests;
var
  I: Integer;
  LEntry: TTestEntry;
  LStatus: TTestStatus;
  LMsg: string;
  LSubCtx: TTestContext;
  LSubCtxI: ITestContext;
  LTestResult: TTestResult;
begin
  for I := 0 to High(FSubtests) do
  begin
    LEntry := FSubtests[I];
    LStatus := tsPassed;
    LMsg    := '';
    SetTestContext(GExecState^.SuiteName, LEntry.Name);
    try
      if LEntry.Kind = ekSkipped then
      begin
        LStatus := tsSkipped;
        LMsg    := LEntry.SkipReason;
        WriteLn('    ', StatusDot(tsSkipped), ' ', AnsiDim(LEntry.Name),
          ' -- ', LEntry.SkipReason);
        Inc(FSubSkip);
      end
      else if LEntry.Kind = ekSubtest then
      begin
        LSubCtx := TTestContext.Create(LEntry.Name);
        LSubCtx.FOnResult := FOnResult; { propagate result callback }
        LSubCtxI := LSubCtx;
        LEntry.SubtestProc(LSubCtxI);
        LSubCtx.ExecuteSubtests;
        { Aggregate nested subtest counts into parent }
        Inc(FSubPass, LSubCtx.FSubPass);
        Inc(FSubFail, LSubCtx.FSubFail);
        Inc(FSubSkip, LSubCtx.FSubSkip);
      end
      else
      begin
        LEntry.Proc;
        WriteLn('    ', StatusDot(tsPassed), ' ', LEntry.Name);
        Inc(FSubPass);
      end;
    except
      on E: ETestSkipped do
      begin
        LStatus := tsSkipped;
        LMsg    := E.Message;
        WriteLn('    ', StatusDot(tsSkipped), ' ', AnsiDim(LEntry.Name));
        Inc(FSubSkip);
      end;
      on E: EAssertionFailed do
      begin
        LStatus := tsFailed;
        LMsg    := E.Message;
        WriteLn('    ', StatusDot(tsFailed), ' ', AnsiRed(LEntry.Name));
        WriteLn('      ', AnsiDim(E.Message));
        Inc(FSubFail);
      end;
      on E: Exception do
      begin
        LStatus := tsError;
        LMsg    := E.ClassName + ': ' + E.Message;
        WriteLn('    ', StatusDot(tsError), ' ', AnsiRed(LEntry.Name),
          ' [', E.ClassName, ']');
        WriteLn('      ', AnsiDim(E.Message));
        Inc(FSubFail);
      end;
    end;
    ReportLeakIfAny(LStatus);
    { Collect subtest result via callback if caller requested it }
    if (LEntry.Kind <> ekSubtest) and Assigned(FOnResult) then
    begin
      LTestResult.Name    := LEntry.Name;
      LTestResult.Status  := LStatus;
      LTestResult.Message := LMsg;
      FOnResult(LTestResult);
    end;
  end;
  { Propagate subtest failures to parent }
  if FSubFail > 0 then
    InternalFail(IntToStr(FSubFail) + ' subtest(s) failed in ' + FTestName);
end;

{ ═════════════════════════════════════════════════════════════════════════════ }
{ Timeout worker (internal)                                                    }
{ ═════════════════════════════════════════════════════════════════════════════ }

type
  TTimeoutRec = record
    Proc    : TTestProc;
    Done    : Boolean;
    TimedOut: Boolean;
    ErrorMsg: string;
  end;
  PTimeoutRec = ^TTimeoutRec;

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
end;

function RunTestWithTimeout(AProc: TTestProc; ATimeoutMs: Integer;
  out AStatus: TTestStatus; out AMsg: string): Boolean;
{ Returns True if test completed (pass/fail/error/skip).
  Returns False if timed out (AStatus = tsError, AMsg = 'timeout'). }
var
  LRec: TTimeoutRec;
  LHandle: TPlatformThreadHandle;
  LRetVal: Pointer;
  LElapsed: Integer;
begin
  LRec.Proc := AProc;
  LRec.Done := False;
  LRec.TimedOut := False;
  LRec.ErrorMsg := '';

  platform_thread_create(LHandle, @TimeoutWorker, @LRec);

  { Poll with sleep — cross-platform via platform_thread_sleep_ns }
  LElapsed := 0;
  while (LElapsed < ATimeoutMs) and (not LRec.Done) do
  begin
    platform_thread_sleep_ns(10 * 1000 * 1000); { 10 ms }
    Inc(LElapsed, 10);
  end;

  if LRec.Done then
  begin
    { Test completed — determine status from error prefix }
    platform_thread_join(LHandle, LRetVal);
    if LRec.ErrorMsg = '' then
    begin
      AStatus := tsPassed;
      AMsg := '';
    end
    else if LRec.ErrorMsg[1] = #1 then
    begin
      AStatus := tsSkipped;
      AMsg := Copy(LRec.ErrorMsg, 2, MaxInt);
    end
    else if LRec.ErrorMsg[1] = #2 then
    begin
      AStatus := tsError;
      AMsg := Copy(LRec.ErrorMsg, 2, MaxInt);
    end
    else
    begin
      AStatus := tsFailed;
      AMsg := LRec.ErrorMsg;
    end;
    Result := True;
  end
  else
  begin
    { Timed out — thread is still running (cannot kill) }
    AStatus := tsError;
    AMsg := 'test timed out after ' + IntToStr(ATimeoutMs) + 'ms';
    Result := False;
    { Note: worker thread is leaked — cannot force-terminate Pascal threads.
      This is a known limitation documented in the API. }
  end;
end;

{ ═════════════════════════════════════════════════════════════════════════════ }
{ TTestSuite                                                                   }
{ ═════════════════════════════════════════════════════════════════════════════ }

class function TTestSuite.Create(const AName: string): TTestSuite;
begin
  Result.Name       := AName;
  Result.Tests      := nil;
  Result.Setup      := nil;
  Result.Teardown   := nil;
  Result.BeforeEach := nil;
  Result.AfterEach  := nil;
  Result.LastRunPassed := False;
  Result.HasRun        := False;
  Result.LastPass      := 0;
  Result.LastFail      := 0;
  Result.LastSkip      := 0;
end;

procedure TTestSuite.Test(const AName: string; AProc: TTestProc);
var
  LEntry: TTestEntry;
begin
  LEntry.Name        := AName;
  LEntry.Proc        := AProc;
  LEntry.SubtestProc := nil;
  LEntry.Kind        := ekTest;
  LEntry.SkipReason := '';
  SetLength(Tests, Length(Tests) + 1);
  Tests[High(Tests)] := LEntry;
end;

procedure TTestSuite.TestSubtest(const AName: string; AProc: TSubtestProc);
var
  LEntry: TTestEntry;
begin
  LEntry.Name        := AName;
  LEntry.Proc        := nil;
  LEntry.SubtestProc := AProc;
  LEntry.Kind        := ekSubtest;
  LEntry.SkipReason  := '';
  SetLength(Tests, Length(Tests) + 1);
  Tests[High(Tests)] := LEntry;
end;

procedure TTestSuite.Skip(const AName: string; const AReason: string);
var
  LEntry: TTestEntry;
begin
  LEntry.Name        := AName;
  LEntry.Proc        := nil;
  LEntry.SubtestProc := nil;
  LEntry.Kind        := ekSkipped;
  LEntry.SkipReason  := AReason;
  SetLength(Tests, Length(Tests) + 1);
  Tests[High(Tests)] := LEntry;
end;

procedure TTestSuite.SetSetup(AProc: TTestProc);
begin
  Setup := AProc;
end;

procedure TTestSuite.SetTeardown(AProc: TTestProc);
begin
  Teardown := AProc;
end;

procedure TTestSuite.OnBeforeEach(AProc: TTestProc);
begin
  BeforeEach := AProc;
end;

procedure TTestSuite.OnAfterEach(AProc: TTestProc);
begin
  AfterEach := AProc;
end;

function TTestSuite.Run: Boolean;
var
  LResult: TTestRunResult;
begin
  Result := RunWithResult(LResult);
end;

function TTestSuite.RunWithResult(out AResult: TTestRunResult): Boolean;
var
  I, J: Integer;
  LEntry: TTestEntry;
  LStatus: TTestStatus;
  LSubCtx: TTestContext;
  LSubCtxI: ITestContext;
  LPass, LFail, LSkip: Integer;
  LLastFailMsg: string;
  LTestResult: TTestResult;
  LAppender: TTestResultAppender;
  LGTestTimeoutMs: Integer;
begin
  AResult := TTestRunResult.Create(Name);
  LPass := 0;
  LFail := 0;
  LSkip := 0;
  LLastFailMsg := '';
  LAppender := TTestResultAppender.Create;
  LGTestTimeoutMs := GetTestTimeout;

  WriteLn;
  WriteLn(AnsiBold('> ') + AnsiCyan(Name) +
    AnsiDim(' (' + IntToStr(Length(Tests)) + ' tests)'));

  { Suite-level setup }
  if Assigned(Setup) then
  begin
    try
      Setup;
    except
      on E: Exception do
      begin
        WriteLn('  ', AnsiRed('X setup failed: ') + E.Message);
        { All tests skipped }
        for I := 0 to High(Tests) do
        begin
          Inc(LSkip);
          LTestResult.Name    := Tests[I].Name;
          LTestResult.Status  := tsSkipped;
          LTestResult.Message := 'setup failed: ' + E.Message;
          SetLength(AResult.Results, Length(AResult.Results) + 1);
          AResult.Results[High(AResult.Results)] := LTestResult;
          WriteLn('    ', StatusDot(tsSkipped), ' ', AnsiDim(Tests[I].Name));
        end;
        AResult.Failed    := 1;
        AResult.Skipped   := LSkip;
        AResult.AllPassed := False;
        HasRun        := True;
        LastRunPassed := False;
        LastPass      := 0;
        LastFail      := 1;
        LastSkip      := LSkip;
        Result         := False;
        LAppender.Free;
        WriteLn(AnsiDim('  ') + IntToStr(LSkip) + ' skipped (setup failure)');
        Exit;
      end;
    end;
  end;

  for I := 0 to High(Tests) do
  begin
    LEntry := Tests[I];
    LStatus := tsPassed;
    LTestResult.Name    := LEntry.Name;
    LTestResult.Message := '';
    SetTestContext(Name, LEntry.Name);

    { Test filter — skip non-matching tests silently }
    if (GetTestFilter <> '') and not MatchesFilter(LEntry.Name) then
    begin
      { Not counted as pass/fail/skip — just invisible }
      LTestResult.Name    := LEntry.Name;
      LTestResult.Status  := tsSkipped;
      LTestResult.Message := 'filtered out';
      SetLength(AResult.Results, Length(AResult.Results) + 1);
      AResult.Results[High(AResult.Results)] := LTestResult;
      Inc(LSkip);
      Continue;
    end;

    { Skip check BEFORE BeforeEach — skipped tests don't need hooks }
    if LEntry.Kind = ekSkipped then
    begin
      LStatus := tsSkipped;
      Inc(LSkip);
      LTestResult.Status  := tsSkipped;
      LTestResult.Message := LEntry.SkipReason;
      SetLength(AResult.Results, Length(AResult.Results) + 1);
      AResult.Results[High(AResult.Results)] := LTestResult;
      if LEntry.SkipReason <> '' then
        WriteLn('  ', StatusDot(tsSkipped), ' ', AnsiDim(LEntry.Name),
          ' -- ', LEntry.SkipReason)
      else
        WriteLn('  ', StatusDot(tsSkipped), ' ', AnsiDim(LEntry.Name));
      ReportLeakIfAny(LStatus);
      Continue;
    end;

    { BeforeEach (only for non-skipped tests) }
    if Assigned(BeforeEach) then
    begin
      try
        BeforeEach;
      except
        on E: ETestSkipped do
        begin
          LStatus := tsSkipped;
          Inc(LSkip);
          LTestResult.Status  := tsSkipped;
          LTestResult.Message := E.Message;
          SetLength(AResult.Results, Length(AResult.Results) + 1);
          AResult.Results[High(AResult.Results)] := LTestResult;
          WriteLn('  ', StatusDot(tsSkipped), ' ', AnsiDim(LEntry.Name),
            ' -- ', E.Message);
          Continue;
        end;
        on E: Exception do
        begin
          LStatus := tsError;
          LLastFailMsg := E.Message;
          LTestResult.Status  := tsError;
          LTestResult.Message := 'beforeEach failed: ' + E.Message;
          SetLength(AResult.Results, Length(AResult.Results) + 1);
          AResult.Results[High(AResult.Results)] := LTestResult;
          WriteLn('  ', StatusDot(tsError), ' ', LEntry.Name,
            ' -- beforeEach failed: ', E.Message);
          Inc(LFail);
          Continue;
        end;
      end;
    end;

    try
      if LEntry.Kind = ekSubtest then
      begin
        LSubCtx := TTestContext.Create(LEntry.Name);
        LSubCtx.FOnResult := @LAppender.Append;
        LSubCtxI := LSubCtx;
        LEntry.SubtestProc(LSubCtxI);
        try
          LSubCtx.ExecuteSubtests;
        except
          on E: EAssertionFailed do
          begin
            LStatus := tsFailed;
            LLastFailMsg := E.Message;
            Inc(LFail);
          end;
          on E: Exception do
          begin
            LStatus := tsError;
            LLastFailMsg := E.ClassName + ': ' + E.Message;
            Inc(LFail);
          end;
        end;
      end
      else
      begin
        if (LGTestTimeoutMs > 0) and (LEntry.Kind = ekTest) then
        begin
          { Timeout-enabled path — runs in watchdog thread }
          if RunTestWithTimeout(LEntry.Proc, LGTestTimeoutMs, LStatus, LLastFailMsg) then
          begin
            if LStatus = tsPassed then Inc(LPass)
            else Inc(LFail);
          end
          else
          begin
            { Timed out — LStatus already set to tsError }
            Inc(LFail);
          end;
        end
        else
        begin
          LEntry.Proc;
          Inc(LPass);
        end;
      end;
    except
      on E: ETestSkipped do
      begin
        LStatus := tsSkipped;
        Inc(LSkip);
      end;
      on E: EAssertionFailed do
      begin
        LStatus := tsFailed;
        LLastFailMsg := E.Message;
        Inc(LFail);
      end;
      on E: Exception do
      begin
        LStatus := tsError;
        LLastFailMsg := E.ClassName + ': ' + E.Message;
        Inc(LFail);
      end;
    end;

    { AfterEach }
    if Assigned(AfterEach) then
    begin
      try
        AfterEach;
      except
        on E: Exception do
        begin
          WriteLn('  ', AnsiYellow('WARNING afterEach failed: '), E.Message);
          if LStatus = tsPassed then
          begin
            LStatus := tsError;
            LLastFailMsg := 'afterEach failed: ' + E.Message;
            if LEntry.Kind <> ekSubtest then
            begin
              Inc(LFail);
              if LPass > 0 then
                Dec(LPass);
            end;
          end;
        end;
      end;
    end;

    { Record test result }
    LTestResult.Status  := LStatus;
    LTestResult.Message := LLastFailMsg;
    SetLength(AResult.Results, Length(AResult.Results) + 1);
    AResult.Results[High(AResult.Results)] := LTestResult;

    { Output per-test }
    case LStatus of
      tsPassed:
        WriteLn('  ', StatusDot(tsPassed), ' ', LEntry.Name);
      tsFailed:
        begin
          WriteLn('  ', StatusDot(tsFailed), ' ', AnsiRed(LEntry.Name));
          if LLastFailMsg <> '' then
            WriteLn('    ', AnsiDim(LLastFailMsg))
          else
            WriteLn('    ', AnsiDim('(assertion failed)'));
        end;
      tsSkipped:
        begin
          if LEntry.SkipReason <> '' then
            WriteLn('  ', StatusDot(tsSkipped), ' ', AnsiDim(LEntry.Name),
              ' -- ', LEntry.SkipReason)
          else
            WriteLn('  ', StatusDot(tsSkipped), ' ', AnsiDim(LEntry.Name));
        end;
      tsError:
        begin
          WriteLn('  ', StatusDot(tsError), ' ', AnsiRed(LEntry.Name),
            ' [unexpected exception]');
          if LLastFailMsg <> '' then
            WriteLn('    ', AnsiDim(LLastFailMsg));
        end;
    end;

    LLastFailMsg := '';
    ReportLeakIfAny(LStatus);
  end;

  { Suite-level teardown }
  if Assigned(Teardown) then
  begin
    try
      Teardown;
    except
      on E: Exception do
        WriteLn('  ', AnsiYellow('WARNING teardown error: ') + E.Message);
    end;
  end;

  { Merge subtest-level results from appender }
  for J := 0 to High(LAppender.FResults) do
  begin
    SetLength(AResult.Results, Length(AResult.Results) + 1);
    AResult.Results[High(AResult.Results)] := LAppender.FResults[J];
  end;
  LAppender.Free;

  AResult.Passed    := LPass;
  AResult.Failed    := LFail;
  AResult.Skipped   := LSkip;
  AResult.AllPassed := LFail = 0;

  HasRun        := True;
  LastRunPassed := AResult.AllPassed;
  LastPass      := LPass;
  LastFail      := LFail;
  LastSkip      := LSkip;
  Result         := LastRunPassed;
  WriteLn(AnsiDim('  ') +
    IntToStr(LPass) + ' passed, ' +
    IntToStr(LFail) + ' failed, ' +
    IntToStr(LSkip) + ' skipped');
end;

{ ── Parallel thread worker (unit-level for CDecl compatibility) ───────────── }

type
  TThreadRec = record
    Entry     : TTestEntry;
    SuiteName : string;
    Mtx       : IMutex;
    Before    : TTestProc;
    After     : TTestProc;
    Pass      : PInteger;
    Fail      : PInteger;
    Skip      : PInteger;
    Res       : ^TTestResult; { non-nil -> write per-test result here }
  end;
  PThreadRec = ^TThreadRec;

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
  SetTestContext(R^.SuiteName, R^.Entry.Name);

  { Subtests are not supported in parallel mode — skip gracefully }
  if R^.Entry.Kind = ekSubtest then
  begin
    R^.Mtx.Acquire;
    try
      R^.Skip^ := R^.Skip^ + 1;
      WriteLn('  ', StatusDot(tsSkipped), ' ', AnsiDim(R^.Entry.Name),
        ' -- subtests not supported in parallel mode');
    finally
      R^.Mtx.Release;
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
      R^.Mtx.Release;
    end;
    Exit;
  end;

  if Assigned(R^.Before) then
  begin
    try R^.Before;
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
          R^.Mtx.Release;
        end;
      end;
    end;
  end;

  if LStatus = tsPassed then
  begin
    try
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

  if Assigned(R^.After) then
  begin
    try
      R^.After;
    except
      on E: Exception do
      begin
        R^.Mtx.Acquire;
        try
          WriteLn('  ', AnsiYellow('WARNING afterEach failed: '), E.Message);
        finally
          R^.Mtx.Release;
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
  finally
    R^.Mtx.Release;
  end;
  { Write per-test result if caller requested it }
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

  if GExecState <> nil then
  begin
    Dispose(GExecState);
    GExecState := nil;
  end;
end;

function TTestSuite.RunParallel(APool: IThreadPool): Boolean;
var
  LResult: TTestRunResult;
begin
  Result := RunParallelWithResult(APool, LResult);
end;

function TTestSuite.RunParallelWithResult(APool: IThreadPool;
  out AResult: TTestRunResult): Boolean;
var
  LTotal: Integer;
  LPass, LFail, LSkip: Integer;
  LMtx: IMutex;
  I: Integer;
  LRecs: array of TThreadRec;
  LHandles: array of TPlatformThreadHandle;
  LRetVal: Pointer;
  LResults: array of TTestResult;
begin
  AResult := TTestRunResult.Create(Name);
  LTotal := Length(Tests);
  LPass := 0;
  LFail := 0;
  LSkip := 0;
  LMtx := Mutex();

  WriteLn;
  WriteLn(AnsiBold('> ') + AnsiCyan(Name) +
    AnsiDim(' (' + IntToStr(LTotal) + ' tests, parallel)'));

  { Suite-level setup (serial) }
  if Assigned(Setup) then
  begin
    try
      Setup;
    except
      on E: Exception do
      begin
        WriteLn('  ', AnsiRed('X setup failed: ') + E.Message);
        for I := 0 to High(Tests) do
        begin
          Inc(LSkip);
          WriteLn('    ', StatusDot(tsSkipped), ' ', AnsiDim(Tests[I].Name));
        end;
        AResult.Failed    := 1;
        AResult.Skipped   := LSkip;
        AResult.AllPassed := False;
        HasRun        := True;
        LastRunPassed := False;
        LastPass      := 0;
        LastFail      := 1;
        LastSkip      := LSkip;
        Result         := False;
        WriteLn(AnsiDim('  ') + IntToStr(LSkip) + ' skipped (setup failure)');
        Exit;
      end;
    end;
  end;

  SetLength(LHandles, LTotal);
  SetLength(LRecs, LTotal);
  SetLength(LResults, LTotal);

  { Pre-fill records — each thread gets its own result slot }
  for I := 0 to High(Tests) do
  begin
    LRecs[I].Entry     := Tests[I];
    LRecs[I].SuiteName := Name;
    LRecs[I].Mtx       := LMtx;
    LRecs[I].Before    := BeforeEach;
    LRecs[I].After     := AfterEach;
    LRecs[I].Pass      := @LPass;
    LRecs[I].Fail      := @LFail;
    LRecs[I].Skip      := @LSkip;
    LRecs[I].Res       := @LResults[I];
  end;

  for I := 0 to High(Tests) do
    platform_thread_create(LHandles[I], @ParallelWorkerProc, @LRecs[I]);

  for I := 0 to High(Tests) do
    platform_thread_join(LHandles[I], LRetVal);

  { Suite-level teardown }
  if Assigned(Teardown) then
  begin
    try
      Teardown;
    except
      on E: Exception do
        WriteLn('  ', AnsiYellow('WARNING teardown error: ') + E.Message);
    end;
  end;

  { Collect results from all threads }
  SetLength(AResult.Results, LTotal);
  for I := 0 to High(Tests) do
    AResult.Results[I] := LResults[I];

  AResult.Passed    := LPass;
  AResult.Failed    := LFail;
  AResult.Skipped   := LSkip;
  AResult.AllPassed := LFail = 0;

  HasRun        := True;
  LastRunPassed := AResult.AllPassed;
  LastPass      := LPass;
  LastFail      := LFail;
  LastSkip      := LSkip;
  Result         := LastRunPassed;
  WriteLn(AnsiDim('  ') +
    IntToStr(LPass) + ' passed, ' +
    IntToStr(LFail) + ' failed, ' +
    IntToStr(LSkip) + ' skipped');
end;

procedure TTestSuite.Summary;
begin
  if not HasRun then
  begin
    WriteLn(AnsiYellow('Warning: ') + Name + ' has not been run yet');
    Exit;
  end;
  WriteLn(AnsiBold('--- ') + AnsiCyan(Name) + AnsiBold(' ---'));
  WriteLn('  Total tests: ', Length(Tests));
  WriteLn('  Passed: ', LastPass, ', Failed: ', LastFail, ', Skipped: ', LastSkip);
end;

function TTestSuite.AllPassed: Boolean;
  { Returns whether all tests passed. If Run/RunParallel has not been called yet,
    this will automatically execute Run (serial mode) first. }
begin
  if not HasRun then
    Result := Run
  else
    Result := LastRunPassed;
end;

{ ═════════════════════════════════════════════════════════════════════════════ }
{ TTestRunner                                                                  }
{ ═════════════════════════════════════════════════════════════════════════════ }

class function TTestRunner.Create(const AName: string): TTestRunner;
begin
  Result.Name      := AName;
  Result.Suites    := nil;
  Result.TotalPass := 0;
  Result.TotalFail := 0;
  Result.TotalSkip := 0;
  Result.HasRun    := False;
end;

procedure TTestRunner.Add(var ASuite: TTestSuite);
  { IMPORTANT — Record value-copy semantics:
    ASuite is passed by `var` only to avoid copying the entire record on the
    call side. Internally the suite is *copied* into the Suites[] array via
    Pascal assignment (record + dynamic-array copy-on-write).
    After Add() returns, any further mutations to the caller's ASuite variable
    (e.g. appending more tests) will NOT be visible to the runner.
    Rule: register ALL tests before calling Add. }
begin
  SetLength(Suites, Length(Suites) + 1);
  Suites[High(Suites)] := ASuite;
end;

function TTestRunner.RunAll: Boolean;
var
  LResults: specialize TArray<TTestRunResult>;
begin
  Result := RunAllWithResult(LResults);
end;

function TTestRunner.RunAllParallel(APool: IThreadPool): Boolean;
var
  LResults: specialize TArray<TTestRunResult>;
begin
  Result := RunAllParallelWithResult(APool, LResults);
end;

function TTestRunner.RunAllWithResult(
  out AResults: specialize TArray<TTestRunResult>): Boolean;
var
  I: Integer;
  LAllPassed: Boolean;
  LSuiteResult: TTestRunResult;

  function ParseFilterFromArgs: string;
  var
    K: Integer;
  begin
    Result := '';
    for K := 1 to ParamCount do
      if (ParamStr(K) = '--filter') and (K < ParamCount) then
        Exit(ParamStr(K + 1));
  end;

begin
  { Auto-detect --filter from command line if not already set programmatically }
  if GetTestFilter = '' then
    SetTestFilter(ParseFilterFromArgs);

  WriteLn(AnsiBold('=== ') + AnsiBold(Name) + AnsiBold(' ==='));
  LAllPassed := True;
  TotalPass := 0;
  TotalFail := 0;
  TotalSkip := 0;
  SetLength(AResults, Length(Suites));
  for I := 0 to High(Suites) do
  begin
    if not Suites[I].RunWithResult(LSuiteResult) then
      LAllPassed := False;
    AResults[I] := LSuiteResult;
    Inc(TotalPass, Suites[I].LastPass);
    Inc(TotalFail, Suites[I].LastFail);
    Inc(TotalSkip, Suites[I].LastSkip);
  end;
  HasRun := True;
  Result := LAllPassed;
end;

function TTestRunner.RunAllParallelWithResult(APool: IThreadPool;
  out AResults: specialize TArray<TTestRunResult>): Boolean;
var
  I: Integer;
  LAllPassed: Boolean;
  LSuiteResult: TTestRunResult;
begin
  WriteLn(AnsiBold('=== ') + AnsiBold(Name) + AnsiBold(' (parallel) ==='));
  LAllPassed := True;
  TotalPass := 0;
  TotalFail := 0;
  TotalSkip := 0;
  SetLength(AResults, Length(Suites));
  for I := 0 to High(Suites) do
  begin
    if not Suites[I].RunParallelWithResult(APool, LSuiteResult) then
      LAllPassed := False;
    AResults[I] := LSuiteResult;
    Inc(TotalPass, Suites[I].LastPass);
    Inc(TotalFail, Suites[I].LastFail);
    Inc(TotalSkip, Suites[I].LastSkip);
  end;
  HasRun := True;
  Result := LAllPassed;
end;

procedure TTestRunner.Summary;
begin
  WriteLn;
  WriteLn(AnsiBold('=== Summary ==='));
  WriteLn('  Suites: ', Length(Suites));
  WriteLn('  Passed: ', TotalPass,
    ', Failed: ', TotalFail,
    ', Skipped: ', TotalSkip);
end;

function TTestRunner.AllPassed: Boolean;
begin
  if HasRun then
    Result := TotalFail = 0
  else
    Result := RunAll;
end;

end.
