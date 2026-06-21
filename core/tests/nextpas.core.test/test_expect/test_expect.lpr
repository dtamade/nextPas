{ test_expect — Validates IExpectation fluent API }
program test_expect;

{$mode objfpc}{$H+}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

uses
  SysUtils,
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
      Check(Pos('no exception', LowerCase(E.Message)) > 0, 'Not_ fail msg');
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

  if not LSuite.Run then
  begin
    WriteLn;
    WriteLn(AnsiRed('SOME TESTS FAILED'));
    Halt(1);
  end;
  WriteLn;
  WriteLn(AnsiGreen('ALL PASSED'));
end.
