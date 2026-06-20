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

{ ── Test Entry ────────────────────────────────────────────────────────────── }

  TTestSkipReason = string;

  ETestSkipped = class(EAbort)
    constructor Create(const AReason: string);
  end;

  TTestEntry = record
    Name : string;
    Proc : TTestProc;
    Kind : (ekTest, ekSubtest, ekSkipped);
    SkipReason: string;
  end;

{ ── Test Suite ────────────────────────────────────────────────────────────── }

  TTestSuite = record
    Name      : string;
    Tests     : specialize TArray<TTestEntry>;
    Setup     : TTestProc;
    Teardown  : TTestProc;
    BeforeEach: TTestProc;
    AfterEach : TTestProc;

    class function Create(const AName: string): TTestSuite; static;
    procedure Test(const AName: string; AProc: TTestProc);
    procedure TestSubtest(const AName: string; AProc: TSubtestProc);
    procedure Skip(const AName: string; const AReason: string = '');
    procedure SetSetup(AProc: TTestProc);
    procedure SetTeardown(AProc: TTestProc);
    procedure OnBeforeEach(AProc: TTestProc);
    procedure OnAfterEach(AProc: TTestProc);
    function  Run: Boolean;
    function  RunParallel(APool: IThreadPool): Boolean;
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
    TotalErr : Integer;

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

function StrStartsWith(const S, APrefix: string): Boolean; inline;
begin
  Result := (Length(APrefix) > 0) and
            (Length(S) >= Length(APrefix)) and
            (Copy(S, 1, Length(APrefix)) = APrefix);
end;

{ ═════════════════════════════════════════════════════════════════════════════ }
{ Internal State                                                               }
{ ═════════════════════════════════════════════════════════════════════════════ }

var
  { Context for active test — set by runner before each test }
  GActiveTestName : string = '';
  GActiveSuiteName: string = '';

  { Flow control — set by InternalFail/InternalSkip, read by SetTestContext }
  GTestSkipped   : Boolean = False;  // set true on Skip()
  GTestFailed    : Boolean = False;  // set true on Fail()/Check*
  GSkipReason    : string  = '';

  { ANSI capability }
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

function StatusStr(AStatus: TTestStatus): string;
begin
  case AStatus of
    tsPassed:  Result := AnsiGreen('PASS');
    tsFailed:  Result := AnsiRed('FAIL');
    tsSkipped: Result := AnsiYellow('SKIP');
    tsError:   Result := AnsiRed('ERR ');
  end;
end;

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
  GTestFailed := True;
  raise EAssertionFailed.Create(AMessage);
end;

procedure InternalSkip(const AReason: string);
begin
  GTestSkipped := True;
  GSkipReason  := AReason;
  raise ETestSkipped.Create(AReason);
end;

procedure SetTestContext(const ASuiteName, ATestName: string);
begin
  GActiveTestName  := ATestName;
  GActiveSuiteName := ASuiteName;
  GTestSkipped     := False;
  GTestFailed      := False;
  GSkipReason      := '';
end;

procedure ReportLeakIfAny(AStatus: TTestStatus);
begin
  { GTestFailed is read below under HASHEAPTRACE; the conditional read
    also serves as explicit usage to suppress FPC's "assigned but never used" note. }
  if GTestSkipped then { intentionally check flag to suppress note };
  if GTestFailed then { intentionally check flag to suppress note };
  {$IFDEF HASHEAPTRACE}
  if (AStatus = tsPassed) and not GTestFailed and
     (GetFPCHeapStatus.CurrHeapUsed > 0) then
  begin
    WriteLn('  ', AnsiYellow('⚠ leak'), ': ',
      GetFPCHeapStatus.CurrHeapUsed, ' bytes not freed in ',
      AnsiBold(GActiveTestName));
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
  LLen: Integer;
begin
  LLen := Length(ASuffix);
  if (LLen = 0) or (Length(AStr) < LLen) or
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
  Result := Self;
end;

function TExpectation.ToBeNotNil: IExpectation;
begin
  FNegated := not FNegated;
  Result := ToBeNil;
end;

function TExpectation.ToContain(const ASubstr: string): IExpectation;
var
  LFound: Boolean;
begin
  if FKind <> ekString then
    InternalFail('ToContain called on non-string expectation');
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
  LEntry.Name      := FTestName + '/' + AName;
  LEntry.Proc      := AProc;
  LEntry.Kind      := ekTest;
  LEntry.SkipReason:= '';
  SetLength(FSubtests, Length(FSubtests) + 1);
  FSubtests[High(FSubtests)] := LEntry;
end;

procedure TTestContext.RunNested(const AName: string; AProc: Pointer);
var
  LEntry: TTestEntry;
begin
  LEntry.Name      := FTestName + '/' + AName;
  LEntry.Proc      := TTestProc(AProc);
  LEntry.Kind      := ekSubtest;
  LEntry.SkipReason:= '';
  SetLength(FSubtests, Length(FSubtests) + 1);
  FSubtests[High(FSubtests)] := LEntry;
end;

procedure TTestContext.Fail(const AMessage: string);
begin
  InternalFail(AMessage);
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
    SetTestContext(GActiveSuiteName, LEntry.Name);
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
        TSubtestProc(LEntry.Proc)(LSubCtxI);
        LSubCtx.ExecuteSubtests;
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
end;

procedure TTestSuite.Test(const AName: string; AProc: TTestProc);
var
  LEntry: TTestEntry;
begin
  LEntry.Name       := AName;
  LEntry.Proc       := AProc;
  LEntry.Kind       := ekTest;
  LEntry.SkipReason := '';
  SetLength(Tests, Length(Tests) + 1);
  Tests[High(Tests)] := LEntry;
end;

procedure TTestSuite.TestSubtest(const AName: string; AProc: TSubtestProc);
var
  LEntry: TTestEntry;
begin
  LEntry.Name       := AName;
  LEntry.Proc       := TTestProc(AProc);
  LEntry.Kind       := ekSubtest;
  LEntry.SkipReason := '';
  SetLength(Tests, Length(Tests) + 1);
  Tests[High(Tests)] := LEntry;
end;

procedure TTestSuite.Skip(const AName: string; const AReason: string);
var
  LEntry: TTestEntry;
begin
  LEntry.Name       := AName;
  LEntry.Proc       := nil;
  LEntry.Kind       := ekSkipped;
  LEntry.SkipReason := AReason;
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
  I: Integer;
  LEntry: TTestEntry;
  LStatus: TTestStatus;
  LSubCtx: TTestContext;
  LSubCtxI: ITestContext;
  LPass, LFail, LSkip: Integer;
begin
  LPass := 0;
  LFail := 0;
  LSkip := 0;

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
          WriteLn('    ', StatusDot(tsSkipped), ' ', AnsiDim(Tests[I].Name));
        end;
        Result := False;
        WriteLn(AnsiDim('  ') + IntToStr(LSkip) + ' skipped (setup failure)');
        Exit;
      end;
    end;
  end;

  for I := 0 to High(Tests) do
  begin
    LEntry := Tests[I];
    LStatus := tsPassed;
    SetTestContext(Name, LEntry.Name);

    { BeforeEach }
    if Assigned(BeforeEach) then
    begin
      try
        BeforeEach;
      except
        on E: Exception do
        begin
          LStatus := tsError;
          WriteLn('  ', StatusDot(tsError), ' ', LEntry.Name,
            ' — beforeEach failed: ', E.Message);
          Inc(LFail);
          Continue;
        end;
      end;
    end;

    try
      if LEntry.Kind = ekSkipped then
      begin
        LStatus := tsSkipped;
        Inc(LSkip);
      end
      else if LEntry.Kind = ekSubtest then
      begin
        LSubCtx := TTestContext.Create(LEntry.Name);
        LSubCtxI := LSubCtx;
        TSubtestProc(LEntry.Proc)(LSubCtxI);
        LSubCtx.ExecuteSubtests;
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
        Inc(LFail);
      end;
      on E: Exception do
      begin
        LStatus := tsError;
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
          if LStatus = tsPassed then
          begin
            LStatus := tsError;
            Inc(LFail);
            Dec(LPass);
          end;
        end;
      end;
    end;

    { Output per-test }
    case LStatus of
      tsPassed:
        WriteLn('  ', StatusDot(tsPassed), ' ', LEntry.Name);
      tsFailed:
        begin
          WriteLn('  ', StatusDot(tsFailed), ' ', AnsiRed(LEntry.Name));
          { Find the exception message from the last failure }
          WriteLn('    ', AnsiDim('(assertion failed — see above)'));
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
        WriteLn('  ', StatusDot(tsError), ' ', AnsiRed(LEntry.Name),
          ' [unexpected exception]');
    end;

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

  Result := LFail = 0;
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
begin
  Result := nil;
  R := PThreadRec(AArg);
  LStatus := tsPassed;
  SetTestContext(R^.SuiteName, R^.Entry.Name);

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
    try R^.Before; except LStatus := tsError; end;
  end;

  if LStatus = tsPassed then
  begin
    try
      R^.Entry.Proc;
    except
      on E: ETestSkipped do LStatus := tsSkipped;
      on E: EAssertionFailed do LStatus := tsFailed;
      on E: Exception do LStatus := tsError;
    end;
  end;

  if Assigned(R^.After) then
  begin
    try
      R^.After;
    except
      if LStatus = tsPassed then LStatus := tsError;
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
        end;
      tsSkipped:
        begin
          R^.Skip^ := R^.Skip^ + 1;
          WriteLn('  ', StatusDot(tsSkipped), ' ', AnsiDim(R^.Entry.Name));
        end;
      tsError:
        begin
          R^.Fail^ := R^.Fail^ + 1;
          WriteLn('  ', StatusDot(tsError), ' ', AnsiRed(R^.Entry.Name));
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
        Result := False;
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

  { Wait for all threads }
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

  Result := LFail = 0;
  WriteLn(AnsiDim('  ') +
    IntToStr(LPass) + ' passed, ' +
    IntToStr(LFail) + ' failed, ' +
    IntToStr(LSkip) + ' skipped');

  if Assigned(Teardown) then
  begin
    try
      Teardown;
    except
      on E: Exception do
        WriteLn('  ', AnsiYellow('⚠ teardown error: ') + E.Message);
    end;
  end;

  Result := LFail = 0;
  WriteLn(AnsiDim('  ') +
    IntToStr(LPass) + ' passed, ' +
    IntToStr(LFail) + ' failed, ' +
    IntToStr(LSkip) + ' skipped');
end;

procedure TTestSuite.Summary;
begin
  WriteLn(AnsiBold('─── ') + AnsiCyan(Name) + AnsiBold(' ───'));
  WriteLn('  Total tests: ', Length(Tests));
end;

function TTestSuite.AllPassed: Boolean;
begin
  Result := Run;
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
  Result.TotalErr  := 0;
end;

procedure TTestRunner.Add(var ASuite: TTestSuite);
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
  for I := 0 to High(Suites) do
  begin
    if not Suites[I].Run then
      LAllPassed := False;
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
  for I := 0 to High(Suites) do
  begin
    if not Suites[I].RunParallel(APool) then
      LAllPassed := False;
  end;
  Result := LAllPassed;
end;

procedure TTestRunner.Summary;
begin
  WriteLn;
  WriteLn(AnsiBold('═══ Summary ═══'));
  WriteLn('  Suites: ', Length(Suites));
end;

function TTestRunner.AllPassed: Boolean;
begin
  Result := RunAll;
end;

{ ═════════════════════════════════════════════════════════════════════════════ }
{ Init / Fini                                                                   }
{ ═════════════════════════════════════════════════════════════════════════════ }

initialization
  InitAnsi;

finalization
  { Cleanup }

end.
