{ nextpas.core.test.mock — Manual mock helper
  =========================================================
  String-based call recorder with configurable return values and
  call-count verification.  Not an interface proxy — callers record
  calls manually and retrieve configured return values.
  Usage:
    LMock := TMock.Create;
    LMock.Setup('Bar').Returns('hello');
    LMock.RecordCall('Bar', []);
    CheckEqual('hello', LMock.GetReturn('Bar'));
    LMock.Verify('Bar').CalledExactly(1);
  Depends on: nextpas.core.test.base }

unit nextpas.core.test.mock;

{$I nextpas.core.settings.inc}

interface

uses
  SysUtils,
  nextpas.core.test.base;

{ ── Typed Mock Values ──────────────────────────────────────────────────────── }

type
  TMockValueKind = (mvUnset, mvString, mvInt64, mvBool, mvDouble);

  TMockValue = record
    Kind   : TMockValueKind;
    StrVal : string;
    IntVal : Int64;
    BoolVal: Boolean;
    DblVal : Double;
  end;

function MockStr(const AValue: string): TMockValue;
function MockInt(AValue: Int64): TMockValue;
function MockBool(AValue: Boolean): TMockValue;
function MockDouble(AValue: Double): TMockValue;

{ ── Call Record ───────────────────────────────────────────────────────────── }

type
  TMockValues = specialize TArray<TMockValue>;

  TMockCall = record
    MethodName      : string;
    Args            : specialize TArray<string>;
    TypedArgs       : TMockValues;
    HasResult       : Boolean;
    ResultValue     : string;
    TypedReturnValue: TMockValue;
  end;

  TMockCalls = specialize TArray<TMockCall>;

{ ── Setup (configure return values) ───────────────────────────────────────── }

type
  IMockSetup = interface
    ['{A7B2C3D4-1234-5678-ABCD-EF0123456789}']
    { Configure the return value for this method }
    function Returns(const AValue: string): IMockSetup;
    { Configure the return value as Integer }
    function ReturnsInt(AValue: Int64): IMockSetup;
    { Configure the return value as Boolean }
    function ReturnsBool(AValue: Boolean): IMockSetup;
  end;

{ ── Verify (assert call expectations) ─────────────────────────────────────── }

type
  IMockVerify = interface
    ['{B8C9D0E1-2345-6789-BCDE-F01234567890}']
    procedure CalledExactly(ACount: Integer);
    procedure CalledAtLeast(ACount: Integer);
    procedure CalledAtMost(ACount: Integer);
    procedure CalledNever;
    procedure CalledOnce;
  end;

{ ── Mock State ────────────────────────────────────────────────────────────── }

type
  TMockState = class
  private
    FCalls   : TMockCalls;
    FSetups  : specialize TArray<TMockCall>;
  public
    constructor Create;
    destructor Destroy; override;
    { Record a call }
    procedure RecordCall(const AMethodName: string;
      const AArgs: array of string);
    procedure RecordCallTyped(const AMethodName: string;
      const AArgs: array of TMockValue);
    { Get return value for a method, or '' if not configured }
    function GetReturn(const AMethodName: string): string;
    function GetReturnTyped(const AMethodName: string;
      const AArgs: array of TMockValue): TMockValue;
    { Configure a return value }
    procedure SetReturn(const AMethodName, AValue: string);
    { Get call count for a method }
    function CallCount(const AMethodName: string): Integer;
    { Get all recorded calls }
    property Calls: TMockCalls read FCalls;
    { Clear all recorded calls }
    procedure Reset;
  end;

{ ── Mock Object ───────────────────────────────────────────────────────────── }

type
  TMock = class
  private
    FState: TMockState;
  public
    constructor Create;
    destructor Destroy; override;

    { Configure a method's return value.
      Example: Mock.Setup('Foo').Returns('bar'); }
    function Setup(const AMethodName: string): IMockSetup;

    { Verify a method was called as expected.
      Example: Mock.Verify('Foo').CalledExactly(2); }
    function Verify(const AMethodName: string): IMockVerify;

    { Record a method call (called by generated stubs or manual recording).
      Example: Mock.RecordCall('Foo', ['arg1', 'arg2']); }
    procedure RecordCall(const AMethodName: string;
      const AArgs: array of string);

    { Get the configured return value for a method.
      Returns '' if not configured. }
    function GetReturn(const AMethodName: string): string;

    { Get the configured return value as Int64. Returns 0 if not configured. }
    function GetReturnInt(const AMethodName: string): Int64;

    { Get the configured return value as Boolean. Returns False if not configured. }
    function GetReturnBool(const AMethodName: string): Boolean;

    { Get call count for a method }
    function CallCount(const AMethodName: string): Integer;

    { Reset all recorded calls (keeps setup configuration) }
    procedure ResetCalls;

    { Access to the raw state for advanced usage }
    property State: TMockState read FState;
  end;

implementation

uses
  nextpas.core.text.conv;

{ ── TMockValue helpers ─────────────────────────────────────────────────────── }

function MockUnsetValue: TMockValue;
begin
  Result.Kind    := mvUnset;
  Result.StrVal  := '';
  Result.IntVal  := 0;
  Result.BoolVal := False;
  Result.DblVal  := 0.0;
end;

function MockStr(const AValue: string): TMockValue;
begin
  Result         := MockUnsetValue;
  Result.Kind    := mvString;
  Result.StrVal  := AValue;
end;

function MockInt(AValue: Int64): TMockValue;
begin
  Result         := MockUnsetValue;
  Result.Kind    := mvInt64;
  Result.IntVal  := AValue;
end;

function MockBool(AValue: Boolean): TMockValue;
begin
  Result         := MockUnsetValue;
  Result.Kind    := mvBool;
  Result.BoolVal := AValue;
end;

function MockDouble(AValue: Double): TMockValue;
begin
  Result         := MockUnsetValue;
  Result.Kind    := mvDouble;
  Result.DblVal  := AValue;
end;

function MockValueToString(const AValue: TMockValue): string;
begin
  case AValue.Kind of
    mvString:
      Result := AValue.StrVal;
    mvInt64:
      Result := IntToStr(AValue.IntVal);
    mvBool:
      if AValue.BoolVal then
        Result := 'true'
      else
        Result := 'false';
    mvDouble:
      Result := FloatToStr(AValue.DblVal);
  else
    Result := '';
  end;
end;

{ ── TMockState ────────────────────────────────────────────────────────────── }

constructor TMockState.Create;
begin
  inherited Create;
  FCalls  := nil;
  FSetups := nil;
end;

destructor TMockState.Destroy;
begin
  FCalls  := nil;
  FSetups := nil;
  inherited Destroy;
end;

procedure TMockState.RecordCall(const AMethodName: string;
  const AArgs: array of string);
var
  LCall: TMockCall;
  I: Integer;
begin
  LCall.MethodName := AMethodName;
  LCall.HasResult  := False;
  LCall.ResultValue := '';
  LCall.TypedReturnValue := MockUnsetValue;
  SetLength(LCall.Args, Length(AArgs));
  SetLength(LCall.TypedArgs, Length(AArgs));
  for I := 0 to High(AArgs) do
  begin
    LCall.Args[I] := AArgs[I];
    LCall.TypedArgs[I] := MockStr(AArgs[I]);
  end;

  SetLength(FCalls, Length(FCalls) + 1);
  FCalls[High(FCalls)] := LCall;
end;

procedure TMockState.RecordCallTyped(const AMethodName: string;
  const AArgs: array of TMockValue);
var
  LCall: TMockCall;
  I: Integer;
begin
  LCall.MethodName := AMethodName;
  LCall.HasResult  := False;
  LCall.ResultValue := '';
  LCall.TypedReturnValue := MockUnsetValue;
  SetLength(LCall.Args, Length(AArgs));
  SetLength(LCall.TypedArgs, Length(AArgs));
  for I := 0 to High(AArgs) do
  begin
    LCall.TypedArgs[I] := AArgs[I];
    LCall.Args[I] := MockValueToString(AArgs[I]);
  end;

  SetLength(FCalls, Length(FCalls) + 1);
  FCalls[High(FCalls)] := LCall;
end;

function TMockState.GetReturn(const AMethodName: string): string;
var
  I: Integer;
begin
  for I := High(FSetups) downto 0 do
  begin
    if FSetups[I].MethodName = AMethodName then
      Exit(FSetups[I].ResultValue);
  end;
  Result := '';
end;

function TMockState.GetReturnTyped(const AMethodName: string;
  const AArgs: array of TMockValue): TMockValue;
var
  I: Integer;
begin
  for I := High(FSetups) downto 0 do
  begin
    if FSetups[I].MethodName = AMethodName then
      Exit(FSetups[I].TypedReturnValue);
  end;
  Result := MockUnsetValue;
end;

procedure TMockState.SetReturn(const AMethodName, AValue: string);
var
  LSetup: TMockCall;
  I: Integer;
begin
  { R6-20: Override existing setup for the same method instead of appending }
  for I := 0 to High(FSetups) do
  begin
    if FSetups[I].MethodName = AMethodName then
    begin
      FSetups[I].ResultValue      := AValue;
      FSetups[I].TypedReturnValue := MockStr(AValue);
      FSetups[I].HasResult        := True;
      Exit;
    end;
  end;
  { No existing setup found — append new slot }
  LSetup.MethodName       := AMethodName;
  LSetup.ResultValue      := AValue;
  LSetup.TypedReturnValue := MockStr(AValue);
  LSetup.HasResult        := True;
  LSetup.Args             := nil;
  LSetup.TypedArgs        := nil;
  SetLength(FSetups, Length(FSetups) + 1);
  FSetups[High(FSetups)] := LSetup;
end;

function TMockState.CallCount(const AMethodName: string): Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to High(FCalls) do
    if FCalls[I].MethodName = AMethodName then
      Inc(Result);
end;

procedure TMockState.Reset;
begin
  FCalls := nil;
end;

{ ── IMockSetup implementation ──────────────────────────────────────────────── }

type
  TMockSetup = class(TInterfacedObject, IMockSetup)
  private
    FState: TMockState;
    FMethod: string;
  public
    constructor Create(AState: TMockState; const AMethod: string);
    function Returns(const AValue: string): IMockSetup;
    function ReturnsInt(AValue: Int64): IMockSetup;
    function ReturnsBool(AValue: Boolean): IMockSetup;
  end;

constructor TMockSetup.Create(AState: TMockState; const AMethod: string);
begin
  inherited Create;
  FState  := AState;
  FMethod := AMethod;
end;

function TMockSetup.Returns(const AValue: string): IMockSetup;
begin
  FState.SetReturn(FMethod, AValue);
  Result := Self;
end;

function TMockSetup.ReturnsInt(AValue: Int64): IMockSetup;
begin
  FState.SetReturn(FMethod, IntToStr(AValue));
  Result := Self;
end;

function TMockSetup.ReturnsBool(AValue: Boolean): IMockSetup;
begin
  if AValue then
    FState.SetReturn(FMethod, 'true')
  else
    FState.SetReturn(FMethod, 'false');
  Result := Self;
end;

{ ── IMockVerify implementation ─────────────────────────────────────────────── }

type
  TMockVerifier = class(TInterfacedObject, IMockVerify)
  private
    FState: TMockState;
    FMethod: string;
  public
    constructor Create(AState: TMockState; const AMethod: string);
    procedure CalledExactly(ACount: Integer);
    procedure CalledAtLeast(ACount: Integer);
    procedure CalledAtMost(ACount: Integer);
    procedure CalledNever;
    procedure CalledOnce;
  end;

constructor TMockVerifier.Create(AState: TMockState; const AMethod: string);
begin
  inherited Create;
  FState  := AState;
  FMethod := AMethod;
end;

procedure TMockVerifier.CalledExactly(ACount: Integer);
var
  LCount: Integer;
begin
  LCount := FState.CallCount(FMethod);
  if LCount <> ACount then
    InternalFail('Expected ' + FMethod + ' called exactly ' +
      IntToStr(ACount) + ' time(s), but was called ' +
      IntToStr(LCount) + ' time(s)');
end;

procedure TMockVerifier.CalledAtLeast(ACount: Integer);
var
  LCount: Integer;
begin
  LCount := FState.CallCount(FMethod);
  if LCount < ACount then
    InternalFail('Expected ' + FMethod + ' called at least ' +
      IntToStr(ACount) + ' time(s), but was called ' +
      IntToStr(LCount) + ' time(s)');
end;

procedure TMockVerifier.CalledAtMost(ACount: Integer);
var
  LCount: Integer;
begin
  LCount := FState.CallCount(FMethod);
  if LCount > ACount then
    InternalFail('Expected ' + FMethod + ' called at most ' +
      IntToStr(ACount) + ' time(s), but was called ' +
      IntToStr(LCount) + ' time(s)');
end;

procedure TMockVerifier.CalledNever;
begin
  CalledExactly(0);
end;

procedure TMockVerifier.CalledOnce;
begin
  CalledExactly(1);
end;

{ ── TMock ─────────────────────────────────────────────────────────────────── }

constructor TMock.Create;
begin
  inherited Create;
  FState := TMockState.Create;
end;

destructor TMock.Destroy;
begin
  FState.Free;
  inherited Destroy;
end;

function TMock.Setup(const AMethodName: string): IMockSetup;
begin
  Result := TMockSetup.Create(FState, AMethodName);
end;

function TMock.Verify(const AMethodName: string): IMockVerify;
begin
  Result := TMockVerifier.Create(FState, AMethodName);
end;

procedure TMock.RecordCall(const AMethodName: string;
  const AArgs: array of string);
begin
  FState.RecordCall(AMethodName, AArgs);
end;

function TMock.GetReturn(const AMethodName: string): string;
begin
  Result := FState.GetReturn(AMethodName);
end;

function TMock.GetReturnInt(const AMethodName: string): Int64;
var
  LVal: string;
begin
  LVal := FState.GetReturn(AMethodName);
  if LVal = '' then
    Exit(0);
  if not TryStrToInt64(LVal, Result) then
    Result := 0;
end;

function TMock.GetReturnBool(const AMethodName: string): Boolean;
begin
  Result := SameText(FState.GetReturn(AMethodName), 'true');
end;

function TMock.CallCount(const AMethodName: string): Integer;
begin
  Result := FState.CallCount(AMethodName);
end;

procedure TMock.ResetCalls;
begin
  FState.Reset;
end;

end.
