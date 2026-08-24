{ nextpas.core.test.runner — TTestSuite registration + execution engine
  (TSuiteRunner multi-suite orchestration lives in nextpas.core.test.runner.multi)
  =========================================================
  Depends on: nextpas.core.test.base, nextpas.core.test.check, nextpas.core.test.output,
              nextpas.core.test.runner.cli, nextpas.core.test.runner.context,
              nextpas.core.test.runner.parallel }

unit nextpas.core.test.runner;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.system,
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
  nextpas.core.time,
  nextpas.core.time.cpu;

{ v8.25: timeout-worker leak counter (implemented in runner.parallel). }
function GetTimeoutWorkerLeakCount: Integer;
procedure ResetTimeoutWorkerLeakCount;

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
    { Source files for cache key computation — if set, cache key includes
      file contents so cache is invalidated when source changes. }
    SourceFiles  : specialize TArray<string>;

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
    { TestTable: data-driven test with multiple input/output cases.
      Each TTestCase provides input args and expected output. The test runs
      once per case, reporting pass/fail per case.

      NOTE: Most tests prefer Test() + closure for clarity. Use TestTable
      when you have many input/output pairs that are cleaner as data than code.

      Example:
        TestTable('Add', [
          TTestCase.Create(['1', '2'], '3'),
          TTestCase.Create(['0', '0'], '0')
        ], @AddProc); }
    procedure TestTable(const AName: string;
      ACases: specialize TArray<TTestCase>;
      AProc: TTestCaseProc);
    { ShouldFail: test passes if proc raises any exception (Rust #[should_panic]).
      AShouldFailMsg is optional reason shown in output. }
    procedure ShouldFail(const AName: string; AProc: TTestProc;
      const AShouldFailMsg: string = '');
    procedure ShouldFail(const AName: string; AProc: TTestClosure;
      const AShouldFailMsg: string = '');
    { ShouldFail with exception class matching:
      test passes only if proc raises AExpectedClass (or subclass).
      AContains is optional substring that must appear in exception message. }
    procedure ShouldFail(const AName: string; AProc: TTestProc;
      AExpectedClass: TClass;
      const AContains: string = '');
    procedure ShouldFail(const AName: string; AProc: TTestClosure;
      AExpectedClass: TClass;
      const AContains: string = '');
    { ShouldFail with message substring matching only (no class check).
      ADummy is a disambiguation parameter (pass 0) — FPC cannot distinguish
      this from ShouldFail(name, proc, msg) without it.
      Prefer ShouldFail(name, proc, TClass, contains) when class check is desired. }
    procedure ShouldFail(const AName: string; AProc: TTestProc;
      const AContains: string;
      ADummy: Integer);
    procedure ShouldFail(const AName: string; AProc: TTestClosure;
      const AContains: string;
      ADummy: Integer);
    { ShortSkip: mark a test to be skipped in --short mode (Go testing.Short()).
      When ShortMode is off, the test runs normally. }
    procedure ShortSkip(const AName: string; AProc: TTestProc);
    procedure ShortSkip(const AName: string; AProc: TTestClosure);
    { TestSeq: register a test that runs serially even in parallel mode.
      Go t.Parallel() inverse — use for tests with shared mutable state
      (DB, file system, global variables) that cannot run concurrently. }
    procedure TestSeq(const AName: string; AProc: TTestProc);
    procedure TestSeq(const AName: string; AProc: TTestClosure);
    procedure Skip(const AName: string; const AReason: string = '');
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
    { Tag: apply tags to all tests currently registered in this suite.
      Call after registering tests to bulk-tag them.
      Example:
        Suite.Test('A', @TestA);
        Suite.Test('B', @TestB);
        Suite.Tag('integration');  // A and B both get 'integration' tag }
    procedure Tag(const ATags: array of string);
    { ⚠️ With* methods return a NEW record — you MUST assign the return value:
        Suite := Suite.WithSetup(Proc);  // ✅ correct
        Suite.WithSetup(Proc);           // ❌ BUG: changes discarded
      Prefer direct modification methods (SetSetup/OnBeforeEach/etc.) to avoid
      this trap. Note: FPC deprecated directive does not work on record methods,
      so these cannot emit compile-time warnings. }
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
    function  RunWithResult(out AResult: TTestRunResult;
      ADeferCleanup: Boolean = False): Boolean;
    function  RunParallel(APool: IThreadPool): Boolean;
      { Note: APool is currently unused — parallel mode uses BeginThread directly
        to ensure FPC properly initializes per-thread state. Reserved for future
        thread pool integration. }
    function  RunParallelWithResult(APool: IThreadPool;
      out AResult: TTestRunResult;
      ADeferCleanup: Boolean = False): Boolean;
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
                APopulateResults: Boolean;
                ADeferCleanup: Boolean = False);
    procedure FinalizeResults(const AConfig: TTestConfig;
                var AResult: TTestRunResult;
                APass, AFail, ASkip: Integer);
    { Emit a test result: MakeTestResult + AppendResult + WriteTestOutput.
      Returns True (caller should Continue). }
    function  EmitResult(AStatus: TTestStatus; const AEntry: TTestEntry;
                const AMsg: string; var ACounter: Integer;
                var AResults: specialize TArray<TTestResult>;
                const AOutSink: IOutputSink;
                const AConfig: TTestConfig): Boolean;
  end;

{ Register a heap-allocated method stub for later disposal.
  Adds to both the suite's per-instance list and a global safety-net registry. }
procedure RegisterStub(var ASuite: TTestSuite; APtr: Pointer);
{ R6-05: Register a fixture object for safety-net disposal.
  Records the GFixtureRegistry index in the suite for cleanup.
  Only call once per fixture (from DiscoverTests). }
procedure RegisterFixture(var ASuite: TTestSuite; AFixture: TObject);
{ White-box helpers for test_runner: pure single-arg CLI parsers (no ParamStr). }
function HasArgFlag(const AArg, AFlag1: string;
  const AFlag2: string = ''): Boolean;
function ExtractArgValue(const AArg, APrefix: string): string;
function ExtractArgIntValue(const AArg, APrefix: string;
  ADefault: Integer): Integer;
{ White-box helper for test_runner: parse --filter=value form from one argv item. }
function ParseFilter(const AArg: string): string;
{ White-box helper for test_runner: parse --tag=value form from one argv item. }
function ParseTag(const AArg: string): string;
{ Apply CLI flags from an injectable argv list (not ParamStr). }
procedure ApplyCLIArgsFrom(const AArgs: array of string);
{ Check if a test entry matches a tag filter. Empty filter = match all. }
function MatchesTagFilter(const AEntryTags: specialize TArray<string>;
  const ATagFilter: string): Boolean;
{ Unified eligibility filter: name + tag + optional ShortSkip check.
  AIncludeShortSkip=True means ShortSkip tests are eligible (for pre-count). }
function IsTestEligible(const AEntry: TTestEntry; const AConfig: TTestConfig;
  const ATagFilter: string; AIncludeShortSkip: Boolean = False): Boolean;
{ Get effective display name: DisplayName if non-empty, else Name. }
function GetDisplayName(const AEntry: TTestEntry): string;
{ Active test context for the currently executing test. }
function Ctx: ITestContext;

implementation

uses
  nextpas.core.test.runner.cli,
  nextpas.core.test.runner.context,
  nextpas.core.test.runner.parallel,
  nextpas.core.json,
  nextpas.core.json.builder,
  nextpas.core.fs,
  nextpas.core.time.base;

function GetTimeoutWorkerLeakCount: Integer;
begin
  Result := nextpas.core.test.runner.parallel.GetTimeoutWorkerLeakCount;
end;

procedure ResetTimeoutWorkerLeakCount;
begin
  nextpas.core.test.runner.parallel.ResetTimeoutWorkerLeakCount;
end;

{ Forward CLI helpers — declarations in interface, implementations in runner.cli }

function HasArgFlag(const AArg, AFlag1: string;
  const AFlag2: string = ''): Boolean;
begin
  Result := nextpas.core.test.runner.cli.HasArgFlag(AArg, AFlag1, AFlag2);
end;

function ExtractArgValue(const AArg, APrefix: string): string;
begin
  Result := nextpas.core.test.runner.cli.ExtractArgValue(AArg, APrefix);
end;

function ExtractArgIntValue(const AArg, APrefix: string;
  ADefault: Integer): Integer;
begin
  Result := nextpas.core.test.runner.cli.ExtractArgIntValue(AArg, APrefix, ADefault);
end;

function ParseFilter(const AArg: string): string;
begin Result := nextpas.core.test.runner.cli.ParseFilter(AArg); end;

function ParseTag(const AArg: string): string;
begin Result := nextpas.core.test.runner.cli.ParseTag(AArg); end;

procedure ApplyCLIArgsFrom(const AArgs: array of string);
begin
  nextpas.core.test.runner.cli.ApplyCLIArgsFrom(AArgs);
end;

{ Global registry of all heap-allocated method stubs from DiscoverTests.
  Stubs are disposed by CleanupTableAllocations (with FCleanupDone guard)
  or in finalization as safety net for suites that are never run.
  R6-08: NOT thread-safe — all access must be from the main thread only. }
var
  { FIX-B: safety-net registry for table payloads (mirrors GStubRegistry R6-08) }
  GTableCases: specialize TArray<Pointer>;
  GTableProcs: specialize TArray<Pointer>;
  GStubRegistry: specialize TArray<Pointer>;
  { Parallel array tracking fixture objects from DiscoverTests.
    Only non-nil for stubs registered by discovery. Freed in finalization
    as safety net for suites that are created but never run.
    R6-08: NOT thread-safe — all access must be from the main thread only. }
  GFixtureRegistry: specialize TArray<TObject>;
  GStubCleanupI: Integer;
  GMainThreadId: UInt64;

function Ctx: ITestContext;
begin
  if (GetCurrentTestContext = nil) or
     (not Supports(GetCurrentTestContext, ITestContext, Result)) then
    raise Exception.Create(
      'No active test context — Ctx can only be called from within a running test.' +
      ' If called from a parallel worker, ensure BeforeEach has completed.');
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

function IsTestEligible(const AEntry: TTestEntry; const AConfig: TTestConfig;
  const ATagFilter: string; AIncludeShortSkip: Boolean): Boolean;
begin
  Result := MatchesFilter(AEntry.Name, AConfig) and
            MatchesTagFilter(AEntry.Tags, ATagFilter) and
            (AIncludeShortSkip or not (AConfig.ShortMode and AEntry.ShortSkip));
end;

function GetDisplayName(const AEntry: TTestEntry): string;
begin
  if AEntry.DisplayName <> '' then
    Result := AEntry.DisplayName
  else
    Result := AEntry.Name;
end;

function GetCompilerVersion: string;
const
  cFPCVersion = {$I %FPCVERSION%};
begin
  Result := cFPCVersion;
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

{ ── Generic array capacity growth ───────────────────────────────────────────── }
{ Grow AArray capacity if needed. Returns old length (= insertion index).
  FPC doesn't support generic standalone functions, so we need4 overloads.
  Each body is identical — GrowCapacity computes geometric growth. }

function GrowArrayLen(var AArray: specialize TArray<Pointer>; AInitCap: Integer): Integer;
begin
  Result := Length(AArray);
  SetLength(AArray, GrowCapacity(Result, AInitCap));
end;

function GrowArrayLen(var AArray: specialize TArray<TObject>; AInitCap: Integer): Integer;
begin
  Result := Length(AArray);
  SetLength(AArray, GrowCapacity(Result, AInitCap));
end;

function GrowArrayLen(var AArray: specialize TArray<Integer>; AInitCap: Integer): Integer;
begin
  Result := Length(AArray);
  SetLength(AArray, GrowCapacity(Result, AInitCap));
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
  if platform_thread_id <> GMainThreadId then
    raise Exception.Create(
      'RegisterStub must be called from the main thread (tid=' +
      UIntToStr(platform_thread_id) + ', expected=' +
      UIntToStr(GMainThreadId) + ')');
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
  if platform_thread_id <> GMainThreadId then
    raise Exception.Create(
      'RegisterFixture must be called from the main thread (tid=' +
      UIntToStr(platform_thread_id) + ', expected=' +
      UIntToStr(GMainThreadId) + ')');
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
    New(LPCase);
    LPCase^ := Default(TTestCase);
    LPCase^ := ACases[I];
    New(LPProc);
    LPProc^ := AProc;
    { FIX-B: track payloads so finalization can dispose them even when the
      owning suite record is dropped without CleanupTableAllocations }
    SetLength(GTableCases, Length(GTableCases) + 1);
    GTableCases[High(GTableCases)] := LPCase;
    SetLength(GTableProcs, Length(GTableProcs) + 1);
    GTableProcs[High(GTableProcs)] := LPProc;

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

procedure TTestSuite.ShouldFail(const AName: string; AProc: TTestProc;
  AExpectedClass: TClass; const AContains: string);
var
  LEntry: TTestEntry;
begin
  InitProcEntry(LEntry, AName, AProc);
  LEntry.Kind             := ekShouldFail;
  LEntry.ShouldFailClass  := AExpectedClass;
  LEntry.ShouldFailContains := AContains;
  RegisterEntry(Tests, LEntry);
end;

procedure TTestSuite.ShouldFail(const AName: string; AProc: TTestClosure;
  AExpectedClass: TClass; const AContains: string);
var
  LEntry: TTestEntry;
begin
  InitClosureEntry(LEntry, AName, AProc);
  LEntry.Kind             := ekShouldFail;
  LEntry.ShouldFailClass  := AExpectedClass;
  LEntry.ShouldFailContains := AContains;
  RegisterEntry(Tests, LEntry);
end;

procedure TTestSuite.ShouldFail(const AName: string; AProc: TTestProc;
  const AContains: string; ADummy: Integer);
var
  LEntry: TTestEntry;
begin
  InitProcEntry(LEntry, AName, AProc);
  LEntry.Kind               := ekShouldFail;
  LEntry.ShouldFailContains := AContains;
  RegisterEntry(Tests, LEntry);
end;

procedure TTestSuite.ShouldFail(const AName: string; AProc: TTestClosure;
  const AContains: string; ADummy: Integer);
var
  LEntry: TTestEntry;
begin
  InitClosureEntry(LEntry, AName, AProc);
  LEntry.Kind               := ekShouldFail;
  LEntry.ShouldFailContains := AContains;
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

procedure TTestSuite.TestSeq(const AName: string; AProc: TTestProc);
var
  LEntry: TTestEntry;
begin
  InitProcEntry(LEntry, AName, AProc);
  LEntry.Sequential := True;
  RegisterEntry(Tests, LEntry);
end;

procedure TTestSuite.TestSeq(const AName: string; AProc: TTestClosure);
var
  LEntry: TTestEntry;
begin
  InitClosureEntry(LEntry, AName, AProc);
  LEntry.Sequential := True;
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

procedure TTestSuite.Cleanup(AProc: TTestProc);
var
  LProc: TTestProc;
  LIdx: Integer;
begin
  LProc := AProc;
  LIdx := GrowCleanups(EachCleanups);
  EachCleanups[LIdx] := procedure
  begin
    LProc;
  end;
end;

procedure TTestSuite.Cleanup(AProc: TTestClosure);
var
  LIdx: Integer;
begin
  LIdx := GrowCleanups(EachCleanups);
  EachCleanups[LIdx] := AProc;
end;

procedure TTestSuite.Tag(const ATags: array of string);
var
  I, J, LOldLen: Integer;
  LNewTags: specialize TArray<string>;
begin
  if Length(ATags) = 0 then Exit;
  for I := 0 to High(Tests) do
  begin
    LOldLen := Length(Tests[I].Tags);
    SetLength(LNewTags, LOldLen + Length(ATags));
    for J := 0 to LOldLen - 1 do
      LNewTags[J] := Tests[I].Tags[J];
    for J := 0 to High(ATags) do
      LNewTags[LOldLen + J] := ATags[J];
    Tests[I].Tags := LNewTags;
  end;
end;

function TTestSuite.WithConfig(const AConfig: TTestConfig): TTestSuite;
begin
  Result := Self;
  Result.Config := AConfig;
end;

function TTestSuite.WithSetup(AProc: TTestProc): TTestSuite;
begin
  Result := Self;
  Result.SetSetup(AProc);
end;

function TTestSuite.WithSetup(AProc: TTestClosure): TTestSuite;
begin
  Result := Self;
  Result.SetSetup(AProc);
end;

function TTestSuite.WithTeardown(AProc: TTestProc): TTestSuite;
begin
  Result := Self;
  Result.SetTeardown(AProc);
end;

function TTestSuite.WithTeardown(AProc: TTestClosure): TTestSuite;
begin
  Result := Self;
  Result.SetTeardown(AProc);
end;

function TTestSuite.WithBeforeEach(AProc: TTestProc): TTestSuite;
begin
  Result := Self;
  Result.OnBeforeEach(AProc);
end;

function TTestSuite.WithBeforeEach(AProc: TTestClosure): TTestSuite;
begin
  Result := Self;
  Result.OnBeforeEach(AProc);
end;

function TTestSuite.WithAfterEach(AProc: TTestProc): TTestSuite;
begin
  Result := Self;
  Result.OnAfterEach(AProc);
end;

function TTestSuite.WithAfterEach(AProc: TTestClosure): TTestSuite;
begin
  Result := Self;
  Result.OnAfterEach(AProc);
end;

function TTestSuite.WithEachCleanup(AProc: TTestProc): TTestSuite;
begin
  Result := Self;
  Result.Cleanup(AProc);
end;

function TTestSuite.WithEachCleanup(AProc: TTestClosure): TTestSuite;
begin
  Result := Self;
  Result.Cleanup(AProc);
end;

function TTestSuite.Run: Boolean;
var
  LResult: TTestRunResult;
begin
  Result := RunWithResult(LResult);
end;

function TTestSuite.RunWithResult(out AResult: TTestRunResult;
  ADeferCleanup: Boolean): Boolean;
var
  I, J: Integer;
  LEntry: TTestEntry;
  LStatus: TTestStatus;
  LSubCtx: TTestContext;
  LSubCtxI: ITestContext;
  LPass, LFail, LSkip: Integer;
  LLastFailMsg: string;
  LWasPassed: Boolean;
  LTestResult: TTestResult;
  LAppender: TTestResultAppender;
  LConfig: TTestConfig;
  LOutSink: IOutputSink;
  LErrSink: IOutputSink;
  LGTestTimeoutMs: Integer;
  LTotalRetries: Integer;
  LRetriesLeft: Integer;
  LStart: TInstant;
  LRepeatCount: Integer;
  LRepeatI: Integer;
  LTagFilter: string;
  LDisplayName: string;
  LProgressTotal: Integer;
  LProgressCurrent: Integer;
  LProgressPrefix: string;
  LIdx: Integer;
  LRunStart: TInstant;
  LRunTimeout: TDuration;
  LSuiteStart: TInstant;  { suite-level duration tracking }
  LBeforeEachPassed: Boolean;
  LBeforeEachFailMsg: string;
  LCache: TTestCache;
  LCacheKey: string;
  LCacheEntry: TCacheEntry;
  LCacheHit: Boolean;
  LLeak0: Integer;
begin
  ApplyCLIArgs;
  LSuiteStart := TInstant.Now;
  AResult := TTestRunResult.Create(Name);
  LLeak0 := GetTimeoutWorkerLeakCount;
  LPass := 0;
  LFail := 0;
  LSkip := 0;
  LLastFailMsg := '';
  LAppender := nil; { R5-24: will be created inside try block to prevent leak }
  LConfig := ResolveConfig(Config);
  LOutSink := ResolveOutSink(LConfig);
  LErrSink := ResolveErrSink(LConfig);
  LGTestTimeoutMs := GetTestTimeout(LConfig);
  LTagFilter := GetTagFilter(LConfig);
  LProgressCurrent := 0;
  { Cache setup }
  if LConfig.CacheEnabled then
  begin
    if LConfig.CacheDir <> '' then
      LCache := TTestCache.Create(LConfig.CacheDir)
    else
      LCache := TTestCache.Create('.nextpas/test-cache');
    LCacheKey := LCache.ComputeKey(SourceFiles, GetCompilerVersion, LConfig, Name);
  end
  else
  begin
    LCache := Default(TTestCache);
    LCacheKey := '';
  end;
  { Pre-count eligible tests for progress display }
  if LConfig.ShowProgress then
  begin
    LProgressTotal := 0;
    for I := 0 to High(Tests) do
      if IsTestEligible(Tests[I], LConfig, LTagFilter) then
        Inc(LProgressTotal);
  end
  else
    LProgressTotal := 0;
  try
  LAppender := TTestResultAppender.Create;

  LRunStart := TInstant.Now;
  if LConfig.RunTimeoutSec > 0 then
    LRunTimeout := TDuration.FromSeconds(LConfig.RunTimeoutSec)
  else
    LRunTimeout := TDuration.Zero;

  LOutSink.WriteLn('');
  WriteSuiteHeader(Name, IntToStr(Length(Tests)) + ' tests',
    LOutSink, LConfig);

  { Shuffle tests if enabled }
  if LConfig.ShuffleSeed <> 0 then
  begin
    ShuffleEntries(Tests, LConfig.ShuffleSeed);
    if LConfig.ShuffleSeed = -1 then
      LOutSink.WriteLn(AnsiDim(
        '  shuffled (random)', LConfig))
    else
      LOutSink.WriteLn(AnsiDim(
        '  shuffled (seed=' + IntToStr(LConfig.ShuffleSeed) + ')', LConfig));
  end;

  { Suite-level setup (uses shared helper) }
  if not RunSetup(LConfig, LSkip, LLastFailMsg) then
  begin
    HandleSetupFailure(AResult, LSkip, LLastFailMsg, LOutSink, LConfig, True, ADeferCleanup);
    Result := False;
    Exit;
  end;
  { R4-01: ETestSkipped from setup — skip all tests, don't fall through.
    Return False because the suite didn't pass (AllPassed=False, Failed=1).
    P1 fix: setup skip semantic contradiction. }
  if LSkip > 0 then
  begin
    HandleSetupFailure(AResult, LSkip, LLastFailMsg, LOutSink, LConfig, True, ADeferCleanup);
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
    NoteHeapBaseline; { optional leak delta (F-05/F-11); no-op without probe }

    { Global run timeout check }
    if (LRunTimeout > TDuration.Zero) and
       (LRunStart.Elapsed >= LRunTimeout) then
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
    if not IsTestEligible(LEntry, LConfig, LTagFilter, True) then
    begin
      { Not counted as pass/fail/skip — just invisible }
      Continue;
    end;

    { Short mode — skip tests marked with ShortSkip }
    if LConfig.ShortMode and LEntry.ShortSkip then
    begin
      EmitResult(tsSkipped, LEntry, 'skipped: short mode', LSkip,
        AResult.Results, LOutSink, LConfig);
      Continue;
    end;

    { Cache lookup — skip execution if cached result is valid }
    LCacheHit := False;
    if LConfig.CacheEnabled and (LCacheKey <> '') then
    begin
      LCacheHit := LCache.Get(LCacheKey, LEntry.Name, LCacheEntry);
      if LCacheHit then
      begin
        LDisplayName := GetDisplayName(LEntry);
        LStatus := TTestStatus(LCacheEntry.Status);
        LLastFailMsg := LCacheEntry.Message;
        IncByStatus(LStatus, LPass, LFail, LSkip);
        LTestResult := MakeTestResult(LEntry.Name, LStatus, LLastFailMsg,
          LCacheEntry.Duration);
        AppendResult(AResult.Results, LTestResult);
        WriteTestOutput(LStatus, LDisplayName + ' (cached)',
          LLastFailMsg, LEntry.SkipReason,
          LCacheEntry.Duration, LOutSink, LConfig);
        Continue;
      end;
    end;

    { Progress counter }
    Inc(LProgressCurrent);
    if LConfig.ShowProgress then
      LProgressPrefix := '[' + IntToStr(LProgressCurrent) + '/' +
        IntToStr(LProgressTotal) + '] '
    else
      LProgressPrefix := '';

    { Skip check BEFORE BeforeEach — skipped tests don't need hooks }
    if LEntry.Kind = ekSkipped then
    begin
      EmitResult(tsSkipped, LEntry, LEntry.SkipReason, LSkip,
        AResult.Results, LOutSink, LConfig);
      Continue;
    end;

    { R4-03: track whether BeforeEach passed; on failure still run AfterEach/EachCleanups }
    LBeforeEachPassed := True;
    LBeforeEachFailMsg := '';

    { BeforeEach (only for non-skipped tests) }
    if Assigned(BeforeEach) or Assigned(BeforeEachClosure) then
    begin
      try
        if Assigned(BeforeEach) then BeforeEach else BeforeEachClosure();
      except
        on E: ETestSkipped do
        begin
          LBeforeEachPassed := False;
          LStatus := tsSkipped;
          LBeforeEachFailMsg := E.Message;
        end;
        on E: Exception do
        begin
          LBeforeEachPassed := False;
          LStatus := tsError;
          LBeforeEachFailMsg := 'beforeEach failed: ' + E.Message;
        end;
      end;
    end;

    { R5-02: set LStart before BeforeEach check so all paths have valid duration }
    LStart := TInstant.Now;
    LDisplayName := GetDisplayName(LEntry);

    if not LBeforeEachPassed then
    begin
      { R4-03: BeforeEach failed — skip test execution but still run AfterEach/EachCleanups }
      LLastFailMsg := LBeforeEachFailMsg;
      IncByStatus(LStatus, LPass, LFail, LSkip);
    end
    else
    begin
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
          on E: Exception do
          begin
            ClassifyTestException(E, LStatus, LLastFailMsg);
            if LStatus <> tsSkipped then Inc(LFail);
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
          on E: Exception do
          begin
            ClassifyTestException(E, LStatus, LLastFailMsg);
            IncByStatus(LStatus, LPass, LFail, LSkip);
          end;
        end;
      end
      else if LEntry.Kind = ekShouldFail then
      begin
        RunShouldFailEntry(LEntry, LStatus, LLastFailMsg);
        IncByStatus(LStatus, LPass, LFail, LSkip);
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
          LStart := TInstant.Now;
          try
            if (LGTestTimeoutMs > 0) and (LEntry.Kind = ekTest) and
               (Assigned(LEntry.Proc) or Assigned(LEntry.Closure)) then
            begin
              if Assigned(LEntry.Closure) then
                RunTestWithTimeout(LEntry.Closure, LGTestTimeoutMs,
                  LConfig, LStatus, LLastFailMsg)
              else
                RunTestWithTimeout(LEntry.Proc, LGTestTimeoutMs,
                  LConfig, LStatus, LLastFailMsg);
            end
            else
            begin
              if Assigned(LEntry.Closure) then
                LEntry.Closure()
              else
                LEntry.Proc;
            end;
          except
            on E: Exception do
              ClassifyTestException(E, LStatus, LLastFailMsg);
          end;

          if (LStatus = tsPassed) or (LStatus = tsSkipped) or (LRetriesLeft <= 0) then
            Break;

          { Retry: print hint and loop }
          Dec(LRetriesLeft);
          WriteRetryHint(LTotalRetries - LRetriesLeft, LTotalRetries,
            LOutSink, LConfig);
        until False;
        end; { end repeat loop }

        IncByStatus(LStatus, LPass, LFail, LSkip);

      end;
    except
      on E: Exception do
      begin
        ClassifyTestException(E, LStatus, LLastFailMsg);
        IncByStatus(LStatus, LPass, LFail, LSkip);
      end;
    end;
    end; { R4-03: end if LBeforeEachPassed }

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

    { SoftFail (Go t.Error): if body/hooks soft-failed but status still pass,
      flip to tsFailed and correct pass/fail counters.
      v8.28: ApplySoftFails also returns True for already-failed + also-soft;
      only adjust counters when we actually flipped pass→fail. }
    LWasPassed := (LStatus = tsPassed);
    if ApplySoftFails(LStatus, LLastFailMsg) then
    begin
      if LWasPassed then
      begin
        Inc(LFail);
        if LPass > 0 then
          Dec(LPass);
      end;
    end;

    { Record test result }
    LTestResult := MakeTestResult(LEntry.Name, LStatus, LLastFailMsg,
      LStart.Elapsed.AsMilliseconds);
    { Copy captured log lines on failure/error or verbose mode for report output }
    if (LSubCtx <> nil) and (Length(LSubCtx.FLogLines) > 0) and
       ((LStatus in [tsFailed, tsError]) or LConfig.VerboseMode) then
      LTestResult.CapturedLog := LSubCtx.FLogLines;
    AppendResult(AResult.Results, LTestResult);

    { Cache store — persist result for future runs }
    if LConfig.CacheEnabled and (LCacheKey <> '') then
    begin
      LCacheEntry.Status := Ord(LStatus);
      LCacheEntry.Message := LLastFailMsg;
      LCacheEntry.Duration := LStart.Elapsed.AsMilliseconds;
      LCacheEntry.Time := 0;
      LCache.Put(LCacheKey, LEntry.Name, LCacheEntry);
    end;

    { Output per-test — use DisplayName + progress prefix }
    WriteTestOutput(LStatus, LProgressPrefix + LDisplayName,
      LLastFailMsg, LEntry.SkipReason,
      LStart.Elapsed.AsMilliseconds, LOutSink, LConfig);
    { Auto-print captured log on failure/error — no --verbose needed }
    if (LSubCtx <> nil) and (Length(LSubCtx.FLogLines) > 0) and
       (LStatus in [tsFailed, tsError]) then
      WriteCapturedLog(LSubCtx.FLogLines, LOutSink, LConfig);

    LLastFailMsg := '';
    ReportLeakIfAny(LStatus, LConfig);
    SetCurrentTestContext(nil);
    LSubCtxI := nil;
    LSubCtx := nil;
    { FailFast: stop on hard failure/error only — SoftFail-only continues
      (Go: t.Error does not stop; t.Fatal does). SoftFailOnly = soft msgs
      and no InternalFail on this entry. }
    if LConfig.FailFast and (LStatus in [tsFailed, tsError]) then
    begin
      if (LStatus = tsError) or (not SoftFailOnly) then
      begin
        LOutSink.WriteLn(AnsiYellow(
          '  FAILFAST: stopping on first failure', LConfig));
        Break;
      end;
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
    if GExecState <> nil then
    begin
      Dispose(GExecState);
      GExecState := nil;
    end;
  end;

  { Dispose table test allocations (PTestCase/PTestCaseProc heap data).
    Must be called before FinalizeResults so that --count=N re-runs can
    skip already-disposed entries via the nil guard in the test loop.
    FCleanupDone guard prevents double-free when RunAllWithResult also
    calls CleanupTableAllocations after the full run.
    ADeferCleanup=True skips cleanup here — caller must call
    CleanupTableAllocations after all iterations complete (P1 fix:
    table repeat run skips). }
  if not ADeferCleanup then
    CleanupTableAllocations;

  AResult.Duration := LSuiteStart.Elapsed.AsMilliseconds;
  AResult.TimeoutWorkerLeaks := GetTimeoutWorkerLeakCount - LLeak0;
  if AResult.TimeoutWorkerLeaks < 0 then
    AResult.TimeoutWorkerLeaks := 0;
  if AResult.TimeoutWorkerLeaks > 0 then
    LErrSink.WriteLn(
      AnsiYellow('  WARNING: ', LConfig) +
      IntToStr(AResult.TimeoutWorkerLeaks) +
      ' timeout worker(s) stuck/detached this suite (TimeoutWorkerLeaks)');
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
    on E: ETestSkipped do
    begin
      { Intentional skip from setup — mark all tests as skipped, not failed }
      ASkipCount := Length(Tests);
      AErrorMsg := E.Message;
      Result := True; { not an error, just a skip }
    end;
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
  { Note: Do NOT nil-out Teardown/TeardownClosure here.
    RepeatAllCount re-runs the same suite, and teardown must run each time.
    The fixture owner is responsible for preventing double-free. }
end;

procedure TTestSuite.HandleSetupFailure(var AResult: TTestRunResult;
  ASkipCount: Integer; const AErrorMsg: string;
  const ASink: IOutputSink; const AConfig: TTestConfig;
  APopulateResults: Boolean; ADeferCleanup: Boolean);
{ Shared setup-failure handler for RunWithResult and RunParallelWithResult.
  APopulateResults: True for serial (populates AResult.Results with skipped entries),
  False for parallel (output only). }
var
  I: Integer;
  LTestResult: TTestResult;
begin
  for I := 0 to High(Tests) do
  begin
    if APopulateResults then
    begin
      LTestResult := MakeTestResult(Tests[I].Name, tsSkipped,
        'setup failed: ' + AErrorMsg, 0);
      AppendResult(AResult.Results, LTestResult);
    end;
    ASink.WriteLn('    ' + FormatStatusLine(tsSkipped, Tests[I].Name, AConfig));
  end;
  { Append a synthetic setup-failure entry so JUnit/JSON exporters can
    distinguish "setup failed" from "all tests individually skipped".
    The tsError status is counted separately by JUnitXML. }
  if APopulateResults then
  begin
    LTestResult := MakeTestResult('[setup]', tsError,
      'setup failed: ' + AErrorMsg, 0);
    AppendResult(AResult.Results, LTestResult);
  end;
  { R4-04: Cleanup table-test allocations on setup failure path (both serial
    and parallel). Without this, early Exit skips CleanupTableAllocations in
    the normal post-loop path, leaking PTestCase/PTestCaseProc data.
    ADeferCleanup=True skips cleanup — caller must call CleanupTableAllocations
    after all iterations complete. }
  if not ADeferCleanup then
    CleanupTableAllocations;
  { R4-08: Failed=1 to match the [setup] tsError entry }
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

function TTestSuite.EmitResult(AStatus: TTestStatus; const AEntry: TTestEntry;
  const AMsg: string; var ACounter: Integer;
  var AResults: specialize TArray<TTestResult>;
  const AOutSink: IOutputSink; const AConfig: TTestConfig): Boolean;
var
  LTestResult: TTestResult;
begin
  Inc(ACounter);
  LTestResult := MakeTestResult(AEntry.Name, AStatus, AMsg, 0);
  AppendResult(AResults, LTestResult);
  WriteTestOutput(AStatus, GetDisplayName(AEntry), AMsg, '', 0, AOutSink, AConfig);
  ReportLeakIfAny(AStatus, AConfig);
  Result := True; { caller should Continue }
end;

function TTestSuite.RunParallelWithResult(APool: IThreadPool;
  out AResult: TTestRunResult; ADeferCleanup: Boolean): Boolean;
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
  LCache: TTestCache;
  LCacheKey: string;
  LCacheEntry: TCacheEntry;
  LProcessed: array of Boolean;
  LCacheHits: array of Boolean;
  LLeak0: Integer;
  LErrSink: IOutputSink;
begin
  ApplyCLIArgs;
  AResult := TTestRunResult.Create(Name);
  LLeak0 := GetTimeoutWorkerLeakCount;
  LTotal := Length(Tests);
  LPass := 0;
  LFail := 0;
  LSkip := 0;
  LMtx := Mutex();
  LConfig := ResolveConfig(Config);
  LOutSink := ResolveOutSink(LConfig);
  LErrSink := ResolveErrSink(LConfig);
  LTagFilter := GetTagFilter(LConfig);
  { F-20: fail fast at suite start if any TestSubtest registered (not silent skip). }
  for I := 0 to High(Tests) do
    if Tests[I].Kind = ekSubtest then
    begin
      LErrSink.WriteLn(AnsiRed(
        'ERROR: TestSubtest "' + Tests[I].Name +
        '" cannot run under RunParallel (use serial Run)', LConfig));
      AResult.Failed := 1;
      AResult.AllPassed := False;
      Result := False;
      Exit;
    end;
  { Cache setup }
  if LConfig.CacheEnabled then
  begin
    if LConfig.CacheDir <> '' then
      LCache := TTestCache.Create(LConfig.CacheDir)
    else
      LCache := TTestCache.Create('.nextpas/test-cache');
    LCacheKey := LCache.ComputeKey(SourceFiles, GetCompilerVersion, LConfig, Name);
  end
  else
  begin
    LCache := Default(TTestCache);
    LCacheKey := '';
  end;

  LOutSink.WriteLn('');
  WriteSuiteHeader(Name, IntToStr(LTotal) + ' tests, parallel',
    LOutSink, LConfig);

  { Empty suite guard: skip thread spawn + batch dispatch entirely.
    Without this, the while-loop falls through with LBatchStart=0=LTotal,
    but the array allocation + thread-join scan still runs on garbage.
    Skip both setup and teardown for empty suites — no tests to run means
    no lifecycle hooks needed (P1 fix: empty parallel suite order inversion). }
  if LTotal = 0 then
  begin
    FinalizeResults(LConfig, AResult, 0, 0, 0);
    Result := LastRunPassed;
    Exit;
  end;

  { Pre-count eligible tests for progress display }
  LProgressCounter := 0;
  if LConfig.ShowProgress then
  begin
    LProgressTotal := 0;
    for I := 0 to High(Tests) do
      if IsTestEligible(Tests[I], LConfig, LTagFilter) then
        Inc(LProgressTotal);
  end
  else
    LProgressTotal := 0;

  { Suite-level setup (serial, uses shared helper) }
  if not RunSetup(LConfig, LSkip, LErrorMsg) then
  begin
    HandleSetupFailure(AResult, LSkip, LErrorMsg, LOutSink, LConfig, False, ADeferCleanup);
    Result := False;
    Exit;
  end;
  { R4-01: ETestSkipped from setup — skip all tests, don't fall through.
    Return False because the suite didn't pass (AllPassed=False, Failed=1).
    P1 fix: setup skip semantic contradiction. }
  if LSkip > 0 then
  begin
    HandleSetupFailure(AResult, LSkip, LErrorMsg, LOutSink, LConfig, False, ADeferCleanup);
    Result := False;
    Exit;
  end;

  SetLength(LThreads, LTotal);
  SetLength(LRecs, LTotal);
  SetLength(LResults, LTotal);
  SetLength(LProcessed, LTotal);
  SetLength(LCacheHits, LTotal);

  { Pre-fill records — each thread gets its own result slot }
  for I := 0 to High(Tests) do
  begin
    { Test filter — skip non-matching tests silently (same as serial mode:
      filtered tests are invisible, not counted as pass/fail/skip) }
    if not IsTestEligible(Tests[I], LConfig, LTagFilter, True) then
    begin
      LThreads[I] := TThreadID(0);
      LProcessed[I] := True;
      Continue;
    end;
    { Short mode — skip tests marked with ShortSkip (handle before thread spawn) }
    if LConfig.ShortMode and Tests[I].ShortSkip then
    begin
      LThreads[I] := TThreadID(0);
      LProcessed[I] := True;
      Inc(LSkip);
      LResults[I] := MakeTestResult(Tests[I].Name, tsSkipped,
        'skipped: short mode', 0);
      WriteTestOutput(tsSkipped, Tests[I].Name, '', 'short mode',
        0, LOutSink, LConfig);
      Continue;
    end;

    { Cache lookup — skip thread spawn if cached result is valid.
      Note: cache hit skips BeforeEach/AfterEach/EachCleanups — assumes
      tests are independent and idempotent. }
    if LConfig.CacheEnabled and (LCacheKey <> '') and
       LCache.Get(LCacheKey, Tests[I].Name, LCacheEntry) then
    begin
      LThreads[I] := TThreadID(0);
      LProcessed[I] := True;
      LCacheHits[I] := True;
      IncByStatus(TTestStatus(LCacheEntry.Status), LPass, LFail, LSkip);
      LResults[I] := MakeTestResult(Tests[I].Name,
        TTestStatus(LCacheEntry.Status), LCacheEntry.Message,
        LCacheEntry.Duration);
      WriteTestOutput(TTestStatus(LCacheEntry.Status),
        Tests[I].Name + ' (cached)', LCacheEntry.Message, '',
        LCacheEntry.Duration, LOutSink, LConfig);
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

  { Phase 1: Sequential tests — run serially before parallel batch.
    Go t.Parallel() inverse: tests with shared mutable state (DB, file,
    global vars) run first, one at a time, before parallel tests start.
    LProcessed[I] = true means: filter-excluded, ShortSkip, or cache-hit — skip. }
  for I := 0 to High(Tests) do
  begin
    if LProcessed[I] then
      Continue;
    if not Tests[I].Sequential then
      Continue;
    LProcessed[I] := True;
    ParallelWorkerProc(@LRecs[I]);
    { Mark as "already processed" — result is in LResults[I],
      which the final collection loop will pick up via Name <> ''. }
  end;

  { Phase 2: Parallel batch dispatch — skip Sequential tests (already done).
    Use BeginThread to ensure FPC properly initializes per-thread state
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
      if LProcessed[I] then
        Continue; { already processed: filter-excluded, ShortSkip, cache-hit, Phase 1 }
      if IsTestEligible(Tests[I], LConfig, LTagFilter) and
         not Tests[I].Sequential then
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
      if LProcessed[I] then
        Continue; { already processed }
      if not IsTestEligible(Tests[I], LConfig, LTagFilter) then
        Continue;
      if Tests[I].Sequential then
        Continue; { already ran in Phase 1 }
      LProcessed[I] := True;
      LThreads[I] := BeginThread(@ParallelThreadEntry, @LRecs[I]);
      if LThreads[I] = TThreadID(0) then
      begin
        LResults[I] := MakeTestResult(Tests[I].Name, tsError,
          'BeginThread failed', 0);
        LCacheHits[I] := True; { Don't cache system-level errors }
        LMtx.Acquire;
        try
          Inc(LFail);
        finally
          LMtx.Release;
        end;
      end;
      Inc(LSpawned);
      LBatchStart := I + 1;
    end;

    { Join this batch before spawning the next }
    for I := 0 to High(Tests) do
      if LThreads[I] <> TThreadID(0) then
        WaitForThreadTerminate(LThreads[I], 0);

    { Close thread handles — required on Windows to avoid kernel handle leak }
    for I := 0 to High(Tests) do
      if LThreads[I] <> TThreadID(0) then
        CloseThread(LThreads[I]);

    { Clear handles for reuse in next batch }
    FillChar(LThreads[0], Length(LThreads) * SizeOf(TThreadID), 0);
  end;

  { Suite-level teardown (uses shared helper) }
  RunTeardown(LConfig);

  { Collect results from threads that actually ran.
    Filter-excluded slots have LThreads[I]=TThreadID(0) and no result data.
    BeginThread-failed slots also have LThreads[I]=TThreadID(0) but have result data
    written directly (tsError + 'BeginThread failed'). }
  for I := 0 to High(Tests) do
  begin
    if (LThreads[I] <> TThreadID(0)) or (LResults[I].Status <> tsPassed) or
       (LResults[I].Name <> '') then
      AppendResult(AResult.Results, LResults[I]);
    { Cache store — persist result for future runs (skip cache-hit tests) }
    if LConfig.CacheEnabled and (LCacheKey <> '') and
       (LResults[I].Name <> '') and not LCacheHits[I] then
    begin
      LCacheEntry.Status := Ord(LResults[I].Status);
      LCacheEntry.Message := LResults[I].Message;
      LCacheEntry.Duration := LResults[I].Duration;
      LCacheEntry.Time := 0;
      LCache.Put(LCacheKey, LResults[I].Name, LCacheEntry);
    end;
  end;

  if not ADeferCleanup then
    CleanupTableAllocations;
  AResult.TimeoutWorkerLeaks := GetTimeoutWorkerLeakCount - LLeak0;
  if AResult.TimeoutWorkerLeaks < 0 then
    AResult.TimeoutWorkerLeaks := 0;
  if AResult.TimeoutWorkerLeaks > 0 then
    LErrSink.WriteLn(
      AnsiYellow('  WARNING: ', LConfig) +
      IntToStr(AResult.TimeoutWorkerLeaks) +
      ' timeout worker(s) stuck/detached this suite (TimeoutWorkerLeaks)');
  FinalizeResults(LConfig, AResult, LPass, LFail, LSkip);
  Result := LFail = 0;
  LastRunPassed := Result;
end;

{ ═════════════════════════════════════════════════════════════════════════════ }
{ TTestSuite — Summary, AllPassed, CleanupTableAllocations                    }
{ ═════════════════════════════════════════════════════════════════════════════ }

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
begin
  if not HasRun then
    Result := Run
  else
    Result := LastRunPassed;
end;

procedure TTestSuite.CleanupTableAllocations;
var
  I, J: Integer;
begin
  if FCleanupDone then Exit;
  FCleanupDone := True;
  for I := 0 to High(Tests) do
  begin
    if Tests[I].Kind = ekTableTest then
    begin
      if Tests[I].TableCase <> nil then
      begin
        for J := 0 to High(GTableCases) do
          if GTableCases[J] = Tests[I].TableCase then
          begin
            GTableCases[J] := nil;
            Break;
          end;
        Dispose(PTestCase(Tests[I].TableCase));
        Tests[I].TableCase := nil;
      end;
      if Tests[I].TableProc <> nil then
      begin
        for J := 0 to High(GTableProcs) do
          if GTableProcs[J] = Tests[I].TableProc then
          begin
            GTableProcs[J] := nil;
            Break;
          end;
        Dispose(PTestCaseProc(Tests[I].TableProc));
        Tests[I].TableProc := nil;
      end;
    end;
  end;
  for I := 0 to High(StubAllocations) do
    if GStubRegistry[StubAllocations[I]] <> nil then
    begin
      FreeMem(GStubRegistry[StubAllocations[I]]);
      GStubRegistry[StubAllocations[I]] := nil;
    end;
  StubAllocations := nil;
  for I := 0 to High(FixtureAllocations) do
    if GFixtureRegistry[FixtureAllocations[I]] <> nil then
    begin
      GFixtureRegistry[FixtureAllocations[I]].Free;
      GFixtureRegistry[FixtureAllocations[I]] := nil;
    end;
  FixtureAllocations := nil;
end;

initialization
  GMainThreadId := platform_thread_id;

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
  { FIX-B: dispose any table payloads whose suite was never cleaned }
  for GStubCleanupI := 0 to High(GTableCases) do
    if GTableCases[GStubCleanupI] <> nil then
      Dispose(PTestCase(GTableCases[GStubCleanupI]));
  GTableCases := nil;
  for GStubCleanupI := 0 to High(GTableProcs) do
    if GTableProcs[GStubCleanupI] <> nil then
      Dispose(PTestCaseProc(GTableProcs[GStubCleanupI]));
  GTableProcs := nil;

end.
