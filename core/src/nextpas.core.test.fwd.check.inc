{ ── Forward to test.check ─────────────────────────────────────────────────── }

procedure Check(ACondition: Boolean; const AMessage: string);
begin nextpas.core.test.check.Check(ACondition, AMessage); end;

procedure CheckEqual(const AExpected, AActual: string);
begin nextpas.core.test.check.CheckEqual(AExpected, AActual); end;

procedure CheckEqual(const AExpected, AActual: Int64);
begin nextpas.core.test.check.CheckEqual(AExpected, AActual); end;

procedure CheckEqual(const AExpected, AActual: Boolean);
begin nextpas.core.test.check.CheckEqual(AExpected, AActual); end;

procedure CheckEqual(const AExpected, AActual: Pointer);
begin nextpas.core.test.check.CheckEqual(AExpected, AActual); end;

procedure CheckEqual(const AExpected, AActual: UInt64);
begin nextpas.core.test.check.CheckEqual(AExpected, AActual); end;

procedure CheckEqual(const AExpected, AActual: Double;
  AEpsilon: Double);
begin nextpas.core.test.check.CheckEqual(AExpected, AActual, AEpsilon); end;

procedure CheckEqual(const AExpected, AActual: string;
  const AMessage: string);
begin nextpas.core.test.check.CheckEqual(AExpected, AActual, AMessage); end;

procedure CheckEqual(const AExpected, AActual: Int64;
  const AMessage: string);
begin nextpas.core.test.check.CheckEqual(AExpected, AActual, AMessage); end;

procedure CheckEqual(const AExpected, AActual: Boolean;
  const AMessage: string);
begin nextpas.core.test.check.CheckEqual(AExpected, AActual, AMessage); end;

procedure CheckNotEqual(const AExpected, AActual: string);
begin nextpas.core.test.check.CheckNotEqual(AExpected, AActual); end;

procedure CheckNotEqual(const AExpected, AActual: string;
  const AMessage: string);
begin nextpas.core.test.check.CheckNotEqual(AExpected, AActual, AMessage); end;

procedure CheckNotEqual(const AExpected, AActual: Int64);
begin nextpas.core.test.check.CheckNotEqual(AExpected, AActual); end;

procedure CheckNotEqual(const AExpected, AActual: Int64;
  const AMessage: string);
begin nextpas.core.test.check.CheckNotEqual(AExpected, AActual, AMessage); end;

procedure CheckNotEqual(const AExpected, AActual: Boolean);
begin nextpas.core.test.check.CheckNotEqual(AExpected, AActual); end;

procedure CheckNotEqual(const AExpected, AActual: Boolean;
  const AMessage: string);
begin nextpas.core.test.check.CheckNotEqual(AExpected, AActual, AMessage); end;

procedure CheckNotEqual(const AExpected, AActual: Pointer);
begin nextpas.core.test.check.CheckNotEqual(AExpected, AActual); end;

procedure CheckNotEqual(const AExpected, AActual: UInt64);
begin nextpas.core.test.check.CheckNotEqual(AExpected, AActual); end;

procedure CheckNotEqual(const AExpected, AActual: Double;
  AEpsilon: Double);
begin nextpas.core.test.check.CheckNotEqual(AExpected, AActual, AEpsilon); end;

procedure CheckEqual(const AExpected, AActual: TBytes);
begin nextpas.core.test.check.CheckEqual(AExpected, AActual); end;

procedure CheckNotEqual(const AExpected, AActual: TBytes);
begin nextpas.core.test.check.CheckNotEqual(AExpected, AActual); end;

procedure CheckTrue(AValue: Boolean; const AMessage: string);
begin nextpas.core.test.check.CheckTrue(AValue, AMessage); end;

procedure CheckFalse(AValue: Boolean; const AMessage: string);
begin nextpas.core.test.check.CheckFalse(AValue, AMessage); end;

procedure CheckNil(AValue: Pointer; const AMessage: string);
begin nextpas.core.test.check.CheckNil(AValue, AMessage); end;

procedure CheckNotNil(AValue: Pointer; const AMessage: string);
begin nextpas.core.test.check.CheckNotNil(AValue, AMessage); end;

procedure CheckContains(const AHaystack, ANeedle: string);
begin nextpas.core.test.check.CheckContains(AHaystack, ANeedle); end;

procedure CheckContains(const AHaystack, ANeedle: string;
  const AMessage: string);
begin nextpas.core.test.check.CheckContains(AHaystack, ANeedle, AMessage); end;

procedure CheckNotContains(const AHaystack, ANeedle: string);
begin nextpas.core.test.check.CheckNotContains(AHaystack, ANeedle); end;

procedure CheckNotContains(const AHaystack, ANeedle: string;
  const AMessage: string);
begin nextpas.core.test.check.CheckNotContains(AHaystack, ANeedle, AMessage); end;

procedure CheckStartsWith(const AStr, APrefix: string);
begin nextpas.core.test.check.CheckStartsWith(AStr, APrefix); end;

procedure CheckStartsWith(const AStr, APrefix: string;
  const AMessage: string);
begin nextpas.core.test.check.CheckStartsWith(AStr, APrefix, AMessage); end;

procedure CheckEndsWith(const AStr, ASuffix: string);
begin nextpas.core.test.check.CheckEndsWith(AStr, ASuffix); end;

procedure CheckEndsWith(const AStr, ASuffix: string;
  const AMessage: string);
begin nextpas.core.test.check.CheckEndsWith(AStr, ASuffix, AMessage); end;

procedure CheckSame(const AExpected, AActual: Pointer; const AMessage: string);
begin nextpas.core.test.check.CheckSame(AExpected, AActual, AMessage); end;

procedure CheckInRange(const AValue, ALow, AHigh: Int64);
begin nextpas.core.test.check.CheckInRange(AValue, ALow, AHigh); end;

procedure CheckInRange(const AValue, ALow, AHigh: Int64;
  const AMessage: string);
begin nextpas.core.test.check.CheckInRange(AValue, ALow, AHigh, AMessage); end;

procedure CheckGreaterThan(const AValue, AThreshold: Int64);
begin nextpas.core.test.check.CheckGreaterThan(AValue, AThreshold); end;

procedure CheckGreaterThan(const AValue, AThreshold: Int64;
  const AMessage: string);
begin nextpas.core.test.check.CheckGreaterThan(AValue, AThreshold, AMessage); end;

procedure CheckLessThan(const AValue, AThreshold: Int64);
begin nextpas.core.test.check.CheckLessThan(AValue, AThreshold); end;

procedure CheckLessThan(const AValue, AThreshold: Int64;
  const AMessage: string);
begin nextpas.core.test.check.CheckLessThan(AValue, AThreshold, AMessage); end;

procedure CheckGreaterOrEqual(const AValue, AThreshold: Int64);
begin nextpas.core.test.check.CheckGreaterOrEqual(AValue, AThreshold); end;

procedure CheckGreaterOrEqual(const AValue, AThreshold: Int64;
  const AMessage: string);
begin nextpas.core.test.check.CheckGreaterOrEqual(AValue, AThreshold, AMessage); end;

procedure CheckLessOrEqual(const AValue, AThreshold: Int64);
begin nextpas.core.test.check.CheckLessOrEqual(AValue, AThreshold); end;

procedure CheckLessOrEqual(const AValue, AThreshold: Int64;
  const AMessage: string);
begin nextpas.core.test.check.CheckLessOrEqual(AValue, AThreshold, AMessage); end;

procedure CheckInRangeD(const AValue, ALow, AHigh: Double;
  const AEpsilon: Double);
begin nextpas.core.test.check.CheckInRangeD(AValue, ALow, AHigh, AEpsilon); end;

procedure CheckInRangeD(const AValue, ALow, AHigh: Double;
  const AEpsilon: Double; const AMessage: string);
begin nextpas.core.test.check.CheckInRangeD(AValue, ALow, AHigh, AEpsilon, AMessage); end;

procedure CheckGreaterThanD(const AValue, AThreshold: Double;
  const AEpsilon: Double);
begin nextpas.core.test.check.CheckGreaterThanD(AValue, AThreshold, AEpsilon); end;

procedure CheckLessThanD(const AValue, AThreshold: Double;
  const AEpsilon: Double);
begin nextpas.core.test.check.CheckLessThanD(AValue, AThreshold, AEpsilon); end;

procedure CheckGreaterOrEqualD(const AValue, AThreshold: Double;
  const AEpsilon: Double);
begin nextpas.core.test.check.CheckGreaterOrEqualD(AValue, AThreshold, AEpsilon); end;

procedure CheckLessOrEqualD(const AValue, AThreshold: Double;
  const AEpsilon: Double);
begin nextpas.core.test.check.CheckLessOrEqualD(AValue, AThreshold, AEpsilon); end;

procedure CheckContainsCI(const AHaystack, ANeedle: string);
begin nextpas.core.test.check.CheckContainsCI(AHaystack, ANeedle); end;

procedure CheckContainsCI(const AHaystack, ANeedle: string;
  const AMessage: string);
begin nextpas.core.test.check.CheckContainsCI(AHaystack, ANeedle, AMessage); end;

procedure CheckNotContainsCI(const AHaystack, ANeedle: string);
begin nextpas.core.test.check.CheckNotContainsCI(AHaystack, ANeedle); end;

procedure CheckNotContainsCI(const AHaystack, ANeedle: string;
  const AMessage: string);
begin nextpas.core.test.check.CheckNotContainsCI(AHaystack, ANeedle, AMessage); end;

procedure CheckStartsWithCI(const AStr, APrefix: string);
begin nextpas.core.test.check.CheckStartsWithCI(AStr, APrefix); end;

procedure CheckStartsWithCI(const AStr, APrefix: string;
  const AMessage: string);
begin nextpas.core.test.check.CheckStartsWithCI(AStr, APrefix, AMessage); end;

procedure CheckEndsWithCI(const AStr, ASuffix: string);
begin nextpas.core.test.check.CheckEndsWithCI(AStr, ASuffix); end;

procedure CheckEndsWithCI(const AStr, ASuffix: string;
  const AMessage: string);
begin nextpas.core.test.check.CheckEndsWithCI(AStr, ASuffix, AMessage); end;

procedure CheckNotStartsWith(const AStr, APrefix: string);
begin nextpas.core.test.check.CheckNotStartsWith(AStr, APrefix); end;

procedure CheckNotStartsWith(const AStr, APrefix: string;
  const AMessage: string);
begin nextpas.core.test.check.CheckNotStartsWith(AStr, APrefix, AMessage); end;

procedure CheckNotEndsWith(const AStr, ASuffix: string);
begin nextpas.core.test.check.CheckNotEndsWith(AStr, ASuffix); end;

procedure CheckNotEndsWith(const AStr, ASuffix: string;
  const AMessage: string);
begin nextpas.core.test.check.CheckNotEndsWith(AStr, ASuffix, AMessage); end;

procedure CheckLength(const AExpected, AActual: NativeInt);
begin nextpas.core.test.check.CheckLength(AExpected, AActual); end;

procedure CheckLength(const AExpected, AActual: NativeInt;
  const AMessage: string);
begin nextpas.core.test.check.CheckLength(AExpected, AActual, AMessage); end;

procedure CheckRaises(AExceptionClass: ExceptClass; AProc: TTestProc;
  const AMessage: string);
begin nextpas.core.test.check.CheckRaises(AExceptionClass, AProc, AMessage); end;

procedure CheckNoRaise(AProc: TTestProc; const AMessage: string);
begin nextpas.core.test.check.CheckNoRaise(AProc, AMessage); end;

procedure CheckNear(const AExpected, AActual: Double;
  const AEpsilon: Double; const AMessage: string);
begin nextpas.core.test.check.CheckNear(AExpected, AActual, AEpsilon, AMessage); end;

procedure CheckNotNear(const AExpected, AActual: Double;
  const AEpsilon: Double; const AMessage: string);
begin nextpas.core.test.check.CheckNotNear(AExpected, AActual, AEpsilon, AMessage); end;

procedure CheckNearRel(const AExpected, AActual: Double;
  const ARelEps: Double; const AMessage: string);
begin nextpas.core.test.check.CheckNearRel(AExpected, AActual, ARelEps, AMessage); end;

procedure CheckNotNearRel(const AExpected, AActual: Double;
  const ARelEps: Double; const AMessage: string);
begin nextpas.core.test.check.CheckNotNearRel(AExpected, AActual, ARelEps, AMessage); end;

procedure CheckNaN(const AValue: Double; const AMessage: string);
begin nextpas.core.test.check.CheckNaN(AValue, AMessage); end;

procedure CheckNotNaN(const AValue: Double; const AMessage: string);
begin nextpas.core.test.check.CheckNotNaN(AValue, AMessage); end;

procedure CheckMatch(const APattern, AStr: string);
begin nextpas.core.test.check.CheckMatch(APattern, AStr); end;

procedure CheckMatch(const APattern, AStr: string;
  const AMessage: string);
begin nextpas.core.test.check.CheckMatch(APattern, AStr, AMessage); end;

procedure CheckNotMatch(const APattern, AStr: string);
begin nextpas.core.test.check.CheckNotMatch(APattern, AStr); end;

procedure CheckNotMatch(const APattern, AStr: string;
  const AMessage: string);
begin nextpas.core.test.check.CheckNotMatch(APattern, AStr, AMessage); end;

procedure Fail(const AMessage: string);
begin nextpas.core.test.check.Fail(AMessage); end;

procedure FailUnexpected(const E: Exception);
begin nextpas.core.test.check.FailUnexpected(E); end;

procedure SoftFail(const AMessage: string);
begin nextpas.core.test.check.SoftFail(AMessage); end;

procedure SoftCheckTrue(ACondition: Boolean; const AMessage: string);
begin nextpas.core.test.check.SoftCheckTrue(ACondition, AMessage); end;

procedure SoftCheckFalse(ACondition: Boolean; const AMessage: string);
begin nextpas.core.test.check.SoftCheckFalse(ACondition, AMessage); end;

procedure SoftCheckEqual(const AExpected, AActual: Int64;
  const AMessage: string);
begin nextpas.core.test.check.SoftCheckEqual(AExpected, AActual, AMessage); end;

procedure SoftCheckEqual(const AExpected, AActual: string;
  const AMessage: string);
begin nextpas.core.test.check.SoftCheckEqual(AExpected, AActual, AMessage); end;

procedure SoftCheckContains(const AHaystack, ANeedle: string;
  const AMessage: string);
begin nextpas.core.test.check.SoftCheckContains(AHaystack, ANeedle, AMessage); end;

procedure Skip(const AReason: string);
begin nextpas.core.test.check.Skip(AReason); end;

procedure SleepMs(AMilliseconds: Integer);
begin nextpas.core.test.base.SleepMs(AMilliseconds); end;

procedure CheckSnapshot(const AActual: string;
  const ASnapshotDir, ASnapshotName: string);
begin nextpas.core.test.check.CheckSnapshot(AActual, ASnapshotDir, ASnapshotName); end;

function ReadFileContents(const APath: string; out AContents: string;
  out AStatus: TReadFileStatus): Boolean;
begin Result := nextpas.core.test.check.ReadFileContents(APath, AContents, AStatus); end;
function ReadFileContents(const APath: string; out AContents: string): Boolean;
var LStatus: TReadFileStatus;
begin Result := nextpas.core.test.check.ReadFileContents(APath, AContents, LStatus); end;

procedure WriteFileContents(const APath, AContents: string);
begin nextpas.core.test.check.WriteFileContents(APath, AContents); end;

procedure CheckArrayEqual(const AExpected, AActual: array of Int64);
begin nextpas.core.test.check.CheckArrayEqual(AExpected, AActual); end;

procedure CheckArrayEqual(const AExpected, AActual: array of Int64;
  const AMessage: string);
begin nextpas.core.test.check.CheckArrayEqual(AExpected, AActual, AMessage); end;

procedure CheckArrayEqual(const AExpected, AActual: array of string);
begin nextpas.core.test.check.CheckArrayEqual(AExpected, AActual); end;

procedure CheckArrayEqual(const AExpected, AActual: array of string;
  const AMessage: string);
begin nextpas.core.test.check.CheckArrayEqual(AExpected, AActual, AMessage); end;

procedure CheckIsNil(const AValue: IInterface; const AMessage: string);
begin nextpas.core.test.check.CheckIsNil(AValue, AMessage); end;

procedure CheckIsNotNil(const AValue: IInterface; const AMessage: string);
begin nextpas.core.test.check.CheckIsNotNil(AValue, AMessage); end;

procedure CheckArrayContains(const AArray: array of string;
  const AValue: string);
begin nextpas.core.test.check.CheckArrayContains(AArray, AValue); end;

procedure CheckArrayContains(const AArray: array of string;
  const AValue: string; const AMessage: string);
begin nextpas.core.test.check.CheckArrayContains(AArray, AValue, AMessage); end;

procedure CheckArrayContains(const AArray: array of Int64;
  const AValue: Int64);
begin nextpas.core.test.check.CheckArrayContains(AArray, AValue); end;

procedure CheckArrayContains(const AArray: array of Int64;
  const AValue: Int64; const AMessage: string);
begin nextpas.core.test.check.CheckArrayContains(AArray, AValue, AMessage); end;

procedure CheckArrayContains(const AArray: array of Byte;
  AValue: Byte);
begin nextpas.core.test.check.CheckArrayContains(AArray, AValue); end;

procedure CheckArrayContains(const AArray: array of Byte;
  AValue: Byte; const AMessage: string);
begin nextpas.core.test.check.CheckArrayContains(AArray, AValue, AMessage); end;

procedure CheckArrayNotContains(const AArray: array of string;
  const AValue: string);
begin nextpas.core.test.check.CheckArrayNotContains(AArray, AValue); end;

procedure CheckArrayNotContains(const AArray: array of string;
  const AValue: string; const AMessage: string);
begin nextpas.core.test.check.CheckArrayNotContains(AArray, AValue, AMessage); end;

procedure CheckArrayNotContains(const AArray: array of Int64;
  const AValue: Int64);
begin nextpas.core.test.check.CheckArrayNotContains(AArray, AValue); end;

procedure CheckArrayNotContains(const AArray: array of Int64;
  const AValue: Int64; const AMessage: string);
begin nextpas.core.test.check.CheckArrayNotContains(AArray, AValue, AMessage); end;

procedure CheckArrayNotContains(const AArray: array of Byte;
  AValue: Byte);
begin nextpas.core.test.check.CheckArrayNotContains(AArray, AValue); end;

procedure CheckArrayNotContains(const AArray: array of Byte;
  AValue: Byte; const AMessage: string);
begin nextpas.core.test.check.CheckArrayNotContains(AArray, AValue, AMessage); end;

procedure CheckSorted(const AArray: array of Int64);
begin nextpas.core.test.check.CheckSorted(AArray); end;

procedure CheckSorted(const AArray: array of Int64;
  const AMessage: string);
begin nextpas.core.test.check.CheckSorted(AArray, AMessage); end;

procedure CheckSorted(const AArray: array of string);
begin nextpas.core.test.check.CheckSorted(AArray); end;

procedure CheckSorted(const AArray: array of string;
  const AMessage: string);
begin nextpas.core.test.check.CheckSorted(AArray, AMessage); end;

procedure CheckEmpty(const AValue: string);
begin nextpas.core.test.check.CheckEmpty(AValue); end;
procedure CheckEmpty(const AValue: string; const AMessage: string);
begin nextpas.core.test.check.CheckEmpty(AValue, AMessage); end;
procedure CheckNotEmpty(const AValue: string);
begin nextpas.core.test.check.CheckNotEmpty(AValue); end;
procedure CheckNotEmpty(const AValue: string; const AMessage: string);
begin nextpas.core.test.check.CheckNotEmpty(AValue, AMessage); end;
procedure CheckEmpty(const AValue: TBytes);
begin nextpas.core.test.check.CheckEmpty(AValue); end;
procedure CheckEmpty(const AValue: TBytes; const AMessage: string);
begin nextpas.core.test.check.CheckEmpty(AValue, AMessage); end;
procedure CheckNotEmpty(const AValue: TBytes);
begin nextpas.core.test.check.CheckNotEmpty(AValue); end;
procedure CheckNotEmpty(const AValue: TBytes; const AMessage: string);
begin nextpas.core.test.check.CheckNotEmpty(AValue, AMessage); end;

procedure CheckInf(const AValue: Double; const AMessage: string);
begin nextpas.core.test.check.CheckInf(AValue, AMessage); end;
procedure CheckNotInf(const AValue: Double; const AMessage: string);
begin nextpas.core.test.check.CheckNotInf(AValue, AMessage); end;
procedure CheckFinite(const AValue: Double; const AMessage: string);
begin nextpas.core.test.check.CheckFinite(AValue, AMessage); end;

procedure CheckOneOf(const AValue: string; const AValues: array of string);
begin nextpas.core.test.check.CheckOneOf(AValue, AValues); end;
procedure CheckOneOf(const AValue: string; const AValues: array of string; const AMessage: string);
begin nextpas.core.test.check.CheckOneOf(AValue, AValues, AMessage); end;
procedure CheckOneOfInt(const AValue: Int64; const AValues: array of Int64);
begin nextpas.core.test.check.CheckOneOfInt(AValue, AValues); end;
procedure CheckOneOfInt(const AValue: Int64; const AValues: array of Int64; const AMessage: string);
begin nextpas.core.test.check.CheckOneOfInt(AValue, AValues, AMessage); end;
procedure CheckOneOfBool(AValue: Boolean; const AValues: array of Boolean);
begin nextpas.core.test.check.CheckOneOfBool(AValue, AValues); end;
procedure CheckOneOfBool(AValue: Boolean; const AValues: array of Boolean; const AMessage: string);
begin nextpas.core.test.check.CheckOneOfBool(AValue, AValues, AMessage); end;

procedure CheckInstanceOf(AObject: TObject; AClass: TClass);
begin nextpas.core.test.check.CheckInstanceOf(AObject, AClass); end;
procedure CheckInstanceOf(AObject: TObject; AClass: TClass; const AMessage: string);
begin nextpas.core.test.check.CheckInstanceOf(AObject, AClass, AMessage); end;
