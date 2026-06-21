{ nextpas.core.test.runner — TTestSuite, TTestRunner, parallel execution
  =========================================================
  Depends on: nextpas.core.test.base, nextpas.core.test.check, nextpas.core.test.output,
              nextpas.core.test.runner.context, nextpas.core.test.runner.parallel }

unit nextpas.core.test.runner;

{$I nextpas.core.settings.inc}

interface

uses
  SysUtils,
  Classes,
  nextpas.core.test.base,
  nextpas.core.test.check,
  nextpas.core.test.output,
  nextpas.core.test.runner.context,
  nextpas.core.test.runner.parallel,
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
    Setup       : TTestProc;
    SetupClosure: TTestClosure;
    Teardown       : TTestProc;
    TeardownClosure: TTestClosure;
    BeforeEach       : TTestProc;
    BeforeEachClosure: TTestClosure;
    AfterEach       : TTestProc;
    AfterEachClosure : TTestClosure;
    { Cached run results — set by Run/RunParallel }
    LastRunPassed: Boolean;
    HasRun       : Boolean;
    LastPass     : Integer;
    LastFail     : Integer;
    LastSkip     : Integer;

    class function Create(const AName: string): TTestSuite; static;
    procedure Test(const AName: string; AProc: TTestProc);
    procedure Test(const AName: string; AProc: TTestClosure);
    procedure TestSubtest(const AName: string; AProc: TSubtestProc);
    procedure TestTable(const AName: string;
      ACases: specialize TArray<TTestCase>;
      AProc: TTestCaseProc);
    procedure Skip(const AName: string; const AReason: string = '');
    procedure SetSetup(AProc: TTestProc);
    procedure SetSetup(AProc: TTestClosure);
    procedure SetTeardown(AProc: TTestProc);
    procedure SetTeardown(AProc: TTestClosure);
    procedure OnBeforeEach(AProc: TTestProc);
    procedure OnBeforeEach(AProc: TTestClosure);
    procedure OnAfterEach(AProc: TTestProc);
    procedure OnAfterEach(AProc: TTestClosure);
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
{ TTestSuite                                                                   }
{ ═════════════════════════════════════════════════════════════════════════════ }

class function TTestSuite.Create(const AName: string): TTestSuite;
begin
  Result.Name       := AName;
  Result.Tests      := nil;
  Result.Setup       := nil;
  Result.SetupClosure := nil;
  Result.Teardown       := nil;
  Result.TeardownClosure := nil;
  Result.BeforeEach       := nil;
  Result.BeforeEachClosure := nil;
  Result.AfterEach       := nil;
  Result.AfterEachClosure := nil;
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
  LEntry.Closure     := nil;
  LEntry.SubtestProc := nil;
  LEntry.Kind        := ekTest;
  LEntry.SkipReason := '';
  SetLength(Tests, Length(Tests) + 1);
  Tests[High(Tests)] := LEntry;
end;

procedure TTestSuite.Test(const AName: string; AProc: TTestClosure);
var
  LEntry: TTestEntry;
begin
  LEntry.Name        := AName;
  LEntry.Proc        := nil;
  LEntry.Closure     := AProc;
  LEntry.SubtestProc := nil;
  LEntry.Kind        := ekTest;
  LEntry.SkipReason  := '';
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

procedure TTestSuite.TestTable(const AName: string;
  ACases: specialize TArray<TTestCase>;
  AProc: TTestCaseProc);
var
  I: Integer;
  LEntry: TTestEntry;
  LPCase: PTestCase;
  LPProc: PTestCaseProc;
begin
  for I := 0 to High(ACases) do
  begin
    { Heap-allocate case data and proc to avoid closure capture issues }
    New(LPCase);
    LPCase^ := ACases[I];
    New(LPProc);
    LPProc^ := AProc;

    LEntry.Name       := AName + '/' + ACases[I].Name;
    LEntry.Proc       := nil;
    LEntry.SubtestProc := nil;
    LEntry.Kind       := ekTableTest;
    LEntry.SkipReason := '';
    LEntry.TableCase  := LPCase;
    LEntry.TableProc  := LPProc;
    SetLength(Tests, Length(Tests) + 1);
    Tests[High(Tests)] := LEntry;
  end;
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
  SetupClosure := nil;
end;

procedure TTestSuite.SetSetup(AProc: TTestClosure);
begin
  Setup := nil;
  SetupClosure := AProc;
end;

procedure TTestSuite.SetTeardown(AProc: TTestProc);
begin
  Teardown := AProc;
  TeardownClosure := nil;
end;

procedure TTestSuite.SetTeardown(AProc: TTestClosure);
begin
  Teardown := nil;
  TeardownClosure := AProc;
end;

procedure TTestSuite.OnBeforeEach(AProc: TTestProc);
begin
  BeforeEach := AProc;
  BeforeEachClosure := nil;
end;

procedure TTestSuite.OnBeforeEach(AProc: TTestClosure);
begin
  BeforeEach := nil;
  BeforeEachClosure := AProc;
end;

procedure TTestSuite.OnAfterEach(AProc: TTestProc);
begin
  AfterEach := AProc;
  AfterEachClosure := nil;
end;

procedure TTestSuite.OnAfterEach(AProc: TTestClosure);
begin
  AfterEach := nil;
  AfterEachClosure := AProc;
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
  if Assigned(Setup) or Assigned(SetupClosure) then
  begin
    try
      if Assigned(Setup) then Setup else SetupClosure();
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
    if Assigned(BeforeEach) or Assigned(BeforeEachClosure) then
    begin
      try
        if Assigned(BeforeEach) then BeforeEach else BeforeEachClosure();
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
      else if LEntry.Kind = ekTableTest then
      begin
        { Table-driven test: invoke the stored proc with case data }
        PTestCaseProc(LEntry.TableProc)^(PTestCase(LEntry.TableCase)^);
        Inc(LPass);
      end
      else
      begin
        if (LGTestTimeoutMs > 0) and (LEntry.Kind = ekTest) and Assigned(LEntry.Proc) then
        begin
          { Timeout-enabled path — runs in watchdog thread (only for TTestProc) }
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
          if Assigned(LEntry.Closure) then
            LEntry.Closure()
          else
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
    if Assigned(AfterEach) or Assigned(AfterEachClosure) then
    begin
      try
        if Assigned(AfterEach) then AfterEach else AfterEachClosure();
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
  if Assigned(Teardown) or Assigned(TeardownClosure) then
  begin
    try
      if Assigned(Teardown) then Teardown else TeardownClosure();
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
  if Assigned(Setup) or Assigned(SetupClosure) then
  begin
    try
      if Assigned(Setup) then Setup else SetupClosure();
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
    LRecs[I].BeforeClosure := BeforeEachClosure;
    LRecs[I].After     := AfterEach;
    LRecs[I].AfterClosure  := AfterEachClosure;
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
  if Assigned(Teardown) or Assigned(TeardownClosure) then
  begin
    try
      if Assigned(Teardown) then Teardown else TeardownClosure();
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
