{ nextpas.core.test.expect — Fluent IExpectation API
  =========================================================
  Depends on: nextpas.core.test.base }

unit nextpas.core.test.expect;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.system,
  nextpas.core.text.conv,
  nextpas.core.test.base;

{ ── IExpectation (fluent) ─────────────────────────────────────────────────── }

type
  IExpectation = interface
    ['{A7B3D91E-4C6F-4A28-B5D8-9E1F3C7A2B54}']
    { Toggle negation: Not_.ToEqual('x') passes when value <> 'x'. }
    function Not_: IExpectation;
    { Set a contextual message; prepended to all failure messages in this chain. }
    function WithMessage(const AMessage: string): IExpectation;
    function ToEqual(const AExpected: string): IExpectation;
    function ToEqualInt(const AExpected: Int64): IExpectation;
    function ToEqualBool(AExpected: Boolean): IExpectation;
    function ToBeTrue: IExpectation;
    function ToBeFalse: IExpectation;
    function ToBeNil: IExpectation;
    function ToBeNotNil: IExpectation;
    function ToContain(const ASubstr: string): IExpectation;
    function ToStartWith(const APrefix: string): IExpectation;
    function ToEndWith(const ASuffix: string): IExpectation;
    function ToBeGreaterThan(const AThreshold: Int64): IExpectation;
    function ToBeLessThan(const AThreshold: Int64): IExpectation;
    function ToBeGreaterOrEqual(const AThreshold: Int64): IExpectation;
    function ToBeLessOrEqual(const AThreshold: Int64): IExpectation;
    { Inclusive range: ALow <= value <= AHigh. }
    function ToBeInRange(const ALow, AHigh: Int64): IExpectation;
    function ToHaveLength(const AExpected: NativeInt): IExpectation;
    { Assert proc raises AExceptionClass. nil class → graceful fail. }
    function ToRaise(AExceptionClass: ExceptClass;
      const AMessage: string = ''): IExpectation;
    { Asserts no exception. Not_.ToNotRaise is an error — use ToRaise(EClass) instead. }
    function ToNotRaise: IExpectation;
    function ToBeNear(const AExpected: Double;
      const AEpsilon: Double = 1e-10): IExpectation;
    function ToNotBeNear(const AExpected: Double;
      const AEpsilon: Double = 1e-10): IExpectation;
    { Double comparison }
    function ToBeGreaterThanD(const AThreshold: Double): IExpectation;
    function ToBeLessThanD(const AThreshold: Double): IExpectation;
    function ToBeGreaterOrEqualD(const AThreshold: Double): IExpectation;
    function ToBeLessOrEqualD(const AThreshold: Double): IExpectation;
    function ToBeInRangeD(const ALow, AHigh: Double;
      const AEpsilon: Double = 1e-10): IExpectation;
    { Case-insensitive string matching }
    function ToContainCI(const ASubstr: string): IExpectation;
    function ToStartWithCI(const APrefix: string): IExpectation;
    function ToEndWithCI(const ASuffix: string): IExpectation;
    { Pointer identity: same address (like CheckSame). }
    function ToBeSame(const AExpected: Pointer): IExpectation;
    { Pointer equality: same address (alias for ToBeSame). }
    function ToEqualPointer(const AExpected: Pointer): IExpectation;
    { Double equality within epsilon (like CheckEqual(Double)).
      Uses absolute epsilon: |a-b| <= AEpsilon.
      Default epsilon 1e-10 is suitable for small-to-moderate values.
      For large values (e.g. 1e15+), absolute epsilon is too tight —
      use ToBeNearRel for relative tolerance instead. }
    function ToEqualD(const AExpected: Double;
      const AEpsilon: Double = 1e-10): IExpectation;
    { Relative tolerance: |a-b| <= ARelEps * max(|a|, |b|).
      Better than ToBeNear for values spanning wide ranges. }
    function ToBeNearRel(const AExpected: Double;
      const ARelEps: Double = 1e-9): IExpectation;
    function ToNotBeNearRel(const AExpected: Double;
      const ARelEps: Double = 1e-9): IExpectation;
     { NaN checks }
     function ToBeNaN: IExpectation;
     function ToBeNotNaN: IExpectation;
     { Infinity / finiteness checks (parity with CheckInf/CheckNotInf/CheckFinite) }
     function ToBeInf: IExpectation;
     function ToBeNotInf: IExpectation;
     function ToBeFinite: IExpectation;
    { Byte array comparison: element-wise equality. }
    function ToEqualBytes(const AExpected: TBytes): IExpectation;
    { Int64 array comparison: element-wise equality. }
    function ToEqualIntArray(const AExpected: array of Int64): IExpectation;
    { String array comparison: element-wise equality. }
    function ToEqualStrArray(const AExpected: array of string): IExpectation;
    { Array containment: value must exist in the array.
      Works for ekIntArray and ekStrArray kinds. }
    function ToContainInt(const AValue: Int64): IExpectation;
    function ToContainStr(const AValue: string): IExpectation;
    { Byte array containment: value must exist in the bytes. }
    function ToContain(const AValue: Byte): IExpectation;
    { Emptiness check: works for strings, arrays, and bytes.
      ToBeEmpty passes when length = 0. ToBeNotEmpty passes when length > 0. }
    function ToBeEmpty: IExpectation;
    function ToBeNotEmpty: IExpectation;
    { Sorted check: works for int arrays and string arrays.
      ToBeSorted passes when elements are in non-decreasing order. }
    function ToBeSorted: IExpectation;
    { Set membership: value must be one of the given values.
      Empty array always fails — value cannot be "one of" an empty set. }
    function ToBeOneOf(const AValues: array of string): IExpectation;
    function ToBeOneOfInt(const AValues: array of Int64): IExpectation;
    function ToBeOneOfBool(const AValues: array of Boolean): IExpectation;
    { Regex matching: value must match the pattern. }
    function ToMatch(const APattern: string): IExpectation;
    { Object type checking: value must be an instance of AClass.
      Works with pointer expectations (ExpectPtr). }
    function ToBeInstanceOf(AClass: TClass): IExpectation;
    { Snapshot comparison: string value must match the contents of the snapshot
      file at ASnapshotDir/ASnapshotName. On first run (file not found), the
      snapshot is created automatically. Set NEXTPAS_UPDATE_SNAPSHOTS=1 to
      update existing snapshots. }
    function ToMatchSnapshot(const ASnapshotDir,
      ASnapshotName: string): IExpectation;
    { Unconditional failure — use in conditional branches. }
    procedure ToFailUnexpected(const AMessage: string = '');
  end;

{ ── Expect (fluent factory) ───────────────────────────────────────────────── }

function Expect(const AValue: string): IExpectation;
{ Alias for Expect(string) — explicit naming for clarity. }
function ExpectStr(const AValue: string): IExpectation;
function ExpectInt(const AValue: Int64): IExpectation;
function ExpectBool(AValue: Boolean): IExpectation;
function ExpectDouble(const AValue: Double): IExpectation;
function ExpectPtr(const AValue: Pointer): IExpectation;
{ ExpectObj: create expectation for a TObject. Aliased to ExpectPtr internally. }
function ExpectObj(const AValue: TObject): IExpectation;
function ExpectProc(AProc: TTestProc): IExpectation;
function ExpectBytes(const AValue: TBytes): IExpectation;
function ExpectArrayOfInt(const AValues: array of Int64): IExpectation;
function ExpectArrayOfStr(const AValues: array of string): IExpectation;

implementation

uses
  nextpas.core.math.scalar,    { IsNan / IsInfinite for Double guards }
  nextpas.core.regex,          { RegexIsMatch for ToMatch }
  nextpas.core.test.snapshot,  { CheckSnapshot — shared L1, not via check }
  nextpas.core.platform.thread;{ platform_thread_id for main-thread pool guard }

{ ── Local helpers ─────────────────────────────────────────────────────────── }

function MaxI(A, B: Integer): Integer;
begin
  if A > B then Result := A else Result := B;
end;

procedure RequireNotNaN(const AValue, AThreshold: Double;
  const AOp: string);
{ Shared NaN guard for double comparison methods. Fails with descriptive
  message if either value is NaN. }
begin
  if IsNan(AValue) or IsNan(AThreshold) then
    InternalFail(FloatToStr(AValue) + ' ' + AOp + ' ' +
      FloatToStr(AThreshold) + ' (NaN)');
end;

{ ── TExpectation (fluent API) ──────────────────────────────────────────────── }

type
  TExpectationKind = (
    ekString, ekInt64, ekBool, ekPointer, ekProc, ekDouble, ekBytes,
    ekIntArray, ekStrArray
  );

const
  KindNames: array[TExpectationKind] of string = (
    'string', 'integer', 'boolean', 'pointer', 'proc', 'double', 'bytes',
    'int array', 'string array'
  );
  FactoryHints: array[TExpectationKind] of string = (
    'ExpectStr(s)', 'ExpectInt(n)', 'ExpectBool(b)',
    'ExpectPtr(p)', 'ExpectProc(p)', 'ExpectDouble(d)', 'ExpectBytes(b)',
    'ExpectArrayOfInt(arr)', 'ExpectArrayOfStr(arr)'
  );

type
  { Non-atomic refcount base for single-threaded test scenarios.
    Avoids InterlockedDecrement overhead (~30ns) per interface release. }
  TExpectationBase = class(TObject, IUnknown)
  private
    FRefCount: LongInt;
  public
    function QueryInterface({$IFDEF FPC_HAS_CONSTREF}constref{$ELSE}const{$ENDIF} IID: TGUID; out Obj): LongInt; {$IFDEF WINDOWS}stdcall{$ELSE}cdecl{$ENDIF};
    function _AddRef: LongInt; {$IFDEF WINDOWS}stdcall{$ELSE}cdecl{$ENDIF};
    function _Release: LongInt; {$IFDEF WINDOWS}stdcall{$ELSE}cdecl{$ENDIF};
  end;

  TExpectation = class(TExpectationBase, IExpectation)
  private
    FKind       : TExpectationKind;
    FStrValue   : string;
    FIntValue   : Int64;
    FBoolValue  : Boolean;
    FPtrValue   : Pointer;
    FProcValue  : TTestProc;
    FDoubleValue: Double;
    FBytesValue : TBytes;
    FNegated    : Boolean;
    FMessage    : string;
    FIntArrayValue : specialize TArray<Int64>;
    FStrArrayValue : specialize TArray<string>;
  public
    constructor CreateStr(const AValue: string);
    constructor CreateInt(const AValue: Int64);
    constructor CreateBool(AValue: Boolean);
    constructor CreatePtr(const AValue: Pointer);
    constructor CreateProc(AProc: TTestProc);
    constructor CreateDouble(const AValue: Double);
    constructor CreateBytes(const AValue: TBytes);
    constructor CreateIntArray(const AValues: array of Int64);
    constructor CreateStrArray(const AValues: array of string);

    { Object pool support }
    procedure ResetState;
      { Reset all fields to default values for pool reuse. }
    class function AllocStr(const AValue: string): TExpectation;
    class function AllocInt(const AValue: Int64): TExpectation;
    class function AllocBool(AValue: Boolean): TExpectation;
    class function AllocPtr(const AValue: Pointer): TExpectation;
    class function AllocProc(AProc: TTestProc): TExpectation;
    class function AllocDouble(const AValue: Double): TExpectation;
    class function AllocBytes(const AValue: TBytes): TExpectation;
    class function AllocIntArray(const AValues: array of Int64): TExpectation;
    class function AllocStrArray(const AValues: array of string): TExpectation;

    procedure RequireKind(AKind: TExpectationKind;
      const AMethod: string);
      { Guard: fail with "X called on non-Y expectation" if FKind <> AKind. }
    procedure CheckMatch(AIsMatch: Boolean;
      const ANegMsg, APosMsg: string);
      { Core negation check: fail with ANegMsg if (FNegated and AIsMatch)
        or with APosMsg if (not FNegated and not AIsMatch). }
    function CloneSelf: TExpectation;
      { Create a heap copy of this expectation, preserving all state.
        Used by Not_ and WithMessage to avoid duplicating the kind-case. }

    { IExpectation }
    { Not_: returns a NEW expectation with negated assertion.
      Creates an independent heap copy so the original expectation
      chain is not affected. This is intentional — allows:
        E := ExpectStr('hello');
        E.Not_.ToEqual('world');  // passes (negated)
        E.ToEqual('hello');       // still works (original unchanged) }
    function Not_: IExpectation;
    function ToEqual(const AExpected: string): IExpectation;
    function ToEqualInt(const AExpected: Int64): IExpectation;
    function ToEqualBool(AExpected: Boolean): IExpectation;
    function ToBeTrue: IExpectation;
    function ToBeFalse: IExpectation;
    function ToBeNil: IExpectation;
    function ToBeNotNil: IExpectation;
    function ToContain(const ASubstr: string): IExpectation;
    function ToStartWith(const APrefix: string): IExpectation;
    function ToEndWith(const ASuffix: string): IExpectation;
    function ToBeGreaterThan(const AThreshold: Int64): IExpectation;
    function ToBeLessThan(const AThreshold: Int64): IExpectation;
    function ToBeGreaterOrEqual(const AThreshold: Int64): IExpectation;
    function ToBeLessOrEqual(const AThreshold: Int64): IExpectation;
    function ToBeInRange(const ALow, AHigh: Int64): IExpectation;
    function ToHaveLength(const AExpected: NativeInt): IExpectation;
    function ToRaise(AExceptionClass: ExceptClass;
      const AMessage: string = ''): IExpectation;
    function ToNotRaise: IExpectation;
    function ToBeNear(const AExpected: Double;
      const AEpsilon: Double = 1e-10): IExpectation;
    function ToNotBeNear(const AExpected: Double;
      const AEpsilon: Double = 1e-10): IExpectation;
    { Double comparison }
    function ToBeGreaterThanD(const AThreshold: Double): IExpectation;
    function ToBeLessThanD(const AThreshold: Double): IExpectation;
    function ToBeGreaterOrEqualD(const AThreshold: Double): IExpectation;
    function ToBeLessOrEqualD(const AThreshold: Double): IExpectation;
    function ToBeInRangeD(const ALow, AHigh: Double;
      const AEpsilon: Double = 1e-10): IExpectation;
    { Case-insensitive string matching }
    function ToContainCI(const ASubstr: string): IExpectation;
    function ToStartWithCI(const APrefix: string): IExpectation;
    function ToEndWithCI(const ASuffix: string): IExpectation;
    function ToBeSame(const AExpected: Pointer): IExpectation;
    function ToEqualPointer(const AExpected: Pointer): IExpectation;
    function ToEqualD(const AExpected: Double;
      const AEpsilon: Double = 1e-10): IExpectation;
    function ToBeNearRel(const AExpected: Double;
      const ARelEps: Double = 1e-9): IExpectation;
    function ToNotBeNearRel(const AExpected: Double;
      const ARelEps: Double = 1e-9): IExpectation;
    function ToBeNaN: IExpectation;
    function ToBeNotNaN: IExpectation;
    function ToBeInf: IExpectation;
    function ToBeNotInf: IExpectation;
    function ToBeFinite: IExpectation;
    { New: WithMessage, ToEqualBytes, ToFailUnexpected }
    function WithMessage(const AMessage: string): IExpectation;
    function ToEqualBytes(const AExpected: TBytes): IExpectation;
    function ToBeOneOf(const AValues: array of string): IExpectation;
    function ToBeOneOfInt(const AValues: array of Int64): IExpectation;
    function ToBeOneOfBool(const AValues: array of Boolean): IExpectation;
    function ToMatch(const APattern: string): IExpectation;
    function ToEqualIntArray(const AExpected: array of Int64): IExpectation;
    function ToEqualStrArray(const AExpected: array of string): IExpectation;
    function ToContainInt(const AValue: Int64): IExpectation;
    function ToContainStr(const AValue: string): IExpectation;
    function ToContain(const AValue: Byte): IExpectation;
    function ToBeEmpty: IExpectation;
    function ToBeNotEmpty: IExpectation;
    function ToBeSorted: IExpectation;
    function ToBeInstanceOf(AClass: TClass): IExpectation;
    function ToMatchSnapshot(const ASnapshotDir,
      ASnapshotName: string): IExpectation;
    procedure ToFailUnexpected(const AMessage: string = '');
  end;

{ ── Expectation Object Pool ────────────────────────────────────────────────── }

const
  MAX_POOL_SIZE = 64;

type
  TExpectationPool = record
    Pool: array[0..MAX_POOL_SIZE-1] of TExpectation;
    Count: Integer;
    Initialized: Boolean;
    procedure Init;
    function Acquire: TExpectation;
    procedure Release(AExp: TExpectation);
  end;

threadvar
  { Thread-local pool — each thread gets its own pool instance }
  ThreadPool: TExpectationPool;

var
  GMainThreadTid: UInt64;  { captured in initialization }

procedure TExpectationPool.Init;
var
  I: Integer;
begin
  Count := 0;
  Initialized := True;
  for I := 0 to MAX_POOL_SIZE - 1 do
    Pool[I] := nil;
end;

function TExpectationPool.Acquire: TExpectation;
begin
  if not Initialized then
    Init;
  if Count > 0 then
  begin
    Dec(Count);
    Result := Pool[Count];
    Pool[Count] := nil;
  end
  else
    Result := nil;
end;

procedure TExpectationPool.Release(AExp: TExpectation);
begin
  if (AExp <> nil) and (Count < MAX_POOL_SIZE) then
  begin
    AExp.ResetState;
    Pool[Count] := AExp;
    Inc(Count);
  end
  else if AExp <> nil then
    AExp.Free;
end;

{ ── TExpectationBase (non-atomic refcount) ─────────────────────────────────── }

function TExpectationBase.QueryInterface({$IFDEF FPC_HAS_CONSTREF}constref{$ELSE}const{$ENDIF} IID: TGUID; out Obj): LongInt; {$IFDEF WINDOWS}stdcall{$ELSE}cdecl{$ENDIF};
begin
  if GetInterface(IID, Obj) then
    Result := 0
  else
    Result := LongInt(E_NOINTERFACE);
end;

function TExpectationBase._AddRef: LongInt; {$IFDEF WINDOWS}stdcall{$ELSE}cdecl{$ENDIF};
begin
  Inc(FRefCount);
  Result := FRefCount;
end;

function TExpectationBase._Release: LongInt; {$IFDEF WINDOWS}stdcall{$ELSE}cdecl{$ENDIF};
begin
  Dec(FRefCount);
  Result := FRefCount;
  if Result = 0 then
  begin
    { FIX-A3: pool only on the main thread — unit finalization never runs for
      spawned worker threads, so their thread-local pool would leak. }
    if (ThreadPool.Count < MAX_POOL_SIZE) and (platform_thread_id = GMainThreadTid) then
    begin
      { Return to pool: finalize managed types, then store pointer }
      (Self as TExpectation).ResetState;
      ThreadPool.Pool[ThreadPool.Count] := Self as TExpectation;
      Inc(ThreadPool.Count);
    end
    else
      Free;
  end;
end;

constructor TExpectation.CreateStr(const AValue: string);
begin
  inherited Create;
  FKind     := ekString;
  FStrValue := AValue;
  FNegated  := False;
end;

constructor TExpectation.CreateInt(const AValue: Int64);
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

constructor TExpectation.CreatePtr(const AValue: Pointer);
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

constructor TExpectation.CreateDouble(const AValue: Double);
begin
  inherited Create;
  FKind        := ekDouble;
  FDoubleValue := AValue;
  FNegated     := False;
end;

constructor TExpectation.CreateBytes(const AValue: TBytes);
begin
  inherited Create;
  FKind      := ekBytes;
  FBytesValue := AValue;
  FNegated   := False;
end;

constructor TExpectation.CreateIntArray(const AValues: array of Int64);
var
  I: Integer;
begin
  inherited Create;
  FKind  := ekIntArray;
  FNegated := False;
  SetLength(FIntArrayValue, Length(AValues));
  for I := 0 to High(AValues) do
    FIntArrayValue[I] := AValues[I];
end;

constructor TExpectation.CreateStrArray(const AValues: array of string);
var
  I: Integer;
begin
  inherited Create;
  FKind  := ekStrArray;
  FNegated := False;
  SetLength(FStrArrayValue, Length(AValues));
  for I := 0 to High(AValues) do
    FStrArrayValue[I] := AValues[I];
end;

procedure TExpectation.ResetState;
begin
  FKind := ekString;
  FStrValue := '';
  FIntValue := 0;
  FBoolValue := False;
  FPtrValue := nil;
  FProcValue := nil;
  FDoubleValue := 0.0;
  FBytesValue := nil;
  FNegated := False;
  FMessage := '';
  FIntArrayValue := nil;
  FStrArrayValue := nil;
end;

class function TExpectation.AllocStr(const AValue: string): TExpectation;
begin
  Result := ThreadPool.Acquire;
  if Result = nil then
    Result := TExpectation.CreateStr(AValue)
  else
  begin
    Result.FKind := ekString;
    Result.FStrValue := AValue;
  end;
end;

class function TExpectation.AllocInt(const AValue: Int64): TExpectation;
begin
  Result := ThreadPool.Acquire;
  if Result = nil then
    Result := TExpectation.CreateInt(AValue)
  else
  begin
    Result.FKind := ekInt64;
    Result.FIntValue := AValue;
  end;
end;

class function TExpectation.AllocBool(AValue: Boolean): TExpectation;
begin
  Result := ThreadPool.Acquire;
  if Result = nil then
    Result := TExpectation.CreateBool(AValue)
  else
  begin
    Result.FKind := ekBool;
    Result.FBoolValue := AValue;
  end;
end;

class function TExpectation.AllocPtr(const AValue: Pointer): TExpectation;
begin
  Result := ThreadPool.Acquire;
  if Result = nil then
    Result := TExpectation.CreatePtr(AValue)
  else
  begin
    Result.FKind := ekPointer;
    Result.FPtrValue := AValue;
  end;
end;

class function TExpectation.AllocProc(AProc: TTestProc): TExpectation;
begin
  Result := ThreadPool.Acquire;
  if Result = nil then
    Result := TExpectation.CreateProc(AProc)
  else
  begin
    Result.FKind := ekProc;
    Result.FProcValue := AProc;
  end;
end;

class function TExpectation.AllocDouble(const AValue: Double): TExpectation;
begin
  Result := ThreadPool.Acquire;
  if Result = nil then
    Result := TExpectation.CreateDouble(AValue)
  else
  begin
    Result.FKind := ekDouble;
    Result.FDoubleValue := AValue;
  end;
end;

class function TExpectation.AllocBytes(const AValue: TBytes): TExpectation;
begin
  Result := ThreadPool.Acquire;
  if Result = nil then
    Result := TExpectation.CreateBytes(AValue)
  else
  begin
    Result.FKind := ekBytes;
    Result.FBytesValue := AValue;
  end;
end;

class function TExpectation.AllocIntArray(const AValues: array of Int64): TExpectation;
var
  I: Integer;
begin
  Result := ThreadPool.Acquire;
  if Result = nil then
    Result := TExpectation.CreateIntArray(AValues)
  else
  begin
    Result.FKind := ekIntArray;
    SetLength(Result.FIntArrayValue, Length(AValues));
    for I := 0 to High(AValues) do
      Result.FIntArrayValue[I] := AValues[I];
  end;
end;

class function TExpectation.AllocStrArray(const AValues: array of string): TExpectation;
var
  I: Integer;
begin
  Result := ThreadPool.Acquire;
  if Result = nil then
    Result := TExpectation.CreateStrArray(AValues)
  else
  begin
    Result.FKind := ekStrArray;
    SetLength(Result.FStrArrayValue, Length(AValues));
    for I := 0 to High(AValues) do
      Result.FStrArrayValue[I] := AValues[I];
  end;
end;

function TExpectation.CloneSelf: TExpectation;
begin
  case FKind of
    ekString:   Result := TExpectation.AllocStr(FStrValue);
    ekInt64:    Result := TExpectation.AllocInt(FIntValue);
    ekBool:     Result := TExpectation.AllocBool(FBoolValue);
    ekPointer:  Result := TExpectation.AllocPtr(FPtrValue);
    ekProc:     Result := TExpectation.AllocProc(FProcValue);
    ekDouble:   Result := TExpectation.AllocDouble(FDoubleValue);
    ekBytes:    Result := TExpectation.AllocBytes(FBytesValue);
    ekIntArray: Result := TExpectation.AllocIntArray(FIntArrayValue);
    ekStrArray: Result := TExpectation.AllocStrArray(FStrArrayValue);
  end;
  Result.FNegated := FNegated;
  Result.FMessage := FMessage;
end;

function TExpectation.Not_: IExpectation;
var
  LCopy: TExpectation;
begin
  LCopy := CloneSelf;
  LCopy.FNegated := not FNegated;
  Result := LCopy;
end;

procedure TExpectation.RequireKind(AKind: TExpectationKind;
  const AMethod: string);
begin
  if FKind <> AKind then
    InternalFail(AMethod + ' requires ' + KindNames[AKind] +
      ' expectation, but got ' + KindNames[FKind] +
      '. Use ' + FactoryHints[AKind] + ' to create the correct type.');
end;

procedure TExpectation.CheckMatch(AIsMatch: Boolean;
  const ANegMsg, APosMsg: string);
begin
  if FNegated then
  begin
    if AIsMatch then
    begin
      if FMessage <> '' then
        InternalFail(FMessage + ': ' + ANegMsg)
      else
        InternalFail(ANegMsg);
    end;
  end
  else
  begin
    if not AIsMatch then
    begin
      if FMessage <> '' then
        InternalFail(FMessage + ': ' + APosMsg)
      else
        InternalFail(APosMsg);
    end;
  end;
end;

function TExpectation.ToEqual(const AExpected: string): IExpectation;
var
  LMin, LDiffAt, I: Integer;
  LDiffDetail: string;
begin
  RequireKind(ekString, 'ToEqual(string)');
  if FStrValue = AExpected then
  begin
    if FNegated then
    begin
      if FMessage <> '' then
        InternalFail(FMessage + ': Expected "' + FStrValue + '" not to equal "' + AExpected + '"')
      else
        InternalFail('Expected "' + FStrValue + '" not to equal "' + AExpected + '"');
    end;
  end
  else
  begin
    if not FNegated then
    begin
      { Find first differing position }
      LDiffAt := 0;
      LMin := Length(AExpected);
      if Length(FStrValue) < LMin then
        LMin := Length(FStrValue);
      for I := 1 to LMin do
        if FStrValue[I] <> AExpected[I] then
        begin
          LDiffAt := I;
          Break;
        end;
      if LDiffAt = 0 then
        LDiffAt := LMin + 1; { one string is prefix of the other }
      { Build diff detail — short strings get ^ pointer, long strings get context }
      if (Length(AExpected) <= 40) and (Length(FStrValue) <= 40) and
         (Pos(#10, AExpected) = 0) and (Pos(#10, FStrValue) = 0) then
      begin
        { Short string: show full value with ^ pointer }
        LDiffDetail :=
          '  expected: "' + AExpected + '"'#10 +
          '    actual: "' + FStrValue + '"'#10 +
          '            ' + StringOfChar(' ', LDiffAt - 1) + '^' +
          ' diff at pos ' + IntToStr(LDiffAt);
      end
      else
      begin
        { Long string: show context window around first difference }
        LDiffDetail := 'Strings differ at position ' + IntToStr(LDiffAt) + ':' +
          #10'  expected: ...' +
          Copy(AExpected, MaxI(1, LDiffAt - 10), 21) + '...' +
          #10'    actual: ...' +
          Copy(FStrValue, MaxI(1, LDiffAt - 10), 21) + '...' +
          #10'  (lengths: ' + IntToStr(Length(AExpected)) +
          ' vs ' + IntToStr(Length(FStrValue)) + ')';
      end;
      if FMessage <> '' then
        InternalFail(FMessage + ': ' + LDiffDetail)
      else
        InternalFail(LDiffDetail);
    end;
  end;
  Result := Self;
end;

function TExpectation.ToEqualInt(const AExpected: Int64): IExpectation;
begin
  RequireKind(ekInt64, 'ToEqualInt');
  CheckMatch(FIntValue = AExpected,
    'Expected not ' + IntToStr(AExpected) + ' but value is ' + IntToStr(FIntValue),
    'Expected ' + IntToStr(AExpected) + ' but got ' + IntToStr(FIntValue));
  Result := Self;
end;

function TExpectation.ToEqualBool(AExpected: Boolean): IExpectation;
var
  LExpStr, LActStr: string;
begin
  RequireKind(ekBool, 'ToEqualBool');
  LExpStr := BoolToStr(AExpected, 'True', 'False');
  LActStr := BoolToStr(FBoolValue, 'True', 'False');
  CheckMatch(FBoolValue = AExpected,
    'Expected not ' + LExpStr + ' but got ' + LActStr,
    'Expected ' + LExpStr + ' but got ' + LActStr);
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
begin
  RequireKind(ekPointer, 'ToBeNil');
  CheckMatch(FPtrValue = nil,
    'Expected non-nil but got nil',
    'Expected nil but got $' + IntToHex(NativeUInt(FPtrValue), 16));
  Result := Self;
end;

function TExpectation.ToBeNotNil: IExpectation;
begin
  RequireKind(ekPointer, 'ToBeNotNil');
  CheckMatch(FPtrValue <> nil,
    'Expected nil but got $' + IntToHex(NativeUInt(FPtrValue), 16),
    'Expected non-nil but got nil');
  Result := Self;
end;

function TExpectation.ToContain(const ASubstr: string): IExpectation;
var
  LFound: Boolean;
begin
  RequireKind(ekString, 'ToContain');
  if Length(ASubstr) = 0 then
    LFound := True { empty substring matches everything }
  else
    LFound := Pos(ASubstr, FStrValue) > 0;
  CheckMatch(LFound,
    '"' + FStrValue + '" should not contain "' + ASubstr + '"',
    '"' + FStrValue + '" does not contain "' + ASubstr + '"');
  Result := Self;
end;

function TExpectation.ToStartWith(const APrefix: string): IExpectation;
begin
  RequireKind(ekString, 'ToStartWith');
  CheckMatch(StrStartsWith(FStrValue, APrefix),
    '"' + FStrValue + '" should not start with "' + APrefix + '"',
    '"' + FStrValue + '" does not start with "' + APrefix + '"');
  Result := Self;
end;

function TExpectation.ToEndWith(const ASuffix: string): IExpectation;
begin
  RequireKind(ekString, 'ToEndWith');
  CheckMatch(StrEndsWith(FStrValue, ASuffix),
    '"' + FStrValue + '" should not end with "' + ASuffix + '"',
    '"' + FStrValue + '" does not end with "' + ASuffix + '"');
  Result := Self;
end;

function TExpectation.ToBeGreaterThan(const AThreshold: Int64): IExpectation;
begin
  RequireKind(ekInt64, 'ToBeGreaterThan');
  CheckMatch(FIntValue > AThreshold,
    IntToStr(FIntValue) + ' should not be > ' + IntToStr(AThreshold),
    IntToStr(FIntValue) + ' is not > ' + IntToStr(AThreshold));
  Result := Self;
end;

function TExpectation.ToBeLessThan(const AThreshold: Int64): IExpectation;
begin
  RequireKind(ekInt64, 'ToBeLessThan');
  CheckMatch(FIntValue < AThreshold,
    IntToStr(FIntValue) + ' should not be < ' + IntToStr(AThreshold),
    IntToStr(FIntValue) + ' is not < ' + IntToStr(AThreshold));
  Result := Self;
end;

function TExpectation.ToBeInRange(const ALow, AHigh: Int64): IExpectation;
begin
  RequireKind(ekInt64, 'ToBeInRange');
  if ALow > AHigh then
    InternalFail('ToBeInRange: ALow (' + IntToStr(ALow) +
      ') > AHigh (' + IntToStr(AHigh) + ')');
  CheckMatch((FIntValue >= ALow) and (FIntValue <= AHigh),
    IntToStr(FIntValue) + ' should not be in [' +
      IntToStr(ALow) + '..' + IntToStr(AHigh) + ']',
    IntToStr(FIntValue) + ' not in [' +
      IntToStr(ALow) + '..' + IntToStr(AHigh) + ']');
  Result := Self;
end;

function TExpectation.ToHaveLength(const AExpected: NativeInt): IExpectation;
var
  LActual: NativeInt;
begin
  case FKind of
    ekString:   LActual := Length(FStrValue);
    ekIntArray: LActual := Length(FIntArrayValue);
    ekStrArray: LActual := Length(FStrArrayValue);
    ekBytes:    LActual := Length(FBytesValue);
  else
    InternalFail('ToHaveLength requires string, array, or bytes expectation, ' +
      'but got ' + KindNames[FKind] + '. Use ' + FactoryHints[FKind] +
      ' to create the correct type.');
    Result := Self;
    Exit;
  end;
  CheckMatch(LActual = AExpected,
    'should not have length ' + IntToStr(AExpected),
    'Expected length ' + IntToStr(AExpected) +
      ' but got ' + IntToStr(LActual));
  Result := Self;
end;

function TExpectation.ToRaise(AExceptionClass: ExceptClass;
  const AMessage: string): IExpectation;
var
  LRaised: Boolean = False;
begin
  RequireKind(ekProc, 'ToRaise');
  if AExceptionClass = nil then
    InternalFail('ToRaise: AExceptionClass is nil');
  if not Assigned(FProcValue) then
    InternalFail('ToRaise: proc is nil');
  try
    FProcValue;
  except
    on E: ETestSkipped do
      raise; { Skip is flow control, not a testable exception }
    on E: Exception do
    begin
      LRaised := True;
      if FNegated then
      begin
        if E is AExceptionClass then
          InternalFail('Expected no ' + AExceptionClass.ClassName +
            ' but got ' + E.ClassName + ': ' + E.Message);
        raise; { Different exception class — re-raise to propagate }
      end
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

{ ToNotRaise — asserts that the proc does NOT raise any exception.

  NOTE: Not_.ToNotRaise is an error — it fails with a diagnostic message
  directing the user to use ToRaise(EClass) instead.

  Implementation: ToNotRaise runs the proc; if any exception (other than
  ETestSkipped) escapes, it calls InternalFail. }
function TExpectation.ToNotRaise: IExpectation;
begin
  RequireKind(ekProc, 'ToNotRaise');
  if FNegated then
    InternalFail('Not_.ToNotRaise is not supported — ' +
      'use ToRaise(EClass) to assert that a specific exception is raised');
  if not Assigned(FProcValue) then
    InternalFail('ToNotRaise: proc is nil');
  try
    FProcValue;
  except
    on E: ETestSkipped do
      raise; { Skip is flow control, not a testable exception }
    on E: Exception do
      InternalFail('Expected no exception but got ' +
        E.ClassName + ': ' + E.Message);
  end;
  Result := Self;
end;

function TExpectation.ToBeNear(const AExpected: Double;
  const AEpsilon: Double): IExpectation;
var
  LDiff: Double;
begin
  RequireKind(ekDouble, 'ToBeNear');
  if IsNan(FDoubleValue) or IsNan(AExpected) then
    InternalFail('Expected ' + FloatToStr(AExpected) +
      ' (+/-' + FloatToStr(AEpsilon) + ') but got ' + FloatToStr(FDoubleValue) + ' (NaN)');
  LDiff := Abs(FDoubleValue - AExpected);
  if FNegated then
  begin
    if LDiff <= AEpsilon then
      InternalFail('Expected not near ' + FloatToStr(AExpected) +
        ' (+/-' + FloatToStr(AEpsilon) + ') but got ' + FloatToStr(FDoubleValue));
  end
  else
  begin
    if LDiff > AEpsilon then
      InternalFail('Expected ' + FloatToStr(AExpected) +
        ' (+/-' + FloatToStr(AEpsilon) + ') but got ' + FloatToStr(FDoubleValue));
  end;
  Result := Self;
end;

function TExpectation.ToNotBeNear(const AExpected: Double;
  const AEpsilon: Double): IExpectation;
begin
  RequireKind(ekDouble, 'ToNotBeNear');
  FNegated := not FNegated;
  try
    Result := ToBeNear(AExpected, AEpsilon);
  finally
    FNegated := not FNegated;
  end;
end;

{ ── TExpectation: >= / <= for Int64 ────────────────────────────────────────── }

function TExpectation.ToBeGreaterOrEqual(const AThreshold: Int64): IExpectation;
begin
  RequireKind(ekInt64, 'ToBeGreaterOrEqual');
  CheckMatch(FIntValue >= AThreshold,
    IntToStr(FIntValue) + ' should not be >= ' + IntToStr(AThreshold),
    IntToStr(FIntValue) + ' is not >= ' + IntToStr(AThreshold));
  Result := Self;
end;

function TExpectation.ToBeLessOrEqual(const AThreshold: Int64): IExpectation;
begin
  RequireKind(ekInt64, 'ToBeLessOrEqual');
  CheckMatch(FIntValue <= AThreshold,
    IntToStr(FIntValue) + ' should not be <= ' + IntToStr(AThreshold),
    IntToStr(FIntValue) + ' is not <= ' + IntToStr(AThreshold));
  Result := Self;
end;

{ ── TExpectation: Double comparison ────────────────────────────────────────── }

function TExpectation.ToBeGreaterThanD(const AThreshold: Double): IExpectation;
begin
  RequireKind(ekDouble, 'ToBeGreaterThanD');
  RequireNotNaN(FDoubleValue, AThreshold, 'is not >');
  CheckMatch(FDoubleValue > AThreshold,
    FloatToStr(FDoubleValue) + ' should not be > ' + FloatToStr(AThreshold),
    FloatToStr(FDoubleValue) + ' is not > ' + FloatToStr(AThreshold));
  Result := Self;
end;

function TExpectation.ToBeLessThanD(const AThreshold: Double): IExpectation;
begin
  RequireKind(ekDouble, 'ToBeLessThanD');
  RequireNotNaN(FDoubleValue, AThreshold, 'is not <');
  CheckMatch(FDoubleValue < AThreshold,
    FloatToStr(FDoubleValue) + ' should not be < ' + FloatToStr(AThreshold),
    FloatToStr(FDoubleValue) + ' is not < ' + FloatToStr(AThreshold));
  Result := Self;
end;

function TExpectation.ToBeGreaterOrEqualD(const AThreshold: Double): IExpectation;
begin
  RequireKind(ekDouble, 'ToBeGreaterOrEqualD');
  RequireNotNaN(FDoubleValue, AThreshold, 'is not >=');
  CheckMatch(FDoubleValue >= AThreshold,
    FloatToStr(FDoubleValue) + ' should not be >= ' + FloatToStr(AThreshold),
    FloatToStr(FDoubleValue) + ' is not >= ' + FloatToStr(AThreshold));
  Result := Self;
end;

function TExpectation.ToBeLessOrEqualD(const AThreshold: Double): IExpectation;
begin
  RequireKind(ekDouble, 'ToBeLessOrEqualD');
  RequireNotNaN(FDoubleValue, AThreshold, 'is not <=');
  CheckMatch(FDoubleValue <= AThreshold,
    FloatToStr(FDoubleValue) + ' should not be <= ' + FloatToStr(AThreshold),
    FloatToStr(FDoubleValue) + ' is not <= ' + FloatToStr(AThreshold));
  Result := Self;
end;

function TExpectation.ToBeInRangeD(const ALow, AHigh: Double;
  const AEpsilon: Double): IExpectation;
var
  LIn, LInEps: Boolean;
begin
  RequireKind(ekDouble, 'ToBeInRangeD');
  if IsNan(FDoubleValue) or IsNan(ALow) or IsNan(AHigh) then
    InternalFail(FloatToStr(FDoubleValue) + ' is not in [' +
      FloatToStr(ALow) + '..' + FloatToStr(AHigh) + '] (NaN)');
  if ALow > AHigh then
    InternalFail('ToBeInRangeD: low (' + FloatToStr(ALow) +
      ') > high (' + FloatToStr(AHigh) + ')');
  LIn := (FDoubleValue >= ALow) and (FDoubleValue <= AHigh);
  { Epsilon tolerance: accept values slightly outside the range }
  if not LIn then
    LInEps := (Abs(FDoubleValue - ALow) <= AEpsilon) or
              (Abs(FDoubleValue - AHigh) <= AEpsilon)
  else
    LInEps := True;
  CheckMatch(LInEps,
    FloatToStr(FDoubleValue) + ' should not be in [' +
      FloatToStr(ALow) + '..' + FloatToStr(AHigh) + ']',
    FloatToStr(FDoubleValue) + ' is not in [' +
      FloatToStr(ALow) + '..' + FloatToStr(AHigh) + ']');
  Result := Self;
end;

{ ── TExpectation: Case-insensitive string ──────────────────────────────────── }

function TExpectation.ToContainCI(const ASubstr: string): IExpectation;
var
  LFound: Boolean;
begin
  RequireKind(ekString, 'ToContainCI');
  if Length(ASubstr) = 0 then
    LFound := True { empty needle matches everything }
  else
    LFound := PosCI(ASubstr, FStrValue) > 0;
  CheckMatch(LFound,
    '"' + FStrValue + '" should not contain (ci) "' + ASubstr + '"',
    '"' + FStrValue + '" does not contain (ci) "' + ASubstr + '"');
  Result := Self;
end;

function TExpectation.ToStartWithCI(const APrefix: string): IExpectation;
begin
  RequireKind(ekString, 'ToStartWithCI');
  CheckMatch(StrStartsWithCI(FStrValue, APrefix),
    '"' + FStrValue + '" should not start with (ci) "' + APrefix + '"',
    '"' + FStrValue + '" does not start with (ci) "' + APrefix + '"');
  Result := Self;
end;

function TExpectation.ToEndWithCI(const ASuffix: string): IExpectation;
begin
  RequireKind(ekString, 'ToEndWithCI');
  CheckMatch(StrEndsWithCI(FStrValue, ASuffix),
    '"' + FStrValue + '" should not end with (ci) "' + ASuffix + '"',
    '"' + FStrValue + '" does not end with (ci) "' + ASuffix + '"');
  Result := Self;
end;

{ ── TExpectation: Pointer identity ───────────────────────────────────────── }

function TExpectation.ToBeSame(const AExpected: Pointer): IExpectation;
begin
  RequireKind(ekPointer, 'ToBeSame');
  CheckMatch(FPtrValue = AExpected,
    'Expected different pointer but both are $' +
      IntToHex(NativeUInt(FPtrValue), 16),
    'Expected $' + IntToHex(NativeUInt(AExpected), 16) +
      ' but got $' + IntToHex(NativeUInt(FPtrValue), 16));
  Result := Self;
end;

function TExpectation.ToEqualPointer(const AExpected: Pointer): IExpectation;
begin
  Result := ToBeSame(AExpected);
end;

{ ── TExpectation: Double equality ────────────────────────────────────────── }

function TExpectation.ToEqualD(const AExpected: Double;
  const AEpsilon: Double): IExpectation;
begin
  RequireKind(ekDouble, 'ToEqualD');
  if IsNan(FDoubleValue) or IsNan(AExpected) then
    InternalFail(FloatToStr(FDoubleValue) + ' <> ' +
      FloatToStr(AExpected) + ' (NaN)');
  CheckMatch(Abs(FDoubleValue - AExpected) <= AEpsilon,
    FloatToStr(FDoubleValue) + ' should not equal ' +
      FloatToStr(AExpected) + ' (+/-' + FloatToStr(AEpsilon) + ')',
    FloatToStr(FDoubleValue) + ' <> ' +
      FloatToStr(AExpected) + ' (+/-' + FloatToStr(AEpsilon) + ')');
  Result := Self;
end;

{ ── TExpectation: Relative tolerance ──────────────────────────────────────── }

function TExpectation.ToBeNearRel(const AExpected: Double;
  const ARelEps: Double): IExpectation;
var
  LAbsDiff, LScale: Double;
begin
  RequireKind(ekDouble, 'ToBeNearRel');
  if IsNan(FDoubleValue) or IsNan(AExpected) then
    InternalFail('Expected ' + FloatToStr(AExpected) +
      ' (rel ' + FloatToStr(ARelEps) + ') but got ' + FloatToStr(FDoubleValue) + ' (NaN)');
  LAbsDiff := Abs(FDoubleValue - AExpected);
  LScale := Abs(AExpected);
  if Abs(FDoubleValue) > LScale then
    LScale := Abs(FDoubleValue);
  { Near-zero fallback: when LScale < ARelEps, use absolute comparison }
  if LScale < ARelEps then
  begin
    if FNegated then
    begin
      if LAbsDiff <= ARelEps then
        InternalFail('Expected not near ' + FloatToStr(AExpected) +
          ' (rel ' + FloatToStr(ARelEps) + ') but got ' + FloatToStr(FDoubleValue));
    end
    else
    begin
      if LAbsDiff > ARelEps then
        InternalFail('Expected ' + FloatToStr(AExpected) +
          ' (rel ' + FloatToStr(ARelEps) + ') but got ' + FloatToStr(FDoubleValue));
    end;
  end
  else
  begin
    if FNegated then
    begin
      if LAbsDiff <= ARelEps * LScale then
        InternalFail('Expected not near ' + FloatToStr(AExpected) +
          ' (rel ' + FloatToStr(ARelEps) + ') but got ' + FloatToStr(FDoubleValue));
    end
    else
    begin
      if LAbsDiff > ARelEps * LScale then
        InternalFail('Expected ' + FloatToStr(AExpected) +
          ' (rel ' + FloatToStr(ARelEps) + ') but got ' + FloatToStr(FDoubleValue));
    end;
  end;
  Result := Self;
end;

function TExpectation.ToNotBeNearRel(const AExpected: Double;
  const ARelEps: Double): IExpectation;
begin
  RequireKind(ekDouble, 'ToNotBeNearRel');
  FNegated := not FNegated;
  try
    Result := ToBeNearRel(AExpected, ARelEps);
  finally
    FNegated := not FNegated;
  end;
end;

function TExpectation.ToBeNaN: IExpectation;
begin
  RequireKind(ekDouble, 'ToBeNaN');
  CheckMatch(IsNan(FDoubleValue),
    'Expected non-NaN but got NaN',
    'Expected NaN but got ' + FloatToStr(FDoubleValue));
  Result := Self;
end;

function TExpectation.ToBeNotNaN: IExpectation;
begin
  RequireKind(ekDouble, 'ToBeNotNaN');
  CheckMatch(not IsNan(FDoubleValue),
    'Expected NaN but got ' + FloatToStr(FDoubleValue),
    'Expected non-NaN but got NaN');
  Result := Self;
end;

function TExpectation.ToBeInf: IExpectation;
begin
  RequireKind(ekDouble, 'ToBeInf');
  CheckMatch(IsInfinite(FDoubleValue),
    'Expected non-infinite but got ' + FloatToStr(FDoubleValue),
    'Expected infinite but got ' + FloatToStr(FDoubleValue));
  Result := Self;
end;

function TExpectation.ToBeNotInf: IExpectation;
begin
  RequireKind(ekDouble, 'ToBeNotInf');
  CheckMatch(not IsInfinite(FDoubleValue),
    'Expected infinite but got ' + FloatToStr(FDoubleValue),
    'Expected non-infinite but got ' + FloatToStr(FDoubleValue));
  Result := Self;
end;

function TExpectation.ToBeFinite: IExpectation;
var
  LIsFinite: Boolean;
  LActual: string;
begin
  RequireKind(ekDouble, 'ToBeFinite');
  LIsFinite := (not IsNan(FDoubleValue)) and (not IsInfinite(FDoubleValue));
  if IsNan(FDoubleValue) then
    LActual := 'NaN'
  else
    LActual := FloatToStr(FDoubleValue);
  CheckMatch(LIsFinite,
    'Expected non-finite but got ' + LActual,
    'Expected finite but got ' + LActual);
  Result := Self;
end;

{ ── TExpectation: WithMessage, ToEqualBytes, ToFailUnexpected ───────────── }

function TExpectation.WithMessage(const AMessage: string): IExpectation;
var
  LCopy: TExpectation;
begin
  LCopy := CloneSelf;
  LCopy.FMessage := AMessage;
  Result := LCopy;
end;

function TExpectation.ToEqualBytes(const AExpected: TBytes): IExpectation;
var
  I, LLen: NativeInt;
  LMatch: Boolean;
  LActLen, LExpLen: NativeInt;
begin
  RequireKind(ekBytes, 'ToEqualBytes');
  LActLen := Length(FBytesValue);
  LExpLen := Length(AExpected);
  if LActLen <> LExpLen then
  begin
    CheckMatch(False,
      'Expected same byte array but lengths differ (' +
        IntToStr(LExpLen) + ' vs ' + IntToStr(LActLen) + ')',
      'Expected ' + IntToStr(LExpLen) + ' bytes but got ' + IntToStr(LActLen));
    Result := Self;
    Exit;
  end;
  { Both empty — always equal }
  if LActLen = 0 then
  begin
    CheckMatch(True,
      'Expected different byte array but both are empty',
      '');
    Result := Self;
    Exit;
  end;
  LMatch := True;
  LLen := LActLen;
  for I := 0 to LLen - 1 do
    if FBytesValue[I] <> AExpected[I] then
    begin
      LMatch := False;
      CheckMatch(LMatch,
        'Expected different byte array but both are equal (' + IntToStr(LLen) + ' bytes)',
        'Byte arrays differ at index ' + IntToStr(I) +
          ': expected $' + IntToHex(AExpected[I], 2) +
          ' but got $' + IntToHex(FBytesValue[I], 2));
      Result := Self;
      Exit;
    end;
  { All bytes match }
  CheckMatch(True,
    'Expected different byte array but both are equal (' + IntToStr(LLen) + ' bytes)',
    '');
  Result := Self;
end;

function TExpectation.ToBeOneOf(const AValues: array of string): IExpectation;
var
  I: Integer;
  LFound: Boolean;
  LList: string;
begin
  RequireKind(ekString, 'ToBeOneOf');
  LFound := False;
  LList := '';
  for I := 0 to High(AValues) do
  begin
    if I > 0 then LList := LList + ', ';
    LList := LList + '"' + AValues[I] + '"';
    if FStrValue = AValues[I] then
      LFound := True;
  end;
  CheckMatch(LFound,
    '"' + FStrValue + '" should not be one of [' + LList + ']',
    '"' + FStrValue + '" is not one of [' + LList + ']');
  Result := Self;
end;

function TExpectation.ToBeOneOfInt(const AValues: array of Int64): IExpectation;
var
  I: Integer;
  LFound: Boolean;
  LList: string;
begin
  RequireKind(ekInt64, 'ToBeOneOfInt');
  LFound := False;
  LList := '';
  for I := 0 to High(AValues) do
  begin
    if I > 0 then LList := LList + ', ';
    LList := LList + IntToStr(AValues[I]);
    if FIntValue = AValues[I] then
      LFound := True;
  end;
  CheckMatch(LFound,
    IntToStr(FIntValue) + ' should not be one of [' + LList + ']',
    IntToStr(FIntValue) + ' is not one of [' + LList + ']');
  Result := Self;
end;

function TExpectation.ToBeOneOfBool(const AValues: array of Boolean): IExpectation;
var
  I: Integer;
  LFound: Boolean;
  LList: string;
begin
  RequireKind(ekBool, 'ToBeOneOfBool');
  LFound := False;
  LList := '';
  for I := 0 to High(AValues) do
  begin
    if I > 0 then LList := LList + ', ';
    LList := LList + BoolToStr(AValues[I], 'True', 'False');
    if FBoolValue = AValues[I] then
      LFound := True;
  end;
  CheckMatch(LFound,
    BoolToStr(FBoolValue, 'True', 'False') + ' should not be one of [' + LList + ']',
    BoolToStr(FBoolValue, 'True', 'False') + ' is not one of [' + LList + ']');
  Result := Self;
end;

function TExpectation.ToMatch(const APattern: string): IExpectation;
begin
  RequireKind(ekString, 'ToMatch');
  CheckMatch(RegexIsMatch(APattern, FStrValue),
    '"' + FStrValue + '" should not match pattern "' + APattern + '"',
    '"' + FStrValue + '" does not match pattern "' + APattern + '"');
  Result := Self;
end;

function TExpectation.ToEqualIntArray(const AExpected: array of Int64): IExpectation;
const
  MAX_DIFFS = 10;
var
  I, LMin, LDiffCount: Integer;
  LMsg, LDiffs: string;
begin
  RequireKind(ekIntArray, 'ToEqualIntArray');
  if Length(FIntArrayValue) <> Length(AExpected) then
  begin
    LMsg := 'Expected array length ' + IntToStr(Length(AExpected)) +
      ' but got ' + IntToStr(Length(FIntArrayValue));
    CheckMatch(False, LMsg, LMsg);
    Result := Self;
    Exit;
  end;
  LMin := Length(AExpected);
  LDiffCount := 0;
  LDiffs := '';
  for I := 0 to LMin - 1 do
  begin
    if FIntArrayValue[I] <> AExpected[I] then
    begin
      Inc(LDiffCount);
      if LDiffCount <= MAX_DIFFS then
      begin
        if LDiffs <> '' then LDiffs := LDiffs + #10;
        LDiffs := LDiffs + '  [' + IntToStr(I) + '] expected ' +
          IntToStr(AExpected[I]) + ' but got ' + IntToStr(FIntArrayValue[I]);
      end;
    end;
  end;
  if LDiffCount > 0 then
  begin
    LMsg := 'Arrays differ at ' + IntToStr(LDiffCount) + ' of ' +
      IntToStr(LMin) + ' positions:';
    if LDiffCount > MAX_DIFFS then
      LMsg := LMsg + ' (showing first ' + IntToStr(MAX_DIFFS) + ')';
    LMsg := LMsg + #10 + LDiffs;
    CheckMatch(False, LMsg, LMsg);
  end
  else
    CheckMatch(True,
      'Expected arrays to differ but both are identical (' +
        IntToStr(LMin) + ' elements)', '');
  Result := Self;
end;

function TExpectation.ToEqualStrArray(const AExpected: array of string): IExpectation;
const
  MAX_DIFFS = 10;
var
  I, LMin, LDiffCount: Integer;
  LMsg, LDiffs: string;
begin
  RequireKind(ekStrArray, 'ToEqualStrArray');
  if Length(FStrArrayValue) <> Length(AExpected) then
  begin
    LMsg := 'Expected array length ' + IntToStr(Length(AExpected)) +
      ' but got ' + IntToStr(Length(FStrArrayValue));
    CheckMatch(False, LMsg, LMsg);
    Result := Self;
    Exit;
  end;
  LMin := Length(AExpected);
  LDiffCount := 0;
  LDiffs := '';
  for I := 0 to LMin - 1 do
  begin
    if FStrArrayValue[I] <> AExpected[I] then
    begin
      Inc(LDiffCount);
      if LDiffCount <= MAX_DIFFS then
      begin
        if LDiffs <> '' then LDiffs := LDiffs + #10;
        LDiffs := LDiffs + '  [' + IntToStr(I) + '] expected "' +
          AExpected[I] + '" but got "' + FStrArrayValue[I] + '"';
      end;
    end;
  end;
  if LDiffCount > 0 then
  begin
    LMsg := 'Arrays differ at ' + IntToStr(LDiffCount) + ' of ' +
      IntToStr(LMin) + ' positions:';
    if LDiffCount > MAX_DIFFS then
      LMsg := LMsg + ' (showing first ' + IntToStr(MAX_DIFFS) + ')';
    LMsg := LMsg + #10 + LDiffs;
    CheckMatch(False, LMsg, LMsg);
  end
  else
    CheckMatch(True,
      'Expected arrays to differ but both are identical (' +
        IntToStr(LMin) + ' elements)', '');
  Result := Self;
end;

function TExpectation.ToContainInt(const AValue: Int64): IExpectation;
var
  I: Integer;
  LFound: Boolean;
begin
  RequireKind(ekIntArray, 'ToContainInt');
  LFound := False;
  for I := 0 to High(FIntArrayValue) do
    if FIntArrayValue[I] = AValue then
    begin
      LFound := True;
      Break;
    end;
  CheckMatch(LFound,
    'Array should not contain ' + IntToStr(AValue),
    'Array does not contain ' + IntToStr(AValue));
  Result := Self;
end;

function TExpectation.ToContainStr(const AValue: string): IExpectation;
var
  I: Integer;
  LFound: Boolean;
begin
  RequireKind(ekStrArray, 'ToContainStr');
  LFound := False;
  for I := 0 to High(FStrArrayValue) do
    if FStrArrayValue[I] = AValue then
    begin
      LFound := True;
      Break;
    end;
  CheckMatch(LFound,
    'Array should not contain "' + AValue + '"',
    'Array does not contain "' + AValue + '"');
  Result := Self;
end;

function TExpectation.ToContain(const AValue: Byte): IExpectation;
var
  I: Integer;
  LFound: Boolean;
begin
  RequireKind(ekBytes, 'ToContain(byte)');
  LFound := False;
  for I := 0 to High(FBytesValue) do
    if FBytesValue[I] = AValue then
    begin
      LFound := True;
      Break;
    end;
  CheckMatch(LFound,
    'Bytes should not contain $' + IntToHex(AValue, 2),
    'Byte array does not contain $' + IntToHex(AValue, 2));
  Result := Self;
end;

function TExpectation.ToBeEmpty: IExpectation;
var
  LLen: NativeInt;
begin
  case FKind of
    ekString:   LLen := Length(FStrValue);
    ekIntArray: LLen := Length(FIntArrayValue);
    ekStrArray: LLen := Length(FStrArrayValue);
    ekBytes:    LLen := Length(FBytesValue);
  else
    InternalFail('ToBeEmpty requires string, array, or bytes expectation, ' +
      'but got ' + KindNames[FKind] + '. Use ' + FactoryHints[FKind] +
      ' to create the correct type.');
    Result := Self;
    Exit;
  end;
  CheckMatch(LLen = 0,
    'Expected non-empty but got empty',
    'Expected empty but got ' + IntToStr(LLen) + ' element(s)');
  Result := Self;
end;

function TExpectation.ToBeNotEmpty: IExpectation;
var
  LLen: NativeInt;
begin
  case FKind of
    ekString:   LLen := Length(FStrValue);
    ekIntArray: LLen := Length(FIntArrayValue);
    ekStrArray: LLen := Length(FStrArrayValue);
    ekBytes:    LLen := Length(FBytesValue);
  else
    InternalFail('ToBeNotEmpty requires string, array, or bytes expectation, ' +
      'but got ' + KindNames[FKind] + '. Use ' + FactoryHints[FKind] +
      ' to create the correct type.');
    Result := Self;
    Exit;
  end;
  CheckMatch(LLen > 0,
    'Expected empty but got ' + IntToStr(LLen) + ' element(s)',
    'Expected non-empty but got empty');
  Result := Self;
end;

function TExpectation.ToBeSorted: IExpectation;
var
  I: Integer;
begin
  case FKind of
    ekIntArray:
    begin
      for I := 1 to High(FIntArrayValue) do
        if FIntArrayValue[I] < FIntArrayValue[I - 1] then
        begin
          CheckMatch(False,
            'Array is sorted but expected unsorted',
            'Array not sorted at index ' + IntToStr(I) +
            ': ' + IntToStr(FIntArrayValue[I - 1]) + ' > ' +
            IntToStr(FIntArrayValue[I]));
          Result := Self;
          Exit;
        end;
      CheckMatch(True,
        'Expected array not to be sorted but it is',
        'Array is sorted');
    end;
    ekStrArray:
    begin
      for I := 1 to High(FStrArrayValue) do
        if FStrArrayValue[I] < FStrArrayValue[I - 1] then
        begin
          CheckMatch(False,
            'Array is sorted but expected unsorted',
            'Array not sorted at index ' + IntToStr(I) +
            ': "' + FStrArrayValue[I - 1] + '" > "' +
            FStrArrayValue[I] + '"');
          Result := Self;
          Exit;
        end;
      CheckMatch(True,
        'Expected array not to be sorted but it is',
        'Array is sorted');
    end;
  else
    InternalFail('ToBeSorted requires int array or string array expectation, ' +
      'but got ' + KindNames[FKind] + '. Use ' + FactoryHints[FKind] +
      ' to create the correct type.');
  end;
  Result := Self;
end;

procedure TExpectation.ToFailUnexpected(const AMessage: string);
begin
  if FMessage <> '' then
  begin
    if AMessage <> '' then
      InternalFail(FMessage + ': ' + AMessage)
    else
      InternalFail(FMessage + ': unexpected');
  end
  else
  begin
    if AMessage <> '' then
      InternalFail(AMessage)
    else
      InternalFail('unexpected');
  end;
end;

function TExpectation.ToBeInstanceOf(AClass: TClass): IExpectation;
var
  LObj: TObject;
begin
  RequireKind(ekPointer, 'ToBeInstanceOf');
  if AClass = nil then
    InternalFail('ToBeInstanceOf: AClass is nil');
  LObj := TObject(FPtrValue);
  if FNegated then
  begin
    if (LObj <> nil) and (LObj is AClass) then
      InternalFail('Expected object not to be instance of ' + AClass.ClassName +
        ' but it is');
  end
  else
  begin
    if LObj = nil then
      InternalFail('Expected instance of ' + AClass.ClassName + ' but got nil')
    else if not (LObj is AClass) then
      InternalFail('Expected instance of ' + AClass.ClassName +
        ' but got ' + LObj.ClassName);
  end;
  Result := Self;
end;

function TExpectation.ToMatchSnapshot(const ASnapshotDir,
  ASnapshotName: string): IExpectation;
begin
  RequireKind(ekString, 'ToMatchSnapshot');
  CheckSnapshot(FStrValue, ASnapshotDir, ASnapshotName);
  Result := Self;
end;

{ ── Expect factories ──────────────────────────────────────────────────────── }

function Expect(const AValue: string): IExpectation;
begin
  Result := TExpectation.AllocStr(AValue);
end;

function ExpectStr(const AValue: string): IExpectation;
begin
  Result := TExpectation.AllocStr(AValue);
end;

function ExpectInt(const AValue: Int64): IExpectation;
begin
  Result := TExpectation.AllocInt(AValue);
end;

function ExpectBool(AValue: Boolean): IExpectation;
begin
  Result := TExpectation.AllocBool(AValue);
end;

function ExpectDouble(const AValue: Double): IExpectation;
begin
  Result := TExpectation.AllocDouble(AValue);
end;

function ExpectPtr(const AValue: Pointer): IExpectation;
begin
  Result := TExpectation.AllocPtr(AValue);
end;

function ExpectObj(const AValue: TObject): IExpectation;
begin
  Result := TExpectation.AllocPtr(Pointer(AValue));
end;

function ExpectProc(AProc: TTestProc): IExpectation;
begin
  Result := TExpectation.AllocProc(AProc);
end;

function ExpectBytes(const AValue: TBytes): IExpectation;
begin
  Result := TExpectation.AllocBytes(AValue);
end;

function ExpectArrayOfInt(const AValues: array of Int64): IExpectation;
begin
  Result := TExpectation.AllocIntArray(AValues);
end;

function ExpectArrayOfStr(const AValues: array of string): IExpectation;
begin
  Result := TExpectation.AllocStrArray(AValues);
end;

{ ── Initialization / Finalization ────────────────────────────────────────── }

initialization
  GMainThreadTid := platform_thread_id;

finalization
begin
  { Release all pooled expectations when thread exits }
  if ThreadPool.Initialized then
  begin
    while ThreadPool.Count > 0 do
    begin
      Dec(ThreadPool.Count);
      ThreadPool.Pool[ThreadPool.Count].Free;
      ThreadPool.Pool[ThreadPool.Count] := nil;
    end;
  end;
end;

end.
