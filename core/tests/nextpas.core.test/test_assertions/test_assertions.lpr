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
    on E: EAssertionFailed do
      Check(Pos('True', E.Message) > 0, 'msg contains True');
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
    on E: EAssertionFailed do
      Check(Pos('pointer', LowerCase(E.Message)) > 0, 'msg contains pointer');
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
    on E: EAssertionFailed do Check(Pos('differ', E.Message) > 0, 'msg');
  end;
end;

procedure TestCheckNotEqualBool;
begin
  CheckNotEqual(True, False);
  try
    CheckNotEqual(True, True);
    Halt(1);
  except
    on E: EAssertionFailed do Check(Pos('True', E.Message) > 0, 'bool msg');
  end;
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
    on E: EAssertionFailed do Check(Pos('differ', LowerCase(E.Message)) > 0, 'ptr msg');
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
    on E: EAssertionFailed do Check(Pos('should fail', E.Message) > 0, 'msg');
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
    on E: EAssertionFailed do Check(Pos('non-nil', LowerCase(E.Message)) > 0, 'msg');
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
    on E: EAssertionFailed do Check(Pos('does not contain', E.Message) > 0, 'msg');
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
    on E: EAssertionFailed do Check(Pos('does not start', E.Message) > 0, 'msg');
  end;
end;

procedure TestCheckEndsWith;
begin
  CheckEndsWith('hello world', 'world');
  CheckEndsWith('abc', 'bc');
  { Empty suffix matches everything (consistent with ToEndWith) }
  CheckEndsWith('hello', '');
  CheckEndsWith('', '');
  try
    CheckEndsWith('hello', 'xyz');
    Halt(1);
  except
    on E: EAssertionFailed do Check(Pos('does not end', E.Message) > 0, 'msg');
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
    on E: EAssertionFailed do Check(Pos('should be same', E.Message) > 0, 'msg');
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
    on E: EAssertionFailed do Check(Pos('not in range', E.Message) > 0, 'msg');
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
    on E: EAssertionFailed do Check(Pos('Expected length', E.Message) > 0, 'msg');
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
    on E: EAssertionFailed do
      Check(Pos('EConvertError', E.Message) > 0, 'msg contains expected class');
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
    on E: EAssertionFailed do
      Check(Pos('EConvertError', E.Message) > 0, 'msg contains class');
  end;
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
  LSuite.Test('CheckNotEqual (bool)',  @TestCheckNotEqualBool);
  LSuite.Test('CheckNotEqual (ptr)',   @TestCheckNotEqualPtr);
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
  LSuite.Test('CheckRaises+Skip',      @TestCheckRaisesSkipPassthrough);
  LSuite.Test('CheckNoRaise+Skip',     @TestCheckNoRaiseSkipPassthrough);
  LSuite.Test('StartsWith empty',      @TestCheckStartsWithEmptyPrefix);
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
