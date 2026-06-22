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
    procedure RunNested(const AName: string; AProc: Pointer);
      { AProc is TSubtestProc — typed as Pointer to break circular reference
        between ITestContext and TSubtestProc declarations. }
    procedure Fail(const AMessage: string);
    procedure Skip(const AReason: string = '');
    function  GetTestName: string;
    property  TestName: string read GetTestName;
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
    { Table-driven test fields (used when Kind = ekTableTest) }
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

finalization
  if GExecState <> nil then
    Dispose(GExecState);

end.
