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
    { Configure the return value as Double }
    function ReturnsDouble(const AValue: Double): IMockSetup;
    { Mark this setup for ordered verification (InOrder) }
    function InOrder: IMockSetup;
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
    { Times(N) — synonym for CalledExactly(N), more fluent API }
    function  Times(N: Integer): IMockVerify;
    { Verify this method was called before AOtherMethod (by call order) }
    function  CalledBefore(const AOtherMethod: string): IMockVerify;
    { Verify this method was called after AOtherMethod (by call order) }
    function  CalledAfter(const AOtherMethod: string): IMockVerify;
    { Verify at least one call was made with matching arguments }
    function  CalledWith(const AArgs: array of string): IMockVerify;
    { Verify exactly N calls were made with matching arguments }
    function  CalledExactlyWith(ACount: Integer;
      const AArgs: array of string): IMockVerify;
  end;

{ ── Mock State ────────────────────────────────────────────────────────────── }

type
  TMockState = class
  private
    FCalls   : TMockCalls;
    FSetups  : specialize TArray<TMockCall>;
    FCallOrder: specialize TArray<string>;  { records method names in call order }
    procedure SetTypedReturnValue(const AMethodName: string;
      const AValue: TMockValue);
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
    function GetReturnInt64(const AMethodName: string;
      const AArgs: array of string): Int64;
    function GetReturnBool(const AMethodName: string;
      const AArgs: array of string): Boolean;
    { Configure a return value }
    procedure SetReturn(const AMethodName, AValue: string);
    { Get call count for a method }
    function CallCount(const AMethodName: string): Integer;
    { Get call count for a method with matching arguments }
    function MatchingCallCount(const AMethodName: string;
      const AArgs: array of string): Integer;
    { Get all recorded calls }
    property Calls: TMockCalls read FCalls;
    { Get the recorded call order (method names in sequence) }
    property CallOrder: specialize TArray<string> read FCallOrder;
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
    procedure RecordCallTyped(const AMethodName: string;
      const AArgs: array of TMockValue);

    { Get the configured return value for a method.
      Returns '' if not configured. }
    function GetReturn(const AMethodName: string): string;

    { Get the configured return value as Int64. Returns 0 if not configured. }
    function GetReturnInt(const AMethodName: string): Int64; overload;
    function GetReturnInt(const AMethodName: string;
      const AArgs: array of string): Int64; overload;

    { Get the configured return value as Boolean. Returns False if not configured. }
    function GetReturnBool(const AMethodName: string): Boolean; overload;
    function GetReturnBool(const AMethodName: string;
      const AArgs: array of string): Boolean; overload;

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

procedure BuildTypedStringArgs(const AArgs: array of string;
  out ATypedArgs: TMockValues);
var
  I: Integer;
begin
  SetLength(ATypedArgs, Length(AArgs));
  for I := 0 to High(AArgs) do
    ATypedArgs[I] := MockStr(AArgs[I]);
end;

{ ── TMockState ────────────────────────────────────────────────────────────── }

constructor TMockState.Create;
begin
  inherited Create;
  FCalls  := nil;
  FSetups := nil;
  FCallOrder := nil;
end;

destructor TMockState.Destroy;
begin
  FCalls  := nil;
  FSetups := nil;
  FCallOrder := nil;
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
  { Track call order }
  SetLength(FCallOrder, Length(FCallOrder) + 1);
  FCallOrder[High(FCallOrder)] := AMethodName;
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
  { Track call order }
  SetLength(FCallOrder, Length(FCallOrder) + 1);
  FCallOrder[High(FCallOrder)] := AMethodName;
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

function TMockState.GetReturnInt64(const AMethodName: string;
  const AArgs: array of string): Int64;
var
  LTypedArgs: TMockValues;
  LTyped: TMockValue;
  LValue: string;
begin
  BuildTypedStringArgs(AArgs, LTypedArgs);
  LTyped := GetReturnTyped(AMethodName, LTypedArgs);
  if LTyped.Kind = mvInt64 then
    Exit(LTyped.IntVal);

  LValue := GetReturn(AMethodName);
  if LValue = '' then
    Exit(0);
  if not TryStrToInt64(LValue, Result) then
    Result := 0;
end;

function TMockState.GetReturnBool(const AMethodName: string;
  const AArgs: array of string): Boolean;
var
  LTypedArgs: TMockValues;
  LTyped: TMockValue;
begin
  BuildTypedStringArgs(AArgs, LTypedArgs);
  LTyped := GetReturnTyped(AMethodName, LTypedArgs);
  if LTyped.Kind = mvBool then
    Exit(LTyped.BoolVal);

  Result := SameText(GetReturn(AMethodName), 'true');
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

procedure TMockState.SetTypedReturnValue(const AMethodName: string;
  const AValue: TMockValue);
var
  LSetup: TMockCall;
  I: Integer;
begin
  for I := 0 to High(FSetups) do
  begin
    if FSetups[I].MethodName = AMethodName then
    begin
      FSetups[I].TypedReturnValue := AValue;
      Exit;
    end;
  end;

  LSetup.MethodName       := AMethodName;
  LSetup.Args             := nil;
  LSetup.TypedArgs        := nil;
  LSetup.HasResult        := True;
  LSetup.ResultValue      := MockValueToString(AValue);
  LSetup.TypedReturnValue := AValue;
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

function TMockState.MatchingCallCount(const AMethodName: string;
  const AArgs: array of string): Integer;
var
  I, J: Integer;
  LMatch: Boolean;
begin
  Result := 0;
  for I := 0 to High(FCalls) do
  begin
    if FCalls[I].MethodName <> AMethodName then
      Continue;
    if Length(FCalls[I].Args) <> Length(AArgs) then
      Continue;
    LMatch := True;
    for J := 0 to High(AArgs) do
      if FCalls[I].Args[J] <> AArgs[J] then
      begin
        LMatch := False;
        Break;
      end;
    if LMatch then
      Inc(Result);
  end;
end;

procedure TMockState.Reset;
begin
  FCalls := nil;
  FCallOrder := nil;
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
    function ReturnsDouble(const AValue: Double): IMockSetup;
    function InOrder: IMockSetup;
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
  FState.SetTypedReturnValue(FMethod, MockInt(AValue));
  Result := Self;
end;

function TMockSetup.ReturnsBool(AValue: Boolean): IMockSetup;
begin
  if AValue then
    FState.SetReturn(FMethod, 'true')
  else
    FState.SetReturn(FMethod, 'false');
  FState.SetTypedReturnValue(FMethod, MockBool(AValue));
  Result := Self;
end;

function TMockSetup.ReturnsDouble(const AValue: Double): IMockSetup;
begin
  FState.SetReturn(FMethod, FloatToStr(AValue));
  FState.SetTypedReturnValue(FMethod, MockDouble(AValue));
  Result := Self;
end;

function TMockSetup.InOrder: IMockSetup;
begin
  { InOrder is a marker — call order tracking is always on.
    This method exists for fluent API readability:
      Mock.Setup('Foo').InOrder.Returns('x'); }
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
    function  Times(N: Integer): IMockVerify;
    function  CalledBefore(const AOtherMethod: string): IMockVerify;
    function  CalledAfter(const AOtherMethod: string): IMockVerify;
    function  CalledWith(const AArgs: array of string): IMockVerify;
    function  CalledExactlyWith(ACount: Integer;
      const AArgs: array of string): IMockVerify;
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

function TMockVerifier.Times(N: Integer): IMockVerify;
begin
  CalledExactly(N);
  Result := Self;
end;

function TMockVerifier.CalledBefore(const AOtherMethod: string): IMockVerify;
var
  I, LSelfIdx, LOtherIdx: Integer;
begin
  LSelfIdx := -1;
  LOtherIdx := -1;
  for I := 0 to High(FState.CallOrder) do
  begin
    { Find first occurrence of each method }
    if (LSelfIdx < 0) and (FState.CallOrder[I] = FMethod) then
      LSelfIdx := I;
    if (LOtherIdx < 0) and (FState.CallOrder[I] = AOtherMethod) then
      LOtherIdx := I;
    if (LSelfIdx >= 0) and (LOtherIdx >= 0) then
      Break;
  end;
  if LSelfIdx < 0 then
    InternalFail('Expected ' + FMethod + ' called before ' +
      AOtherMethod + ', but ' + FMethod + ' was never called');
  if LOtherIdx < 0 then
    InternalFail('Expected ' + FMethod + ' called before ' +
      AOtherMethod + ', but ' + AOtherMethod + ' was never called');
  if LSelfIdx >= LOtherIdx then
    InternalFail('Expected ' + FMethod + ' called before ' +
      AOtherMethod + ', but ' + FMethod + ' was called at index ' +
      IntToStr(LSelfIdx) + ' (after ' + AOtherMethod + ' at index ' +
      IntToStr(LOtherIdx) + ')');
  Result := Self;
end;

function TMockVerifier.CalledAfter(const AOtherMethod: string): IMockVerify;
var
  I, LSelfIdx, LOtherIdx: Integer;
begin
  LSelfIdx := -1;
  LOtherIdx := -1;
  for I := 0 to High(FState.CallOrder) do
  begin
    { Find first occurrence of each method }
    if (LSelfIdx < 0) and (FState.CallOrder[I] = FMethod) then
      LSelfIdx := I;
    if (LOtherIdx < 0) and (FState.CallOrder[I] = AOtherMethod) then
      LOtherIdx := I;
    if (LSelfIdx >= 0) and (LOtherIdx >= 0) then
      Break;
  end;
  if LSelfIdx < 0 then
    InternalFail('Expected ' + FMethod + ' called after ' +
      AOtherMethod + ', but ' + FMethod + ' was never called');
  if LOtherIdx < 0 then
    InternalFail('Expected ' + FMethod + ' called after ' +
      AOtherMethod + ', but ' + AOtherMethod + ' was never called');
  if LSelfIdx <= LOtherIdx then
    InternalFail('Expected ' + FMethod + ' called after ' +
      AOtherMethod + ', but ' + FMethod + ' was called at index ' +
      IntToStr(LSelfIdx) + ' (before ' + AOtherMethod + ' at index ' +
      IntToStr(LOtherIdx) + ')');
  Result := Self;
end;

function TMockVerifier.CalledWith(const AArgs: array of string): IMockVerify;
var
  LCount: Integer;
begin
  LCount := FState.MatchingCallCount(FMethod, AArgs);
  if LCount = 0 then
    InternalFail('Expected ' + FMethod + ' called with matching args, ' +
      'but no matching call found (total calls: ' +
      IntToStr(FState.CallCount(FMethod)) + ')');
  Result := Self;
end;

function TMockVerifier.CalledExactlyWith(ACount: Integer;
  const AArgs: array of string): IMockVerify;
var
  LCount: Integer;
begin
  LCount := FState.MatchingCallCount(FMethod, AArgs);
  if LCount <> ACount then
    InternalFail('Expected ' + FMethod + ' called exactly ' +
      IntToStr(ACount) + ' times with matching args, but was called ' +
      IntToStr(LCount) + ' times');
  Result := Self;
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

procedure TMock.RecordCallTyped(const AMethodName: string;
  const AArgs: array of TMockValue);
begin
  FState.RecordCallTyped(AMethodName, AArgs);
end;

function TMock.GetReturn(const AMethodName: string): string;
begin
  Result := FState.GetReturn(AMethodName);
end;

function TMock.GetReturnInt(const AMethodName: string): Int64;
begin
  Result := FState.GetReturnInt64(AMethodName, []);
end;

function TMock.GetReturnInt(const AMethodName: string;
  const AArgs: array of string): Int64;
begin
  Result := FState.GetReturnInt64(AMethodName, AArgs);
end;

function TMock.GetReturnBool(const AMethodName: string): Boolean;
begin
  Result := FState.GetReturnBool(AMethodName, []);
end;

function TMock.GetReturnBool(const AMethodName: string;
  const AArgs: array of string): Boolean;
begin
  Result := FState.GetReturnBool(AMethodName, AArgs);
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
