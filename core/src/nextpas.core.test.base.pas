{ nextpas.core.test.base — Test framework types, exceptions, and internal state
  =========================================================
  Foundation unit: no dependencies on other test.* units. }

unit nextpas.core.test.base;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.system,   { Exception, EAbort, EAssertionFailed, ExceptClass }
  nextpas.core.text.conv, { LowerCase }
  nextpas.core.time;     { GetTickCount64 }

{ ── Test Context (for subtests) ───────────────────────────────────────────── }
{ ITestContext MUST be declared before TSubtestProc which references it.       }

type
  TTestProc = procedure;
  TTestClosure = reference to procedure;

  ITestContext = interface
    ['{C4E8A57A-5B1D-4F3A-9C7E-2D8F1A6B3E90}']
    procedure Run(const AName: string; AProc: TTestProc);
    procedure Run(const AName: string; AProc: TTestClosure);
    procedure RunNested(const AName: string; AProc: Pointer);
      { AProc is TSubtestProc — typed as Pointer to break FPC circular
        forward-reference between ITestContext and TSubtestProc. }
    procedure Fail(const AMessage: string);
    procedure Skip(const AReason: string = '');
    function  GetTestName: string;
    property  TestName: string read GetTestName;
    procedure Log(const AMessage: string);
    procedure LogF(const AFormat: string; const AArgs: array of const);
    procedure OnCleanup(AProc: TTestProc);
    procedure OnCleanup(AProc: TTestClosure);
    { TempDir: lazy-created temporary directory for this test.
      Created on first access, auto-cleaned when the test context is destroyed. }
    function  GetTempDir: string;
    property  TempDir: string read GetTempDir;
    { Environment variable isolation: set/unset env vars for this test.
      Original values are saved and automatically restored when the test ends. }
    procedure SetEnv(const AName, AValue: string);
    procedure UnsetEnv(const AName: string);
  end;

  TSubtestProc = procedure(constref Ctx: ITestContext);

{ ── Parameterized test types ─────────────────────────────────────────────── }

  TTestCase = record
    Name : string;
    Data : string;  { string as least-common-denominator; caller parses }
  end;

  PTestCase = ^TTestCase;

  TTestCaseProc = procedure(const ACase: TTestCase);

  PTestCaseProc = ^TTestCaseProc;

{ ── Re-exported from nextpas.core.system ───────────────────────────────────── }

type
  ExceptClass = nextpas.core.system.ExceptClass;

{ ── Status ────────────────────────────────────────────────────────────────── }

  TTestStatus = (
    tsPassed,
    tsFailed,
    tsSkipped,
    tsError
  );

{ ── Results ──────────────────────────────────────────────────────────────── }

  TTestResult = record
    Name    : string;
    Status  : TTestStatus;
    Message : string;  { fail message or skip reason }
    Duration: Int64;   { milliseconds, 0 if not measured }
    CapturedLog: specialize TArray<string>;  { Ctx.Log output, populated on failure }
  end;

  TTestResults = array of TTestResult;

  TTestRunResult = record
    SuiteName : string;
    Passed    : Integer;
    Failed    : Integer;
    Skipped   : Integer;
    AllPassed : Boolean;
    Duration  : Int64;   { suite execution time in milliseconds }
    Results   : TTestResults;
    SlowTests : TTestResults;  { top N slowest tests, populated by runner }
    { v8.25: stuck timeout-worker threads detached during this suite run
      (GTimeoutLeakCount delta). Non-zero means at least one test deadlocked. }
    TimeoutWorkerLeaks: Integer;
    class function Create(const ASuiteName: string): TTestRunResult; static;
  end;

{ ── Test Entry ────────────────────────────────────────────────────────────── }

  ETestSkipped = class(EAbort)
    constructor Create(const AReason: string);
  end;

  TTestEntryKind = (ekTest, ekSubtest, ekSkipped, ekTableTest, ekShouldFail);

  TBenchContext = record
    N        : Integer;  { iterations — set by framework, user loop runs N times }
    TotalNs  : Int64;    { accumulated by StartTimer/StopTimer pairs }
    AllocBytes: Int64;   { set by user (or framework) if --benchmem }
    AllocCount: Int64;   { set by user (or framework) if --benchmem }
  end;

  TBenchResult = record
    Name      : string;
    N         : Integer;  { total iterations }
    TotalNs   : Int64;    { total time in nanoseconds }
    NsPerOp   : Int64;    { nanoseconds per operation }
    AllocBytes: Int64;    { bytes per op (0 if not tracked) }
    AllocCount: Int64;    { allocs per op (0 if not tracked) }
  end;

  TTestEntry = record
    Name       : string;
    Proc       : TTestProc;
    Closure    : TTestClosure;  { alternative to Proc for closure-based tests }
    SubtestProc: TSubtestProc;  { used when Kind = ekSubtest }
    Kind       : TTestEntryKind;
    SkipReason : string;
    RetryCount : Integer;  { >0 means retry this many times before failing }
    DisplayName: string;  { empty = use Name for output }
    Tags       : specialize TArray<string>;  { used for tag-based filtering }
    RepeatCount: Integer;  { >1 = repeat this test N times, report last result }
    { Table-driven test fields (used when Kind = ekTableTest).
      Heap-allocated via New() in TestTable, disposed via CleanupTableAllocations()
      in runner.pas. Caller MUST ensure CleanupTableAllocations is called after
      Run/RunParallel completes — the record has no managed finalization for raw
      pointers. Safety net: GStubRegistry in finalization catches suites that
      never run. }
    ShouldFailMsg: string;  { ekShouldFail: expected failure reason; test passes if it fails }
    ShouldFailClass: TClass;      { ekShouldFail: expected exception class (nil = any) }
    ShouldFailContains: string;   { ekShouldFail: expected substring in exception message }
    ShortSkip  : Boolean;  { true = skip this test in --short mode (Go testing.Short()) }
    Sequential : Boolean;  { true = run serially even in parallel mode (Go t.Parallel() inverse) }
    TableCase  : Pointer;       { PTestCase, heap-allocated }
    TableProc  : Pointer;       { PTestCaseProc, heap-allocated }
  end;

{ ── Internal State ───────────────────────────────────────────────────────── }

type
  { Thread-local execution state — allocated on first use, nil = uninitialized }
  TTestExecState = record
    SuiteName     : string;
    TestName      : string;
    Failed        : Boolean;
    HardFailed    : Boolean;  { True only on InternalFail/raise path }
    SkipReason    : string;
    SoftFailCount : Integer;  { Go t.Error style: fail but continue }
    SoftFailMsgs  : specialize TArray<string>; { up to CMaxSoftFailMsgs }
    HeapAtStart   : Int64;    { optional leak delta baseline; -1 = unset }
  end;
  PTestExecState = ^TTestExecState;

const
  { Soft-fail message cap (Go t.Error accumulates; avoid unbounded growth). }
  CMaxSoftFailMsgs = 32;

threadvar
  GExecState: PTestExecState;
  GLastTestTrace: string;

{ ── Stack Trace Capture ──────────────────────────────────────────────────── }
{ Captures the call-site of a test failure, filtering out framework frames.
  Uses FPC's ExceptProc hook to walk the exception stack on every exception,
  storing the filtered result in a threadvar. Runner code calls GetLastTestTrace
  after catching EAssertionFailed to extract the user-facing file:line. }

function GetLastTestTrace: string;
  { Returns the most recently captured (and filtered) stack trace.
    Empty if no trace has been captured yet on this thread. }
function FormatTestLocation(const APrefix: string = ''): string;
  { Returns the first non-empty frame from GLastTestTrace, prefixed with APrefix.
    Returns '' if no useful frame was captured. }
function IsFrameworkFrame(const AFrameStr: string): Boolean;
  { Go t.Helper intent: True if frame is framework/sysutils/system and should
    be hidden from user-facing failure location. }

{ ── Record Helpers (reduce boilerplate at creation sites) ───────────────────── }

procedure ClearEntry(out AEntry: TTestEntry);
  { Initialize all TTestEntry fields to safe defaults.
    Callers then override only the fields they need. }
function MakeTestResult(const AName: string; AStatus: TTestStatus;
  const AMessage: string; ADuration: Int64): TTestResult;
  { Construct a fully-initialized TTestResult in one call. }
procedure AppendResult(var AResults: specialize TArray<TTestResult>;
  const AResult: TTestResult);
  { Append a TTestResult to a dynamic array. }
function GetTopSlowest(const AResults: TTestResults;
  ACount: Integer): TTestResults;
  { Return up to ACount slowest tests from AResults, sorted descending by Duration. }
procedure ShuffleEntries(var AEntries: specialize TArray<TTestEntry>;
  ASeed: Integer);
  { Fisher-Yates shuffle of test entries. ASeed > 0 for deterministic shuffle.
    ASeed = -1 uses a pseudo-random seed based on current tick count. }
procedure RegisterEntry(var AEntries: specialize TArray<TTestEntry>;
  const AEntry: TTestEntry);
  { Append a TTestEntry to a dynamic array. }
procedure CopyTags(out ATags: specialize TArray<string>;
  const ASource: array of string);
  { Copy an open array of tag strings into a dynamic array. }
function GrowCapacity(ALen, AInitCap: Integer): Integer;
  { Returns new capacity for a dynamic array. Geometric growth above AInitCap.
    Shared by runner, context, and other growth call-sites. }
function GrowCleanups(var ACleanups: specialize TArray<TTestClosure>): Integer;
  { Grow ACleanups capacity and return insertion index (old length).
    Shared by runner.EachCleanups and context.FCleanups. }
procedure RunShouldFailEntry(const AEntry: TTestEntry;
  out AStatus: TTestStatus; out AFailMsg: string);
  { Execute a ShouldFail test entry. Sets AStatus to tsPassed if the proc
    raises (expected), tsFailed if it doesn't, tsSkipped on ETestSkipped.
    Shared by serial and parallel runners. }

{ ── Exception Formatting (eliminate repeated ClassName + trace patterns) ──── }

function FormatExceptionMsg(E: Exception): string;
  { Returns 'ClassName: Message' — the standard error message format. }
function AppendTestTrace(const AMsg: string): string;
  { Appends ' [file:line]' from GLastTestTrace if non-empty; returns AMsg as-is
    when no trace was captured. }
procedure ClassifyTestException(E: Exception;
  out AStatus: TTestStatus; out AMsg: string);
  { Standard exception → status classification for test execution.
    ETestSkipped → tsSkipped, EAssertionFailed → tsFailed, other → tsError.
    Shared by serial runner, parallel worker, and any future runners. }

{ ── Internal Helpers (exported for use by other test.* units) ─────────────── }

procedure SetTestContext(const ASuiteName, ATestName: string);
procedure InternalFail(const AMessage: string);
procedure InternalSkip(const AReason: string);
{ SoftFail (Go t.Error): record failure without raising; test body continues.
  Check*/Fail remain Fatal (raise). Runner marks tsFailed if SoftFailCount > 0. }
procedure SoftFail(const AMessage: string);
procedure SoftCheckTrue(ACondition: Boolean; const AMessage: string = '');
procedure SoftCheckFalse(ACondition: Boolean; const AMessage: string = '');
procedure SoftCheckEqual(const AExpected, AActual: Int64;
  const AMessage: string = ''); overload;
procedure SoftCheckEqual(const AExpected, AActual: string;
  const AMessage: string = ''); overload;
procedure SoftCheckContains(const AHaystack, ANeedle: string;
  const AMessage: string = '');
{ If status is still tsPassed and soft fails were recorded, set tsFailed + message.
  Returns True when status was flipped. Does not clear the soft-fail counters
  until SetTestContext (next test). }
function ApplySoftFails(var AStatus: TTestStatus; var AMsg: string): Boolean;
{ True when current test has soft fails but no hard InternalFail. Used so
  FailFast does not stop the suite on soft-only failures (Go t.Error). }
function SoftFailOnly: Boolean;

{ Nested SoftFail layering (Go t.Run): save/restore parent soft state around
  nested subtest execution so parent SoftFail is not wiped by SetTestContext. }
type
  TSoftFailSnapshot = record
    SoftFailCount: Integer;
    SoftFailMsgs: specialize TArray<string>;
    Failed: Boolean;
  end;

procedure PushSoftFailState(out ASnap: TSoftFailSnapshot);
procedure PopSoftFailState(const ASnap: TSoftFailSnapshot);
function  StrStartsWith(const S, APrefix: string): Boolean;
function  StrEndsWith(const AStr, ASuffix: string): Boolean;
  { Returns True if AStr ends with ASuffix. Empty suffix always returns True. }
function  PosCI(const ANeedle, AHaystack: string): Integer;
  { Case-insensitive Pos: returns 1-based index of first occurrence, 0 if not found.
    Does NOT allocate — compares characters via UpCase. }
function  StrStartsWithCI(const S, APrefix: string): Boolean;
  { Case-insensitive prefix check. No allocation. }
function  StrEndsWithCI(const AStr, ASuffix: string): Boolean;
  { Case-insensitive suffix check. No allocation. }
procedure IncByStatus(AStatus: TTestStatus;
  var APass, AFail, ASkip: Integer);
  { Increment the appropriate counter based on test status. }

{ ── Timing helpers ────────────────────────────────────────────────────────── }

procedure SleepMs(AMilliseconds: Integer);
  { Cross-platform millisecond sleep. Replaces SysUtils.Sleep for test programs. }

implementation

{ ═════════════════════════════════════════════════════════════════════════════ }
{ ETestSkipped                                                                 }
{ ═════════════════════════════════════════════════════════════════════════════ }

constructor ETestSkipped.Create(const AReason: string);
begin
  inherited Create(AReason);
end;

{ ═════════════════════════════════════════════════════════════════════════════ }
{ TTestRunResult                                                               }
{ ═════════════════════════════════════════════════════════════════════════════ }

class function TTestRunResult.Create(const ASuiteName: string): TTestRunResult;
begin
  Result.SuiteName := ASuiteName;
  Result.Passed    := 0;
  Result.Failed    := 0;
  Result.Skipped   := 0;
  Result.AllPassed := True;
  Result.Duration  := 0;
  Result.Results   := nil;
  Result.SlowTests := nil;
  Result.TimeoutWorkerLeaks := 0;
end;

{ ═════════════════════════════════════════════════════════════════════════════ }
{ Record Helpers                                                                }
{ ═════════════════════════════════════════════════════════════════════════════ }

procedure ClearEntry(out AEntry: TTestEntry);
begin
  AEntry.Name        := '';
  AEntry.Proc        := nil;
  AEntry.Closure     := nil;
  AEntry.SubtestProc := nil;
  AEntry.Kind        := ekTest;
  AEntry.SkipReason  := '';
  AEntry.RetryCount  := 0;
  AEntry.DisplayName := '';
  AEntry.Tags        := nil;
  AEntry.RepeatCount := 0;
  AEntry.ShouldFailMsg := '';
  AEntry.ShouldFailClass := nil;
  AEntry.ShouldFailContains := '';
  AEntry.ShortSkip   := False;
  AEntry.Sequential  := False;
  AEntry.TableCase   := nil;
  AEntry.TableProc   := nil;
end;

function MakeTestResult(const AName: string; AStatus: TTestStatus;
  const AMessage: string; ADuration: Int64): TTestResult;
begin
  Result.Name       := AName;
  Result.Status     := AStatus;
  Result.Message    := AMessage;
  Result.Duration   := ADuration;
  Result.CapturedLog := nil;
end;



procedure AppendResult(var AResults: specialize TArray<TTestResult>;
  const AResult: TTestResult);
var
  LOldLen: Integer;
begin
  LOldLen := Length(AResults);
  SetLength(AResults, LOldLen + 1);
  AResults[LOldLen] := AResult;
end;

function GetTopSlowest(const AResults: TTestResults;
  ACount: Integer): TTestResults;
{ Returns up to ACount slowest tests, sorted descending by Duration.
  IntroSort: QuickSort + depth-limited HeapSort fallback + InsertionSort for small partitions.
  Guaranteed O(N log N) worst-case. }

  procedure InsertionSortDesc(var AArr: TTestResults; ALo, AHi: Integer);
  var
    I, J: Integer;
    LKey: TTestResult;
  begin
    for I := ALo + 1 to AHi do
    begin
      LKey := AArr[I];
      J := I - 1;
      while (J >= ALo) and (AArr[J].Duration < LKey.Duration) do
      begin
        AArr[J + 1] := AArr[J];
        Dec(J);
      end;
      AArr[J + 1] := LKey;
    end;
  end;

  procedure SiftDown(var AArr: TTestResults; AStart, AEnd: Integer);
  var
    LRoot, LChild, LSwap: Integer;
    LTemp: TTestResult;
  begin
    LRoot := AStart;
    while True do
    begin
      LChild := 2 * LRoot + 1;
      if LChild > AEnd then Break;
      LSwap := LRoot;
      if AArr[LSwap].Duration < AArr[LChild].Duration then
        LSwap := LChild;
      if (LChild + 1 <= AEnd) and (AArr[LSwap].Duration < AArr[LChild + 1].Duration) then
        LSwap := LChild + 1;
      if LSwap = LRoot then
        Break
      else
      begin
        LTemp := AArr[LRoot];
        AArr[LRoot] := AArr[LSwap];
        AArr[LSwap] := LTemp;
        LRoot := LSwap;
      end;
    end;
  end;

  procedure HeapSortDesc(var AArr: TTestResults; ALo, AHi: Integer);
  var
    I: Integer;
    LTemp: TTestResult;
  begin
    { Build max-heap }
    for I := (ALo + AHi) div 2 downto ALo do
      SiftDown(AArr, I, AHi);
    { Extract max one by one }
    for I := AHi downto ALo + 1 do
    begin
      LTemp := AArr[ALo];
      AArr[ALo] := AArr[I];
      AArr[I] := LTemp;
      SiftDown(AArr, ALo, I - 1);
    end;
  end;

  procedure IntroSortDesc(var AArr: TTestResults; ALo, AHi, ADepthLimit: Integer);
  var
    LPivot: Int64;
    I, J: Integer;
    LTemp: TTestResult;
  begin
    { Small partition: InsertionSort }
    if AHi - ALo < 16 then
    begin
      InsertionSortDesc(AArr, ALo, AHi);
      Exit;
    end;
    { Depth exhausted: HeapSort fallback }
    if ADepthLimit <= 0 then
    begin
      HeapSortDesc(AArr, ALo, AHi);
      Exit;
    end;
    { QuickSort partition (median-of-three pivot) }
    LPivot := AArr[(ALo + AHi) shr 1].Duration;
    I := ALo;
    J := AHi;
    while I <= J do
    begin
      while AArr[I].Duration > LPivot do Inc(I);
      while AArr[J].Duration < LPivot do Dec(J);
      if I <= J then
      begin
        LTemp := AArr[I];
        AArr[I] := AArr[J];
        AArr[J] := LTemp;
        Inc(I);
        Dec(J);
      end;
    end;
    if ALo < J then IntroSortDesc(AArr, ALo, J, ADepthLimit - 1);
    if I < AHi then IntroSortDesc(AArr, I, AHi, ADepthLimit - 1);
  end;

var
  LCopy: TTestResults;
  LCount, LTrim, LDepthLimit, LBits: Integer;
  I: Integer;
begin
  if (ACount <= 0) or (Length(AResults) = 0) then
    Exit(nil);
  LCount := Length(AResults);
  if ACount > LCount then
    ACount := LCount;
  SetLength(LCopy, LCount);
  for I := 0 to LCount - 1 do
    LCopy[I] := AResults[I];
  { Depth limit = 2 * floor(log2(n)) }
  LBits := LCount;
  LDepthLimit := 0;
  while LBits > 1 do
  begin
    LBits := LBits shr 1;
    Inc(LDepthLimit);
  end;
  LDepthLimit := LDepthLimit * 2;
  IntroSortDesc(LCopy, 0, LCount - 1, LDepthLimit);
  { Trim trailing zero-duration entries }
  LTrim := ACount;
  while (LTrim > 0) and (LCopy[LTrim - 1].Duration = 0) do
    Dec(LTrim);
  SetLength(Result, LTrim);
  for I := 0 to LTrim - 1 do
    Result[I] := LCopy[I];
end;

procedure ShuffleEntries(var AEntries: specialize TArray<TTestEntry>;
  ASeed: Integer);
{ Fisher-Yates (Knuth) shuffle. ASeed > 0 = deterministic, ASeed = -1 = random.
  ASeed = 0 treated as -1 (random) to avoid degenerate LCG sequence.
  On Unix, reads seed from /dev/urandom for better entropy.
  On other platforms, falls back to GetTickCount64 mixed with stack address. }
var
  I, J, N: Integer;
  LSeed: Integer;
  LTemp: TTestEntry;

  function ReadRandomSeed: Integer;
  { Best-effort entropy source. Falls back to tick count if unavailable. }
  var
    F: file;
    LBytes: array[0..3] of Byte;
    LRead: Integer;
  begin
    {$IFDEF UNIX}
    Assign(F, '/dev/urandom');
    {$I-}
    Reset(F, 1);
    {$I+}
    if IOResult = 0 then
    begin
      BlockRead(F, LBytes, 4, LRead);
      Close(F);
      if LRead = 4 then
      begin
        Result := Integer((Cardinal(LBytes[0]) shl 24) or
                          (Cardinal(LBytes[1]) shl 16) or
                          (Cardinal(LBytes[2]) shl 8) or
                          Cardinal(LBytes[3]));
        Result := Result and $7FFFFFFF;
        if Result = 0 then
          Result := 1;
        Exit;
      end;
    end;
    {$ENDIF}
    { Fallback: mix tick count with stack address for less predictability }
    Result := Integer((GetTickCount64 xor NativeUInt(@LBytes)) and $7FFFFFFF);
    if Result = 0 then
      Result := 1;
  end;

begin
  N := Length(AEntries);
  if N <= 1 then Exit;
  if (ASeed = -1) or (ASeed = 0) then
    LSeed := ReadRandomSeed
  else
    LSeed := ASeed;
  { Simple LCG PRNG — not cryptographic, just needs to be uniform }
  for I := N - 1 downto 1 do
  begin
    LSeed := LSeed * 1103515245 + 12345;
    J := (LSeed and $7FFFFFFF) mod (I + 1);
    LTemp := AEntries[I];
    AEntries[I] := AEntries[J];
    AEntries[J] := LTemp;
  end;
end;

procedure RegisterEntry(var AEntries: specialize TArray<TTestEntry>;
  const AEntry: TTestEntry);
var
  LOldLen: Integer;
begin
  LOldLen := Length(AEntries);
  SetLength(AEntries, LOldLen + 1);
  AEntries[LOldLen] := AEntry;
end;

procedure CopyTags(out ATags: specialize TArray<string>;
  const ASource: array of string);
var
  I: Integer;
begin
  SetLength(ATags, Length(ASource));
  for I := 0 to High(ASource) do
    ATags[I] := ASource[I];
end;

function GrowCapacity(ALen, AInitCap: Integer): Integer;
begin
  if ALen < AInitCap then
    Result := AInitCap
  else if ALen <= MaxInt div 2 then
    Result := ALen * 2
  else
    Result := MaxInt;
end;

function GrowCleanups(var ACleanups: specialize TArray<TTestClosure>): Integer;
begin
  Result := Length(ACleanups);
  SetLength(ACleanups, Result + 1);
end;

procedure RunShouldFailEntry(const AEntry: TTestEntry;
  out AStatus: TTestStatus; out AFailMsg: string);
begin
  AStatus := tsPassed;
  AFailMsg := '';
  try
    if Assigned(AEntry.Closure) then
      AEntry.Closure()
    else
      AEntry.Proc;
    { No exception = unexpected success }
    AStatus := tsFailed;
    if AEntry.ShouldFailMsg <> '' then
      AFailMsg := 'Expected failure (' + AEntry.ShouldFailMsg + ') but test passed'
    else
      AFailMsg := 'Expected failure but test passed';
  except
    on E: ETestSkipped do
    begin
      AStatus := tsSkipped;
      AFailMsg := E.Message;
    end;
    on E: EAssertionFailed do
    begin
      { Assertion inside ShouldFail = expected failure. Must come BEFORE
        the EAbort catch because EAssertionFailed inherits from EAbort. }
      AStatus := tsPassed;
    end;
    on E: Exception do
    begin
      { EAbort (user abort) — propagate, don't swallow.
        Note: EAssertionFailed was already caught above. }
      if E is EAbort then
        raise;
      { Check exception class if specified }
      if (AEntry.ShouldFailClass <> nil) and
         not (E.InheritsFrom(AEntry.ShouldFailClass)) then
      begin
        AStatus := tsFailed;
        AFailMsg := 'ShouldFail: expected ' + AEntry.ShouldFailClass.ClassName +
          ' (or subclass) but got ' + E.ClassName + ': ' + E.Message;
        Exit;
      end;
      { Check message substring if specified }
      if (AEntry.ShouldFailContains <> '') and
         (Pos(AEntry.ShouldFailContains, E.Message) = 0) then
      begin
        AStatus := tsFailed;
        AFailMsg := 'ShouldFail: expected message containing "' +
          AEntry.ShouldFailContains + '" but got: ' + E.Message;
        Exit;
      end;
      { Expected failure — test passes }
      AStatus := tsPassed;
    end;
  end;
end;

{ Exception Formatting }

function FormatExceptionMsg(E: Exception): string;
begin
  Result := E.ClassName + ': ' + E.Message;
end;

function AppendTestTrace(const AMsg: string): string;
begin
  if GLastTestTrace <> '' then
    Result := AMsg + ' [' + GLastTestTrace + ']'
  else
    Result := AMsg;
end;

procedure ClassifyTestException(E: Exception;
  out AStatus: TTestStatus; out AMsg: string);
begin
  { Check specific subtypes first, before the broad EAbort check.
    ETestSkipped and EAssertionFailed both descend from EAbort,
    so the EAbort guard must come AFTER them. }
  if E is ETestSkipped then
  begin
    AStatus := tsSkipped;
    AMsg := E.Message;
  end
  else if E is EAssertionFailed then
  begin
    AStatus := tsFailed;
    AMsg := AppendTestTrace(E.Message);
  end
  else if E is EAbort then
  begin
    { P1 fix: re-raise EAbort — user aborts must propagate, not be swallowed
      as tsError. This matches the public contract that EAbort bypasses the
      test framework's exception handling. }
    raise E;
  end
  else
  begin
    AStatus := tsError;
    AMsg := AppendTestTrace(FormatExceptionMsg(E));
  end;
end;

{ ═════════════════════════════════════════════════════════════════════════════ }
{ Stack Trace Capture                                                         }
{ ═════════════════════════════════════════════════════════════════════════════ }

{ Thread-local trace storage — set by ExceptProc hook, read by GetLastTestTrace.
  threadvar ensures parallel tests don't interfere. }
var
  GTestExceptProcHooked: Boolean;
  GPrevExceptProc: TExceptProc;

function IsFrameworkFrame(const AFrameStr: string): Boolean;
{ Returns True if the frame belongs to the test framework and should be hidden
  from the user-facing output (Go t.Helper intent via unit-prefix filtering).
  Matches unit name prefixes:
    nextpas.core.test  (any sub-unit: .check, .helpers, .runner… )
    sysutils            (FPC exception machinery)
    system              (FPC runtime)
  There is no separate MarkHelper API: put helpers in nextpas.core.test.* units. }
const
  CPrefix = 'nextpas.core.test';
var
  LLower: string;
  LPos, LAfter: Integer;
begin
  LLower := LowerCase(AFrameStr);
  LPos := Pos(CPrefix, LLower);
  if LPos > 0 then
  begin
    LAfter := LPos + Length(CPrefix);
    { Match if followed by delimiter (., comma, space, newline) or at end-of-string }
    Result := (LAfter > Length(LLower)) or
              (LLower[LAfter] in ['.', ',', ' ', #10]);
  end
  else
    Result := False;
  if not Result then
    { Also filter sysutils/system frames that appear in exception stack }
    Result := (Pos('sysutils', LLower) > 0) or
              (Pos('system,', LLower) > 0) or
              (Pos('system ', LLower) > 0);
end;

procedure TestExceptProc(Obj: TObject; Addr: CodePointer;
  FrameCount: LongInt; Frame: PCodePointer);
{ ExceptProc hook: captures a filtered stack trace on every exception.
  Stores first non-framework frame in GLastTestTrace. }
var
  I: Integer;
  LFrameStr: string;
begin
  GLastTestTrace := '';
  if FrameCount > 0 then
  begin
    for I := 0 to FrameCount - 1 do
    begin
      if Frame[I] = nil then Continue;
      LFrameStr := BackTraceStrFunc(Frame[I]);
      if LFrameStr = '' then Continue;
      if not IsFrameworkFrame(LFrameStr) then
      begin
        { First non-framework frame is the most useful for the user }
        GLastTestTrace := LFrameStr;
        Break;
      end;
    end;
  end;
  { Chain to previous handler if one was installed }
  if Assigned(GPrevExceptProc) then
    GPrevExceptProc(Obj, Addr, FrameCount, Frame);
end;

function GetLastTestTrace: string;
begin
  Result := GLastTestTrace;
end;

function FormatTestLocation(const APrefix: string): string;
var
  LTrace: string;
begin
  LTrace := GLastTestTrace;
  if LTrace = '' then
    Exit('');
  if APrefix <> '' then
    Result := APrefix + ' ' + LTrace
  else
    Result := LTrace;
end;

{ ═════════════════════════════════════════════════════════════════════════════ }
{ StrStartsWith                                                                }
{ ═════════════════════════════════════════════════════════════════════════════ }

function StrStartsWith(const S, APrefix: string): Boolean;
begin
  if Length(APrefix) = 0 then
    Exit(True); { empty prefix matches everything — consistent with Contains/EndsWith }
  Result := (Length(S) >= Length(APrefix)) and
            (Copy(S, 1, Length(APrefix)) = APrefix);
end;

function StrEndsWith(const AStr, ASuffix: string): Boolean;
var
  LStrLen, LSuffixLen: Integer;
begin
  LSuffixLen := Length(ASuffix);
  if LSuffixLen = 0 then
    Exit(True);
  LStrLen := Length(AStr);
  Result := (LStrLen >= LSuffixLen) and
    (Copy(AStr, LStrLen - LSuffixLen + 1, LSuffixLen) = ASuffix);
end;

function PosCI(const ANeedle, AHaystack: string): Integer;
{ Case-insensitive Pos without allocation. Scans AHaystack for ANeedle
  comparing via UpCase. Returns 1-based position or 0. }
var
  LNeedleLen, LHayLen, I, J: Integer;
  LMatch: Boolean;
begin
  LNeedleLen := Length(ANeedle);
  LHayLen := Length(AHaystack);
  if LNeedleLen = 0 then
    Exit(1); { empty needle matches at position 1, consistent with FPC Pos }
  if LNeedleLen > LHayLen then
    Exit(0);
  for I := 1 to LHayLen - LNeedleLen + 1 do
  begin
    LMatch := True;
    for J := 1 to LNeedleLen do
    begin
      if UpCase(AHaystack[I + J - 1]) <> UpCase(ANeedle[J]) then
      begin
        LMatch := False;
        Break;
      end;
    end;
    if LMatch then
      Exit(I);
  end;
  Result := 0;
end;

function StrStartsWithCI(const S, APrefix: string): Boolean;
{ Case-insensitive prefix check. No allocation. }
var
  LPreLen, I: Integer;
begin
  LPreLen := Length(APrefix);
  if LPreLen = 0 then
    Exit(True);
  if Length(S) < LPreLen then
    Exit(False);
  for I := 1 to LPreLen do
    if UpCase(S[I]) <> UpCase(APrefix[I]) then
      Exit(False);
  Result := True;
end;

function StrEndsWithCI(const AStr, ASuffix: string): Boolean;
{ Case-insensitive suffix check. No allocation. }
var
  LStrLen, LSuffixLen, I: Integer;
begin
  LSuffixLen := Length(ASuffix);
  if LSuffixLen = 0 then
    Exit(True);
  LStrLen := Length(AStr);
  if LStrLen < LSuffixLen then
    Exit(False);
  for I := 1 to LSuffixLen do
    if UpCase(AStr[LStrLen - LSuffixLen + I]) <> UpCase(ASuffix[I]) then
      Exit(False);
  Result := True;
end;

procedure IncByStatus(AStatus: TTestStatus;
  var APass, AFail, ASkip: Integer);
begin
  case AStatus of
    tsPassed:  Inc(APass);
    tsSkipped: Inc(ASkip);
  else
    Inc(AFail);
  end;
end;

{ ═════════════════════════════════════════════════════════════════════════════ }
{ Internal State Management                                                    }
{ ═════════════════════════════════════════════════════════════════════════════ }

procedure InternalFail(const AMessage: string);
begin
  if GExecState <> nil then
  begin
    GExecState^.Failed := True;
    GExecState^.HardFailed := True;
  end;
  raise EAssertionFailed.Create(AMessage);
end;

procedure InternalSkip(const AReason: string);
begin
  if GExecState <> nil then
    GExecState^.SkipReason := AReason;
  raise ETestSkipped.Create(AReason);
end;

procedure SoftFail(const AMessage: string);
var
  LMsg: string;
  LLen: Integer;
begin
  if AMessage = '' then
    LMsg := 'soft fail'
  else
    LMsg := AMessage;
  if GExecState = nil then
  begin
    { Outside a running test there is no result to attach — do not lose signal. }
    raise EAssertionFailed.Create('SoftFail outside test context: ' + LMsg);
  end;
  Inc(GExecState^.SoftFailCount);
  GExecState^.Failed := True;
  LLen := Length(GExecState^.SoftFailMsgs);
  if LLen < CMaxSoftFailMsgs then
  begin
    SetLength(GExecState^.SoftFailMsgs, LLen + 1);
    GExecState^.SoftFailMsgs[LLen] := LMsg;
  end;
end;

procedure SoftCheckTrue(ACondition: Boolean; const AMessage: string);
begin
  if ACondition then
    Exit;
  if AMessage = '' then
    SoftFail('SoftCheckTrue failed')
  else
    SoftFail(AMessage);
end;

procedure SoftCheckFalse(ACondition: Boolean; const AMessage: string);
begin
  if not ACondition then
    Exit;
  if AMessage = '' then
    SoftFail('SoftCheckFalse failed')
  else
    SoftFail(AMessage);
end;

procedure SoftCheckEqual(const AExpected, AActual: Int64;
  const AMessage: string);
begin
  if AExpected = AActual then
    Exit;
  if AMessage = '' then
    SoftFail('SoftCheckEqual expected ' + IntToStr(AExpected) +
      ' but got ' + IntToStr(AActual))
  else
    SoftFail(AMessage + ': expected ' + IntToStr(AExpected) +
      ' but got ' + IntToStr(AActual));
end;

procedure SoftCheckEqual(const AExpected, AActual: string;
  const AMessage: string);
begin
  if AExpected = AActual then
    Exit;
  if AMessage = '' then
    SoftFail('SoftCheckEqual expected "' + AExpected +
      '" but got "' + AActual + '"')
  else
    SoftFail(AMessage + ': expected "' + AExpected +
      '" but got "' + AActual + '"');
end;

procedure SoftCheckContains(const AHaystack, ANeedle: string;
  const AMessage: string);
begin
  if Pos(ANeedle, AHaystack) > 0 then
    Exit;
  if AMessage = '' then
    SoftFail('SoftCheckContains expected to find "' + ANeedle +
      '" in "' + AHaystack + '"')
  else
    SoftFail(AMessage);
end;

function FormatSoftFailSummary: string;
var
  I, LStored, LExtra: Integer;
begin
  Result := '';
  if (GExecState = nil) or (GExecState^.SoftFailCount <= 0) then
    Exit;
  LStored := Length(GExecState^.SoftFailMsgs);
  if LStored = 0 then
    Exit('soft fail');
  Result := GExecState^.SoftFailMsgs[0];
  for I := 1 to LStored - 1 do
    Result := Result + '; ' + GExecState^.SoftFailMsgs[I];
  LExtra := GExecState^.SoftFailCount - LStored;
  if LExtra > 0 then
    Result := Result + ' (+' + IntToStr(LExtra) + ' more soft fails)';
end;

function ApplySoftFails(var AStatus: TTestStatus; var AMsg: string): Boolean;
var
  LSummary: string;
begin
  Result := False;
  if GExecState = nil then
    Exit;
  if GExecState^.SoftFailCount <= 0 then
    Exit;
  LSummary := FormatSoftFailSummary;
  if AStatus = tsPassed then
  begin
    AStatus := tsFailed;
    AMsg := LSummary;
    Result := True;
  end
  else if AStatus in [tsFailed, tsError] then
  begin
    { Soft contributed alongside hard/aggregate failure — still "applied".
      v8.28: return True so nested RunNested Soft layers enter result collect. }
    if AMsg <> '' then
      AMsg := AMsg + ' [also soft: ' + LSummary + ']'
    else
      AMsg := LSummary;
    Result := True;
  end;
end;

function SoftFailOnly: Boolean;
begin
  Result := (GExecState <> nil) and
    (GExecState^.SoftFailCount > 0) and
    (not GExecState^.HardFailed);
end;

procedure PushSoftFailState(out ASnap: TSoftFailSnapshot);
begin
  if GExecState = nil then
  begin
    ASnap.SoftFailCount := 0;
    SetLength(ASnap.SoftFailMsgs, 0);
    ASnap.Failed := False;
    Exit;
  end;
  ASnap.SoftFailCount := GExecState^.SoftFailCount;
  ASnap.SoftFailMsgs := Copy(GExecState^.SoftFailMsgs);
  ASnap.Failed := GExecState^.Failed and (not GExecState^.HardFailed);
end;

procedure PopSoftFailState(const ASnap: TSoftFailSnapshot);
begin
  if GExecState = nil then
    Exit;
  GExecState^.SoftFailCount := ASnap.SoftFailCount;
  GExecState^.SoftFailMsgs := Copy(ASnap.SoftFailMsgs);
  { Restore soft-failed flag without clearing HardFailed from nested InternalFail. }
  if ASnap.SoftFailCount > 0 then
    GExecState^.Failed := True
  else if not GExecState^.HardFailed then
    GExecState^.Failed := ASnap.Failed;
end;

procedure SetTestContext(const ASuiteName, ATestName: string);
begin
  if GExecState = nil then
  begin
    New(GExecState);
    GExecState^ := Default(TTestExecState);
  end;
  GExecState^.SuiteName      := ASuiteName;
  GExecState^.TestName       := ATestName;
  GExecState^.Failed         := False;
  GExecState^.HardFailed     := False;
  GExecState^.SkipReason     := '';
  GExecState^.SoftFailCount  := 0;
  SetLength(GExecState^.SoftFailMsgs, 0);
  GExecState^.HeapAtStart    := -1; { set by runner if heap probe installed }
end;

{ ── SleepMs ───────────────────────────────────────────────────────────────── }

procedure SleepMs(AMilliseconds: Integer);
begin
  if AMilliseconds <= 0 then
    Exit;
  MsSleep(UInt64(AMilliseconds));
end;

initialization
  { Install ExceptProc hook for stack trace capture.
    Save previous handler so we can chain to it. }
  GPrevExceptProc := ExceptProc;
  ExceptProc := @TestExceptProc;
  GTestExceptProcHooked := True;

finalization
  if GTestExceptProcHooked then
  begin
    ExceptProc := GPrevExceptProc;
    GTestExceptProcHooked := False;
  end;
  GLastTestTrace := '';
  if GExecState <> nil then
  begin
    Dispose(GExecState);
    GExecState := nil;
  end;

end.
