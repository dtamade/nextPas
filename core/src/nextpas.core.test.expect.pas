{ nextpas.core.test.expect — Fluent IExpectation API
  =========================================================
  Depends on: nextpas.core.test.types }

unit nextpas.core.test.expect;

{$I nextpas.core.settings.inc}

interface

uses
  SysUtils,
  nextpas.core.test.types;

{ ── IExpectation (fluent) ─────────────────────────────────────────────────── }

type
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
    function ToBeNear(AExpected: Double;
      AEpsilon: Double = 1e-10): IExpectation;
    function ToNotBeNear(AExpected: Double;
      AEpsilon: Double = 1e-10): IExpectation;
  end;

{ ── Expect (fluent factory) ───────────────────────────────────────────────── }

function Expect(const AValue: string): IExpectation;
function ExpectInt(AValue: Int64): IExpectation;
function ExpectBool(AValue: Boolean): IExpectation;
function ExpectDouble(AValue: Double): IExpectation;
function ExpectPtr(AValue: Pointer): IExpectation;
function ExpectProc(AProc: TTestProc): IExpectation;

implementation

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
    constructor CreateInt(AValue: Int64);
    constructor CreateBool(AValue: Boolean);
    constructor CreatePtr(AValue: Pointer);
    constructor CreateProc(AProc: TTestProc);
    constructor CreateDouble(AValue: Double);

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
    function ToBeNear(AExpected: Double;
      AEpsilon: Double = 1e-10): IExpectation;
    function ToNotBeNear(AExpected: Double;
      AEpsilon: Double = 1e-10): IExpectation;
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

constructor TExpectation.CreateDouble(AValue: Double);
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
  Result := Self;
end;

function TExpectation.ToBeNear(AExpected: Double;
  AEpsilon: Double): IExpectation;
var
  LDiff: Double;
begin
  if FKind <> ekDouble then
    InternalFail('ToBeNear called on non-double expectation');
  LDiff := FDoubleValue - AExpected;
  if LDiff < 0 then LDiff := -LDiff;
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

function TExpectation.ToNotBeNear(AExpected: Double;
  AEpsilon: Double): IExpectation;
begin
  FNegated := not FNegated;
  Result := ToBeNear(AExpected, AEpsilon);
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

function ExpectDouble(AValue: Double): IExpectation;
begin
  Result := TExpectation.CreateDouble(AValue);
end;

function ExpectPtr(AValue: Pointer): IExpectation;
begin
  Result := TExpectation.CreatePtr(AValue);
end;

function ExpectProc(AProc: TTestProc): IExpectation;
begin
  Result := TExpectation.CreateProc(AProc);
end;

end.
