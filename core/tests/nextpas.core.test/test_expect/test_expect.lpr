{ test_expect — Validates IExpectation fluent API }
program test_expect;

{$mode objfpc}{$H+}
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
      Check(Pos('world', E.Message) > 0);
  end;
end;

procedure TestExpectStringFailNotToEqual;
begin
  try
    Expect('hello').Not_.ToEqual('hello');
    Halt(1);
  except
    on E: EAssertionFailed do
      Check(Pos('not to equal', E.Message) > 0);
  end;
end;

procedure TestExpectIntFailToEqual;
begin
  try
    ExpectInt(42).ToEqualInt(99);
    Halt(1);
  except
    on E: EAssertionFailed do
      Check(Pos('99', E.Message) > 0);
  end;
end;

procedure TestExpectBoolFailToBeTrue;
begin
  try
    ExpectBool(False).ToBeTrue;
    Halt(1);
  except
    on E: EAssertionFailed do
      Check(Pos('True', E.Message) > 0);
  end;
end;

procedure TestExpectPtrFailToBeNil;
begin
  try
    ExpectPtr(@TestExpectPtrFailToBeNil).ToBeNil;
    Halt(1);
  except
    on E: EAssertionFailed do
      Check(Pos('nil', E.Message) > 0);
  end;
end;

procedure TestExpectContainFail;
begin
  try
    Expect('hello').ToContain('xyz');
    Halt(1);
  except
    on E: EAssertionFailed do
      Check(Pos('does not contain', E.Message) > 0);
  end;
end;

procedure TestExpectRangeFail;
begin
  try
    ExpectInt(100).ToBeInRange(1, 10);
    Halt(1);
  except
    on E: EAssertionFailed do
      Check(Pos('not in', E.Message) > 0);
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
      Check(Pos('ALow', E.Message) > 0, 'inverted range should mention ALow');
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
      Check(Pos('nothing raised', E.Message) > 0);
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
      Check(Pos('not', LowerCase(E.Message)) > 0, 'Not_ fail msg');
  end;
end;

procedure TestNotFailToEqualBool;
begin
  try
    ExpectBool(True).Not_.ToEqualBool(True);
    Halt(1);
  except
    on E: EAssertionFailed do
      Check(Pos('not', LowerCase(E.Message)) > 0, 'Not_ fail msg');
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
      Check(Pos('Expected not', E.Message) > 0, 'Not_ fail msg');
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
      Check(Pos('Expected not', E.Message) > 0, 'Not_ fail msg');
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
      Check(Pos('Expected non-nil but got nil', E.Message) > 0, 'Not_ fail msg');
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
      Check(Pos('Expected nil but got', E.Message) > 0, 'Not_ fail msg');
  end;
end;

procedure TestNotFailToContain;
begin
  try
    Expect('hello').Not_.ToContain('ell');
    Halt(1);
  except
    on E: EAssertionFailed do
      Check(Pos('should not contain', E.Message) > 0, 'Not_ fail msg');
  end;
end;

procedure TestNotFailToStartWith;
begin
  try
    Expect('hello').Not_.ToStartWith('hel');
    Halt(1);
  except
    on E: EAssertionFailed do
      Check(Pos('should not start', E.Message) > 0, 'Not_ fail msg');
  end;
end;

procedure TestNotFailToEndWith;
begin
  try
    Expect('hello').Not_.ToEndWith('llo');
    Halt(1);
  except
    on E: EAssertionFailed do
      Check(Pos('should not end', E.Message) > 0, 'Not_ fail msg');
  end;
end;

procedure TestNotFailToBeGreaterThan;
begin
  try
    ExpectInt(10).Not_.ToBeGreaterThan(5);
    Halt(1);
  except
    on E: EAssertionFailed do
      Check(Pos('should not', E.Message) > 0, 'Not_ fail msg');
  end;
end;

procedure TestNotFailToBeLessThan;
begin
  try
    ExpectInt(5).Not_.ToBeLessThan(10);
    Halt(1);
  except
    on E: EAssertionFailed do
      Check(Pos('should not', E.Message) > 0, 'Not_ fail msg');
  end;
end;

procedure TestNotFailToBeInRange;
begin
  try
    ExpectInt(5).Not_.ToBeInRange(1, 10);
    Halt(1);
  except
    on E: EAssertionFailed do
      Check(Pos('should not', E.Message) > 0, 'Not_ fail msg');
  end;
end;

procedure TestNotFailToHaveLength;
begin
  try
    Expect('abc').Not_.ToHaveLength(3);
    Halt(1);
  except
    on E: EAssertionFailed do
      Check(Pos('should not', LowerCase(E.Message)) > 0, 'Not_ fail msg');
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
      Check(Pos('EConvertError', E.Message) > 0, 'Not_ fail msg');
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
      Check(Pos('does not start', E.Message) > 0, 'start fail msg');
  end;
end;

procedure TestFailToEndWith;
begin
  try
    Expect('hello').ToEndWith('xyz');
    Halt(1);
  except
    on E: EAssertionFailed do
      Check(Pos('does not end', E.Message) > 0, 'end fail msg');
  end;
end;

procedure TestFailToHaveLength;
begin
  try
    Expect('abc').ToHaveLength(99);
    Halt(1);
  except
    on E: EAssertionFailed do
      Check(Pos('Expected length', E.Message) > 0, 'length fail msg');
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
      Check(Pos('Expected False but got', E.Message) > 0, 'bool fail msg');
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
      Check(Pos('Expected non-nil but got nil', E.Message) > 0, 'notnil fail msg');
  end;
end;

procedure TestFailToBeGreaterThan;
begin
  try
    ExpectInt(1).ToBeGreaterThan(100);
    Halt(1);
  except
    on E: EAssertionFailed do
      Check(Pos('not >', E.Message) > 0, 'gt fail msg');
  end;
end;

procedure TestFailToBeLessThan;
begin
  try
    ExpectInt(100).ToBeLessThan(1);
    Halt(1);
  except
    on E: EAssertionFailed do
      Check(Pos('not <', E.Message) > 0, 'lt fail msg');
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
      Check(Pos('Expected False but got', E.Message) > 0, 'bool eq fail msg');
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
      Check(Pos('does not contain', E.Message) > 0, 'raise msg fail');
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
      Check(Pos('Expected not False but got', E.Message) > 0, 'Not_ bool eq fail msg');
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
      Check(Pos('Expected nil but got', E.Message) > 0, 'nil fail msg');
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
      Check(Pos('non-string', E.Message) > 0, 'type mismatch msg');
  end;
end;

procedure TestTypeMismatchStrToEqualInt;
begin
  try
    Expect('hello').ToEqualInt(42);
    Halt(1);
  except
    on E: EAssertionFailed do
      Check(Pos('non-integer', E.Message) > 0, 'type mismatch msg');
  end;
end;

procedure TestTypeMismatchStrToBeNil;
begin
  try
    Expect('hello').ToBeNil;
    Halt(1);
  except
    on E: EAssertionFailed do
      Check(Pos('non-pointer', E.Message) > 0, 'type mismatch msg');
  end;
end;

procedure TestTypeMismatchStrToRaise;
begin
  try
    Expect('hello').ToRaise(Exception);
    Halt(1);
  except
    on E: EAssertionFailed do
      Check(Pos('non-proc', E.Message) > 0, 'type mismatch msg');
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
      Check(Pos('no exception', E.Message) > 0, 'ToNotRaise fail msg');
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
      Check(Pos('EConvertError', E.Message) > 0, 'Not_.ToRaise fail msg');
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
    WriteLn(AnsiRed('FAIL: EAccessViolation should propagate through Not_.ToRaise'));
    Halt(1);
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
      Check(Pos('Expected', E.Message) > 0, 'message');
    on E: Exception do
      Check(False, 'unexpected ' + E.ClassName + ': ' + E.Message);
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
      Check(Pos('not near', E.Message) > 0, 'message');
    on E: Exception do
      Check(False, 'unexpected ' + E.ClassName + ': ' + E.Message);
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
      Check(Pos('non-integer', E.Message) > 0, 'mismatch message');
    on E: Exception do
      Check(False, 'unexpected ' + E.ClassName + ': ' + E.Message);
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
      Check(Pos('no exception', E.Message) > 0, 'should mention no exception');
  end;
end;

{ ── Main ──────────────────────────────────────────────────────────────────── }

var
  LSuite: TTestSuite;
begin
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

  if not LSuite.Run then
  begin
    WriteLn;
    WriteLn(AnsiRed('SOME TESTS FAILED'));
    Halt(1);
  end;
  WriteLn;
  WriteLn(AnsiGreen('ALL PASSED'));
end.
