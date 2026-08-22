{ nextpas.core.test.mock — Manual mock helper
  =========================================================
  String-based call recorder with configurable return values and
  call-count verification.  Not an interface proxy — callers record
  calls manually and retrieve configured return values.

  Dual API Design (intentional, not redundant):
  - String API: Mock.CalledWith(['a', 'b']) — quick, flexible, no type safety
  - Typed API:  Mock.CalledWith([MockStr('a'), MockInt(42)]) — type-safe matching
  Both APIs are actively used (30+ calls each in tests). The typed API prevents
  subtle bugs where MockInt(42) ≠ MockStr('42').

  Thread safety: NOT thread-safe. TMockState uses unsynchronized
  dynamic arrays (FCalls, FSetups, FCallOrder). Use only within a
  single test; for parallel tests, each worker must have its own
  TMock instance.

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
  nextpas.core.system,
  nextpas.core.text.conv,
  nextpas.core.platform.thread,
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
function MockInt(const AValue: Int64): TMockValue;
function MockBool(AValue: Boolean): TMockValue;
function MockDouble(const AValue: Double): TMockValue;

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
    ArgHash         : Integer;  { P2 #6: pre-computed hash for O(1) arg mismatch detection }
    StrArgHash      : Integer;  { hash over legacy string Args (all-MockStr domain);
                                  ArgHash uses typed kinds, so a typed-recorded call
                                  would never hash-match a string-domain query even
                                  though the field comparison uses Args }
  end;

  TMockCalls = specialize TArray<TMockCall>;

{ ── Setup (configure return values) ───────────────────────────────────────── }

type
  IMockWhen = interface;

  IMockSetup = interface
    ['{A7B2C3D4-1234-5678-ABCD-EF0123456789}']
    { Configure the return value for this method }
    function Returns(const AValue: string): IMockSetup;
    { Configure the return value as Integer }
    function ReturnsInt(const AValue: Int64): IMockSetup;
    { Configure the return value as Boolean }
    function ReturnsBool(AValue: Boolean): IMockSetup;
    { Configure the return value as Double }
    function ReturnsDouble(const AValue: Double): IMockSetup;
    { Mark this setup for ordered verification (InOrder) }
    function InOrder: IMockSetup;
    { Configure parameter-dependent return value (E-09 When API).
      When args match the recorded call, the configured return is used.
      Example: Mock.Setup('Add').When([MockInt(1)]).ReturnsInt(10); }
    function When(const AArgs: array of TMockValue): IMockWhen;
  end;

  {** Parameter-dependent return configuration (E-09) }
  IMockWhen = interface
    ['{C9D0E1F2-3456-789A-CDEF-012345678901}']
    function Returns(const AValue: string): IMockSetup;
    function ReturnsInt(const AValue: Int64): IMockSetup;
    function ReturnsBool(AValue: Boolean): IMockSetup;
    function ReturnsDouble(const AValue: Double): IMockSetup;
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
    { Verify at least one call was made with typed matching arguments.
      Compares TMockValue kind + value, so MockInt(42) ≠ MockStr('42'). }
    function  CalledWith(const AArgs: array of TMockValue): IMockVerify;
    { Verify exactly N calls were made with matching arguments }
    function  CalledExactlyWith(ACount: Integer;
      const AArgs: array of string): IMockVerify;
    { Verify exactly N calls were made with typed matching arguments }
    function  CalledExactlyWith(ACount: Integer;
      const AArgs: array of TMockValue): IMockVerify;
    { Return the actual call count for this method (no assertion).
      Useful for conditional logic: if Mock.Verify('Foo').Count > 0 then ... }
    function  Count: Integer;
    { Verify that the given methods were called in the specified order.
      Checks that the first occurrence of each method in FCallOrder
      appears in the given sequence. Returns Self for chaining. }
    function  CalledInOrder(const AMethods: array of string): IMockVerify;
  end;

{ ── Mock State ────────────────────────────────────────────────────────────── }

type
  {** E-09: Parameter-dependent return entry }
  TMockWhenEntry = record
    MethodName: string;
    Args      : TMockValues;
    ReturnValue: TMockValue;
    HasReturn : Boolean;
    ReturnStr : string;
  end;

  TMockState = class
  private
    FCalls   : TMockCalls;
    FSetups  : specialize TArray<TMockCall>;
    FCallOrder: specialize TArray<string>;  { records method names in call order }
    FWhenEntries: specialize TArray<TMockWhenEntry>; { E-09: conditional returns }
    FWhenMethodNames: specialize TArray<string>; { methods configured only via When }
    FOwnerThreadId: UInt64; { thread that created this mock; 0 = not yet assigned }
    procedure CheckThread(const AMethod: string);
    procedure AppendCall(const ACall: TMockCall; const AMethodName: string);
    procedure AppendSetup(const ASetup: TMockCall);
    procedure SetTypedReturnValue(const AMethodName: string;
      const AValue: TMockValue);
    { Track a method name in FWhenMethodNames if not already present }
    procedure TrackWhenMethod(const AMethodName: string);
  public
    constructor Create;
    destructor Destroy; override;
    { Record a call }
    procedure RecordCall(const AMethodName: string;
      const AArgs: array of string);
    procedure RecordCallTyped(const AMethodName: string;
      const AArgs: array of TMockValue);
    { Get return value for a method, or '' if not configured }
    function GetReturn(const AMethodName: string): string; overload;
    function GetReturn(const AMethodName: string;
      const AArgs: array of string): string; overload;
    function GetReturn(const AMethodName: string;
      const AArgs: array of TMockValue): string; overload;
    function GetReturnTyped(const AMethodName: string;
      const AArgs: array of TMockValue): TMockValue;
    function GetReturnInt64(const AMethodName: string;
      const AArgs: array of string): Int64;
    function GetReturnBool(const AMethodName: string;
      const AArgs: array of string): Boolean;
    { Configure a return value }
    procedure SetReturn(const AMethodName, AValue: string);
    { E-09: Add a parameter-dependent return entry }
    procedure AddWhenEntry(const AMethodName: string;
      const AArgs: array of TMockValue; const AValue: TMockValue;
      const AReturnStr: string);
    { E-09: Find matching When entry for given method + args }
    function FindWhenEntry(const AMethodName: string;
      const AArgs: array of TMockValue): Integer;
    { Get call count for a method }
    function CallCount(const AMethodName: string): Integer;
    { Get call count for a method with matching arguments }
    function MatchingCallCount(const AMethodName: string;
      const AArgs: array of string): Integer;
    { Get call count for a method with typed matching arguments.
      Compares TMockValue kind + value. }
    function MatchingCallCountTyped(const AMethodName: string;
      const AArgs: array of TMockValue): Integer;
    { Get all recorded calls }
    property Calls: TMockCalls read FCalls;
    { Get the recorded call order (method names in sequence) }
    property CallOrder: specialize TArray<string> read FCallOrder;
    { Clear all recorded calls }
    procedure Reset;
    { Clear all recorded calls AND setup configurations }
    procedure ResetAll;
    { Get names of all set-up methods }
    function GetSetupMethodNames: specialize TArray<string>;
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

    { Verify all set-up methods were called at least once.
      Checks methods configured via Setup.Returns AND Setup.When.
      Fails with a list of uncalled methods if any setup was never invoked. }
    procedure VerifyAll;

    { Verify that every set-up method was called at least once AND no calls
      were made to methods that were never set up.
      Stricter than VerifyAll — catches unexpected/spurious calls. }
    procedure VerifyNoMoreInteractions;

    { Record a method call (called by generated stubs or manual recording).
      Example: Mock.RecordCall('Foo', ['arg1', 'arg2']); }
    procedure RecordCall(const AMethodName: string;
      const AArgs: array of string);
    procedure RecordCallTyped(const AMethodName: string;
      const AArgs: array of TMockValue);

    { Get the configured return value for a method.
      Returns '' if not configured. }
    function GetReturn(const AMethodName: string): string; overload;
    function GetReturn(const AMethodName: string;
      const AArgs: array of string): string; overload;
    function GetReturn(const AMethodName: string;
      const AArgs: array of TMockValue): string; overload;

    { Get the configured return value as Int64. Returns 0 if not configured. }
    function GetReturnInt(const AMethodName: string): Int64; overload;
    function GetReturnInt(const AMethodName: string;
      const AArgs: array of string): Int64; overload;
    function GetReturnInt(const AMethodName: string;
      const AArgs: array of TMockValue): Int64; overload;

    { Get the configured return value as Boolean. Returns False if not configured. }
    function GetReturnBool(const AMethodName: string): Boolean; overload;
    function GetReturnBool(const AMethodName: string;
      const AArgs: array of string): Boolean; overload;
    function GetReturnBool(const AMethodName: string;
      const AArgs: array of TMockValue): Boolean; overload;

    { Get the configured return value as Double. Returns 0.0 if not configured. }
    function GetReturnDouble(const AMethodName: string): Double; overload;
    function GetReturnDouble(const AMethodName: string;
      const AArgs: array of string): Double; overload;
    function GetReturnDouble(const AMethodName: string;
      const AArgs: array of TMockValue): Double; overload;

    { Get call count for a method }
    function CallCount(const AMethodName: string): Integer;

    { Reset all recorded calls (keeps setup configuration) }
    procedure ResetCalls;
    { Reset all recorded calls AND setup configurations }
    procedure ResetAll;

    { Get formatted call history for debugging.
      Returns all recorded calls with arguments and return values:
        Foo('a', 'b') => 'result'
        Bar('c') => (void)
      Useful for test failure diagnostics. }
    function GetCallHistory: string;

    { Verify methods were called in the given order (by call order tracking).
      Each method in AMethods must appear after the previous one in the
      recorded call order. Methods don't need to be consecutive.
      Example: Mock.VerifyInOrder(['Init', 'Process', 'Finish']); }
    procedure VerifyInOrder(const AMethods: array of string);

    { Access to the raw state for advanced usage }
    property State: TMockState read FState;
  end;

{ ── Mock Argument Captor ──────────────────────────────────────────────────── }

type
  {** TMockCaptor — captures arguments from mock calls for later assertion.
    Usage:
      var LCaptor: TMockCaptor;
      LCaptor := TMockCaptor.Create;
      // After recording calls:
      LMock.RecordCall('Foo', ['hello']);
      // Capture from the last call to 'Foo':
      LCaptor.CaptureFrom(LMock, 'Foo', 0); // capture arg index 0
      CheckEqual('hello', LCaptor.Value);
      // Or capture all args from all calls:
      LCaptor.CaptureAllFrom(LMock, 'Foo', 0);
      CheckEqual(1, LCaptor.Count);
      CheckEqual('hello', LCaptor.Values[0]); }
  TMockCaptor = class
  private
    FValues: specialize TArray<string>;
    FTypedValues: specialize TArray<TMockValue>;
    function GetCount: Integer;
    function GetValue: string;
    function GetTypedValue: TMockValue;
    function GetValues(AIndex: Integer): string;
    function GetTypedValues(AIndex: Integer): TMockValue;
  public
    constructor Create;
    { Capture the argument at AArgIndex from the last call to AMethod.
      Fails if no calls recorded or AArgIndex out of range. }
    procedure CaptureFrom(const AMock: TMock; const AMethod: string;
      AArgIndex: Integer);
    { Capture the argument at AArgIndex from ALL calls to AMethod.
      Appends to internal list. }
    procedure CaptureAllFrom(const AMock: TMock; const AMethod: string;
      AArgIndex: Integer);
    { Capture the typed argument at AArgIndex from the last call to AMethod. }
    procedure CaptureTypedFrom(const AMock: TMock; const AMethod: string;
      AArgIndex: Integer);
    { Capture the typed argument at AArgIndex from ALL calls to AMethod. }
    procedure CaptureAllTypedFrom(const AMock: TMock; const AMethod: string;
      AArgIndex: Integer);
    { Number of captured values }
    property Count: Integer read GetCount;
    { Last captured string value (convenience for single-capture) }
    property Value: string read GetValue;
    { Last captured typed value }
    property TypedValue: TMockValue read GetTypedValue;
    { Captured string values by index }
    property Values[AIndex: Integer]: string read GetValues;
    { Captured typed values by index }
    property TypedValues[AIndex: Integer]: TMockValue read GetTypedValues;
    { Clear all captured values }
    procedure Reset;
  end;

implementation

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

function MockInt(const AValue: Int64): TMockValue;
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

function MockDouble(const AValue: Double): TMockValue;
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

function MockValueEqual(const A, B: TMockValue): Boolean;
{ Deep equality: kind must match, then kind-specific value comparison. }
begin
  if A.Kind <> B.Kind then
    Exit(False);
  case A.Kind of
    mvString: Result := A.StrVal = B.StrVal;
    mvInt64:  Result := A.IntVal = B.IntVal;
    mvBool:   Result := A.BoolVal = B.BoolVal;
    mvDouble: Result := A.DblVal = B.DblVal; { exact bit-level; NaN ≠ NaN }
  else
    Result := True; { mvUnset == mvUnset }
  end;
end;

function MockValueHash(const AV: TMockValue): Integer;
{ Quick hash for O(1) early mismatch detection in MatchingCallCountTyped. }
begin
  Result := Ord(AV.Kind);
  case AV.Kind of
    mvUnset: ; { 无载体字段可混入，保留 Ord 基值 }
    mvString: Result := Result * 31 + Length(AV.StrVal);
    mvInt64:  Result := Result * 31 + Integer(AV.IntVal and $FFFFFFFF);
    mvBool:   Result := Result * 31 + Ord(AV.BoolVal);
    mvDouble: Result := Result * 31 + Integer(Trunc(AV.DblVal * 1000));
  end;
end;

{ ── Local helpers ──────────────────────────────────────────────────────────── }

function FormatArgs(const AArgs: array of string): string;
var I: Integer;
begin
  Result := '[';
  for I := 0 to High(AArgs) do
  begin
    if I > 0 then Result := Result + ', ';
    Result := Result + '"' + AArgs[I] + '"';
  end;
  Result := Result + ']';
end;

function FormatMockValue(const AV: TMockValue): string;
begin
  case AV.Kind of
    mvString:  Result := 'MockStr("' + AV.StrVal + '")';
    mvInt64:   Result := 'MockInt(' + IntToStr(AV.IntVal) + ')';
    mvBool:    if AV.BoolVal then Result := 'MockBool(true)'
               else Result := 'MockBool(false)';
    mvDouble:  Result := 'MockDouble(' + FloatToStr(AV.DblVal) + ')';
  else
    Result := '?';
  end;
end;

function FormatMockArgs(const AArgs: array of TMockValue): string;
var I: Integer;
begin
  Result := '[';
  for I := 0 to High(AArgs) do
  begin
    if I > 0 then Result := Result + ', ';
    Result := Result + FormatMockValue(AArgs[I]);
  end;
  Result := Result + ']';
end;

function FindFirstCallArgs(AState: TMockState; const AMethod: string): string;
var I: Integer;
begin
  for I := 0 to High(AState.Calls) do
    if AState.Calls[I].MethodName = AMethod then
      Exit(FormatArgs(AState.Calls[I].Args));
  Result := '(none)';
end;

procedure InitCallRecord(out ACall: TMockCall; const AName: string);
begin
  ACall.MethodName       := AName;
  ACall.HasResult        := False;
  ACall.ResultValue      := '';
  ACall.TypedReturnValue := MockUnsetValue;
  ACall.ArgHash          := 0;
  ACall.StrArgHash       := 0;
end;

procedure RecordOrder(var AOrder: specialize TArray<string>;
  const AName: string);
var
  LOldLen: Integer;
begin
  LOldLen := Length(AOrder);
  SetLength(AOrder, LOldLen + 1);
  AOrder[LOldLen] := AName;
end;

function FindSetupIndex(const ASetups: specialize TArray<TMockCall>;
  const AName: string): Integer;
var
  I: Integer;
begin
  for I := 0 to High(ASetups) do
    if ASetups[I].MethodName = AName then
      Exit(I);
  Result := -1;
end;

{ ── TMockState ────────────────────────────────────────────────────────────── }

constructor TMockState.Create;
begin
  inherited Create;
  FCalls  := nil;
  FSetups := nil;
  FCallOrder := nil;
  FWhenMethodNames := nil;
  FOwnerThreadId := 0; { assigned on first access }
end;

procedure TMockState.CheckThread(const AMethod: string);
var
  LCurrent: UInt64;
begin
  LCurrent := platform_thread_id;
  if FOwnerThreadId = 0 then
    FOwnerThreadId := LCurrent
  else if LCurrent <> FOwnerThreadId then
    InternalFail('TMock.' + AMethod + ': not thread-safe (created on thread ' +
      UIntToStr(FOwnerThreadId) + ', called from ' + UIntToStr(LCurrent) + ')');
end;

destructor TMockState.Destroy;
begin
  FCalls  := nil;
  FSetups := nil;
  FCallOrder := nil;
  FWhenEntries := nil;      { P2 #15 fix: clear conditional returns }
  FWhenMethodNames := nil;
  inherited Destroy;
end;

procedure TMockState.AppendCall(const ACall: TMockCall;
  const AMethodName: string);
var
  LOldLen: Integer;
begin
  LOldLen := Length(FCalls);
  SetLength(FCalls, LOldLen + 1);
  FCalls[LOldLen] := ACall;
  RecordOrder(FCallOrder, AMethodName);
end;

procedure TMockState.AppendSetup(const ASetup: TMockCall);
var
  LOldLen: Integer;
begin
  LOldLen := Length(FSetups);
  SetLength(FSetups, LOldLen + 1);
  FSetups[LOldLen] := ASetup;
end;

procedure TMockState.RecordCall(const AMethodName: string;
  const AArgs: array of string);
var
  LCall: TMockCall;
  I: Integer;
begin
  CheckThread('RecordCall');
  InitCallRecord(LCall, AMethodName);
  SetLength(LCall.Args, Length(AArgs));
  SetLength(LCall.TypedArgs, Length(AArgs));
  for I := 0 to High(AArgs) do
  begin
    LCall.Args[I] := AArgs[I];
    LCall.TypedArgs[I] := MockStr(AArgs[I]);
    LCall.ArgHash := LCall.ArgHash * 31 + MockValueHash(LCall.TypedArgs[I]);
  end;
  LCall.StrArgHash := LCall.ArgHash; { all-MockStr: both domains identical }
  AppendCall(LCall, AMethodName);
end;

procedure TMockState.RecordCallTyped(const AMethodName: string;
  const AArgs: array of TMockValue);
var
  LCall: TMockCall;
  I: Integer;
begin
  CheckThread('RecordCallTyped');
  InitCallRecord(LCall, AMethodName);
  SetLength(LCall.Args, Length(AArgs));
  SetLength(LCall.TypedArgs, Length(AArgs));
  for I := 0 to High(AArgs) do
  begin
    LCall.TypedArgs[I] := AArgs[I];
    LCall.Args[I] := MockValueToString(AArgs[I]);
    LCall.ArgHash := LCall.ArgHash * 31 + MockValueHash(AArgs[I]);
    LCall.StrArgHash := LCall.StrArgHash * 31 + MockValueHash(MockStr(LCall.Args[I]));
  end;
  AppendCall(LCall, AMethodName);
end;

function TMockState.GetReturn(const AMethodName: string): string;
var
  I: Integer;
begin
  CheckThread('GetReturn');
  for I := High(FSetups) downto 0 do
  begin
    if FSetups[I].MethodName = AMethodName then
      Exit(FSetups[I].ResultValue);
  end;
  Result := '';
end;

function TMockState.GetReturn(const AMethodName: string;
  const AArgs: array of string): string;
var
  LTypedArgs: TMockValues;
  LWhenIdx: Integer;
begin
  BuildTypedStringArgs(AArgs, LTypedArgs);
  LWhenIdx := FindWhenEntry(AMethodName, LTypedArgs);
  if LWhenIdx >= 0 then
    Exit(MockValueToString(FWhenEntries[LWhenIdx].ReturnValue));
  Result := GetReturn(AMethodName);
end;

function TMockState.GetReturn(const AMethodName: string;
  const AArgs: array of TMockValue): string;
var
  LWhenIdx: Integer;
begin
  LWhenIdx := FindWhenEntry(AMethodName, AArgs);
  if LWhenIdx >= 0 then
    Exit(MockValueToString(FWhenEntries[LWhenIdx].ReturnValue));
  Result := GetReturn(AMethodName);
end;

function TMockState.GetReturnTyped(const AMethodName: string;
  const AArgs: array of TMockValue): TMockValue;
var
  I, LWhenIdx: Integer;
begin
  { E-09: Check When entries first (parameter-dependent returns) }
  LWhenIdx := FindWhenEntry(AMethodName, AArgs);
  if LWhenIdx >= 0 then
    Exit(FWhenEntries[LWhenIdx].ReturnValue);
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
  LIdx: Integer;
begin
  { R6-20: Override existing setup for the same method instead of appending }
  LIdx := FindSetupIndex(FSetups, AMethodName);
  if LIdx >= 0 then
  begin
    FSetups[LIdx].ResultValue      := AValue;
    FSetups[LIdx].TypedReturnValue := MockStr(AValue);
    FSetups[LIdx].HasResult        := True;
    Exit;
  end;
  { No existing setup found — append new slot with geometric growth }
  LSetup.MethodName       := AMethodName;
  LSetup.ResultValue      := AValue;
  LSetup.TypedReturnValue := MockStr(AValue);
  LSetup.HasResult        := True;
  LSetup.Args             := nil;
  LSetup.TypedArgs        := nil;
  AppendSetup(LSetup);
end;

procedure TMockState.SetTypedReturnValue(const AMethodName: string;
  const AValue: TMockValue);
var
  LSetup: TMockCall;
  LIdx: Integer;
begin
  LIdx := FindSetupIndex(FSetups, AMethodName);
  if LIdx >= 0 then
  begin
    FSetups[LIdx].TypedReturnValue := AValue;
    Exit;
  end;

  LSetup.MethodName       := AMethodName;
  LSetup.Args             := nil;
  LSetup.TypedArgs        := nil;
  LSetup.HasResult        := True;
  LSetup.ResultValue      := MockValueToString(AValue);
  LSetup.TypedReturnValue := AValue;
  AppendSetup(LSetup);
end;

procedure TMockState.AddWhenEntry(const AMethodName: string;
  const AArgs: array of TMockValue; const AValue: TMockValue;
  const AReturnStr: string);
var
  LEntry: TMockWhenEntry;
  LOldLen, I: Integer;
begin
  LEntry.MethodName := AMethodName;
  SetLength(LEntry.Args, Length(AArgs));
  for I := 0 to High(AArgs) do
    LEntry.Args[I] := AArgs[I];
  LEntry.ReturnValue := AValue;
  LEntry.HasReturn := True;
  LEntry.ReturnStr := AReturnStr;
  LOldLen := Length(FWhenEntries);
  SetLength(FWhenEntries, LOldLen + 1);
  FWhenEntries[LOldLen] := LEntry;
  TrackWhenMethod(AMethodName);
end;

function TMockState.FindWhenEntry(const AMethodName: string;
  const AArgs: array of TMockValue): Integer;
var
  I, J: Integer;
  LMatch: Boolean;
begin
  for I := High(FWhenEntries) downto 0 do
  begin
    if FWhenEntries[I].MethodName <> AMethodName then
      Continue;
    if Length(FWhenEntries[I].Args) <> Length(AArgs) then
      Continue;
    LMatch := True;
    for J := 0 to High(AArgs) do
    begin
      if not MockValueEqual(FWhenEntries[I].Args[J], AArgs[J]) then
      begin
        LMatch := False;
        Break;
      end;
    end;
    if LMatch then
      Exit(I);
  end;
  Result := -1;
end;

procedure TMockState.TrackWhenMethod(const AMethodName: string);
var
  I: Integer;
begin
  for I := 0 to High(FWhenMethodNames) do
    if FWhenMethodNames[I] = AMethodName then
      Exit;
  SetLength(FWhenMethodNames, Length(FWhenMethodNames) + 1);
  FWhenMethodNames[High(FWhenMethodNames)] := AMethodName;
end;

function TMockState.CallCount(const AMethodName: string): Integer;
var
  I: Integer;
begin
  CheckThread('CallCount');
  Result := 0;
  for I := 0 to High(FCalls) do
    if FCalls[I].MethodName = AMethodName then
      Inc(Result);
end;

function TMockState.MatchingCallCount(const AMethodName: string;
  const AArgs: array of string): Integer;
var
  I, J, LHash: Integer;
  LMatch: Boolean;
begin
  Result := 0;
  { P2 #6: pre-compute argument hash for O(1) early mismatch detection.
    Reduces common case from O(n*m) to O(n) when args differ. }
  LHash := 0;
  for J := 0 to High(AArgs) do
    LHash := LHash * 31 + MockValueHash(MockStr(AArgs[J]));
  for I := 0 to High(FCalls) do
  begin
    if FCalls[I].MethodName <> AMethodName then
      Continue;
    if Length(FCalls[I].Args) <> Length(AArgs) then
      Continue;
    if LHash <> FCalls[I].StrArgHash then
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

function TMockState.MatchingCallCountTyped(const AMethodName: string;
  const AArgs: array of TMockValue): Integer;
var
  I, J, LHash: Integer;
  LMatch: Boolean;
begin
  Result := 0;
  { P2 #6: pre-compute argument hash for O(1) early mismatch detection }
  LHash := 0;
  for J := 0 to High(AArgs) do
    LHash := LHash * 31 + MockValueHash(AArgs[J]);
  for I := 0 to High(FCalls) do
  begin
    if FCalls[I].MethodName <> AMethodName then
      Continue;
    if Length(FCalls[I].TypedArgs) <> Length(AArgs) then
      Continue;
    if LHash <> FCalls[I].ArgHash then
      Continue;
    LMatch := True;
    for J := 0 to High(AArgs) do
      if not MockValueEqual(FCalls[I].TypedArgs[J], AArgs[J]) then
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

procedure TMockState.ResetAll;
begin
  FCalls := nil;
  FSetups := nil;
  FCallOrder := nil;
  FWhenEntries := nil;
  FWhenMethodNames := nil;
end;

function TMockState.GetSetupMethodNames: specialize TArray<string>;
var
  I, LSetupCount, LWhenCount, LTotal, LOutIdx: Integer;
  LFound: Boolean;
begin
  LSetupCount := Length(FSetups);
  LWhenCount := Length(FWhenMethodNames);
  SetLength(Result, LSetupCount + LWhenCount);
  LOutIdx := 0;
  { Copy all setup method names }
  for I := 0 to LSetupCount - 1 do
  begin
    Result[LOutIdx] := FSetups[I].MethodName;
    Inc(LOutIdx);
  end;
  { Add When-only method names (not already in FSetups) }
  for I := 0 to LWhenCount - 1 do
  begin
    LFound := False;
    for LTotal := 0 to LSetupCount - 1 do
      if FSetups[LTotal].MethodName = FWhenMethodNames[I] then
      begin
        LFound := True;
        Break;
      end;
    if not LFound then
    begin
      Result[LOutIdx] := FWhenMethodNames[I];
      Inc(LOutIdx);
    end;
  end;
  SetLength(Result, LOutIdx);
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
    function ReturnsInt(const AValue: Int64): IMockSetup;
    function ReturnsBool(AValue: Boolean): IMockSetup;
    function ReturnsDouble(const AValue: Double): IMockSetup;
    function InOrder: IMockSetup;
    function When(const AArgs: array of TMockValue): IMockWhen;
  end;

  TMockWhen = class(TInterfacedObject, IMockWhen)
  private
    FState: TMockState;
    FMethod: string;
    FArgs: TMockValues;
  public
    constructor Create(AState: TMockState; const AMethod: string;
      const AArgs: array of TMockValue);
    function Returns(const AValue: string): IMockSetup;
    function ReturnsInt(const AValue: Int64): IMockSetup;
    function ReturnsBool(AValue: Boolean): IMockSetup;
    function ReturnsDouble(const AValue: Double): IMockSetup;
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

function TMockSetup.ReturnsInt(const AValue: Int64): IMockSetup;
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
      Mock.Setup('Foo').InOrder.Returns('x');

    For full ordered verification, use CalledInOrder on IMockVerify:
      Mock.Verify('Foo').CalledInOrder(['Foo', 'Bar', 'Baz']);
    Pairwise ordering is also available via CalledBefore/CalledAfter. }
  Result := Self;
end;

function TMockSetup.When(const AArgs: array of TMockValue): IMockWhen;
var
  LWhen: TMockWhen;
begin
  LWhen := TMockWhen.Create(FState, FMethod, AArgs);
  Result := LWhen;
end;

{ ── TMockWhen implementation (E-09) ────────────────────────────────────────── }

constructor TMockWhen.Create(AState: TMockState; const AMethod: string;
  const AArgs: array of TMockValue);
var
  I: Integer;
begin
  inherited Create;
  FState := AState;
  FMethod := AMethod;
  SetLength(FArgs, Length(AArgs));
  for I := 0 to High(AArgs) do
    FArgs[I] := AArgs[I];
end;

function TMockWhen.Returns(const AValue: string): IMockSetup;
var
  LSetup: TMockSetup;
begin
  FState.AddWhenEntry(FMethod, FArgs, MockStr(AValue), AValue);
  LSetup := TMockSetup.Create(FState, FMethod);
  Result := LSetup;
end;

function TMockWhen.ReturnsInt(const AValue: Int64): IMockSetup;
var
  LSetup: TMockSetup;
begin
  FState.AddWhenEntry(FMethod, FArgs, MockInt(AValue), IntToStr(AValue));
  LSetup := TMockSetup.Create(FState, FMethod);
  Result := LSetup;
end;

function TMockWhen.ReturnsBool(AValue: Boolean): IMockSetup;
var
  LSetup: TMockSetup;
  LStr: string;
begin
  if AValue then LStr := 'true' else LStr := 'false';
  FState.AddWhenEntry(FMethod, FArgs, MockBool(AValue), LStr);
  LSetup := TMockSetup.Create(FState, FMethod);
  Result := LSetup;
end;

function TMockWhen.ReturnsDouble(const AValue: Double): IMockSetup;
var
  LSetup: TMockSetup;
begin
  FState.AddWhenEntry(FMethod, FArgs, MockDouble(AValue), FloatToStr(AValue));
  LSetup := TMockSetup.Create(FState, FMethod);
  Result := LSetup;
end;

{ ── IMockVerify implementation ─────────────────────────────────────────────── }

type
  TMockVerifier = class(TInterfacedObject, IMockVerify)
  private
    FState: TMockState;
    FMethod: string;
    procedure CheckCount(AActual, AExpected: Integer;
      const AQualifier: string; APasses: Boolean);
    function CheckCallOrder(const AOtherMethod: string;
      AExpectBefore: Boolean): IMockVerify;
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
    function  CalledWith(const AArgs: array of TMockValue): IMockVerify;
    function  CalledExactlyWith(ACount: Integer;
      const AArgs: array of string): IMockVerify;
    function  CalledExactlyWith(ACount: Integer;
      const AArgs: array of TMockValue): IMockVerify;
    function  Count: Integer;
    function  CalledInOrder(const AMethods: array of string): IMockVerify;
  end;

constructor TMockVerifier.Create(AState: TMockState; const AMethod: string);
begin
  inherited Create;
  FState  := AState;
  FMethod := AMethod;
end;

function FormatCallDetail(AState: TMockState; const AMethod: string): string;
{ Build a human-readable list of all calls to AMethod with their arguments.
  Example: "  Foo('a', 'b')\n  Foo('c')" }
var
  I, J: Integer;
  LCall: TMockCall;
  LFound: Boolean;
begin
  Result := '';
  LFound := False;
  for I := 0 to High(AState.Calls) do
  begin
    LCall := AState.Calls[I];
    if LCall.MethodName <> AMethod then
      Continue;
    if not LFound then
    begin
      Result := #10 + '  calls to ' + AMethod + ':';
      LFound := True;
    end;
    Result := Result + #10 + '    ' + AMethod + '(';
    for J := 0 to High(LCall.Args) do
    begin
      if J > 0 then Result := Result + ', ';
      Result := Result + '"' + LCall.Args[J] + '"';
    end;
    Result := Result + ')';
  end;
  { Also list all calls if method was never called, to help spot typos }
  if not LFound then
  begin
    for I := 0 to High(AState.Calls) do
    begin
      if I = 0 then
        Result := #10 + '  all recorded calls:';
      Result := Result + #10 + '    ' + AState.Calls[I].MethodName + '(';
      for J := 0 to High(AState.Calls[I].Args) do
      begin
        if J > 0 then Result := Result + ', ';
        Result := Result + '"' + AState.Calls[I].Args[J] + '"';
      end;
      Result := Result + ')';
    end;
  end;
end;

procedure TMockVerifier.CheckCount(AActual, AExpected: Integer;
  const AQualifier: string; APasses: Boolean);
begin
  if not APasses then
    InternalFail('Expected ' + FMethod + ' called ' + AQualifier + ' ' +
      IntToStr(AExpected) + ' time(s), but was called ' +
      IntToStr(AActual) + ' time(s)' +
      FormatCallDetail(FState, FMethod));
end;

procedure TMockVerifier.CalledExactly(ACount: Integer);
var
  LCount: Integer;
begin
  LCount := FState.CallCount(FMethod);
  CheckCount(LCount, ACount, 'exactly', LCount = ACount);
end;

procedure TMockVerifier.CalledAtLeast(ACount: Integer);
var
  LCount: Integer;
begin
  LCount := FState.CallCount(FMethod);
  CheckCount(LCount, ACount, 'at least', LCount >= ACount);
end;

procedure TMockVerifier.CalledAtMost(ACount: Integer);
var
  LCount: Integer;
begin
  LCount := FState.CallCount(FMethod);
  CheckCount(LCount, ACount, 'at most', LCount <= ACount);
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

function TMockVerifier.CheckCallOrder(const AOtherMethod: string;
  AExpectBefore: Boolean): IMockVerify;
var
  I, LSelfIdx, LOtherIdx: Integer;
  LRelWord, LOppositeWord: string;
begin
  if AExpectBefore then
  begin
    LRelWord := 'before';
    LOppositeWord := 'after';
  end
  else
  begin
    LRelWord := 'after';
    LOppositeWord := 'before';
  end;
  LSelfIdx := -1;
  LOtherIdx := -1;
  for I := 0 to High(FState.CallOrder) do
  begin
    if (LSelfIdx < 0) and (FState.CallOrder[I] = FMethod) then
      LSelfIdx := I;
    if (LOtherIdx < 0) and (FState.CallOrder[I] = AOtherMethod) then
      LOtherIdx := I;
    if (LSelfIdx >= 0) and (LOtherIdx >= 0) then
      Break;
  end;
  if LSelfIdx < 0 then
    InternalFail('Expected ' + FMethod + ' called ' + LRelWord + ' ' +
      AOtherMethod + ', but ' + FMethod + ' was never called');
  if LOtherIdx < 0 then
    InternalFail('Expected ' + FMethod + ' called ' + LRelWord + ' ' +
      AOtherMethod + ', but ' + AOtherMethod + ' was never called');
  if AExpectBefore then
  begin
    if LSelfIdx >= LOtherIdx then
      InternalFail('Expected ' + FMethod + ' called ' + LRelWord + ' ' +
        AOtherMethod + ', but ' + FMethod + ' was called at index ' +
        IntToStr(LSelfIdx) + ' (' + LOppositeWord + ' ' + AOtherMethod +
        ' at index ' + IntToStr(LOtherIdx) + ')');
  end
  else
  begin
    if LSelfIdx <= LOtherIdx then
      InternalFail('Expected ' + FMethod + ' called ' + LRelWord + ' ' +
        AOtherMethod + ', but ' + FMethod + ' was called at index ' +
        IntToStr(LSelfIdx) + ' (' + LOppositeWord + ' ' + AOtherMethod +
        ' at index ' + IntToStr(LOtherIdx) + ')');
  end;
  Result := Self;
end;

function TMockVerifier.CalledBefore(const AOtherMethod: string): IMockVerify;
begin
  Result := CheckCallOrder(AOtherMethod, True);
end;

function TMockVerifier.CalledAfter(const AOtherMethod: string): IMockVerify;
begin
  Result := CheckCallOrder(AOtherMethod, False);
end;

function TMockVerifier.CalledWith(const AArgs: array of string): IMockVerify;
var
  LCount: Integer;
begin
  LCount := FState.MatchingCallCount(FMethod, AArgs);
  if LCount = 0 then
    InternalFail('Expected ' + FMethod + ' called with ' +
      FormatArgs(AArgs) + ', but no matching call found' +
      ' (first actual call: ' + FindFirstCallArgs(FState, FMethod) +
      ', total calls: ' + IntToStr(FState.CallCount(FMethod)) + ')');
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
      IntToStr(ACount) + ' times with ' + FormatArgs(AArgs) +
      ', but was called ' + IntToStr(LCount) + ' times');
  Result := Self;
end;

function TMockVerifier.CalledWith(const AArgs: array of TMockValue): IMockVerify;
var
  LCount: Integer;
begin
  LCount := FState.MatchingCallCountTyped(FMethod, AArgs);
  if LCount = 0 then
    InternalFail('Expected ' + FMethod + ' called with ' +
      FormatMockArgs(AArgs) + ', but no matching call found' +
      ' (total calls: ' + IntToStr(FState.CallCount(FMethod)) + ')');
  Result := Self;
end;

function TMockVerifier.CalledExactlyWith(ACount: Integer;
  const AArgs: array of TMockValue): IMockVerify;
var
  LCount: Integer;
begin
  LCount := FState.MatchingCallCountTyped(FMethod, AArgs);
  if LCount <> ACount then
    InternalFail('Expected ' + FMethod + ' called exactly ' +
      IntToStr(ACount) + ' times with ' + FormatMockArgs(AArgs) +
      ', but was called ' + IntToStr(LCount) + ' times');
  Result := Self;
end;

function TMockVerifier.Count: Integer;
begin
  Result := FState.CallCount(FMethod);
end;

function TMockVerifier.CalledInOrder(const AMethods: array of string): IMockVerify;
var
  I, J, LPrevIdx, LIdx: Integer;
  LOrderStr, LPrevName: string;
begin
  LPrevIdx := -1;
  for I := 0 to High(AMethods) do
  begin
    LIdx := -1;
    for J := LPrevIdx + 1 to High(FState.CallOrder) do
    begin
      if FState.CallOrder[J] = AMethods[I] then
      begin
        LIdx := J;
        Break;
      end;
    end;
    if LIdx < 0 then
    begin
      LOrderStr := '';
      for J := 0 to High(AMethods) do
      begin
        if J > 0 then LOrderStr := LOrderStr + ' -> ';
        LOrderStr := LOrderStr + AMethods[J];
      end;
      if I > 0 then
        LPrevName := AMethods[I-1]
      else
        LPrevName := '<start>';
      InternalFail('Expected methods called in order [' + LOrderStr +
        '], but ' + AMethods[I] + ' was not called (or not after ' +
        LPrevName + ')');
    end;
    LPrevIdx := LIdx;
  end;
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
  { v8.29: owner-thread guard — Setup is not thread-safe. }
  FState.CheckThread('Setup');
  Result := TMockSetup.Create(FState, AMethodName);
end;

function TMock.Verify(const AMethodName: string): IMockVerify;
begin
  { Verify* body paths also hit CallCount CheckThread; guard at entry too. }
  FState.CheckThread('Verify');
  Result := TMockVerifier.Create(FState, AMethodName);
end;

procedure TMock.VerifyAll;
var
  LNames: specialize TArray<string>;
  LUncalled: string;
  I: Integer;
begin
  FState.CheckThread('VerifyAll');
  LNames := FState.GetSetupMethodNames;
  LUncalled := '';
  for I := 0 to High(LNames) do
    if FState.CallCount(LNames[I]) = 0 then
    begin
      if LUncalled <> '' then
        LUncalled := LUncalled + ', ';
      LUncalled := LUncalled + LNames[I];
    end;
  if LUncalled <> '' then
    InternalFail('VerifyAll: set-up methods never called: ' + LUncalled);
end;

procedure TMock.VerifyNoMoreInteractions;
var
  LSetupNames: specialize TArray<string>;
  LUncalled, LUnexpected: string;
  I, J: Integer;
  LFound: Boolean;
begin
  LSetupNames := FState.GetSetupMethodNames;
  { Check: all set-up methods were called }
  LUncalled := '';
  for I := 0 to High(LSetupNames) do
    if FState.CallCount(LSetupNames[I]) = 0 then
    begin
      if LUncalled <> '' then LUncalled := LUncalled + ', ';
      LUncalled := LUncalled + LSetupNames[I];
    end;
  { Check: no calls to un-set-up methods }
  LUnexpected := '';
  for I := 0 to High(FState.Calls) do
  begin
    LFound := False;
    for J := 0 to High(LSetupNames) do
      if FState.Calls[I].MethodName = LSetupNames[J] then
      begin
        LFound := True;
        Break;
      end;
    if not LFound then
    begin
      if LUnexpected <> '' then LUnexpected := LUnexpected + ', ';
      LUnexpected := LUnexpected + FState.Calls[I].MethodName;
    end;
  end;
  { Report }
  if (LUncalled <> '') or (LUnexpected <> '') then
  begin
    if (LUncalled <> '') and (LUnexpected <> '') then
      InternalFail('VerifyNoMoreInteractions: set-up methods never called: ' +
        LUncalled + '; unexpected calls: ' + LUnexpected)
    else if LUncalled <> '' then
      InternalFail('VerifyNoMoreInteractions: set-up methods never called: ' +
        LUncalled)
    else
      InternalFail('VerifyNoMoreInteractions: unexpected calls to methods ' +
        'not set up: ' + LUnexpected);
  end;
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

function TMock.GetReturn(const AMethodName: string;
  const AArgs: array of string): string;
begin
  Result := FState.GetReturn(AMethodName, AArgs);
end;

function TMock.GetReturn(const AMethodName: string;
  const AArgs: array of TMockValue): string;
begin
  Result := FState.GetReturn(AMethodName, AArgs);
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

function TMock.GetReturnInt(const AMethodName: string;
  const AArgs: array of TMockValue): Int64;
var
  LTyped: TMockValue;
begin
  LTyped := FState.GetReturnTyped(AMethodName, AArgs);
  if LTyped.Kind = mvInt64 then
    Exit(LTyped.IntVal);
  Result := 0;
end;

function TMock.GetReturnBool(const AMethodName: string;
  const AArgs: array of TMockValue): Boolean;
var
  LTyped: TMockValue;
begin
  LTyped := FState.GetReturnTyped(AMethodName, AArgs);
  if LTyped.Kind = mvBool then
    Exit(LTyped.BoolVal);
  Result := False;
end;

function TMock.GetReturnDouble(const AMethodName: string): Double;
var
  LTyped: TMockValue;
begin
  LTyped := FState.GetReturnTyped(AMethodName, []);
  if LTyped.Kind = mvDouble then
    Exit(LTyped.DblVal);
  Result := 0.0;
end;

function TMock.GetReturnDouble(const AMethodName: string;
  const AArgs: array of string): Double;
var
  LTypedArgs: TMockValues;
  LTyped: TMockValue;
begin
  BuildTypedStringArgs(AArgs, LTypedArgs);
  LTyped := FState.GetReturnTyped(AMethodName, LTypedArgs);
  if LTyped.Kind = mvDouble then
    Exit(LTyped.DblVal);
  Result := 0.0;
end;

function TMock.GetReturnDouble(const AMethodName: string;
  const AArgs: array of TMockValue): Double;
var
  LTyped: TMockValue;
begin
  LTyped := FState.GetReturnTyped(AMethodName, AArgs);
  if LTyped.Kind = mvDouble then
    Exit(LTyped.DblVal);
  Result := 0.0;
end;

function TMock.CallCount(const AMethodName: string): Integer;
begin
  Result := FState.CallCount(AMethodName);
end;

procedure TMock.ResetCalls;
begin
  FState.CheckThread('ResetCalls');
  FState.Reset;
end;

procedure TMock.ResetAll;
begin
  FState.CheckThread('ResetAll');
  FState.ResetAll;
end;

function TMock.GetCallHistory: string;
var
  I, J: Integer;
  LCall: TMockCall;
  LSb: specialize TArray<string>;
begin
  FState.CheckThread('GetCallHistory');
  if Length(FState.Calls) = 0 then
  begin
    Result := '(no calls recorded)';
    Exit;
  end;
  LSb := nil;
  for I := 0 to High(FState.Calls) do
  begin
    LCall := FState.Calls[I];
    SetLength(LSb, Length(LSb) + 1);
    LSb[High(LSb)] := '  ' + LCall.MethodName + '(';
    for J := 0 to High(LCall.Args) do
    begin
      if J > 0 then LSb[High(LSb)] := LSb[High(LSb)] + ', ';
      LSb[High(LSb)] := LSb[High(LSb)] + '"' + LCall.Args[J] + '"';
    end;
    LSb[High(LSb)] := LSb[High(LSb)] + ')';
    if LCall.HasResult then
      LSb[High(LSb)] := LSb[High(LSb)] + ' => "' + LCall.ResultValue + '"'
    else
      LSb[High(LSb)] := LSb[High(LSb)] + ' => (void)';
  end;
  Result := '';
  for I := 0 to High(LSb) do
  begin
    if I > 0 then Result := Result + #10;
    Result := Result + LSb[I];
  end;
end;

procedure TMock.VerifyInOrder(const AMethods: array of string);
var
  I, J, LOrderIdx: Integer;
  LOrder: specialize TArray<string>;
  LActual: string;
begin
  FState.CheckThread('VerifyInOrder');
  if Length(AMethods) < 2 then
  begin
    if Length(AMethods) = 1 then
      { Single method: just verify it was called }
      Verify(AMethods[0]).CalledAtLeast(1);
    Exit;
  end;
  LOrder := FState.CallOrder;
  LOrderIdx := 0;
  for I := 0 to High(LOrder) do
  begin
    if LOrderIdx > High(AMethods) then
      Break;
    if LOrder[I] = AMethods[LOrderIdx] then
      Inc(LOrderIdx);
  end;
  if LOrderIdx <= High(AMethods) then
  begin
    { Build expected order string for error message }
    LActual := '';
    for I := 0 to High(AMethods) do
    begin
      if I > 0 then LActual := LActual + ' -> ';
      LActual := LActual + AMethods[I];
    end;
    { Build actual call order }
    LActual := LActual + #10'  actual call order: ';
    J := 0;
    for I := 0 to High(LOrder) do
    begin
      if I > 0 then LActual := LActual + ' -> ';
      LActual := LActual + LOrder[I];
      Inc(J);
    end;
    if J = 0 then
      LActual := LActual + '(no calls recorded)';
    InternalFail('VerifyInOrder: expected call order ' + LActual);
  end;
end;

{ ── TMockCaptor implementation ─────────────────────────────────────────────── }

constructor TMockCaptor.Create;
begin
  inherited Create;
  SetLength(FValues, 0);
  SetLength(FTypedValues, 0);
end;

function TMockCaptor.GetCount: Integer;
begin
  Result := Length(FValues);
end;

function TMockCaptor.GetValue: string;
begin
  if Length(FValues) = 0 then
    InternalFail('TMockCaptor: no values captured');
  Result := FValues[High(FValues)];
end;

function TMockCaptor.GetTypedValue: TMockValue;
begin
  if Length(FTypedValues) = 0 then
    InternalFail('TMockCaptor: no typed values captured');
  Result := FTypedValues[High(FTypedValues)];
end;

function TMockCaptor.GetValues(AIndex: Integer): string;
begin
  if (AIndex < 0) or (AIndex >= Length(FValues)) then
    InternalFail('TMockCaptor: index ' + IntToStr(AIndex) +
      ' out of range (count=' + IntToStr(Length(FValues)) + ')');
  Result := FValues[AIndex];
end;

function TMockCaptor.GetTypedValues(AIndex: Integer): TMockValue;
begin
  if (AIndex < 0) or (AIndex >= Length(FTypedValues)) then
    InternalFail('TMockCaptor: index ' + IntToStr(AIndex) +
      ' out of range (count=' + IntToStr(Length(FTypedValues)) + ')');
  Result := FTypedValues[AIndex];
end;

procedure TMockCaptor.CaptureFrom(const AMock: TMock; const AMethod: string;
  AArgIndex: Integer);
var
  LCalls: TMockCalls;
  I, LLast: Integer;
begin
  LCalls := AMock.State.Calls;
  LLast := -1;
  for I := 0 to High(LCalls) do
    if LCalls[I].MethodName = AMethod then
      LLast := I;
  if LLast < 0 then
    InternalFail('TMockCaptor: no calls to "' + AMethod + '" recorded');
  if (AArgIndex < 0) or (AArgIndex > High(LCalls[LLast].Args)) then
    InternalFail('TMockCaptor: arg index ' + IntToStr(AArgIndex) +
      ' out of range for "' + AMethod + '"');
  SetLength(FValues, 1);
  FValues[0] := LCalls[LLast].Args[AArgIndex];
end;

procedure TMockCaptor.CaptureAllFrom(const AMock: TMock; const AMethod: string;
  AArgIndex: Integer);
var
  LCalls: TMockCalls;
  I, LCount: Integer;
begin
  LCalls := AMock.State.Calls;
  LCount := 0;
  for I := 0 to High(LCalls) do
    if LCalls[I].MethodName = AMethod then
      Inc(LCount);
  if LCount = 0 then
    InternalFail('TMockCaptor: no calls to "' + AMethod + '" recorded');
  SetLength(FValues, LCount);
  LCount := 0;
  for I := 0 to High(LCalls) do
  begin
    if LCalls[I].MethodName = AMethod then
    begin
      if (AArgIndex < 0) or (AArgIndex > High(LCalls[I].Args)) then
        InternalFail('TMockCaptor: arg index ' + IntToStr(AArgIndex) +
          ' out of range for "' + AMethod + '"');
      FValues[LCount] := LCalls[I].Args[AArgIndex];
      Inc(LCount);
    end;
  end;
end;

procedure TMockCaptor.CaptureTypedFrom(const AMock: TMock;
  const AMethod: string; AArgIndex: Integer);
var
  LCalls: TMockCalls;
  I, LLast: Integer;
begin
  LCalls := AMock.State.Calls;
  LLast := -1;
  for I := 0 to High(LCalls) do
    if LCalls[I].MethodName = AMethod then
      LLast := I;
  if LLast < 0 then
    InternalFail('TMockCaptor: no calls to "' + AMethod + '" recorded');
  if (AArgIndex < 0) or (AArgIndex > High(LCalls[LLast].TypedArgs)) then
    InternalFail('TMockCaptor: typed arg index ' + IntToStr(AArgIndex) +
      ' out of range for "' + AMethod + '"');
  SetLength(FTypedValues, 1);
  FTypedValues[0] := LCalls[LLast].TypedArgs[AArgIndex];
end;

procedure TMockCaptor.CaptureAllTypedFrom(const AMock: TMock;
  const AMethod: string; AArgIndex: Integer);
var
  LCalls: TMockCalls;
  I, LCount: Integer;
begin
  LCalls := AMock.State.Calls;
  LCount := 0;
  for I := 0 to High(LCalls) do
    if LCalls[I].MethodName = AMethod then
      Inc(LCount);
  if LCount = 0 then
    InternalFail('TMockCaptor: no calls to "' + AMethod + '" recorded');
  SetLength(FTypedValues, LCount);
  LCount := 0;
  for I := 0 to High(LCalls) do
  begin
    if LCalls[I].MethodName = AMethod then
    begin
      if (AArgIndex < 0) or (AArgIndex > High(LCalls[I].TypedArgs)) then
        InternalFail('TMockCaptor: typed arg index ' + IntToStr(AArgIndex) +
          ' out of range for "' + AMethod + '"');
      FTypedValues[LCount] := LCalls[I].TypedArgs[AArgIndex];
      Inc(LCount);
    end;
  end;
end;

procedure TMockCaptor.Reset;
begin
  SetLength(FValues, 0);
  SetLength(FTypedValues, 0);
end;

end.
