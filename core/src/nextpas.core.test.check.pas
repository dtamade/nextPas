{ nextpas.core.test.check — Procedural Check* assertion API
  =========================================================
  Depends on: nextpas.core.test.types }

unit nextpas.core.test.check;

{$I nextpas.core.settings.inc}

interface

uses
  SysUtils,
  nextpas.core.test.types;

procedure Check(ACondition: Boolean; const AMessage: string = '');
procedure CheckEqual(const AExpected, AActual: string); overload;
procedure CheckEqual(AExpected, AActual: Int64); overload;
procedure CheckEqual(AExpected, AActual: Boolean); overload;
procedure CheckEqual(AExpected, AActual: Pointer); overload;
procedure CheckNotEqual(const AExpected, AActual: string); overload;
procedure CheckNotEqual(AExpected, AActual: Int64); overload;
procedure CheckNotEqual(AExpected, AActual: Boolean); overload;
procedure CheckNotEqual(AExpected, AActual: Pointer); overload;
procedure CheckTrue(AValue: Boolean; const AMessage: string = '');
procedure CheckFalse(AValue: Boolean; const AMessage: string = '');
procedure CheckNil(AValue: Pointer; const AMessage: string = '');
procedure CheckNotNil(AValue: Pointer; const AMessage: string = '');
procedure CheckContains(const AHaystack, ANeedle: string);
procedure CheckStartsWith(const AStr, APrefix: string);
procedure CheckEndsWith(const AStr, ASuffix: string);
procedure CheckSame(AExpected, AActual: Pointer; const AMessage: string = '');
procedure CheckInRange(AValue, ALow, AHigh: Int64);
procedure CheckLength(AExpected, AActual: NativeInt);
procedure CheckRaises(AExceptionClass: ExceptClass; AProc: TTestProc;
  const AMessage: string = '');
procedure CheckNoRaise(AProc: TTestProc; const AMessage: string = '');
procedure CheckNear(AExpected, AActual: Double;
  AEpsilon: Double = 1e-10; const AMessage: string = '');
procedure CheckNotNear(AExpected, AActual: Double;
  AEpsilon: Double = 1e-10; const AMessage: string = '');
procedure Fail(const AMessage: string);
procedure Skip(const AReason: string = '');

function StringDiff(const AExpected, AActual: string): string;

implementation

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

function StringDiff(const AExpected, AActual: string): string;
var
  I, LMin, LStart, LEnd: Integer;
begin
  LMin := Length(AExpected);
  if Length(AActual) < LMin then
    LMin := Length(AActual);
  I := 1;
  while (I <= LMin) and (AExpected[I] = AActual[I]) do
    Inc(I);
  if I > LMin then
    I := LMin; { difference is purely in length }
  { Extract context around first difference }
  LStart := I - 10;
  if LStart < 1 then LStart := 1;
  LEnd := I + 20;
  if LEnd > Length(AExpected) then LEnd := Length(AExpected);
  Result := 'Strings differ at position ' + IntToStr(I) + ':' + #10 +
    '  expected: ...' + Copy(AExpected, LStart, LEnd - LStart + 1) + '...' + #10;
  LEnd := I + 20;
  if LEnd > Length(AActual) then LEnd := Length(AActual);
  Result := Result +
    '  actual:   ...' + Copy(AActual, LStart, LEnd - LStart + 1) + '...' + #10 +
    '  (lengths: ' + IntToStr(Length(AExpected)) + ' vs ' + IntToStr(Length(AActual)) + ')';
end;

procedure CheckEqual(const AExpected, AActual: string);
begin
  if AExpected <> AActual then
  begin
    if (Length(AExpected) > 40) or (Length(AActual) > 40) or
       (Pos(#10, AExpected) > 0) or (Pos(#10, AActual) > 0) then
      InternalFail(StringDiff(AExpected, AActual))
    else
      InternalFail('Expected "' + AExpected + '" but got "' + AActual + '"');
  end;
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
  begin
    if (Length(AActual) > 40) or (Pos(#10, AActual) > 0) then
      InternalFail('Expected values to differ but both have length ' +
        IntToStr(Length(AActual)))
    else
      InternalFail('Expected values to differ but both are "' + AActual + '"');
  end;
end;

procedure CheckNotEqual(AExpected, AActual: Int64);
begin
  if AExpected = AActual then
    InternalFail('Expected values to differ but both are ' + IntToStr(AActual));
end;

procedure CheckNotEqual(AExpected, AActual: Boolean);
begin
  if AExpected = AActual then
    InternalFail('Expected values to differ but both are ' +
      BoolToStr(AActual, 'True', 'False'));
end;

procedure CheckNotEqual(AExpected, AActual: Pointer);
begin
  if AExpected = AActual then
    InternalFail('Expected values to differ but both are $' +
      IntToHex(NativeUInt(AActual), 16));
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

procedure CheckLength(AExpected, AActual: NativeInt);
begin
  if AExpected <> AActual then
    InternalFail('Expected length ' + IntToStr(AExpected) +
      ' but got ' + IntToStr(AActual));
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

procedure CheckNear(AExpected, AActual: Double;
  AEpsilon: Double; const AMessage: string);
var
  LDiff: Double;
begin
  LDiff := AActual - AExpected;
  if LDiff < 0 then LDiff := -LDiff;
  if LDiff > AEpsilon then
  begin
    if AMessage <> '' then
      InternalFail(AMessage)
    else
      InternalFail('Expected ' + FloatToStr(AExpected) +
        ' (+/-' + FloatToStr(AEpsilon) + ') but got ' + FloatToStr(AActual));
  end;
end;

procedure CheckNotNear(AExpected, AActual: Double;
  AEpsilon: Double; const AMessage: string);
var
  LDiff: Double;
begin
  LDiff := AActual - AExpected;
  if LDiff < 0 then LDiff := -LDiff;
  if LDiff <= AEpsilon then
  begin
    if AMessage <> '' then
      InternalFail(AMessage)
    else
      InternalFail('Expected not near ' + FloatToStr(AExpected) +
        ' (+/-' + FloatToStr(AEpsilon) + ') but got ' + FloatToStr(AActual));
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

end.
