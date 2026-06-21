{ nextpas.core.test — Advanced Pascal Unit Testing Framework
  =========================================================
  Dual API: procedural Check* + fluent IExpectation chain.
  Parallel execution, subtests, ANSI output, leak detection. }

unit nextpas.core.test;

{$I nextpas.core.settings.inc}

interface

uses
  SysUtils,
  Classes,
  nextpas.core.errors,
  nextpas.core.text.conv,
  nextpas.core.atomic,
  nextpas.core.sync,
  nextpas.core.thread.base,
  nextpas.core.thread.intf,
  nextpas.core.collections.base,
  nextpas.core.platform.thread;

{ ── Test Context (for subtests) ───────────────────────────────────────────── }
{ ITestContext MUST be declared before TSubtestProc which references it.       }

type
  TTestProc = procedure;

  ITestContext = interface
    ['{C4E8A57A-5B1D-4F3A-9C7E-2D8F1A6B3E90}']
    procedure Run(const AName: string; AProc: TTestProc);
    procedure RunNested(const AName: string; AProc: Pointer);
    procedure Fail(const AMessage: string);
    procedure Skip(const AReason: string = '');
    function  GetTestName: string;
    property  TestName: string read GetTestName;
  end;

  TSubtestProc = procedure(constref Ctx: ITestContext);

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

  TTestRunResult = record
    SuiteName : string;
    Passed    : Integer;
    Failed    : Integer;
    Skipped   : Integer;
    AllPassed : Boolean;
    Results   : specialize TArray<TTestResult>;
    class function Create(const ASuiteName: string): TTestRunResult; static;
  end;

{ ── Test Entry ────────────────────────────────────────────────────────────── }

  ETestSkipped = class(EAbort)
    constructor Create(const AReason: string);
  end;

  TTestEntryKind = (ekTest, ekSubtest, ekSkipped);

  TTestEntry = record
    Name       : string;
    Proc       : TTestProc;
    SubtestProc: TSubtestProc;  { used when Kind = ekSubtest }
    Kind       : TTestEntryKind;
    SkipReason : string;
  end;

{ ── Test Suite ────────────────────────────────────────────────────────────── }

  TTestSuite = record
    Name      : string;
    Tests     : specialize TArray<TTestEntry>;
    Setup     : TTestProc;
    Teardown  : TTestProc;
    BeforeEach: TTestProc;
    AfterEach : TTestProc;
    { Cached run results — set by Run/RunParallel }
    FLastRunPassed: Boolean;
    FHasRun       : Boolean;
    FLastPass     : Integer;
    FLastFail     : Integer;
    FLastSkip     : Integer;

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

    class function Create(const AName: string): TTestRunner; static;
    procedure Add(var ASuite: TTestSuite);
    function  RunAll: Boolean;
    function  RunAllParallel(APool: IThreadPool): Boolean;
    procedure Summary;
    function  AllPassed: Boolean;
  end;

{ ── IExpectation (fluent) ─────────────────────────────────────────────────── }

  IExpectation = interface
    ['{A7B3D91E-4C6F-4A28-B5D8-9E1F3C7A2B54}']
    function Not_: IExpectation;
    function ToEqual(const AExpected: string): IExpectation;
    function ToEqualInt(AExpected: Int64): IExpectation;
    function ToEqualBool(AExpected: Boolean): IExpectation;
    function ToBeTrue: IExpectation;
    function ToBeFalse: IExpectation;
    function ToBeNil: IExpectation;
    function ToBeNotNil: IExpectation;
    function ToContain(const ASubstr: string): IExpectation;
    function ToStartWith(const APrefix: string): IExpectation;
    function ToEndWith(const ASuffix: string): IExpectation;
    function ToBeGreaterThan(AExpected: Int64): IExpectation;
    function ToBeLessThan(AExpected: Int64): IExpectation;
    function ToBeInRange(ALow, AHigh: Int64): IExpectation;
    function ToHaveLength(AExpected: NativeInt): IExpectation;
    function ToRaise(AExceptionClass: ExceptClass;
      const AMessage: string = ''): IExpectation;
    function ToNotRaise: IExpectation;
  end;

{ ── Expect (fluent factory) ───────────────────────────────────────────────── }

function Expect(const AValue: string): IExpectation;
function ExpectInt(AValue: Int64): IExpectation;
function ExpectBool(AValue: Boolean): IExpectation;
function ExpectPtr(AValue: Pointer): IExpectation;
function ExpectProc(AProc: TTestProc): IExpectation;

{ ── Check* (procedural) ───────────────────────────────────────────────────── }

procedure Check(ACondition: Boolean; const AMessage: string = '');
procedure CheckEqual(const AExpected, AActual: string); overload;
procedure CheckEqual(AExpected, AActual: Int64); overload;
procedure CheckEqual(AExpected, AActual: Boolean); overload;
procedure CheckEqual(AExpected, AActual: Pointer); overload;
procedure CheckNotEqual(const AExpected, AActual: string); overload;
procedure CheckNotEqual(AExpected, AActual: Int64); overload;
procedure CheckTrue(AValue: Boolean; const AMessage: string = '');
procedure CheckFalse(AValue: Boolean; const AMessage: string = '');
procedure CheckNil(AValue: Pointer; const AMessage: string = '');
procedure CheckNotNil(AValue: Pointer; const AMessage: string = '');
procedure CheckContains(const AHaystack, ANeedle: string);
procedure CheckStartsWith(const AStr, APrefix: string);
procedure CheckEndsWith(const AStr, ASuffix: string);
procedure CheckSame(AExpected, AActual: Pointer; const AMessage: string = '');
procedure CheckInRange(AValue, ALow, AHigh: Int64);
procedure CheckLength(AValue: NativeInt; AExpected: NativeInt);
  { Note: parameter order is (actual, expected), not (expected, actual) like CheckEqual }
procedure CheckRaises(AExceptionClass: ExceptClass; AProc: TTestProc;
  const AMessage: string = '');
procedure CheckNoRaise(AProc: TTestProc; const AMessage: string = '');
procedure Fail(const AMessage: string);
procedure Skip(const AReason: string = '');

{ ── ANSI helpers (exposed for benchmarks) ─────────────────────────────────── }

function AnsiBold(const S: string): string;
function AnsiGreen(const S: string): string;
function AnsiRed(const S: string): string;
function AnsiYellow(const S: string): string;
function AnsiCyan(const S: string): string;
function AnsiDim(const S: string): string;

implementation

{ ═════════════════════════════════════════════════════════════════════════════ }
{ ETestSkipped                                                                 }
{ ═════════════════════════════════════════════════════════════════════════════ }

constructor ETestSkipped.Create(const AReason: string);
begin
  inherited Create(AReason);
end;

{ ═════════════════════════════════════════════════════════════════════════════ }
{ Local Helpers                                                                }
{ ═════════════════════════════════════════════════════════════════════════════ }

function StrStartsWith(const S, APrefix: string): Boolean;
begin
  if Length(APrefix) = 0 then
    Exit(True); { empty prefix matches everything — consistent with Contains/EndsWith }
  Result := (Length(S) >= Length(APrefix)) and
            (Copy(S, 1, Length(APrefix)) = APrefix);
end;

{ ═════════════════════════════════════════════════════════════════════════════ }
{ Internal State                                                               }
{ ═════════════════════════════════════════════════════════════════════════════ }

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

var
  { ANSI capability — set once in initialization, read-only after }
  GAnsiEnabled: Boolean = False;
  GAnsiChecked: Boolean = False;

{ ═════════════════════════════════════════════════════════════════════════════ }
{ ANSI Helpers                                                                 }
{ ═════════════════════════════════════════════════════════════════════════════ }

const
  ESC     = #27'[';
  C_RESET = ESC + '0m';
  C_BOLD  = ESC + '1m';
  C_GREEN = ESC + '32m';
  C_RED   = ESC + '31m';
  C_YELLOW= ESC + '33m';
  C_CYAN  = ESC + '36m';
  C_DIM   = ESC + '2m';

procedure InitAnsi;
begin
  if not GAnsiChecked then
  begin
    GAnsiChecked := True;
    {$IFDEF NEXTPAS_LINUX}
    GAnsiEnabled := True;
    {$ELSE}
    GAnsiEnabled := (GetEnvironmentVariable('TERM') <> '') or
                    (GetEnvironmentVariable('ANSICON') <> '') or
                    (GetEnvironmentVariable('ConEmuANSI') = 'ON') or
                    (GetEnvironmentVariable('WT_SESSION') <> '');
    {$ENDIF}
  end;
end;

function Wrap(const ACode, S: string): string;
begin
  InitAnsi;
  if GAnsiEnabled then
    Result := ACode + S + C_RESET
  else
    Result := S;
end;

function AnsiBold(const S: string): string;  begin Result := Wrap(C_BOLD, S); end;
function AnsiGreen(const S: string): string;  begin Result := Wrap(C_GREEN, S); end;
function AnsiRed(const S: string): string;    begin Result := Wrap(C_RED, S); end;
function AnsiYellow(const S: string): string; begin Result := Wrap(C_YELLOW, S); end;
function AnsiCyan(const S: string): string;   begin Result := Wrap(C_CYAN, S); end;
function AnsiDim(const S: string): string;    begin Result := Wrap(C_DIM, S); end;

function StatusDot(AStatus: TTestStatus): string;
begin
  case AStatus of
    tsPassed:  Result := AnsiGreen('✓');
    tsFailed:  Result := AnsiRed('✗');
    tsSkipped: Result := AnsiYellow('○');
    tsError:   Result := AnsiRed('!');
  end;
end;

{ ═════════════════════════════════════════════════════════════════════════════ }
{ Assertion Helpers                                                            }
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

procedure ReportLeakIfAny(AStatus: TTestStatus);
begin
  {$IFDEF HASHEAPTRACE}
  if (AStatus = tsPassed) and
     ((GExecState = nil) or (not GExecState^.Failed)) and
     (GetFPCHeapStatus.CurrHeapUsed > 0) then
  begin
    WriteLn('  ', AnsiYellow('⚠ leak'), ': ',
      GetFPCHeapStatus.CurrHeapUsed, ' bytes not freed in ',
      AnsiBold(GExecState^.TestName));
  end;
  {$ENDIF}
end;

{ ═════════════════════════════════════════════════════════════════════════════ }
{ Check* (procedural API)                                                      }
{ ═════════════════════════════════════════════════════════════════════════════ }

procedure Check(ACondition: Boolean; const AMessage: string);
var
  LMsg: string;
begin
  if not ACondition then
  begin
    if AMessage <> '' then
      LMsg := AMessage
    else
      LMsg := 'Check failed';
    InternalFail(LMsg);
  end;
end;

procedure CheckEqual(const AExpected, AActual: string);
begin
  if AExpected <> AActual then
    InternalFail('Expected "' + AExpected + '" but got "' + AActual + '"');
end;

procedure CheckEqual(AExpected, AActual: Int64);
begin
  if AExpected <> AActual then
    InternalFail('Expected ' + IntToStr(AExpected) + ' but got ' + IntToStr(AActual));
end;

procedure CheckEqual(AExpected, AActual: Boolean);
begin
  if AExpected <> AActual then
    InternalFail('Expected ' + BoolToStr(AExpected, 'True', 'False') +
      ' but got ' + BoolToStr(AActual, 'True', 'False'));
end;

procedure CheckEqual(AExpected, AActual: Pointer);
begin
  if AExpected <> AActual then
    InternalFail('Expected pointer $' + IntToHex(NativeUInt(AExpected), 16) +
      ' but got $' + IntToHex(NativeUInt(AActual), 16));
end;

procedure CheckNotEqual(const AExpected, AActual: string);
begin
  if AExpected = AActual then
    InternalFail('Expected values to differ but both are "' + AActual + '"');
end;

procedure CheckNotEqual(AExpected, AActual: Int64);
begin
  if AExpected = AActual then
    InternalFail('Expected values to differ but both are ' + IntToStr(AActual));
end;

procedure CheckTrue(AValue: Boolean; const AMessage: string);
begin
  if not AValue then
  begin
    if AMessage <> '' then
      InternalFail(AMessage)
    else
      InternalFail('Expected True but got False');
  end;
end;

procedure CheckFalse(AValue: Boolean; const AMessage: string);
begin
  if AValue then
  begin
    if AMessage <> '' then
      InternalFail(AMessage)
    else
      InternalFail('Expected False but got True');
  end;
end;

procedure CheckNil(AValue: Pointer; const AMessage: string);
begin
  if AValue <> nil then
  begin
    if AMessage <> '' then
      InternalFail(AMessage)
    else
      InternalFail('Expected nil but got $' + IntToHex(NativeUInt(AValue), 16));
  end;
end;

procedure CheckNotNil(AValue: Pointer; const AMessage: string);
begin
  if AValue = nil then
  begin
    if AMessage <> '' then
      InternalFail(AMessage)
    else
      InternalFail('Expected non-nil but got nil');
  end;
end;

procedure CheckContains(const AHaystack, ANeedle: string);
begin
  if (Length(ANeedle) = 0) then
    Exit; { empty needle matches everything — consistent with StartsWith/EndsWith }
  if Pos(ANeedle, AHaystack) = 0 then
    InternalFail('"' + AHaystack + '" does not contain "' + ANeedle + '"');
end;

procedure CheckStartsWith(const AStr, APrefix: string);
begin
  if not StrStartsWith(AStr, APrefix) then
    InternalFail('"' + AStr + '" does not start with "' + APrefix + '"');
end;

procedure CheckEndsWith(const AStr, ASuffix: string);
var
  LLen: NativeInt;
begin
  LLen := Length(ASuffix);
  if LLen = 0 then
    Exit; { empty suffix matches everything (consistent with ToEndWith) }
  if (Length(AStr) < LLen) or
     (Copy(AStr, Length(AStr) - LLen + 1, LLen) <> ASuffix) then
    InternalFail('"' + AStr + '" does not end with "' + ASuffix + '"');
end;

procedure CheckSame(AExpected, AActual: Pointer; const AMessage: string);
begin
  if AExpected <> AActual then
  begin
    if AMessage <> '' then
      InternalFail(AMessage)
    else
      InternalFail('Expected same pointer $' +
        IntToHex(NativeUInt(AExpected), 16) + ' but got $' +
        IntToHex(NativeUInt(AActual), 16));
  end;
end;

procedure CheckInRange(AValue, ALow, AHigh: Int64);
begin
  if (AValue < ALow) or (AValue > AHigh) then
    InternalFail(IntToStr(AValue) + ' not in range [' +
      IntToStr(ALow) + '..' + IntToStr(AHigh) + ']');
end;

procedure CheckLength(AValue: NativeInt; AExpected: NativeInt);
begin
  if AValue <> AExpected then
    InternalFail('Expected length ' + IntToStr(AExpected) +
      ' but got ' + IntToStr(AValue));
end;

procedure CheckRaises(AExceptionClass: ExceptClass; AProc: TTestProc;
  const AMessage: string);
var
  LRaised: Boolean = False;
begin
  try
    AProc;
  except
    on E: ETestSkipped do
      raise; { Skip is flow control, not a testable exception }
    on E: Exception do
    begin
      LRaised := True;
      if not (E is AExceptionClass) then
        InternalFail('Expected ' + AExceptionClass.ClassName +
          ' but got ' + E.ClassName + ': ' + E.Message);
      if (AMessage <> '') and (Pos(AMessage, E.Message) = 0) then
        InternalFail('Exception message "' + E.Message +
          '" does not contain "' + AMessage + '"');
    end;
  end;
  if not LRaised then
    InternalFail('Expected ' + AExceptionClass.ClassName + ' but nothing raised');
end;

procedure CheckNoRaise(AProc: TTestProc; const AMessage: string);
begin
  try
    AProc;
  except
    on E: ETestSkipped do
      raise; { Skip is flow control, not a testable exception }
    on E: Exception do
    begin
      if AMessage <> '' then
        InternalFail(AMessage + ': ' + E.ClassName + ': ' + E.Message)
      else
        InternalFail('Unexpected exception: ' + E.ClassName + ': ' + E.Message);
    end;
  end;
end;

procedure Fail(const AMessage: string);
begin
  InternalFail(AMessage);
end;

procedure Skip(const AReason: string);
begin
  InternalSkip(AReason);
end;

{ ═════════════════════════════════════════════════════════════════════════════ }
{ TExpectation (fluent API)                                                    }
{ ═════════════════════════════════════════════════════════════════════════════ }

type
  TExpectationKind = (
    ekString, ekInt64, ekBool, ekPointer, ekProc
  );

  TExpectation = class(TInterfacedObject, IExpectation)
  private
    FKind      : TExpectationKind;
    FStrValue  : string;
    FIntValue  : Int64;
    FBoolValue : Boolean;
    FPtrValue  : Pointer;
    FProcValue : TTestProc;
    FNegated   : Boolean;
  public
    constructor CreateStr(const AValue: string);
    constructor CreateInt(AValue: Int64);
    constructor CreateBool(AValue: Boolean);
    constructor CreatePtr(AValue: Pointer);
    constructor CreateProc(AProc: TTestProc);

    { IExpectation }
    function Not_: IExpectation;
    function ToEqual(const AExpected: string): IExpectation;
    function ToEqualInt(AExpected: Int64): IExpectation;
    function ToEqualBool(AExpected: Boolean): IExpectation;
    function ToBeTrue: IExpectation;
    function ToBeFalse: IExpectation;
    function ToBeNil: IExpectation;
    function ToBeNotNil: IExpectation;
    function ToContain(const ASubstr: string): IExpectation;
    function ToStartWith(const APrefix: string): IExpectation;
    function ToEndWith(const ASuffix: string): IExpectation;
    function ToBeGreaterThan(AExpected: Int64): IExpectation;
    function ToBeLessThan(AExpected: Int64): IExpectation;
    function ToBeInRange(ALow, AHigh: Int64): IExpectation;
    function ToHaveLength(AExpected: NativeInt): IExpectation;
    function ToRaise(AExceptionClass: ExceptClass;
      const AMessage: string = ''): IExpectation;
    function ToNotRaise: IExpectation;
  end;

constructor TExpectation.CreateStr(const AValue: string);
begin
  inherited Create;
  FKind     := ekString;
  FStrValue := AValue;
  FNegated  := False;
end;

constructor TExpectation.CreateInt(AValue: Int64);
begin
  inherited Create;
  FKind     := ekInt64;
  FIntValue := AValue;
  FNegated  := False;
end;

constructor TExpectation.CreateBool(AValue: Boolean);
begin
  inherited Create;
  FKind      := ekBool;
  FBoolValue := AValue;
  FNegated   := False;
end;

constructor TExpectation.CreatePtr(AValue: Pointer);
begin
  inherited Create;
  FKind     := ekPointer;
  FPtrValue := AValue;
  FNegated  := False;
end;

constructor TExpectation.CreateProc(AProc: TTestProc);
begin
  inherited Create;
  FKind      := ekProc;
  FProcValue := AProc;
  FNegated   := False;
end;

function TExpectation.Not_: IExpectation;
begin
  FNegated := not FNegated;
  Result := Self;
end;

function TExpectation.ToEqual(const AExpected: string): IExpectation;
var
  LMatch: Boolean;
begin
  if FKind <> ekString then
    InternalFail('ToEqual(string) called on non-string expectation');
  LMatch := FStrValue = AExpected;
  if FNegated then
  begin
    if LMatch then
      InternalFail('Expected "' + FStrValue + '" not to equal "' + AExpected + '"');
  end
  else
  begin
    if not LMatch then
      InternalFail('Expected "' + AExpected + '" but got "' + FStrValue + '"');
  end;
  FNegated := False;
  Result := Self;
end;

function TExpectation.ToEqualInt(AExpected: Int64): IExpectation;
var
  LMatch: Boolean;
begin
  if FKind <> ekInt64 then
    InternalFail('ToEqualInt called on non-integer expectation');
  LMatch := FIntValue = AExpected;
  if FNegated then
  begin
    if LMatch then
      InternalFail('Expected not ' + IntToStr(AExpected) +
        ' but value is ' + IntToStr(FIntValue));
  end
  else
  begin
    if not LMatch then
      InternalFail('Expected ' + IntToStr(AExpected) +
        ' but got ' + IntToStr(FIntValue));
  end;
  FNegated := False;
  Result := Self;
end;

function TExpectation.ToEqualBool(AExpected: Boolean): IExpectation;
var
  LMatch: Boolean;
  LExpStr, LActStr: string;
begin
  if FKind <> ekBool then
    InternalFail('ToEqualBool called on non-boolean expectation');
  LMatch := FBoolValue = AExpected;
  LExpStr := BoolToStr(AExpected, 'True', 'False');
  LActStr := BoolToStr(FBoolValue, 'True', 'False');
  if FNegated then
  begin
    if LMatch then
      InternalFail('Expected not ' + LExpStr + ' but got ' + LActStr);
  end
  else
  begin
    if not LMatch then
      InternalFail('Expected ' + LExpStr + ' but got ' + LActStr);
  end;
  FNegated := False;
  Result := Self;
end;

function TExpectation.ToBeTrue: IExpectation;
begin
  Result := ToEqualBool(True);
end;

function TExpectation.ToBeFalse: IExpectation;
begin
  Result := ToEqualBool(False);
end;

function TExpectation.ToBeNil: IExpectation;
var
  LIsNil: Boolean;
begin
  if FKind <> ekPointer then
    InternalFail('ToBeNil called on non-pointer expectation');
  LIsNil := FPtrValue = nil;
  if FNegated then
  begin
    if LIsNil then
      InternalFail('Expected non-nil but got nil');
  end
  else
  begin
    if not LIsNil then
      InternalFail('Expected nil but got $' +
        IntToHex(NativeUInt(FPtrValue), 16));
  end;
  FNegated := False;
  Result := Self;
end;

function TExpectation.ToBeNotNil: IExpectation;
begin
  if FKind <> ekPointer then
    InternalFail('ToBeNotNil called on non-pointer expectation');
  if FNegated then
  begin
    { Not_.ToBeNotNil = expect nil }
    if FPtrValue <> nil then
      InternalFail('Expected nil but got $' +
        IntToHex(NativeUInt(FPtrValue), 16));
  end
  else
  begin
    { ToBeNotNil = expect non-nil }
    if FPtrValue = nil then
      InternalFail('Expected non-nil but got nil');
  end;
  FNegated := False;
  Result := Self;
end;

function TExpectation.ToContain(const ASubstr: string): IExpectation;
var
  LFound: Boolean;
begin
  if FKind <> ekString then
    InternalFail('ToContain called on non-string expectation');
  if Length(ASubstr) = 0 then
    LFound := True { empty substring matches everything }
  else
    LFound := Pos(ASubstr, FStrValue) > 0;
  if FNegated then
  begin
    if LFound then
      InternalFail('"' + FStrValue + '" should not contain "' + ASubstr + '"');
  end
  else
  begin
    if not LFound then
      InternalFail('"' + FStrValue + '" does not contain "' + ASubstr + '"');
  end;
  FNegated := False;
  Result := Self;
end;

function TExpectation.ToStartWith(const APrefix: string): IExpectation;
var
  LMatch: Boolean;
begin
  if FKind <> ekString then
    InternalFail('ToStartWith called on non-string expectation');
  LMatch := StrStartsWith(FStrValue, APrefix);
  if FNegated then
  begin
    if LMatch then
      InternalFail('"' + FStrValue + '" should not start with "' + APrefix + '"');
  end
  else
  begin
    if not LMatch then
      InternalFail('"' + FStrValue + '" does not start with "' + APrefix + '"');
  end;
  FNegated := False;
  Result := Self;
end;

function TExpectation.ToEndWith(const ASuffix: string): IExpectation;
var
  LMatch: Boolean;
  LLen: Integer;
begin
  if FKind <> ekString then
    InternalFail('ToEndWith called on non-string expectation');
  LLen := Length(ASuffix);
  if LLen = 0 then
    LMatch := True
  else
    LMatch := (Length(FStrValue) >= LLen) and
              (Copy(FStrValue, Length(FStrValue) - LLen + 1, LLen) = ASuffix);
  if FNegated then
  begin
    if LMatch then
      InternalFail('"' + FStrValue + '" should not end with "' + ASuffix + '"');
  end
  else
  begin
    if not LMatch then
      InternalFail('"' + FStrValue + '" does not end with "' + ASuffix + '"');
  end;
  FNegated := False;
  Result := Self;
end;

function TExpectation.ToBeGreaterThan(AExpected: Int64): IExpectation;
var
  LMatch: Boolean;
begin
  if FKind <> ekInt64 then
    InternalFail('ToBeGreaterThan called on non-integer expectation');
  LMatch := FIntValue > AExpected;
  if FNegated then
  begin
    if LMatch then
      InternalFail(IntToStr(FIntValue) + ' should not be > ' + IntToStr(AExpected));
  end
  else
  begin
    if not LMatch then
      InternalFail(IntToStr(FIntValue) + ' is not > ' + IntToStr(AExpected));
  end;
  FNegated := False;
  Result := Self;
end;

function TExpectation.ToBeLessThan(AExpected: Int64): IExpectation;
var
  LMatch: Boolean;
begin
  if FKind <> ekInt64 then
    InternalFail('ToBeLessThan called on non-integer expectation');
  LMatch := FIntValue < AExpected;
  if FNegated then
  begin
    if LMatch then
      InternalFail(IntToStr(FIntValue) + ' should not be < ' + IntToStr(AExpected));
  end
  else
  begin
    if not LMatch then
      InternalFail(IntToStr(FIntValue) + ' is not < ' + IntToStr(AExpected));
  end;
  FNegated := False;
  Result := Self;
end;

function TExpectation.ToBeInRange(ALow, AHigh: Int64): IExpectation;
var
  LMatch: Boolean;
begin
  if FKind <> ekInt64 then
    InternalFail('ToBeInRange called on non-integer expectation');
  LMatch := (FIntValue >= ALow) and (FIntValue <= AHigh);
  if FNegated then
  begin
    if LMatch then
      InternalFail(IntToStr(FIntValue) + ' should not be in [' +
        IntToStr(ALow) + '..' + IntToStr(AHigh) + ']');
  end
  else
  begin
    if not LMatch then
      InternalFail(IntToStr(FIntValue) + ' not in [' +
        IntToStr(ALow) + '..' + IntToStr(AHigh) + ']');
  end;
  FNegated := False;
  Result := Self;
end;

function TExpectation.ToHaveLength(AExpected: NativeInt): IExpectation;
begin
  if FKind <> ekString then
    InternalFail('ToHaveLength called on non-string expectation');
  if FNegated then
  begin
    if Length(FStrValue) = AExpected then
      InternalFail('String should not have length ' + IntToStr(AExpected));
  end
  else
  begin
    if Length(FStrValue) <> AExpected then
      InternalFail('Expected length ' + IntToStr(AExpected) +
        ' but got ' + IntToStr(Length(FStrValue)));
  end;
  FNegated := False;
  Result := Self;
end;

function TExpectation.ToRaise(AExceptionClass: ExceptClass;
  const AMessage: string): IExpectation;
var
  LRaised: Boolean = False;
begin
  if FKind <> ekProc then
    InternalFail('ToRaise called on non-proc expectation');
  try
    FProcValue;
  except
    on E: ETestSkipped do
      raise; { Skip is flow control, not a testable exception }
    on E: Exception do
    begin
      LRaised := True;
      if FNegated then
        InternalFail('Expected no exception but got ' +
          E.ClassName + ': ' + E.Message)
      else
      begin
        if not (E is AExceptionClass) then
          InternalFail('Expected ' + AExceptionClass.ClassName +
            ' but got ' + E.ClassName + ': ' + E.Message);
        if (AMessage <> '') and (Pos(AMessage, E.Message) = 0) then
          InternalFail('Exception message "' + E.Message +
            '" does not contain "' + AMessage + '"');
      end;
    end;
  end;
  if not LRaised then
  begin
    if not FNegated then
      InternalFail('Expected ' + AExceptionClass.ClassName +
        ' but nothing raised');
  end;
  FNegated := False;
  Result := Self;
end;

function TExpectation.ToNotRaise: IExpectation;
begin
  if FKind <> ekProc then
    InternalFail('ToNotRaise called on non-proc expectation');
  try
    FProcValue;
  except
    on E: ETestSkipped do
      raise; { Skip is flow control, not a testable exception }
    on E: Exception do
      InternalFail('Expected no exception but got ' +
        E.ClassName + ': ' + E.Message);
  end;
  FNegated := False;
  Result := Self;
end;

{ ── Expect factories ──────────────────────────────────────────────────────── }

function Expect(const AValue: string): IExpectation;
begin
  Result := TExpectation.CreateStr(AValue);
end;

function ExpectInt(AValue: Int64): IExpectation;
begin
  Result := TExpectation.CreateInt(AValue);
end;

function ExpectBool(AValue: Boolean): IExpectation;
begin
  Result := TExpectation.CreateBool(AValue);
end;

function ExpectPtr(AValue: Pointer): IExpectation;
begin
  Result := TExpectation.CreatePtr(AValue);
end;

function ExpectProc(AProc: TTestProc): IExpectation;
begin
  Result := TExpectation.CreateProc(AProc);
end;

{ ═════════════════════════════════════════════════════════════════════════════ }
{ TTestContext (internal, for subtests)                                        }
{ ═════════════════════════════════════════════════════════════════════════════ }

type
  TTestContext = class(TInterfacedObject, ITestContext)
  private
    FTestName : string;
    FSubtests : specialize TArray<TTestEntry>;
    FSubPass  : Integer;
    FSubFail  : Integer;
    FSubSkip  : Integer;
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
  LSubCtx: TTestContext;
  LSubCtxI: ITestContext;
begin
  for I := 0 to High(FSubtests) do
  begin
    LEntry := FSubtests[I];
    LStatus := tsPassed;
    SetTestContext(GExecState^.SuiteName, LEntry.Name);
    try
      if LEntry.Kind = ekSkipped then
      begin
        LStatus := tsSkipped;
        WriteLn('    ', StatusDot(tsSkipped), ' ', AnsiDim(LEntry.Name),
          ' — ', LEntry.SkipReason);
        Inc(FSubSkip);
      end
      else if LEntry.Kind = ekSubtest then
      begin
        LSubCtx := TTestContext.Create(LEntry.Name);
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
        WriteLn('    ', StatusDot(tsSkipped), ' ', AnsiDim(LEntry.Name));
        Inc(FSubSkip);
      end;
      on E: EAssertionFailed do
      begin
        LStatus := tsFailed;
        WriteLn('    ', StatusDot(tsFailed), ' ', AnsiRed(LEntry.Name));
        WriteLn('      ', AnsiDim(E.Message));
        Inc(FSubFail);
      end;
      on E: Exception do
      begin
        LStatus := tsError;
        WriteLn('    ', StatusDot(tsError), ' ', AnsiRed(LEntry.Name),
          ' [', E.ClassName, ']');
        WriteLn('      ', AnsiDim(E.Message));
        Inc(FSubFail);
      end;
    end;
    ReportLeakIfAny(LStatus);
  end;
  { Propagate subtest failures to parent }
  if FSubFail > 0 then
    InternalFail(IntToStr(FSubFail) + ' subtest(s) failed in ' + FTestName);
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
  Result.FLastRunPassed := False;
  Result.FHasRun        := False;
  Result.FLastPass      := 0;
  Result.FLastFail      := 0;
  Result.FLastSkip      := 0;
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
  I: Integer;
  LEntry: TTestEntry;
  LStatus: TTestStatus;
  LSubCtx: TTestContext;
  LSubCtxI: ITestContext;
  LPass, LFail, LSkip: Integer;
  LLastFailMsg: string;
  LTestResult: TTestResult;
begin
  AResult := TTestRunResult.Create(Name);
  LPass := 0;
  LFail := 0;
  LSkip := 0;
  LLastFailMsg := '';

  WriteLn;
  WriteLn(AnsiBold('▸ ') + AnsiCyan(Name) +
    AnsiDim(' (' + IntToStr(Length(Tests)) + ' tests)'));

  { Suite-level setup }
  if Assigned(Setup) then
  begin
    try
      Setup;
    except
      on E: Exception do
      begin
        WriteLn('  ', AnsiRed('✗ setup failed: ') + E.Message);
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
        FHasRun        := True;
        FLastRunPassed := False;
        FLastPass      := 0;
        FLastFail      := 1;
        FLastSkip      := LSkip;
        Result         := False;
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
          ' — ', LEntry.SkipReason)
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
        on E: Exception do
        begin
          LStatus := tsError;
          LLastFailMsg := E.Message;
          LTestResult.Status  := tsError;
          LTestResult.Message := 'beforeEach failed: ' + E.Message;
          SetLength(AResult.Results, Length(AResult.Results) + 1);
          AResult.Results[High(AResult.Results)] := LTestResult;
          WriteLn('  ', StatusDot(tsError), ' ', LEntry.Name,
            ' — beforeEach failed: ', E.Message);
          Inc(LFail);
          Continue;
        end;
      end;
    end;

    try
      if LEntry.Kind = ekSubtest then
      begin
        LSubCtx := TTestContext.Create(LEntry.Name);
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
        LEntry.Proc;
        Inc(LPass);
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
          WriteLn('  ', AnsiYellow('⚠ afterEach failed: '), E.Message);
          if LStatus = tsPassed then
          begin
            LStatus := tsError;
            LLastFailMsg := 'afterEach failed: ' + E.Message;
            Inc(LFail);
            if LPass > 0 then { Guard against negative count for subtests }
              Dec(LPass);
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
              ' — ', LEntry.SkipReason)
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
        WriteLn('  ', AnsiYellow('⚠ teardown error: ') + E.Message);
    end;
  end;

  AResult.Passed    := LPass;
  AResult.Failed    := LFail;
  AResult.Skipped   := LSkip;
  AResult.AllPassed := LFail = 0;

  FHasRun        := True;
  FLastRunPassed := AResult.AllPassed;
  FLastPass      := LPass;
  FLastFail      := LFail;
  FLastSkip      := LSkip;
  Result         := FLastRunPassed;
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
  { Note: We intentionally do NOT call SetTestContext here.
    SetTestContext allocates thread-local GExecState — each thread would get
    its own copy, which is safe but unnecessary since parallel tests track
    state locally via LStatus and the TThreadRec record. }

  { Subtests are not supported in parallel mode — skip gracefully }
  if R^.Entry.Kind = ekSubtest then
  begin
    R^.Mtx.Acquire;
    try
      R^.Skip^ := R^.Skip^ + 1;
      WriteLn('  ', StatusDot(tsSkipped), ' ', AnsiDim(R^.Entry.Name),
        ' — subtests not supported in parallel mode');
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
      on E: Exception do
      begin
        LStatus := tsError;
        LFailMsg := E.Message;
        R^.Mtx.Acquire;
        try
          WriteLn('  ', StatusDot(tsError), ' ', R^.Entry.Name,
            ' — beforeEach failed: ', E.Message);
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
          WriteLn('  ', AnsiYellow('⚠ afterEach failed: '), E.Message);
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
              ' — ', LSkipReason)
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
end;

function TTestSuite.RunParallel(APool: IThreadPool): Boolean;
var
  LTotal: Integer;
  LPass, LFail, LSkip: Integer;
  LMtx: IMutex;
  I: Integer;
var
  LRecs: array of TThreadRec;
  LHandles: array of TPlatformThreadHandle;
  LRetVal: Pointer;
begin
  LTotal := Length(Tests);
  LPass := 0;
  LFail := 0;
  LSkip := 0;
  LMtx := Mutex();

  WriteLn;
  WriteLn(AnsiBold('▸ ') + AnsiCyan(Name) +
    AnsiDim(' (' + IntToStr(LTotal) + ' tests, parallel)'));

  { Suite-level setup (serial) }
  if Assigned(Setup) then
  begin
    try
      Setup;
    except
      on E: Exception do
      begin
        WriteLn('  ', AnsiRed('✗ setup failed: ') + E.Message);
        for I := 0 to High(Tests) do
        begin
          Inc(LSkip);
          WriteLn('    ', StatusDot(tsSkipped), ' ', AnsiDim(Tests[I].Name));
        end;
        FHasRun        := True;
        FLastRunPassed := False;
        FLastPass      := 0;
        FLastFail      := 0;
        FLastSkip      := LSkip;
        Result         := False;
        WriteLn(AnsiDim('  ') + IntToStr(LSkip) + ' skipped (setup failure)');
        Exit;
      end;
    end;
  end;

  { ── Parallel dispatch ──────────────────────────────────────────────────────
    Uses direct platform_thread_create/join to avoid FPC closure capture issues.
    Each thread receives its own heap-allocated TThreadRec with the test entry. }

  SetLength(LHandles, LTotal);
  SetLength(LRecs, LTotal);

  { Pre-fill records (all tests, including skipped) }
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
  end;

  { Spawn one thread per test }
  for I := 0 to High(Tests) do
    platform_thread_create(LHandles[I], @ParallelWorkerProc, @LRecs[I]);

  { Wait for all threads — join provides happens-before guarantee }
  for I := 0 to High(Tests) do
    platform_thread_join(LHandles[I], LRetVal);

  { Suite-level teardown }
  if Assigned(Teardown) then
  begin
    try
      Teardown;
    except
      on E: Exception do
        WriteLn('  ', AnsiYellow('⚠ teardown error: ') + E.Message);
    end;
  end;

  FHasRun        := True;
  FLastRunPassed := LFail = 0;
  FLastPass      := LPass;
  FLastFail      := LFail;
  FLastSkip      := LSkip;
  Result         := FLastRunPassed;
  WriteLn(AnsiDim('  ') +
    IntToStr(LPass) + ' passed, ' +
    IntToStr(LFail) + ' failed, ' +
    IntToStr(LSkip) + ' skipped');
end;

procedure TTestSuite.Summary;
begin
  if not FHasRun then
  begin
    WriteLn(AnsiYellow('Warning: ') + Name + ' has not been run yet');
    Exit;
  end;
  WriteLn(AnsiBold('─── ') + AnsiCyan(Name) + AnsiBold(' ───'));
  WriteLn('  Total tests: ', Length(Tests));
  WriteLn('  Passed: ', FLastPass, ', Failed: ', FLastFail, ', Skipped: ', FLastSkip);
end;

function TTestSuite.AllPassed: Boolean;
  { Returns whether all tests passed. If Run/RunParallel has not been called yet,
    this will automatically execute Run (serial mode) first. }
begin
  if not FHasRun then
    Result := Run
  else
    Result := FLastRunPassed;
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
end;

procedure TTestRunner.Add(var ASuite: TTestSuite);
  { Note: ASuite is copied by value. After Add(), further modifications to the
    original ASuite variable will NOT be reflected in the runner due to Pascal
    dynamic-array copy-on-write semantics. Add all tests before calling Add. }
begin
  SetLength(Suites, Length(Suites) + 1);
  Suites[High(Suites)] := ASuite;
end;

function TTestRunner.RunAll: Boolean;
var
  I: Integer;
  LAllPassed: Boolean;
begin
  WriteLn(AnsiBold('═══ ') + AnsiBold(Name) + AnsiBold(' ═══'));
  LAllPassed := True;
  TotalPass := 0;
  TotalFail := 0;
  TotalSkip := 0;
  for I := 0 to High(Suites) do
  begin
    if not Suites[I].Run then
      LAllPassed := False;
    Inc(TotalPass, Suites[I].FLastPass);
    Inc(TotalFail, Suites[I].FLastFail);
    Inc(TotalSkip, Suites[I].FLastSkip);
  end;
  Result := LAllPassed;
end;

function TTestRunner.RunAllParallel(APool: IThreadPool): Boolean;
var
  I: Integer;
  LAllPassed: Boolean;
begin
  WriteLn(AnsiBold('═══ ') + AnsiBold(Name) + AnsiBold(' (parallel) ═══'));
  LAllPassed := True;
  TotalPass := 0;
  TotalFail := 0;
  TotalSkip := 0;
  for I := 0 to High(Suites) do
  begin
    if not Suites[I].RunParallel(APool) then
      LAllPassed := False;
    Inc(TotalPass, Suites[I].FLastPass);
    Inc(TotalFail, Suites[I].FLastFail);
    Inc(TotalSkip, Suites[I].FLastSkip);
  end;
  Result := LAllPassed;
end;

procedure TTestRunner.Summary;
begin
  WriteLn;
  WriteLn(AnsiBold('═══ Summary ═══'));
  WriteLn('  Suites: ', Length(Suites));
  WriteLn('  Passed: ', TotalPass,
    ', Failed: ', TotalFail,
    ', Skipped: ', TotalSkip);
end;

function TTestRunner.AllPassed: Boolean;
begin
  if TotalPass + TotalFail + TotalSkip > 0 then
    Result := TotalFail = 0
  else
    Result := RunAll;
end;

{ ═════════════════════════════════════════════════════════════════════════════ }
{ Init / Fini                                                                   }
{ ═════════════════════════════════════════════════════════════════════════════ }

initialization
  InitAnsi;

finalization
  if GExecState <> nil then
    Dispose(GExecState);

end.
