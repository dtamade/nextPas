{ nextpas.core.test.runner — TTestSuite, TTestRunner, parallel execution
  =========================================================
  Depends on: nextpas.core.test.base, nextpas.core.test.check, nextpas.core.test.output,
              nextpas.core.test.runner.context, nextpas.core.test.runner.parallel }

unit nextpas.core.test.runner;

{$I nextpas.core.settings.inc}

interface

uses
  SysUtils,          { Exception — FPC built-in, irreplaceable }
  nextpas.core.text.conv,
  nextpas.core.test.base,
  nextpas.core.test.check,
  nextpas.core.test.output,
  nextpas.core.atomic,
  nextpas.core.sync,
  nextpas.core.thread.base,
  nextpas.core.thread.intf,
  nextpas.core.collections.base,
  nextpas.core.platform.thread,
  nextpas.core.time.cpu;

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
    { Heap-allocated stubs from DiscoverTests — disposed by CleanupTableAllocations.
      Stores GStubRegistry indices for O(1) cleanup (R4-10).
      Raw pointers because discovery.pas uses PMethodStub which runner.pas cannot see. }
    StubAllocations: specialize TArray<Integer>;
    { R6-05: GFixtureRegistry indices for fixtures registered by DiscoverTests.
      Freed by CleanupTableAllocations when suite runs, or by finalization if not. }
    FixtureAllocations: specialize TArray<Integer>;
    { Cached run results — set by Run/RunParallel }
    LastRunPassed: Boolean;
    HasRun       : Boolean;
    LastPass     : Integer;
    LastFail     : Integer;
    LastSkip     : Integer;

    class function Create(const AName: string): TTestSuite; static;
    procedure Test(const AName: string; AProc: TTestProc); overload;
    procedure Test(const AName: string; AProc: TTestClosure); overload;
    { Retry overloads: ARetryCount > 0 retries that many times before failing }
    procedure Test(const AName: string; AProc: TTestProc;
      ARetryCount: Integer); overload;
    procedure Test(const AName: string; AProc: TTestClosure;
      ARetryCount: Integer); overload;
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
      { Note: APool is currently unused — parallel mode uses BeginThread directly
        to ensure FPC properly initializes per-thread state. Reserved for future
        thread pool integration. }
    function  RunParallelWithResult(APool: IThreadPool;
      out AResult: TTestRunResult): Boolean;
    procedure Summary;
    function  AllPassed: Boolean;
    { Free heap-allocated table test pointers (TableCase, TableProc) }
    procedure CleanupTableAllocations;
    { Shared helpers for RunWithResult/RunParallelWithResult (R4-03) }
    function  RunSetup(out ASkipCount: Integer;
                out AErrorMsg: string): Boolean;
    procedure RunTeardown;
    procedure FinalizeResults(var AResult: TTestRunResult;
                APass, AFail, ASkip: Integer);
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
    procedure Add(const ASuite: TTestSuite);
    function  RunAll: Boolean;
    function  RunAllWithResult(
      out AResults: specialize TArray<TTestRunResult>): Boolean;
    function  RunAllParallel(APool: IThreadPool): Boolean;
    function  RunAllParallelWithResult(APool: IThreadPool;
      out AResults: specialize TArray<TTestRunResult>): Boolean;
    procedure Summary;
    function  AllPassed: Boolean;
  end;

{ Register a heap-allocated method stub for later disposal.
  Adds to both the suite's per-instance list and a global safety-net registry. }
procedure RegisterStub(var ASuite: TTestSuite; APtr: Pointer);
{ R6-05: Register a fixture object for safety-net disposal.
  Records the GFixtureRegistry index in the suite for cleanup.
  Only call once per fixture (from DiscoverTests). }
procedure RegisterFixture(var ASuite: TTestSuite; AFixture: TObject);

implementation

uses
  nextpas.core.test.runner.context,
  nextpas.core.test.runner.parallel;

{ Global registry of all heap-allocated method stubs from DiscoverTests.
  Stubs are disposed here in finalization as a safety net for suites that
  are created but never run (and thus never call CleanupTableAllocations).
  R6-08: NOT thread-safe — all access must be from the main thread only. }
var
  GStubRegistry: specialize TArray<Pointer>;
  { Parallel array tracking fixture objects from DiscoverTests.
    Only non-nil for stubs registered by discovery. Freed in finalization
    as safety net for suites that are created but never run.
    R6-08: NOT thread-safe — all access must be from the main thread only. }
  GFixtureRegistry: specialize TArray<TObject>;
  LStubCleanupI: Integer;

{ ── Command-line helpers ──────────────────────────────────────────────────── }

function ParseFilterFromArgs: string;
var
  K: Integer;
begin
  Result := '';
  for K := 1 to ParamCount do
  begin
    { Support both --filter value and --filter=value syntax }
    if Copy(ParamStr(K), 1, 9) = '--filter=' then
      Exit(Copy(ParamStr(K), 10, MaxInt));
    if (ParamStr(K) = '--filter') and (K < ParamCount) then
      Exit(ParamStr(K + 1));
  end;
end;

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
  Result.StubAllocations := nil;
  Result.FixtureAllocations := nil;
  Result.LastRunPassed := False;
  Result.HasRun        := False;
  Result.LastPass      := 0;
  Result.LastFail      := 0;
  Result.LastSkip      := 0;
end;

procedure RegisterStub(var ASuite: TTestSuite; APtr: Pointer);
  { Note: RegisterStub must be called from the main thread only.
    GStubRegistry is not thread-safe — it uses plain dynamic arrays
    with no synchronization. Current usage is safe: registration and
    cleanup both occur on the main thread during discovery and suite
    finalization. }
begin
  { Global safety-net — disposed in finalization for suites that never run }
  SetLength(GStubRegistry, Length(GStubRegistry) + 1);
  GStubRegistry[High(GStubRegistry)] := APtr;
  { Per-suite tracking — stores GStubRegistry index for O(1) cleanup (R4-10) }
  SetLength(ASuite.StubAllocations, Length(ASuite.StubAllocations) + 1);
  ASuite.StubAllocations[High(ASuite.StubAllocations)] := High(GStubRegistry);
end;

procedure RegisterFixture(var ASuite: TTestSuite; AFixture: TObject);
  { Note: RegisterFixture must be called from the main thread only.
    GFixtureRegistry is not thread-safe — it uses plain dynamic arrays
    with no synchronization. Current usage is safe: registration and
    cleanup both occur on the main thread during discovery and suite
    finalization. }
begin
  { Global safety-net — disposed in finalization for suites that never run }
  SetLength(GFixtureRegistry, Length(GFixtureRegistry) + 1);
  GFixtureRegistry[High(GFixtureRegistry)] := AFixture;
  { Per-suite tracking — stores GFixtureRegistry index for O(1) cleanup }
  SetLength(ASuite.FixtureAllocations, Length(ASuite.FixtureAllocations) + 1);
  ASuite.FixtureAllocations[High(ASuite.FixtureAllocations)] := High(GFixtureRegistry);
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
  LEntry.SkipReason  := '';
  LEntry.RetryCount  := 0;
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
  LEntry.RetryCount  := 0;
  SetLength(Tests, Length(Tests) + 1);
  Tests[High(Tests)] := LEntry;
end;

procedure TTestSuite.Test(const AName: string; AProc: TTestProc;
  ARetryCount: Integer);
var
  LEntry: TTestEntry;
begin
  LEntry.Name        := AName;
  LEntry.Proc        := AProc;
  LEntry.Closure     := nil;
  LEntry.SubtestProc := nil;
  LEntry.Kind        := ekTest;
  LEntry.SkipReason  := '';
  LEntry.RetryCount  := ARetryCount;
  SetLength(Tests, Length(Tests) + 1);
  Tests[High(Tests)] := LEntry;
end;

procedure TTestSuite.Test(const AName: string; AProc: TTestClosure;
  ARetryCount: Integer);
var
  LEntry: TTestEntry;
begin
  LEntry.Name        := AName;
  LEntry.Proc        := nil;
  LEntry.Closure     := AProc;
  LEntry.SubtestProc := nil;
  LEntry.Kind        := ekTest;
  LEntry.SkipReason  := '';
  LEntry.RetryCount  := ARetryCount;
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
  LEntry.RetryCount  := 0;
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
    LEntry.RetryCount := 0;
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
  LEntry.RetryCount  := 0;
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
  LRetriesLeft: Integer;
  LStartMs: Int64;
begin
  AResult := TTestRunResult.Create(Name);
  LPass := 0;
  LFail := 0;
  LSkip := 0;
  LLastFailMsg := '';
  LAppender := TTestResultAppender.Create;
  LGTestTimeoutMs := GetTestTimeout;
  try

  WriteLn;
  WriteLn(AnsiBold('> ') + AnsiCyan(Name) +
    AnsiDim(' (' + IntToStr(Length(Tests)) + ' tests)'));

  { Suite-level setup (uses shared helper) }
  if not RunSetup(LSkip, LLastFailMsg) then
  begin
    { All tests skipped — populate results with skipped entries }
    for I := 0 to High(Tests) do
    begin
      LTestResult.Name     := Tests[I].Name;
      LTestResult.Status   := tsSkipped;
      LTestResult.Message  := 'setup failed: ' + LLastFailMsg;
      LTestResult.Duration := 0;
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
    WriteLn(AnsiDim('  ') + IntToStr(LSkip) + ' skipped (setup failure)');
    Exit;
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
      Continue;
    end;

    { Skip check BEFORE BeforeEach — skipped tests don't need hooks }
    if LEntry.Kind = ekSkipped then
    begin
      LStatus := tsSkipped;
      Inc(LSkip);
      LTestResult.Status   := tsSkipped;
      LTestResult.Message  := LEntry.SkipReason;
      LTestResult.Duration := 0;
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
          LTestResult.Status   := tsSkipped;
          LTestResult.Message  := E.Message;
          LTestResult.Duration := 0;
          SetLength(AResult.Results, Length(AResult.Results) + 1);
          AResult.Results[High(AResult.Results)] := LTestResult;
          WriteLn('  ', StatusDot(tsSkipped), ' ', AnsiDim(LEntry.Name),
            ' -- ', E.Message);
          ReportLeakIfAny(LStatus);
          Continue;
        end;
        on E: Exception do
        begin
          LStatus := tsError;
          LLastFailMsg := E.Message;
          LTestResult.Status   := tsError;
          LTestResult.Message  := 'beforeEach failed: ' + E.Message;
          LTestResult.Duration := 0;
          SetLength(AResult.Results, Length(AResult.Results) + 1);
          AResult.Results[High(AResult.Results)] := LTestResult;
          WriteLn('  ', StatusDot(tsError), ' ', LEntry.Name,
            ' -- beforeEach failed: ', E.Message);
          Inc(LFail);
          Continue;
        end;
      end;
    end;

    LStartMs := GetTickCount64;
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
        { Run with retry support: if test fails and retries remain, re-run. }
        LRetriesLeft := LEntry.RetryCount;
        repeat
          LStatus := tsPassed;
          LLastFailMsg := '';
          try
            if (LGTestTimeoutMs > 0) and (LEntry.Kind = ekTest) and Assigned(LEntry.Proc) then
            begin
              { Timeout-enabled path — runs in watchdog thread (only for TTestProc) }
              if RunTestWithTimeout(LEntry.Proc, LGTestTimeoutMs, LStatus, LLastFailMsg) then
              begin
                if LStatus = tsPassed then { ok }
                else { LStatus already set }
              end
              else
                { Timed out — LStatus already set to tsError };
            end
            else
            begin
              if Assigned(LEntry.Closure) then
                LEntry.Closure()
              else
                LEntry.Proc;
            end;
          except
            on E: ETestSkipped do
            begin
              LStatus := tsSkipped;
              LLastFailMsg := E.Message;
            end;
            on E: EAssertionFailed do
            begin
              LStatus := tsFailed;
              LLastFailMsg := E.Message;
            end;
            on E: Exception do
            begin
              LStatus := tsError;
              LLastFailMsg := E.ClassName + ': ' + E.Message;
            end;
          end;

          if (LStatus = tsPassed) or (LStatus = tsSkipped) or (LRetriesLeft <= 0) then
            Break;

          { Retry: print hint and loop }
          Dec(LRetriesLeft);
          WriteLn('  ', AnsiYellow('retrying'), ' (',
            LEntry.RetryCount - LRetriesLeft, '/', LEntry.RetryCount, ')...');
        until False;

        if LStatus = tsPassed then Inc(LPass)
        else if LStatus = tsSkipped then Inc(LSkip)
        else Inc(LFail);
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
            { R6-04 analysis: ekSubtest AfterEach failure is intentionally
              non-fatal (design decision). Subtests use LAppender for result
              collection and do not Inc(LPass) at the parent level, so
              Dec(LPass) would underflow. Inc(LFail) alone would also be
              inconsistent. Keeping this as WARNING-only matches the contract
              tested by test_subtests: 'subtest AfterEach failure should be
              non-fatal'. }
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
    LTestResult.Status   := LStatus;
    LTestResult.Message  := LLastFailMsg;
    LTestResult.Duration := GetTickCount64 - LStartMs;
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
  { Suite-level teardown (uses shared helper) }
  RunTeardown;

  { Merge subtest-level results from appender }
  for J := 0 to High(LAppender.Results) do
  begin
    SetLength(AResult.Results, Length(AResult.Results) + 1);
    AResult.Results[High(AResult.Results)] := LAppender.Results[J];
  end;

  finally
    LAppender.Free;
  end;

  FinalizeResults(AResult, LPass, LFail, LSkip);
  Result := LastRunPassed;
end;

function TTestSuite.RunParallel(APool: IThreadPool): Boolean;
var
  LResult: TTestRunResult;
begin
  Result := RunParallelWithResult(APool, LResult);
end;

{ Wrapper to adapt ParallelWorkerProc (cdecl, returns Pointer) to
  BeginThread's expected signature (register, returns PtrInt).
  On x86-64 Linux calling conventions are compatible — both pass arg in
  RDI and return in RAX. }
function ParallelThreadEntry(AArg: Pointer): PtrInt;
begin
  ParallelWorkerProc(AArg);
  Result := 0;
end;

{ TODO: RunWithResult and RunParallelWithResult share setup-failure, teardown,
  result-counting, and HasRun/LastRunPassed-update logic.  Extract shared
  helpers (e.g. RunSetup, RunTeardown, FinalizeResults) to reduce duplication.
  R4-03: setup/teardown/finalize helpers now extracted below. }

function TTestSuite.RunSetup(out ASkipCount: Integer;
  out AErrorMsg: string): Boolean;
{ Runs suite-level setup. Returns True on success, False on exception.
  On failure, prints the error and sets ASkipCount/AErrorMsg for the caller. }
begin
  Result := True;
  ASkipCount := 0;
  AErrorMsg := '';
  if not (Assigned(Setup) or Assigned(SetupClosure)) then
    Exit;
  try
    if Assigned(Setup) then Setup else SetupClosure();
  except
    on E: Exception do
    begin
      WriteLn('  ', AnsiRed('X setup failed: ') + E.Message);
      ASkipCount := Length(Tests);
      AErrorMsg := E.Message;
      Result := False;
    end;
  end;
end;

procedure TTestSuite.RunTeardown;
begin
  if not (Assigned(Teardown) or Assigned(TeardownClosure)) then
    Exit;
  try
    if Assigned(Teardown) then Teardown else TeardownClosure();
  except
    on E: Exception do
      WriteLn('  ', AnsiYellow('WARNING teardown error: ') + E.Message);
  end;
  { R4-12: Nil-out after execution to prevent double-free if the same
    suite is run twice on the same runner (e.g. fixture teardown that frees
    an object). Without this, the second run would call the closure again
    on an already-freed object. }
  Teardown := nil;
  TeardownClosure := nil;
end;

procedure TTestSuite.FinalizeResults(
  var AResult: TTestRunResult; APass, AFail, ASkip: Integer);
begin
  CleanupTableAllocations;
  AResult.Passed    := APass;
  AResult.Failed    := AFail;
  AResult.Skipped   := ASkip;
  AResult.AllPassed := AFail = 0;
  HasRun        := True;
  LastRunPassed := AResult.AllPassed;
  LastPass      := APass;
  LastFail      := AFail;
  LastSkip      := ASkip;
  WriteLn(AnsiDim('  ') +
    IntToStr(APass) + ' passed, ' +
    IntToStr(AFail) + ' failed, ' +
    IntToStr(ASkip) + ' skipped');
end;

function TTestSuite.RunParallelWithResult(APool: IThreadPool;
  out AResult: TTestRunResult): Boolean;
var
  LTotal: Integer;
  LPass, LFail, LSkip: Integer;
  LMtx: IMutex;
  I: Integer;
  LErrorMsg: string;
  LRecs: array of TThreadRec;
  LThreads: array of TThreadID;
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

  { Suite-level setup (serial, uses shared helper) }
  if not RunSetup(LSkip, LErrorMsg) then
  begin
    for I := 0 to High(Tests) do
      WriteLn('    ', StatusDot(tsSkipped), ' ', AnsiDim(Tests[I].Name));
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

  SetLength(LThreads, LTotal);
  SetLength(LRecs, LTotal);
  SetLength(LResults, LTotal);

  { Pre-fill records — each thread gets its own result slot }
  for I := 0 to High(Tests) do
  begin
    { Test filter — skip non-matching tests silently (same as serial mode:
      filtered tests are invisible, not counted as pass/fail/skip) }
    if (GetTestFilter <> '') and not MatchesFilter(Tests[I].Name) then
    begin
      LThreads[I] := 0;  { no thread for this slot — also marks filter-excluded }
      Continue;
    end;

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
    { Subtest/ekSkipped results and counters are handled entirely by the worker
      to avoid double-counting. See ParallelWorkerProc. }
  end;

  { Use BeginThread to ensure FPC properly initializes per-thread state
    (exception handler chain, threadvar TLS, heap manager).
    Previously platform_thread_create (direct pthread_create) was used,
    which bypasses FPC init and caused intermittent SIGSEGV on thread exit. }
  for I := 0 to High(Tests) do
  begin
    { Skip filtered-out tests — LRecs[I] is uninitialized for them }
    if (GetTestFilter <> '') and not MatchesFilter(Tests[I].Name) then
    begin
      LThreads[I] := 0;
      Continue;
    end;
    LThreads[I] := BeginThread(@ParallelThreadEntry, @LRecs[I]);
    if LThreads[I] = 0 then
    begin
      LResults[I].Name     := Tests[I].Name;
      LResults[I].Status   := tsError;
      LResults[I].Message  := 'BeginThread failed';
      LResults[I].Duration := 0;
      Inc(LFail);
    end;
  end;

  for I := 0 to High(Tests) do
    if LThreads[I] <> 0 then
      WaitForThreadTerminate(LThreads[I], 0);

  { Close thread handles — required on Windows to avoid kernel handle leak }
  for I := 0 to High(Tests) do
    if LThreads[I] <> 0 then
      CloseThread(LThreads[I]);

  { Suite-level teardown (uses shared helper) }
  RunTeardown;

  { Collect results from threads that actually ran.
    Filter-excluded slots have LThreads[I]=0 and no result data.
    BeginThread-failed slots also have LThreads[I]=0 but have result data
    written directly (tsError + 'BeginThread failed'). }
  for I := 0 to High(Tests) do
    if (LThreads[I] <> 0) or (LResults[I].Status <> tsPassed) or
       (LResults[I].Name <> '') then
    begin
      SetLength(AResult.Results, Length(AResult.Results) + 1);
      AResult.Results[High(AResult.Results)] := LResults[I];
    end;

  FinalizeResults(AResult, LPass, LFail, LSkip);
  Result := LastRunPassed;
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

{ Nil-out a specific pointer value in a dynamic array (for double-free prevention) }
procedure NilPointerInArray(var AArr: specialize TArray<Pointer>; APtr: Pointer);
var
  I: Integer;
begin
  for I := 0 to High(AArr) do
    if AArr[I] = APtr then
    begin
      AArr[I] := nil;
      Exit;
    end;
end;

procedure TTestSuite.CleanupTableAllocations;
  { Note: Must be called from the main thread only. Accesses GStubRegistry
    and GFixtureRegistry which are not thread-safe. Current usage is safe:
    called from FinalizeResults which runs on the main thread after all
    parallel worker threads have joined. }
var
  I: Integer;
begin
  for I := 0 to High(Tests) do
  begin
    if Tests[I].Kind = ekTableTest then
    begin
      if Tests[I].TableCase <> nil then
      begin
        Dispose(PTestCase(Tests[I].TableCase));
        Tests[I].TableCase := nil;
      end;
      if Tests[I].TableProc <> nil then
      begin
        Dispose(PTestCaseProc(Tests[I].TableProc));
        Tests[I].TableProc := nil;
      end;
    end;
  end;
  { Dispose heap-allocated method stubs from DiscoverTests.
    R4-10: StubAllocations stores GStubRegistry indices for O(1) cleanup. }
  for I := 0 to High(StubAllocations) do
    if GStubRegistry[StubAllocations[I]] <> nil then
    begin
      FreeMem(GStubRegistry[StubAllocations[I]]);
      GStubRegistry[StubAllocations[I]] := nil;
    end;
  StubAllocations := nil;
  { R6-05: Dispose fixture objects registered by DiscoverTests.
    Nil-out in GFixtureRegistry to prevent finalization double-free. }
  for I := 0 to High(FixtureAllocations) do
    if GFixtureRegistry[FixtureAllocations[I]] <> nil then
    begin
      GFixtureRegistry[FixtureAllocations[I]].Free;
      GFixtureRegistry[FixtureAllocations[I]] := nil;
    end;
  FixtureAllocations := nil;
  StubAllocations := nil;
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

procedure TTestRunner.Add(const ASuite: TTestSuite);
  { const avoids copying the entire record on the call side (same as var for
    structured types). Internally the suite IS copied into Suites[] via Pascal
    assignment. Mutations to the caller's ASuite after Add() are NOT visible
    to the runner. Rule: register ALL tests before calling Add. }
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
  { Auto-detect --filter from command line if not already set programmatically }
  if GetTestFilter = '' then
    SetTestFilter(ParseFilterFromArgs);

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

finalization
  { Safety net: dispose any method stubs and fixture objects that were not
    cleaned up by CleanupTableAllocations (e.g. suites created but never run). }
  for LStubCleanupI := 0 to High(GStubRegistry) do
  begin
    if GStubRegistry[LStubCleanupI] <> nil then
      FreeMem(GStubRegistry[LStubCleanupI]);
    if LStubCleanupI <= High(GFixtureRegistry) then
      if GFixtureRegistry[LStubCleanupI] <> nil then
        GFixtureRegistry[LStubCleanupI].Free;
  end;
  GStubRegistry := nil;
  GFixtureRegistry := nil;

end.
