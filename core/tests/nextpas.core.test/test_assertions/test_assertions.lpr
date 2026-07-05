{ test_assertions — Validates Check* procedural API

  CheckEqual comparison semantics:
    string    → <> operator (exact match, case-sensitive)
    Int64     → <> operator (exact match)
    UInt64    → <> operator (exact match)
    Boolean   → <> operator (exact match)
    Pointer   → <> operator (exact address)
    Double    → via CheckNear (Epsilon tolerance, see ToBeNear docs)
    TBytes    → element-by-element (length + byte comparison)
    3-arg     → wraps 2-arg + prepends AMessage on failure

  ⚠ Float comparison: CheckEqual(expected, actual, epsilon) delegates to
     CheckNear — epsilon=0 means bitwise identity, not "very tight".
     For normal floating-point comparisons, always use epsilon > 0.
 }
program test_assertions;

{$mode objfpc}{$H+}{$J-}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

uses
  nextpas.core.thread.init,
  nextpas.core.text.conv,
  nextpas.core.math,
  nextpas.core.test;

{ ── Test procedures ──────────────────────────────────────────────────────── }

procedure TestCheckPass;
begin
  Check(True, 'True should pass');
  Check(1 + 1 = 2);
end;

procedure TestCheckFail;
begin
  ExpectFail(procedure begin Check(False, 'expected failure'); WriteLn('ERROR: Check(False) did not raise'); end, 'expected failure');
end;

procedure TestCheckEqualString;
begin
  CheckEqual('hello', 'hello');
  ExpectFail(procedure begin CheckEqual('hello', 'world'); end, 'hello');
end;

procedure TestCheckEqualInt;
begin
  CheckEqual(Int64(42), Int64(42));
  ExpectFail(procedure begin CheckEqual(Int64(42), Int64(99)); end, '42');
end;

procedure TestCheckEqualBool;
begin
  CheckEqual(True, True);
  CheckEqual(False, False);
  ExpectFail(procedure begin CheckEqual(True, False); end, 'True');
end;

procedure TestCheckEqualPtr;
var
  LP: Pointer;
begin
  LP := @LP;
  CheckEqual(LP, LP);
  { FPC internal error when LP is captured by anonymous closure }
  try
    CheckEqual(nil, LP);
    Fail('expected pointer equality fail');
  except
    on E: EAssertionFailed do
      Check(Pos(LowerCase('pointer'), LowerCase(E.Message)) > 0,
        'expected "pointer" in message');
  end;
end;

procedure TestCheckNotEqual;
begin
  CheckNotEqual('a', 'b');
  CheckNotEqual(Int64(1), Int64(2));
  ExpectFail(procedure begin CheckNotEqual('x', 'x'); end, 'differ');
end;

procedure TestCheckNotEqualBool;
begin
  CheckNotEqual(True, False);
  ExpectFail(procedure begin CheckNotEqual(True, True); end, 'True');
end;

procedure TestCheckNotEqualPtr;
var
  LP, LP2: Pointer;
begin
  LP := @LP;
  LP2 := @LP2;
  CheckNotEqual(LP, LP2);
  try
    CheckNotEqual(LP, LP);
    Halt(1);
  except
    on E: EAssertionFailed do CheckContains(LowerCase(E.Message), 'differ');
    on E: Exception do FailUnexpected(E);
  end;
end;

procedure TestCheckTrueFalse;
begin
  CheckTrue(True);
  CheckTrue(2 > 1, 'math works');
  CheckFalse(False);
  CheckFalse(1 > 2);
  ExpectFail(procedure begin CheckTrue(False, 'should fail'); end, 'should fail');
end;

procedure TestCheckNilNotNil;
var
  LP: Pointer = nil;
begin
  CheckNil(nil);
  CheckNil(LP);
  LP := @LP;
  CheckNotNil(LP);
  try
    CheckNotNil(nil, 'should be non-nil');
    Halt(1);
  except
    on E: EAssertionFailed do CheckContains(LowerCase(E.Message), 'non-nil');
    on E: Exception do FailUnexpected(E);
  end;
end;

procedure TestCheckContains;
begin
  CheckContains('hello world', 'world');
  CheckContains('abcdef', 'cde');
  ExpectFail(procedure begin CheckContains('hello', 'xyz'); end, 'does not contain');
end;

procedure TestCheckStartsWith;
begin
  CheckStartsWith('hello world', 'hello');
  CheckStartsWith('abc', 'a');
  ExpectFail(procedure begin CheckStartsWith('hello', 'xyz'); end, 'does not start');
end;

procedure TestCheckEndsWith;
begin
  CheckEndsWith('hello world', 'world');
  CheckEndsWith('abc', 'bc');
  { Empty suffix matches everything (consistent with ToEndWith) }
  CheckEndsWith('hello', '');
  CheckEndsWith('', '');
  ExpectFail(procedure begin CheckEndsWith('hello', 'xyz'); end, 'does not end');
end;

procedure TestCheckSame;
var
  LP1, LP2: Pointer;
begin
  LP1 := @LP1;
  LP2 := LP1;
  CheckSame(LP1, LP2);
  { FPC internal error when LP1 is captured by anonymous closure }
  try
    CheckSame(LP1, nil, 'should be same');
    Fail('expected CheckSame fail');
  except
    on E: EAssertionFailed do
      Check(Pos('should be same', E.Message) > 0,
        'expected message in CheckSame fail');
  end;
end;

procedure TestCheckInRange;
begin
  CheckInRange(5, 1, 10);
  CheckInRange(1, 1, 10);
  CheckInRange(10, 1, 10);
  ExpectFail(procedure begin CheckInRange(0, 1, 10); end, 'not in range');
end;

procedure TestCheckGreaterThan;
begin
  CheckGreaterThan(10, 5);
  CheckGreaterThan(1, 0);
  ExpectFail(procedure begin CheckGreaterThan(5, 10); end, '>');
end;

procedure TestCheckLessThan;
begin
  CheckLessThan(5, 10);
  CheckLessThan(0, 1);
  ExpectFail(procedure begin CheckLessThan(10, 5); end, '<');
end;

procedure TestCheckLength;
begin
  CheckLength(5, 5);
  CheckLength(0, 0);
  ExpectFail(procedure begin CheckLength(5, 3); end, 'Expected length');
end;

procedure TestCheckRaises;
begin
  CheckRaises(EConvertError,
    procedure begin StrToInt('not_a_number'); end);
  ExpectFail(procedure begin CheckRaises(EConvertError, procedure begin { does nothing } end); end, 'EConvertError');
end;

procedure TestCheckNoRaise;
begin
  CheckNoRaise(procedure begin { ok } end);
  ExpectFail(procedure begin CheckNoRaise( procedure begin raise EConvertError.Create('oops'); end); end, 'EConvertError');
end;

procedure TestCheckRaisesSkipPassthrough;
begin
  { CheckRaises must NOT catch ETestSkip — it's flow control, not a testable exception }
  try
    CheckRaises(EConvertError,
      procedure begin Skip('flow control'); end);
    Halt(1); { Should never reach here — Skip should propagate }
  except
    on E: ETestSkipped do { expected: Skip escaped CheckRaises };
  end;
end;

procedure TestCheckNoRaiseSkipPassthrough;
begin
  { CheckNoRaise must NOT catch ETestSkipped — it's flow control }
  try
    CheckNoRaise(procedure begin Skip('flow control'); end);
    Halt(1); { Should never reach here — Skip should propagate }
  except
    on E: ETestSkipped do { expected };
  end;
end;

{ R4-09: CheckRaises with nil proc — FPC raises EAccessViolation when
  calling a nil procedure pointer, which CheckRaises catches as a
  non-matching exception class. Verify this doesn't crash the test runner. }
procedure TestCheckRaisesNil;
begin
  try
    CheckRaises(EAbort, nil);
    Halt(1);
  except
    on E: EAssertionFailed do
      Check(True, 'nil proc raised EAssertionFailed (expected class mismatch)');
    on E: Exception do
      Check(True, 'nil proc raised ' + E.ClassName + ' (not a crash)');
  end;
end;

{ P0: CheckRaises with nil ExceptClass — must fail gracefully, not SIGSEGV }
procedure TestCheckRaisesNilClass;
begin
  try
    CheckRaises(nil, procedure begin end);
    Halt(1); { should not reach here }
  except
    on E: EAssertionFailed do
      Check(Pos('nil', E.Message) > 0,
        'Expected nil in error message, got: ' + E.Message);
  end;
end;

procedure TestCheckStartsWithEmptyPrefix;
begin
  { Empty pattern matches everything — consistent across Contains/StartsWith/EndsWith }
  CheckStartsWith('hello', '');
  CheckStartsWith('', '');
  CheckContains('hello', '');
  CheckContains('', '');
  CheckEndsWith('hello', '');
  CheckEndsWith('', '');
end;

procedure TestFail;
begin
  ExpectFail(procedure begin Fail('intentional'); end, 'intentional');
end;

procedure TestSkip;
begin
  try
    Skip('not ready');
    Halt(1);
  except
    on E: ETestSkipped do
      CheckContains(E.Message, 'not ready');
  end;
end;

procedure TestCheckNearPass;
begin
  CheckNear(1.0, 1.0);
  CheckNear(1.0 + 1e-11, 1.0, 1e-10);
  CheckNear(1e-12, 0.0, 1e-10);
end;

procedure TestCheckNearFail;
begin
  ExpectFail(procedure begin CheckNear(2.0, 1.0, 1e-10, 'should differ'); end, 'should differ');
end;

{ CheckEqual(Double) / CheckNotEqual(Double) }

procedure TestCheckEqualDoublePass;
begin
  CheckEqual(1.0, 1.0);
  CheckEqual(3.14159, 3.14159);
  CheckEqual(0.0, 0.0);
  CheckEqual(-1.0, -1.0);
  { With epsilon }
  CheckEqual(1.0, 1.0 + 1e-11, 1e-10);
  CheckEqual(1.0, 1.0 - 1e-11, 1e-10);
end;

procedure TestCheckEqualDoubleFail;
begin
  ExpectFail(procedure begin CheckEqual(1.0, 2.0, 1e-10); end, 'Expected');
end;

procedure TestCheckNotEqualDoublePass;
begin
  CheckNotEqual(1.0, 2.0);
  CheckNotEqual(0.0, 1.0, 1e-10);
end;

procedure TestCheckNotEqualDoubleFail;
begin
  ExpectFail(procedure begin CheckNotEqual(1.0, 1.0); end, 'differ');
end;

procedure TestCheckNotNearPass;
begin
  CheckNotNear(2.0, 1.0);
  CheckNotNear(1.0, 0.0, 1e-10);
end;

procedure TestCheckNotNearFail;
begin
  ExpectFail(procedure begin CheckNotNear(1.0, 1.0, 1e-10, 'too close'); end, 'too close');
end;

{ CheckNearRel / CheckNotNearRel — relative tolerance }

procedure TestCheckNearRelPass;
begin
  { Both near zero — falls back to absolute }
  CheckNearRel(0.0, 1e-12, 1e-9);
  { Large values with small relative difference }
  CheckNearRel(1e15, 1e15 + 1e5, 1e-9);
  { Small values }
  CheckNearRel(1.0, 1.0 + 1e-10, 1e-9);
  { Exact match }
  CheckNearRel(42.0, 42.0);
end;

procedure TestCheckNearRelFail;
begin
  { Large values that differ significantly in relative terms }
  ExpectFail(procedure begin CheckNearRel(1e15, 1e15 + 1e10, 1e-9); end, 'Expected');
  { Small values with large relative difference }
  ExpectFail(procedure begin CheckNearRel(1.0, 2.0, 1e-9); end, 'Expected');
end;

procedure TestCheckNearRelNaN;
begin
  { NaN guard: relative comparison with NaN must fail }
  ExpectFail(procedure begin CheckNearRel(1.0, Sqrt(-1.0), 1e-9); end, 'NaN');
  ExpectFail(procedure begin CheckNearRel(Sqrt(-1.0), 1.0, 1e-9); end, 'NaN');
end;

procedure TestCheckNotNearRelPass;
begin
  CheckNotNearRel(1.0, 2.0, 1e-9);
  CheckNotNearRel(1e15, 2e15, 1e-9);
end;

procedure TestCheckNotNearRelFail;
begin
  ExpectFail(procedure begin CheckNotNearRel(1.0, 1.0, 1e-9, 'too close'); end, 'too close');
  ExpectFail(procedure begin CheckNotNearRel(1e15, 1e15 + 1e3, 1e-9, 'rel near'); end, 'rel near');
end;

procedure TestCheckNotNearRelNaN;
begin
  ExpectFail(procedure begin CheckNotNearRel(1.0, Sqrt(-1.0), 1e-9); end, 'NaN');
end;

{ F-06: CheckSnapshot }

procedure TestCheckSnapshotCreateAndMatch;
const
  LSnapDir = '/tmp/np_snap_a';
begin
  CheckSnapshot('hello world', LSnapDir, 'test1.txt');
  CheckSnapshot('hello world', LSnapDir, 'test1.txt');
end;

procedure TestCheckSnapshotMismatch;
const
  LSnapDir = '/tmp/np_snap_b';
begin
  CheckSnapshot('hello world', LSnapDir, 'test2.txt');
  ExpectFail(procedure begin CheckSnapshot('goodbye world', LSnapDir, 'test2.txt'); end, 'mismatch');
end;

{ E-10: CheckNaN / CheckNotNaN }

procedure TestCheckNaNPass;
begin
  CheckNaN(Sqrt(-1.0), 'NaN should be NaN');
end;

procedure TestCheckNaNFail;
begin
  ExpectFail(procedure begin CheckNaN(1.0, 'expect-fail: 1.0 is not NaN'); end);
end;

procedure TestCheckNotNaNPass;
begin
  CheckNotNaN(1.0, '1.0 should not be NaN');
end;

procedure TestCheckNotNaNFail;
begin
  ExpectFail(procedure begin CheckNotNaN(Sqrt(-1.0), 'expect-fail: NaN is NaN'); end);
end;

{ R6-40: Empty string semantics for Contains/StartsWith/EndsWith }

procedure TestR640CheckContainsEmptyNeedle;
begin
  { Empty needle is a substring of any string }
  CheckContains('abc', '');
  CheckContains('', '');
end;

procedure TestR640CheckStartsWithEmptyPrefix;
begin
  { Empty prefix matches any string }
  CheckStartsWith('abc', '');
  CheckStartsWith('', '');
end;

procedure TestR640CheckEndsWithEmptySuffix;
begin
  { Confirm empty suffix matches; complements existing TestCheckEndsWith }
  CheckEndsWith('abc', '');
  CheckEndsWith('', '');
end;

{ R6-41: CheckInRange boundary equality values }

procedure TestCheckInRangeLowerBoundEqual;
begin
  { Value equal to ALow should pass }
  CheckInRange(5, 5, 10);
end;

procedure TestCheckInRangeUpperBoundEqual;
begin
  { Value equal to AHigh should pass }
  CheckInRange(10, 5, 10);
end;

{ R6-42: CheckGreaterThan/CheckLessThan equal values should fail }

procedure TestCheckGreaterThanEqualFail;
begin
  ExpectFail(procedure begin CheckGreaterThan(5, 5); end);
end;

procedure TestCheckLessThanEqualFail;
begin
  ExpectFail(procedure begin CheckLessThan(5, 5); end);
end;

{ R6-43: CheckRaises catches child exception with parent class }

type
  ETestChildException = class(Exception);

procedure TestCheckRaisesCatchesChildWithParent;
begin
  { CheckRaises(EException) should catch a child exception class }
  CheckRaises(Exception,
    procedure begin raise ETestChildException.Create('child'); end);
end;

{ ── v3.1: CheckGreaterOrEqual / CheckLessOrEqual ───────────────────────────── }

procedure TestCheckGreaterOrEqualPass;
begin
  CheckGreaterOrEqual(5, 5);
  CheckGreaterOrEqual(6, 5);
end;

procedure TestCheckGreaterOrEqualFail;
begin
  ExpectFail(procedure begin CheckGreaterOrEqual(4, 5); end, '>=');
end;

procedure TestCheckLessOrEqualPass;
begin
  CheckLessOrEqual(5, 5);
  CheckLessOrEqual(4, 5);
end;

procedure TestCheckLessOrEqualFail;
begin
  ExpectFail(procedure begin CheckLessOrEqual(6, 5); end, '<=');
end;

procedure TestCheckNotContains;
{ G1: CheckNotContains — symmetric to CheckContains }
begin
  { pass: haystack does NOT contain needle }
  CheckNotContains('hello world', 'xyz');
  { fail: haystack DOES contain needle }
  try
    CheckNotContains('hello world', 'world');
    Fail('CheckNotContains should fail when haystack contains needle');
  except
    on E: EAssertionFailed do
      CheckContains(E.Message, 'should not contain');
  end;
end;

procedure TestFailUnexpected;
{ G1: FailUnexpected — formats "unexpected ClassName: Message" }
begin
  try
    FailUnexpected(Exception.Create('boom'));
    Fail('FailUnexpected should raise');
  except
    on E: EAssertionFailed do
    begin
      CheckContains(E.Message, 'unexpected');
      CheckContains(E.Message, 'boom');
    end;
  end;
end;

{ ── S1: New Check*D + CI + Negation tests ──────────────────────────────────── }

procedure TestCheckGreaterThanDPass;
begin
  CheckGreaterThanD(5.5, 5.0);
  CheckGreaterThanD(1.0 + 1e-9, 1.0, 1e-8);
end;

procedure TestCheckGreaterThanDFail;
begin
  ExpectFail(procedure begin CheckGreaterThanD(5.0, 5.0); end);
end;

procedure TestCheckGreaterThanDEqEps;
begin
  { Equal within epsilon — should fail (strict >, not >=) }
  ExpectFail(procedure begin CheckGreaterThanD(5.0, 5.0 + 1e-11, 1e-10); end, 'epsilon');
end;

procedure TestCheckLessThanDPass;
begin
  CheckLessThanD(4.5, 5.0);
  CheckLessThanD(1.0 - 1e-9, 1.0, 1e-8);
end;

procedure TestCheckLessThanDFail;
begin
  ExpectFail(procedure begin CheckLessThanD(5.0, 5.0); end);
end;

procedure TestCheckLessThanDEqEps;
begin
  ExpectFail(procedure begin CheckLessThanD(5.0, 5.0 - 1e-11, 1e-10); end, 'epsilon');
end;

procedure TestCheckGreaterOrEqualDPass;
begin
  CheckGreaterOrEqualD(5.0, 5.0);
  CheckGreaterOrEqualD(5.1, 5.0);
  CheckGreaterOrEqualD(5.0 + 1e-11, 5.0, 1e-10);
end;

procedure TestCheckGreaterOrEqualDFail;
begin
  ExpectFail(procedure begin CheckGreaterOrEqualD(4.0, 5.0); end);
end;

procedure TestCheckGreaterOrEqualDEq;
begin
  { Value slightly below expected but within epsilon — should pass }
  CheckGreaterOrEqualD(5.0 - 1e-11, 5.0, 1e-10);
end;

procedure TestCheckGreaterOrEqualDNaN;
var
  LNaN: Double;
  LOldMask: TFPUExceptionMask;
begin
  LOldMask := GetExceptionMask;
  SetExceptionMask([exInvalidOp, exZeroDivide, exOverflow, exUnderflow, exPrecision, exDenormalized]);
  LNaN := 0.0 / 0.0;
  ExpectFail(procedure begin CheckGreaterOrEqualD(LNaN, 0.0); end, 'NaN');
  ExpectFail(procedure begin CheckGreaterOrEqualD(0.0, LNaN); end, 'NaN');
  SetExceptionMask(LOldMask);
end;

procedure TestCheckLessOrEqualDPass;
begin
  CheckLessOrEqualD(5.0, 5.0);
  CheckLessOrEqualD(4.9, 5.0);
  CheckLessOrEqualD(5.0 - 1e-11, 5.0, 1e-10);
end;

procedure TestCheckLessOrEqualDFail;
begin
  ExpectFail(procedure begin CheckLessOrEqualD(6.0, 5.0); end);
end;

procedure TestCheckLessOrEqualDEq;
begin
  { Value slightly above expected but within epsilon — should pass }
  CheckLessOrEqualD(5.0 + 1e-11, 5.0, 1e-10);
end;

procedure TestCheckLessOrEqualDNaN;
var
  LNaN: Double;
  LOldMask: TFPUExceptionMask;
begin
  LOldMask := GetExceptionMask;
  SetExceptionMask([exInvalidOp, exZeroDivide, exOverflow, exUnderflow, exPrecision, exDenormalized]);
  LNaN := 0.0 / 0.0;
  ExpectFail(procedure begin CheckLessOrEqualD(LNaN, 0.0); end, 'NaN');
  ExpectFail(procedure begin CheckLessOrEqualD(0.0, LNaN); end, 'NaN');
  SetExceptionMask(LOldMask);
end;

procedure TestCheckInRangeDPass;
begin
  CheckInRangeD(5.0, 1.0, 10.0);
  CheckInRangeD(3.14, 3.0, 4.0);
end;

procedure TestCheckInRangeDBounds;
begin
  CheckInRangeD(1.0, 1.0, 10.0);
  CheckInRangeD(10.0, 1.0, 10.0);
  { Boundary within epsilon }
  CheckInRangeD(1.0 - 1e-11, 1.0, 10.0, 1e-10);
  CheckInRangeD(10.0 + 1e-11, 1.0, 10.0, 1e-10);
end;

procedure TestCheckInRangeDFail;
begin
  ExpectFail(procedure begin CheckInRangeD(11.0, 1.0, 10.0); end, 'not in range');
end;

procedure TestCheckInRangeDInverted;
begin
  ExpectFail(procedure begin CheckInRangeD(5.0, 10.0, 1.0); end, 'ALow');
end;

procedure TestCheckInRangeDNaN;
var
  LNaN: Double;
  LOldMask: TFPUExceptionMask;
begin
  LOldMask := GetExceptionMask;
  SetExceptionMask([exInvalidOp, exZeroDivide, exOverflow, exUnderflow, exPrecision, exDenormalized]);
  LNaN := 0.0 / 0.0;
  ExpectFail(procedure begin CheckInRangeD(LNaN, 0.0, 1.0); end, 'NaN');
  { ALow/High NaN must also fail }
  ExpectFail(procedure begin CheckInRangeD(0.5, LNaN, 1.0); end, 'NaN');
  ExpectFail(procedure begin CheckInRangeD(0.5, 0.0, LNaN); end, 'NaN');
  SetExceptionMask(LOldMask);
end;

procedure TestCheckGreaterThanDNaN;
var
  LNaN: Double;
  LOldMask: TFPUExceptionMask;
begin
  LOldMask := GetExceptionMask;
  SetExceptionMask([exInvalidOp, exZeroDivide, exOverflow, exUnderflow, exPrecision, exDenormalized]);
  LNaN := 0.0 / 0.0;
  ExpectFail(procedure begin CheckGreaterThanD(LNaN, 0.0); end, 'NaN');
  ExpectFail(procedure begin CheckGreaterThanD(0.0, LNaN); end, 'NaN');
  SetExceptionMask(LOldMask);
end;

procedure TestCheckLessThanDNaN;
var
  LNaN: Double;
  LOldMask: TFPUExceptionMask;
begin
  LOldMask := GetExceptionMask;
  SetExceptionMask([exInvalidOp, exZeroDivide, exOverflow, exUnderflow, exPrecision, exDenormalized]);
  LNaN := 0.0 / 0.0;
  ExpectFail(procedure begin CheckLessThanD(LNaN, 0.0); end, 'NaN');
  ExpectFail(procedure begin CheckLessThanD(0.0, LNaN); end, 'NaN');
  SetExceptionMask(LOldMask);
end;

procedure TestCheckNearNaN;
var
  LNaN: Double;
  LOldMask: TFPUExceptionMask;
begin
  LOldMask := GetExceptionMask;
  SetExceptionMask([exInvalidOp, exZeroDivide, exOverflow, exUnderflow, exPrecision, exDenormalized]);
  LNaN := 0.0 / 0.0;
  ExpectFail(procedure begin CheckNear(LNaN, 0.0, 1e-10); end, 'NaN');
  ExpectFail(procedure begin CheckNear(0.0, LNaN, 1e-10); end, 'NaN');
  ExpectFail(procedure begin CheckNear(LNaN, LNaN, 1e-10); end, 'NaN');
  SetExceptionMask(LOldMask);
end;

procedure TestCheckNotNearNaN;
var
  LNaN: Double;
  LOldMask: TFPUExceptionMask;
begin
  LOldMask := GetExceptionMask;
  SetExceptionMask([exInvalidOp, exZeroDivide, exOverflow, exUnderflow, exPrecision, exDenormalized]);
  LNaN := 0.0 / 0.0;
  ExpectFail(procedure begin CheckNotNear(LNaN, 0.0, 1e-10); end, 'NaN');
  ExpectFail(procedure begin CheckNotNear(0.0, LNaN, 1e-10); end, 'NaN');
  SetExceptionMask(LOldMask);
end;

{ ── P3: Edge cases — -0.0, Infinity, negative epsilon, denormals ──────────── }

procedure TestCheckNearNegativeZero;
begin
  { IEEE 754: -0.0 = +0.0 }
  CheckNear(0.0, -0.0, 1e-10);
  CheckNear(-0.0, 0.0, 1e-10);
end;

procedure TestCheckEqualDoubleNegativeZero;
begin
  CheckEqual(0.0, -0.0);
  CheckEqual(-0.0, 0.0);
end;

procedure TestCheckNearNegativeEpsilon;
begin
  { Negative epsilon: Abs() of the diff is always positive, so
    negative epsilon means everything is "not near" — near should always fail.
    But Abs(epsilon) would be more user-friendly. Current behavior: fail. }
  ExpectFail(procedure begin CheckNear(1.0, 1.0, -1e-10); end);
end;

procedure TestCheckNearDenormal;
var
  LDenorm: Double;
begin
  { Smallest positive denormalized Double }
  LDenorm := 5e-324;
  CheckNear(0.0, LDenorm, 1e-300);
  CheckNear(LDenorm, LDenorm, 0.0);
end;

procedure TestCheckGreaterThanDInfinity;
var
  LInf: Double;
  LOldMask: TFPUExceptionMask;
begin
  LOldMask := GetExceptionMask;
  SetExceptionMask([exInvalidOp, exZeroDivide, exOverflow, exUnderflow, exPrecision, exDenormalized]);
  LInf := 1.0 / 0.0;
  CheckGreaterThanD(LInf, 1e308);
  ExpectFail(procedure begin CheckGreaterThanD(1e308, LInf); end);
  SetExceptionMask(LOldMask);
end;

procedure TestCheckLessThanDInfinity;
var
  LInf: Double;
  LOldMask: TFPUExceptionMask;
begin
  LOldMask := GetExceptionMask;
  SetExceptionMask([exInvalidOp, exZeroDivide, exOverflow, exUnderflow, exPrecision, exDenormalized]);
  LInf := 1.0 / 0.0;
  CheckLessThanD(1e308, LInf);
  ExpectFail(procedure begin CheckLessThanD(LInf, 1e308); end);
  SetExceptionMask(LOldMask);
end;

procedure TestCheckContainsCIEmptyHaystack;
begin
  { Empty haystack with non-empty needle → fail }
  ExpectFail(procedure begin CheckContainsCI('', 'abc'); end);
end;

{ ── T-01: NaN/边界测试补全 ───────────────────────────────────────────────── }

procedure TestCheckEqualDoubleNaN;
var
  LNaN: Double;
  LOldMask: TFPUExceptionMask;
begin
  LOldMask := GetExceptionMask;
  SetExceptionMask([exInvalidOp, exZeroDivide, exOverflow, exUnderflow, exPrecision, exDenormalized]);
  LNaN := 0.0 / 0.0;
  { NaN == NaN should fail (IEEE 754: NaN ≠ NaN) }
  ExpectFail(procedure begin CheckEqual(LNaN, LNaN); end, 'NaN');
  { NaN == 0.0 should also fail }
  ExpectFail(procedure begin CheckEqual(LNaN, 0.0); end, 'NaN');
  ExpectFail(procedure begin CheckEqual(0.0, LNaN); end, 'NaN');
  SetExceptionMask(LOldMask);
end;

procedure TestCheckNotEqualDoubleNaN;
var
  LNaN: Double;
  LOldMask: TFPUExceptionMask;
begin
  LOldMask := GetExceptionMask;
  SetExceptionMask([exInvalidOp, exZeroDivide, exOverflow, exUnderflow, exPrecision, exDenormalized]);
  LNaN := 0.0 / 0.0;
  { NaN != NaN should pass (NaN is always "not equal" to anything) }
  CheckNotEqual(LNaN, LNaN);
  { NaN != 0.0 should also pass }
  CheckNotEqual(LNaN, 0.0);
  CheckNotEqual(0.0, LNaN);
  SetExceptionMask(LOldMask);
end;

procedure TestCheckNearEpsilonExact;
begin
  { Diff slightly less than epsilon — should pass }
  CheckNear(1.0, 1.0 + 9.99e-11, 1e-10);
  CheckNear(1.0, 1.0 - 9.99e-11, 1e-10);
end;

procedure TestCheckSameNilNil;
begin
  { nil == nil should pass }
  CheckSame(nil, nil);
end;

procedure TestCheckSameNilNotNil;
var
  LDummy: Integer;
  LP: Pointer;
begin
  LDummy := 42;
  LP := @LDummy;
  { nil != @LP should fail }
  try
    CheckSame(nil, LP);
    Fail('expected CheckSame(nil, ptr) to fail');
  except
    on E: EAssertionFailed do
      Check(True, 'CheckSame(nil, ptr) raised as expected');
  end;
end;

procedure TestCheckNotStartsWithPass;
begin
  CheckNotStartsWith('hello', 'xyz');
  CheckNotStartsWith('hello', 'world');
end;

procedure TestCheckNotStartsWithFail;
begin
  ExpectFail(procedure begin CheckNotStartsWith('hello', 'hel'); end, 'should not start');
end;

procedure TestCheckNotStartsWithEmpty;
begin
  { Empty prefix is a no-op (always passes) }
  CheckNotStartsWith('hello', '');
end;

procedure TestCheckNotEndsWithPass;
begin
  CheckNotEndsWith('hello', 'xyz');
  CheckNotEndsWith('hello', 'world');
end;

procedure TestCheckNotEndsWithFail;
begin
  ExpectFail(procedure begin CheckNotEndsWith('hello', 'llo'); end, 'should not end');
end;

procedure TestCheckNotEndsWithEmpty;
begin
  { Empty suffix is a no-op (always passes) }
  CheckNotEndsWith('hello', '');
end;

procedure TestCheckContainsCIPass;
begin
  CheckContainsCI('Hello World', 'hello');
  CheckContainsCI('Hello World', 'WORLD');
  CheckContainsCI('abc', 'ABC');
end;

procedure TestCheckContainsCIFail;
begin
  ExpectFail(procedure begin CheckContainsCI('Hello', 'xyz'); end, 'does not contain (ci)');
end;

procedure TestCheckContainsCIEmpty;
begin
  CheckContainsCI('hello', '');
  CheckContainsCI('', '');
end;

procedure TestCheckNotContainsCIPass;
begin
  CheckNotContainsCI('Hello World', 'xyz');
end;

procedure TestCheckNotContainsCIFail;
begin
  ExpectFail(procedure begin CheckNotContainsCI('Hello World', 'hello'); end, 'should not contain (ci)');
end;

procedure TestCheckStartsWithCIPass;
begin
  CheckStartsWithCI('Hello World', 'hello');
  CheckStartsWithCI('HELLO', 'hel');
end;

procedure TestCheckStartsWithCIFail;
begin
  ExpectFail(procedure begin CheckStartsWithCI('Hello World', 'world'); end, 'does not start with (ci)');
end;

procedure TestCheckEndsWithCIPass;
begin
  CheckEndsWithCI('Hello World', 'WORLD');
  CheckEndsWithCI('hello', 'LLo');
end;

procedure TestCheckEndsWithCIFail;
begin
  ExpectFail(procedure begin CheckEndsWithCI('Hello World', 'hello'); end, 'does not end with (ci)');
end;

{ ── Main ──────────────────────────────────────────────────────────────────── }

var
  LSuite: TTestSuite;
begin
  WriteLn('=== test_assertions ===');
  LSuite := TTestSuite.Create('Check* API');

  LSuite.Test('Check (pass)',          @TestCheckPass);
  LSuite.Test('Check (fail)',          @TestCheckFail);
  LSuite.Test('CheckEqual (string)',   @TestCheckEqualString);
  LSuite.Test('CheckEqual (int64)',    @TestCheckEqualInt);
  LSuite.Test('CheckEqual (bool)',     @TestCheckEqualBool);
  LSuite.Test('CheckEqual (pointer)',  @TestCheckEqualPtr);
  LSuite.Test('CheckNotEqual',         @TestCheckNotEqual);
  LSuite.Test('CheckNotEqual (bool)',  @TestCheckNotEqualBool);
  LSuite.Test('CheckNotEqual (ptr)',   @TestCheckNotEqualPtr);
  LSuite.Test('CheckTrue/False',       @TestCheckTrueFalse);
  LSuite.Test('CheckNil/NotNil',       @TestCheckNilNotNil);
  LSuite.Test('CheckContains',         @TestCheckContains);
  LSuite.Test('CheckStartsWith',       @TestCheckStartsWith);
  LSuite.Test('CheckEndsWith',         @TestCheckEndsWith);
  LSuite.Test('CheckSame',             @TestCheckSame);
  LSuite.Test('CheckInRange',          @TestCheckInRange);
  LSuite.Test('CheckGreaterThan',      @TestCheckGreaterThan);
  LSuite.Test('CheckLessThan',         @TestCheckLessThan);
  LSuite.Test('CheckLength',           @TestCheckLength);
  LSuite.Test('CheckRaises',           @TestCheckRaises);
  LSuite.Test('CheckNoRaise',          @TestCheckNoRaise);
  LSuite.Test('CheckRaises+Skip',      @TestCheckRaisesSkipPassthrough);
  LSuite.Test('CheckNoRaise+Skip',     @TestCheckNoRaiseSkipPassthrough);
  LSuite.Test('CheckRaises nil',        @TestCheckRaisesNil); { R4-09 }
  LSuite.Test('CheckRaises nil class',  @TestCheckRaisesNilClass); { P0 }
  LSuite.Test('StartsWith empty',      @TestCheckStartsWithEmptyPrefix);
  LSuite.Test('Fail',                  @TestFail);
  LSuite.Test('Skip',                  @TestSkip);
  LSuite.Test('CheckNear (pass)',      @TestCheckNearPass);
  LSuite.Test('CheckNear (fail)',      @TestCheckNearFail);
  LSuite.Test('CheckNotNear (pass)',   @TestCheckNotNearPass);
  LSuite.Test('CheckNotNear (fail)',   @TestCheckNotNearFail);

  { R6-40: Empty string semantics }
  LSuite.Test('Contains empty needle',        @TestR640CheckContainsEmptyNeedle);
  LSuite.Test('StartsWith empty prefix',      @TestR640CheckStartsWithEmptyPrefix);
  LSuite.Test('EndsWith empty suffix',        @TestR640CheckEndsWithEmptySuffix);

  { R6-41: CheckInRange boundary equality }
  LSuite.Test('InRange lower bound equal',    @TestCheckInRangeLowerBoundEqual);
  LSuite.Test('InRange upper bound equal',    @TestCheckInRangeUpperBoundEqual);

  { R6-42: GreaterThan/LessThan equal values fail }
  LSuite.Test('GreaterThan equal fails',      @TestCheckGreaterThanEqualFail);
  LSuite.Test('LessThan equal fails',         @TestCheckLessThanEqualFail);

  { R6-43: CheckRaises parent catches child }
  LSuite.Test('Raises parent catches child',  @TestCheckRaisesCatchesChildWithParent);

  { Phase 1: CheckEqual(Double) / CheckNotEqual(Double) }
  LSuite.Test('CheckEqual (double pass)',     @TestCheckEqualDoublePass);
  LSuite.Test('CheckEqual (double fail)',     @TestCheckEqualDoubleFail);
  LSuite.Test('CheckNotEqual (double pass)',  @TestCheckNotEqualDoublePass);
  LSuite.Test('CheckNotEqual (double fail)',  @TestCheckNotEqualDoubleFail);

  { v3.1: CheckGreaterOrEqual / CheckLessOrEqual }
  LSuite.Test('GreaterOrEqual pass',         @TestCheckGreaterOrEqualPass);
  LSuite.Test('GreaterOrEqual fail',         @TestCheckGreaterOrEqualFail);
  LSuite.Test('LessOrEqual pass',            @TestCheckLessOrEqualPass);
  LSuite.Test('LessOrEqual fail',            @TestCheckLessOrEqualFail);

  { G1: Coverage gaps }
  LSuite.Test('CheckNotContains',            @TestCheckNotContains);
  LSuite.Test('FailUnexpected',              @TestFailUnexpected);

  { === S1: New Check*D + CI + Negation tests (usability audit) === }

  { Double comparison operators }
  LSuite.Test('GreaterThanD pass',           @TestCheckGreaterThanDPass);
  LSuite.Test('GreaterThanD fail',           @TestCheckGreaterThanDFail);
  LSuite.Test('GreaterThanD eq+eps',         @TestCheckGreaterThanDEqEps);
  LSuite.Test('LessThanD pass',              @TestCheckLessThanDPass);
  LSuite.Test('LessThanD fail',              @TestCheckLessThanDFail);
  LSuite.Test('LessThanD eq+eps',            @TestCheckLessThanDEqEps);
  LSuite.Test('GreaterOrEqualD pass',        @TestCheckGreaterOrEqualDPass);
  LSuite.Test('GreaterOrEqualD fail',        @TestCheckGreaterOrEqualDFail);
  LSuite.Test('GreaterOrEqualD eq',          @TestCheckGreaterOrEqualDEq);
  LSuite.Test('GreaterOrEqualD NaN',         @TestCheckGreaterOrEqualDNaN);
  LSuite.Test('LessOrEqualD pass',           @TestCheckLessOrEqualDPass);
  LSuite.Test('LessOrEqualD fail',           @TestCheckLessOrEqualDFail);
  LSuite.Test('LessOrEqualD eq',             @TestCheckLessOrEqualDEq);
  LSuite.Test('LessOrEqualD NaN',            @TestCheckLessOrEqualDNaN);
  LSuite.Test('InRangeD pass',               @TestCheckInRangeDPass);
  LSuite.Test('InRangeD bounds',             @TestCheckInRangeDBounds);
  LSuite.Test('InRangeD fail',               @TestCheckInRangeDFail);
  LSuite.Test('InRangeD inverted',           @TestCheckInRangeDInverted);
  LSuite.Test('InRangeD NaN',                @TestCheckInRangeDNaN);
  LSuite.Test('GreaterThanD NaN',            @TestCheckGreaterThanDNaN);
  LSuite.Test('LessThanD NaN',               @TestCheckLessThanDNaN);
  LSuite.Test('Near NaN',                    @TestCheckNearNaN);
  LSuite.Test('NotNear NaN',                 @TestCheckNotNearNaN);

  { P3: Edge cases }
  LSuite.Test('Near -0.0 = +0.0',           @TestCheckNearNegativeZero);
  LSuite.Test('EqualD -0.0 = +0.0',         @TestCheckEqualDoubleNegativeZero);
  LSuite.Test('Near negative epsilon',       @TestCheckNearNegativeEpsilon);
  LSuite.Test('Near denormal',               @TestCheckNearDenormal);
  LSuite.Test('GreaterThanD Infinity',       @TestCheckGreaterThanDInfinity);
  LSuite.Test('LessThanD Infinity',          @TestCheckLessThanDInfinity);
  LSuite.Test('ContainsCI empty haystack',   @TestCheckContainsCIEmptyHaystack);

  { T-01: NaN/边界补全 }
  LSuite.Test('CheckEqualD NaN',             @TestCheckEqualDoubleNaN);
  LSuite.Test('CheckNotEqualD NaN',          @TestCheckNotEqualDoubleNaN);
  LSuite.Test('Near epsilon exact',          @TestCheckNearEpsilonExact);
  LSuite.Test('CheckSame nil=nil',           @TestCheckSameNilNil);
  LSuite.Test('CheckSame nil<>ptr',          @TestCheckSameNilNotNil);

  { String negation }
  LSuite.Test('NotStartsWith pass',          @TestCheckNotStartsWithPass);
  LSuite.Test('NotStartsWith fail',          @TestCheckNotStartsWithFail);
  LSuite.Test('NotStartsWith empty',         @TestCheckNotStartsWithEmpty);
  LSuite.Test('NotEndsWith pass',            @TestCheckNotEndsWithPass);
  LSuite.Test('NotEndsWith fail',            @TestCheckNotEndsWithFail);
  LSuite.Test('NotEndsWith empty',           @TestCheckNotEndsWithEmpty);

  { Case-insensitive string }
  LSuite.Test('ContainsCI pass',             @TestCheckContainsCIPass);
  LSuite.Test('ContainsCI fail',             @TestCheckContainsCIFail);
  LSuite.Test('ContainsCI empty',            @TestCheckContainsCIEmpty);
  LSuite.Test('NotContainsCI pass',          @TestCheckNotContainsCIPass);
  LSuite.Test('NotContainsCI fail',          @TestCheckNotContainsCIFail);
  LSuite.Test('StartsWithCI pass',           @TestCheckStartsWithCIPass);
  LSuite.Test('StartsWithCI fail',           @TestCheckStartsWithCIFail);
  LSuite.Test('EndsWithCI pass',             @TestCheckEndsWithCIPass);
  LSuite.Test('EndsWithCI fail',             @TestCheckEndsWithCIFail);

  { Relative tolerance }
  LSuite.Test('NearRel pass',               @TestCheckNearRelPass);
  LSuite.Test('NearRel fail',               @TestCheckNearRelFail);
  LSuite.Test('NearRel NaN',                @TestCheckNearRelNaN);
  LSuite.Test('NotNearRel pass',            @TestCheckNotNearRelPass);
  LSuite.Test('NotNearRel fail',            @TestCheckNotNearRelFail);
  LSuite.Test('NotNearRel NaN',             @TestCheckNotNearRelNaN);

  { F-06: Snapshot testing }
  LSuite.Test('Snapshot create+match',     @TestCheckSnapshotCreateAndMatch);
  LSuite.Test('Snapshot mismatch',         @TestCheckSnapshotMismatch);

  { E-10: CheckNaN / CheckNotNaN coverage }
  LSuite.Test('CheckNaN pass',             @TestCheckNaNPass);
  LSuite.Test('CheckNaN fail',             @TestCheckNaNFail);
  LSuite.Test('CheckNotNaN pass',          @TestCheckNotNaNPass);
  LSuite.Test('CheckNotNaN fail',          @TestCheckNotNaNFail);

  if not LSuite.Run then
  begin
    Finalize(LSuite);
    WriteLn;
    FailTest('SOME TESTS FAILED');
  end;
  WriteLn;
  PassTest('ALL PASSED');
  Finalize(LSuite);
end.
