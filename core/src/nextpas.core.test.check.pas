{ nextpas.core.test.check — Procedural Check* assertion API
  =========================================================
  Depends on: nextpas.core.test.base }

unit nextpas.core.test.check;

{$I nextpas.core.settings.inc}

interface

uses
  SysUtils,          { ExceptClass — FPC built-in, irreplaceable }
  nextpas.core.text.conv,
  nextpas.core.test.base;

procedure Check(ACondition: Boolean; const AMessage: string = '');
procedure CheckEqual(const AExpected, AActual: string); overload;
procedure CheckEqual(const AExpected, AActual: Int64); overload;
procedure CheckEqual(const AExpected, AActual: Boolean); overload;
procedure CheckEqual(const AExpected, AActual: Pointer); overload;
{ CheckEqual for Double — exact bit-wise comparison.
  For floating-point tolerance comparisons, use CheckNear instead. }
procedure CheckEqual(const AExpected, AActual: Double;
  AEpsilon: Double = 1e-10); overload;
procedure CheckNotEqual(const AExpected, AActual: string); overload;
procedure CheckNotEqual(const AExpected, AActual: Int64); overload;
procedure CheckNotEqual(const AExpected, AActual: Boolean); overload;
procedure CheckNotEqual(const AExpected, AActual: Pointer); overload;
{ CheckNotEqual for Double — values must differ by more than AEpsilon.
  For floating-point tolerance comparisons, use CheckNotNear instead. }
procedure CheckNotEqual(const AExpected, AActual: Double;
  AEpsilon: Double = 1e-10); overload;
procedure CheckTrue(AValue: Boolean; const AMessage: string = '');
procedure CheckFalse(AValue: Boolean; const AMessage: string = '');
procedure CheckNil(AValue: Pointer; const AMessage: string = '');
procedure CheckNotNil(AValue: Pointer; const AMessage: string = '');
procedure CheckContains(const AHaystack, ANeedle: string);
{ Fails if AHaystack contains ANeedle. Empty needle is a no-op (always passes). }
procedure CheckNotContains(const AHaystack, ANeedle: string);
procedure CheckStartsWith(const AStr, APrefix: string);
procedure CheckEndsWith(const AStr, ASuffix: string);
{ Pointer identity: passes if AExpected = AActual (same address). }
procedure CheckSame(const AExpected, AActual: Pointer; const AMessage: string = '');
{ Inclusive range: passes if ALow <= AValue <= AHigh. }
procedure CheckInRange(const AValue, ALow, AHigh: Int64);
procedure CheckGreaterThan(const AValue, AExpected: Int64);
procedure CheckLessThan(const AValue, AExpected: Int64);
procedure CheckLength(const AExpected, AActual: NativeInt);
procedure CheckRaises(AExceptionClass: ExceptClass; AProc: TTestProc;
  const AMessage: string = '');
procedure CheckNoRaise(AProc: TTestProc; const AMessage: string = '');
procedure CheckGreaterOrEqual(const AValue, AExpected: Int64);
procedure CheckLessOrEqual(const AValue, AExpected: Int64);
{ Check that AActual is within AEpsilon of AExpected (absolute difference).
  R4-07: Uses absolute epsilon — for large values (e.g. 1e15), the default
  1e-10 is too tight. Callers should pass a larger AEpsilon or use a
  relative-epsilon variant for magnitude-spanning comparisons. }
procedure CheckNear(const AExpected, AActual: Double;
  const AEpsilon: Double = 1e-10; const AMessage: string = '');
procedure CheckNotNear(const AExpected, AActual: Double;
  const AEpsilon: Double = 1e-10; const AMessage: string = '');
procedure Fail(const AMessage: string);
{ Fail with "unexpected ClassName: Message" — for catch-all exception handlers. }
procedure FailUnexpected(const E: Exception);
procedure Skip(const AReason: string = '');

implementation

procedure FailWithDefault(const AMessage, ADefaultMsg: string);
begin
  if AMessage <> '' then
    InternalFail(AMessage)
  else
    InternalFail(ADefaultMsg);
end;

procedure Check(ACondition: Boolean; const AMessage: string);
begin
  if not ACondition then
    FailWithDefault(AMessage, 'Check failed');
end;

function Utf8SafeStart(const S: string; APos: Integer): Integer;
{ Adjust APos backward to avoid starting in the middle of a multi-byte UTF-8 sequence.
  In UTF-8, continuation bytes have the form 10xxxxxx ($80-$BF). }
begin
  Result := APos;
  if Result < 1 then
    Result := 1;
  { Scan backward past any continuation bytes }
  while (Result > 1) and (Ord(S[Result]) >= $80) and (Ord(S[Result]) <= $BF) do
    Dec(Result);
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
  LStart := Utf8SafeStart(AExpected, I - 10);
  LEnd := I + 20;
  if LEnd > Length(AExpected) then LEnd := Length(AExpected);
  Result := 'Strings differ at position ' + IntToStr(I) + ':' + #10 +
    '  expected: ...' + Copy(AExpected, LStart, LEnd - LStart + 1) + '...' + #10;
  LEnd := I + 20;
  if LEnd > Length(AActual) then LEnd := Length(AActual);
  Result := Result +
    '  actual:   ...' + Copy(AActual, Utf8SafeStart(AActual, I - 10),
      LEnd - Utf8SafeStart(AActual, I - 10) + 1) + '...' + #10 +
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

procedure CheckEqual(const AExpected, AActual: Int64);
begin
  if AExpected <> AActual then
    InternalFail('Expected ' + IntToStr(AExpected) + ' but got ' + IntToStr(AActual));
end;

procedure CheckEqual(const AExpected, AActual: Boolean);
begin
  if AExpected <> AActual then
    InternalFail('Expected ' + BoolToStr(AExpected, 'True', 'False') +
      ' but got ' + BoolToStr(AActual, 'True', 'False'));
end;

procedure CheckEqual(const AExpected, AActual: Pointer);
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

procedure CheckNotEqual(const AExpected, AActual: Int64);
begin
  if AExpected = AActual then
    InternalFail('Expected values to differ but both are ' + IntToStr(AActual));
end;

procedure CheckNotEqual(const AExpected, AActual: Boolean);
begin
  if AExpected = AActual then
    InternalFail('Expected values to differ but both are ' +
      BoolToStr(AActual, 'True', 'False'));
end;

procedure CheckNotEqual(const AExpected, AActual: Pointer);
begin
  if AExpected = AActual then
    InternalFail('Expected values to differ but both are $' +
      IntToHex(NativeUInt(AActual), 16));
end;

procedure CheckNear(const AExpected, AActual: Double;
  const AEpsilon: Double; const AMessage: string);
var
  LDiff: Double;
begin
  LDiff := Abs(AActual - AExpected);
  if LDiff > AEpsilon then
    FailWithDefault(AMessage,
      'Expected ' + FloatToStr(AExpected) +
      ' (+/-' + FloatToStr(AEpsilon) + ') but got ' + FloatToStr(AActual));
end;

procedure CheckNotNear(const AExpected, AActual: Double;
  const AEpsilon: Double; const AMessage: string);
var
  LDiff: Double;
begin
  LDiff := Abs(AActual - AExpected);
  if LDiff <= AEpsilon then
    FailWithDefault(AMessage,
      'Expected not near ' + FloatToStr(AExpected) +
      ' (+/-' + FloatToStr(AEpsilon) + ') but got ' + FloatToStr(AActual));
end;

procedure CheckEqual(const AExpected, AActual: Double;
  AEpsilon: Double);
begin
  CheckNear(AExpected, AActual, AEpsilon);
end;

procedure CheckNotEqual(const AExpected, AActual: Double;
  AEpsilon: Double);
begin
  CheckNotNear(AExpected, AActual, AEpsilon);
end;

procedure CheckTrue(AValue: Boolean; const AMessage: string);
begin
  if not AValue then
    FailWithDefault(AMessage, 'Expected condition to be True but got False');
end;

procedure CheckFalse(AValue: Boolean; const AMessage: string);
begin
  if AValue then
    FailWithDefault(AMessage, 'Expected condition to be False but got True');
end;

procedure CheckNil(AValue: Pointer; const AMessage: string);
begin
  if AValue <> nil then
    FailWithDefault(AMessage,
      'Expected nil but got $' + IntToHex(NativeUInt(AValue), 16));
end;

procedure CheckNotNil(AValue: Pointer; const AMessage: string);
begin
  if AValue = nil then
    FailWithDefault(AMessage, 'Expected non-nil but got nil');
end;

procedure CheckContains(const AHaystack, ANeedle: string);
begin
  if (Length(ANeedle) = 0) then
    Exit; { empty needle matches everything — consistent with StartsWith/EndsWith }
  if Pos(ANeedle, AHaystack) = 0 then
    InternalFail('"' + AHaystack + '" does not contain "' + ANeedle + '"');
end;

procedure CheckNotContains(const AHaystack, ANeedle: string);
begin
  if (Length(ANeedle) = 0) then
    Exit; { empty needle matches everything — companion to CheckContains }
  if Pos(ANeedle, AHaystack) > 0 then
    InternalFail('"' + AHaystack + '" should not contain "' + ANeedle + '"');
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

procedure CheckSame(const AExpected, AActual: Pointer; const AMessage: string);
begin
  if AExpected <> AActual then
    FailWithDefault(AMessage,
      'Expected same pointer $' + IntToHex(NativeUInt(AExpected), 16) +
      ' but got $' + IntToHex(NativeUInt(AActual), 16));
end;

procedure CheckInRange(const AValue, ALow, AHigh: Int64);
begin
  if ALow > AHigh then
    InternalFail('CheckInRange: ALow (' + IntToStr(ALow) +
      ') > AHigh (' + IntToStr(AHigh) + ')');
  if (AValue < ALow) or (AValue > AHigh) then
    InternalFail(IntToStr(AValue) + ' not in range [' +
      IntToStr(ALow) + '..' + IntToStr(AHigh) + ']');
end;

procedure CheckGreaterThan(const AValue, AExpected: Int64);
begin
  if AValue <= AExpected then
    InternalFail('Expected ' + IntToStr(AValue) + ' > ' +
      IntToStr(AExpected));
end;

procedure CheckLessThan(const AValue, AExpected: Int64);
begin
  if AValue >= AExpected then
    InternalFail('Expected ' + IntToStr(AValue) + ' < ' +
      IntToStr(AExpected));
end;

procedure CheckGreaterOrEqual(const AValue, AExpected: Int64);
begin
  if AValue < AExpected then
    InternalFail('Expected ' + IntToStr(AValue) + ' >= ' +
      IntToStr(AExpected));
end;

procedure CheckLessOrEqual(const AValue, AExpected: Int64);
begin
  if AValue > AExpected then
    InternalFail('Expected ' + IntToStr(AValue) + ' <= ' +
      IntToStr(AExpected));
end;

procedure CheckLength(const AExpected, AActual: NativeInt);
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
  if AExceptionClass = nil then
  begin
    InternalFail('CheckRaises: AExceptionClass is nil');
  end;
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

procedure FailUnexpected(const E: Exception);
begin
  InternalFail('unexpected ' + E.ClassName + ': ' + E.Message);
end;

procedure Skip(const AReason: string);
begin
  InternalSkip(AReason);
end;

end.
