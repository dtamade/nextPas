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

{ ── Regex Matching ──────────────────────────────────────────────────────────── }

{ Check that AStr matches regex APattern. Uses nextpas.core.regex for matching.
  Fails with pattern/str details on mismatch. }
procedure CheckMatch(const APattern, AStr: string); overload;
procedure CheckMatch(const APattern, AStr: string;
  const AMessage: string); overload;
{ Check that AStr does NOT match regex APattern. }
procedure CheckNotMatch(const APattern, AStr: string); overload;
procedure CheckNotMatch(const APattern, AStr: string;
  const AMessage: string); overload;

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

{ Compare two string arrays element-by-element.
  Reports length mismatch or first differing index with values. }
procedure CheckArrayEqual(const AExpected, AActual: array of string); overload;

{ Compare two string arrays with custom message. }
procedure CheckArrayEqual(const AExpected, AActual: array of string;
  const AMessage: string); overload;

{ ── Array Containment ──────────────────────────────────────────────────────── }

{ Check that AValue exists in AArray. }
procedure CheckArrayContains(const AArray: array of string;
  const AValue: string); overload;
procedure CheckArrayContains(const AArray: array of string;
  const AValue: string; const AMessage: string); overload;
procedure CheckArrayContains(const AArray: array of Int64;
  const AValue: Int64); overload;
procedure CheckArrayContains(const AArray: array of Int64;
  const AValue: Int64; const AMessage: string); overload;
{ Check that AValue exists in a byte array. }
procedure CheckArrayContains(const AArray: array of Byte;
  AValue: Byte); overload;
procedure CheckArrayContains(const AArray: array of Byte;
  AValue: Byte; const AMessage: string); overload;

{ Check that AValue does NOT exist in AArray. }
procedure CheckArrayNotContains(const AArray: array of string;
  const AValue: string); overload;
procedure CheckArrayNotContains(const AArray: array of string;
  const AValue: string; const AMessage: string); overload;
procedure CheckArrayNotContains(const AArray: array of Int64;
  const AValue: Int64); overload;
procedure CheckArrayNotContains(const AArray: array of Int64;
  const AValue: Int64; const AMessage: string); overload;
{ Check that AValue does NOT exist in a byte array. }
procedure CheckArrayNotContains(const AArray: array of Byte;
  AValue: Byte); overload;
procedure CheckArrayNotContains(const AArray: array of Byte;
  AValue: Byte; const AMessage: string); overload;

{ ── Array Sorted Checks ───────────────────────────────────────────────────── }

{ Check that an Int64 array is sorted in ascending order (non-decreasing). }
procedure CheckSorted(const AArray: array of Int64); overload;
procedure CheckSorted(const AArray: array of Int64;
  const AMessage: string); overload;

{ Check that a string array is sorted in ascending order (non-decreasing). }
procedure CheckSorted(const AArray: array of string); overload;
procedure CheckSorted(const AArray: array of string;
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
  nextpas.core.fs,             { ReadFileText/WriteFileText for snapshot I/O }
  nextpas.core.regex;          { RegexIsMatch for CheckMatch }

procedure FailWithDefault(const AMessage, ADefaultMsg: string);
begin
  if AMessage <> '' then
    InternalFail(AMessage)
  else
    InternalFail(ADefaultMsg);
end;

procedure FailPrepend(const AMessage, ADetail: string);
begin
  if AMessage <> '' then
    InternalFail(AMessage + ': ' + ADetail)
  else
    InternalFail(ADetail);
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
  LActualStart: Integer;
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
  LActualStart := Utf8SafeStart(AActual, I - 10);
  LEnd := I + 20;
  if LEnd > Length(AActual) then LEnd := Length(AActual);
  Result := Result +
    '  actual:   ...' + Copy(AActual, LActualStart,
      LEnd - LActualStart + 1) + '...' + #10 +
    '  (lengths: ' + IntToStr(Length(AExpected)) + ' vs ' + IntToStr(Length(AActual)) + ')';
end;

{ 3-arg overloads: direct check, prepend AMessage on failure.
  2-arg versions delegate to these with AMessage=''. }

procedure CheckEqual(const AExpected, AActual: string;
  const AMessage: string);
var
  LDiffPos, LMin, I: Integer;
begin
  if AExpected <> AActual then
  begin
    if (Length(AExpected) > 40) or (Length(AActual) > 40) or
       (Pos(#10, AExpected) > 0) or (Pos(#10, AActual) > 0) then
      FailPrepend(AMessage, StringDiff(AExpected, AActual))
    else
    begin
      { Find first differing position for short strings }
      LMin := Length(AExpected);
      if Length(AActual) < LMin then LMin := Length(AActual);
      LDiffPos := 0;
      for I := 1 to LMin do
        if AExpected[I] <> AActual[I] then
        begin
          LDiffPos := I;
          Break;
        end;
      if LDiffPos = 0 then
        LDiffPos := LMin + 1; { difference is purely in length }
      FailPrepend(AMessage,
        'expected: "' + AExpected + '"'#10 +
        '  actual: "' + AActual + '"'#10 +
        '          ' + StringOfChar(' ', LDiffPos - 1) + '^' +
        ' diff at pos ' + IntToStr(LDiffPos));
    end;
  end;
end;

procedure CheckEqual(const AExpected, AActual: string);
begin
  CheckEqual(AExpected, AActual, '');
end;

procedure CheckEqual(const AExpected, AActual: Int64;
  const AMessage: string);
begin
  if AExpected <> AActual then
    FailPrepend(AMessage,
      'expected: ' + IntToStr(AExpected) + #10 +
      '  actual: ' + IntToStr(AActual));
end;

procedure CheckEqual(const AExpected, AActual: Int64);
begin
  CheckEqual(AExpected, AActual, '');
end;

procedure CheckEqual(const AExpected, AActual: Boolean;
  const AMessage: string);
begin
  if AExpected <> AActual then
    FailPrepend(AMessage,
      'expected: ' + BoolToStr(AExpected, 'True', 'False') + #10 +
      '  actual: ' + BoolToStr(AActual, 'True', 'False'));
end;

procedure CheckEqual(const AExpected, AActual: Boolean);
begin
  CheckEqual(AExpected, AActual, '');
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

{ CheckNotEqual: 3-arg first, 2-arg delegates }

procedure CheckNotEqual(const AExpected, AActual: string;
  const AMessage: string);
begin
  if AExpected = AActual then
    FailPrepend(AMessage, 'Expected values to differ but both are "' + AActual + '"');
end;

procedure CheckNotEqual(const AExpected, AActual: string);
begin
  CheckNotEqual(AExpected, AActual, '');
end;

procedure CheckNotEqual(const AExpected, AActual: Int64;
  const AMessage: string);
begin
  if AExpected = AActual then
    FailPrepend(AMessage, 'Expected values to differ but both are ' + IntToStr(AActual));
end;

procedure CheckNotEqual(const AExpected, AActual: Int64);
begin
  CheckNotEqual(AExpected, AActual, '');
end;

procedure CheckNotEqual(const AExpected, AActual: Boolean;
  const AMessage: string);
begin
  if AExpected = AActual then
    FailPrepend(AMessage, 'Expected values to differ but both are ' +
      BoolToStr(AActual, 'True', 'False'));
end;

procedure CheckNotEqual(const AExpected, AActual: Boolean);
begin
  CheckNotEqual(AExpected, AActual, '');
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
    FailPrepend(AMessage,
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
    FailPrepend(AMessage,
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
      FailPrepend(AMessage,
        'Expected ' + FloatToStr(AExpected) +
        ' (rel ' + FloatToStr(ARelEps) + ') but got ' + FloatToStr(AActual));
  end
  else if LAbsDiff > ARelEps * LScale then
    FailPrepend(AMessage,
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
      FailPrepend(AMessage,
        'Expected not near ' + FloatToStr(AExpected) +
        ' (rel ' + FloatToStr(ARelEps) + ') but got ' + FloatToStr(AActual));
  end
  else if LAbsDiff <= ARelEps * LScale then
    FailPrepend(AMessage,
      'Expected not near ' + FloatToStr(AExpected) +
      ' (rel ' + FloatToStr(ARelEps) + ') but got ' + FloatToStr(AActual));
end;

procedure CheckNaN(const AValue: Double; const AMessage: string);
begin
  if not IsNan(AValue) then
    FailPrepend(AMessage,
      'Expected NaN but got ' + FloatToStr(AValue));
end;

procedure CheckNotNaN(const AValue: Double; const AMessage: string);
begin
  if IsNan(AValue) then
    FailPrepend(AMessage, 'Expected non-NaN but got NaN');
end;

{ ── Regex Matching ──────────────────────────────────────────────────────────── }

procedure CheckMatch(const APattern, AStr: string);
begin
  if not RegexIsMatch(APattern, AStr) then
    InternalFail('Expected string to match pattern "' + APattern + '"' +
      #10 + '  actual: "' + AStr + '"');
end;

procedure CheckMatch(const APattern, AStr: string; const AMessage: string);
begin
  if not RegexIsMatch(APattern, AStr) then
    FailPrepend(AMessage, 'Expected string to match pattern "' + APattern + '"' +
      #10 + '  actual: "' + AStr + '"');
end;

procedure CheckNotMatch(const APattern, AStr: string);
begin
  if RegexIsMatch(APattern, AStr) then
    InternalFail('Expected string NOT to match pattern "' + APattern + '"' +
      #10 + '  actual: "' + AStr + '"');
end;

procedure CheckNotMatch(const APattern, AStr: string; const AMessage: string);
begin
  if RegexIsMatch(APattern, AStr) then
    FailPrepend(AMessage, 'Expected string NOT to match pattern "' + APattern + '"' +
      #10 + '  actual: "' + AStr + '"');
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

{ CheckContains: 3-arg first, 2-arg delegates }

procedure CheckContains(const AHaystack, ANeedle: string;
  const AMessage: string);
begin
  if (Length(ANeedle) = 0) then
    Exit;
  if Pos(ANeedle, AHaystack) = 0 then
    FailPrepend(AMessage, '"' + AHaystack + '" does not contain "' + ANeedle + '"');
end;

procedure CheckContains(const AHaystack, ANeedle: string);
begin
  CheckContains(AHaystack, ANeedle, '');
end;

{ CheckNotContains: 3-arg first, 2-arg delegates }

procedure CheckNotContains(const AHaystack, ANeedle: string;
  const AMessage: string);
begin
  if (Length(ANeedle) = 0) then
    Exit;
  if Pos(ANeedle, AHaystack) > 0 then
    FailPrepend(AMessage, '"' + AHaystack + '" should not contain "' + ANeedle + '"');
end;

procedure CheckNotContains(const AHaystack, ANeedle: string);
begin
  CheckNotContains(AHaystack, ANeedle, '');
end;

{ CheckStartsWith: 3-arg first, 2-arg delegates }

procedure CheckStartsWith(const AStr, APrefix: string;
  const AMessage: string);
begin
  if not StrStartsWith(AStr, APrefix) then
    FailPrepend(AMessage, '"' + AStr + '" does not start with "' + APrefix + '"');
end;

procedure CheckStartsWith(const AStr, APrefix: string);
begin
  CheckStartsWith(AStr, APrefix, '');
end;

{ CheckEndsWith: 3-arg first, 2-arg delegates }

procedure CheckEndsWith(const AStr, ASuffix: string;
  const AMessage: string);
begin
  if not StrEndsWith(AStr, ASuffix) then
    FailPrepend(AMessage, '"' + AStr + '" does not end with "' + ASuffix + '"');
end;

procedure CheckEndsWith(const AStr, ASuffix: string);
begin
  CheckEndsWith(AStr, ASuffix, '');
end;

procedure CheckSame(const AExpected, AActual: Pointer; const AMessage: string);
begin
  if AExpected <> AActual then
    FailPrepend(AMessage,
      'Expected $' + IntToHex(NativeUInt(AExpected), 16) +
      ' but got $' + IntToHex(NativeUInt(AActual), 16));
end;

{ CheckInRange: 3-arg first, 2-arg delegates }

procedure CheckInRange(const AValue, ALow, AHigh: Int64;
  const AMessage: string);
begin
  if ALow > AHigh then
    InternalFail('CheckInRange: ALow (' + IntToStr(ALow) +
      ') > AHigh (' + IntToStr(AHigh) + ')');
  if (AValue < ALow) or (AValue > AHigh) then
    FailPrepend(AMessage, IntToStr(AValue) + ' not in range [' +
      IntToStr(ALow) + '..' + IntToStr(AHigh) + ']');
end;

procedure CheckInRange(const AValue, ALow, AHigh: Int64);
begin
  CheckInRange(AValue, ALow, AHigh, '');
end;

{ CheckGreaterThan: 3-arg first, 2-arg delegates }

procedure CheckGreaterThan(const AValue, AThreshold: Int64;
  const AMessage: string);
begin
  if AValue <= AThreshold then
    FailPrepend(AMessage, 'Expected ' + IntToStr(AValue) + ' > ' +
      IntToStr(AThreshold));
end;

procedure CheckGreaterThan(const AValue, AThreshold: Int64);
begin
  CheckGreaterThan(AValue, AThreshold, '');
end;

{ CheckLessThan: 3-arg first, 2-arg delegates }

procedure CheckLessThan(const AValue, AThreshold: Int64;
  const AMessage: string);
begin
  if AValue >= AThreshold then
    FailPrepend(AMessage, 'Expected ' + IntToStr(AValue) + ' < ' +
      IntToStr(AThreshold));
end;

procedure CheckLessThan(const AValue, AThreshold: Int64);
begin
  CheckLessThan(AValue, AThreshold, '');
end;

{ CheckGreaterOrEqual: 3-arg first, 2-arg delegates }

procedure CheckGreaterOrEqual(const AValue, AThreshold: Int64;
  const AMessage: string);
begin
  if AValue < AThreshold then
    FailPrepend(AMessage, 'Expected ' + IntToStr(AValue) + ' >= ' +
      IntToStr(AThreshold));
end;

procedure CheckGreaterOrEqual(const AValue, AThreshold: Int64);
begin
  CheckGreaterOrEqual(AValue, AThreshold, '');
end;

{ CheckLessOrEqual: 3-arg first, 2-arg delegates }

procedure CheckLessOrEqual(const AValue, AThreshold: Int64;
  const AMessage: string);
begin
  if AValue > AThreshold then
    FailPrepend(AMessage, 'Expected ' + IntToStr(AValue) + ' <= ' +
      IntToStr(AThreshold));
end;

procedure CheckLessOrEqual(const AValue, AThreshold: Int64);
begin
  CheckLessOrEqual(AValue, AThreshold, '');
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
        FloatToStr(AThreshold) + ' (eps ' + FloatToStr(AEpsilon) + ')')
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
        FloatToStr(AThreshold) + ' (eps ' + FloatToStr(AEpsilon) + ')')
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

{ CheckInRangeD: 3-arg first, 2-arg delegates }

procedure CheckInRangeD(const AValue, ALow, AHigh: Double;
  const AEpsilon: Double; const AMessage: string);
var
  LMsg: string;
begin
  if IsNan(AValue) or IsNan(ALow) or IsNan(AHigh) then
    InternalFail(FloatToStr(AValue) + ' not in range [' +
      FloatToStr(ALow) + '..' + FloatToStr(AHigh) + '] (NaN)');
  if ALow > AHigh then
    InternalFail('CheckInRangeD: ALow (' + FloatToStr(ALow) +
      ') > AHigh (' + FloatToStr(AHigh) + ')');
  LMsg := FloatToStr(AValue) + ' not in range [' +
    FloatToStr(ALow) + '..' + FloatToStr(AHigh) + '] (eps ' +
    FloatToStr(AEpsilon) + ')';
  if (AValue < ALow) and (Abs(AValue - ALow) > AEpsilon) then
    FailPrepend(AMessage, LMsg);
  if (AValue > AHigh) and (Abs(AValue - AHigh) > AEpsilon) then
    FailPrepend(AMessage, LMsg);
end;

procedure CheckInRangeD(const AValue, ALow, AHigh: Double;
  const AEpsilon: Double);
begin
  CheckInRangeD(AValue, ALow, AHigh, AEpsilon, '');
end;

{ ── String prefix/suffix negation ──────────────────────────────────────────── }

{ CheckContainsCI: 3-arg first, 2-arg delegates }

procedure CheckContainsCI(const AHaystack, ANeedle: string;
  const AMessage: string);
begin
  if Length(ANeedle) = 0 then
    Exit;
  if Pos(LowerCase(ANeedle), LowerCase(AHaystack)) = 0 then
    FailPrepend(AMessage, '"' + AHaystack + '" does not contain (ci) "' + ANeedle + '"');
end;

procedure CheckContainsCI(const AHaystack, ANeedle: string);
begin
  CheckContainsCI(AHaystack, ANeedle, '');
end;

{ CheckNotContainsCI: 3-arg first, 2-arg delegates }

procedure CheckNotContainsCI(const AHaystack, ANeedle: string;
  const AMessage: string);
begin
  if Length(ANeedle) = 0 then
    Exit;
  if Pos(LowerCase(ANeedle), LowerCase(AHaystack)) > 0 then
    FailPrepend(AMessage, '"' + AHaystack + '" should not contain (ci) "' + ANeedle + '"');
end;

procedure CheckNotContainsCI(const AHaystack, ANeedle: string);
begin
  CheckNotContainsCI(AHaystack, ANeedle, '');
end;

{ CheckStartsWithCI: 3-arg first, 2-arg delegates }

procedure CheckStartsWithCI(const AStr, APrefix: string;
  const AMessage: string);
begin
  if not StrStartsWith(LowerCase(AStr), LowerCase(APrefix)) then
    FailPrepend(AMessage, '"' + AStr + '" does not start with (ci) "' + APrefix + '"');
end;

procedure CheckStartsWithCI(const AStr, APrefix: string);
begin
  CheckStartsWithCI(AStr, APrefix, '');
end;

{ CheckEndsWithCI: 3-arg first, 2-arg delegates }

procedure CheckEndsWithCI(const AStr, ASuffix: string;
  const AMessage: string);
begin
  if not StrEndsWith(LowerCase(AStr), LowerCase(ASuffix)) then
    FailPrepend(AMessage, '"' + AStr + '" does not end with (ci) "' + ASuffix + '"');
end;

procedure CheckEndsWithCI(const AStr, ASuffix: string);
begin
  CheckEndsWithCI(AStr, ASuffix, '');
end;

{ CheckNotStartsWith: 3-arg first, 2-arg delegates }

procedure CheckNotStartsWith(const AStr, APrefix: string;
  const AMessage: string);
begin
  if Length(APrefix) = 0 then
    Exit;
  if StrStartsWith(AStr, APrefix) then
    FailPrepend(AMessage, '"' + AStr + '" should not start with "' + APrefix + '"');
end;

procedure CheckNotStartsWith(const AStr, APrefix: string);
begin
  CheckNotStartsWith(AStr, APrefix, '');
end;

{ CheckNotEndsWith: 3-arg first, 2-arg delegates }

procedure CheckNotEndsWith(const AStr, ASuffix: string;
  const AMessage: string);
begin
  if Length(ASuffix) = 0 then
    Exit;
  if StrEndsWith(AStr, ASuffix) then
    FailPrepend(AMessage, '"' + AStr + '" should not end with "' + ASuffix + '"');
end;

procedure CheckNotEndsWith(const AStr, ASuffix: string);
begin
  CheckNotEndsWith(AStr, ASuffix, '');
end;

{ CheckLength: 3-arg first, 2-arg delegates }

procedure CheckLength(const AExpected, AActual: NativeInt;
  const AMessage: string);
begin
  if AExpected <> AActual then
    FailPrepend(AMessage, 'Expected length ' + IntToStr(AExpected) +
      ' but got ' + IntToStr(AActual));
end;

procedure CheckLength(const AExpected, AActual: NativeInt);
begin
  CheckLength(AExpected, AActual, '');
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
      FailPrepend(AMessage, 'Unexpected exception: ' + E.ClassName + ': ' + E.Message);
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
  Result := FileExists(APath);
  if not Result then
  begin
    AContents := '';
    Exit;
  end;
  try
    AContents := ReadFileText(APath);
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
    FailPrepend(AMessage, LMsg);
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
    FailPrepend(AMessage, LMsg);
  end;
end;

{ ── Interface Nil Checks (v8.0c) ──────────────────────────────────────────── }

procedure CheckIsNil(const AValue: IInterface; const AMessage: string);
begin
  if AValue <> nil then
    FailPrepend(AMessage, 'Expected nil interface but got non-nil');
end;

procedure CheckIsNotNil(const AValue: IInterface; const AMessage: string);
begin
  if AValue = nil then
    FailPrepend(AMessage, 'Expected non-nil interface but got nil');
end;

{ ── String Array Comparison ────────────────────────────────────────────────── }

procedure CheckArrayEqual(const AExpected, AActual: array of string);
begin
  CheckArrayEqual(AExpected, AActual, '');
end;

procedure CheckArrayEqual(const AExpected, AActual: array of string;
  const AMessage: string);
var
  I, LMin, LDiffIdx: Integer;
  LMsg: string;
begin
  if Length(AExpected) <> Length(AActual) then
  begin
    LMsg := 'Expected array length ' + IntToStr(Length(AExpected)) +
      ' but got ' + IntToStr(Length(AActual));
    FailPrepend(AMessage, LMsg);
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
    LMsg := 'Arrays differ at index ' + IntToStr(LDiffIdx) + ':'#10 +
      '  expected: "' + AExpected[LDiffIdx] + '"'#10 +
      '    actual: "' + AActual[LDiffIdx] + '"';
    FailPrepend(AMessage, LMsg);
  end;
end;

{ ── Array Containment ──────────────────────────────────────────────────────── }

procedure CheckArrayContains(const AArray: array of string;
  const AValue: string);
begin
  CheckArrayContains(AArray, AValue, '');
end;

procedure CheckArrayContains(const AArray: array of string;
  const AValue: string; const AMessage: string);
var
  I: Integer;
  LList: string;
begin
  for I := 0 to High(AArray) do
    if AArray[I] = AValue then
      Exit;
  { Not found — build list for error message }
  LList := '';
  for I := 0 to High(AArray) do
  begin
    if I > 0 then LList := LList + ', ';
    LList := LList + '"' + AArray[I] + '"';
  end;
  FailPrepend(AMessage, 'Expected array to contain "' + AValue +
    '" but it contains [' + LList + ']');
end;

procedure CheckArrayContains(const AArray: array of Int64;
  const AValue: Int64);
begin
  CheckArrayContains(AArray, AValue, '');
end;

procedure CheckArrayContains(const AArray: array of Int64;
  const AValue: Int64; const AMessage: string);
var
  I: Integer;
  LList: string;
begin
  for I := 0 to High(AArray) do
    if AArray[I] = AValue then
      Exit;
  { Not found — build list for error message }
  LList := '';
  for I := 0 to High(AArray) do
  begin
    if I > 0 then LList := LList + ', ';
    LList := LList + IntToStr(AArray[I]);
  end;
  FailPrepend(AMessage, 'Expected array to contain ' + IntToStr(AValue) +
    ' but it contains [' + LList + ']');
end;

procedure CheckArrayNotContains(const AArray: array of string;
  const AValue: string);
begin
  CheckArrayNotContains(AArray, AValue, '');
end;

procedure CheckArrayNotContains(const AArray: array of string;
  const AValue: string; const AMessage: string);
var
  I: Integer;
begin
  for I := 0 to High(AArray) do
    if AArray[I] = AValue then
      FailPrepend(AMessage, 'Expected array NOT to contain "' + AValue +
        '" but found at index ' + IntToStr(I));
end;

procedure CheckArrayNotContains(const AArray: array of Int64;
  const AValue: Int64);
begin
  CheckArrayNotContains(AArray, AValue, '');
end;

procedure CheckArrayNotContains(const AArray: array of Int64;
  const AValue: Int64; const AMessage: string);
var
  I: Integer;
begin
  for I := 0 to High(AArray) do
    if AArray[I] = AValue then
      FailPrepend(AMessage, 'Expected array NOT to contain ' + IntToStr(AValue) +
        ' but found at index ' + IntToStr(I));
end;

{ CheckArrayContains for TBytes }

procedure CheckArrayContains(const AArray: array of Byte;
  AValue: Byte; const AMessage: string);
var
  I: Integer;
begin
  for I := 0 to High(AArray) do
    if AArray[I] = AValue then
      Exit;
  FailPrepend(AMessage, 'Expected bytes to contain $' + IntToHex(AValue, 2) +
    ' but not found (length ' + IntToStr(Length(AArray)) + ')');
end;

procedure CheckArrayContains(const AArray: array of Byte;
  AValue: Byte);
begin
  CheckArrayContains(AArray, AValue, '');
end;

{ CheckArrayNotContains for TBytes }

procedure CheckArrayNotContains(const AArray: array of Byte;
  AValue: Byte; const AMessage: string);
var
  I: Integer;
begin
  for I := 0 to High(AArray) do
    if AArray[I] = AValue then
      FailPrepend(AMessage, 'Expected bytes NOT to contain $' + IntToHex(AValue, 2) +
        ' but found at index ' + IntToStr(I));
end;

procedure CheckArrayNotContains(const AArray: array of Byte;
  AValue: Byte);
begin
  CheckArrayNotContains(AArray, AValue, '');
end;

{ ── Array Sorted Checks ───────────────────────────────────────────────────── }

procedure CheckSorted(const AArray: array of Int64);
begin
  CheckSorted(AArray, '');
end;

procedure CheckSorted(const AArray: array of Int64;
  const AMessage: string);
var
  I: Integer;
begin
  for I := 1 to High(AArray) do
    if AArray[I] < AArray[I - 1] then
      FailPrepend(AMessage,
        'Array not sorted at index ' + IntToStr(I) +
        ': ' + IntToStr(AArray[I - 1]) + ' > ' + IntToStr(AArray[I]));
end;

procedure CheckSorted(const AArray: array of string);
begin
  CheckSorted(AArray, '');
end;

procedure CheckSorted(const AArray: array of string;
  const AMessage: string);
var
  I: Integer;
begin
  for I := 1 to High(AArray) do
    if AArray[I] < AArray[I - 1] then
      FailPrepend(AMessage,
        'Array not sorted at index ' + IntToStr(I) +
        ': "' + AArray[I - 1] + '" > "' + AArray[I] + '"');
end;

end.
