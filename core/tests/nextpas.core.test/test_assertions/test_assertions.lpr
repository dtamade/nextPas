{ test_assertions — Validates Check* procedural API }
program test_assertions;

{$mode objfpc}{$H+}{$J-}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

uses
  cthreads,
  SysUtils,
  nextpas.core.test,
  nextpas.core.test.helpers;

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

  if not LSuite.Run then
  begin
    WriteLn;
    FailTest('SOME TESTS FAILED');
  end;
  WriteLn;
  PassTest('ALL PASSED');
end.
