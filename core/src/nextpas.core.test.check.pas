{ nextpas.core.test.check — Procedural Check* assertion API
  =========================================================
  Depends on: nextpas.core.test.base }

unit nextpas.core.test.check;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.system,
  nextpas.core.text.conv,
  nextpas.core.test.base;

procedure Check(ACondition: Boolean; const AMessage: string = '');
procedure CheckEqual(const AExpected, AActual: string); overload;
procedure CheckEqual(const AExpected, AActual: Int64); overload;
procedure CheckEqual(const AExpected, AActual: Boolean); overload;
procedure CheckEqual(const AExpected, AActual: Pointer); overload;
procedure CheckEqual(const AExpected, AActual: UInt64); overload;
{ CheckEqual for Double — uses CheckNear (absolute epsilon |a-b| <= AEpsilon).
  Default epsilon is 1e-10, suitable for small-to-moderate values.
  For large values (e.g. 1e15+), absolute epsilon is too tight — use
  CheckNearRel for relative tolerance, or CheckNear with a custom epsilon.
  For floating-point tolerance comparisons, use CheckNear directly. }
procedure CheckEqual(const AExpected, AActual: Double;
  AEpsilon: Double = 1e-10); overload;
{ 3-arg overloads: prepend AMessage on failure (backward compat). }
procedure CheckEqual(const AExpected, AActual: string;
  const AMessage: string); overload;
procedure CheckEqual(const AExpected, AActual: Int64;
  const AMessage: string); overload;
procedure CheckEqual(const AExpected, AActual: Boolean;
  const AMessage: string); overload;
procedure CheckNotEqual(const AExpected, AActual: string); overload;
procedure CheckNotEqual(const AExpected, AActual: string;
  const AMessage: string); overload;
procedure CheckNotEqual(const AExpected, AActual: Int64); overload;
procedure CheckNotEqual(const AExpected, AActual: Int64;
  const AMessage: string); overload;
procedure CheckNotEqual(const AExpected, AActual: Boolean); overload;
procedure CheckNotEqual(const AExpected, AActual: Boolean;
  const AMessage: string); overload;
procedure CheckNotEqual(const AExpected, AActual: Pointer); overload;
procedure CheckNotEqual(const AExpected, AActual: UInt64); overload;
{ CheckNotEqual for Double — uses absolute epsilon |a-b| <= AEpsilon.
  For floating-point tolerance comparisons, use CheckNotNear directly. }
procedure CheckNotEqual(const AExpected, AActual: Double;
  AEpsilon: Double = 1e-10); overload;
procedure CheckEqual(const AExpected, AActual: TBytes); overload;
procedure CheckNotEqual(const AExpected, AActual: TBytes); overload;
procedure CheckTrue(AValue: Boolean; const AMessage: string = '');
procedure CheckFalse(AValue: Boolean; const AMessage: string = '');
procedure CheckNil(AValue: Pointer; const AMessage: string = '');
procedure CheckNotNil(AValue: Pointer; const AMessage: string = '');
procedure CheckContains(const AHaystack, ANeedle: string);
procedure CheckContains(const AHaystack, ANeedle: string;
  const AMessage: string); overload;
{ Case-insensitive containment. }
procedure CheckContainsCI(const AHaystack, ANeedle: string);
procedure CheckContainsCI(const AHaystack, ANeedle: string;
  const AMessage: string); overload;
{ Fails if AHaystack contains ANeedle. Empty needle is a no-op (always passes). }
procedure CheckNotContains(const AHaystack, ANeedle: string);
procedure CheckNotContains(const AHaystack, ANeedle: string;
  const AMessage: string); overload;
{ Case-insensitive CheckNotContains. }
procedure CheckNotContainsCI(const AHaystack, ANeedle: string);
procedure CheckNotContainsCI(const AHaystack, ANeedle: string;
  const AMessage: string); overload;
procedure CheckStartsWith(const AStr, APrefix: string);
procedure CheckStartsWith(const AStr, APrefix: string;
  const AMessage: string); overload;
{ Case-insensitive prefix check. }
procedure CheckStartsWithCI(const AStr, APrefix: string);
procedure CheckStartsWithCI(const AStr, APrefix: string;
  const AMessage: string); overload;
procedure CheckEndsWith(const AStr, ASuffix: string);
procedure CheckEndsWith(const AStr, ASuffix: string;
  const AMessage: string); overload;
{ Case-insensitive suffix check. }
procedure CheckEndsWithCI(const AStr, ASuffix: string);
procedure CheckEndsWithCI(const AStr, ASuffix: string;
  const AMessage: string); overload;
{ Fails if AStr starts with APrefix. Empty prefix is a no-op (always passes). }
procedure CheckNotStartsWith(const AStr, APrefix: string);
procedure CheckNotStartsWith(const AStr, APrefix: string;
  const AMessage: string); overload;
{ Fails if AStr ends with ASuffix. Empty suffix is a no-op (always passes). }
procedure CheckNotEndsWith(const AStr, ASuffix: string);
procedure CheckNotEndsWith(const AStr, ASuffix: string;
  const AMessage: string); overload;
{ Pointer identity: passes if AExpected = AActual (same address). }
procedure CheckSame(const AExpected, AActual: Pointer; const AMessage: string = '');
{ Inclusive range: passes if ALow <= AValue <= AHigh. }
procedure CheckInRange(const AValue, ALow, AHigh: Int64);
procedure CheckInRange(const AValue, ALow, AHigh: Int64;
  const AMessage: string); overload;
{ Double inclusive range: passes if ALow <= AValue <= AHigh (absolute epsilon). }
procedure CheckInRangeD(const AValue, ALow, AHigh: Double;
  const AEpsilon: Double = 1e-10);
procedure CheckInRangeD(const AValue, ALow, AHigh: Double;
  const AEpsilon: Double; const AMessage: string); overload;
procedure CheckGreaterThan(const AValue, AThreshold: Int64);
procedure CheckGreaterThan(const AValue, AThreshold: Int64;
  const AMessage: string); overload;
procedure CheckLessThan(const AValue, AThreshold: Int64);
procedure CheckLessThan(const AValue, AThreshold: Int64;
  const AMessage: string); overload;
procedure CheckLength(const AExpected, AActual: NativeInt);
procedure CheckLength(const AExpected, AActual: NativeInt;
  const AMessage: string); overload;
procedure CheckRaises(AExceptionClass: ExceptClass; AProc: TTestProc;
  const AMessage: string = '');
procedure CheckNoRaise(AProc: TTestProc; const AMessage: string = '');
procedure CheckGreaterOrEqual(const AValue, AThreshold: Int64);
procedure CheckGreaterOrEqual(const AValue, AThreshold: Int64;
  const AMessage: string); overload;
procedure CheckLessOrEqual(const AValue, AThreshold: Int64);
procedure CheckLessOrEqual(const AValue, AThreshold: Int64;
  const AMessage: string); overload;
{ Double comparisons — absolute epsilon. }
procedure CheckGreaterThanD(const AValue, AThreshold: Double;
  const AEpsilon: Double = 1e-10);
procedure CheckLessThanD(const AValue, AThreshold: Double;
  const AEpsilon: Double = 1e-10);
procedure CheckGreaterOrEqualD(const AValue, AThreshold: Double;
  const AEpsilon: Double = 1e-10);
procedure CheckLessOrEqualD(const AValue, AThreshold: Double;
  const AEpsilon: Double = 1e-10);
{ Check that AActual is within AEpsilon of AExpected (absolute difference).
  R4-07: Uses absolute epsilon — for large values (e.g. 1e15), the default
  1e-10 is too tight. Callers should pass a larger AEpsilon or use
  CheckNearRel (relative tolerance) for magnitude-spanning comparisons. }
procedure CheckNear(const AExpected, AActual: Double;
  const AEpsilon: Double = 1e-10; const AMessage: string = '');
procedure CheckNotNear(const AExpected, AActual: Double;
  const AEpsilon: Double = 1e-10; const AMessage: string = '');
{ CheckNearRel — relative tolerance: |a-b| <= ARelEps * max(|a|, |b|).
  Falls back to absolute comparison when both values are near zero. }
procedure CheckNearRel(const AExpected, AActual: Double;
  const ARelEps: Double = 1e-9; const AMessage: string = '');
procedure CheckNotNearRel(const AExpected, AActual: Double;
  const ARelEps: Double = 1e-9; const AMessage: string = '');
{ CheckNaN — passes if AValue is NaN. }
procedure CheckNaN(const AValue: Double; const AMessage: string = '');
{ CheckNotNaN — passes if AValue is NOT NaN. }
procedure CheckNotNaN(const AValue: Double; const AMessage: string = '');
procedure Fail(const AMessage: string);
{ Fail with "unexpected ClassName: Message" — for catch-all exception handlers. }
procedure FailUnexpected(const E: Exception);
procedure Skip(const AReason: string = '');

{ ── Snapshot Testing ──────────────────────────────────────────────────────── }

procedure CheckSnapshot(const AActual: string;
  const ASnapshotDir, ASnapshotName: string);
{ Compare AActual against a saved snapshot file at ASnapshotDir/ASnapshotName.
  If the file does not exist, creates it (first-run auto-approval).
  If the file exists and differs, fails with a diff message.
  Set NEXTPAS_UPDATE_SNAPSHOTS=1 environment variable to auto-update. }

function ReadFileContents(const APath: string; out AContents: string): Boolean;
{ Read entire file to string. Returns False if file doesn't exist or is empty. }

procedure WriteFileContents(const APath, AContents: string);
{ Write string to file, creating directories if needed. }

{ ── Array Comparison (v8.0c) ──────────────────────────────────────────────── }

{ Compare two Int64 arrays element-by-element.
  Reports length mismatch or first differing index with values. }
procedure CheckArrayEqual(const AExpected, AActual: array of Int64); overload;

{ Compare two Int64 arrays with custom message. }
procedure CheckArrayEqual(const AExpected, AActual: array of Int64;
  const AMessage: string); overload;

{ ── Interface Nil Checks (v8.0c) ──────────────────────────────────────────── }

{ Check that an interface reference is nil. }
procedure CheckIsNil(const AValue: IInterface; const AMessage: string = '');

{ Check that an interface reference is not nil. }
procedure CheckIsNotNil(const AValue: IInterface; const AMessage: string = '');

implementation

uses
  nextpas.core.math.scalar,     { IsNan for Double comparison NaN guards }
  nextpas.core.platform.env,   { platform_env_get_str for snapshot update flag }
  nextpas.core.fs;             { ReadFileText/WriteFileText for snapshot I/O }

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

procedure CheckEqual(const AExpected, AActual: UInt64);
begin
  if AExpected <> AActual then
    InternalFail('Expected ' + UIntToStr(AExpected) +
      ' but got ' + UIntToStr(AActual));
end;

{ 3-arg overloads: direct check, prepend AMessage on failure }

procedure CheckEqual(const AExpected, AActual: string;
  const AMessage: string);
begin
  if AExpected <> AActual then
  begin
    if AMessage <> '' then
    begin
      if (Length(AExpected) > 40) or (Length(AActual) > 40) or
         (Pos(#10, AExpected) > 0) or (Pos(#10, AActual) > 0) then
        InternalFail(AMessage + ': ' + StringDiff(AExpected, AActual))
      else
        InternalFail(AMessage + ': Expected "' + AExpected + '" but got "' + AActual + '"');
    end
    else
    begin
      if (Length(AExpected) > 40) or (Length(AActual) > 40) or
         (Pos(#10, AExpected) > 0) or (Pos(#10, AActual) > 0) then
        InternalFail(StringDiff(AExpected, AActual))
      else
        InternalFail('Expected "' + AExpected + '" but got "' + AActual + '"');
    end;
  end;
end;

procedure CheckEqual(const AExpected, AActual: Int64;
  const AMessage: string);
begin
  if AExpected <> AActual then
    if AMessage <> '' then
      InternalFail(AMessage + ': Expected ' + IntToStr(AExpected) + ' but got ' + IntToStr(AActual))
    else
      InternalFail('Expected ' + IntToStr(AExpected) + ' but got ' + IntToStr(AActual));
end;

procedure CheckEqual(const AExpected, AActual: Boolean;
  const AMessage: string);
begin
  if AExpected <> AActual then
    if AMessage <> '' then
      InternalFail(AMessage + ': Expected ' + BoolToStr(AExpected, 'True', 'False') +
        ' but got ' + BoolToStr(AActual, 'True', 'False'))
    else
      InternalFail('Expected ' + BoolToStr(AExpected, 'True', 'False') +
        ' but got ' + BoolToStr(AActual, 'True', 'False'));
end;

procedure CheckNotEqual(const AExpected, AActual: string);
begin
  if AExpected = AActual then
  begin
    if (Length(AActual) > 40) or (Pos(#10, AActual) > 0) then
      InternalFail('Expected values to differ but both have length ' +
        IntToStr(Length(AActual)) + ': "' +
        Copy(AActual, 1, 30) + '..."')
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

procedure CheckNotEqual(const AExpected, AActual: UInt64);
begin
  if AExpected = AActual then
    InternalFail('Expected values to differ but both are ' +
      UIntToStr(AActual));
end;

procedure CheckNotEqual(const AExpected, AActual: string;
  const AMessage: string);
begin
  if AExpected = AActual then
    if AMessage <> '' then
      InternalFail(AMessage + ': Expected values to differ but both are "' + AActual + '"')
    else
      InternalFail('Expected values to differ but both are "' + AActual + '"');
end;

procedure CheckNotEqual(const AExpected, AActual: Int64;
  const AMessage: string);
begin
  if AExpected = AActual then
    if AMessage <> '' then
      InternalFail(AMessage + ': Expected values to differ but both are ' + IntToStr(AActual))
    else
      InternalFail('Expected values to differ but both are ' + IntToStr(AActual));
end;

procedure CheckNotEqual(const AExpected, AActual: Boolean;
  const AMessage: string);
begin
  if AExpected = AActual then
    if AMessage <> '' then
      InternalFail(AMessage + ': Expected values to differ but both are ' +
        BoolToStr(AActual, 'True', 'False'))
    else
      InternalFail('Expected values to differ but both are ' +
        BoolToStr(AActual, 'True', 'False'));
end;

procedure CheckNear(const AExpected, AActual: Double;
  const AEpsilon: Double; const AMessage: string);
var
  LDiff: Double;
begin
  if IsNan(AExpected) or IsNan(AActual) then
    InternalFail('Expected ' + FloatToStr(AExpected) +
      ' (+/-' + FloatToStr(AEpsilon) + ') but got ' + FloatToStr(AActual) + ' (NaN)');
  LDiff := Abs(AActual - AExpected);
  if LDiff > AEpsilon then
    FailWithDefault(AMessage,
      'Expected ' + FloatToStr(AExpected) +
      ' (+/-' + FloatToStr(AEpsilon) + ') but got ' + FloatToStr(AActual) +
      ' (diff=' + FloatToStr(LDiff) + ')');
end;

procedure CheckNotNear(const AExpected, AActual: Double;
  const AEpsilon: Double; const AMessage: string);
var
  LDiff: Double;
begin
  if IsNan(AExpected) or IsNan(AActual) then
    InternalFail('Expected not near ' + FloatToStr(AExpected) +
      ' (+/-' + FloatToStr(AEpsilon) + ') but got ' + FloatToStr(AActual) + ' (NaN)');
  LDiff := Abs(AActual - AExpected);
  if LDiff <= AEpsilon then
    FailWithDefault(AMessage,
      'Expected not near ' + FloatToStr(AExpected) +
      ' (+/-' + FloatToStr(AEpsilon) + ') but got ' + FloatToStr(AActual));
end;

procedure CheckNearRel(const AExpected, AActual: Double;
  const ARelEps: Double; const AMessage: string);
var
  LAbsDiff, LScale: Double;
begin
  if IsNan(AExpected) or IsNan(AActual) then
    InternalFail('Expected ' + FloatToStr(AExpected) +
      ' (rel ' + FloatToStr(ARelEps) + ') but got ' + FloatToStr(AActual) + ' (NaN)');
  LAbsDiff := Abs(AActual - AExpected);
  LScale := Abs(AExpected);
  if Abs(AActual) > LScale then
    LScale := Abs(AActual);
  { When both values are near zero, LScale ≈ 0 → relative comparison degenerates.
    Fall back to absolute comparison using ARelEps as absolute tolerance. }
  if LScale < ARelEps then
  begin
    if LAbsDiff > ARelEps then
      FailWithDefault(AMessage,
        'Expected ' + FloatToStr(AExpected) +
        ' (rel ' + FloatToStr(ARelEps) + ') but got ' + FloatToStr(AActual));
  end
  else if LAbsDiff > ARelEps * LScale then
    FailWithDefault(AMessage,
      'Expected ' + FloatToStr(AExpected) +
      ' (rel ' + FloatToStr(ARelEps) + ') but got ' + FloatToStr(AActual));
end;

procedure CheckNotNearRel(const AExpected, AActual: Double;
  const ARelEps: Double; const AMessage: string);
var
  LAbsDiff, LScale: Double;
begin
  if IsNan(AExpected) or IsNan(AActual) then
    InternalFail('Expected not near ' + FloatToStr(AExpected) +
      ' (rel ' + FloatToStr(ARelEps) + ') but got ' + FloatToStr(AActual) + ' (NaN)');
  LAbsDiff := Abs(AActual - AExpected);
  LScale := Abs(AExpected);
  if Abs(AActual) > LScale then
    LScale := Abs(AActual);
  if LScale < ARelEps then
  begin
    if LAbsDiff <= ARelEps then
      FailWithDefault(AMessage,
        'Expected not near ' + FloatToStr(AExpected) +
        ' (rel ' + FloatToStr(ARelEps) + ') but got ' + FloatToStr(AActual));
  end
  else if LAbsDiff <= ARelEps * LScale then
    FailWithDefault(AMessage,
      'Expected not near ' + FloatToStr(AExpected) +
      ' (rel ' + FloatToStr(ARelEps) + ') but got ' + FloatToStr(AActual));
end;

procedure CheckNaN(const AValue: Double; const AMessage: string);
begin
  if not IsNan(AValue) then
    FailWithDefault(AMessage,
      'Expected NaN but got ' + FloatToStr(AValue));
end;

procedure CheckNotNaN(const AValue: Double; const AMessage: string);
begin
  if IsNan(AValue) then
    FailWithDefault(AMessage, 'Expected non-NaN but got NaN');
end;

procedure CheckEqual(const AExpected, AActual: Double;
  AEpsilon: Double);
begin
  CheckNear(AExpected, AActual, AEpsilon);
end;

procedure CheckNotEqual(const AExpected, AActual: Double;
  AEpsilon: Double);
var
  LDiff: Double;
begin
  if IsNan(AExpected) or IsNan(AActual) then
    Exit; { NaN != anything, including NaN — always "not equal" }
  LDiff := Abs(AActual - AExpected);
  if LDiff <= AEpsilon then
    InternalFail('Expected values to differ but both are ' +
      FloatToStr(AExpected) + ' (+/-' + FloatToStr(AEpsilon) + ')');
end;

procedure CheckEqual(const AExpected, AActual: TBytes);
var
  I: Integer;
begin
  if Length(AExpected) <> Length(AActual) then
    InternalFail('Expected TBytes length ' + IntToStr(Length(AExpected)) +
      ' but got ' + IntToStr(Length(AActual)));
  for I := 0 to High(AExpected) do
    if AExpected[I] <> AActual[I] then
      InternalFail('TBytes differ at index ' + IntToStr(I) +
        ': expected $' + IntToHex(AExpected[I], 2) +
        ' but got $' + IntToHex(AActual[I], 2));
end;

procedure CheckNotEqual(const AExpected, AActual: TBytes);
var
  I: Integer;
  LDiffer: Boolean;
begin
  if Length(AExpected) <> Length(AActual) then
    Exit; { different lengths = not equal }
  LDiffer := False;
  for I := 0 to High(AExpected) do
    if AExpected[I] <> AActual[I] then
    begin
      LDiffer := True;
      Break;
    end;
  if not LDiffer then
    InternalFail('Expected TBytes to differ but both are identical (' +
      IntToStr(Length(AExpected)) + ' bytes)');
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

procedure CheckContains(const AHaystack, ANeedle: string;
  const AMessage: string);
begin
  if (Length(ANeedle) = 0) then
    Exit;
  if Pos(ANeedle, AHaystack) = 0 then
    if AMessage <> '' then
      InternalFail(AMessage + ': "' + AHaystack + '" does not contain "' + ANeedle + '"')
    else
      InternalFail('"' + AHaystack + '" does not contain "' + ANeedle + '"');
end;

procedure CheckNotContains(const AHaystack, ANeedle: string);
begin
  if (Length(ANeedle) = 0) then
    Exit; { empty needle is a no-op — consistent with CheckContains }
  if Pos(ANeedle, AHaystack) > 0 then
    InternalFail('"' + AHaystack + '" should not contain "' + ANeedle + '"');
end;

procedure CheckNotContains(const AHaystack, ANeedle: string;
  const AMessage: string);
begin
  if (Length(ANeedle) = 0) then
    Exit;
  if Pos(ANeedle, AHaystack) > 0 then
    if AMessage <> '' then
      InternalFail(AMessage + ': "' + AHaystack + '" should not contain "' + ANeedle + '"')
    else
      InternalFail('"' + AHaystack + '" should not contain "' + ANeedle + '"');
end;

procedure CheckStartsWith(const AStr, APrefix: string);
begin
  if not StrStartsWith(AStr, APrefix) then
    InternalFail('"' + AStr + '" does not start with "' + APrefix + '"');
end;

procedure CheckStartsWith(const AStr, APrefix: string;
  const AMessage: string);
begin
  if not StrStartsWith(AStr, APrefix) then
    if AMessage <> '' then
      InternalFail(AMessage + ': "' + AStr + '" does not start with "' + APrefix + '"')
    else
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

procedure CheckEndsWith(const AStr, ASuffix: string;
  const AMessage: string);
var
  LLen: NativeInt;
begin
  LLen := Length(ASuffix);
  if LLen = 0 then
    Exit;
  if (Length(AStr) < LLen) or
     (Copy(AStr, Length(AStr) - LLen + 1, LLen) <> ASuffix) then
    if AMessage <> '' then
      InternalFail(AMessage + ': "' + AStr + '" does not end with "' + ASuffix + '"')
    else
      InternalFail('"' + AStr + '" does not end with "' + ASuffix + '"');
end;

procedure CheckSame(const AExpected, AActual: Pointer; const AMessage: string);
begin
  if AExpected <> AActual then
    FailWithDefault(AMessage,
      'Expected $' + IntToHex(NativeUInt(AExpected), 16) +
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

procedure CheckInRange(const AValue, ALow, AHigh: Int64;
  const AMessage: string);
begin
  if ALow > AHigh then
    InternalFail('CheckInRange: ALow (' + IntToStr(ALow) +
      ') > AHigh (' + IntToStr(AHigh) + ')');
  if (AValue < ALow) or (AValue > AHigh) then
    if AMessage <> '' then
      InternalFail(AMessage + ': ' + IntToStr(AValue) + ' not in range [' +
        IntToStr(ALow) + '..' + IntToStr(AHigh) + ']')
    else
      InternalFail(IntToStr(AValue) + ' not in range [' +
        IntToStr(ALow) + '..' + IntToStr(AHigh) + ']');
end;

procedure CheckGreaterThan(const AValue, AThreshold: Int64);
begin
  if AValue <= AThreshold then
    InternalFail('Expected ' + IntToStr(AValue) + ' > ' +
      IntToStr(AThreshold));
end;

procedure CheckGreaterThan(const AValue, AThreshold: Int64;
  const AMessage: string);
begin
  if AValue <= AThreshold then
    if AMessage <> '' then
      InternalFail(AMessage + ': Expected ' + IntToStr(AValue) + ' > ' +
        IntToStr(AThreshold))
    else
      InternalFail('Expected ' + IntToStr(AValue) + ' > ' +
        IntToStr(AThreshold));
end;

procedure CheckLessThan(const AValue, AThreshold: Int64);
begin
  if AValue >= AThreshold then
    InternalFail('Expected ' + IntToStr(AValue) + ' < ' +
      IntToStr(AThreshold));
end;

procedure CheckLessThan(const AValue, AThreshold: Int64;
  const AMessage: string);
begin
  if AValue >= AThreshold then
    if AMessage <> '' then
      InternalFail(AMessage + ': Expected ' + IntToStr(AValue) + ' < ' +
        IntToStr(AThreshold))
    else
      InternalFail('Expected ' + IntToStr(AValue) + ' < ' +
        IntToStr(AThreshold));
end;

procedure CheckGreaterOrEqual(const AValue, AThreshold: Int64);
begin
  if AValue < AThreshold then
    InternalFail('Expected ' + IntToStr(AValue) + ' >= ' +
      IntToStr(AThreshold));
end;

procedure CheckGreaterOrEqual(const AValue, AThreshold: Int64;
  const AMessage: string);
begin
  if AValue < AThreshold then
    if AMessage <> '' then
      InternalFail(AMessage + ': Expected ' + IntToStr(AValue) + ' >= ' +
        IntToStr(AThreshold))
    else
      InternalFail('Expected ' + IntToStr(AValue) + ' >= ' +
        IntToStr(AThreshold));
end;

procedure CheckLessOrEqual(const AValue, AThreshold: Int64);
begin
  if AValue > AThreshold then
    InternalFail('Expected ' + IntToStr(AValue) + ' <= ' +
      IntToStr(AThreshold));
end;

procedure CheckLessOrEqual(const AValue, AThreshold: Int64;
  const AMessage: string);
begin
  if AValue > AThreshold then
    if AMessage <> '' then
      InternalFail(AMessage + ': Expected ' + IntToStr(AValue) + ' <= ' +
        IntToStr(AThreshold))
    else
      InternalFail('Expected ' + IntToStr(AValue) + ' <= ' +
        IntToStr(AThreshold));
end;

{ ── Double comparison operators ────────────────────────────────────────────── }

procedure CheckGreaterThanD(const AValue, AThreshold: Double;
  const AEpsilon: Double);
begin
  if IsNan(AValue) or IsNan(AThreshold) then
    InternalFail('Expected ' + FloatToStr(AValue) + ' > ' +
      FloatToStr(AThreshold) + ' (NaN)');
  if AValue <= AThreshold then
    if Abs(AValue - AThreshold) <= AEpsilon then
      InternalFail('Expected ' + FloatToStr(AValue) + ' > ' +
        FloatToStr(AThreshold) + ' (within epsilon ' + FloatToStr(AEpsilon) + ')')
    else
      InternalFail('Expected ' + FloatToStr(AValue) + ' > ' +
        FloatToStr(AThreshold));
end;

procedure CheckLessThanD(const AValue, AThreshold: Double;
  const AEpsilon: Double);
begin
  if IsNan(AValue) or IsNan(AThreshold) then
    InternalFail('Expected ' + FloatToStr(AValue) + ' < ' +
      FloatToStr(AThreshold) + ' (NaN)');
  if AValue >= AThreshold then
    if Abs(AValue - AThreshold) <= AEpsilon then
      InternalFail('Expected ' + FloatToStr(AValue) + ' < ' +
        FloatToStr(AThreshold) + ' (within epsilon ' + FloatToStr(AEpsilon) + ')')
    else
      InternalFail('Expected ' + FloatToStr(AValue) + ' < ' +
        FloatToStr(AThreshold));
end;

procedure CheckGreaterOrEqualD(const AValue, AThreshold: Double;
  const AEpsilon: Double);
begin
  if IsNan(AValue) or IsNan(AThreshold) then
    InternalFail('Expected ' + FloatToStr(AValue) + ' >= ' +
      FloatToStr(AThreshold) + ' (NaN)');
  if AValue < AThreshold then
    if Abs(AValue - AThreshold) <= AEpsilon then
      Exit { within epsilon of equal — pass }
    else
      InternalFail('Expected ' + FloatToStr(AValue) + ' >= ' +
        FloatToStr(AThreshold));
end;

procedure CheckLessOrEqualD(const AValue, AThreshold: Double;
  const AEpsilon: Double);
begin
  if IsNan(AValue) or IsNan(AThreshold) then
    InternalFail('Expected ' + FloatToStr(AValue) + ' <= ' +
      FloatToStr(AThreshold) + ' (NaN)');
  if AValue > AThreshold then
    if Abs(AValue - AThreshold) <= AEpsilon then
      Exit { within epsilon of equal — pass }
    else
      InternalFail('Expected ' + FloatToStr(AValue) + ' <= ' +
        FloatToStr(AThreshold));
end;

procedure CheckInRangeD(const AValue, ALow, AHigh: Double;
  const AEpsilon: Double);
begin
  if IsNan(AValue) or IsNan(ALow) or IsNan(AHigh) then
    InternalFail(FloatToStr(AValue) + ' not in range [' +
      FloatToStr(ALow) + '..' + FloatToStr(AHigh) + '] (NaN)');
  if ALow > AHigh then
    InternalFail('CheckInRangeD: ALow (' + FloatToStr(ALow) +
      ') > AHigh (' + FloatToStr(AHigh) + ')');
  if (AValue < ALow) and (Abs(AValue - ALow) > AEpsilon) then
    InternalFail(FloatToStr(AValue) + ' not in range [' +
      FloatToStr(ALow) + '..' + FloatToStr(AHigh) + '] (within epsilon ' +
      FloatToStr(AEpsilon) + ')');
  if (AValue > AHigh) and (Abs(AValue - AHigh) > AEpsilon) then
    InternalFail(FloatToStr(AValue) + ' not in range [' +
      FloatToStr(ALow) + '..' + FloatToStr(AHigh) + '] (within epsilon ' +
      FloatToStr(AEpsilon) + ')');
end;

procedure CheckInRangeD(const AValue, ALow, AHigh: Double;
  const AEpsilon: Double; const AMessage: string);
begin
  if IsNan(AValue) or IsNan(ALow) or IsNan(AHigh) then
    InternalFail(FloatToStr(AValue) + ' not in range [' +
      FloatToStr(ALow) + '..' + FloatToStr(AHigh) + '] (NaN)');
  if ALow > AHigh then
    InternalFail('CheckInRangeD: ALow (' + FloatToStr(ALow) +
      ') > AHigh (' + FloatToStr(AHigh) + ')');
  if (AValue < ALow) and (Abs(AValue - ALow) > AEpsilon) then
    if AMessage <> '' then
      InternalFail(AMessage + ': ' + FloatToStr(AValue) + ' not in range [' +
        FloatToStr(ALow) + '..' + FloatToStr(AHigh) + ']')
    else
      InternalFail(FloatToStr(AValue) + ' not in range [' +
        FloatToStr(ALow) + '..' + FloatToStr(AHigh) + ']');
  if (AValue > AHigh) and (Abs(AValue - AHigh) > AEpsilon) then
    if AMessage <> '' then
      InternalFail(AMessage + ': ' + FloatToStr(AValue) + ' not in range [' +
        FloatToStr(ALow) + '..' + FloatToStr(AHigh) + ']')
    else
      InternalFail(FloatToStr(AValue) + ' not in range [' +
        FloatToStr(ALow) + '..' + FloatToStr(AHigh) + ']');
end;

{ ── String prefix/suffix negation ──────────────────────────────────────────── }

procedure CheckContainsCI(const AHaystack, ANeedle: string);
begin
  if Length(ANeedle) = 0 then
    Exit;
  if Pos(LowerCase(ANeedle), LowerCase(AHaystack)) = 0 then
    InternalFail('"' + AHaystack + '" does not contain (ci) "' + ANeedle + '"');
end;

procedure CheckContainsCI(const AHaystack, ANeedle: string;
  const AMessage: string);
begin
  if Length(ANeedle) = 0 then
    Exit;
  if Pos(LowerCase(ANeedle), LowerCase(AHaystack)) = 0 then
    if AMessage <> '' then
      InternalFail(AMessage + ': "' + AHaystack + '" does not contain (ci) "' + ANeedle + '"')
    else
      InternalFail('"' + AHaystack + '" does not contain (ci) "' + ANeedle + '"');
end;

procedure CheckNotContainsCI(const AHaystack, ANeedle: string);
begin
  if Length(ANeedle) = 0 then
    Exit;
  if Pos(LowerCase(ANeedle), LowerCase(AHaystack)) > 0 then
    InternalFail('"' + AHaystack + '" should not contain (ci) "' + ANeedle + '"');
end;

procedure CheckNotContainsCI(const AHaystack, ANeedle: string;
  const AMessage: string);
begin
  if Length(ANeedle) = 0 then
    Exit;
  if Pos(LowerCase(ANeedle), LowerCase(AHaystack)) > 0 then
    if AMessage <> '' then
      InternalFail(AMessage + ': "' + AHaystack + '" should not contain (ci) "' + ANeedle + '"')
    else
      InternalFail('"' + AHaystack + '" should not contain (ci) "' + ANeedle + '"');
end;

procedure CheckStartsWithCI(const AStr, APrefix: string);
begin
  if (Length(AStr) < Length(APrefix)) or
     (LowerCase(Copy(AStr, 1, Length(APrefix))) <> LowerCase(APrefix)) then
    InternalFail('"' + AStr + '" does not start with (ci) "' + APrefix + '"');
end;

procedure CheckStartsWithCI(const AStr, APrefix: string;
  const AMessage: string);
begin
  if (Length(AStr) < Length(APrefix)) or
     (LowerCase(Copy(AStr, 1, Length(APrefix))) <> LowerCase(APrefix)) then
    if AMessage <> '' then
      InternalFail(AMessage + ': "' + AStr + '" does not start with (ci) "' + APrefix + '"')
    else
      InternalFail('"' + AStr + '" does not start with (ci) "' + APrefix + '"');
end;

procedure CheckEndsWithCI(const AStr, ASuffix: string);
begin
  if Length(ASuffix) = 0 then
    Exit;
  if (Length(AStr) < Length(ASuffix)) or
     (LowerCase(Copy(AStr, Length(AStr) - Length(ASuffix) + 1,
      Length(ASuffix))) <> LowerCase(ASuffix)) then
    InternalFail('"' + AStr + '" does not end with (ci) "' + ASuffix + '"');
end;

procedure CheckEndsWithCI(const AStr, ASuffix: string;
  const AMessage: string);
begin
  if Length(ASuffix) = 0 then
    Exit;
  if (Length(AStr) < Length(ASuffix)) or
     (LowerCase(Copy(AStr, Length(AStr) - Length(ASuffix) + 1,
      Length(ASuffix))) <> LowerCase(ASuffix)) then
    if AMessage <> '' then
      InternalFail(AMessage + ': "' + AStr + '" does not end with (ci) "' + ASuffix + '"')
    else
      InternalFail('"' + AStr + '" does not end with (ci) "' + ASuffix + '"');
end;

procedure CheckNotStartsWith(const AStr, APrefix: string);
begin
  if Length(APrefix) = 0 then
    Exit; { empty prefix matches everything — consistent with CheckStartsWith }
  if StrStartsWith(AStr, APrefix) then
    InternalFail('"' + AStr + '" should not start with "' + APrefix + '"');
end;

procedure CheckNotStartsWith(const AStr, APrefix: string;
  const AMessage: string);
begin
  if Length(APrefix) = 0 then
    Exit;
  if StrStartsWith(AStr, APrefix) then
    if AMessage <> '' then
      InternalFail(AMessage + ': "' + AStr + '" should not start with "' + APrefix + '"')
    else
      InternalFail('"' + AStr + '" should not start with "' + APrefix + '"');
end;

procedure CheckNotEndsWith(const AStr, ASuffix: string);
begin
  if Length(ASuffix) = 0 then
    Exit; { empty suffix matches everything — consistent with CheckEndsWith }
  if (Length(AStr) >= Length(ASuffix)) and
     (Copy(AStr, Length(AStr) - Length(ASuffix) + 1, Length(ASuffix)) = ASuffix) then
    InternalFail('"' + AStr + '" should not end with "' + ASuffix + '"');
end;

procedure CheckNotEndsWith(const AStr, ASuffix: string;
  const AMessage: string);
begin
  if Length(ASuffix) = 0 then
    Exit;
  if (Length(AStr) >= Length(ASuffix)) and
     (Copy(AStr, Length(AStr) - Length(ASuffix) + 1, Length(ASuffix)) = ASuffix) then
    if AMessage <> '' then
      InternalFail(AMessage + ': "' + AStr + '" should not end with "' + ASuffix + '"')
    else
      InternalFail('"' + AStr + '" should not end with "' + ASuffix + '"');
end;

procedure CheckLength(const AExpected, AActual: NativeInt);
begin
  if AExpected <> AActual then
    InternalFail('Expected length ' + IntToStr(AExpected) +
      ' but got ' + IntToStr(AActual));
end;

procedure CheckLength(const AExpected, AActual: NativeInt;
  const AMessage: string);
begin
  if AExpected <> AActual then
    if AMessage <> '' then
      InternalFail(AMessage + ': Expected length ' + IntToStr(AExpected) +
        ' but got ' + IntToStr(AActual))
    else
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

{ ── Snapshot Testing ──────────────────────────────────────────────────────── }

function ReadFileContents(const APath: string; out AContents: string): Boolean;
begin
  try
    AContents := ReadFileText(APath);
    Result := AContents <> '';
  except
    on E: Exception do
    begin
      AContents := '';
      Result := False;
    end;
  end;
end;

procedure WriteFileContents(const APath, AContents: string);
begin
  WriteFileText(APath, AContents);
end;

procedure CheckSnapshot(const AActual: string;
  const ASnapshotDir, ASnapshotName: string);
var
  LPath, LExisting, LUpdateEnv: string;
  LShouldUpdate: Boolean;
begin
  LPath := ASnapshotDir + DirectorySeparator + ASnapshotName;
  LShouldUpdate := platform_env_get_str('NEXTPAS_UPDATE_SNAPSHOTS') = '1';
  if ReadFileContents(LPath, LExisting) then
  begin
    if LShouldUpdate then
    begin
      WriteFileContents(LPath, AActual);
      Exit;
    end;
    if AActual <> LExisting then
    begin
      { Show first difference for debugging }
      InternalFail('Snapshot mismatch: ' + LPath +
        ' (set NEXTPAS_UPDATE_SNAPSHOTS=1 to update)' + #10 +
        StringDiff(LExisting, AActual));
    end;
  end
  else
  begin
    { First run — create snapshot directory and file }
    {$I-}
    MkDir(ASnapshotDir);
    {$I+}
    { Ignore MkDir error if directory already exists }
    WriteFileContents(LPath, AActual);
  end;
end;

{ ── Array Comparison (v8.0c) ──────────────────────────────────────────────── }

procedure CheckArrayEqual(const AExpected, AActual: array of Int64);
begin
  CheckArrayEqual(AExpected, AActual, '');
end;

procedure CheckArrayEqual(const AExpected, AActual: array of Int64;
  const AMessage: string);
var
  I, LMin, LDiffIdx: Integer;
  LMsg: string;
begin
  if Length(AExpected) <> Length(AActual) then
  begin
    LMsg := 'Expected array length ' + IntToStr(Length(AExpected)) +
      ' but got ' + IntToStr(Length(AActual));
    if AMessage <> '' then
      LMsg := AMessage + ': ' + LMsg;
    InternalFail(LMsg);
    Exit;
  end;

  LMin := Length(AExpected);
  LDiffIdx := -1;
  for I := 0 to LMin - 1 do
  begin
    if AExpected[I] <> AActual[I] then
    begin
      LDiffIdx := I;
      Break;
    end;
  end;

  if LDiffIdx >= 0 then
  begin
    LMsg := 'Arrays differ at index ' + IntToStr(LDiffIdx) +
      ': expected ' + IntToStr(AExpected[LDiffIdx]) +
      ' but got ' + IntToStr(AActual[LDiffIdx]);
    if AMessage <> '' then
      LMsg := AMessage + ': ' + LMsg;
    InternalFail(LMsg);
  end;
end;

{ ── Interface Nil Checks (v8.0c) ──────────────────────────────────────────── }

procedure CheckIsNil(const AValue: IInterface; const AMessage: string);
begin
  if AValue <> nil then
  begin
    if AMessage <> '' then
      InternalFail(AMessage + ': expected nil interface but got non-nil')
    else
      InternalFail('Expected nil interface but got non-nil');
  end;
end;

procedure CheckIsNotNil(const AValue: IInterface; const AMessage: string);
begin
  if AValue = nil then
  begin
    if AMessage <> '' then
      InternalFail(AMessage + ': expected non-nil interface but got nil')
    else
      InternalFail('Expected non-nil interface but got nil');
  end;
end;

end.
