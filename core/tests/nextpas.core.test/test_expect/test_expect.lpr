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

  { Failure path tests }
  LSuite.Test('Fail: ToEqual wrong',     @TestExpectStringFailToEqual);
  LSuite.Test('Fail: Not_ ToEqual same', @TestExpectStringFailNotToEqual);
  LSuite.Test('Fail: ToEqualInt wrong',  @TestExpectIntFailToEqual);
  LSuite.Test('Fail: ToBeTrue on False', @TestExpectBoolFailToBeTrue);
  LSuite.Test('Fail: ToBeNil on ptr',    @TestExpectPtrFailToBeNil);
  LSuite.Test('Fail: ToContain miss',    @TestExpectContainFail);
  LSuite.Test('Fail: ToBeInRange OOB',   @TestExpectRangeFail);
  LSuite.Test('Fail: ToRaise no raise',  @TestExpectRaiseFail);

  if not LSuite.Run then
  begin
    WriteLn;
    WriteLn(AnsiRed('SOME TESTS FAILED'));
    Halt(1);
  end;
  WriteLn;
  WriteLn(AnsiGreen('ALL PASSED'));
end.
