{ test_expect — Validates IExpectation fluent API }
program test_expect;

{$mode objfpc}{$H+}{$J-}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

uses
  cthreads,
  SysUtils,
  Math,
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
    .ToRaise(EConvertError, 'invalid');
end;

procedure TestExpectProcNotRaise;
begin
  ExpectProc(procedure begin { ok } end)
    .Not_.ToRaise(EConvertError);
end;

{ ── Failure tests ────────────────────────────────────────────────────────── }

procedure TestExpectStringFailToEqual;
begin
  try
    Expect('hello').ToEqual('world');
    Halt(1);
  except
    on E: EAssertionFailed do
      CheckContains(E.Message, 'world');
  end;
end;

procedure TestExpectStringFailNotToEqual;
begin
  try
    Expect('hello').Not_.ToEqual('hello');
    Halt(1);
  except
    on E: EAssertionFailed do
      CheckContains(E.Message, 'not to equal');
  end;
end;

procedure TestExpectIntFailToEqual;
begin
  try
    ExpectInt(42).ToEqualInt(99);
    Halt(1);
  except
    on E: EAssertionFailed do
      CheckContains(E.Message, '99');
  end;
end;

procedure TestExpectBoolFailToBeTrue;
begin
  try
    ExpectBool(False).ToBeTrue;
    Halt(1);
  except
    on E: EAssertionFailed do
      CheckContains(E.Message, 'True');
  end;
end;

procedure TestExpectPtrFailToBeNil;
begin
  try
    ExpectPtr(@TestExpectPtrFailToBeNil).ToBeNil;
    Halt(1);
  except
    on E: EAssertionFailed do
      CheckContains(E.Message, 'nil');
  end;
end;

procedure TestExpectContainFail;
begin
  try
    Expect('hello').ToContain('xyz');
    Halt(1);
  except
    on E: EAssertionFailed do
      CheckContains(E.Message, 'does not contain');
  end;
end;

procedure TestExpectRangeFail;
begin
  try
    ExpectInt(100).ToBeInRange(1, 10);
    Halt(1);
  except
    on E: EAssertionFailed do
      CheckContains(E.Message, 'not in');
  end;
end;

procedure TestExpectRangeInverted;
begin
  { R5-11: ToBeInRange must validate ALow > AHigh (consistent with CheckInRange) }
  try
    ExpectInt(5).ToBeInRange(10, 1);
    Halt(1);
  except
    on E: EAssertionFailed do
      CheckContains(E.Message, 'ALow');
  end;
end;

procedure TestExpectRaiseFail;
begin
  try
    ExpectProc(procedure begin { nothing } end)
      .ToRaise(EConvertError);
    Halt(1);
  except
    on E: EAssertionFailed do
      CheckContains(E.Message, 'nothing raised');
  end;
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
  try
    ExpectInt(42).Not_.ToEqualInt(42);
    Halt(1);
  except
    on E: EAssertionFailed do
      CheckContains(LowerCase(E.Message), 'not');
  end;
end;

procedure TestNotFailToEqualBool;
begin
  try
    ExpectBool(True).Not_.ToEqualBool(True);
    Halt(1);
  except
    on E: EAssertionFailed do
      CheckContains(LowerCase(E.Message), 'not');
  end;
end;

procedure TestNotFailToBeTrue;
begin
  try
    { ToBeTrue delegates to ToEqualBool(True), message: 'Expected not True but got True' }
    ExpectBool(True).Not_.ToBeTrue;
    Halt(1);
  except
    on E: EAssertionFailed do
      CheckContains(E.Message, 'Expected not');
  end;
end;

procedure TestNotFailToBeFalse;
begin
  try
    { ToBeFalse delegates to ToEqualBool(False), message: 'Expected not False but got False' }
    ExpectBool(False).Not_.ToBeFalse;
    Halt(1);
  except
    on E: EAssertionFailed do
      CheckContains(E.Message, 'Expected not');
  end;
end;

procedure TestNotFailToBeNil;
begin
  try
    { Not_.ToBeNil on nil → 'Expected non-nil but got nil' }
    ExpectPtr(nil).Not_.ToBeNil;
    Halt(1);
  except
    on E: EAssertionFailed do
      CheckContains(E.Message, 'Expected non-nil but got nil');
  end;
end;

procedure TestNotFailToBeNotNil;
var
  LP: Pointer;
begin
  LP := @LP;
  try
    { Not_.ToBeNotNil on non-nil → 'Expected nil but got $...' }
    ExpectPtr(LP).Not_.ToBeNotNil;
    Halt(1);
  except
    on E: EAssertionFailed do
      CheckContains(E.Message, 'Expected nil but got');
  end;
end;

procedure TestNotFailToContain;
begin
  try
    Expect('hello').Not_.ToContain('ell');
    Halt(1);
  except
    on E: EAssertionFailed do
      CheckContains(E.Message, 'should not contain');
  end;
end;

procedure TestNotFailToStartWith;
begin
  try
    Expect('hello').Not_.ToStartWith('hel');
    Halt(1);
  except
    on E: EAssertionFailed do
      CheckContains(E.Message, 'should not start');
  end;
end;

procedure TestNotFailToEndWith;
begin
  try
    Expect('hello').Not_.ToEndWith('llo');
    Halt(1);
  except
    on E: EAssertionFailed do
      CheckContains(E.Message, 'should not end');
  end;
end;

procedure TestNotFailToBeGreaterThan;
begin
  try
    ExpectInt(10).Not_.ToBeGreaterThan(5);
    Halt(1);
  except
    on E: EAssertionFailed do
      CheckContains(E.Message, 'should not');
  end;
end;

procedure TestNotFailToBeLessThan;
begin
  try
    ExpectInt(5).Not_.ToBeLessThan(10);
    Halt(1);
  except
    on E: EAssertionFailed do
      CheckContains(E.Message, 'should not');
  end;
end;

procedure TestNotFailToBeInRange;
begin
  try
    ExpectInt(5).Not_.ToBeInRange(1, 10);
    Halt(1);
  except
    on E: EAssertionFailed do
      CheckContains(E.Message, 'should not');
  end;
end;

procedure TestNotFailToHaveLength;
begin
  try
    Expect('abc').Not_.ToHaveLength(3);
    Halt(1);
  except
    on E: EAssertionFailed do
      CheckContains(LowerCase(E.Message), 'should not');
  end;
end;

procedure TestNotFailToRaise;
begin
  try
    ExpectProc(procedure begin StrToInt('bad'); end)
      .Not_.ToRaise(EConvertError);
    Halt(1);
  except
    on E: EAssertionFailed do
      CheckContains(E.Message, 'EConvertError');
  end;
end;

{ ── IExpectation failure path tests (B5.2) ────────────────────────────────── }

procedure TestFailToStartWith;
begin
  try
    Expect('hello').ToStartWith('xyz');
    Halt(1);
  except
    on E: EAssertionFailed do
      CheckContains(E.Message, 'does not start');
  end;
end;

procedure TestFailToEndWith;
begin
  try
    Expect('hello').ToEndWith('xyz');
    Halt(1);
  except
    on E: EAssertionFailed do
      CheckContains(E.Message, 'does not end');
  end;
end;

procedure TestFailToHaveLength;
begin
  try
    Expect('abc').ToHaveLength(99);
    Halt(1);
  except
    on E: EAssertionFailed do
      CheckContains(E.Message, 'Expected length');
  end;
end;

procedure TestFailToBeFalse;
begin
  try
    { ToBeFalse(True) → 'Expected False but got True' }
    ExpectBool(True).ToBeFalse;
    Halt(1);
  except
    on E: EAssertionFailed do
      CheckContains(E.Message, 'Expected False but got');
  end;
end;

procedure TestFailToBeNotNil;
begin
  try
    { ToBeNotNil(nil) → 'Expected non-nil but got nil' }
    ExpectPtr(nil).ToBeNotNil;
    Halt(1);
  except
    on E: EAssertionFailed do
      CheckContains(E.Message, 'Expected non-nil but got nil');
  end;
end;

procedure TestFailToBeGreaterThan;
begin
  try
    ExpectInt(1).ToBeGreaterThan(100);
    Halt(1);
  except
    on E: EAssertionFailed do
      CheckContains(E.Message, 'not >');
  end;
end;

procedure TestFailToBeLessThan;
begin
  try
    ExpectInt(100).ToBeLessThan(1);
    Halt(1);
  except
    on E: EAssertionFailed do
      CheckContains(E.Message, 'not <');
  end;
end;

procedure TestFailToEqualBool;
begin
  try
    { ToEqualBool(True, False) → 'Expected False but got True' }
    ExpectBool(True).ToEqualBool(False);
    Halt(1);
  except
    on E: EAssertionFailed do
      CheckContains(E.Message, 'Expected False but got');
  end;
end;

procedure TestFailToRaiseWithMsg;
begin
  try
    ExpectProc(procedure begin StrToInt('bad'); end)
      .ToRaise(EConvertError, 'specific_mismatch_msg_xyz');
    Halt(1);
  except
    on E: EAssertionFailed do
      CheckContains(E.Message, 'does not contain');
  end;
end;

procedure TestFailNotToEqualBool;
begin
  try
    { Not_.ToEqualBool(False, False) → 'Expected not False but got False' }
    ExpectBool(False).Not_.ToEqualBool(False);
    Halt(1);
  except
    on E: EAssertionFailed do
      CheckContains(E.Message, 'Expected not False but got');
  end;
end;

procedure TestFailToBeNil;
begin
  try
    { ToBeNil(non-nil) → 'Expected nil but got $...' }
    ExpectPtr(@TestFailToBeNil).ToBeNil;
    Halt(1);
  except
    on E: EAssertionFailed do
      CheckContains(E.Message, 'Expected nil but got');
  end;
end;

{ ── F10: Type mismatch error paths ────────────────────────────────────────── }

procedure TestTypeMismatchIntToEqual;
begin
  try
    ExpectInt(42).ToEqual('hello');
    Halt(1);
  except
    on E: EAssertionFailed do
      CheckContains(E.Message, 'non-string');
  end;
end;

procedure TestTypeMismatchStrToEqualInt;
begin
  try
    Expect('hello').ToEqualInt(42);
    Halt(1);
  except
    on E: EAssertionFailed do
      CheckContains(E.Message, 'non-integer');
  end;
end;

procedure TestTypeMismatchStrToBeNil;
begin
  try
    Expect('hello').ToBeNil;
    Halt(1);
  except
    on E: EAssertionFailed do
      CheckContains(E.Message, 'non-pointer');
  end;
end;

procedure TestTypeMismatchStrToRaise;
begin
  try
    Expect('hello').ToRaise(Exception);
    Halt(1);
  except
    on E: EAssertionFailed do
      CheckContains(E.Message, 'non-proc');
  end;
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
  try
    ExpectProc(procedure begin StrToInt('bad'); end).ToNotRaise;
    Halt(1);
  except
    on E: EAssertionFailed do
      CheckContains(E.Message, 'no exception');
  end;
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
  try
    ExpectProc(procedure begin StrToInt('bad'); end).Not_.ToRaise(EConvertError);
    Halt(1);
  except
    on E: EAssertionFailed do
      CheckContains(E.Message, 'EConvertError');
  end;
end;

procedure TestNotToRaiseOtherException;
var
  LCaught: Boolean = False;
begin
  { Not_.ToRaise(EConvertError) + EAccessViolation → re-raise (not swallowed) }
  try
    ExpectProc(procedure begin raise EAccessViolation.Create('av'); end)
      .Not_.ToRaise(EConvertError);
  except
    on E: EAccessViolation do
      LCaught := True;
  end;
  if not LCaught then
  begin
    FailTest('EAccessViolation should propagate through Not_.ToRaise');
  end;
end;

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
  try
    ExpectDouble(1.0).ToBeNear(2.0, 1e-10);
    WriteLn('ERROR: ToBeNear did not raise');
    Halt(1);
  except
    on E: EAssertionFailed do
      CheckContains(E.Message, 'Expected');
    on E: Exception do
      FailUnexpected(E);
  end;
end;

procedure TestExpectDoubleFailNotToBeNear;
begin
  try
    ExpectDouble(1.0).ToNotBeNear(1.0, 1e-10);
    WriteLn('ERROR: ToNotBeNear did not raise');
    Halt(1);
  except
    on E: EAssertionFailed do
      CheckContains(E.Message, 'not near');
    on E: Exception do
      FailUnexpected(E);
  end;
end;

procedure TestExpectDoubleNotNegation;
begin
  ExpectDouble(1.0).Not_.ToBeNear(2.0, 1e-10);
  ExpectDouble(1.0).Not_.ToNotBeNear(1.0, 1e-10);
end;

procedure TestExpectDoubleTypeMismatch;
begin
  try
    ExpectDouble(1.0).ToEqualInt(1);
    WriteLn('ERROR: type mismatch not raised');
    Halt(1);
  except
    on E: EAssertionFailed do
      CheckContains(E.Message, 'non-integer');
    on E: Exception do
      FailUnexpected(E);
  end;
end;

{ ── R2-F15: NaN/Infinity/Int64 boundary ────────────────────────────────────── }

procedure TestExpectDoubleNaN;
var
  LNaN: Double;
  LOldMask: TFPUExceptionMask;
begin
  LNaN := 0.0;
  { Generate NaN and evaluate near-ness without triggering EInvalidOp }
  LOldMask := GetExceptionMask;
  SetExceptionMask([exInvalidOp, exZeroDivide, exOverflow, exUnderflow, exPrecision, exDenormalized]);
  LNaN := 0.0/0.0;
  ExpectDouble(LNaN).Not_.ToBeNear(0.0, 1e-10);
  ExpectDouble(LNaN).Not_.ToBeNear(1.0, 1e-10);
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
  { Not_.ToNotRaise should behave the same as ToNotRaise when no exception:
    both pass. }
  ExpectProc(procedure begin end).Not_.ToNotRaise;
end;

procedure TestNotToNotRaiseAlwaysExpectsNoException;
begin
  { Not_.ToNotRaise + exception raised → still fails (same as ToNotRaise).
    This verifies the FNegated flag is ignored. }
  try
    ExpectProc(procedure begin StrToInt('bad'); end).Not_.ToNotRaise;
    Halt(1);
  except
    on E: EAssertionFailed do
      CheckContains(E.Message, 'no exception');
  end;
end;

{ R6-44: Type mismatch edge cases — verify EAssertionFailed with type hint }

procedure TestExpectIntToBeNearTypeMismatch;
begin
  { ExpectInt creates ekInt, ToBeNear requires ekDouble → type mismatch }
  try
    ExpectInt(42).ToBeNear(42.0, 1.0);
    Halt(1);
  except
    on E: EAssertionFailed do
      CheckContains(LowerCase(E.Message), 'non-double');
  end;
end;

procedure TestExpectPtrToEqualIntTypeMismatch;
begin
  { ExpectPtr creates ekPtr, ToEqualInt requires ekInt → type mismatch }
  try
    ExpectPtr(nil).ToEqualInt(0);
    Halt(1);
  except
    on E: EAssertionFailed do
      CheckContains(LowerCase(E.Message), 'non-integer');
  end;
end;

{ R6-45: Not_.ToBeNear combination }

procedure TestNotToBeNearWithinEpsilonShouldFail;
begin
  { Value is within epsilon → Not_ should negate to fail }
  try
    ExpectDouble(1.0).Not_.ToBeNear(1.0, 0.01);
    Halt(1);
  except
    on E: EAssertionFailed do
      CheckContains(LowerCase(E.Message), 'not');
  end;
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
  try
    ExpectDouble(1.0).Not_.ToNotBeNear(100.0, 0.01);
    Halt(1);
  except
    on E: EAssertionFailed do
      Check(True, 'expected failure from Not_.ToNotBeNear outside epsilon');
  end;
end;

{ ── v3.1: New Expect API tests ─────────────────────────────────────────────── }

procedure TestExpectGreaterOrEqual;
begin
  ExpectInt(5).ToBeGreaterOrEqual(5);
  ExpectInt(5).ToBeGreaterOrEqual(4);
  try
    ExpectInt(4).ToBeGreaterOrEqual(5);
    Halt(1);
  except
    on E: EAssertionFailed do
      CheckContains(E.Message, 'is not >=');
  end;
end;

procedure TestExpectLessOrEqual;
begin
  ExpectInt(5).ToBeLessOrEqual(5);
  ExpectInt(4).ToBeLessOrEqual(5);
  try
    ExpectInt(5).ToBeLessOrEqual(4);
    Halt(1);
  except
    on E: EAssertionFailed do
      CheckContains(E.Message, 'is not <=');
  end;
end;

procedure TestExpectDoubleGreaterThan;
begin
  ExpectDouble(5.5).ToBeGreaterThanD(5.0);
  try
    ExpectDouble(5.0).ToBeGreaterThanD(5.0);
    Halt(1);
  except
    on E: EAssertionFailed do
      Check(True, 'expected > fail');
  end;
end;

procedure TestExpectDoubleLessThan;
begin
  ExpectDouble(4.5).ToBeLessThanD(5.0);
  try
    ExpectDouble(5.0).ToBeLessThanD(5.0);
    Halt(1);
  except
    on E: EAssertionFailed do
      Check(True, 'expected < fail');
  end;
end;

procedure TestExpectDoubleGreaterOrEqual;
begin
  ExpectDouble(5.0).ToBeGreaterOrEqualD(5.0);
  ExpectDouble(5.1).ToBeGreaterOrEqualD(5.0);
  try
    ExpectDouble(4.9).ToBeGreaterOrEqualD(5.0);
    Halt(1);
  except
    on E: EAssertionFailed do
      Check(True, 'expected >= fail');
  end;
end;

procedure TestExpectDoubleLessOrEqual;
begin
  ExpectDouble(5.0).ToBeLessOrEqualD(5.0);
  ExpectDouble(4.9).ToBeLessOrEqualD(5.0);
  try
    ExpectDouble(5.1).ToBeLessOrEqualD(5.0);
    Halt(1);
  except
    on E: EAssertionFailed do
      Check(True, 'expected <= fail');
  end;
end;

procedure TestExpectDoubleInRange;
begin
  ExpectDouble(5.0).ToBeInRangeD(1.0, 10.0);
  ExpectDouble(1.0).ToBeInRangeD(1.0, 10.0);
  ExpectDouble(10.0).ToBeInRangeD(1.0, 10.0);
  try
    ExpectDouble(11.0).ToBeInRangeD(1.0, 10.0);
    Halt(1);
  except
    on E: EAssertionFailed do
      Check(True, 'expected range fail');
  end;
end;

procedure TestExpectContainCI;
begin
  Expect('Hello World').ToContainCI('hello');
  Expect('Hello World').ToContainCI('WORLD');
  try
    Expect('Hello').ToContainCI('xyz');
    Halt(1);
  except
    on E: EAssertionFailed do
      Check(True, 'expected contain CI fail');
  end;
end;

procedure TestExpectStartWithCI;
begin
  Expect('Hello World').ToStartWithCI('hello');
  try
    Expect('Hello World').ToStartWithCI('world');
    Halt(1);
  except
    on E: EAssertionFailed do
      Check(True, 'expected start CI fail');
  end;
end;

procedure TestExpectEndWithCI;
begin
  Expect('Hello World').ToEndWithCI('WORLD');
  try
    Expect('Hello World').ToEndWithCI('hello');
    Halt(1);
  except
    on E: EAssertionFailed do
      Check(True, 'expected end CI fail');
  end;
end;

procedure TestExpectGreaterOrEqualNot;
begin
  ExpectInt(4).Not_.ToBeGreaterOrEqual(5);
  try
    ExpectInt(5).Not_.ToBeGreaterOrEqual(5);
    Halt(1);
  except
    on E: EAssertionFailed do
      Check(True, 'expected Not_ >= fail');
  end;
end;

procedure TestExpectLessOrEqualNot;
{ G1: Not_.ToBeLessOrEqual negation path }
begin
  { 4 <= 5 is true → Not_ inverts → pass }
  ExpectInt(5).Not_.ToBeLessOrEqual(4);
  { 5 <= 5 is true → Not_ inverts → fail }
  try
    ExpectInt(5).Not_.ToBeLessOrEqual(5);
    Halt(1);
  except
    on E: EAssertionFailed do
      Check(True, 'expected Not_ <= fail');
  end;
end;

procedure TestExpectDoubleGreaterOrEqualNot;
{ G1: Not_.ToBeGreaterOrEqualD negation path }
begin
  ExpectDouble(4.9).Not_.ToBeGreaterOrEqualD(5.0);
  try
    ExpectDouble(5.0).Not_.ToBeGreaterOrEqualD(5.0);
    Halt(1);
  except
    on E: EAssertionFailed do
      Check(True, 'expected Not_ >=D fail');
  end;
end;

procedure TestExpectDoubleLessOrEqualNot;
{ G1: Not_.ToBeLessOrEqualD negation path }
begin
  ExpectDouble(5.1).Not_.ToBeLessOrEqualD(5.0);
  try
    ExpectDouble(5.0).Not_.ToBeLessOrEqualD(5.0);
    Halt(1);
  except
    on E: EAssertionFailed do
      Check(True, 'expected Not_ <=D fail');
  end;
end;

procedure TestExpectDoubleInRangeNot;
{ G1: Not_.ToBeInRangeD negation path }
begin
  { Outside range → Not_ inverts → pass }
  ExpectDouble(9.9).Not_.ToBeInRangeD(0.0, 9.0);
  { Inside range → Not_ inverts → fail }
  try
    ExpectDouble(5.0).Not_.ToBeInRangeD(0.0, 9.0);
    Halt(1);
  except
    on E: EAssertionFailed do
      Check(True, 'expected Not_ InRangeD fail');
  end;
end;

procedure TestExpectContainCINot;
{ G1: Not_.ToContainCI negation path }
begin
  Expect('Hello World').Not_.ToContainCI('xyz');
  try
    Expect('Hello World').Not_.ToContainCI('hello');
    Halt(1);
  except
    on E: EAssertionFailed do
      Check(True, 'expected Not_ ContainCI fail');
  end;
end;

procedure TestExpectStartWithCINot;
{ G1: Not_.ToStartWithCI negation path }
begin
  Expect('Hello World').Not_.ToStartWithCI('world');
  try
    Expect('Hello World').Not_.ToStartWithCI('hello');
    Halt(1);
  except
    on E: EAssertionFailed do
      Check(True, 'expected Not_ StartWithCI fail');
  end;
end;

procedure TestExpectEndWithCINot;
{ G1: Not_.ToEndWithCI negation path }
begin
  Expect('Hello World').Not_.ToEndWithCI('hello');
  try
    Expect('Hello World').Not_.ToEndWithCI('WORLD');
    Halt(1);
  except
    on E: EAssertionFailed do
      Check(True, 'expected Not_ EndWithCI fail');
  end;
end;

procedure TestExpectToRaiseNilClass;
{ P0: ToRaise(nil) must fail gracefully, not SIGSEGV }
begin
  try
    ExpectProc(procedure begin end).ToRaise(nil);
    Halt(1); { should not reach here }
  except
    on E: EAssertionFailed do
      Check(Pos('nil', E.Message) > 0,
        'Expected nil in error message, got: ' + E.Message);
  end;
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
  LSuite.Test('Double NaN not near',           @TestExpectDoubleNaN);
  LSuite.Test('Double Infinity near',          @TestExpectDoubleInfinity);
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

  if not LSuite.Run then
  begin
    WriteLn;
    FailTest('SOME TESTS FAILED');
  end;
  WriteLn;
  PassTest('ALL PASSED');
end.
