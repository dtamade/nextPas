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
    function ToBeGreaterThan(const AExpected: Int64): IExpectation;
    function ToBeLessThan(const AExpected: Int64): IExpectation;
    function ToBeGreaterOrEqual(const AExpected: Int64): IExpectation;
    function ToBeLessOrEqual(const AExpected: Int64): IExpectation;
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
    function ToBeGreaterThanD(const AExpected: Double): IExpectation;
    function ToBeLessThanD(const AExpected: Double): IExpectation;
    function ToBeGreaterOrEqualD(const AExpected: Double): IExpectation;
    function ToBeLessOrEqualD(const AExpected: Double): IExpectation;
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
    { Double equality within epsilon (like CheckEqual(Double)). }
    function ToEqualD(const AExpected: Double;
      const AEpsilon: Double = 1e-10): IExpectation;
    { Relative tolerance: |a-b| <= ARelEps * max(|a|, |b|).
      Better than ToBeNear for values spanning wide ranges. }
    function ToBeNearRel(const AExpected: Double;
      const ARelEps: Double = 1e-9): IExpectation;
    function ToNotBeNearRel(const AExpected: Double;
      const ARelEps: Double = 1e-9): IExpectation;
  end;

{ ── Expect (fluent factory) ───────────────────────────────────────────────── }

function Expect(const AValue: string): IExpectation;
{ Alias for Expect(string) — explicit naming for clarity. }
function ExpectStr(const AValue: string): IExpectation;
function ExpectInt(const AValue: Int64): IExpectation;
function ExpectBool(AValue: Boolean): IExpectation;
function ExpectDouble(const AValue: Double): IExpectation;
function ExpectPtr(const AValue: Pointer): IExpectation;
function ExpectProc(AProc: TTestProc): IExpectation;

implementation

uses
  Math; { IsNan for Double comparison NaN guards }

{ ═════════════════════════════════════════════════════════════════════════════ }
{ TExpectation (fluent API)                                                    }
{ ═════════════════════════════════════════════════════════════════════════════ }

type
  TExpectationKind = (
    ekString, ekInt64, ekBool, ekPointer, ekProc, ekDouble
  );

  TExpectation = class(TInterfacedObject, IExpectation)
  private
    FKind       : TExpectationKind;
    FStrValue   : string;
    FIntValue   : Int64;
    FBoolValue  : Boolean;
    FPtrValue   : Pointer;
    FProcValue  : TTestProc;
    FDoubleValue: Double;
    FNegated    : Boolean;
  public
    constructor CreateStr(const AValue: string);
    constructor CreateInt(const AValue: Int64);
    constructor CreateBool(AValue: Boolean);
    constructor CreatePtr(const AValue: Pointer);
    constructor CreateProc(AProc: TTestProc);
    constructor CreateDouble(const AValue: Double);

    procedure RequireKind(AKind: TExpectationKind;
      const AMethod: string);
      { Guard: fail with "X called on non-Y expectation" if FKind <> AKind. }
    procedure CheckMatch(AIsMatch: Boolean;
      const ANegMsg, APosMsg: string);
      { Core negation check: fail with ANegMsg if (FNegated and AIsMatch)
        or with APosMsg if (not FNegated and not AIsMatch). }

    { IExpectation }
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
    function ToBeGreaterThan(const AExpected: Int64): IExpectation;
    function ToBeLessThan(const AExpected: Int64): IExpectation;
    function ToBeGreaterOrEqual(const AExpected: Int64): IExpectation;
    function ToBeLessOrEqual(const AExpected: Int64): IExpectation;
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
    function ToBeGreaterThanD(const AExpected: Double): IExpectation;
    function ToBeLessThanD(const AExpected: Double): IExpectation;
    function ToBeGreaterOrEqualD(const AExpected: Double): IExpectation;
    function ToBeLessOrEqualD(const AExpected: Double): IExpectation;
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

function TExpectation.Not_: IExpectation;
var
  LCopy: TExpectation;
begin
  case FKind of
    ekString:  LCopy := TExpectation.CreateStr(FStrValue);
    ekInt64:   LCopy := TExpectation.CreateInt(FIntValue);
    ekBool:    LCopy := TExpectation.CreateBool(FBoolValue);
    ekPointer: LCopy := TExpectation.CreatePtr(FPtrValue);
    ekProc:    LCopy := TExpectation.CreateProc(FProcValue);
    ekDouble:  LCopy := TExpectation.CreateDouble(FDoubleValue);
  end;
  LCopy.FNegated := not FNegated;
  Result := LCopy;
end;

procedure TExpectation.RequireKind(AKind: TExpectationKind;
  const AMethod: string);
const
  KindNames: array[TExpectationKind] of string = (
    'string', 'integer', 'boolean', 'pointer', 'proc', 'double'
  );
begin
  if FKind <> AKind then
    InternalFail(AMethod + ' called on non-' + KindNames[AKind] + ' expectation');
end;

procedure TExpectation.CheckMatch(AIsMatch: Boolean;
  const ANegMsg, APosMsg: string);
begin
  if FNegated then
  begin
    if AIsMatch then
      InternalFail(ANegMsg);
  end
  else
  begin
    if not AIsMatch then
      InternalFail(APosMsg);
  end;
end;

function TExpectation.ToEqual(const AExpected: string): IExpectation;
begin
  RequireKind(ekString, 'ToEqual(string)');
  CheckMatch(FStrValue = AExpected,
    'Expected "' + FStrValue + '" not to equal "' + AExpected + '"',
    'Expected "' + AExpected + '" but got "' + FStrValue + '"');
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
var
  LMatch: Boolean;
  LLen: Integer;
begin
  RequireKind(ekString, 'ToEndWith');
  LLen := Length(ASuffix);
  if LLen = 0 then
    LMatch := True
  else
    LMatch := (Length(FStrValue) >= LLen) and
              (Copy(FStrValue, Length(FStrValue) - LLen + 1, LLen) = ASuffix);
  CheckMatch(LMatch,
    '"' + FStrValue + '" should not end with "' + ASuffix + '"',
    '"' + FStrValue + '" does not end with "' + ASuffix + '"');
  Result := Self;
end;

function TExpectation.ToBeGreaterThan(const AExpected: Int64): IExpectation;
begin
  RequireKind(ekInt64, 'ToBeGreaterThan');
  CheckMatch(FIntValue > AExpected,
    IntToStr(FIntValue) + ' should not be > ' + IntToStr(AExpected),
    IntToStr(FIntValue) + ' is not > ' + IntToStr(AExpected));
  Result := Self;
end;

function TExpectation.ToBeLessThan(const AExpected: Int64): IExpectation;
begin
  RequireKind(ekInt64, 'ToBeLessThan');
  CheckMatch(FIntValue < AExpected,
    IntToStr(FIntValue) + ' should not be < ' + IntToStr(AExpected),
    IntToStr(FIntValue) + ' is not < ' + IntToStr(AExpected));
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
begin
  RequireKind(ekString, 'ToHaveLength');
  CheckMatch(Length(FStrValue) = AExpected,
    'String should not have length ' + IntToStr(AExpected),
    'Expected length ' + IntToStr(AExpected) +
      ' but got ' + IntToStr(Length(FStrValue)));
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

function TExpectation.ToBeGreaterOrEqual(const AExpected: Int64): IExpectation;
begin
  RequireKind(ekInt64, 'ToBeGreaterOrEqual');
  CheckMatch(FIntValue >= AExpected,
    IntToStr(FIntValue) + ' should not be >= ' + IntToStr(AExpected),
    IntToStr(FIntValue) + ' is not >= ' + IntToStr(AExpected));
  Result := Self;
end;

function TExpectation.ToBeLessOrEqual(const AExpected: Int64): IExpectation;
begin
  RequireKind(ekInt64, 'ToBeLessOrEqual');
  CheckMatch(FIntValue <= AExpected,
    IntToStr(FIntValue) + ' should not be <= ' + IntToStr(AExpected),
    IntToStr(FIntValue) + ' is not <= ' + IntToStr(AExpected));
  Result := Self;
end;

{ ── TExpectation: Double comparison ────────────────────────────────────────── }

function TExpectation.ToBeGreaterThanD(const AExpected: Double): IExpectation;
begin
  RequireKind(ekDouble, 'ToBeGreaterThanD');
  if IsNan(FDoubleValue) or IsNan(AExpected) then
    InternalFail(FloatToStr(FDoubleValue) + ' is not > ' +
      FloatToStr(AExpected) + ' (NaN)');
  CheckMatch(FDoubleValue > AExpected,
    FloatToStr(FDoubleValue) + ' should not be > ' + FloatToStr(AExpected),
    FloatToStr(FDoubleValue) + ' is not > ' + FloatToStr(AExpected));
  Result := Self;
end;

function TExpectation.ToBeLessThanD(const AExpected: Double): IExpectation;
begin
  RequireKind(ekDouble, 'ToBeLessThanD');
  if IsNan(FDoubleValue) or IsNan(AExpected) then
    InternalFail(FloatToStr(FDoubleValue) + ' is not < ' +
      FloatToStr(AExpected) + ' (NaN)');
  CheckMatch(FDoubleValue < AExpected,
    FloatToStr(FDoubleValue) + ' should not be < ' + FloatToStr(AExpected),
    FloatToStr(FDoubleValue) + ' is not < ' + FloatToStr(AExpected));
  Result := Self;
end;

function TExpectation.ToBeGreaterOrEqualD(const AExpected: Double): IExpectation;
begin
  RequireKind(ekDouble, 'ToBeGreaterOrEqualD');
  if IsNan(FDoubleValue) or IsNan(AExpected) then
    InternalFail(FloatToStr(FDoubleValue) + ' is not >= ' +
      FloatToStr(AExpected) + ' (NaN)');
  CheckMatch(FDoubleValue >= AExpected,
    FloatToStr(FDoubleValue) + ' should not be >= ' + FloatToStr(AExpected),
    FloatToStr(FDoubleValue) + ' is not >= ' + FloatToStr(AExpected));
  Result := Self;
end;

function TExpectation.ToBeLessOrEqualD(const AExpected: Double): IExpectation;
begin
  RequireKind(ekDouble, 'ToBeLessOrEqualD');
  if IsNan(FDoubleValue) or IsNan(AExpected) then
    InternalFail(FloatToStr(FDoubleValue) + ' is not <= ' +
      FloatToStr(AExpected) + ' (NaN)');
  CheckMatch(FDoubleValue <= AExpected,
    FloatToStr(FDoubleValue) + ' should not be <= ' + FloatToStr(AExpected),
    FloatToStr(FDoubleValue) + ' is not <= ' + FloatToStr(AExpected));
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
begin
  RequireKind(ekString, 'ToContainCI');
  if Length(ASubstr) = 0 then
    Exit(Self); { empty needle matches everything — consistent with ToContain }
  CheckMatch(Pos(LowerCase(ASubstr), LowerCase(FStrValue)) > 0,
    '"' + FStrValue + '" should not contain (ci) "' + ASubstr + '"',
    '"' + FStrValue + '" does not contain (ci) "' + ASubstr + '"');
  Result := Self;
end;

function TExpectation.ToStartWithCI(const APrefix: string): IExpectation;
begin
  RequireKind(ekString, 'ToStartWithCI');
  CheckMatch(
    (Length(FStrValue) >= Length(APrefix)) and
    (LowerCase(Copy(FStrValue, 1, Length(APrefix))) = LowerCase(APrefix)),
    '"' + FStrValue + '" should not start with (ci) "' + APrefix + '"',
    '"' + FStrValue + '" does not start with (ci) "' + APrefix + '"');
  Result := Self;
end;

function TExpectation.ToEndWithCI(const ASuffix: string): IExpectation;
begin
  RequireKind(ekString, 'ToEndWithCI');
  CheckMatch(
    (Length(FStrValue) >= Length(ASuffix)) and
    (LowerCase(Copy(FStrValue, Length(FStrValue) - Length(ASuffix) + 1,
     Length(ASuffix))) = LowerCase(ASuffix)),
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

{ ── Expect factories ──────────────────────────────────────────────────────── }

function Expect(const AValue: string): IExpectation;
begin
  Result := TExpectation.CreateStr(AValue);
end;

function ExpectStr(const AValue: string): IExpectation;
begin
  Result := TExpectation.CreateStr(AValue);
end;

function ExpectInt(const AValue: Int64): IExpectation;
begin
  Result := TExpectation.CreateInt(AValue);
end;

function ExpectBool(AValue: Boolean): IExpectation;
begin
  Result := TExpectation.CreateBool(AValue);
end;

function ExpectDouble(const AValue: Double): IExpectation;
begin
  Result := TExpectation.CreateDouble(AValue);
end;

function ExpectPtr(const AValue: Pointer): IExpectation;
begin
  Result := TExpectation.CreatePtr(AValue);
end;

function ExpectProc(AProc: TTestProc): IExpectation;
begin
  Result := TExpectation.CreateProc(AProc);
end;

end.
