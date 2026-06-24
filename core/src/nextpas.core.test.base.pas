{ nextpas.core.test.base — Test framework types, exceptions, and internal state
  =========================================================
  Foundation unit: no dependencies on other test.* units. }

unit nextpas.core.test.base;

{$I nextpas.core.settings.inc}

interface

uses
  SysUtils,          { ExceptClass, EAbort, EAssertionFailed — FPC built-in, irreplaceable }
  nextpas.core.errors;

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

{ ── Re-exported from SysUtils (avoid facade depending on FPC RTL) ──────────── }

type
  ExceptClass = SysUtils.ExceptClass;

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
    Results   : TTestResults;
    class function Create(const ASuiteName: string): TTestRunResult; static;
  end;

{ ── Test Entry ────────────────────────────────────────────────────────────── }

  ETestSkipped = class(EAbort)
    constructor Create(const AReason: string);
  end;

  TTestEntryKind = (ekTest, ekSubtest, ekSkipped, ekTableTest);

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
    TableCase  : Pointer;       { PTestCase, heap-allocated }
    TableProc  : Pointer;       { PTestCaseProc, heap-allocated }
  end;

{ ── Internal State ───────────────────────────────────────────────────────── }

type
  { Thread-local execution state — allocated on first use, nil = uninitialized }
  TTestExecState = record
    SuiteName  : string;
    TestName   : string;
    Failed     : Boolean;
    SkipReason : string;
  end;
  PTestExecState = ^TTestExecState;

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
function FormatTestLocation(APrefix: string = ''): string;
  { Returns the first non-empty frame from GLastTestTrace, prefixed with APrefix.
    Returns '' if no useful frame was captured. }

{ ── Internal Helpers (exported for use by other test.* units) ─────────────── }

procedure SetTestContext(const ASuiteName, ATestName: string);
procedure InternalFail(const AMessage: string);
procedure InternalSkip(const AReason: string);
function  StrStartsWith(const S, APrefix: string): Boolean;

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
  Result.Results   := nil;
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
  from the user-facing output. Matches unit name prefixes:
    nextpas.core.test.  (any sub-unit of the test framework)
    sysutils             (FPC exception machinery)
    system               (FPC runtime) }
var
  LLower: string;
begin
  LLower := LowerCase(AFrameStr);
  Result := (Pos('nextpas.core.test.', LLower) > 0) or
            (Pos('nextpas.core.test,', LLower) > 0) or
            (Pos('nextpas.core.test ', LLower) > 0) or
            (Pos('nextpas.core.test'#10, LLower) > 0);
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

function FormatTestLocation(APrefix: string): string;
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

{ ═════════════════════════════════════════════════════════════════════════════ }
{ Internal State Management                                                    }
{ ═════════════════════════════════════════════════════════════════════════════ }

procedure InternalFail(const AMessage: string);
begin
  if GExecState <> nil then
    GExecState^.Failed := True;
  raise EAssertionFailed.Create(AMessage);
end;

procedure InternalSkip(const AReason: string);
begin
  if GExecState <> nil then
    GExecState^.SkipReason := AReason;
  raise ETestSkipped.Create(AReason);
end;

procedure SetTestContext(const ASuiteName, ATestName: string);
begin
  if GExecState = nil then
    New(GExecState);
  GExecState^.SuiteName  := ASuiteName;
  GExecState^.TestName   := ATestName;
  GExecState^.Failed     := False;
  GExecState^.SkipReason := '';
end;

initialization
  { Install ExceptProc hook for stack trace capture.
    Save previous handler so we can chain to it. }
  GPrevExceptProc := ExceptProc;
  ExceptProc := @TestExceptProc;
  GTestExceptProcHooked := True;

finalization
  { Restore previous ExceptProc handler }
  if GTestExceptProcHooked then
  begin
    ExceptProc := GPrevExceptProc;
    GTestExceptProcHooked := False;
  end;
  if GExecState <> nil then
    Dispose(GExecState);

end.
