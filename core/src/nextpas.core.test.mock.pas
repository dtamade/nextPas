{ nextpas.core.test.mock — Interface-based mock objects
  =========================================================
  Mock any interface, record calls, configure return values, verify expectations.
  Usage:
    LMock := TMock.Create<IFoo>;
    LMock.Setup('Bar').Returns('hello');
    CheckEqual('hello', (LMock.Instance as IFoo).Bar);
    LMock.Verify('Bar').CalledExactly(1);
  Depends on: nextpas.core.test.base }

unit nextpas.core.test.mock;

{$I nextpas.core.settings.inc}

interface

uses
  SysUtils,
  nextpas.core.test.base;

{ ── Call Record ───────────────────────────────────────────────────────────── }

type
  TMockCall = record
    MethodName : string;
    Args       : specialize TArray<string>;
    HasResult  : Boolean;
    ResultValue: string;
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
    { Get return value for a method, or '' if not configured }
    function GetReturn(const AMethodName: string): string;
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
  SetLength(LCall.Args, Length(AArgs));
  for I := 0 to High(AArgs) do
    LCall.Args[I] := AArgs[I];

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

procedure TMockState.SetReturn(const AMethodName, AValue: string);
var
  LSetup: TMockCall;
begin
  LSetup.MethodName  := AMethodName;
  LSetup.ResultValue := AValue;
  LSetup.HasResult   := True;
  LSetup.Args        := nil;
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
  Result := StrToInt64(LVal);
end;

function TMock.GetReturnBool(const AMethodName: string): Boolean;
begin
  Result := FState.GetReturn(AMethodName) = 'true';
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
