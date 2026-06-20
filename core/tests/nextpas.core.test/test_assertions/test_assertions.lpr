{ test_assertions — Validates Check* procedural API }
program test_assertions;

{$mode objfpc}{$H+}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

uses
  SysUtils,
  nextpas.core.test;

{ ── Test procedures ──────────────────────────────────────────────────────── }

procedure TestCheckPass;
begin
  Check(True, 'True should pass');
  Check(1 + 1 = 2);
end;

procedure TestCheckFail;
begin
  try
    Check(False, 'expected failure');
    WriteLn('ERROR: Check(False) did not raise');
    Halt(1);
  except
    on E: EAssertionFailed do
      Check(Pos('expected failure', E.Message) > 0, 'message mismatch');
  end;
end;

procedure TestCheckEqualString;
begin
  CheckEqual('hello', 'hello');
  try
    CheckEqual('hello', 'world');
    Halt(1);
  except
    on E: EAssertionFailed do
      Check(Pos('hello', E.Message) > 0, 'should contain expected');
  end;
end;

procedure TestCheckEqualInt;
begin
  CheckEqual(Int64(42), Int64(42));
  try
    CheckEqual(Int64(42), Int64(99));
    Halt(1);
  except
    on E: EAssertionFailed do
      Check(Pos('42', E.Message) > 0);
  end;
end;

procedure TestCheckEqualBool;
begin
  CheckEqual(True, True);
  CheckEqual(False, False);
  try
    CheckEqual(True, False);
    Halt(1);
  except
    on E: EAssertionFailed do { expected };
  end;
end;

procedure TestCheckEqualPtr;
var
  LP: Pointer;
begin
  LP := @LP;
  CheckEqual(LP, LP);
  try
    CheckEqual(nil, LP);
    Halt(1);
  except
    on E: EAssertionFailed do { expected };
  end;
end;

procedure TestCheckNotEqual;
begin
  CheckNotEqual('a', 'b');
  CheckNotEqual(Int64(1), Int64(2));
  try
    CheckNotEqual('x', 'x');
    Halt(1);
  except
    on E: EAssertionFailed do { expected };
  end;
end;

procedure TestCheckTrueFalse;
begin
  CheckTrue(True);
  CheckTrue(2 > 1, 'math works');
  CheckFalse(False);
  CheckFalse(1 > 2);
  try
    CheckTrue(False, 'should fail');
    Halt(1);
  except
    on E: EAssertionFailed do { expected };
  end;
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
    on E: EAssertionFailed do { expected };
  end;
end;

procedure TestCheckContains;
begin
  CheckContains('hello world', 'world');
  CheckContains('abcdef', 'cde');
  try
    CheckContains('hello', 'xyz');
    Halt(1);
  except
    on E: EAssertionFailed do { expected };
  end;
end;

procedure TestCheckStartsWith;
begin
  CheckStartsWith('hello world', 'hello');
  CheckStartsWith('abc', 'a');
  try
    CheckStartsWith('hello', 'xyz');
    Halt(1);
  except
    on E: EAssertionFailed do { expected };
  end;
end;

procedure TestCheckEndsWith;
begin
  CheckEndsWith('hello world', 'world');
  CheckEndsWith('abc', 'bc');
  try
    CheckEndsWith('hello', 'xyz');
    Halt(1);
  except
    on E: EAssertionFailed do { expected };
  end;
end;

procedure TestCheckSame;
var
  LP1, LP2: Pointer;
begin
  LP1 := @LP1;
  LP2 := LP1;
  CheckSame(LP1, LP2);
  try
    CheckSame(LP1, nil, 'should be same');
    Halt(1);
  except
    on E: EAssertionFailed do { expected };
  end;
end;

procedure TestCheckInRange;
begin
  CheckInRange(5, 1, 10);
  CheckInRange(1, 1, 10);
  CheckInRange(10, 1, 10);
  try
    CheckInRange(0, 1, 10);
    Halt(1);
  except
    on E: EAssertionFailed do { expected };
  end;
end;

procedure TestCheckLength;
begin
  CheckLength(5, 5);
  CheckLength(0, 0);
  try
    CheckLength(3, 5);
    Halt(1);
  except
    on E: EAssertionFailed do { expected };
  end;
end;

procedure TestCheckRaises;
begin
  CheckRaises(EConvertError,
    procedure begin StrToInt('not_a_number'); end);
  try
    CheckRaises(EConvertError,
      procedure begin { does nothing } end);
    Halt(1);
  except
    on E: EAssertionFailed do { expected };
  end;
end;

procedure TestCheckNoRaise;
begin
  CheckNoRaise(procedure begin { ok } end);
  try
    CheckNoRaise(
      procedure begin raise EConvertError.Create('oops'); end);
    Halt(1);
  except
    on E: EAssertionFailed do { expected };
  end;
end;

procedure TestFail;
begin
  try
    Fail('intentional');
    Halt(1);
  except
    on E: EAssertionFailed do
      Check(Pos('intentional', E.Message) > 0);
  end;
end;

procedure TestSkip;
begin
  try
    Skip('not ready');
    Halt(1);
  except
    on E: ETestSkipped do
      Check(Pos('not ready', E.Message) > 0);
  end;
end;

{ ── Main ──────────────────────────────────────────────────────────────────── }

var
  LSuite: TTestSuite;
begin
  LSuite := TTestSuite.Create('Check* API');

  LSuite.Test('Check (pass)',          @TestCheckPass);
  LSuite.Test('Check (fail)',          @TestCheckFail);
  LSuite.Test('CheckEqual (string)',   @TestCheckEqualString);
  LSuite.Test('CheckEqual (int64)',    @TestCheckEqualInt);
  LSuite.Test('CheckEqual (bool)',     @TestCheckEqualBool);
  LSuite.Test('CheckEqual (pointer)',  @TestCheckEqualPtr);
  LSuite.Test('CheckNotEqual',         @TestCheckNotEqual);
  LSuite.Test('CheckTrue/False',       @TestCheckTrueFalse);
  LSuite.Test('CheckNil/NotNil',       @TestCheckNilNotNil);
  LSuite.Test('CheckContains',         @TestCheckContains);
  LSuite.Test('CheckStartsWith',       @TestCheckStartsWith);
  LSuite.Test('CheckEndsWith',         @TestCheckEndsWith);
  LSuite.Test('CheckSame',             @TestCheckSame);
  LSuite.Test('CheckInRange',          @TestCheckInRange);
  LSuite.Test('CheckLength',           @TestCheckLength);
  LSuite.Test('CheckRaises',           @TestCheckRaises);
  LSuite.Test('CheckNoRaise',          @TestCheckNoRaise);
  LSuite.Test('Fail',                  @TestFail);
  LSuite.Test('Skip',                  @TestSkip);

  if not LSuite.Run then
  begin
    WriteLn;
    WriteLn(AnsiRed('SOME TESTS FAILED'));
    Halt(1);
  end;
  WriteLn;
  WriteLn(AnsiGreen('ALL PASSED'));
end.
