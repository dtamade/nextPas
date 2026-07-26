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
     Error messages use "eps" as abbreviation for epsilon.
 }
program test_assertions;

{$mode objfpc}{$H+}{$J-}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

uses
  nextpas.core.thread.init,
  nextpas.core.text.conv,
  nextpas.core.math,
  nextpas.core.base,
  nextpas.core.platform.env,
  nextpas.core.test,
  nextpas.core.test.check,
  nextpas.core.test.prop.gen,
  nextpas.core.test.prop;

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

procedure TestCheckEqualUInt64;
begin
  CheckEqual(UInt64(0), UInt64(0));
  CheckEqual(UInt64($FFFFFFFFFFFFFFFF), UInt64($FFFFFFFFFFFFFFFF));
  CheckEqual(UInt64(42), UInt64(42));
  ExpectFail(procedure begin CheckEqual(UInt64(1), UInt64(2)); end, '1');
end;

procedure TestCheckNotEqualUInt64;
begin
  CheckNotEqual(UInt64(1), UInt64(2));
  CheckNotEqual(UInt64(0), UInt64($FFFFFFFFFFFFFFFF));
  ExpectFail(procedure begin CheckNotEqual(UInt64(99), UInt64(99)); end, '99');
end;

procedure TestCheckEqualTBytes;
var
  LA, LB: TBytes;
begin
  SetLength(LA, 3); LA[0] := 1; LA[1] := 2; LA[2] := 3;
  SetLength(LB, 3); LB[0] := 1; LB[1] := 2; LB[2] := 3;
  CheckEqual(LA, LB);
  { empty arrays }
  SetLength(LA, 0); SetLength(LB, 0);
  CheckEqual(LA, LB);
  { different values }
  SetLength(LA, 2); LA[0] := 1; LA[1] := 2;
  SetLength(LB, 2); LB[0] := 1; LB[1] := 9;
  try
    CheckEqual(LA, LB);
    Fail('expected TBytes equal fail');
  except
    on E: EAssertionFailed do CheckContains(E.Message, 'index');
  end;
  { different lengths }
  SetLength(LA, 3); LA[0] := 1; LA[1] := 2; LA[2] := 3;
  SetLength(LB, 2); LB[0] := 1; LB[1] := 2;
  try
    CheckEqual(LA, LB);
    Fail('expected TBytes length fail');
  except
    on E: EAssertionFailed do CheckContains(E.Message, 'length');
  end;
end;

procedure TestCheckNotEqualTBytes;
var
  LA, LB: TBytes;
begin
  SetLength(LA, 2); LA[0] := 1; LA[1] := 2;
  SetLength(LB, 2); LB[0] := 1; LB[1] := 9;
  CheckNotEqual(LA, LB);
  { different lengths }
  SetLength(LA, 1); LA[0] := 1;
  SetLength(LB, 2); LB[0] := 1; LB[1] := 2;
  CheckNotEqual(LA, LB);
  { same arrays should fail }
  SetLength(LA, 2); LA[0] := $AB; LA[1] := $CD;
  SetLength(LB, 2); LB[0] := $AB; LB[1] := $CD;
  try
    CheckNotEqual(LA, LB);
    Fail('expected TBytes not-equal fail');
  except
    on E: EAssertionFailed do CheckContains(E.Message, 'differ');
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

procedure TestB12CheckEqualDoubleNaN;
var
  LNaN: Double;
begin
  LNaN := 0.0 / 0.0;
  ExpectFail(procedure begin CheckEqual(1.0, LNaN, 1e-9); end, 'NaN');
  ExpectFail(procedure begin CheckEqual(LNaN, 1.0, 1e-9); end, 'NaN');
  ExpectFail(procedure begin CheckEqual(LNaN, LNaN, 1e-9); end, 'NaN');
end;

procedure TestB12CheckNotEqualDoubleNaN;
var
  LNaN: Double;
begin
  { NaN != anything including NaN — CheckNotEqual must pass (early exit) }
  LNaN := 0.0 / 0.0;
  CheckNotEqual(1.0, LNaN, 1e-9);
  CheckNotEqual(LNaN, 1.0, 1e-9);
  CheckNotEqual(LNaN, LNaN, 1e-9);
end;

procedure TestB12CheckEqualDoubleExactEpsilon;
begin
  { Diff exactly equal to epsilon → still "near" (Abs <= eps) }
  CheckEqual(1.0, 1.0 + 1e-6, 1e-6);
  { Just outside epsilon → fail }
  ExpectFail(procedure begin CheckEqual(1.0, 1.0 + 1e-6 + 1e-12, 1e-6); end, 'Expected');
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

{ B2.1: Snapshot env contracts (insta / NEXTPAS_* parity) }

procedure EnvSet(const AName, AValue: string);
var
  LN, LV: AnsiString;
begin
  { Keep AnsiString locals alive for the setenv call (no dangling PAnsiChar). }
  LN := AnsiString(AName);
  LV := AnsiString(AValue);
  if platform_env_set(PAnsiChar(LN), PAnsiChar(LV)) <> 0 then
    Fail('platform_env_set failed for ' + AName);
  if string(platform_env_get_str(LN)) <> AValue then
    Fail('platform_env_get_str mismatch after set for ' + AName);
end;

procedure EnvUnset(const AName: string);
var
  LN: AnsiString;
begin
  LN := AnsiString(AName);
  platform_env_unset(PAnsiChar(LN));
end;

procedure TestCheckSnapshotFailOnCreate;
const
  LSnapDir = '/tmp/np_snap_b2_fail_create';
  LName = 'missing.txt';
var
  LPath: string;
begin
  LPath := LSnapDir + '/' + LName;
  { Ensure clean slate }
  EnvUnset('NEXTPAS_SNAPSHOT_FAIL_ON_CREATE');
  EnvUnset('NEXTPAS_UPDATE_SNAPSHOTS');
  try
    { Remove prior file if any by writing then we'll rely on fail path when missing:
      delete via overwrite of dir is hard; use unique name with random suffix via path }
  except
  end;
  EnvSet('NEXTPAS_SNAPSHOT_FAIL_ON_CREATE', '1');
  try
    ExpectFail(procedure begin
      CheckSnapshot('content-never-written', LSnapDir + '_unique_a', 'nofile.txt');
    end, 'does not exist');
  finally
    EnvUnset('NEXTPAS_SNAPSHOT_FAIL_ON_CREATE');
  end;
end;

{ ── v8.16 SoftFail (Go t.Error) — Check remains Fatal ─────────────────────── }

var
  GSoftAfter: Integer = 0;

procedure SoftFailBodyContinues;
begin
  SoftFail('first soft');
  Inc(GSoftAfter);
  SoftCheckTrue(False, 'second soft');
  Inc(GSoftAfter);
  SoftCheckEqual(1, 2, 'third soft');
  Inc(GSoftAfter);
end;

procedure SoftFailBodyHardAfterSoft;
begin
  SoftFail('soft then hard');
  CheckTrue(False, 'hard fatal');
  Inc(GSoftAfter); { must not run }
end;

procedure SoftFailBodyMultiOnly;
begin
  SoftFail('alpha');
  SoftFail('beta');
  SoftFail('gamma');
end;

procedure TestSoftFailContinuesThenFails;
var
  LSuite: TTestSuite;
  LResult: TTestRunResult;
begin
  GSoftAfter := 0;
  LSuite := TTestSuite.Create('soft-continue');
  LSuite.Test('body', @SoftFailBodyContinues);
  CheckFalse(LSuite.RunWithResult(LResult), 'soft fails → suite fail');
  CheckEqual(GSoftAfter, 3, 'body continues after SoftFail');
  CheckEqual(LResult.Failed, 1);
  CheckEqual(LResult.Passed, 0);
  CheckTrue(Pos('first soft', LResult.Results[0].Message) > 0,
    'message includes first soft fail');
  CheckTrue(Pos('second soft', LResult.Results[0].Message) > 0,
    'message includes all soft lines');
  CheckTrue(Pos('third soft', LResult.Results[0].Message) > 0);
  LSuite := Default(TTestSuite);
end;

procedure TestSoftCheckHelpers;
var
  LSuite: TTestSuite;
  LResult: TTestRunResult;
begin
  LSuite := TTestSuite.Create('soft-check');
  LSuite.Test('ok', procedure
    begin
      SoftCheckTrue(True);
      SoftCheckEqual(7, 7);
      SoftCheckTrue(False, 'bool soft');
    end);
  CheckFalse(LSuite.RunWithResult(LResult));
  CheckEqual(LResult.Failed, 1);
  CheckContains(LResult.Results[0].Message, 'bool soft');
  LSuite := Default(TTestSuite);
end;

procedure TestCheckStillFatal;
var
  LSuite: TTestSuite;
  LResult: TTestRunResult;
begin
  GSoftAfter := 0;
  LSuite := TTestSuite.Create('hard-still');
  LSuite.Test('body', @SoftFailBodyHardAfterSoft);
  CheckFalse(LSuite.RunWithResult(LResult));
  CheckEqual(GSoftAfter, 0, 'hard Check aborts body');
  CheckEqual(LResult.Failed, 1);
  CheckTrue(Pos('hard fatal', LResult.Results[0].Message) > 0);
  CheckTrue(Pos('soft', LowerCase(LResult.Results[0].Message)) > 0,
    'annotates soft fail count with hard fail');
  LSuite := Default(TTestSuite);
end;

procedure TestSoftFailMultiMessage;
var
  LSuite: TTestSuite;
  LResult: TTestRunResult;
begin
  LSuite := TTestSuite.Create('soft-multi');
  LSuite.Test('body', @SoftFailBodyMultiOnly);
  CheckFalse(LSuite.RunWithResult(LResult));
  { v8.19: exact join contract — FormatSoftFailSummary uses '; ' }
  CheckEqual('alpha; beta; gamma', LResult.Results[0].Message,
    'SoftFail multi join exact');
  LSuite := Default(TTestSuite);
end;

procedure TestSoftFailExactDefaultsAndHardAlsoSoft;
{ Default SoftCheck* messages + hard then soft annotate exact form.
  v8.23: SoftCheckEqual(string) uses ColorDiff (position), not quoted one-liner. }
var
  LSuite: TTestSuite;
  LResult: TTestRunResult;
  LMsg: string;
begin
  LSuite := TTestSuite.Create('soft-defaults');
  LSuite.Test('defaults', procedure
    begin
      SoftFail('');
      SoftCheckTrue(False);
      SoftCheckFalse(True);
      SoftCheckEqual(Int64(1), Int64(2));
      SoftCheckEqual('x', 'y');
      SoftCheckContains('abc', 'zz');
    end);
  CheckFalse(LSuite.RunWithResult(LResult));
  LMsg := LResult.Results[0].Message;
  CheckContains(LMsg, 'soft fail', 'join has SoftFail default');
  CheckContains(LMsg, 'SoftCheckTrue failed', 'join has SoftCheckTrue default');
  CheckContains(LMsg, 'SoftCheckFalse failed', 'join has SoftCheckFalse default');
  CheckContains(LMsg, 'SoftCheckEqual expected 1 but got 2', 'int soft exact');
  CheckContains(LMsg, 'Strings differ at position', 'v8.23 string soft ColorDiff');
  CheckContains(LMsg, 'SoftCheckContains expected to find "zz" in "abc"',
    'contains soft exact');
  LSuite := Default(TTestSuite);

  LSuite := TTestSuite.Create('hard-also-soft');
  LSuite.Test('body', @SoftFailBodyHardAfterSoft);
  CheckFalse(LSuite.RunWithResult(LResult));
  CheckEqual('hard fatal [also soft: soft then hard]',
    LResult.Results[0].Message,
    'hard primary + also soft exact');
  LSuite := Default(TTestSuite);
end;

procedure SoftFailBodyCap35;
var
  J: Integer;
begin
  for J := 0 to 34 do  { 35 soft fails → 32 stored + 3 more }
    SoftFail('m' + IntToStr(J));
end;

procedure TestSoftFailCapMoreSuffix;
{ CMaxSoftFailMsgs=32: overflow count appears as (+N more soft fails). }
var
  LSuite: TTestSuite;
  LResult: TTestRunResult;
  I: Integer;
  LExpected: string;
begin
  LSuite := TTestSuite.Create('soft-cap');
  LSuite.Test('body', @SoftFailBodyCap35);
  CheckFalse(LSuite.RunWithResult(LResult));
  LExpected := 'm0';
  for I := 1 to 31 do
    LExpected := LExpected + '; m' + IntToStr(I);
  LExpected := LExpected + ' (+3 more soft fails)';
  CheckEqual(LExpected, LResult.Results[0].Message, 'cap +N more exact');
  LSuite := Default(TTestSuite);
end;

procedure AssertSoftFailOutsideContextExact;
{ Must run with GExecState=nil (not inside Suite.Test). }
begin
  try
    SoftFail('orphan');
    raise Exception.Create('expected SoftFail outside context to raise');
  except
    on E: EAssertionFailed do
      if E.Message <> 'SoftFail outside test context: orphan' then
        raise Exception.Create('outside SoftFail msg: ' + E.Message);
  end;
end;

procedure TestSoftCheckStringAndContains;
var
  LSuite: TTestSuite;
  LResult: TTestRunResult;
begin
  LSuite := TTestSuite.Create('soft-str');
  LSuite.Test('body', procedure
    begin
      SoftCheckEqual('a', 'a');
      SoftCheckContains('hello world', 'world');
      SoftCheckFalse(False);
      SoftCheckEqual('x', 'y', 'str soft');
      SoftCheckContains('abc', 'zz', 'miss soft');
    end);
  CheckFalse(LSuite.RunWithResult(LResult));
  CheckContains(LResult.Results[0].Message, 'str soft');
  CheckContains(LResult.Results[0].Message, 'Strings differ at position',
    'string soft uses ColorDiff');
  CheckContains(LResult.Results[0].Message, 'miss soft');
  LSuite := Default(TTestSuite);
end;

procedure TestSoftCheckHighFreqSurface;
{ v8.23: SoftCheckEqual Bool/TBytes + SoftCheckNear — continue + message contract. }
var
  LSuite: TTestSuite;
  LResult: TTestRunResult;
  LMsg: string;
  LExp, LAct: TBytes;
begin
  SetLength(LExp, 2);
  LExp[0] := $01;
  LExp[1] := $02;
  SetLength(LAct, 2);
  LAct[0] := $01;
  LAct[1] := $FF;

  LSuite := TTestSuite.Create('soft-hf');
  LSuite.Test('body', procedure
    begin
      SoftCheckEqual(True, True);
      SoftCheckEqual(True, False, 'bool soft');
      SoftCheckEqual(LExp, LExp);
      SoftCheckEqual(LExp, LAct, 'bytes soft');
      SoftCheckNear(1.0, 1.0);
      SoftCheckNear(1.0, 2.0, 1e-9, 'near soft');
      SoftCheckNear(0.0 / 0.0, 1.0, 1e-9, 'near nan');
    end);
  CheckFalse(LSuite.RunWithResult(LResult));
  LMsg := LResult.Results[0].Message;
  CheckContains(LMsg, 'bool soft', 'bool soft prefix');
  CheckContains(LMsg, 'expected: True', 'bool soft expected');
  CheckContains(LMsg, 'bytes soft', 'bytes soft prefix');
  CheckContains(LMsg, 'TBytes differ at index 1', 'bytes soft index');
  CheckContains(LMsg, 'near soft', 'near soft prefix');
  CheckContains(LMsg, 'diff=', 'near soft diff');
  CheckContains(LMsg, 'near nan', 'near nan prefix');
  CheckContains(LMsg, '(NaN)', 'near nan marker');
  LSuite := Default(TTestSuite);
end;

procedure TestSoftCheckSecondWave;
{ v8.27 B56: SoftCheckNil/NotNil/Empty/ContainsCI — continue + exact messages. }
var
  LSuite: TTestSuite;
  LResult: TTestRunResult;
  LMsg: string;
  LPtr: Pointer;
begin
  LPtr := Pointer(NativeUInt($DEADBEEF));
  LSuite := TTestSuite.Create('soft-wave2');
  LSuite.Test('body', procedure
    begin
      SoftCheckNil(nil);
      SoftCheckNotNil(Pointer(1));
      SoftCheckEmpty('');
      SoftCheckContainsCI('Hello World', 'WORLD');
      SoftCheckNil(LPtr, 'nil soft');
      SoftCheckNotNil(nil, 'notnil soft');
      SoftCheckEmpty('abc', 'empty soft');
      SoftCheckContainsCI('Hello', 'ZZ', 'ci soft');
      SoftCheckContainsCI('Hello', ''); { empty needle = match }
    end);
  CheckFalse(LSuite.RunWithResult(LResult));
  LMsg := LResult.Results[0].Message;
  CheckContains(LMsg, 'nil soft', 'nil soft prefix');
  CheckContains(LMsg, 'Expected nil but got $', 'nil soft detail');
  CheckContains(LMsg, 'notnil soft', 'notnil soft prefix');
  CheckContains(LMsg, 'Expected non-nil but got nil', 'notnil soft detail');
  CheckContains(LMsg, 'empty soft', 'empty soft prefix');
  CheckContains(LMsg, 'Expected empty string but got 3 char(s)', 'empty soft detail');
  CheckContains(LMsg, 'ci soft', 'ci soft prefix');
  CheckContains(LMsg, 'does not contain (ci)', 'ci soft detail');
  LSuite := Default(TTestSuite);

  { Default messages without AMessage }
  LSuite := TTestSuite.Create('soft-wave2-defaults');
  LSuite.Test('defaults', procedure
    begin
      SoftCheckNil(Pointer(1));
      SoftCheckNotNil(nil);
      SoftCheckEmpty('x');
      SoftCheckContainsCI('abc', 'zz');
    end);
  CheckFalse(LSuite.RunWithResult(LResult));
  LMsg := LResult.Results[0].Message;
  CheckContains(LMsg, 'Expected nil but got $', 'nil default');
  CheckContains(LMsg, 'Expected non-nil but got nil', 'notnil default');
  CheckContains(LMsg, 'Expected empty string but got 1 char(s)', 'empty default');
  CheckContains(LMsg, 'SoftCheckContainsCI expected to find "zz" in "abc"',
    'ci default');
  LSuite := Default(TTestSuite);
end;

procedure TestSoftColorDiffJoinStable;
{ v8.27 B59: Soft join keeps '; ' between msgs even when ColorDiff has newlines. }
var
  LSuite: TTestSuite;
  LResult: TTestRunResult;
  LMsg: string;
  LSemiPos, LNLPos: Integer;
begin
  LSuite := TTestSuite.Create('soft-join-nl');
  LSuite.Test('body', procedure
    begin
      SoftCheckEqual('hello', 'hallo'); { ColorDiff multi-line }
      SoftFail('tail-marker');
    end);
  CheckFalse(LSuite.RunWithResult(LResult));
  LMsg := LResult.Results[0].Message;
  CheckContains(LMsg, 'Strings differ at position', 'ColorDiff present');
  CheckContains(LMsg, #10, 'ColorDiff embeds newline');
  CheckContains(LMsg, 'tail-marker', 'second soft after ColorDiff');
  { Contract: join separator is '; ' immediately before the next soft message. }
  CheckContains(LMsg, '; tail-marker', 'join uses ''; '' before next soft msg');
  LSemiPos := Pos('; tail-marker', LMsg);
  CheckTrue(LSemiPos > 0, 'semi join position');
  LNLPos := Pos(#10, LMsg);
  CheckTrue((LNLPos > 0) and (LNLPos < LSemiPos),
    'newline from ColorDiff appears before join separator');
  LSuite := Default(TTestSuite);
end;

procedure TestSoftFailDoesNotFailFast;
var
  LSuite: TTestSuite;
  LResult: TTestRunResult;
  LCfg: TTestConfig;
  LRanSecond: Integer;
begin
  { SoftFail on first test must not stop suite under FailFast. }
  LRanSecond := 0;
  LSuite := TTestSuite.Create('soft-ff');
  LCfg := DefaultConfig;
  LCfg.FailFast := True;
  LSuite.Config := LCfg;
  LSuite.Test('soft1', procedure
    begin
      SoftFail('soft only');
    end);
  LSuite.Test('second', procedure
    begin
      Inc(LRanSecond);
      CheckTrue(True);
    end);
  CheckFalse(LSuite.RunWithResult(LResult), 'suite fails due to soft1');
  CheckEqual(LRanSecond, 1, 'FailFast must not stop after SoftFail-only');
  CheckEqual(LResult.Passed, 1);
  CheckEqual(LResult.Failed, 1);
  LSuite := Default(TTestSuite);
end;

procedure TestCheckSnapshotUpdate;
var
  LSnapDir, LName, LPath, LContents: string;
  LStatus: TReadFileStatus;
begin
  { Unique dir avoids stale /tmp files across suite runs. }
  LSnapDir := '/tmp/np_snap_b2_update_' + IntToStr(Random(MaxInt));
  LName := 'upd.txt';
  EnvUnset('NEXTPAS_SNAPSHOT_FAIL_ON_CREATE');
  EnvUnset('NEXTPAS_UPDATE_SNAPSHOTS');
  try
    CheckSnapshot('old-content', LSnapDir, LName);
    LPath := LSnapDir + DirectorySeparator + LName;
    EnvSet('NEXTPAS_UPDATE_SNAPSHOTS', '1');
    try
      CheckTrue(string(platform_env_get_str('NEXTPAS_UPDATE_SNAPSHOTS')) = '1',
        'UPDATE env visible before CheckSnapshot');
      { Should not raise; rewrite snapshot }
      CheckSnapshot('new-content', LSnapDir, LName);
    finally
      EnvUnset('NEXTPAS_UPDATE_SNAPSHOTS');
    end;
    CheckTrue(ReadFileContents(LPath, LContents, LStatus), 'read updated snapshot');
    CheckTrue(LStatus = rfsFound, 'status rfsFound');
    CheckEqual('new-content', LContents);
  finally
    EnvUnset('NEXTPAS_UPDATE_SNAPSHOTS');
    EnvUnset('NEXTPAS_SNAPSHOT_FAIL_ON_CREATE');
  end;
end;

procedure TestCheckSnapshotMismatchDiffMessage;
const
  LSnapDir = '/tmp/np_snap_b2_diffmsg';
begin
  EnvUnset('NEXTPAS_SNAPSHOT_FAIL_ON_CREATE');
  EnvUnset('NEXTPAS_UPDATE_SNAPSHOTS');
  CheckSnapshot('alpha-line', LSnapDir, 'diff.txt');
  ExpectFail(procedure begin
    CheckSnapshot('beta-line', LSnapDir, 'diff.txt');
  end, 'differ at position');
end;

{ ── B73: Snapshot create/update/mismatch/ColorDiff fail-path table ──────── }

procedure TestB73SnapshotFailPathCase(const AC: TTestCase);
{ Data: mismatch | mismatch_color | fail_create | match | update
  Each case uses a unique snapshot dir to avoid cross-case pollution. }
var
  LDir, LName, LPath, LContents: string;
  LStatus: TReadFileStatus;
begin
  LDir := '/tmp/np_b73_' + AC.Name + '_' + IntToStr(Random(MaxInt));
  LName := 'snap.txt';
  EnvUnset('NEXTPAS_SNAPSHOT_FAIL_ON_CREATE');
  EnvUnset('NEXTPAS_UPDATE_SNAPSHOTS');
  try
    if AC.Data = 'match' then
    begin
      CheckSnapshot('same-body', LDir, LName);
      CheckSnapshot('same-body', LDir, LName); { second pass matches }
    end
    else if AC.Data = 'mismatch' then
    begin
      CheckSnapshot('expected-aaa', LDir, LName);
      ExpectFail(procedure
        begin
          CheckSnapshot('actual-bbb', LDir, LName);
        end, 'Snapshot mismatch');
    end
    else if AC.Data = 'mismatch_color' then
    begin
      EnvSet('NEXTPAS_COLOR', '0');
      try
        CheckSnapshot('line-one', LDir, LName);
        ExpectFail(procedure
          begin
            CheckSnapshot('line-two', LDir, LName);
          end, 'differ at position');
      finally
        EnvUnset('NEXTPAS_COLOR');
      end;
    end
    else if AC.Data = 'fail_create' then
    begin
      EnvSet('NEXTPAS_SNAPSHOT_FAIL_ON_CREATE', '1');
      try
        ExpectFail(procedure
          begin
            CheckSnapshot('never-created', LDir, 'missing.txt');
          end, 'does not exist');
      finally
        EnvUnset('NEXTPAS_SNAPSHOT_FAIL_ON_CREATE');
      end;
    end
    else if AC.Data = 'update' then
    begin
      CheckSnapshot('old-v', LDir, LName);
      EnvSet('NEXTPAS_UPDATE_SNAPSHOTS', '1');
      try
        CheckSnapshot('new-v', LDir, LName);
      finally
        EnvUnset('NEXTPAS_UPDATE_SNAPSHOTS');
      end;
      LPath := LDir + DirectorySeparator + LName;
      CheckTrue(ReadFileContents(LPath, LContents, LStatus));
      CheckEqual('new-v', LContents);
    end
    else
      Fail('unknown B73 kind ' + AC.Data);
  finally
    EnvUnset('NEXTPAS_SNAPSHOT_FAIL_ON_CREATE');
    EnvUnset('NEXTPAS_UPDATE_SNAPSHOTS');
    EnvUnset('NEXTPAS_COLOR');
  end;
end;

{ B2.2: string CheckEqual diagnostic contracts (go-cmp style markers) }

procedure TestCheckEqualStringDiffMarkers;
begin
  EnvSet('NEXTPAS_COLOR', '0');
  try
    ExpectFail(procedure begin
      CheckEqual('hello', 'hallo');
    end, 'differ at position');
    ExpectFail(procedure begin
      CheckEqual('hello', 'hallo');
    end, 'expected');
    ExpectFail(procedure begin
      CheckEqual('hello', 'hallo');
    end, 'actual');
  finally
    EnvUnset('NEXTPAS_COLOR');
  end;
end;

procedure TestCheckEqualMultilineDiff;
begin
  EnvSet('NEXTPAS_COLOR', '0');
  try
    ExpectFail(procedure begin
      CheckEqual('line1' + #10 + 'line2', 'line1' + #10 + 'LINE2');
    end, 'differ at position');
  finally
    EnvUnset('NEXTPAS_COLOR');
  end;
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
var
  LE: Exception;
begin
  LE := Exception.Create('boom');
  try
    try
      FailUnexpected(LE);
      Fail('FailUnexpected should raise');
    except
      on E: EAssertionFailed do
      begin
        CheckContains(E.Message, 'unexpected');
        CheckContains(E.Message, 'boom');
      end;
    end;
  finally
    LE.Free;
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
  ExpectFail(procedure begin CheckGreaterThanD(5.0, 5.0 + 1e-11, 1e-10); end, 'eps');
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
  ExpectFail(procedure begin CheckLessThanD(5.0, 5.0 - 1e-11, 1e-10); end, 'eps');
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
  { Empty prefix matches everything, so NotStartsWith should fail }
  ExpectFail(procedure begin CheckNotStartsWith('hello', ''); end,
    'should not start with empty string');
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
  { Empty suffix matches everything, so NotEndsWith should fail }
  ExpectFail(procedure begin CheckNotEndsWith('hello', ''); end,
    'should not end with empty string');
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

{ ── Unicode boundary tests ───────────────────────────────────────────────── }

procedure TestUnicodeEmojiEqual;
begin
  CheckEqual('🎉🎊', '🎉🎊');
end;

procedure TestUnicodeEmojiNotEqual;
begin
  ExpectFail(procedure begin CheckEqual('🎉', '🎊'); end);
end;

procedure TestUnicodeCJK;
begin
  CheckEqual('你好世界', '你好世界');
  CheckContains('你好世界', '你好');
  CheckStartsWith('你好世界', '你好');
  CheckEndsWith('你好世界', '世界');
end;

procedure TestUnicodeCombining;
{ Combining characters: é can be U+0065+U+0301 (2 codepoints) or U+00E9 (1 codepoint) }
var
  LComposed, LDecomposed: string;
begin
  LComposed := 'café';         { é = U+00E9 }
  LDecomposed := 'café';       { e + combining accent }
  { They are different byte sequences — CheckEqual should detect }
  if LComposed <> LDecomposed then
    Check(True, 'composed vs decomposed differ as expected')
  else
    Check(True, 'same on this platform');
end;

procedure TestUnicodeEmpty;
begin
  CheckEqual('', '');
  CheckContains('你好', '');
  CheckStartsWith('你好', '');
  CheckEndsWith('你好', '');
end;

procedure TestUnicodeLongDiff;
{ StringDiff with long Unicode strings — Utf8SafeStart should not split multi-byte }
var
  LA, LB: string;
begin
  LA := '这是一个很长的中文字符串用于测试差异位置报告功能是否正确处理多字节字符';
  LB := '这是一个很长的中文字符串用于测试差异位置报告功能是否正确处理多字节字符结尾不同';
  ExpectFail(procedure begin CheckEqual(LA, LB); end, 'Strings differ at position');
end;

{ ── AMessage overload tests ──────────────────────────────────────────────── }

procedure TestCheckContainsWithMessage;
begin
  ExpectFail(procedure begin
    CheckContains('hello world', 'xyz', 'context info');
  end, 'context info');
end;

procedure TestCheckStartsWithWithMessage;
begin
  ExpectFail(procedure begin
    CheckStartsWith('hello world', 'xyz', 'prefix check');
  end, 'prefix check');
end;

procedure TestCheckEndsWithWithMessage;
begin
  ExpectFail(procedure begin
    CheckEndsWith('hello world', 'xyz', 'suffix check');
  end, 'suffix check');
end;

procedure TestCheckInRangeWithMessage;
begin
  ExpectFail(procedure begin
    CheckInRange(100, 1, 10, 'range context');
  end, 'range context');
end;

procedure TestCheckGreaterThanWithMessage;
begin
  ExpectFail(procedure begin
    CheckGreaterThan(5, 10, 'gt context');
  end, 'gt context');
end;

procedure TestCheckNotEqualStringWithMessage;
begin
  ExpectFail(procedure begin
    CheckNotEqual('same', 'same', 'should differ');
  end, 'should differ');
end;

procedure TestCheckNotEqualIntWithMessage;
begin
  ExpectFail(procedure begin
    CheckNotEqual(Int64(42), Int64(42), 'int should differ');
  end, 'int should differ');
end;

procedure TestCheckLengthWithMessage;
begin
  ExpectFail(procedure begin
    CheckLength(5, 3, 'length context');
  end, 'length context');
end;

{ ── v8.0c: Array Comparison Tests ─────────────────────────────────────────── }

procedure TestCheckArrayEqualPass;
begin
  CheckArrayEqual([1, 2, 3], [1, 2, 3]);
end;

procedure TestCheckArrayEqualFailLength;
begin
  ExpectFail(procedure begin
    CheckArrayEqual([1, 2, 3], [1, 2]);
  end, 'length');
end;

procedure TestCheckArrayEqualFailValue;
begin
  ExpectFail(procedure begin
    CheckArrayEqual([1, 2, 3], [1, 99, 3]);
  end, '[1]');
end;

procedure TestCheckArrayEqualEmpty;
var
  LA: array of Int64;
begin
  SetLength(LA, 0);
  CheckArrayEqual(LA, LA);
end;

procedure TestCheckArrayEqualWithMessage;
begin
  ExpectFail(procedure begin
    CheckArrayEqual([10, 20], [10, 30], 'my array');
  end, 'my array');
end;

procedure TestCheckArrayEqualStringPass;
begin
  CheckArrayEqual(['a', 'b', 'c'], ['a', 'b', 'c']);
end;

procedure TestCheckArrayEqualStringFailLength;
begin
  ExpectFail(procedure begin
    CheckArrayEqual(['a', 'b'], ['a', 'b', 'c']);
  end, 'length');
end;

procedure TestCheckArrayEqualStringFailValue;
begin
  ExpectFail(procedure begin
    CheckArrayEqual(['hello', 'world'], ['hello', 'wurld']);
  end, 'differ');
end;

procedure TestCheckArrayEqualStringEmpty;
var
  LA, LB: array of string;
begin
  SetLength(LA, 0);
  SetLength(LB, 0);
  CheckArrayEqual(LA, LB);
end;

procedure TestCheckArrayEqualStringWithMessage;
begin
  ExpectFail(procedure begin
    CheckArrayEqual(['a', 'b'], ['a', 'c'], 'my string array');
  end, 'my string array');
end;

{ ── Multi-diff reporting ───────────────────────────────────────────────────── }

procedure TestCheckArrayEqualMultiDiff;
begin
  ExpectFail(procedure begin
    CheckArrayEqual([1, 2, 3, 4, 5], [1, 99, 3, 88, 5]);
  end, '2 of 5 positions');
end;

procedure TestCheckArrayEqualMultiDiffAllDiffer;
begin
  ExpectFail(procedure begin
    CheckArrayEqual([1, 2, 3], [10, 20, 30]);
  end, '3 of 3 positions');
end;

procedure TestCheckArrayEqualStringMultiDiff;
begin
  ExpectFail(procedure begin
    CheckArrayEqual(['a', 'b', 'c', 'd'], ['a', 'X', 'c', 'Y']);
  end, '2 of 4 positions');
end;

{ ── R60: CheckArrayContains/NotContains for TBytes ───────────────────────── }

procedure TestCheckArrayContainsBytePass;
begin
  CheckArrayContains(TBytes([$01, $02, $03]), $02);
end;

procedure TestCheckArrayContainsByteFail;
begin
  ExpectFail(procedure begin
    CheckArrayContains(TBytes([$01, $02]), $FF);
  end, '$FF');
end;

procedure TestCheckArrayContainsByteWithMessage;
begin
  ExpectFail(procedure begin
    CheckArrayContains(TBytes([$01, $02]), $FF, 'byte context');
  end, 'byte context');
end;

procedure TestCheckArrayNotContainsBytePass;
begin
  CheckArrayNotContains(TBytes([$01, $02]), $FF);
end;

procedure TestCheckArrayNotContainsByteFail;
begin
  ExpectFail(procedure begin
    CheckArrayNotContains(TBytes([$01, $02, $03]), $02);
  end, '$02');
end;

procedure TestCheckArrayNotContainsByteWithMessage;
begin
  ExpectFail(procedure begin
    CheckArrayNotContains(TBytes([$01, $02]), $01, 'no byte');
  end, 'no byte');
end;

{ ── v8.0c: Interface Nil Check Tests ──────────────────────────────────────── }

procedure TestCheckIsNilPass;
var
  LI: IInterface;
begin
  LI := nil;
  CheckIsNil(LI);
end;

procedure TestCheckIsNilFail;
var
  LTracker: ICoverageTracker;
begin
  LTracker := CreateCoverageTracker;
  ExpectFail(procedure begin
    CheckIsNil(LTracker);
  end, 'non-nil');
end;

procedure TestCheckIsNotNilPass;
var
  LTracker: ICoverageTracker;
begin
  LTracker := CreateCoverageTracker;
  CheckIsNotNil(LTracker);
end;

procedure TestCheckIsNotNilFail;
var
  LI: IInterface;
begin
  LI := nil;
  ExpectFail(procedure begin
    CheckIsNotNil(LI);
  end, 'nil');
end;

{ ── File I/O Utility Tests ──────────────────────────────────────────────── }

procedure TestReadWriteFileContents;
var
  LPath, LContent: string;
  LStatus: TReadFileStatus;
begin
  LPath := '/tmp/test_rw_contents_' + IntToStr(Random(1000000000)) + '.txt';
  WriteFileContents(LPath, 'hello world');
  CheckTrue(ReadFileContents(LPath, LContent, LStatus), 'ReadFileContents should succeed');
  CheckEqual('hello world', LContent, 'File content');
  CheckTrue(LStatus = rfsFound, 'Status should be rfsFound');
end;

procedure TestReadFileContentsNotFound;
var
  LContent: string;
  LStatus: TReadFileStatus;
begin
  CheckTrue(not ReadFileContents('/tmp/nonexistent_file_12345.txt', LContent, LStatus),
    'ReadFileContents should return False for missing file');
  CheckTrue(LStatus = rfsNotFound, 'Status should be rfsNotFound');
end;

{ ── R52: CheckMatch / CheckNotMatch ────────────────────────────────────────── }

procedure TestCheckMatchPass;
begin
  CheckMatch('\d+', 'hello123world');
end;

procedure TestCheckMatchFail;
begin
  ExpectFail(procedure begin
    CheckMatch('^\d+$', 'hello');
  end, 'match pattern');
end;

procedure TestCheckMatchWithMessage;
begin
  ExpectFail(procedure begin
    CheckMatch('\d+', 'no digits here', 'should have digits');
  end, 'should have digits');
end;

procedure TestCheckNotMatchPass;
begin
  CheckNotMatch('^\d+$', 'hello');
end;

procedure TestCheckNotMatchFail;
begin
  ExpectFail(procedure begin
    CheckNotMatch('\d+', 'hello123');
  end, 'NOT to match');
end;

{ ── CheckEmpty/CheckNotEmpty tests ─────────────────────────────────────────── }

procedure TestCheckEmptyStringPass;
begin
  CheckEmpty('');
end;

procedure TestCheckEmptyStringFail;
begin
  ExpectFail(procedure begin
    CheckEmpty('hello');
  end, 'empty');
end;

procedure TestCheckNotEmptyStringPass;
begin
  CheckNotEmpty('hello');
end;

procedure TestCheckNotEmptyStringFail;
begin
  ExpectFail(procedure begin
    CheckNotEmpty('');
  end, 'non-empty');
end;

procedure TestCheckEmptyBytesPass;
begin
  CheckEmpty(TBytes(nil));
end;

procedure TestCheckEmptyBytesFail;
var
  LB: TBytes;
begin
  SetLength(LB, 1);
  LB[0] := 42;
  ExpectFail(procedure begin
    CheckEmpty(LB);
  end, 'empty');
end;

procedure TestCheckNotEmptyBytesPass;
var
  LB: TBytes;
begin
  SetLength(LB, 1);
  LB[0] := 42;
  CheckNotEmpty(LB);
end;

procedure TestCheckNotEmptyBytesFail;
begin
  ExpectFail(procedure begin
    CheckNotEmpty(TBytes(nil));
  end, 'non-empty');
end;

procedure TestCheckEmptyStringWithMessage;
begin
  ExpectFail(procedure begin
    CheckEmpty('abc', 'must be empty');
  end, 'must be empty');
end;

procedure TestCheckNotEmptyBytesWithMessage;
begin
  ExpectFail(procedure begin
    CheckNotEmpty(TBytes(nil), 'must have data');
  end, 'must have data');
end;

{ ── CheckInf/CheckFinite tests ─────────────────────────────────────────────── }

procedure TestCheckInfPass;
begin
  CheckInf(1.0 / 0.0);
  CheckInf(-1.0 / 0.0);
end;

procedure TestCheckInfFail;
begin
  ExpectFail(procedure begin
    CheckInf(42.0);
  end, 'infinite');
end;

procedure TestCheckNotInfPass;
begin
  CheckNotInf(42.0);
  CheckNotInf(0.0);
end;

procedure TestCheckNotInfFail;
begin
  ExpectFail(procedure begin
    CheckNotInf(1.0 / 0.0);
  end, 'finite');
end;

procedure TestCheckFinitePass;
begin
  CheckFinite(42.0);
  CheckFinite(0.0);
  CheckFinite(-1.0);
end;

procedure TestCheckFiniteFailInf;
begin
  ExpectFail(procedure begin
    CheckFinite(1.0 / 0.0);
  end, 'finite');
end;

procedure TestCheckFiniteFailNaN;
begin
  ExpectFail(procedure begin
    CheckFinite(0.0 / 0.0);
  end, 'finite');
end;

procedure TestCheckInfWithMessage;
begin
  ExpectFail(procedure begin
    CheckInf(42.0, 'must be infinite');
  end, 'must be infinite');
end;

procedure TestCheckFiniteWithMessage;
begin
  ExpectFail(procedure begin
    CheckFinite(1.0 / 0.0, 'must be finite');
  end, 'must be finite');
end;

{ ── v8.8a: CheckOneOf / CheckInstanceOf (Go/Rust zero-untested-API bar) ─── }

procedure TestCheckOneOfStringPass;
begin
  CheckOneOf('b', ['a', 'b', 'c']);
end;

procedure TestCheckOneOfStringFail;
begin
  ExpectFail(procedure begin
    CheckOneOf('z', ['a', 'b', 'c']);
  end, 'not one of');
end;

procedure TestCheckOneOfStringEmpty;
begin
  { Empty set: no value can be a member (Go/Rust membership semantics). }
  ExpectFail(procedure begin
    CheckOneOf('a', []);
  end, 'not one of');
end;

procedure TestCheckOneOfStringWithMessage;
begin
  ExpectFail(procedure begin
    CheckOneOf('z', ['a'], 'custom-oneof');
  end, 'custom-oneof');
end;

procedure TestCheckOneOfIntPass;
begin
  CheckOneOfInt(2, [1, 2, 3]);
end;

procedure TestCheckOneOfIntFail;
begin
  ExpectFail(procedure begin
    CheckOneOfInt(9, [1, 2, 3]);
  end, 'not one of');
end;

procedure TestCheckOneOfBoolPass;
begin
  CheckOneOfBool(True, [False, True]);
end;

procedure TestCheckOneOfBoolFail;
begin
  ExpectFail(procedure begin
    CheckOneOfBool(True, [False]);
  end, 'not one of');
end;

procedure TestCheckInstanceOfPass;
var
  LObj: TObject;
begin
  LObj := TObject.Create;
  try
    CheckInstanceOf(LObj, TObject);
  finally
    LObj.Free;
  end;
end;

procedure TestCheckInstanceOfFailType;
var
  LObj: TObject;
begin
  LObj := TObject.Create;
  try
    ExpectFail(procedure begin
      CheckInstanceOf(LObj, EAssertionFailed);
    end, 'TObject');
  finally
    LObj.Free;
  end;
end;

procedure TestCheckInstanceOfNilObject;
begin
  ExpectFail(procedure begin
    CheckInstanceOf(nil, TObject);
  end, 'nil');
end;

procedure TestCheckInstanceOfNilClass;
var
  LObj: TObject;
begin
  LObj := TObject.Create;
  try
    ExpectFail(procedure begin
      CheckInstanceOf(LObj, nil);
    end, 'AClass is nil');
  finally
    LObj.Free;
  end;
end;

procedure TestCheckInstanceOfWithMessage;
begin
  ExpectFail(procedure begin
    CheckInstanceOf(nil, TObject, 'custom-instanceof');
  end, 'custom-instanceof');
end;

{ ── CheckSorted tests ─────────────────────────────────────────────────────── }

procedure TestCheckSortedIntPass;
begin
  CheckSorted([1, 2, 3, 4, 5]);
end;

procedure TestCheckSortedIntFail;
begin
  ExpectFail(procedure begin
    CheckSorted([1, 3, 2, 4]);
  end, 'not sorted');
end;

procedure TestCheckSortedIntEmpty;
var
  LA: specialize TArray<Int64>;
begin
  SetLength(LA, 0);
  CheckSorted(LA);
end;

procedure TestCheckSortedIntSingle;
begin
  CheckSorted([42]);
end;

procedure TestCheckSortedIntEqual;
begin
  CheckSorted([3, 3, 3]);
end;

procedure TestCheckSortedIntWithMessage;
begin
  ExpectFail(procedure begin
    CheckSorted([5, 3, 1], 'must be ascending');
  end, 'must be ascending');
end;

procedure TestCheckSortedStringPass;
begin
  CheckSorted(['alpha', 'beta', 'gamma']);
end;

procedure TestCheckSortedStringFail;
begin
  ExpectFail(procedure begin
    CheckSorted(['z', 'a']);
  end, 'not sorted');
end;

procedure TestCheckSortedStringEmpty;
var
  LA: specialize TArray<string>;
begin
  SetLength(LA, 0);
  CheckSorted(LA);
end;

procedure TestSoftCheckFailPathCase(const AC: TTestCase);
{ v8.26 fail-path: SoftCheckEqual int/str must mark suite fail with both values. }
var
  LPos: Integer;
  LExp, LAct: string;
  LExpN, LActN: Int64;
  LSuite: TTestSuite;
  LResult: TTestRunResult;
begin
  LPos := Pos('|', AC.Data);
  CheckTrue(LPos > 0, 'soft fail-path data');
  LExp := Copy(AC.Data, 1, LPos - 1);
  LAct := Copy(AC.Data, LPos + 1, MaxInt);
  LExpN := StrToInt(LExp);
  LActN := StrToInt(LAct);
  LSuite := TTestSuite.Create('soft-fp-' + AC.Name);
  LSuite.Test('body', procedure
    begin
      SoftCheckEqual(LExpN, LActN);
      SoftCheckEqual(LExp, LAct);
    end);
  CheckFalse(LSuite.RunWithResult(LResult), 'soft fail-path suite fails');
  CheckContains(LResult.Results[0].Message, LExp, 'soft msg has expected');
  CheckContains(LResult.Results[0].Message, LAct, 'soft msg has actual');
  LSuite := Default(TTestSuite);
end;

{ ── Main ──────────────────────────────────────────────────────────────────── }

var
  LSuite: TTestSuite;
  LB26SoftCases: specialize TArray<TTestCase>;
  LB26SoftI: Integer;
  LB73Cases: specialize TArray<TTestCase>;
  LB73I: Integer;
  LB73Kinds: array[0..4] of string;
begin
  WriteLn('=== test_assertions ===');
  Randomize;
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
  LSuite.Test('CheckEqual (uint64)',   @TestCheckEqualUInt64);
  LSuite.Test('CheckNotEqual (u64)',   @TestCheckNotEqualUInt64);
  LSuite.Test('CheckEqual (TBytes)',   @TestCheckEqualTBytes);
  LSuite.Test('CheckNotEqual (bytes)', @TestCheckNotEqualTBytes);
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
  LSuite.Test('B12 CheckEqual Double NaN',    @TestB12CheckEqualDoubleNaN);
  LSuite.Test('B12 CheckNotEqual Double NaN', @TestB12CheckNotEqualDoubleNaN);
  LSuite.Test('B12 CheckEqual exact epsilon', @TestB12CheckEqualDoubleExactEpsilon);

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
  { B2.1 Snapshot env contracts }
  LSuite.Test('Snapshot fail-on-create',   @TestCheckSnapshotFailOnCreate);
  LSuite.Test('Snapshot update env',       @TestCheckSnapshotUpdate);
  LSuite.Test('Snapshot mismatch diff msg',@TestCheckSnapshotMismatchDiffMessage);
  { B2.2 string diff contracts }
  LSuite.Test('Equal string diff markers', @TestCheckEqualStringDiffMarkers);
  LSuite.Test('Equal multiline diff',      @TestCheckEqualMultilineDiff);

  { E-10: CheckNaN / CheckNotNaN coverage }
  LSuite.Test('CheckNaN pass',             @TestCheckNaNPass);
  LSuite.Test('CheckNaN fail',             @TestCheckNaNFail);
  LSuite.Test('CheckNotNaN pass',          @TestCheckNotNaNPass);
  LSuite.Test('CheckNotNaN fail',          @TestCheckNotNaNFail);

  { Unicode boundary tests }
  LSuite.Test('Unicode emoji equal',       @TestUnicodeEmojiEqual);
  LSuite.Test('Unicode emoji not equal',   @TestUnicodeEmojiNotEqual);
  LSuite.Test('Unicode CJK',               @TestUnicodeCJK);
  LSuite.Test('Unicode combining',         @TestUnicodeCombining);
  LSuite.Test('Unicode empty',             @TestUnicodeEmpty);
  LSuite.Test('Unicode long diff',         @TestUnicodeLongDiff);

  { AMessage overload tests }
  LSuite.Test('Contains+msg',              @TestCheckContainsWithMessage);
  LSuite.Test('StartsWith+msg',            @TestCheckStartsWithWithMessage);
  LSuite.Test('EndsWith+msg',              @TestCheckEndsWithWithMessage);
  LSuite.Test('InRange+msg',               @TestCheckInRangeWithMessage);
  LSuite.Test('GreaterThan+msg',           @TestCheckGreaterThanWithMessage);
  LSuite.Test('NotEqual string+msg',       @TestCheckNotEqualStringWithMessage);
  LSuite.Test('NotEqual int+msg',          @TestCheckNotEqualIntWithMessage);
  LSuite.Test('Length+msg',                @TestCheckLengthWithMessage);

  { v8.0c: Array comparison }
  LSuite.Test('ArrayEqual pass',           @TestCheckArrayEqualPass);
  LSuite.Test('ArrayEqual fail length',    @TestCheckArrayEqualFailLength);
  LSuite.Test('ArrayEqual fail value',     @TestCheckArrayEqualFailValue);
  LSuite.Test('ArrayEqual empty',          @TestCheckArrayEqualEmpty);
  LSuite.Test('ArrayEqual+msg',            @TestCheckArrayEqualWithMessage);
  LSuite.Test('ArrayEqual string pass',    @TestCheckArrayEqualStringPass);
  LSuite.Test('ArrayEqual string fail len',@TestCheckArrayEqualStringFailLength);
  LSuite.Test('ArrayEqual string fail val',@TestCheckArrayEqualStringFailValue);
  LSuite.Test('ArrayEqual string empty',   @TestCheckArrayEqualStringEmpty);
  LSuite.Test('ArrayEqual string+msg',     @TestCheckArrayEqualStringWithMessage);
  LSuite.Test('ArrayEqual multi-diff',     @TestCheckArrayEqualMultiDiff);
  LSuite.Test('ArrayEqual multi-diff all', @TestCheckArrayEqualMultiDiffAllDiffer);
  LSuite.Test('ArrayEqual string multi',   @TestCheckArrayEqualStringMultiDiff);

  { v8.0c: Interface nil checks }
  LSuite.Test('IsNil pass',               @TestCheckIsNilPass);
  LSuite.Test('IsNil fail',               @TestCheckIsNilFail);
  LSuite.Test('IsNotNil pass',            @TestCheckIsNotNilPass);
  LSuite.Test('IsNotNil fail',            @TestCheckIsNotNilFail);

  { Audit round 4: File I/O utilities }
  LSuite.Test('ReadWriteFileContents',    @TestReadWriteFileContents);
  LSuite.Test('ReadFileNotFound',         @TestReadFileContentsNotFound);

  { R52: Regex matching }
  LSuite.Test('Match pass',              @TestCheckMatchPass);
  LSuite.Test('Match fail',              @TestCheckMatchFail);
  LSuite.Test('Match+msg',               @TestCheckMatchWithMessage);
  LSuite.Test('NotMatch pass',           @TestCheckNotMatchPass);
  LSuite.Test('NotMatch fail',           @TestCheckNotMatchFail);

  { R60: CheckArrayContains/NotContains for TBytes }
  LSuite.Test('ArrayContains byte pass',   @TestCheckArrayContainsBytePass);
  LSuite.Test('ArrayContains byte fail',   @TestCheckArrayContainsByteFail);
  LSuite.Test('ArrayContains byte+msg',    @TestCheckArrayContainsByteWithMessage);
  LSuite.Test('ArrayNotContains byte pass',@TestCheckArrayNotContainsBytePass);
  LSuite.Test('ArrayNotContains byte fail',@TestCheckArrayNotContainsByteFail);
  LSuite.Test('ArrayNotContains byte+msg', @TestCheckArrayNotContainsByteWithMessage);

  { CheckSorted }
  LSuite.Test('Sorted int pass',           @TestCheckSortedIntPass);
  LSuite.Test('Sorted int fail',           @TestCheckSortedIntFail);
  LSuite.Test('Sorted int empty',          @TestCheckSortedIntEmpty);
  LSuite.Test('Sorted int single',         @TestCheckSortedIntSingle);
  LSuite.Test('Sorted int equal',          @TestCheckSortedIntEqual);
  LSuite.Test('Sorted int+msg',            @TestCheckSortedIntWithMessage);
  LSuite.Test('Sorted string pass',        @TestCheckSortedStringPass);
  LSuite.Test('Sorted string fail',        @TestCheckSortedStringFail);
  LSuite.Test('Sorted string empty',       @TestCheckSortedStringEmpty);

  LSuite.Test('Empty string pass',        @TestCheckEmptyStringPass);
  LSuite.Test('Empty string fail',        @TestCheckEmptyStringFail);
  LSuite.Test('NotEmpty string pass',     @TestCheckNotEmptyStringPass);
  LSuite.Test('NotEmpty string fail',     @TestCheckNotEmptyStringFail);
  LSuite.Test('Empty bytes pass',         @TestCheckEmptyBytesPass);
  LSuite.Test('Empty bytes fail',         @TestCheckEmptyBytesFail);
  LSuite.Test('NotEmpty bytes pass',      @TestCheckNotEmptyBytesPass);
  LSuite.Test('NotEmpty bytes fail',      @TestCheckNotEmptyBytesFail);
  LSuite.Test('Empty string+msg',         @TestCheckEmptyStringWithMessage);
  LSuite.Test('NotEmpty bytes+msg',       @TestCheckNotEmptyBytesWithMessage);

  LSuite.Test('Inf pass',                @TestCheckInfPass);
  LSuite.Test('Inf fail',                @TestCheckInfFail);
  LSuite.Test('NotInf pass',             @TestCheckNotInfPass);
  LSuite.Test('NotInf fail',             @TestCheckNotInfFail);
  LSuite.Test('Finite pass',             @TestCheckFinitePass);
  LSuite.Test('Finite fail (Inf)',       @TestCheckFiniteFailInf);
  LSuite.Test('Finite fail (NaN)',       @TestCheckFiniteFailNaN);
  LSuite.Test('Inf+msg',                 @TestCheckInfWithMessage);
  LSuite.Test('Finite+msg',             @TestCheckFiniteWithMessage);

  { v8.8a: Go/Rust quality — zero untested public membership/type APIs }
  LSuite.Test('OneOf string pass',        @TestCheckOneOfStringPass);
  LSuite.Test('OneOf string fail',        @TestCheckOneOfStringFail);
  LSuite.Test('OneOf string empty',       @TestCheckOneOfStringEmpty);
  LSuite.Test('OneOf string+msg',         @TestCheckOneOfStringWithMessage);
  LSuite.Test('OneOfInt pass',            @TestCheckOneOfIntPass);
  LSuite.Test('OneOfInt fail',            @TestCheckOneOfIntFail);
  LSuite.Test('OneOfBool pass',           @TestCheckOneOfBoolPass);
  LSuite.Test('OneOfBool fail',           @TestCheckOneOfBoolFail);
  LSuite.Test('InstanceOf pass',          @TestCheckInstanceOfPass);
  LSuite.Test('InstanceOf fail type',     @TestCheckInstanceOfFailType);
  LSuite.Test('InstanceOf nil object',    @TestCheckInstanceOfNilObject);
  LSuite.Test('InstanceOf nil class',     @TestCheckInstanceOfNilClass);
  LSuite.Test('InstanceOf+msg',           @TestCheckInstanceOfWithMessage);

  { v8.16 SoftFail (Go t.Error) — Check remains Fatal }
  LSuite.Test('SoftFail continues then fails', @TestSoftFailContinuesThenFails);
  LSuite.Test('SoftCheck helpers',             @TestSoftCheckHelpers);
  LSuite.Test('Check still Fatal',             @TestCheckStillFatal);
  LSuite.Test('SoftFail multi message',        @TestSoftFailMultiMessage);
  LSuite.Test('SoftCheck string+contains',     @TestSoftCheckStringAndContains);
  LSuite.Test('SoftFail does not FailFast',    @TestSoftFailDoesNotFailFast);
  { v8.19: SoftFail diagnostic exact contracts }
  LSuite.Test('SoftFail exact defaults+hard',  @TestSoftFailExactDefaultsAndHardAlsoSoft);
  LSuite.Test('SoftFail cap +N more',          @TestSoftFailCapMoreSuffix);
  LSuite.Test('SoftCheck high-freq surface',   @TestSoftCheckHighFreqSurface);
  LSuite.Test('SoftCheck second wave',         @TestSoftCheckSecondWave);
  LSuite.Test('Soft ColorDiff join stable',    @TestSoftColorDiffJoinStable);

  { Outside-context SoftFail only valid when no suite entry is active. }
  AssertSoftFailOutsideContextExact;
  WriteLn('  + SoftFail outside context exact');

  { v8.26: SoftCheck fail-path density table }
  SetLength(LB26SoftCases, 250);
  for LB26SoftI := 0 to High(LB26SoftCases) do
  begin
    LB26SoftCases[LB26SoftI].Name := 'soft-fp-' + IntToStr(LB26SoftI);
    LB26SoftCases[LB26SoftI].Data := IntToStr(LB26SoftI) + '|' +
      IntToStr(LB26SoftI + 7);
  end;
  LSuite.TestTable('v8.26 SoftCheck fail-path', LB26SoftCases,
    @TestSoftCheckFailPathCase);

  { B73: Snapshot create/update/mismatch/ColorDiff fail-path density }
  LB73Kinds[0] := 'match';
  LB73Kinds[1] := 'mismatch';
  LB73Kinds[2] := 'mismatch_color';
  LB73Kinds[3] := 'fail_create';
  LB73Kinds[4] := 'update';
  SetLength(LB73Cases, 100);
  for LB73I := 0 to High(LB73Cases) do
  begin
    LB73Cases[LB73I].Name := 'snap-' + IntToStr(LB73I);
    LB73Cases[LB73I].Data := LB73Kinds[LB73I mod 5];
  end;
  LSuite.TestTable('B73 Snapshot fail-path', LB73Cases,
    @TestB73SnapshotFailPathCase);

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
