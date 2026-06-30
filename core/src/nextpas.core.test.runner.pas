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
  nextpas.core.test.config,
  nextpas.core.test.output,
  nextpas.core.test.output.json,
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
    Config    : TTestConfig;
    Tests     : specialize TArray<TTestEntry>;
    Setup       : TTestProc;
    SetupClosure: TTestClosure;
    Teardown       : TTestProc;
    TeardownClosure: TTestClosure;
    BeforeEach       : TTestProc;
    BeforeEachClosure: TTestClosure;
    AfterEach       : TTestProc;
    AfterEachClosure : TTestClosure;
    EachCleanups     : specialize TArray<TTestClosure>;  { LIFO cleanup after each test }
    { Heap-allocated stubs from DiscoverTests — disposed by CleanupTableAllocations
      (FCleanupDone guard) or in finalization safety net.
      Stores GStubRegistry indices for O(1) cleanup (R4-10).
      Raw pointers because discovery.pas uses PMethodStub which runner.pas cannot see. }
    StubAllocations: specialize TArray<Integer>;
    { R6-05: GFixtureRegistry indices for fixtures registered by DiscoverTests.
      Freed by CleanupTableAllocations (FCleanupDone guard) or finalization. }
    FixtureAllocations: specialize TArray<Integer>;
    { Cached run results — set by Run/RunParallel }
    LastRunPassed: Boolean;
    HasRun       : Boolean;
    FCleanupDone : Boolean;  { prevents double-free on --count=N re-runs }
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
    { Tag overloads: ATags for tag-based filtering }
    procedure Test(const AName: string; AProc: TTestProc;
      const ATags: array of string); overload;
    procedure Test(const AName: string; AProc: TTestClosure;
      const ATags: array of string); overload;
    { DisplayName + Tags overloads }
    procedure Test(const AName: string; AProc: TTestProc;
      const ADisplayName: string; const ATags: array of string); overload;
    procedure Test(const AName: string; AProc: TTestClosure;
      const ADisplayName: string; const ATags: array of string); overload;
    { Repeat overloads: ARepeatCount > 1 runs the test N times }
    procedure TestRepeat(const AName: string; AProc: TTestProc;
      ARepeatCount: Integer);
    procedure TestRepeat(const AName: string; AProc: TTestClosure;
      ARepeatCount: Integer);
    procedure TestSubtest(const AName: string; AProc: TSubtestProc);
    procedure TestTable(const AName: string;
      ACases: specialize TArray<TTestCase>;
      AProc: TTestCaseProc);
    { ShouldFail: test passes if proc raises any exception (Rust #[should_panic]).
      AShouldFailMsg is optional reason shown in output. }
    procedure ShouldFail(const AName: string; AProc: TTestProc;
      const AShouldFailMsg: string = '');
    procedure ShouldFail(const AName: string; AProc: TTestClosure;
      const AShouldFailMsg: string = '');
    { ShortSkip: mark a test to be skipped in --short mode (Go testing.Short()).
      When ShortMode is off, the test runs normally. }
    procedure ShortSkip(const AName: string; AProc: TTestProc);
    procedure ShortSkip(const AName: string; AProc: TTestClosure);
    procedure Skip(const AName: string; const AReason: string = '');
    { Bench: register a benchmark (Go BenchmarkXxx equivalent).
      BenchProc receives PBenchContext; framework controls N iterations.
      Benches are only run when --bench is passed. }
    procedure Bench(const AName: string; AProc: TBenchProc);
    procedure SetSetup(AProc: TTestProc);
    procedure SetSetup(AProc: TTestClosure);
    procedure SetTeardown(AProc: TTestProc);
    procedure SetTeardown(AProc: TTestClosure);
    procedure OnBeforeEach(AProc: TTestProc);
    procedure OnBeforeEach(AProc: TTestClosure);
    procedure OnAfterEach(AProc: TTestProc);
    procedure OnAfterEach(AProc: TTestClosure);
    { Cleanup: register a cleanup handler that runs after each test, even on
      failure (Go t.Cleanup() equivalent). Handlers execute in LIFO order. }
    procedure Cleanup(AProc: TTestProc);
    procedure Cleanup(AProc: TTestClosure);
    function  WithConfig(const AConfig: TTestConfig): TTestSuite;
    function  WithSetup(AProc: TTestProc): TTestSuite; overload;
    function  WithSetup(AProc: TTestClosure): TTestSuite; overload;
    function  WithTeardown(AProc: TTestProc): TTestSuite; overload;
    function  WithTeardown(AProc: TTestClosure): TTestSuite; overload;
    function  WithBeforeEach(AProc: TTestProc): TTestSuite; overload;
    function  WithBeforeEach(AProc: TTestClosure): TTestSuite; overload;
    { Note: BeforeEach/AfterEach run in the same thread as the test.
      In parallel mode (RunParallel), each worker thread executes its own
      BeforeEach/AfterEach — if the closure captures shared state, the caller
      is responsible for synchronization. }
    function  WithAfterEach(AProc: TTestProc): TTestSuite; overload;
    function  WithAfterEach(AProc: TTestClosure): TTestSuite; overload;
    function  WithEachCleanup(AProc: TTestProc): TTestSuite; overload;
    function  WithEachCleanup(AProc: TTestClosure): TTestSuite; overload;
    function  Run: Boolean;
    function  RunWithResult(out AResult: TTestRunResult): Boolean;
    function  RunParallel(APool: IThreadPool): Boolean;
      { Note: APool is currently unused — parallel mode uses BeginThread directly
        to ensure FPC properly initializes per-thread state. Reserved for future
        thread pool integration. }
    function  RunParallelWithResult(APool: IThreadPool;
      out AResult: TTestRunResult): Boolean;
    function  RunBenchmarks(out AResults: TBenchResults): Boolean;
    procedure Summary;
    function  AllPassed: Boolean;
    { Dispose table test data, stubs, and fixtures. FCleanupDone guard
      prevents double-free on --count=N re-runs. }
    procedure CleanupTableAllocations;
    { Shared helpers for RunWithResult/RunParallelWithResult (R4-03) }
    function  RunSetup(const AConfig: TTestConfig; out ASkipCount: Integer;
                out AErrorMsg: string): Boolean;
    procedure RunTeardown(const AConfig: TTestConfig);
    procedure HandleSetupFailure(var AResult: TTestRunResult;
                ASkipCount: Integer; const AErrorMsg: string;
                const ASink: IOutputSink; const AConfig: TTestConfig;
                APopulateResults: Boolean);
    procedure FinalizeResults(const AConfig: TTestConfig;
                var AResult: TTestRunResult;
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
    function  RunAllBenchmarks(
      out AResults: specialize TArray<TBenchResults>): Boolean;
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
{ White-box helper for test_runner: parse --filter=value form from one argv item. }
function ParseFilter(const AArg: string): string;
{ White-box helper for test_runner: parse --tag=value form from one argv item. }
function ParseTag(const AArg: string): string;
{ Generic arg parsing primitives — all ParseXxx/IsXxxArg delegate here. }
function HasArgFlag(const AArg, AFlag1: string;
  const AFlag2: string = ''): Boolean;
function ExtractArgValue(const AArg, APrefix: string): string;
function ExtractArgIntValue(const AArg, APrefix: string;
  ADefault: Integer): Integer;
{ Check if a test entry matches a tag filter. Empty filter = match all. }
function MatchesTagFilter(const AEntryTags: specialize TArray<string>;
  const ATagFilter: string): Boolean;
{ Get effective display name: DisplayName if non-empty, else Name. }
function GetDisplayName(const AEntry: TTestEntry): string;
{ Active test context for the currently executing test. }
function Ctx: ITestContext;

implementation

uses
  nextpas.core.test.runner.context,
  nextpas.core.test.runner.parallel;

{ Global registry of all heap-allocated method stubs from DiscoverTests.
  Stubs are disposed by CleanupTableAllocations (with FCleanupDone guard)
  or in finalization as safety net for suites that are never run.
  R6-08: NOT thread-safe — all access must be from the main thread only. }
var
  GStubRegistry: specialize TArray<Pointer>;
  { Parallel array tracking fixture objects from DiscoverTests.
    Only non-nil for stubs registered by discovery. Freed in finalization
    as safety net for suites that are created but never run.
    R6-08: NOT thread-safe — all access must be from the main thread only. }
  GFixtureRegistry: specialize TArray<TObject>;
  GStubCleanupI: Integer;

threadvar
  GCurrentTestContextObj: TObject;

type
  TArgStringParser = function(const AArg: string): string;
  TArgIntParser = function(const AArg: string): Integer;
  TArgFlagChecker = function(const AArg: string): Boolean;

{ ── Command-line helpers ────────────────────────────────────────────────────── }
{ Generic arg parsing primitives — all ParseXxx/IsXxxArg functions delegate here }

function HasArgFlag(const AArg, AFlag1: string;
  const AFlag2: string = ''): Boolean;
{ Returns True if AArg equals AFlag1 or AFlag2. }
begin
  Result := (AArg = AFlag1) or ((AFlag2 <> '') and (AArg = AFlag2));
end;

function ExtractArgValue(const AArg, APrefix: string): string;
{ Returns the value portion of '--prefix=value' if AArg starts with APrefix+'='.
  Returns '' if no match. }
begin
  if Copy(AArg, 1, Length(APrefix) + 1) = APrefix + '=' then
    Result := Copy(AArg, Length(APrefix) + 2, MaxInt)
  else
    Result := '';
end;

function ExtractArgIntValue(const AArg, APrefix: string;
  ADefault: Integer): Integer;
{ Returns integer value of '--prefix=N', clamped to >= 0, or ADefault if no match. }
var
  LValue: string;
begin
  LValue := ExtractArgValue(AArg, APrefix);
  if LValue = '' then
    Exit(ADefault);
  Result := StrToIntDef(LValue, ADefault);
  if Result < 0 then
    Result := 0;
end;

{ ── Single-arg parsers (delegated to generic primitives) ───────────────────── }

function ParseFilter(const AArg: string): string;
begin
  Result := ExtractArgValue(AArg, '--filter');
end;

function ParseTag(const AArg: string): string;
begin
  Result := ExtractArgValue(AArg, '--tag');
end;

function ParseCount(const AArg: string): Integer;
begin
  Result := ExtractArgIntValue(AArg, '--count', 0);
end;

function ParseShuffleSeed(const AArg: string): Integer;
{ Returns: 0 = no shuffle, -1 = --shuffle (random), >0 = --shuffle-seed=N }
begin
  if AArg = '--shuffle' then
    Exit(-1);
  Result := ExtractArgIntValue(AArg, '--shuffle-seed', 0);
  if Result = 0 then Result := -1; { seed=0 means off, so treat 0 as -1 }
end;

function IsFailFastArg(const AArg: string): Boolean;
begin
  Result := HasArgFlag(AArg, '--failfast', '--fail-fast');
end;

function IsListArg(const AArg: string): Boolean;
begin
  Result := HasArgFlag(AArg, '--list', '--list-tests');
end;

function IsShortArg(const AArg: string): Boolean;
begin
  Result := HasArgFlag(AArg, '--short', '-short');
end;

function IsProgressArg(const AArg: string): Boolean;
begin
  Result := HasArgFlag(AArg, '--progress', '-progress');
end;

function ParseMaxFailures(const AArg: string): Integer;
begin
  Result := ExtractArgIntValue(AArg, '--failures-max', 0);
end;

function IsJsonArg(const AArg: string): Boolean;
begin
  Result := HasArgFlag(AArg, '--json', '-json');
end;

function IsVerboseArg(const AArg: string): Boolean;
begin
  Result := HasArgFlag(AArg, '--verbose', '-v');
end;

function ParseRunTimeout(const AArg: string): Integer;
begin
  Result := ExtractArgIntValue(AArg, '--timeout', 0);
end;

function IsBenchArg(const AArg: string): Boolean;
begin
  Result := (Copy(AArg, 1, 8) = '--bench');
end;

function ParseBenchPattern(const AArg: string): string;
begin
  if AArg = '--bench' then
    Exit('.');  { match all benchmarks }
  if Copy(AArg, 1, 7) = '--bench' then
  begin
    if AArg[8] = '=' then
      Exit(Copy(AArg, 9, MaxInt))
    else if AArg = '--bench' then
      Exit('.');
  end;
  Result := '';
end;

function ParseBenchTime(const AArg: string): Integer;
{ Parse --benchtime=Nms or --benchtime=Ns. Returns ms, 0 if not matched. }
var
  LVal: string;
  LNum: Integer;
begin
  if Copy(AArg, 1, 12) = '--benchtime=' then
  begin
    LVal := Copy(AArg, 13, MaxInt);
    if (Length(LVal) > 1) and (LVal[Length(LVal)] = 's') then
    begin
      LNum := StrToIntDef(Copy(LVal, 1, Length(LVal) - 1), 0);
      if LNum > 0 then Exit(LNum * 1000);
    end;
    if (Length(LVal) > 2) and (Copy(LVal, Length(LVal) - 1, 2) = 'ms') then
    begin
      LNum := StrToIntDef(Copy(LVal, 1, Length(LVal) - 2), 0);
      if LNum > 0 then Exit(LNum);
    end;
    { bare number = seconds }
    LNum := StrToIntDef(LVal, 0);
    if LNum > 0 then Exit(LNum * 1000);
  end;
  Result := 0;
end;

function IsBenchMemArg(const AArg: string): Boolean;
begin
  Result := HasArgFlag(AArg, '--benchmem', '-benchmem');
end;

procedure SetCurrentTestContext(AContext: TObject);
begin
  GCurrentTestContextObj := AContext;
end;

function Ctx: ITestContext;
begin
  if (GCurrentTestContextObj = nil) or
     (not Supports(GCurrentTestContextObj, ITestContext, Result)) then
    raise Exception.Create('No active test context');
end;

function MatchesTagFilter(const AEntryTags: specialize TArray<string>;
  const ATagFilter: string): Boolean;
{ Check if a test entry matches a tag filter.
  Empty filter = match all. Comma-separated tags = OR match.
  A test matches if it has ANY of the listed tags. }
var
  LFilter, LTag: string;
  LComma, I: Integer;
begin
  if ATagFilter = '' then
    Exit(True);
  if Length(AEntryTags) = 0 then
    Exit(False);
  LFilter := ATagFilter;
  while LFilter <> '' do
  begin
    LComma := Pos(',', LFilter);
    if LComma > 0 then
    begin
      LTag := Copy(LFilter, 1, LComma - 1);
      Delete(LFilter, 1, LComma);
    end
    else
    begin
      LTag := LFilter;
      LFilter := '';
    end;
    { Trim whitespace }
    while (LTag <> '') and (LTag[1] = ' ') do Delete(LTag, 1, 1);
    while (LTag <> '') and (LTag[Length(LTag)] = ' ') do
      SetLength(LTag, Length(LTag) - 1);
    if LTag = '' then
      Continue;
    for I := 0 to High(AEntryTags) do
      if SameText(AEntryTags[I], LTag) then
        Exit(True);
  end;
  Result := False;
end;

function GetDisplayName(const AEntry: TTestEntry): string;
begin
  if AEntry.DisplayName <> '' then
    Result := AEntry.DisplayName
  else
    Result := AEntry.Name;
end;

{ ── FromArgs helpers (iterate ParamCount once, delegate to single-arg parsers) }

function FindArgValue(
  AParseFunc: TArgStringParser;
  const ALongFlag: string
): string;
{ Generic: scan argv for --flag=value (via AParseFunc) or --flag value form. }
var
  K: Integer;
  LVal: string;
begin
  for K := 1 to ParamCount do
  begin
    LVal := AParseFunc(ParamStr(K));
    if LVal <> '' then
      Exit(LVal);
    if (ParamStr(K) = ALongFlag) and (K < ParamCount) then
      Exit(ParamStr(K + 1));
  end;
  Result := '';
end;

function FindArgInt(
  AParseFunc: TArgIntParser;
  const ALongFlag: string;
  ADefault: Integer
): Integer;
{ Generic: scan argv for --flag=N (via AParseFunc) or --flag N form. }
var
  K: Integer;
  LVal: Integer;
begin
  for K := 1 to ParamCount do
  begin
    LVal := AParseFunc(ParamStr(K));
    if LVal <> 0 then
      Exit(LVal);
    if (ParamStr(K) = ALongFlag) and (K < ParamCount) then
    begin
      Result := StrToIntDef(ParamStr(K + 1), ADefault);
      if Result < 0 then Result := 0;
      Exit;
    end;
  end;
  Result := ADefault;
end;

function FindFlagInArgs(
  AIsFlagFunc: TArgFlagChecker
): Boolean;
{ Generic: scan argv for a boolean flag. }
var
  K: Integer;
begin
  for K := 1 to ParamCount do
    if AIsFlagFunc(ParamStr(K)) then
      Exit(True);
  Result := False;
end;

function ParseFilterFromArgs: string;
begin
  Result := FindArgValue(@ParseFilter, '--filter');
end;

function ParseTagFromArgs: string;
begin
  Result := FindArgValue(@ParseTag, '--tag');
end;

function ParseCountFromArgs: Integer;
begin
  Result := FindArgInt(@ParseCount, '--count', 0);
end;

function ParseShuffleFromArgs: Integer;
var
  K: Integer;
  LSeed: Integer;
begin
  for K := 1 to ParamCount do
  begin
    LSeed := ParseShuffleSeed(ParamStr(K));
    if LSeed <> 0 then
      Exit(LSeed);
  end;
  Result := 0;
end;

function ParseFailFastFromArgs: Boolean;
begin
  Result := FindFlagInArgs(@IsFailFastArg);
end;

function ParseListFromArgs: Boolean;
begin
  Result := FindFlagInArgs(@IsListArg);
end;

function ParseShortFromArgs: Boolean;
begin
  Result := FindFlagInArgs(@IsShortArg);
end;

function ParseProgressFromArgs: Boolean;
begin
  Result := FindFlagInArgs(@IsProgressArg);
end;

function ParseMaxFailuresFromArgs: Integer;
begin
  Result := FindArgInt(@ParseMaxFailures, '--failures-max', 0);
end;

function ParseJsonFromArgs: Boolean;
begin
  Result := FindFlagInArgs(@IsJsonArg);
end;

function ParseVerboseFromArgs: Boolean;
begin
  Result := FindFlagInArgs(@IsVerboseArg);
end;

function ParseRunTimeoutFromArgs: Integer;
begin
  Result := FindArgInt(@ParseRunTimeout, '--timeout', 0);
end;

function ParseBenchFromArgs: string;
{ Returns bench pattern: '' = no bench, '.' = all, 'Foo' = match 'Foo'. }
var
  K: Integer;
begin
  for K := 1 to ParamCount do
  begin
    if IsBenchArg(ParamStr(K)) then
      Exit(ParseBenchPattern(ParamStr(K)));
    if (ParamStr(K) = '--bench') and (K < ParamCount) and
       (Copy(ParamStr(K + 1), 1, 1) <> '-') then
      Exit(ParamStr(K + 1));
  end;
  Result := '';
end;

function ParseBenchTimeFromArgs: Integer;
begin
  Result := FindArgInt(@ParseBenchTime, '--benchtime', 0);
end;

function ParseBenchMemFromArgs: Boolean;
begin
  Result := FindFlagInArgs(@IsBenchMemArg);
end;

function RunnerConfig(const ARunner: TTestRunner): TTestConfig;
begin
  if Length(ARunner.Suites) > 0 then
    Result := ResolveConfig(ARunner.Suites[0].Config)
  else
    Result := ResolveConfig(DefaultConfig);
end;

procedure ApplyCLIArgs;
{ Auto-detect CLI arguments and apply to global default config.
  Shared by RunAllWithResult and RunAllParallelWithResult. }
var
  LCount, LShuffleSeed, LMaxFail, LRunTimeout, LBenchTime: Integer;
  LBenchPattern: string;
begin
  if GetTestFilter = '' then
    SetTestFilter(ParseFilterFromArgs);
  if GetTagFilter = '' then
    SetTagFilter(ParseTagFromArgs);
  if GetRepeatAllCount(DefaultConfig) = 0 then
  begin
    LCount := ParseCountFromArgs;
    if LCount > 0 then
      SetDefaultRepeatAllCount(LCount);
  end;
  LShuffleSeed := ParseShuffleFromArgs;
  if LShuffleSeed <> 0 then
    SetDefaultShuffleSeed(LShuffleSeed);
  if ParseFailFastFromArgs then
    SetDefaultFailFast(True);
  if ParseListFromArgs then
    SetDefaultListMode(True);
  if ParseShortFromArgs then
    SetDefaultShortMode(True);
  if ParseProgressFromArgs then
    SetDefaultShowProgress(True);
  LMaxFail := ParseMaxFailuresFromArgs;
  if LMaxFail > 0 then
    SetDefaultMaxFailures(LMaxFail);
  if ParseJsonFromArgs then
    SetDefaultJsonOutput(True);
  if ParseVerboseFromArgs then
    SetDefaultVerboseMode(True);
  LRunTimeout := ParseRunTimeoutFromArgs;
  if LRunTimeout > 0 then
    SetDefaultRunTimeoutSec(LRunTimeout);
  LBenchPattern := ParseBenchFromArgs;
  if LBenchPattern <> '' then
  begin
    SetDefaultBenchEnabled(True);
    SetDefaultFilterPattern(LBenchPattern);
  end;
  LBenchTime := ParseBenchTimeFromArgs;
  if LBenchTime > 0 then
    SetDefaultBenchTimeMs(LBenchTime);
  if ParseBenchMemFromArgs then
    SetDefaultBenchMem(True);
end;

function WriteListMode(const ASuites: specialize TArray<TTestSuite>;
  const AConfig: TTestConfig; out AResults: specialize TArray<TTestRunResult>): Boolean;
{ Print test names grouped by suite without running. Returns True to indicate
  the caller should use the result directly (always True = no failures). }
var
  I, J: Integer;
  LOutSink: IOutputSink;
begin
  LOutSink := ResolveOutSink(AConfig);
  for I := 0 to High(ASuites) do
  begin
    LOutSink.WriteLn(ASuites[I].Name + ':');
    for J := 0 to High(ASuites[I].Tests) do
    begin
      if ASuites[I].Tests[J].Kind = ekSkipped then
        LOutSink.WriteLn('  ' + ASuites[I].Tests[J].Name + ' (skipped)')
      else if ASuites[I].Tests[J].Kind = ekShouldFail then
        LOutSink.WriteLn('  ' + ASuites[I].Tests[J].Name + ' (should-fail)')
      else if ASuites[I].Tests[J].ShortSkip then
        LOutSink.WriteLn('  ' + ASuites[I].Tests[J].Name + ' (short-skip)')
      else
        LOutSink.WriteLn('  ' + ASuites[I].Tests[J].Name);
    end;
  end;
  SetLength(AResults, 0);
  Result := True;
end;

{ ═════════════════════════════════════════════════════════════════════════════ }
{ TTestSuite                                                                   }
{ ═════════════════════════════════════════════════════════════════════════════ }

class function TTestSuite.Create(const AName: string): TTestSuite;
begin
  Result.Name       := AName;
  Result.Config     := DefaultConfig;
  Result.Tests      := nil;
  Result.Setup       := nil;
  Result.SetupClosure := nil;
  Result.Teardown       := nil;
  Result.TeardownClosure := nil;
  Result.BeforeEach       := nil;
  Result.BeforeEachClosure := nil;
  Result.AfterEach       := nil;
  Result.AfterEachClosure := nil;
  Result.EachCleanups    := nil;
  Result.StubAllocations := nil;
  Result.FixtureAllocations := nil;
  Result.LastRunPassed := False;
  Result.HasRun        := False;
  Result.FCleanupDone  := False;
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
var
  LIdx: Integer;
begin
  { Global safety-net — disposed in finalization for suites that never run.
    Geometric growth to avoid O(n²) realloc on repeated RegisterStub calls. }
  LIdx := GrowArrayLen(GStubRegistry, 16);
  GStubRegistry[LIdx] := APtr;
  SetLength(GStubRegistry, LIdx + 1);
  { Per-suite tracking — stores GStubRegistry index for O(1) cleanup (R4-10).
    Geometric growth: pre-allocate capacity to avoid per-registration realloc. }
  LIdx := GrowArrayLen(ASuite.StubAllocations, 8);
  ASuite.StubAllocations[LIdx] := High(GStubRegistry);
  SetLength(ASuite.StubAllocations, LIdx + 1);
end;

procedure RegisterFixture(var ASuite: TTestSuite; AFixture: TObject);
  { Note: RegisterFixture must be called from the main thread only.
    GFixtureRegistry is not thread-safe — it uses plain dynamic arrays
    with no synchronization. Current usage is safe: registration and
    cleanup both occur on the main thread during discovery and suite
    finalization. }
var
  LIdx: Integer;
begin
  { Global safety-net — disposed in finalization for suites that never run.
    Geometric growth to avoid O(n²) realloc on repeated RegisterFixture calls. }
  LIdx := GrowArrayLen(GFixtureRegistry, 16);
  GFixtureRegistry[LIdx] := AFixture;
  SetLength(GFixtureRegistry, LIdx + 1);
  { Per-suite tracking — stores GFixtureRegistry index for O(1) cleanup.
    Geometric growth to avoid per-registration realloc. }
  LIdx := GrowArrayLen(ASuite.FixtureAllocations, 8);
  ASuite.FixtureAllocations[LIdx] := High(GFixtureRegistry);
  SetLength(ASuite.FixtureAllocations, LIdx + 1);
end;

{ ── Registration helpers ────────────────────────────────────────────────────── }
{ Reduce boilerplate in Test/ShouldFail/ShortSkip overloads. Each public method
  calls InitProcEntry or InitClosureEntry, sets extra fields, then RegisterEntry. }

procedure InitProcEntry(var AEntry: TTestEntry; const AName: string;
  AProc: TTestProc);
begin
  ClearEntry(AEntry);
  AEntry.Name := AName;
  AEntry.Proc := AProc;
end;

procedure InitClosureEntry(var AEntry: TTestEntry; const AName: string;
  AProc: TTestClosure);
begin
  ClearEntry(AEntry);
  AEntry.Name := AName;
  AEntry.Closure := AProc;
end;

procedure TTestSuite.Test(const AName: string; AProc: TTestProc);
var
  LEntry: TTestEntry;
begin
  InitProcEntry(LEntry, AName, AProc);
  RegisterEntry(Tests, LEntry);
end;

procedure TTestSuite.Test(const AName: string; AProc: TTestClosure);
var
  LEntry: TTestEntry;
begin
  InitClosureEntry(LEntry, AName, AProc);
  RegisterEntry(Tests, LEntry);
end;

procedure TTestSuite.Test(const AName: string; AProc: TTestProc;
  ARetryCount: Integer);
var
  LEntry: TTestEntry;
begin
  InitProcEntry(LEntry, AName, AProc);
  LEntry.RetryCount := ARetryCount;
  RegisterEntry(Tests, LEntry);
end;

procedure TTestSuite.Test(const AName: string; AProc: TTestClosure;
  ARetryCount: Integer);
var
  LEntry: TTestEntry;
begin
  InitClosureEntry(LEntry, AName, AProc);
  LEntry.RetryCount := ARetryCount;
  RegisterEntry(Tests, LEntry);
end;

procedure TTestSuite.Test(const AName: string; AProc: TTestProc;
  const ATags: array of string);
var
  LEntry: TTestEntry;
begin
  InitProcEntry(LEntry, AName, AProc);
  CopyTags(LEntry.Tags, ATags);
  RegisterEntry(Tests, LEntry);
end;

procedure TTestSuite.Test(const AName: string; AProc: TTestClosure;
  const ATags: array of string);
var
  LEntry: TTestEntry;
begin
  InitClosureEntry(LEntry, AName, AProc);
  CopyTags(LEntry.Tags, ATags);
  RegisterEntry(Tests, LEntry);
end;

procedure TTestSuite.Test(const AName: string; AProc: TTestProc;
  const ADisplayName: string; const ATags: array of string);
var
  LEntry: TTestEntry;
begin
  InitProcEntry(LEntry, AName, AProc);
  LEntry.DisplayName := ADisplayName;
  CopyTags(LEntry.Tags, ATags);
  RegisterEntry(Tests, LEntry);
end;

procedure TTestSuite.Test(const AName: string; AProc: TTestClosure;
  const ADisplayName: string; const ATags: array of string);
var
  LEntry: TTestEntry;
begin
  InitClosureEntry(LEntry, AName, AProc);
  LEntry.DisplayName := ADisplayName;
  CopyTags(LEntry.Tags, ATags);
  RegisterEntry(Tests, LEntry);
end;

procedure TTestSuite.TestRepeat(const AName: string; AProc: TTestProc;
  ARepeatCount: Integer);
var
  LEntry: TTestEntry;
begin
  InitProcEntry(LEntry, AName, AProc);
  LEntry.RepeatCount := ARepeatCount;
  RegisterEntry(Tests, LEntry);
end;

procedure TTestSuite.TestRepeat(const AName: string; AProc: TTestClosure;
  ARepeatCount: Integer);
var
  LEntry: TTestEntry;
begin
  InitClosureEntry(LEntry, AName, AProc);
  LEntry.RepeatCount := ARepeatCount;
  RegisterEntry(Tests, LEntry);
end;

procedure TTestSuite.TestSubtest(const AName: string; AProc: TSubtestProc);
var
  LEntry: TTestEntry;
begin
  ClearEntry(LEntry);
  LEntry.Name        := AName;
  LEntry.SubtestProc := AProc;
  LEntry.Kind        := ekSubtest;
  RegisterEntry(Tests, LEntry);
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

    ClearEntry(LEntry);
    LEntry.Name      := AName + '/' + ACases[I].Name;
    LEntry.Kind      := ekTableTest;
    LEntry.TableCase := LPCase;
    LEntry.TableProc := LPProc;
    RegisterEntry(Tests, LEntry);
  end;
end;

procedure TTestSuite.Skip(const AName: string; const AReason: string);
var
  LEntry: TTestEntry;
begin
  ClearEntry(LEntry);
  LEntry.Name       := AName;
  LEntry.Kind       := ekSkipped;
  LEntry.SkipReason := AReason;
  RegisterEntry(Tests, LEntry);
end;

procedure TTestSuite.ShouldFail(const AName: string; AProc: TTestProc;
  const AShouldFailMsg: string);
var
  LEntry: TTestEntry;
begin
  InitProcEntry(LEntry, AName, AProc);
  LEntry.Kind          := ekShouldFail;
  LEntry.ShouldFailMsg := AShouldFailMsg;
  RegisterEntry(Tests, LEntry);
end;

procedure TTestSuite.ShouldFail(const AName: string; AProc: TTestClosure;
  const AShouldFailMsg: string);
var
  LEntry: TTestEntry;
begin
  InitClosureEntry(LEntry, AName, AProc);
  LEntry.Kind          := ekShouldFail;
  LEntry.ShouldFailMsg := AShouldFailMsg;
  RegisterEntry(Tests, LEntry);
end;

procedure TTestSuite.ShortSkip(const AName: string; AProc: TTestProc);
var
  LEntry: TTestEntry;
begin
  InitProcEntry(LEntry, AName, AProc);
  LEntry.ShortSkip := True;
  RegisterEntry(Tests, LEntry);
end;

procedure TTestSuite.ShortSkip(const AName: string; AProc: TTestClosure);
var
  LEntry: TTestEntry;
begin
  InitClosureEntry(LEntry, AName, AProc);
  LEntry.ShortSkip := True;
  RegisterEntry(Tests, LEntry);
end;

procedure TTestSuite.Bench(const AName: string; AProc: TBenchProc);
var
  LEntry: TTestEntry;
begin
  ClearEntry(LEntry);
  LEntry.Name     := AName;
  LEntry.Kind     := ekBench;
  LEntry.BenchProc := AProc;
  RegisterEntry(Tests, LEntry);
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

{ ── Generic array capacity growth ───────────────────────────────────────────── }

function GrowArrayLen(var AArray: specialize TArray<Pointer>; AInitCap: Integer): Integer;
{ Grow AArray capacity if needed. Returns old length (= insertion index). }
var
  LOldLen, LCap: Integer;
begin
  LOldLen := Length(AArray);
  LCap := GrowCapacity(LOldLen, AInitCap);
  if LCap <> LOldLen then SetLength(AArray, LCap);
  Result := LOldLen;
end;

function GrowArrayLen(var AArray: specialize TArray<Integer>; AInitCap: Integer): Integer;
var
  LOldLen, LCap: Integer;
begin
  LOldLen := Length(AArray);
  LCap := GrowCapacity(LOldLen, AInitCap);
  if LCap <> LOldLen then SetLength(AArray, LCap);
  Result := LOldLen;
end;

function GrowArrayLen(var AArray: specialize TArray<TTestSuite>; AInitCap: Integer): Integer;
var
  LOldLen, LCap: Integer;
begin
  LOldLen := Length(AArray);
  LCap := GrowCapacity(LOldLen, AInitCap);
  if LCap <> LOldLen then SetLength(AArray, LCap);
  Result := LOldLen;
end;

{ ── EachCleanups capacity growth helper ─────────────────────────────────────── }

function GrowEachCleanups(var ACleanups: specialize TArray<TTestClosure>): Integer;
{ Returns the index where the new element should be placed (old length). }
var
  LOldLen, LCap: Integer;
begin
  LOldLen := Length(ACleanups);
  LCap := GrowCapacity(LOldLen, 4);
  if LCap <> LOldLen then SetLength(ACleanups, LCap);
  Result := LOldLen;
end;

procedure TTestSuite.Cleanup(AProc: TTestProc);
var
  LProc: TTestProc;
  LIdx: Integer;
begin
  LProc := AProc;
  LIdx := GrowEachCleanups(EachCleanups);
  EachCleanups[LIdx] := procedure
  begin
    LProc;
  end;
  SetLength(EachCleanups, LIdx + 1);
end;

procedure TTestSuite.Cleanup(AProc: TTestClosure);
var
  LIdx: Integer;
begin
  LIdx := GrowEachCleanups(EachCleanups);
  EachCleanups[LIdx] := AProc;
  SetLength(EachCleanups, LIdx + 1);
end;

function TTestSuite.WithConfig(const AConfig: TTestConfig): TTestSuite;
begin
  Result := Self;
  Result.Config := AConfig;
end;

function TTestSuite.WithSetup(AProc: TTestProc): TTestSuite;
begin
  Result := Self;
  Result.Setup := AProc;
  Result.SetupClosure := nil;
end;

function TTestSuite.WithSetup(AProc: TTestClosure): TTestSuite;
begin
  Result := Self;
  Result.Setup := nil;
  Result.SetupClosure := AProc;
end;

function TTestSuite.WithTeardown(AProc: TTestProc): TTestSuite;
begin
  Result := Self;
  Result.Teardown := AProc;
  Result.TeardownClosure := nil;
end;

function TTestSuite.WithTeardown(AProc: TTestClosure): TTestSuite;
begin
  Result := Self;
  Result.Teardown := nil;
  Result.TeardownClosure := AProc;
end;

function TTestSuite.WithBeforeEach(AProc: TTestProc): TTestSuite;
begin
  Result := Self;
  Result.BeforeEach := AProc;
  Result.BeforeEachClosure := nil;
end;

function TTestSuite.WithBeforeEach(AProc: TTestClosure): TTestSuite;
begin
  Result := Self;
  Result.BeforeEach := nil;
  Result.BeforeEachClosure := AProc;
end;

function TTestSuite.WithAfterEach(AProc: TTestProc): TTestSuite;
begin
  Result := Self;
  Result.AfterEach := AProc;
  Result.AfterEachClosure := nil;
end;

function TTestSuite.WithAfterEach(AProc: TTestClosure): TTestSuite;
begin
  Result := Self;
  Result.AfterEach := nil;
  Result.AfterEachClosure := AProc;
end;

function TTestSuite.WithEachCleanup(AProc: TTestProc): TTestSuite;
var
  LProc: TTestProc;
  LIdx: Integer;
begin
  Result := Self;
  LProc := AProc;
  LIdx := GrowEachCleanups(Result.EachCleanups);
  Result.EachCleanups[LIdx] := procedure
  begin
    LProc;
  end;
  SetLength(Result.EachCleanups, LIdx + 1);
end;

function TTestSuite.WithEachCleanup(AProc: TTestClosure): TTestSuite;
var
  LIdx: Integer;
begin
  Result := Self;
  LIdx := GrowEachCleanups(Result.EachCleanups);
  Result.EachCleanups[LIdx] := AProc;
  SetLength(Result.EachCleanups, LIdx + 1);
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
  LConfig: TTestConfig;
  LOutSink: IOutputSink;
  LErrSink: IOutputSink;
  LGTestTimeoutMs: Integer;
  LTotalRetries: Integer;
  LRetriesLeft: Integer;
  LStartMs: Int64;
  LRepeatCount: Integer;
  LRepeatI: Integer;
  LTagFilter: string;
  LDisplayName: string;
  LProgressTotal: Integer;
  LProgressCurrent: Integer;
  LProgressPrefix: string;
  LIdx: Integer;
  LRunStartMs: Int64;
  LRunTimeoutMs: Int64;
begin
  AResult := TTestRunResult.Create(Name);
  LPass := 0;
  LFail := 0;
  LSkip := 0;
  LLastFailMsg := '';
  LAppender := TTestResultAppender.Create;
  LConfig := ResolveConfig(Config);
  LOutSink := ResolveOutSink(LConfig);
  LErrSink := ResolveErrSink(LConfig);
  LGTestTimeoutMs := GetTestTimeout(LConfig);
  LTagFilter := GetTagFilter(LConfig);
  LProgressCurrent := 0;
  { Pre-count eligible tests for progress display }
  if LConfig.ShowProgress then
  begin
    LProgressTotal := 0;
    for I := 0 to High(Tests) do
      if MatchesFilter(Tests[I].Name, LConfig) and
         MatchesTagFilter(Tests[I].Tags, LTagFilter) then
        Inc(LProgressTotal);
  end
  else
    LProgressTotal := 0;
  try

  LRunStartMs := GetTickCount64;
  if LConfig.RunTimeoutSec > 0 then
    LRunTimeoutMs := Int64(LConfig.RunTimeoutSec) * 1000
  else
    LRunTimeoutMs := 0;

  LOutSink.WriteLn('');
  WriteSuiteHeader(Name, IntToStr(Length(Tests)) + ' tests',
    LOutSink, LConfig);

  { Shuffle tests if enabled }
  if LConfig.ShuffleSeed <> 0 then
  begin
    ShuffleEntries(Tests, LConfig.ShuffleSeed);
    LOutSink.WriteLn(AnsiDim(
      '  shuffled (seed=' + IntToStr(Abs(LConfig.ShuffleSeed)) + ')', LConfig));
  end;

  { Suite-level setup (uses shared helper) }
  if not RunSetup(LConfig, LSkip, LLastFailMsg) then
  begin
    HandleSetupFailure(AResult, LSkip, LLastFailMsg, LOutSink, LConfig, True);
    Result := False;
    Exit;
  end;

  for I := 0 to High(Tests) do
  begin
    LEntry := Tests[I];
    LStatus := tsPassed;
    LSubCtxI := nil;
    LSubCtx := nil;
    SetCurrentTestContext(nil);
    LTestResult := MakeTestResult(LEntry.Name, tsPassed, '', 0);
    SetTestContext(Name, LEntry.Name);

    { Global run timeout check }
    if (LRunTimeoutMs > 0) and
       (GetTickCount64 - LRunStartMs >= LRunTimeoutMs) then
    begin
      LOutSink.WriteLn(AnsiYellow(
        '  TIMEOUT: run exceeded ' + IntToStr(LConfig.RunTimeoutSec) +
        's (--timeout)', LConfig));
      LStatus := tsError;
      LLastFailMsg := 'run timeout exceeded';
      Inc(LFail);
      Break;
    end;

    { Test filter — skip non-matching tests silently }
    if not MatchesFilter(LEntry.Name, LConfig) then
    begin
      { Not counted as pass/fail/skip — just invisible }
      Continue;
    end;

    { Tag filter — skip tests that don't match the tag filter }
    if not MatchesTagFilter(LEntry.Tags, LTagFilter) then
    begin
      Continue;
    end;

    { Short mode — skip tests marked with ShortSkip }
    if LConfig.ShortMode and LEntry.ShortSkip then
    begin
      LStatus := tsSkipped;
      Inc(LSkip);
      LTestResult := MakeTestResult(LEntry.Name, tsSkipped,
        'skipped: short mode', 0);
      AppendResult(AResult.Results, LTestResult);
      if LConfig.VerboseMode then
        WriteTestStatusVerbose(tsSkipped, LEntry.Name, '', 'short mode',
          0, LOutSink, LConfig)
      else
        LOutSink.WriteLn('  ' + FormatStatusLine(tsSkipped, LEntry.Name,
          'short mode', LConfig));
      ReportLeakIfAny(LStatus, LConfig);
      Continue;
    end;

    { Progress counter }
    Inc(LProgressCurrent);
    if LConfig.ShowProgress then
      LProgressPrefix := '[' + IntToStr(LProgressCurrent) + '/' +
        IntToStr(LProgressTotal) + '] '
    else
      LProgressPrefix := '';

    { Benchmarks: skip in regular test run (only run via RunBenchmarks) }
    if LEntry.Kind = ekBench then
      Continue;

    { Skip check BEFORE BeforeEach — skipped tests don't need hooks }
    if LEntry.Kind = ekSkipped then
    begin
      LStatus := tsSkipped;
      Inc(LSkip);
      LTestResult := MakeTestResult(LEntry.Name, tsSkipped,
        LEntry.SkipReason, 0);
      AppendResult(AResult.Results, LTestResult);
      if LConfig.VerboseMode then
        WriteTestStatusVerbose(tsSkipped, LEntry.Name, '', LEntry.SkipReason,
          0, LOutSink, LConfig)
      else if LEntry.SkipReason <> '' then
        LOutSink.WriteLn('  ' + FormatStatusLine(tsSkipped, LEntry.Name,
          LEntry.SkipReason, LConfig))
      else
        LOutSink.WriteLn('  ' + FormatStatusLine(tsSkipped, LEntry.Name, LConfig));
      ReportLeakIfAny(LStatus, LConfig);
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
          LTestResult := MakeTestResult(LEntry.Name, tsSkipped, E.Message, 0);
          AppendResult(AResult.Results, LTestResult);
          if LConfig.VerboseMode then
            WriteTestStatusVerbose(tsSkipped, LEntry.Name, '', E.Message,
              0, LOutSink, LConfig)
          else
            LOutSink.WriteLn('  ' + FormatStatusLine(tsSkipped, LEntry.Name,
              E.Message, LConfig));
          ReportLeakIfAny(LStatus, LConfig);
          Continue;
        end;
        on E: Exception do
        begin
          LStatus := tsError;
          LLastFailMsg := E.Message;
          LTestResult := MakeTestResult(LEntry.Name, tsError,
            'beforeEach failed: ' + E.Message, 0);
          AppendResult(AResult.Results, LTestResult);
          if LConfig.VerboseMode then
            WriteTestStatusVerbose(tsError, LEntry.Name,
              'beforeEach failed: ' + E.Message, '', 0, LOutSink, LConfig)
          else
            LOutSink.WriteLn('  ' + FormatStatusLine(tsError, LEntry.Name,
              'beforeEach failed: ' + E.Message, LConfig));
          Inc(LFail);
          Continue;
        end;
      end;
    end;

    LStartMs := GetTickCount64;
    LDisplayName := GetDisplayName(LEntry);
    if LEntry.Kind = ekTest then
    begin
      LSubCtx := TTestContext.Create(LEntry.Name, LConfig);
      LSubCtxI := LSubCtx;
      SetCurrentTestContext(LSubCtx);
    end;
    { RepeatCount: 0 means 1 run. >1 means repeat N times. }
    if LEntry.RepeatCount > 1 then
      LRepeatCount := LEntry.RepeatCount
    else
      LRepeatCount := 1;
    try
      if LEntry.Kind = ekSubtest then
      begin
        LSubCtx := TTestContext.Create(LEntry.Name, LConfig);
        LSubCtx.FOnResult := @LAppender.Append;
        LSubCtxI := LSubCtx;
        SetCurrentTestContext(LSubCtx);
        LEntry.SubtestProc(LSubCtxI);
        try
          LSubCtx.ExecuteSubtests;
        except
          on E: EAssertionFailed do
          begin
            LStatus := tsFailed;
            LLastFailMsg := AppendTestTrace(E.Message);
            Inc(LFail);
          end;
          on E: Exception do
          begin
            LStatus := tsError;
            LLastFailMsg := AppendTestTrace(FormatExceptionMsg(E));
            Inc(LFail);
          end;
        end;
      end
      else if LEntry.Kind = ekTableTest then
      begin
        { Table-driven test: invoke the stored proc with case data.
          Nil guard: --count=N re-runs the suite after CleanupTableAllocations
          has disposed TableCase/TableProc. Skip gracefully on re-run. }
        if (LEntry.TableCase = nil) or (LEntry.TableProc = nil) then
        begin
          LStatus := tsSkipped;
          LLastFailMsg := 'table data already disposed (--count re-run)';
          Inc(LSkip);
        end
        else
        try
          PTestCaseProc(LEntry.TableProc)^(PTestCase(LEntry.TableCase)^);
          Inc(LPass);
        except
          on E: ETestSkipped do
          begin
            LStatus := tsSkipped;
            LLastFailMsg := E.Message;
            Inc(LSkip);
          end;
          on E: EAssertionFailed do
          begin
            LStatus := tsFailed;
            LLastFailMsg := AppendTestTrace(E.Message);
            Inc(LFail);
          end;
          on E: Exception do
          begin
            LStatus := tsError;
            LLastFailMsg := AppendTestTrace(FormatExceptionMsg(E));
            Inc(LFail);
          end;
        end;
      end
      else if LEntry.Kind = ekShouldFail then
      begin
        { ShouldFail: test passes if proc raises, fails if it doesn't.
          Rust-style #[should_panic] expected-failure testing. }
        try
          if Assigned(LEntry.Closure) then
            LEntry.Closure()
          else
            LEntry.Proc;
          { No exception = unexpected success }
          LStatus := tsFailed;
          if LEntry.ShouldFailMsg <> '' then
            LLastFailMsg := 'Expected failure (' + LEntry.ShouldFailMsg +
              ') but test passed'
          else
            LLastFailMsg := 'Expected failure but test passed';
          Inc(LFail);
        except
          on E: ETestSkipped do
          begin
            LStatus := tsSkipped;
            LLastFailMsg := E.Message;
            Inc(LSkip);
          end;
          on E: Exception do
          begin
            { Expected failure — test passes }
            LStatus := tsPassed;
            Inc(LPass);
          end;
        end;
      end
      else
      begin
        { Run with retry support + repeat support: if RepeatCount > 1, run
          the test that many times and report the last result. }
        for LRepeatI := 1 to LRepeatCount do
        begin
        { Run with retry support: if test fails and retries remain, re-run. }
        LTotalRetries := LEntry.RetryCount;
        if LTotalRetries = 0 then
          LTotalRetries := LConfig.RetryCount;
        LRetriesLeft := LTotalRetries;
        repeat
          LStatus := tsPassed;
          LLastFailMsg := '';
          try
            if (LGTestTimeoutMs > 0) and (LEntry.Kind = ekTest) and
               (Assigned(LEntry.Proc) or Assigned(LEntry.Closure)) then
            begin
              if Assigned(LEntry.Closure) then
              begin
                if not RunTestWithTimeout(LEntry.Closure, LGTestTimeoutMs,
                  LConfig, LStatus, LLastFailMsg) then
                  { Timed out — LStatus already set to tsError };
              end
              else
              begin
                if RunTestWithTimeout(LEntry.Proc, LGTestTimeoutMs, LConfig,
                  LStatus, LLastFailMsg) then
                begin
                  if LStatus = tsPassed then { ok }
                  else { LStatus already set }
                end
                else
                  { Timed out — LStatus already set to tsError };
              end;
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
              LLastFailMsg := AppendTestTrace(E.Message);
            end;
            on E: Exception do
            begin
              LStatus := tsError;
              LLastFailMsg := AppendTestTrace(FormatExceptionMsg(E));
            end;
          end;

          if (LStatus = tsPassed) or (LStatus = tsSkipped) or (LRetriesLeft <= 0) then
            Break;

          { Retry: print hint and loop }
          Dec(LRetriesLeft);
          WriteRetryHint(LTotalRetries - LRetriesLeft, LTotalRetries,
            LOutSink, LConfig);
        until False;
        end; { end repeat loop }

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
        LLastFailMsg := AppendTestTrace(E.Message);
        Inc(LFail);
      end;
      on E: Exception do
      begin
        LStatus := tsError;
        LLastFailMsg := AppendTestTrace(FormatExceptionMsg(E));
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
          WriteWarning('afterEach failed: ' + E.Message, LErrSink, LConfig);
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

    { EachCleanups: LIFO cleanup, runs even on failure (Go t.Cleanup equivalent) }
    if Length(EachCleanups) > 0 then
    begin
      for LIdx := High(EachCleanups) downto 0 do
      begin
        try
          EachCleanups[LIdx]();
        except
          on E: Exception do
            WriteWarning('cleanup failed: ' + E.Message, LErrSink, LConfig);
        end;
      end;
    end;

    { Record test result }
    LTestResult := MakeTestResult(LEntry.Name, LStatus, LLastFailMsg,
      GetTickCount64 - LStartMs);
    { Copy captured log lines on failure/error for report output }
    if (LStatus in [tsFailed, tsError]) and (LSubCtx <> nil) and
       (Length(LSubCtx.FLogLines) > 0) then
      LTestResult.CapturedLog := LSubCtx.FLogLines;
    AppendResult(AResult.Results, LTestResult);

    { Output per-test — use DisplayName + progress prefix }
    if LConfig.VerboseMode then
      WriteTestStatusVerbose(LStatus, LProgressPrefix + LDisplayName,
        LLastFailMsg, LEntry.SkipReason,
        GetTickCount64 - LStartMs, LOutSink, LConfig)
    else
      WriteTestStatus(LStatus, LProgressPrefix + LDisplayName, LLastFailMsg,
        LEntry.SkipReason, LOutSink, LConfig);

    LLastFailMsg := '';
    ReportLeakIfAny(LStatus, LConfig);
    SetCurrentTestContext(nil);
    LSubCtxI := nil;
    LSubCtx := nil;
    { FailFast: stop on first failure }
    if LConfig.FailFast and (LStatus in [tsFailed, tsError]) then
    begin
      LOutSink.WriteLn(AnsiYellow(
        '  FAILFAST: stopping on first failure', LConfig));
      Break;
    end;
    { MaxFailures: stop after N total failures in this suite }
    if (LConfig.MaxFailures > 0) and (LFail >= LConfig.MaxFailures) then
    begin
      LOutSink.WriteLn(AnsiYellow(
        '  stopping after ' + IntToStr(LFail) + ' failures (--failures-max)',
        LConfig));
      Break;
    end;
  end;

  { Suite-level teardown (uses shared helper) }
  RunTeardown(LConfig);

  { Merge subtest-level results from appender }
  for J := 0 to High(LAppender.Results) do
    AppendResult(AResult.Results, LAppender.Results[J]);

  finally
    LSubCtxI := nil;
    LSubCtx := nil;
    LAppender.Free;
  end;

  { Dispose table test allocations (PTestCase/PTestCaseProc heap data).
    Must be called before FinalizeResults so that --count=N re-runs can
    skip already-disposed entries via the nil guard in the test loop.
    FCleanupDone guard prevents double-free when RunAllWithResult also
    calls CleanupTableAllocations after the full run. }
  CleanupTableAllocations;

  FinalizeResults(LConfig, AResult, LPass, LFail, LSkip);
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

{ R4-03: shared setup/teardown/finalize helpers extracted below. }

function TTestSuite.RunSetup(const AConfig: TTestConfig; out ASkipCount: Integer;
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
      ResolveErrSink(AConfig).WriteLn(
        '  ' + AnsiRed('X setup failed: ', AConfig) + E.Message);
      ASkipCount := Length(Tests);
      AErrorMsg := E.Message;
      Result := False;
    end;
  end;
end;

procedure TTestSuite.RunTeardown(const AConfig: TTestConfig);
begin
  if not (Assigned(Teardown) or Assigned(TeardownClosure)) then
    Exit;
  try
    if Assigned(Teardown) then Teardown else TeardownClosure();
  except
    on E: Exception do
      WriteWarning('teardown error: ' + E.Message,
        ResolveErrSink(AConfig), AConfig);
  end;
  { R4-12: Nil-out after execution to prevent double-free if the same
    suite is run twice on the same runner (e.g. fixture teardown that frees
    an object). Without this, the second run would call the closure again
    on an already-freed object. }
  Teardown := nil;
  TeardownClosure := nil;
end;

procedure TTestSuite.HandleSetupFailure(var AResult: TTestRunResult;
  ASkipCount: Integer; const AErrorMsg: string;
  const ASink: IOutputSink; const AConfig: TTestConfig;
  APopulateResults: Boolean);
{ Shared setup-failure handler for RunWithResult and RunParallelWithResult.
  APopulateResults: True for serial (populates AResult.Results with skipped entries),
  False for parallel (output only). }
var
  I: Integer;
  LTestResult: TTestResult;
begin
  if APopulateResults then
    for I := 0 to High(Tests) do
    begin
      LTestResult := MakeTestResult(Tests[I].Name, tsSkipped,
        'setup failed: ' + AErrorMsg, 0);
      AppendResult(AResult.Results, LTestResult);
      ASink.WriteLn('    ' + FormatStatusLine(tsSkipped, Tests[I].Name, AConfig));
    end
  else
    for I := 0 to High(Tests) do
      ASink.WriteLn('    ' + FormatStatusLine(tsSkipped, Tests[I].Name, AConfig));
  AResult.Failed    := 1;
  AResult.Skipped   := ASkipCount;
  AResult.AllPassed := False;
  HasRun        := True;
  LastRunPassed := False;
  LastPass      := 0;
  LastFail      := 1;
  LastSkip      := ASkipCount;
  ASink.WriteLn(
    AnsiDim('  ' + IntToStr(ASkipCount) + ' skipped (setup failure)', AConfig));
end;

procedure TTestSuite.FinalizeResults(const AConfig: TTestConfig;
  var AResult: TTestRunResult; APass, AFail, ASkip: Integer);
{ Sets result counters, populates slow test report, writes summary line.
  Does NOT call CleanupTableAllocations — stubs/fixtures must survive the
  full suite lifetime (--count=N re-runs need valid closure pointers).
  The caller (RunAll* or finalization) is responsible for cleanup. }
var
  LSlowCount: Integer;
  LOutSink: IOutputSink;
begin
  AResult.Passed    := APass;
  AResult.Failed    := AFail;
  AResult.Skipped   := ASkip;
  AResult.AllPassed := AFail = 0;
  HasRun        := True;
  LastRunPassed := AResult.AllPassed;
  LastPass      := APass;
  LastFail      := AFail;
  LastSkip      := ASkip;
  { Populate slow test report }
  LSlowCount := GetSlowTestCount(AConfig);
  if LSlowCount > 0 then
    AResult.SlowTests := GetTopSlowest(AResult.Results, LSlowCount);
  LOutSink := ResolveOutSink(AConfig);
  WriteSlowTests(AResult.SlowTests, LOutSink, AConfig);
  LOutSink.WriteLn(
    AnsiDim(
      '  ' + IntToStr(APass) + ' passed, ' +
      IntToStr(AFail) + ' failed, ' +
      IntToStr(ASkip) + ' skipped', AConfig));
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
  LConfig: TTestConfig;
  LOutSink: IOutputSink;
  LTagFilter: string;
  LMaxWorkers: Integer;
  LBatchStart, LSpawned, LFirstEligible: Integer;
  LProgressCounter: Integer;
  LProgressTotal: Integer;
begin
  AResult := TTestRunResult.Create(Name);
  LTotal := Length(Tests);
  LPass := 0;
  LFail := 0;
  LSkip := 0;
  LMtx := Mutex();
  LConfig := ResolveConfig(Config);
  LOutSink := ResolveOutSink(LConfig);
  LTagFilter := GetTagFilter(LConfig);

  LOutSink.WriteLn('');
  WriteSuiteHeader(Name, IntToStr(LTotal) + ' tests, parallel',
    LOutSink, LConfig);

  { Pre-count eligible tests for progress display }
  LProgressCounter := 0;
  if LConfig.ShowProgress then
  begin
    LProgressTotal := 0;
    for I := 0 to High(Tests) do
      if MatchesFilter(Tests[I].Name, LConfig) and
         MatchesTagFilter(Tests[I].Tags, LTagFilter) and
         not (LConfig.ShortMode and Tests[I].ShortSkip) then
        Inc(LProgressTotal);
  end
  else
    LProgressTotal := 0;

  { Suite-level setup (serial, uses shared helper) }
  if not RunSetup(LConfig, LSkip, LErrorMsg) then
  begin
    HandleSetupFailure(AResult, LSkip, LErrorMsg, LOutSink, LConfig, False);
    Result := False;
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
    if not MatchesFilter(Tests[I].Name, LConfig) then
    begin
      LThreads[I] := 0;  { no thread for this slot — also marks filter-excluded }
      Continue;
    end;
    { Tag filter }
    if not MatchesTagFilter(Tests[I].Tags, LTagFilter) then
    begin
      LThreads[I] := 0;
      Continue;
    end;
    { Short mode — skip tests marked with ShortSkip (handle before thread spawn) }
    if LConfig.ShortMode and Tests[I].ShortSkip then
    begin
      LThreads[I] := 0;
      Inc(LSkip);
      LResults[I] := MakeTestResult(Tests[I].Name, tsSkipped,
        'skipped: short mode', 0);
      LOutSink.WriteLn('  ' + FormatStatusLine(tsSkipped, Tests[I].Name,
        'short mode', LConfig));
      Continue;
    end;

    LRecs[I].Entry     := Tests[I];
    LRecs[I].SuiteName := Name;
    LRecs[I].Config    := LConfig;
    LRecs[I].Mtx       := LMtx;
    LRecs[I].Before    := BeforeEach;
    LRecs[I].BeforeClosure := BeforeEachClosure;
    LRecs[I].After     := AfterEach;
    LRecs[I].AfterClosure  := AfterEachClosure;
    LRecs[I].EachCleanups  := EachCleanups;
    LRecs[I].Pass      := @LPass;
    LRecs[I].Fail      := @LFail;
    LRecs[I].Skip      := @LSkip;
    LRecs[I].Res       := @LResults[I];
    if LConfig.ShowProgress then
    begin
      LRecs[I].ProgressCounter := @LProgressCounter;
      LRecs[I].ProgressTotal   := LProgressTotal;
    end
    else
    begin
      LRecs[I].ProgressCounter := nil;
      LRecs[I].ProgressTotal   := 0;
    end;
    { Subtest/ekSkipped results and counters are handled entirely by the worker
      to avoid double-counting. See ParallelWorkerProc. }
  end;

  { Use BeginThread to ensure FPC properly initializes per-thread state
    (exception handler chain, threadvar TLS, heap manager).
    Previously platform_thread_create (direct pthread_create) was used,
    which bypasses FPC init and caused intermittent SIGSEGV on thread exit.

    Batch dispatch: when MaxParallelWorkers > 0, spawn at most that many
    threads per batch. This avoids OS thread exhaustion on large suites.
    MaxParallelWorkers = 0 means unlimited (one thread per test). }
  LMaxWorkers := LConfig.MaxParallelWorkers;
  if LMaxWorkers <= 0 then
    LMaxWorkers := LTotal; { unlimited: spawn all in one batch }

  LBatchStart := 0;
  while LBatchStart < LTotal do
  begin
    { Find the first eligible test at or after LBatchStart }
    LFirstEligible := -1;
    for I := LBatchStart to High(Tests) do
    begin
      if MatchesFilter(Tests[I].Name, LConfig) and
         MatchesTagFilter(Tests[I].Tags, LTagFilter) and
         not (LConfig.ShortMode and Tests[I].ShortSkip) then
      begin
        LFirstEligible := I;
        Break;
      end;
    end;
    if LFirstEligible < 0 then
      Break; { no more eligible tests }

    LSpawned := 0;
    for I := LFirstEligible to High(Tests) do
    begin
      if LSpawned >= LMaxWorkers then
        Break;
      if not MatchesFilter(Tests[I].Name, LConfig) then
        Continue;
      if not MatchesTagFilter(Tests[I].Tags, LTagFilter) then
        Continue;
      if LConfig.ShortMode and Tests[I].ShortSkip then
        Continue;
      LThreads[I] := BeginThread(@ParallelThreadEntry, @LRecs[I]);
      if LThreads[I] = 0 then
      begin
        LResults[I] := MakeTestResult(Tests[I].Name, tsError,
          'BeginThread failed', 0);
        Inc(LFail);
      end;
      Inc(LSpawned);
      LBatchStart := I + 1;
    end;

    { Join this batch before spawning the next }
    for I := 0 to High(Tests) do
      if LThreads[I] <> 0 then
        WaitForThreadTerminate(LThreads[I], 0);

    { Close thread handles — required on Windows to avoid kernel handle leak }
    for I := 0 to High(Tests) do
      if LThreads[I] <> 0 then
        CloseThread(LThreads[I]);

    { Clear handles for reuse in next batch }
    FillChar(LThreads[0], Length(LThreads) * SizeOf(TThreadID), 0);
  end;

  { Suite-level teardown (uses shared helper) }
  RunTeardown(LConfig);

  { Collect results from threads that actually ran.
    Filter-excluded slots have LThreads[I]=0 and no result data.
    BeginThread-failed slots also have LThreads[I]=0 but have result data
    written directly (tsError + 'BeginThread failed'). }
  for I := 0 to High(Tests) do
    if (LThreads[I] <> 0) or (LResults[I].Status <> tsPassed) or
       (LResults[I].Name <> '') then
      AppendResult(AResult.Results, LResults[I]);

  { Dispose table test allocations from parallel worker records.
    Same rationale as RunWithResult — FCleanupDone guard prevents
    double-free when RunAllParallelWithResult also calls this. }
  CleanupTableAllocations;

  FinalizeResults(LConfig, AResult, LPass, LFail, LSkip);
  Result := LastRunPassed;
end;

function TTestSuite.RunBenchmarks(out AResults: TBenchResults): Boolean;
{ Run all ekBench entries with adaptive N scaling until timing stabilizes.
    Algorithm (mirrors Go testing.B):
    1. Start with N=1
    2. Run N iterations, measure total time
    3. If total time < BenchTimeMs, multiply N and retry
    4. Stop when total time >= BenchTimeMs or N >= 1 billion
    5. Report NsPerOp = TotalNs / N }
var
  I: Integer;
  LEntry: TTestEntry;
  LConfig: TTestConfig;
  LOutSink: IOutputSink;
  LBenchTimeMs: Integer;
  LShowMem: Boolean;
  LCtx: TBenchContext;
  LN: Integer;
  LStartMs, LElapsedMs: Int64;
  LResult: TBenchResult;
  LCount, LCap: Integer;
begin
  LConfig := ResolveConfig(Config);
  LOutSink := ResolveOutSink(LConfig);
  LBenchTimeMs := GetBenchTimeMs(LConfig);
  if LBenchTimeMs <= 0 then LBenchTimeMs := 1000;
  LShowMem := GetBenchMem(LConfig);
  LCount := 0;
  LCap := 0;
  SetLength(AResults, 0);
  LOutSink.WriteLn('');
  WriteSuiteHeader(Name, 'benchmarks', LOutSink, LConfig);
  for I := 0 to High(Tests) do
  begin
    LEntry := Tests[I];
    if LEntry.Kind <> ekBench then Continue;
    if not MatchesFilter(LEntry.Name, LConfig) then Continue;
    { Adaptive N scaling — use GetTickCount64 (ms) for reliable timing }
    LN := 1;
    repeat
      FillChar(LCtx, SizeOf(LCtx), 0);
      LCtx.N := LN;
      LStartMs := GetTickCount64;
      LEntry.BenchProc(@LCtx);
      LElapsedMs := GetTickCount64 - LStartMs;
      if LElapsedMs >= LBenchTimeMs then
        Break;
      { Scale N: use Int64 to prevent overflow before bounds check }
      if LElapsedMs < 10 then
        LN := Int64(LN) * 100
      else
        LN := Int64(LN) * LBenchTimeMs div LElapsedMs;
      if LN > 1000000000 then
      begin
        LN := 1000000000;
        Break;
      end;
    until False;
    { Final run with calibrated N }
    FillChar(LCtx, SizeOf(LCtx), 0);
    LCtx.N := LN;
    LStartMs := GetTickCount64;
    LEntry.BenchProc(@LCtx);
    LElapsedMs := GetTickCount64 - LStartMs;
    LResult := MakeBenchResult(LEntry.Name, LN,
      LElapsedMs * 1000000, LCtx.AllocBytes, LCtx.AllocCount);
    { Geometric growth: only grow during loop, trim once at end.
      Writing beyond logical length after SetLength-down triggers heaptrc
      guard violation even though allocated capacity is sufficient. }
    if LCount >= LCap then
    begin
      LCap := GrowCapacity(LCap, 4);
      SetLength(AResults, LCap);
    end;
    AResults[LCount] := LResult;
    LOutSink.WriteLn(FormatBenchLine(LResult, LShowMem, LConfig));
    Inc(LCount);
  end;
  SetLength(AResults, LCount); { trim to logical size }
  if LCount = 0 then
    LOutSink.WriteLn(AnsiDim('  (no benchmarks matched)', LConfig));
  Result := LCount > 0;
end;

procedure TTestSuite.Summary;
var
  LConfig: TTestConfig;
  LOutSink: IOutputSink;
begin
  LConfig := ResolveConfig(Config);
  if not HasRun then
  begin
    ResolveErrSink(LConfig).WriteLn(
      AnsiYellow('Warning: ', LConfig) + Name + ' has not been run yet');
    Exit;
  end;
  LOutSink := ResolveOutSink(LConfig);
  LOutSink.WriteLn(
    AnsiBold('--- ', LConfig) +
    AnsiCyan(Name, LConfig) +
    AnsiBold(' ---', LConfig));
  LOutSink.WriteLn('  Total tests: ' + IntToStr(Length(Tests)));
  LOutSink.WriteLn(
    '  Passed: ' + IntToStr(LastPass) +
    ', Failed: ' + IntToStr(LastFail) +
    ', Skipped: ' + IntToStr(LastSkip));
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

procedure TTestSuite.CleanupTableAllocations;
  { Disposes heap-allocated table test data, stubs, and fixtures.
    FCleanupDone guard prevents double-free on --count=N re-runs where
    CleanupTableAllocations is called once after the final iteration.
    Must be called from the main thread only. }
var
  I: Integer;
begin
  if FCleanupDone then Exit;
  FCleanupDone := True;
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
    to the runner. Rule: register ALL tests before calling Add.
    IMPORTANT: Pascal record assignment shares dynamic array references via
    refcount. We must deep-copy Tests so that runner operations (shuffle,
    etc.) don't mutate the caller's original suite data. }
var
  LIdx: Integer;
begin
  LIdx := GrowArrayLen(Suites, 4);
  Suites[LIdx] := ASuite;
  { Deep-copy Tests to break refcount sharing — shuffle and other
    mutations in RunWithResult must not affect the caller's suite. }
  Suites[LIdx].Tests := Copy(ASuite.Tests, 0, Length(ASuite.Tests));
  SetLength(Suites, LIdx + 1);
end;

{ ── Runner banner (shared by sequential + parallel paths) ────────────────────── }

procedure WriteRunnerBanner(const AName: string; const AConfig: TTestConfig;
  const ASink: IOutputSink; AIsParallel: Boolean);
var
  LRepeatAll, LMaxFailures: Integer;
  LLabel: string;
begin
  if AIsParallel then LLabel := ' (parallel)' else LLabel := '';
  ASink.WriteLn(
    AnsiBold('=== ', AConfig) +
    AnsiBold(AName, AConfig) +
    AnsiBold(LLabel + ' ===', AConfig));
  LRepeatAll := GetRepeatAllCount(AConfig);
  if LRepeatAll > 1 then
    ASink.WriteLn(AnsiDim(
      '  Running all tests ' + IntToStr(LRepeatAll) + ' times (--count=' +
      IntToStr(LRepeatAll) + ')', AConfig));
  if GetFailFast(AConfig) then
    ASink.WriteLn(AnsiDim('  FailFast enabled', AConfig));
  LMaxFailures := GetMaxFailures(AConfig);
  if LMaxFailures > 0 then
    ASink.WriteLn(AnsiDim(
      '  Failures max: ' + IntToStr(LMaxFailures) + ' (--failures-max)',
      AConfig));
  if GetShortMode(AConfig) then
    ASink.WriteLn(AnsiDim('  Short mode enabled (--short)', AConfig));
  if GetVerboseMode(AConfig) then
    ASink.WriteLn(AnsiDim('  Verbose mode (--verbose)', AConfig));
  if GetRunTimeoutSec(AConfig) > 0 then
    ASink.WriteLn(AnsiDim(
      '  Run timeout: ' + IntToStr(GetRunTimeoutSec(AConfig)) + 's (--timeout)',
      AConfig));
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
  I, LIter, LRepeatAll: Integer;
  LAllPassed: Boolean;
  LSuiteResult: TTestRunResult;
  LConfig: TTestConfig;
  LOutSink: IOutputSink;
  LStartMs: Int64;
  LFailFast: Boolean;
  LMaxFailures: Integer;
  LBenchResults: specialize TArray<TBenchResults>;
begin
  ApplyCLIArgs;
  LConfig := RunnerConfig(Self);
  LOutSink := ResolveOutSink(LConfig);

  { List mode: print test names and exit without running }
  if GetListMode(LConfig) then
  begin
    HasRun := True;
    Exit(WriteListMode(Suites, LConfig, AResults));
  end;

  LRepeatAll := GetRepeatAllCount(LConfig);
  if LRepeatAll <= 0 then LRepeatAll := 1;
  LFailFast := GetFailFast(LConfig);
  LMaxFailures := GetMaxFailures(LConfig);

  WriteRunnerBanner(Name, LConfig, LOutSink, False);

  LAllPassed := True;
  TotalPass := 0;
  TotalFail := 0;
  TotalSkip := 0;
  SetLength(AResults, Length(Suites));

  for LIter := 1 to LRepeatAll do
  begin
    if LRepeatAll > 1 then
    begin
      LOutSink.WriteLn('');
      LOutSink.WriteLn(AnsiBold(
        '--- Iteration ' + IntToStr(LIter) + '/' + IntToStr(LRepeatAll) +
        ' ---', LConfig));
      { Reset counters each iteration — only the last iteration's totals are kept }
      TotalPass := 0;
      TotalFail := 0;
      TotalSkip := 0;
    end;
    LStartMs := GetTickCount64;
    for I := 0 to High(Suites) do
    begin
      if not Suites[I].RunWithResult(LSuiteResult) then
      begin
        LAllPassed := False;
        if LFailFast then
        begin
          LOutSink.WriteLn(AnsiYellow(
            '  FAILFAST: stopping after suite failure', LConfig));
          AResults[I] := LSuiteResult;
          Inc(TotalPass, Suites[I].LastPass);
          Inc(TotalFail, Suites[I].LastFail);
          Inc(TotalSkip, Suites[I].LastSkip);
          Break;
        end;
      end;
      { Only keep the last iteration's results }
      AResults[I] := LSuiteResult;
      Inc(TotalPass, Suites[I].LastPass);
      Inc(TotalFail, Suites[I].LastFail);
      Inc(TotalSkip, Suites[I].LastSkip);
      { MaxFailures: stop after N total failures across all suites }
      if (LMaxFailures > 0) and (TotalFail >= LMaxFailures) then
      begin
        LOutSink.WriteLn(AnsiYellow(
          '  stopping after ' + IntToStr(TotalFail) +
          ' total failures (--failures-max)', LConfig));
        Break;
      end;
    end;
    if LRepeatAll > 1 then
      LOutSink.WriteLn(AnsiDim(
        '  Iteration ' + IntToStr(LIter) + ' completed in ' +
        FormatDuration(GetTickCount64 - LStartMs), LConfig));
  end;

  { Cleanup after all iterations: stubs/fixtures/table data must survive
    --count=N re-runs. FinalizeResults no longer calls this. }
  for I := 0 to High(Suites) do
    Suites[I].CleanupTableAllocations;

  HasRun := True;
  Result := LAllPassed;
  { JSON output — emit machine-readable report to stdout }
  if GetJsonOutput(LConfig) then
    LOutSink.WriteLn(JSONReport(AResults, Name));
  { Benchmarks — run after regular tests if --bench was passed }
  if GetBenchEnabled(LConfig) then
    RunAllBenchmarks(LBenchResults);
end;

function TTestRunner.RunAllParallelWithResult(APool: IThreadPool;
  out AResults: specialize TArray<TTestRunResult>): Boolean;
var
  I, LIter, LRepeatAll: Integer;
  LAllPassed: Boolean;
  LSuiteResult: TTestRunResult;
  LConfig: TTestConfig;
  LOutSink: IOutputSink;
  LStartMs: Int64;
  LFailFast: Boolean;
  LMaxFailures: Integer;
begin
  ApplyCLIArgs;
  LConfig := RunnerConfig(Self);
  LOutSink := ResolveOutSink(LConfig);

  { List mode: print test names and exit without running }
  if GetListMode(LConfig) then
  begin
    HasRun := True;
    Exit(WriteListMode(Suites, LConfig, AResults));
  end;

  LRepeatAll := GetRepeatAllCount(LConfig);
  if LRepeatAll <= 0 then LRepeatAll := 1;
  LFailFast := GetFailFast(LConfig);
  LMaxFailures := GetMaxFailures(LConfig);

  WriteRunnerBanner(Name, LConfig, LOutSink, True);

  LAllPassed := True;
  TotalPass := 0;
  TotalFail := 0;
  TotalSkip := 0;
  SetLength(AResults, Length(Suites));

  for LIter := 1 to LRepeatAll do
  begin
    if LRepeatAll > 1 then
    begin
      LOutSink.WriteLn('');
      LOutSink.WriteLn(AnsiBold(
        '--- Iteration ' + IntToStr(LIter) + '/' + IntToStr(LRepeatAll) +
        ' ---', LConfig));
      { Reset counters each iteration — only the last iteration's totals are kept }
      TotalPass := 0;
      TotalFail := 0;
      TotalSkip := 0;
    end;
    LStartMs := GetTickCount64;
    for I := 0 to High(Suites) do
    begin
      if not Suites[I].RunParallelWithResult(APool, LSuiteResult) then
      begin
        LAllPassed := False;
        if LFailFast then
        begin
          LOutSink.WriteLn(AnsiYellow(
            '  FAILFAST: stopping after suite failure', LConfig));
          AResults[I] := LSuiteResult;
          Inc(TotalPass, Suites[I].LastPass);
          Inc(TotalFail, Suites[I].LastFail);
          Inc(TotalSkip, Suites[I].LastSkip);
          Break;
        end;
      end;
      AResults[I] := LSuiteResult;
      Inc(TotalPass, Suites[I].LastPass);
      Inc(TotalFail, Suites[I].LastFail);
      Inc(TotalSkip, Suites[I].LastSkip);
      { MaxFailures: stop after N total failures across all suites }
      if (LMaxFailures > 0) and (TotalFail >= LMaxFailures) then
      begin
        LOutSink.WriteLn(AnsiYellow(
          '  stopping after ' + IntToStr(TotalFail) +
          ' total failures (--failures-max)', LConfig));
        Break;
      end;
    end;
    if LRepeatAll > 1 then
      LOutSink.WriteLn(AnsiDim(
        '  Iteration ' + IntToStr(LIter) + ' completed in ' +
        FormatDuration(GetTickCount64 - LStartMs), LConfig));
  end;

  { Cleanup after all iterations: stubs/fixtures/table data must survive
    --count=N re-runs. FinalizeResults no longer calls this. }
  for I := 0 to High(Suites) do
    Suites[I].CleanupTableAllocations;

  HasRun := True;
  Result := LAllPassed;
  { JSON output — emit machine-readable report to stdout }
  if GetJsonOutput(LConfig) then
    LOutSink.WriteLn(JSONReport(AResults, Name));
end;

function TTestRunner.RunAllBenchmarks(
  out AResults: specialize TArray<TBenchResults>): Boolean;
var
  I: Integer;
  LConfig: TTestConfig;
  LOutSink: IOutputSink;
begin
  ApplyCLIArgs;
  LConfig := RunnerConfig(Self);
  LOutSink := ResolveOutSink(LConfig);
  LOutSink.WriteLn(
    AnsiBold('=== ', LConfig) +
    AnsiBold(Name + ' benchmarks', LConfig) +
    AnsiBold(' ===', LConfig));
  SetLength(AResults, Length(Suites));
  Result := True;
  for I := 0 to High(Suites) do
  begin
    if not Suites[I].RunBenchmarks(AResults[I]) then
      { No benchmarks in this suite — not a failure }
      ;
  end;
end;

procedure TTestRunner.Summary;
var
  LConfig: TTestConfig;
  LOutSink: IOutputSink;
begin
  LConfig := RunnerConfig(Self);
  LOutSink := ResolveOutSink(LConfig);
  LOutSink.WriteLn('');
  LOutSink.WriteLn(AnsiBold('=== Summary ===', LConfig));
  LOutSink.WriteLn('  Suites: ' + IntToStr(Length(Suites)));
  LOutSink.WriteLn(
    '  Passed: ' + IntToStr(TotalPass) +
    ', Failed: ' + IntToStr(TotalFail) +
    ', Skipped: ' + IntToStr(TotalSkip));
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
    cleaned up by CleanupTableAllocations (e.g. suites created but never run).
    For suites that ran, CleanupTableAllocations already freed these and
    set the GStubRegistry/GFixtureRegistry entries to nil — the nil check
    prevents double-free here. Iterate each registry independently to handle
    length mismatches. }
  for GStubCleanupI := 0 to High(GStubRegistry) do
    if GStubRegistry[GStubCleanupI] <> nil then
      FreeMem(GStubRegistry[GStubCleanupI]);
  for GStubCleanupI := 0 to High(GFixtureRegistry) do
    if GFixtureRegistry[GStubCleanupI] <> nil then
      GFixtureRegistry[GStubCleanupI].Free;
  GStubRegistry := nil;
  GFixtureRegistry := nil;

end.
