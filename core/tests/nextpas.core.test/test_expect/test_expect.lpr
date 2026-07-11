{ test_expect — Validates IExpectation fluent API

  API Recommendation — Factory function selection:
    Type-safe factory (preferred):
      ExpectStr(s)      — string, enables ToEqual/ToContain/ToStartWith/ToEndWith/ToHaveLength
      ExpectInt(n)      — Int64, enables ToEqualInt/ToBeGreaterThan/ToBeLessThan/ToBeInRange/ToBePositive/ToBeNegative
      ExpectBool(b)     — Boolean, enables ToBeTrue/ToBeFalse
      ExpectDouble(d)   — Double, enables ToEqualDouble/ToBeNear/ToBeGreaterThan/ToBeLessThan
      ExpectPtr(p)      — Pointer, enables ToBeNil/ToNotBeNil
      ExpectProc(p)     — TTestProc, enables ToRaise/ToNotRaise

    Convenience factory (string only):
      Expect(s)         — equivalent to ExpectStr(s)
      ⚠ Do NOT pass non-string to Expect(): compiles via implicit conversion
        but creates wrong expectation kind, causing RequireKind to panic.

    Example:
      ExpectStr(name).ToEqual('Alice');          ✓ clear, type-safe
      Expect(name).ToEqual('Alice');             ✓ also fine for strings
      Expect(42).ToEqualInt(42);                 ✗ compiles but wrong kind! Use ExpectInt(42)
 }
program test_expect;

{$mode objfpc}{$H+}{$J-}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

uses
  nextpas.core.thread.init,
  nextpas.core.base,
  nextpas.core.text.conv,
  nextpas.core.bytes,
  nextpas.core.math,
  nextpas.core.test;

{ ── Test procedures ──────────────────────────────────────────────────────── }

procedure TestExpectString;
begin
  Expect('hello').ToEqual('hello');
  Expect('hello world').ToContain('world');
  Expect('hello').ToStartWith('hel');
  Expect('hello').ToEndWith('llo');
  Expect('hello').ToHaveLength(5);
  Expect('').ToHaveLength(0);
end;

procedure TestExpectInt;
begin
  ExpectInt(42).ToEqualInt(42);
  ExpectInt(10).ToBeGreaterThan(5);
  ExpectInt(5).ToBeLessThan(10);
  ExpectInt(7).ToBeInRange(1, 10);
  ExpectInt(1).ToBeInRange(1, 10);
  ExpectInt(10).ToBeInRange(1, 10);
end;

procedure TestExpectBool;
begin
  ExpectBool(True).ToBeTrue;
  ExpectBool(False).ToBeFalse;
  ExpectBool(True).ToEqualBool(True);
  ExpectBool(False).ToEqualBool(False);
end;

procedure TestExpectPtr;
var
  LP: Pointer;
begin
  LP := @LP;
  ExpectPtr(LP).ToBeNotNil;
  ExpectPtr(nil).ToBeNil;
end;

procedure TestExpectNotString;
begin
  Expect('hello').Not_.ToEqual('world');
  Expect('hello').Not_.ToContain('xyz');
  Expect('hello').Not_.ToStartWith('xyz');
  Expect('hello').Not_.ToEndWith('xyz');
  Expect('hello').Not_.ToHaveLength(3);
end;

procedure TestExpectNotInt;
begin
  ExpectInt(42).Not_.ToEqualInt(99);
  ExpectInt(10).Not_.ToBeLessThan(5);
  ExpectInt(5).Not_.ToBeGreaterThan(10);
  ExpectInt(7).Not_.ToBeInRange(20, 30);
end;

procedure TestExpectNotBool;
begin
  ExpectBool(True).Not_.ToBeFalse;
  ExpectBool(False).Not_.ToBeTrue;
end;

procedure TestExpectNotPtr;
begin
  ExpectPtr(nil).Not_.ToBeNotNil;
end;

procedure TestExpectProcRaise;
begin
  ExpectProc(procedure begin StrToInt('bad'); end)
    .ToRaise(EConvertError);
  ExpectProc(procedure begin StrToInt('bad'); end)
    .ToRaise(EConvertError, 'Invalid');
end;

procedure TestExpectProcNotRaise;
begin
  ExpectProc(procedure begin { ok } end)
    .Not_.ToRaise(EConvertError);
end;

{ ── Failure tests ────────────────────────────────────────────────────────── }

procedure TestExpectStringFailToEqual;
begin
  ExpectFail(procedure begin Expect('hello').ToEqual('world'); end, 'world');
end;

procedure TestExpectStringFailNotToEqual;
begin
  ExpectFail(procedure begin Expect('hello').Not_.ToEqual('hello'); end, 'not to equal');
end;

procedure TestExpectIntFailToEqual;
begin
  ExpectFail(procedure begin ExpectInt(42).ToEqualInt(99); end, '99');
end;

procedure TestExpectBoolFailToBeTrue;
begin
  ExpectFail(procedure begin ExpectBool(False).ToBeTrue; end, 'True');
end;

procedure TestExpectPtrFailToBeNil;
begin
  ExpectFail(procedure begin ExpectPtr(@TestExpectPtrFailToBeNil).ToBeNil; end, 'nil');
end;

procedure TestExpectContainFail;
begin
  ExpectFail(procedure begin Expect('hello').ToContain('xyz'); end, 'does not contain');
end;

procedure TestExpectRangeFail;
begin
  ExpectFail(procedure begin ExpectInt(100).ToBeInRange(1, 10); end, 'not in');
end;

procedure TestExpectRangeInverted;
begin
  { R5-11: ToBeInRange must validate ALow > AHigh (consistent with CheckInRange) }
  ExpectFail(procedure begin ExpectInt(5).ToBeInRange(10, 1); end, 'ALow');
end;

procedure TestExpectRaiseFail;
begin
  ExpectFail(procedure begin ExpectProc(procedure begin { nothing } end) .ToRaise(EConvertError); end, 'nothing raised');
end;

procedure TestExpectNotToBeNotNil;
begin
  { Not_.ToBeNotNil on nil should pass (nil IS "not non-nil") }
  ExpectPtr(nil).Not_.ToBeNotNil;
  { ToBeNotNil on non-nil should pass }
  ExpectPtr(@TestExpectNotToBeNotNil).ToBeNotNil;
end;

procedure TestExpectNotStateReset;
var
  E: IExpectation;
begin
  { FNegated should be reset after each To* call }
  E := Expect('hello');
  E.Not_.ToEqual('world');  { Not_ toggles True, ToEqual resets to False }
  E.ToEqual('hello');       { FNegated was reset — should pass }
end;

{ ── Not_ failure path tests (B5.1) ───────────────────────────────────────── }

procedure TestNotFailToEqualInt;
begin
  ExpectFail(procedure begin ExpectInt(42).Not_.ToEqualInt(42); end, LowerCase('not'));
end;

procedure TestNotFailToEqualBool;
begin
  ExpectFail(procedure begin ExpectBool(True).Not_.ToEqualBool(True); end, LowerCase('not'));
end;

procedure TestNotFailToBeTrue;
begin
  ExpectFail(procedure begin { ToBeTrue delegates to ToEqualBool(True), message: 'Expected not True but got True' } ExpectBool(True).Not_.ToBeTrue; end, 'Expected not');
end;

procedure TestNotFailToBeFalse;
begin
  ExpectFail(procedure begin { ToBeFalse delegates to ToEqualBool(False), message: 'Expected not False but got False' } ExpectBool(False).Not_.ToBeFalse; end, 'Expected not');
end;

procedure TestNotFailToBeNil;
begin
  ExpectFail(procedure begin { Not_.ToBeNil on nil → 'Expected non-nil but got nil' } ExpectPtr(nil).Not_.ToBeNil; end, 'Expected non-nil but got nil');
end;

procedure TestNotFailToBeNotNil;
var
  LP: Pointer;
begin
  LP := @LP;
  { FPC internal error when LP is captured by anonymous closure — keep try/except }
  try
    ExpectPtr(LP).Not_.ToBeNotNil;
    Fail('expected Not_.ToBeNotNil fail');
  except
    on E: EAssertionFailed do
      Check(True, 'expected Not_.ToBeNotNil fail');
  end;
end;

procedure TestNotFailToContain;
begin
  ExpectFail(procedure begin Expect('hello').Not_.ToContain('ell'); end, 'should not contain');
end;

procedure TestNotFailToStartWith;
begin
  ExpectFail(procedure begin Expect('hello').Not_.ToStartWith('hel'); end, 'should not start');
end;

procedure TestNotFailToEndWith;
begin
  ExpectFail(procedure begin Expect('hello').Not_.ToEndWith('llo'); end, 'should not end');
end;

procedure TestNotFailToBeGreaterThan;
begin
  ExpectFail(procedure begin ExpectInt(10).Not_.ToBeGreaterThan(5); end, 'should not');
end;

procedure TestNotFailToBeLessThan;
begin
  ExpectFail(procedure begin ExpectInt(5).Not_.ToBeLessThan(10); end, 'should not');
end;

procedure TestNotFailToBeInRange;
begin
  ExpectFail(procedure begin ExpectInt(5).Not_.ToBeInRange(1, 10); end, 'should not');
end;

procedure TestNotFailToHaveLength;
begin
  ExpectFail(procedure begin Expect('abc').Not_.ToHaveLength(3); end, LowerCase('should not'));
end;

procedure TestNotFailToRaise;
begin
  ExpectFail(procedure begin ExpectProc(procedure begin StrToInt('bad'); end) .Not_.ToRaise(EConvertError); end, 'EConvertError');
end;

{ ── IExpectation failure path tests (B5.2) ────────────────────────────────── }

procedure TestFailToStartWith;
begin
  ExpectFail(procedure begin Expect('hello').ToStartWith('xyz'); end, 'does not start');
end;

procedure TestFailToEndWith;
begin
  ExpectFail(procedure begin Expect('hello').ToEndWith('xyz'); end, 'does not end');
end;

procedure TestFailToHaveLength;
begin
  ExpectFail(procedure begin Expect('abc').ToHaveLength(99); end, 'Expected length');
end;

procedure TestFailToBeFalse;
begin
  ExpectFail(procedure begin { ToBeFalse(True) → 'Expected False but got True' } ExpectBool(True).ToBeFalse; end, 'Expected False but got');
end;

procedure TestFailToBeNotNil;
begin
  ExpectFail(procedure begin { ToBeNotNil(nil) → 'Expected non-nil but got nil' } ExpectPtr(nil).ToBeNotNil; end, 'Expected non-nil but got nil');
end;

procedure TestFailToBeGreaterThan;
begin
  ExpectFail(procedure begin ExpectInt(1).ToBeGreaterThan(100); end, 'not >');
end;

procedure TestFailToBeLessThan;
begin
  ExpectFail(procedure begin ExpectInt(100).ToBeLessThan(1); end, 'not <');
end;

procedure TestFailToEqualBool;
begin
  ExpectFail(procedure begin { ToEqualBool(True, False) → 'Expected False but got True' } ExpectBool(True).ToEqualBool(False); end, 'Expected False but got');
end;

procedure TestFailToRaiseWithMsg;
begin
  ExpectFail(procedure begin ExpectProc(procedure begin StrToInt('bad'); end) .ToRaise(EConvertError, 'specific_mismatch_msg_xyz'); end, 'does not contain');
end;

procedure TestFailNotToEqualBool;
begin
  ExpectFail(procedure begin { Not_.ToEqualBool(False, False) → 'Expected not False but got False' } ExpectBool(False).Not_.ToEqualBool(False); end, 'Expected not False but got');
end;

procedure TestFailToBeNil;
begin
  ExpectFail(procedure begin { ToBeNil(non-nil) → 'Expected nil but got $...' } ExpectPtr(@TestFailToBeNil).ToBeNil; end, 'Expected nil but got');
end;

{ ── F10: Type mismatch error paths ────────────────────────────────────────── }

procedure TestTypeMismatchIntToEqual;
begin
  ExpectFail(procedure begin ExpectInt(42).ToEqual('hello'); end, 'requires string expectation');
end;

procedure TestTypeMismatchStrToEqualInt;
begin
  ExpectFail(procedure begin Expect('hello').ToEqualInt(42); end, 'requires integer expectation');
end;

procedure TestTypeMismatchStrToBeNil;
begin
  ExpectFail(procedure begin Expect('hello').ToBeNil; end, 'requires pointer expectation');
end;

procedure TestTypeMismatchStrToRaise;
begin
  ExpectFail(procedure begin Expect('hello').ToRaise(Exception); end, 'requires proc expectation');
end;

{ ── F12: Not_ positive pass paths ─────────────────────────────────────────── }

procedure TestNotPositivePassToBeNil;
var
  x: Integer = 1;
begin
  ExpectPtr(@x).Not_.ToBeNil;
end;

procedure TestNotPositivePassToBeTrue;
begin
  ExpectBool(False).Not_.ToBeTrue;
end;

procedure TestNotPositivePassToBeFalse;
begin
  ExpectBool(True).Not_.ToBeFalse;
end;

procedure TestNotPositivePassToBeGT;
begin
  ExpectInt(5).Not_.ToBeGreaterThan(10);
end;

procedure TestNotPositivePassToBeLT;
begin
  ExpectInt(10).Not_.ToBeLessThan(5);
end;

procedure TestNotPositivePassToBeInRange;
begin
  ExpectInt(100).Not_.ToBeInRange(1, 10);
end;

procedure TestNotPositivePassToHaveLength;
begin
  Expect('hello').Not_.ToHaveLength(3);
end;

procedure TestNotPositivePassToEqualBool;
begin
  ExpectBool(True).Not_.ToEqualBool(False);
end;

{ ── F04: ToNotRaise ───────────────────────────────────────────────────────── }

procedure TestToNotRaisePass;
begin
  ExpectProc(procedure begin end).ToNotRaise;
end;

procedure TestToNotRaiseFail;
begin
  ExpectFail(procedure begin ExpectProc(procedure begin StrToInt('bad'); end).ToNotRaise; end, 'no exception');
end;

{ ── F23: Not_.Not_ double negation ────────────────────────────────────────── }

procedure TestNotNotDoubleNegation;
begin
  { Not_.Not_ should cancel out → normal assertion }
  ExpectInt(1).Not_.Not_.ToEqualInt(1);
  Expect('hello').Not_.Not_.ToEqual('hello');
  ExpectBool(True).Not_.Not_.ToBeTrue;
  ExpectPtr(@TestNotNotDoubleNegation).Not_.Not_.ToBeNotNil;
end;

{ ── R2-F11: Not_.ToRaise semantic tests ────────────────────────────────────── }

procedure TestNotToRaisePass;
begin
  { Not_.ToRaise(EConvertError) + no exception → pass }
  ExpectProc(procedure begin end).Not_.ToRaise(EConvertError);
end;

procedure TestNotToRaiseFail;
begin
  { Not_.ToRaise(EConvertError) + EConvertError raised → fail }
  ExpectFail(procedure begin ExpectProc(procedure begin StrToInt('bad'); end).Not_.ToRaise(EConvertError); end, 'EConvertError');
end;

procedure TestNotToRaiseOtherException;
var
  LCaught: Boolean = False;
begin
  { Not_.ToRaise(EConvertError) + EAbort → re-raise (not swallowed) }
  try
    ExpectProc(procedure begin raise EAbort.Create('abort'); end)
      .Not_.ToRaise(EConvertError);
  except
    on E: EAbort do
      LCaught := True;
  end;
  if not LCaught then
  begin
    FailTest('EAbort should propagate through Not_.ToRaise');
  end;
end;

{ ── Double comparison semantics ──────────────────────────────────────────────
  ToBeNear(actual, tolerance):
    if tolerance > 0: uses IsNear(actual, expected, tolerance) — true when
      |actual - expected| <= tolerance (relative/absolute hybrid)
    if tolerance = 0: uses IsExact — IEEE bitwise comparison, only true for
      exact same bits (distinguishes +0.0/-0.0, NaN patterns, etc.)

  ⚠ IsExact(tolerance=0) is NOT "very tight tolerance" — it's bitwise identity.
     Use tolerance > 0 for normal floating-point comparisons.
     Example: ExpectDouble(0.3).ToBeNear(0.3, 0.0) might FAIL on some platforms
              because 0.3 cannot be represented exactly in IEEE 754.
 }
procedure TestExpectDouble;
begin
  ExpectDouble(1.0).ToBeNear(1.0);
  ExpectDouble(1.0).ToBeNear(1.0 + 1e-11, 1e-10);
  ExpectDouble(0.0).ToBeNear(1e-12, 1e-10);
end;

procedure TestExpectDoubleNotNear;
begin
  ExpectDouble(1.0).ToNotBeNear(2.0);
  ExpectDouble(0.0).ToNotBeNear(1.0, 1e-10);
end;

procedure TestExpectDoubleNotNearDoesNotMutateExpectation;
var
  LExpectation: IExpectation;
begin
  LExpectation := ExpectDouble(1.0);
  LExpectation.ToNotBeNear(2.0, 1e-10);
  LExpectation.ToBeNear(1.0, 1e-10);
end;

procedure TestExpectDoubleFailToBeNear;
begin
  ExpectFail(procedure begin ExpectDouble(1.0).ToBeNear(2.0, 1e-10); end, 'Expected');
end;

procedure TestExpectDoubleFailNotToBeNear;
begin
  ExpectFail(procedure begin ExpectDouble(1.0).ToNotBeNear(1.0, 1e-10); end, 'not near');
end;

procedure TestExpectDoubleNotNegation;
begin
  ExpectDouble(1.0).Not_.ToBeNear(2.0, 1e-10);
  ExpectDouble(1.0).Not_.ToNotBeNear(1.0, 1e-10);
end;

procedure TestExpectDoubleTypeMismatch;
begin
  ExpectFail(procedure begin ExpectDouble(1.0).ToEqualInt(1); end, 'requires integer expectation');
end;

{ ── R2-F15: NaN/Infinity/Int64 boundary ────────────────────────────────────── }

procedure TestExpectDoubleNaN;
var
  LNaN: Double;
  LOldMask: TFPUExceptionMask;
begin
  LNaN := 0.0;
  { Generate NaN without triggering EInvalidOp }
  LOldMask := GetExceptionMask;
  SetExceptionMask([exInvalidOp, exZeroDivide, exOverflow, exUnderflow, exPrecision, exDenormalized]);
  LNaN := 0.0/0.0;
  { NaN guard: all ordered/near comparisons must fail, even with Not_ }
  ExpectFail(procedure begin ExpectDouble(LNaN).ToBeNear(0.0, 1e-10); end, 'NaN');
  ExpectFail(procedure begin ExpectDouble(LNaN).Not_.ToBeNear(0.0, 1e-10); end, 'NaN');
  ExpectFail(procedure begin ExpectDouble(LNaN).ToBeGreaterThanD(0.0); end, 'NaN');
  ExpectFail(procedure begin ExpectDouble(LNaN).Not_.ToBeGreaterThanD(0.0); end, 'NaN');
  ExpectFail(procedure begin ExpectDouble(LNaN).ToBeLessThanD(0.0); end, 'NaN');
  ExpectFail(procedure begin ExpectDouble(LNaN).Not_.ToBeLessThanD(0.0); end, 'NaN');
  ExpectFail(procedure begin ExpectDouble(LNaN).ToBeGreaterOrEqualD(0.0); end, 'NaN');
  ExpectFail(procedure begin ExpectDouble(LNaN).Not_.ToBeGreaterOrEqualD(0.0); end, 'NaN');
  ExpectFail(procedure begin ExpectDouble(LNaN).ToBeLessOrEqualD(0.0); end, 'NaN');
  ExpectFail(procedure begin ExpectDouble(LNaN).Not_.ToBeLessOrEqualD(0.0); end, 'NaN');
  ExpectFail(procedure begin ExpectDouble(LNaN).ToBeInRangeD(0.0, 1.0); end, 'NaN');
  ExpectFail(procedure begin ExpectDouble(LNaN).Not_.ToBeInRangeD(0.0, 1.0); end, 'NaN');
  SetExceptionMask(LOldMask);
end;

procedure TestExpectDoubleInfinity;
var
  LInf: Double;
  LOldMask: TFPUExceptionMask;
begin
  LInf := 1.0;
  { Generate +Inf and evaluate near-ness without triggering EInvalidOp }
  LOldMask := GetExceptionMask;
  SetExceptionMask([exInvalidOp, exZeroDivide, exOverflow, exUnderflow, exPrecision, exDenormalized]);
  LInf := 1.0/0.0;
  { +Inf is near +Inf (same value) }
  ExpectDouble(LInf).ToBeNear(LInf, 0.0);
  { +Inf is not near any finite value }
  ExpectDouble(LInf).Not_.ToBeNear(1e308, 1e308);
  SetExceptionMask(LOldMask);
end;

procedure TestExpectDoubleInfinityComparison;
var
  LInf: Double;
  LOldMask: TFPUExceptionMask;
begin
  LOldMask := GetExceptionMask;
  SetExceptionMask([exInvalidOp, exZeroDivide, exOverflow, exUnderflow, exPrecision, exDenormalized]);
  LInf := 1.0 / 0.0;
  { +Inf > any finite }
  ExpectDouble(LInf).ToBeGreaterThanD(1e308);
  ExpectDouble(1e308).ToBeLessThanD(LInf);
  ExpectDouble(LInf).ToBeGreaterOrEqualD(LInf);
  ExpectDouble(LInf).ToBeLessOrEqualD(LInf);
  ExpectDouble(LInf).ToBeInRangeD(0.0, LInf);
  SetExceptionMask(LOldMask);
end;

procedure TestExpectDoubleNegativeZero;
begin
  { IEEE 754: -0.0 = +0.0 }
  ExpectDouble(0.0).ToBeNear(-0.0, 0.0);
  ExpectDouble(-0.0).ToEqualD(0.0, 0.0);
end;

procedure TestExpectIntMaxMin;
begin
  { Int64 boundary values }
  ExpectInt(High(Int64)).ToEqualInt(High(Int64));
  ExpectInt(Low(Int64)).ToEqualInt(Low(Int64));
  ExpectInt(High(Int64)).Not_.ToEqualInt(Low(Int64));
  ExpectInt(High(Int64)).ToBeGreaterThan(High(Int64) - 1);
  ExpectInt(Low(Int64)).ToBeLessThan(Low(Int64) + 1);
end;

{ ── R2-F27: ToNotRaise / Not_.ToNotRaise semantics ────────────────────────── }
{ NOTE: ToNotRaise does NOT honor FNegated.  Not_.ToNotRaise behaves identically
  to ToNotRaise (both assert "no exception").  These tests verify this limitation. }

procedure TestNotToNotRaiseSameAsToNotRaise;
begin
  { Not_.ToNotRaise is now an error — fails with diagnostic message }
  ExpectFail(procedure begin
    ExpectProc(procedure begin end).Not_.ToNotRaise;
  end, 'ToRaise');
end;

procedure TestNotToNotRaiseAlwaysExpectsNoException;
begin
  { Not_.ToNotRaise fails before even running the proc — diagnostic message }
  ExpectFail(procedure begin
    ExpectProc(procedure begin StrToInt('bad'); end).Not_.ToNotRaise;
  end, 'ToRaise');
end;

{ R6-44: Type mismatch edge cases — verify EAssertionFailed with type hint }

procedure TestExpectIntToBeNearTypeMismatch;
begin
  { ExpectInt creates ekInt, ToBeNear requires ekDouble → type mismatch }
  ExpectFail(procedure begin ExpectInt(42).ToBeNear(42.0, 1.0); end, 'requires double expectation');
end;

procedure TestExpectPtrToEqualIntTypeMismatch;
begin
  { ExpectPtr creates ekPtr, ToEqualInt requires ekInt → type mismatch }
  ExpectFail(procedure begin ExpectPtr(nil).ToEqualInt(0); end, 'requires integer expectation');
end;

{ R6-45: Not_.ToBeNear combination }

procedure TestNotToBeNearWithinEpsilonShouldFail;
begin
  { Value is within epsilon → Not_ should negate to fail }
  ExpectFail(procedure begin ExpectDouble(1.0).Not_.ToBeNear(1.0, 0.01); end, LowerCase('not'));
end;

procedure TestNotToBeNearOutsideEpsilonShouldPass;
begin
  { Value outside epsilon → Not_ should negate to pass }
  ExpectDouble(1.0).Not_.ToBeNear(2.0, 0.01);
end;

procedure TestNotToNotBeNearCombination;
begin
  { Not_.ToNotBeNear: value is near → ToNotBeNear would fail → Not_ inverts → pass }
  ExpectDouble(1.0).Not_.ToNotBeNear(1.0, 0.01);
  { Not_.ToNotBeNear: value is not near → ToNotBeNear would pass → Not_ inverts → fail }
  ExpectFail(procedure begin ExpectDouble(1.0).Not_.ToNotBeNear(100.0, 0.01); end);
end;

{ ── v3.1: New Expect API tests ─────────────────────────────────────────────── }

procedure TestExpectGreaterOrEqual;
begin
  ExpectInt(5).ToBeGreaterOrEqual(5);
  ExpectInt(5).ToBeGreaterOrEqual(4);
  ExpectFail(procedure begin ExpectInt(4).ToBeGreaterOrEqual(5); end, 'is not >=');
end;

procedure TestExpectLessOrEqual;
begin
  ExpectInt(5).ToBeLessOrEqual(5);
  ExpectInt(4).ToBeLessOrEqual(5);
  ExpectFail(procedure begin ExpectInt(5).ToBeLessOrEqual(4); end, 'is not <=');
end;

procedure TestExpectDoubleGreaterThan;
begin
  ExpectDouble(5.5).ToBeGreaterThanD(5.0);
  ExpectFail(procedure begin ExpectDouble(5.0).ToBeGreaterThanD(5.0); end);
end;

procedure TestExpectDoubleLessThan;
begin
  ExpectDouble(4.5).ToBeLessThanD(5.0);
  ExpectFail(procedure begin ExpectDouble(5.0).ToBeLessThanD(5.0); end);
end;

procedure TestExpectDoubleGreaterOrEqual;
begin
  ExpectDouble(5.0).ToBeGreaterOrEqualD(5.0);
  ExpectDouble(5.1).ToBeGreaterOrEqualD(5.0);
  ExpectFail(procedure begin ExpectDouble(4.9).ToBeGreaterOrEqualD(5.0); end);
end;

procedure TestExpectDoubleLessOrEqual;
begin
  ExpectDouble(5.0).ToBeLessOrEqualD(5.0);
  ExpectDouble(4.9).ToBeLessOrEqualD(5.0);
  ExpectFail(procedure begin ExpectDouble(5.1).ToBeLessOrEqualD(5.0); end);
end;

procedure TestExpectDoubleInRange;
begin
  ExpectDouble(5.0).ToBeInRangeD(1.0, 10.0);
  ExpectDouble(1.0).ToBeInRangeD(1.0, 10.0);
  ExpectDouble(10.0).ToBeInRangeD(1.0, 10.0);
  ExpectFail(procedure begin ExpectDouble(11.0).ToBeInRangeD(1.0, 10.0); end);
end;

procedure TestExpectContainCI;
begin
  Expect('Hello World').ToContainCI('hello');
  Expect('Hello World').ToContainCI('WORLD');
  ExpectFail(procedure begin Expect('Hello').ToContainCI('xyz'); end);
  { P0 fix: empty needle with Not_ should fail (empty matches everything) }
  ExpectFail(procedure begin Expect('abc').Not_.ToContainCI(''); end,
    'should not contain (ci)');
end;

procedure TestExpectStartWithCI;
begin
  Expect('Hello World').ToStartWithCI('hello');
  ExpectFail(procedure begin Expect('Hello World').ToStartWithCI('world'); end);
end;

procedure TestExpectEndWithCI;
begin
  Expect('Hello World').ToEndWithCI('WORLD');
  ExpectFail(procedure begin Expect('Hello World').ToEndWithCI('hello'); end);
end;

procedure TestExpectGreaterOrEqualNot;
begin
  ExpectInt(4).Not_.ToBeGreaterOrEqual(5);
  ExpectFail(procedure begin ExpectInt(5).Not_.ToBeGreaterOrEqual(5); end);
end;

procedure TestExpectLessOrEqualNot;
{ G1: Not_.ToBeLessOrEqual negation path }
begin
  { 4 <= 5 is true → Not_ inverts → pass }
  ExpectInt(5).Not_.ToBeLessOrEqual(4);
  { 5 <= 5 is true → Not_ inverts → fail }
  ExpectFail(procedure begin ExpectInt(5).Not_.ToBeLessOrEqual(5); end);
end;

procedure TestExpectDoubleGreaterOrEqualNot;
{ G1: Not_.ToBeGreaterOrEqualD negation path }
begin
  ExpectDouble(4.9).Not_.ToBeGreaterOrEqualD(5.0);
  ExpectFail(procedure begin ExpectDouble(5.0).Not_.ToBeGreaterOrEqualD(5.0); end);
end;

procedure TestExpectDoubleLessOrEqualNot;
{ G1: Not_.ToBeLessOrEqualD negation path }
begin
  ExpectDouble(5.1).Not_.ToBeLessOrEqualD(5.0);
  ExpectFail(procedure begin ExpectDouble(5.0).Not_.ToBeLessOrEqualD(5.0); end);
end;

procedure TestExpectDoubleInRangeNot;
{ G1: Not_.ToBeInRangeD negation path }
begin
  { Outside range → Not_ inverts → pass }
  ExpectDouble(9.9).Not_.ToBeInRangeD(0.0, 9.0);
  { Inside range → Not_ inverts → fail }
  ExpectFail(procedure begin ExpectDouble(5.0).Not_.ToBeInRangeD(0.0, 9.0); end);
end;

procedure TestExpectContainCINot;
{ G1: Not_.ToContainCI negation path }
begin
  Expect('Hello World').Not_.ToContainCI('xyz');
  ExpectFail(procedure begin Expect('Hello World').Not_.ToContainCI('hello'); end);
end;

procedure TestExpectStartWithCINot;
{ G1: Not_.ToStartWithCI negation path }
begin
  Expect('Hello World').Not_.ToStartWithCI('world');
  ExpectFail(procedure begin Expect('Hello World').Not_.ToStartWithCI('hello'); end);
end;

procedure TestExpectEndWithCINot;
{ G1: Not_.ToEndWithCI negation path }
begin
  Expect('Hello World').Not_.ToEndWithCI('hello');
  ExpectFail(procedure begin Expect('Hello World').Not_.ToEndWithCI('WORLD'); end);
end;

procedure TestExpectToRaiseNilClass;
{ P0: ToRaise(nil) must fail gracefully, not SIGSEGV }
begin
  ExpectFail(procedure begin
    ExpectProc(procedure begin end).ToRaise(nil);
  end, 'nil');
end;

{ ── F5/F6: New API — ToBeSame, ToEqualPointer, ToEqualD ───────────────────── }

procedure TestExpectToBeSamePass;
var
  LP: Pointer;
begin
  LP := @LP;
  ExpectPtr(LP).ToBeSame(LP);
  ExpectPtr(nil).ToBeSame(nil);
end;

procedure TestExpectToBeSameFail;
var
  LA, LB: Integer;
begin
  LA := 1; LB := 2;
  ExpectFail(procedure begin ExpectPtr(@LA).ToBeSame(@LB); end);
end;

procedure TestExpectToBeSameNot;
var
  LA, LB: Integer;
begin
  LA := 1; LB := 2;
  ExpectPtr(@LA).Not_.ToBeSame(@LB);
end;

procedure TestExpectToBeSameMessageCorrectness;
var
  LA, LB: Integer;
begin
  LA := 1; LB := 2;
  { Negative fail: Not_.ToBeSame with same pointer → message should say "both are" }
  ExpectFail(procedure begin ExpectPtr(@LA).Not_.ToBeSame(@LA); end, 'both are');
end;

procedure TestExpectToNotBeNearReturnsExpectation;
var
  LResult: IExpectation;
begin
  { ToNotBeNear must return IExpectation for chaining }
  LResult := ExpectDouble(1.0).ToNotBeNear(2.0);
  ExpectBool(LResult <> nil).ToBeTrue;
end;

procedure TestExpectToEqualPointerIsAlias;
var
  LP: Pointer;
begin
  LP := @LP;
  ExpectPtr(LP).ToEqualPointer(LP);
end;

procedure TestExpectToEqualDPass;
begin
  ExpectDouble(1.0).ToEqualD(1.0);
  ExpectDouble(1.0).ToEqualD(1.0 + 1e-11);
  ExpectDouble(1.0).ToEqualD(1.0, 1e-6);
end;

procedure TestExpectToEqualDFail;
begin
  ExpectFail(procedure begin ExpectDouble(1.0).ToEqualD(2.0); end);
end;

procedure TestExpectToEqualDNot;
begin
  ExpectDouble(1.0).Not_.ToEqualD(2.0);
  ExpectFail(procedure begin ExpectDouble(1.0).Not_.ToEqualD(1.0); end);
end;

procedure TestExpectToEqualDNaN;
var
  LNaN: Double;
  LOldMask: TFPUExceptionMask;
begin
  LOldMask := GetExceptionMask;
  SetExceptionMask([exInvalidOp, exZeroDivide, exOverflow, exUnderflow, exPrecision, exDenormalized]);
  LNaN := 0.0 / 0.0;
  ExpectFail(procedure begin ExpectDouble(LNaN).ToEqualD(0.0); end, 'NaN');
  ExpectFail(procedure begin ExpectDouble(0.0).ToEqualD(LNaN); end, 'NaN');
  SetExceptionMask(LOldMask);
end;

procedure TestExpectToEqualDEpsilonBoundary;
begin
  { Diff slightly less than epsilon — should pass }
  ExpectDouble(1.0).ToEqualD(1.0 + 9.99e-11, 1e-10);
  ExpectDouble(1.0).ToEqualD(1.0 - 9.99e-11, 1e-10);
  { Diff exactly equal to epsilon — test with integer multiples to avoid FP rounding }
  ExpectDouble(100.0).ToEqualD(100.0 + 1e-6, 1e-6);
  ExpectDouble(100.0).ToEqualD(100.0 - 1e-6, 1e-6);
  { Diff > epsilon → should fail }
  ExpectFail(procedure begin ExpectDouble(1.0).ToEqualD(1.0 + 1.01e-10, 1e-10); end);
end;

{ ── ToBeNearRel / ToNotBeNearRel ─────────────────────────────────────────── }

procedure TestExpectToBeNearRelPass;
begin
  ExpectDouble(1e15).ToBeNearRel(1e15 + 1e5, 1e-9);
  ExpectDouble(1.0).ToBeNearRel(1.0 + 1e-10, 1e-9);
  ExpectDouble(42.0).ToBeNearRel(42.0);
  ExpectDouble(0.0).ToBeNearRel(1e-12, 1e-9);
end;

procedure TestExpectToBeNearRelFail;
begin
  ExpectFail(procedure begin ExpectDouble(1e15).ToBeNearRel(1e15 + 1e10, 1e-9); end, 'Expected');
  ExpectFail(procedure begin ExpectDouble(1.0).ToBeNearRel(2.0, 1e-9); end, 'Expected');
end;

procedure TestExpectToNotBeNearRelPass;
begin
  ExpectDouble(1.0).ToNotBeNearRel(2.0, 1e-9);
  ExpectDouble(1e15).ToNotBeNearRel(2e15, 1e-9);
end;

procedure TestExpectToNotBeNearRelFail;
begin
  ExpectFail(procedure begin ExpectDouble(1.0).ToNotBeNearRel(1.0, 1e-9); end, 'not near');
end;

procedure TestExpectToBeNearRelNot;
begin
  ExpectDouble(1.0).Not_.ToBeNearRel(2.0, 1e-9);
  ExpectFail(procedure begin ExpectDouble(1.0).Not_.ToBeNearRel(1.0, 1e-9); end, 'not near');
end;

{ ── ExpectStr alias ──────────────────────────────────────────────────────── }

procedure TestExpectStrAlias;
begin
  ExpectStr('hello').ToEqual('hello');
  ExpectStr('abc').ToContain('b');
  ExpectStr('abc').ToStartWith('a');
  ExpectStr('abc').ToEndWith('c');
end;

{ E-10: ToBeNaN / ToBeNotNaN coverage }

procedure TestExpectToBeNaNPass;
var
  LNaN: Double;
begin
  LNaN := 0.0/0.0;
  ExpectDouble(LNaN).ToBeNaN;
end;

procedure TestExpectToBeNaNFail;
begin
  ExpectFail(procedure begin ExpectDouble(1.0).ToBeNaN; end, 'NaN');
end;

procedure TestExpectToBeNotNaNPass;
begin
  ExpectDouble(1.0).ToBeNotNaN;
end;

procedure TestExpectToBeNotNaNFail;
var
  LNaN: Double;
begin
  LNaN := 0.0/0.0;
  ExpectFail(procedure begin ExpectDouble(LNaN).ToBeNotNaN; end, 'NaN');
end;

procedure TestExpectToBeNaNNot;
var
  LNaN: Double;
begin
  LNaN := 0.0/0.0;
  ExpectFail(procedure begin ExpectDouble(LNaN).Not_.ToBeNaN; end, 'non-NaN');
end;

procedure TestExpectToBeNotNaNNot;
begin
  ExpectFail(procedure begin ExpectDouble(1.0).Not_.ToBeNotNaN; end, 'NaN');
end;

{ E-10: Chaining returns self }

procedure TestExpectChainingReturnsSelf;
var
  LExp: IExpectation;
begin
  { All methods should return the same IExpectation for chaining }
  LExp := Expect('hello');
  CheckTrue(LExp.ToEqual('hello') = LExp, 'ToEqual should return self');
  LExp := ExpectBool(True);
  CheckTrue(LExp.ToBeTrue = LExp, 'ToBeTrue should return self');
  LExp := ExpectDouble(1.0);
  CheckTrue(LExp.ToBeNear(1.0) = LExp, 'ToBeNear should return self');
end;

{ ── WithMessage, ToEqualBytes, ToFailUnexpected ─────────────────────────── }

procedure TestExpectWithMessageFail;
begin
  ExpectFail(
    procedure begin
      ExpectStr('hello').WithMessage('greeting').ToEqual('world');
    end, 'greeting');
end;

procedure TestExpectWithMessagePass;
begin
  { WithMessage should not affect passing assertions }
  ExpectStr('hello').WithMessage('greeting').ToEqual('hello');
end;

procedure TestExpectWithMessageNot;
begin
  ExpectFail(
    procedure begin
      ExpectStr('hello').WithMessage('neg').Not_.ToEqual('hello');
    end, 'neg');
end;

procedure TestExpectWithMessageChain;
begin
  { WithMessage persists through the chain }
  ExpectFail(
    procedure begin
      ExpectStr('hello').WithMessage('chain').ToContain('xyz');
    end, 'chain');
end;

procedure TestExpectToEqualBytesPass;
var
  LA, LB: TBytes;
begin
  LA := TBytes.Create($01, $02, $03);
  LB := TBytes.Create($01, $02, $03);
  ExpectBytes(LA).ToEqualBytes(LB);
end;

procedure TestExpectToEqualBytesFail;
var
  LA, LB: TBytes;
begin
  LA := TBytes.Create($01, $02, $03);
  LB := TBytes.Create($01, $FF, $03);
  ExpectFail(
    procedure begin
      ExpectBytes(LA).ToEqualBytes(LB);
    end, 'index');
end;

procedure TestExpectToEqualBytesDiffLen;
var
  LA, LB: TBytes;
begin
  LA := TBytes.Create($01, $02);
  LB := TBytes.Create($01, $02, $03);
  ExpectFail(
    procedure begin
      ExpectBytes(LA).ToEqualBytes(LB);
    end, 'bytes');
end;

procedure TestExpectToEqualBytesEmpty;
var
  LA, LB: TBytes;
begin
  SetLength(LA, 0);
  SetLength(LB, 0);
  ExpectBytes(LA).ToEqualBytes(LB);
end;

procedure TestExpectToEqualBytesNot;
var
  LA, LB: TBytes;
begin
  LA := TBytes.Create($01, $02);
  LB := TBytes.Create($03, $04);
  ExpectBytes(LA).Not_.ToEqualBytes(LB);
end;

procedure TestExpectToFailUnexpected;
begin
  ExpectFail(
    procedure begin
      ExpectStr('x').ToFailUnexpected('boom');
    end, 'boom');
end;

procedure TestExpectToFailUnexpectedDefault;
begin
  ExpectFail(
    procedure begin
      ExpectStr('x').ToFailUnexpected;
    end, 'unexpected');
end;

procedure TestExpectToFailUnexpectedWithMessage;
begin
  ExpectFail(
    procedure begin
      ExpectStr('x').WithMessage('ctx').ToFailUnexpected('boom');
    end, 'ctx');
end;

{ ── ToBeOneOf tests ─────────────────────────────────────────────────────── }

procedure TestToBeOneOfPass;
begin
  ExpectStr('hello').ToBeOneOf(['hello', 'world', 'foo']);
  ExpectStr('world').ToBeOneOf(['hello', 'world', 'foo']);
end;

procedure TestToBeOneOfFail;
begin
  ExpectFail(procedure begin
    ExpectStr('baz').ToBeOneOf(['hello', 'world', 'foo']);
  end, 'not one of');
end;

procedure TestToBeOneOfNotPass;
begin
  ExpectStr('baz').Not_.ToBeOneOf(['hello', 'world', 'foo']);
end;

procedure TestToBeOneOfNotFail;
begin
  ExpectFail(procedure begin
    ExpectStr('hello').Not_.ToBeOneOf(['hello', 'world', 'foo']);
  end, 'should not be one of');
end;

procedure TestToBeOneOfIntPass;
begin
  ExpectInt(42).ToBeOneOfInt([10, 20, 42, 50]);
end;

procedure TestToBeOneOfIntFail;
begin
  ExpectFail(procedure begin
    ExpectInt(99).ToBeOneOfInt([10, 20, 42, 50]);
  end, '99');
end;

procedure TestToBeOneOfBoolPass;
begin
  ExpectBool(True).ToBeOneOfBool([True, False]);
  ExpectBool(False).ToBeOneOfBool([True, False]);
end;

procedure TestToBeOneOfBoolFail;
begin
  ExpectFail(procedure begin
    ExpectBool(True).ToBeOneOfBool([False]);
  end, 'True');
end;

procedure TestToBeOneOfWithMessage;
begin
  ExpectFail(procedure begin
    ExpectStr('x').WithMessage('pick one').ToBeOneOf(['a', 'b']);
  end, 'pick one');
end;

{ ── R60: ToBeEmpty/ToBeNotEmpty + ToContain(Byte) + ToMatch + array tests ── }

procedure TestToBeEmptyString;
begin
  Expect('').ToBeEmpty;
  ExpectFail(procedure begin Expect('x').ToBeEmpty; end, 'empty');
end;

procedure TestToBeNotEmptyString;
begin
  Expect('x').ToBeNotEmpty;
  ExpectFail(procedure begin Expect('').ToBeNotEmpty; end, 'empty');
end;

procedure TestToBeEmptyIntArray;
begin
  ExpectArrayOfInt([]).ToBeEmpty;
  ExpectFail(procedure begin ExpectArrayOfInt([1]).ToBeEmpty; end, 'empty');
end;

procedure TestToBeNotEmptyIntArray;
begin
  ExpectArrayOfInt([1,2]).ToBeNotEmpty;
  ExpectFail(procedure begin ExpectArrayOfInt([]).ToBeNotEmpty; end, 'empty');
end;

procedure TestToBeEmptyStrArray;
begin
  ExpectArrayOfStr([]).ToBeEmpty;
  ExpectFail(procedure begin ExpectArrayOfStr(['a']).ToBeEmpty; end, 'empty');
end;

procedure TestToBeEmptyBytes;
begin
  ExpectBytes(TBytes([])).ToBeEmpty;
  ExpectFail(procedure begin ExpectBytes(TBytes([$01])).ToBeEmpty; end, 'empty');
end;

procedure TestToBeNotEmptyBytes;
begin
  ExpectBytes(TBytes([$01])).ToBeNotEmpty;
  ExpectFail(procedure begin ExpectBytes(TBytes([])).ToBeNotEmpty; end, 'empty');
end;

procedure TestNotToBeEmpty;
begin
  Expect('x').Not_.ToBeEmpty;
  ExpectFail(procedure begin Expect('').Not_.ToBeEmpty; end, 'non-empty');
end;

procedure TestToEqualIntArrayPass;
begin
  ExpectArrayOfInt([1,2,3]).ToEqualIntArray([1,2,3]);
  ExpectArrayOfInt([]).ToEqualIntArray([]);
end;

procedure TestToEqualIntArrayFail;
begin
  ExpectFail(procedure begin
    ExpectArrayOfInt([1,2]).ToEqualIntArray([1,3]);
  end, 'differ');
end;

procedure TestToEqualIntArrayDiffLen;
begin
  ExpectFail(procedure begin
    ExpectArrayOfInt([1,2]).ToEqualIntArray([1,2,3]);
  end, 'length');
end;

procedure TestToEqualIntArrayNot;
begin
  ExpectArrayOfInt([1,2]).Not_.ToEqualIntArray([1,3]);
  ExpectArrayOfInt([1,2]).Not_.ToEqualIntArray([1,2,3]);
end;

procedure TestToEqualStrArrayPass;
begin
  ExpectArrayOfStr(['a','b']).ToEqualStrArray(['a','b']);
end;

procedure TestToEqualStrArrayFail;
begin
  ExpectFail(procedure begin
    ExpectArrayOfStr(['a','b']).ToEqualStrArray(['a','c']);
  end, 'differ');
end;

procedure TestToEqualStrArrayNot;
begin
  ExpectArrayOfStr(['a','b']).Not_.ToEqualStrArray(['a','c']);
  ExpectArrayOfStr(['a','b']).Not_.ToEqualStrArray(['a','b','c']);
end;

procedure TestToContainIntPass;
begin
  ExpectArrayOfInt([1,2,3]).ToContainInt(2);
end;

procedure TestToContainIntFail;
begin
  ExpectFail(procedure begin
    ExpectArrayOfInt([1,2,3]).ToContainInt(99);
  end, '99');
end;

procedure TestToContainIntNot;
begin
  ExpectArrayOfInt([1,2,3]).Not_.ToContainInt(99);
  ExpectFail(procedure begin
    ExpectArrayOfInt([1,2,3]).Not_.ToContainInt(2);
  end, '2');
end;

procedure TestToContainStrPass;
begin
  ExpectArrayOfStr(['a','b','c']).ToContainStr('b');
end;

procedure TestToContainStrFail;
begin
  ExpectFail(procedure begin
    ExpectArrayOfStr(['a','b']).ToContainStr('z');
  end, 'z');
end;

procedure TestToContainBytePass;
begin
  ExpectBytes(TBytes([$01,$02,$03])).ToContain($02);
end;

procedure TestToContainByteFail;
begin
  ExpectFail(procedure begin
    ExpectBytes(TBytes([$01,$02])).ToContain($FF);
  end, '$FF');
end;

procedure TestToContainByteNot;
begin
  ExpectBytes(TBytes([$01,$02])).Not_.ToContain($FF);
  ExpectFail(procedure begin
    ExpectBytes(TBytes([$01,$02])).Not_.ToContain($01);
  end, '$01');
end;

procedure TestToMatchPass;
begin
  ExpectStr('hello123').ToMatch('^\w+\d+$');
end;

procedure TestToMatchFail;
begin
  ExpectFail(procedure begin
    ExpectStr('hello').ToMatch('^\d+$');
  end, 'pattern');
end;

procedure TestToMatchNot;
begin
  ExpectStr('hello').Not_.ToMatch('^\d+$');
  ExpectFail(procedure begin
    ExpectStr('123').Not_.ToMatch('^\d+$');
  end, 'pattern');
end;

{ ── ToBeSorted tests ──────────────────────────────────────────────────────── }

procedure TestToBeSortedIntPass;
begin
  ExpectArrayOfInt([1, 2, 3, 4, 5]).ToBeSorted;
end;

procedure TestToBeSortedIntFail;
begin
  ExpectFail(procedure begin
    ExpectArrayOfInt([1, 3, 2, 4]).ToBeSorted;
  end, 'not sorted');
end;

procedure TestToBeSortedIntEmpty;
begin
  ExpectArrayOfInt([]).ToBeSorted;
end;

procedure TestToBeSortedIntSingle;
begin
  ExpectArrayOfInt([42]).ToBeSorted;
end;

procedure TestToBeSortedIntEqual;
begin
  ExpectArrayOfInt([3, 3, 3]).ToBeSorted;
end;

procedure TestToBeSortedIntNot;
begin
  ExpectFail(procedure begin
    ExpectArrayOfInt([1, 2, 3]).Not_.ToBeSorted;
  end, 'sorted');
end;

procedure TestToBeSortedStrPass;
begin
  ExpectArrayOfStr(['a', 'b', 'c']).ToBeSorted;
end;

procedure TestToBeSortedStrFail;
begin
  ExpectFail(procedure begin
    ExpectArrayOfStr(['c', 'a', 'b']).ToBeSorted;
  end, 'not sorted');
end;

procedure TestToBeSortedStrEmpty;
begin
  ExpectArrayOfStr([]).ToBeSorted;
end;

{ ── Main ──────────────────────────────────────────────────────────────────── }

var
  LSuite: TTestSuite;
begin
  WriteLn('=== test_expect ===');
  LSuite := TTestSuite.Create('IExpectation API');

  LSuite.Test('Expect string',           @TestExpectString);
  LSuite.Test('Expect int',              @TestExpectInt);
  LSuite.Test('Expect bool',             @TestExpectBool);
  LSuite.Test('Expect ptr',              @TestExpectPtr);
  LSuite.Test('Expect Not_ string',      @TestExpectNotString);
  LSuite.Test('Expect Not_ int',         @TestExpectNotInt);
  LSuite.Test('Expect Not_ bool',        @TestExpectNotBool);
  LSuite.Test('Expect Not_ ptr',         @TestExpectNotPtr);
  LSuite.Test('Expect proc raise',       @TestExpectProcRaise);
  LSuite.Test('Expect proc not raise',   @TestExpectProcNotRaise);
  LSuite.Test('Not_.ToBeNotNil',         @TestExpectNotToBeNotNil);
  LSuite.Test('Not_ state reset',        @TestExpectNotStateReset);

  { Failure path tests }
  LSuite.Test('Fail: ToEqual wrong',       @TestExpectStringFailToEqual);
  LSuite.Test('Fail: Not_ ToEqual same',   @TestExpectStringFailNotToEqual);
  LSuite.Test('Fail: ToEqualInt wrong',    @TestExpectIntFailToEqual);
  LSuite.Test('Fail: ToBeTrue on False',   @TestExpectBoolFailToBeTrue);
  LSuite.Test('Fail: ToBeNil on ptr',      @TestExpectPtrFailToBeNil);
  LSuite.Test('Fail: ToContain miss',      @TestExpectContainFail);
  LSuite.Test('Fail: ToBeInRange OOB',     @TestExpectRangeFail);
  LSuite.Test('Fail: ToBeInRange inverted', @TestExpectRangeInverted);
  LSuite.Test('Fail: ToRaise no raise',    @TestExpectRaiseFail);
  LSuite.Test('Fail: ToStartWith wrong',   @TestFailToStartWith);
  LSuite.Test('Fail: ToEndWith wrong',     @TestFailToEndWith);
  LSuite.Test('Fail: ToHaveLength wrong',  @TestFailToHaveLength);
  LSuite.Test('Fail: ToBeFalse on True',   @TestFailToBeFalse);
  LSuite.Test('Fail: ToBeNotNil on nil',   @TestFailToBeNotNil);
  LSuite.Test('Fail: ToBeGT too small',    @TestFailToBeGreaterThan);
  LSuite.Test('Fail: ToBeLT too large',    @TestFailToBeLessThan);
  LSuite.Test('Fail: ToEqualBool wrong',   @TestFailToEqualBool);
  LSuite.Test('Fail: ToRaise msg mismatch',@TestFailToRaiseWithMsg);
  LSuite.Test('Fail: Not_ ToEqualBool same', @TestFailNotToEqualBool);
  LSuite.Test('Fail: ToBeNil non-nil',     @TestFailToBeNil);

  { Not_ failure path tests (B5.1) }
  LSuite.Test('Not_ fail: ToEqualInt',     @TestNotFailToEqualInt);
  LSuite.Test('Not_ fail: ToEqualBool',    @TestNotFailToEqualBool);
  LSuite.Test('Not_ fail: ToBeTrue',       @TestNotFailToBeTrue);
  LSuite.Test('Not_ fail: ToBeFalse',      @TestNotFailToBeFalse);
  LSuite.Test('Not_ fail: ToBeNil',        @TestNotFailToBeNil);
  LSuite.Test('Not_ fail: ToBeNotNil',     @TestNotFailToBeNotNil);
  LSuite.Test('Not_ fail: ToContain',      @TestNotFailToContain);
  LSuite.Test('Not_ fail: ToStartWith',    @TestNotFailToStartWith);
  LSuite.Test('Not_ fail: ToEndWith',      @TestNotFailToEndWith);
  LSuite.Test('Not_ fail: ToBeGT',         @TestNotFailToBeGreaterThan);
  LSuite.Test('Not_ fail: ToBeLT',         @TestNotFailToBeLessThan);
  LSuite.Test('Not_ fail: ToBeInRange',    @TestNotFailToBeInRange);
  LSuite.Test('Not_ fail: ToHaveLength',   @TestNotFailToHaveLength);
  LSuite.Test('Not_ fail: ToRaise',        @TestNotFailToRaise);

  { F10: Type mismatch error paths }
  LSuite.Test('Type: Int→ToEqual(str)',    @TestTypeMismatchIntToEqual);
  LSuite.Test('Type: Str→ToEqualInt',      @TestTypeMismatchStrToEqualInt);
  LSuite.Test('Type: Str→ToBeNil',         @TestTypeMismatchStrToBeNil);
  LSuite.Test('Type: Str→ToRaise',         @TestTypeMismatchStrToRaise);

  { F12: Not_ positive pass paths }
  LSuite.Test('Not_ pass: ToBeNil',        @TestNotPositivePassToBeNil);
  LSuite.Test('Not_ pass: ToBeTrue',       @TestNotPositivePassToBeTrue);
  LSuite.Test('Not_ pass: ToBeFalse',      @TestNotPositivePassToBeFalse);
  LSuite.Test('Not_ pass: ToBeGT',         @TestNotPositivePassToBeGT);
  LSuite.Test('Not_ pass: ToBeLT',         @TestNotPositivePassToBeLT);
  LSuite.Test('Not_ pass: ToBeInRange',    @TestNotPositivePassToBeInRange);
  LSuite.Test('Not_ pass: ToHaveLength',   @TestNotPositivePassToHaveLength);
  LSuite.Test('Not_ pass: ToEqualBool',    @TestNotPositivePassToEqualBool);

  { F04: ToNotRaise }
  LSuite.Test('ToNotRaise pass',           @TestToNotRaisePass);
  LSuite.Test('ToNotRaise fail',           @TestToNotRaiseFail);

  { F23: Not_.Not_ double negation }
  LSuite.Test('Not_.Not_ double negation', @TestNotNotDoubleNegation);

  { R2-F11: Not_.ToRaise semantic }
  LSuite.Test('Not_.ToRaise pass (no ex)',     @TestNotToRaisePass);
  LSuite.Test('Not_.ToRaise fail (target ex)', @TestNotToRaiseFail);
  LSuite.Test('Not_.ToRaise other ex propag',  @TestNotToRaiseOtherException);

  { R2-F27: ToNotRaise / Not_.ToNotRaise }
  LSuite.Test('Not_.ToNotRaise same as ToNotRaise', @TestNotToNotRaiseSameAsToNotRaise);
  LSuite.Test('Not_.ToNotRaise ignores Not_',       @TestNotToNotRaiseAlwaysExpectsNoException);

  { R2-F23: Float/Double assertions }
  LSuite.Test('Double ToBeNear',               @TestExpectDouble);
  LSuite.Test('Double ToNotBeNear',            @TestExpectDoubleNotNear);
  LSuite.Test('Double ToNotBeNear no mutation', @TestExpectDoubleNotNearDoesNotMutateExpectation);
  LSuite.Test('Fail: ToBeNear too far',        @TestExpectDoubleFailToBeNear);
  LSuite.Test('Fail: ToNotBeNear too close',   @TestExpectDoubleFailNotToBeNear);
  LSuite.Test('Double Not_ negation',          @TestExpectDoubleNotNegation);
  LSuite.Test('Type: Double→ToEqualInt',       @TestExpectDoubleTypeMismatch);

  { R2-F15: NaN/Infinity/Int64 boundary }
  LSuite.Test('Double NaN guard all comparisons',   @TestExpectDoubleNaN);
  LSuite.Test('Double Infinity near',          @TestExpectDoubleInfinity);
  LSuite.Test('Double Infinity comparison',     @TestExpectDoubleInfinityComparison);
  LSuite.Test('Double -0.0 = +0.0',            @TestExpectDoubleNegativeZero);
  LSuite.Test('Int64 max/min boundary',        @TestExpectIntMaxMin);

  { R6-44: Type mismatch edge cases }
  LSuite.Test('Type: Int→ToBeNear',            @TestExpectIntToBeNearTypeMismatch);
  LSuite.Test('Type: Ptr→ToEqualInt',          @TestExpectPtrToEqualIntTypeMismatch);

  { R6-45: Not_.ToBeNear combination }
  LSuite.Test('Not_.ToBeNear in eps → fail',   @TestNotToBeNearWithinEpsilonShouldFail);
  LSuite.Test('Not_.ToBeNear out eps → pass',  @TestNotToBeNearOutsideEpsilonShouldPass);
  LSuite.Test('Not_.ToNotBeNear combo',        @TestNotToNotBeNearCombination);

  { v3.1: New comparison and string methods }
  LSuite.Test('ToBeGreaterOrEqual',           @TestExpectGreaterOrEqual);
  LSuite.Test('ToBeLessOrEqual',              @TestExpectLessOrEqual);
  LSuite.Test('Double ToBeGreaterThanD',      @TestExpectDoubleGreaterThan);
  LSuite.Test('Double ToBeLessThanD',         @TestExpectDoubleLessThan);
  LSuite.Test('Double ToBeGreaterOrEqualD',   @TestExpectDoubleGreaterOrEqual);
  LSuite.Test('Double ToBeLessOrEqualD',      @TestExpectDoubleLessOrEqual);
  LSuite.Test('Double ToBeInRangeD',          @TestExpectDoubleInRange);
  LSuite.Test('ToContainCI',                  @TestExpectContainCI);
  LSuite.Test('ToStartWithCI',               @TestExpectStartWithCI);
  LSuite.Test('ToEndWithCI',                 @TestExpectEndWithCI);
  LSuite.Test('Not_.ToBeGreaterOrEqual',      @TestExpectGreaterOrEqualNot);

  { G1: Negation path for v3.1 additions }
  LSuite.Test('Not_.ToBeLessOrEqual',        @TestExpectLessOrEqualNot);
  LSuite.Test('Not_.ToBeGreaterOrEqualD',    @TestExpectDoubleGreaterOrEqualNot);
  LSuite.Test('Not_.ToBeLessOrEqualD',       @TestExpectDoubleLessOrEqualNot);
  LSuite.Test('Not_.ToBeInRangeD',           @TestExpectDoubleInRangeNot);
  LSuite.Test('Not_.ToContainCI',            @TestExpectContainCINot);
  LSuite.Test('Not_.ToStartWithCI',          @TestExpectStartWithCINot);
  LSuite.Test('Not_.ToEndWithCI',            @TestExpectEndWithCINot);

  { P0: ToRaise nil ExceptClass guard }
  LSuite.Test('ToRaise(nil) → graceful fail', @TestExpectToRaiseNilClass);

  { F5/F6: New API — ToBeSame, ToEqualPointer, ToEqualD }
  LSuite.Test('ToBeSame pass',                 @TestExpectToBeSamePass);
  LSuite.Test('ToBeSame fail',                 @TestExpectToBeSameFail);
  LSuite.Test('Not_.ToBeSame',                 @TestExpectToBeSameNot);
  LSuite.Test('ToBeSame message correctness',  @TestExpectToBeSameMessageCorrectness);
  LSuite.Test('ToNotBeNear returns chain',      @TestExpectToNotBeNearReturnsExpectation);
  LSuite.Test('ToEqualPointer alias',          @TestExpectToEqualPointerIsAlias);
  LSuite.Test('ToEqualD pass',                 @TestExpectToEqualDPass);
  LSuite.Test('ToEqualD fail',                 @TestExpectToEqualDFail);
  LSuite.Test('Not_.ToEqualD',                 @TestExpectToEqualDNot);
  LSuite.Test('ToEqualD NaN',                  @TestExpectToEqualDNaN);
  LSuite.Test('ToEqualD epsilon boundary',     @TestExpectToEqualDEpsilonBoundary);

  { Relative tolerance (ToBeNearRel / ToNotBeNearRel) }
  LSuite.Test('ToBeNearRel pass',              @TestExpectToBeNearRelPass);
  LSuite.Test('ToBeNearRel fail',              @TestExpectToBeNearRelFail);
  LSuite.Test('ToNotBeNearRel pass',           @TestExpectToNotBeNearRelPass);
  LSuite.Test('ToNotBeNearRel fail',           @TestExpectToNotBeNearRelFail);
  LSuite.Test('Not_.ToBeNearRel',              @TestExpectToBeNearRelNot);

  { ExpectStr alias }
  LSuite.Test('ExpectStr alias',               @TestExpectStrAlias);

  { E-10: NaN + chaining coverage }
  LSuite.Test('ToBeNaN pass',                  @TestExpectToBeNaNPass);
  LSuite.Test('ToBeNaN fail',                  @TestExpectToBeNaNFail);
  LSuite.Test('ToBeNotNaN pass',               @TestExpectToBeNotNaNPass);
  LSuite.Test('ToBeNotNaN fail',               @TestExpectToBeNotNaNFail);
  LSuite.Test('Not_.ToBeNaN',                  @TestExpectToBeNaNNot);
  LSuite.Test('Not_.ToBeNotNaN',               @TestExpectToBeNotNaNNot);
  LSuite.Test('Chaining returns self',         @TestExpectChainingReturnsSelf);

  { WithMessage, ToEqualBytes, ToFailUnexpected }
  LSuite.Test('WithMessage fail prefix',      @TestExpectWithMessageFail);
  LSuite.Test('WithMessage pass',             @TestExpectWithMessagePass);
  LSuite.Test('Not_.WithMessage',             @TestExpectWithMessageNot);
  LSuite.Test('WithMessage chain',            @TestExpectWithMessageChain);
  LSuite.Test('ToEqualBytes pass',            @TestExpectToEqualBytesPass);
  LSuite.Test('ToEqualBytes fail',            @TestExpectToEqualBytesFail);
  LSuite.Test('ToEqualBytes diff len',        @TestExpectToEqualBytesDiffLen);
  LSuite.Test('ToEqualBytes empty',           @TestExpectToEqualBytesEmpty);
  LSuite.Test('Not_.ToEqualBytes',            @TestExpectToEqualBytesNot);
  LSuite.Test('ToFailUnexpected message',     @TestExpectToFailUnexpected);
  LSuite.Test('ToFailUnexpected default',     @TestExpectToFailUnexpectedDefault);
  LSuite.Test('ToFailUnexpected+WithMessage', @TestExpectToFailUnexpectedWithMessage);

  { ToBeOneOf }
  LSuite.Test('ToBeOneOf pass',              @TestToBeOneOfPass);
  LSuite.Test('ToBeOneOf fail',              @TestToBeOneOfFail);
  LSuite.Test('Not_.ToBeOneOf pass',         @TestToBeOneOfNotPass);
  LSuite.Test('Not_.ToBeOneOf fail',         @TestToBeOneOfNotFail);
  LSuite.Test('ToBeOneOfInt pass',           @TestToBeOneOfIntPass);
  LSuite.Test('ToBeOneOfInt fail',           @TestToBeOneOfIntFail);
  LSuite.Test('ToBeOneOfBool pass',          @TestToBeOneOfBoolPass);
  LSuite.Test('ToBeOneOfBool fail',          @TestToBeOneOfBoolFail);
  LSuite.Test('ToBeOneOf+WithMessage',       @TestToBeOneOfWithMessage);

  { R60: ToBeEmpty/ToBeNotEmpty + array + byte + regex }
  LSuite.Test('ToBeEmpty string',          @TestToBeEmptyString);
  LSuite.Test('ToBeNotEmpty string',       @TestToBeNotEmptyString);
  LSuite.Test('ToBeEmpty int array',       @TestToBeEmptyIntArray);
  LSuite.Test('ToBeNotEmpty int array',    @TestToBeNotEmptyIntArray);
  LSuite.Test('ToBeEmpty str array',       @TestToBeEmptyStrArray);
  LSuite.Test('ToBeEmpty bytes',           @TestToBeEmptyBytes);
  LSuite.Test('ToBeNotEmpty bytes',        @TestToBeNotEmptyBytes);
  LSuite.Test('Not_.ToBeEmpty',            @TestNotToBeEmpty);
  LSuite.Test('ToEqualIntArray pass',      @TestToEqualIntArrayPass);
  LSuite.Test('ToEqualIntArray fail',      @TestToEqualIntArrayFail);
  LSuite.Test('ToEqualIntArray diff len',  @TestToEqualIntArrayDiffLen);
  LSuite.Test('Not_.ToEqualIntArray',      @TestToEqualIntArrayNot);
  LSuite.Test('ToEqualStrArray pass',      @TestToEqualStrArrayPass);
  LSuite.Test('ToEqualStrArray fail',      @TestToEqualStrArrayFail);
  LSuite.Test('Not_.ToEqualStrArray',      @TestToEqualStrArrayNot);
  LSuite.Test('ToContainInt pass',         @TestToContainIntPass);
  LSuite.Test('ToContainInt fail',         @TestToContainIntFail);
  LSuite.Test('Not_.ToContainInt',         @TestToContainIntNot);
  LSuite.Test('ToContainStr pass',         @TestToContainStrPass);
  LSuite.Test('ToContainStr fail',         @TestToContainStrFail);
  LSuite.Test('ToContain(byte) pass',      @TestToContainBytePass);
  LSuite.Test('ToContain(byte) fail',      @TestToContainByteFail);
  LSuite.Test('Not_.ToContain(byte)',      @TestToContainByteNot);
  LSuite.Test('ToMatch pass',              @TestToMatchPass);
  LSuite.Test('ToMatch fail',              @TestToMatchFail);
  LSuite.Test('Not_.ToMatch',              @TestToMatchNot);

  LSuite.Test('ToBeSorted int pass',      @TestToBeSortedIntPass);
  LSuite.Test('ToBeSorted int fail',      @TestToBeSortedIntFail);
  LSuite.Test('ToBeSorted int empty',     @TestToBeSortedIntEmpty);
  LSuite.Test('ToBeSorted int single',    @TestToBeSortedIntSingle);
  LSuite.Test('ToBeSorted int equal',     @TestToBeSortedIntEqual);
  LSuite.Test('Not_.ToBeSorted int',      @TestToBeSortedIntNot);
  LSuite.Test('ToBeSorted str pass',      @TestToBeSortedStrPass);
  LSuite.Test('ToBeSorted str fail',      @TestToBeSortedStrFail);
  LSuite.Test('ToBeSorted str empty',     @TestToBeSortedStrEmpty);

  if not LSuite.Run then
  begin
    Finalize(LSuite);
    WriteLn;
    FailTest('SOME TESTS FAILED');
  end;
  WriteLn;
  PassTest('ALL PASSED');
  LSuite.Config.OutSink := nil;
  LSuite.Config.ErrSink := nil;
  Finalize(LSuite);
end.
