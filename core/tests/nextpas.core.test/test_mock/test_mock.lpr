{ test_mock — TMock/TMockState tests
  =========================================================
  Validates: Setup, RecordCall, Verify, Returns variants,
             ResetCalls, CallCount, unconfigured return }
program test_mock;

{$I nextpas.core.settings.inc}

uses
  cthreads,
  SysUtils,
  nextpas.core.test.base,
  nextpas.core.test.runner,
  nextpas.core.test.check,
  nextpas.core.test.mock;

{ ── TMockValue constructors ────────────────────────────────────────────────── }

procedure TestMockStrConstructor;
var
  LValue: TMockValue;
begin
  LValue := MockStr('hello');
  CheckTrue(LValue.Kind = mvString, 'MockStr kind');
  CheckEqual('hello', LValue.StrVal);
  CheckEqual(Int64(0), LValue.IntVal);
  CheckFalse(LValue.BoolVal, 'MockStr bool default');
  CheckNear(0.0, LValue.DblVal, 0.0, 'MockStr double default');
end;

procedure TestMockIntConstructor;
var
  LValue: TMockValue;
begin
  LValue := MockInt(42);
  CheckTrue(LValue.Kind = mvInt64, 'MockInt kind');
  CheckEqual('', LValue.StrVal);
  CheckEqual(Int64(42), LValue.IntVal);
  CheckFalse(LValue.BoolVal, 'MockInt bool default');
  CheckNear(0.0, LValue.DblVal, 0.0, 'MockInt double default');
end;

procedure TestMockBoolConstructor;
var
  LValue: TMockValue;
begin
  LValue := MockBool(True);
  CheckTrue(LValue.Kind = mvBool, 'MockBool kind');
  CheckEqual('', LValue.StrVal);
  CheckEqual(Int64(0), LValue.IntVal);
  CheckTrue(LValue.BoolVal, 'MockBool value');
  CheckNear(0.0, LValue.DblVal, 0.0, 'MockBool double default');
end;

procedure TestMockDoubleConstructor;
var
  LValue: TMockValue;
begin
  LValue := MockDouble(3.25);
  CheckTrue(LValue.Kind = mvDouble, 'MockDouble kind');
  CheckEqual('', LValue.StrVal);
  CheckEqual(Int64(0), LValue.IntVal);
  CheckFalse(LValue.BoolVal, 'MockDouble bool default');
  CheckNear(3.25, LValue.DblVal, 1e-12, 'MockDouble value');
end;

{ ── Setup + GetReturn ──────────────────────────────────────────────────────── }

procedure TestSetupReturns;
var
  LM: TMock;
begin
  LM := TMock.Create;
  try
    LM.Setup('Foo').Returns('bar');
    CheckEqual('bar', LM.GetReturn('Foo'));
  finally
    LM.Free;
  end;
end;

procedure TestSetupChained;
var
  LM: TMock;
begin
  LM := TMock.Create;
  try
    LM.Setup('A').Returns('x').Returns('y');
    { Last .Returns wins }
    CheckEqual('y', LM.GetReturn('A'));
  finally
    LM.Free;
  end;
end;

procedure TestSetupMultipleMethods;
var
  LM: TMock;
begin
  LM := TMock.Create;
  try
    LM.Setup('Foo').Returns('hello');
    LM.Setup('Bar').Returns('world');
    CheckEqual('hello', LM.GetReturn('Foo'));
    CheckEqual('world', LM.GetReturn('Bar'));
  finally
    LM.Free;
  end;
end;

{ ── RecordCall + CallCount ─────────────────────────────────────────────────── }

procedure TestRecordCall;
var
  LM: TMock;
begin
  LM := TMock.Create;
  try
    LM.RecordCall('Foo', ['a', 'b']);
    CheckEqual(1, LM.CallCount('Foo'));
    CheckEqual(0, LM.CallCount('Bar'));
  finally
    LM.Free;
  end;
end;

procedure TestRecordCallMultiple;
var
  LM: TMock;
begin
  LM := TMock.Create;
  try
    LM.RecordCall('Foo', []);
    LM.RecordCall('Bar', []);
    LM.RecordCall('Foo', []);
    CheckEqual(2, LM.CallCount('Foo'));
    CheckEqual(1, LM.CallCount('Bar'));
  finally
    LM.Free;
  end;
end;

{ ── Verify ─────────────────────────────────────────────────────────────────── }

procedure TestVerifyCalledExactly;
var
  LM: TMock;
begin
  LM := TMock.Create;
  try
    LM.RecordCall('Foo', []);
    LM.RecordCall('Foo', []);
    { Should not raise }
    LM.Verify('Foo').CalledExactly(2);
  finally
    LM.Free;
  end;
end;

procedure TestVerifyCalledNever;
var
  LM: TMock;
begin
  LM := TMock.Create;
  try
    { Should not raise — Foo never called }
    LM.Verify('Foo').CalledNever;
  finally
    LM.Free;
  end;
end;

procedure TestVerifyCalledOnce;
var
  LM: TMock;
begin
  LM := TMock.Create;
  try
    LM.RecordCall('Foo', []);
    LM.Verify('Foo').CalledOnce;
  finally
    LM.Free;
  end;
end;

procedure TestVerifyCalledAtLeast;
var
  LM: TMock;
begin
  LM := TMock.Create;
  try
    LM.RecordCall('Foo', []);
    LM.RecordCall('Foo', []);
    LM.RecordCall('Foo', []);
    { 3 >= 2 → ok }
    LM.Verify('Foo').CalledAtLeast(2);
  finally
    LM.Free;
  end;
end;

procedure TestVerifyCalledAtMost;
var
  LM: TMock;
begin
  LM := TMock.Create;
  try
    LM.RecordCall('Foo', []);
    LM.RecordCall('Foo', []);
    { 2 <= 3 → ok }
    LM.Verify('Foo').CalledAtMost(3);
  finally
    LM.Free;
  end;
end;

{ ── ReturnsInt / ReturnsBool ───────────────────────────────────────────────── }

procedure TestReturnsInt;
var
  LM: TMock;
begin
  LM := TMock.Create;
  try
    LM.Setup('Val').ReturnsInt(42);
    CheckEqual(42, LM.GetReturnInt('Val'));
  finally
    LM.Free;
  end;
end;

procedure TestReturnsBoolTrue;
var
  LM: TMock;
begin
  LM := TMock.Create;
  try
    LM.Setup('Flag').ReturnsBool(True);
    CheckTrue(LM.GetReturnBool('Flag'), 'expected True');
  finally
    LM.Free;
  end;
end;

procedure TestReturnsBoolFalse;
var
  LM: TMock;
begin
  LM := TMock.Create;
  try
    LM.Setup('Flag').ReturnsBool(False);
    CheckFalse(LM.GetReturnBool('Flag'), 'expected False');
  finally
    LM.Free;
  end;
end;

{ ── Unconfigured return defaults ───────────────────────────────────────────── }

procedure TestGetReturnUnconfigured;
var
  LM: TMock;
begin
  LM := TMock.Create;
  try
    CheckEqual('', LM.GetReturn('NoSuch'));
    CheckEqual(0, LM.GetReturnInt('NoSuch'));
    CheckFalse(LM.GetReturnBool('NoSuch'), 'unconfigured bool should be False');
  finally
    LM.Free;
  end;
end;

{ ── ResetCalls keeps setup ─────────────────────────────────────────────────── }

procedure TestResetCallsPreservesSetup;
var
  LM: TMock;
begin
  LM := TMock.Create;
  try
    LM.Setup('Foo').Returns('keep');
    LM.RecordCall('Foo', []);
    LM.RecordCall('Foo', []);
    CheckEqual(2, LM.CallCount('Foo'));

    LM.ResetCalls;
    CheckTrue(LM.CallCount('Foo') = 0, 'calls should be cleared');
    CheckEqual('keep', LM.GetReturn('Foo'));
  finally
    LM.Free;
  end;
end;

{ ── Verify fail paths ───────────────────────────────────────────────────── }

procedure TestVerifyCalledExactlyFail;
var
  LM: TMock;
begin
  LM := TMock.Create;
  try
    LM.RecordCall('Foo', []);
    try
      LM.Verify('Foo').CalledExactly(3);
      Halt(1);
    except
      on E: EAssertionFailed do
        Check(Pos('exactly', LowerCase(E.Message)) > 0, 'exactly fail msg');
    end;
  finally
    LM.Free;
  end;
end;

procedure TestVerifyCalledNeverFail;
var
  LM: TMock;
begin
  LM := TMock.Create;
  try
    LM.RecordCall('Foo', []);
    try
      LM.Verify('Foo').CalledNever;
      Halt(1);
    except
      on E: EAssertionFailed do
        Check(Pos('exactly', LowerCase(E.Message)) > 0, 'never fail msg');
    end;
  finally
    LM.Free;
  end;
end;

procedure TestVerifyCalledOnceFail;
var
  LM: TMock;
begin
  LM := TMock.Create;
  try
    LM.RecordCall('Foo', []);
    LM.RecordCall('Foo', []);
    try
      LM.Verify('Foo').CalledOnce;
      Halt(1);
    except
      on E: EAssertionFailed do
        Check(Pos('exactly', LowerCase(E.Message)) > 0, 'once fail msg');
    end;
  finally
    LM.Free;
  end;
end;

procedure TestVerifyCalledAtLeastFail;
var
  LM: TMock;
begin
  LM := TMock.Create;
  try
    LM.RecordCall('Foo', []);
    try
      LM.Verify('Foo').CalledAtLeast(5);
      Halt(1);
    except
      on E: EAssertionFailed do
        Check(Pos('at least', LowerCase(E.Message)) > 0, 'at least fail msg');
    end;
  finally
    LM.Free;
  end;
end;

procedure TestVerifyCalledAtMostFail;
var
  LM: TMock;
begin
  LM := TMock.Create;
  try
    LM.RecordCall('Foo', []);
    LM.RecordCall('Foo', []);
    LM.RecordCall('Foo', []);
    try
      LM.Verify('Foo').CalledAtMost(1);
      Halt(1);
    except
      on E: EAssertionFailed do
        Check(Pos('at most', LowerCase(E.Message)) > 0, 'at most fail msg');
    end;
  finally
    LM.Free;
  end;
end;

{ ── GetReturnInt non-numeric ────────────────────────────────────────────── }

procedure TestGetReturnIntNonNumeric;
var
  LM: TMock;
begin
  LM := TMock.Create;
  try
    LM.Setup('Val').Returns('not_a_number');
    { GetReturnInt on non-numeric string should return 0 }
    CheckEqual(0, LM.GetReturnInt('Val'));
  finally
    LM.Free;
  end;
end;

{ ── State.Calls direct access ──────────────────────────────────────────────── }

procedure TestStateCallsDirectAccess;
var
  LM: TMock;
begin
  LM := TMock.Create;
  try
    LM.RecordCall('A', ['x']);
    LM.RecordCall('B', ['y', 'z']);
    CheckEqual(2, Length(LM.State.Calls));
    CheckEqual('A', LM.State.Calls[0].MethodName);
    CheckEqual(1, Length(LM.State.Calls[0].Args));
    CheckEqual('x', LM.State.Calls[0].Args[0]);
    CheckEqual('B', LM.State.Calls[1].MethodName);
    CheckEqual(2, Length(LM.State.Calls[1].Args));
  finally
    LM.Free;
  end;
end;

procedure TestStateCallsTypedArgsMirrorStrings;
var
  LM: TMock;
begin
  LM := TMock.Create;
  try
    LM.RecordCall('Mirror', ['left', 'right']);
    CheckEqual(2, Length(LM.State.Calls[0].TypedArgs));
    CheckTrue(LM.State.Calls[0].TypedArgs[0].Kind = mvString,
      'first typed arg kind');
    CheckEqual('left', LM.State.Calls[0].TypedArgs[0].StrVal);
    CheckTrue(LM.State.Calls[0].TypedArgs[1].Kind = mvString,
      'second typed arg kind');
    CheckEqual('right', LM.State.Calls[0].TypedArgs[1].StrVal);
  finally
    LM.Free;
  end;
end;

procedure TestRecordCallTypedPreservesLegacyArgs;
var
  LM: TMock;
begin
  LM := TMock.Create;
  try
    LM.State.RecordCallTyped('TypedCall', [
      MockStr('alpha'),
      MockInt(42),
      MockBool(True)
    ]);
    CheckEqual(1, LM.CallCount('TypedCall'));
    CheckEqual(3, Length(LM.State.Calls[0].TypedArgs));
    CheckTrue(LM.State.Calls[0].TypedArgs[0].Kind = mvString,
      'typed string arg kind');
    CheckEqual('alpha', LM.State.Calls[0].TypedArgs[0].StrVal);
    CheckTrue(LM.State.Calls[0].TypedArgs[1].Kind = mvInt64,
      'typed int arg kind');
    CheckEqual(Int64(42), LM.State.Calls[0].TypedArgs[1].IntVal);
    CheckTrue(LM.State.Calls[0].TypedArgs[2].Kind = mvBool,
      'typed bool arg kind');
    CheckTrue(LM.State.Calls[0].TypedArgs[2].BoolVal, 'typed bool arg value');
    CheckEqual('alpha', LM.State.Calls[0].Args[0]);
    CheckEqual('42', LM.State.Calls[0].Args[1]);
    CheckEqual('true', LM.State.Calls[0].Args[2]);
  finally
    LM.Free;
  end;
end;

procedure TestGetReturnTypedFromStringSetup;
var
  LM: TMock;
  LValue: TMockValue;
begin
  LM := TMock.Create;
  try
    LM.Setup('Echo').Returns('typed');
    LValue := LM.State.GetReturnTyped('Echo', [MockStr('ignored')]);
    CheckTrue(LValue.Kind = mvString, 'typed return kind');
    CheckEqual('typed', LValue.StrVal);
  finally
    LM.Free;
  end;
end;

procedure TestStateGetReturnInt64FromTypedSetup;
var
  LM: TMock;
  LValue: TMockValue;
begin
  LM := TMock.Create;
  try
    LM.Setup('Count').ReturnsInt(42);
    LValue := LM.State.GetReturnTyped('Count', []);
    CheckTrue(LValue.Kind = mvInt64, 'typed int return kind');
    CheckEqual(Int64(42), LValue.IntVal);
    CheckEqual(Int64(42), LM.State.GetReturnInt64('Count', ['legacy']));
  finally
    LM.Free;
  end;
end;

procedure TestStateGetReturnBoolFromTypedSetup;
var
  LM: TMock;
  LValue: TMockValue;
begin
  LM := TMock.Create;
  try
    LM.Setup('Flag').ReturnsBool(True);
    LValue := LM.State.GetReturnTyped('Flag', []);
    CheckTrue(LValue.Kind = mvBool, 'typed bool return kind');
    CheckTrue(LValue.BoolVal, 'typed bool return value');
    CheckTrue(LM.State.GetReturnBool('Flag', ['legacy']),
      'state typed bool getter');
  finally
    LM.Free;
  end;
end;

procedure TestTypedAndLegacyStringReturnCoexist;
var
  LM: TMock;
  LValue: TMockValue;
begin
  LM := TMock.Create;
  try
    LM.State.SetReturn('LegacyInt', '42');
    LM.State.SetReturn('LegacyFlag', 'true');

    LValue := LM.State.GetReturnTyped('LegacyInt', [MockStr('legacy')]);
    CheckTrue(LValue.Kind = mvString, 'legacy int typed kind');
    CheckEqual('42', LValue.StrVal);
    CheckEqual('42', LM.GetReturn('LegacyInt'));
    CheckEqual(Int64(42), LM.State.GetReturnInt64('LegacyInt', ['legacy']));

    LValue := LM.State.GetReturnTyped('LegacyFlag', [MockStr('legacy')]);
    CheckTrue(LValue.Kind = mvString, 'legacy bool typed kind');
    CheckEqual('true', LValue.StrVal);
    CheckTrue(LM.State.GetReturnBool('LegacyFlag', ['legacy']),
      'legacy bool fallback');
  finally
    LM.Free;
  end;
end;

procedure TestUnsetTypedReturnDefaults;
var
  LM: TMock;
  LValue: TMockValue;
begin
  LM := TMock.Create;
  try
    LValue := LM.State.GetReturnTyped('Missing', []);
    CheckTrue(LValue.Kind = mvUnset, 'unset typed kind');
    CheckEqual('', LM.GetReturn('Missing'));
    CheckEqual(Int64(0), LM.State.GetReturnInt64('Missing', []));
    CheckFalse(LM.State.GetReturnBool('Missing', []),
      'unset bool should be false');
  finally
    LM.Free;
  end;
end;

{ R6-46: Verify expects 1 but called 2 times → should fail }

procedure TestVerifyCalledExactlyOverCall;
var
  LM: TMock;
  LCaught: Boolean = False;
begin
  LM := TMock.Create;
  try
    LM.Setup('Foo').Returns('1');
    LM.RecordCall('Foo', []);
    LM.RecordCall('Foo', []);
    try
      LM.Verify('Foo').CalledExactly(1);
      Halt(1);
    except
      on E: EAssertionFailed do
        LCaught := True;
    end;
    CheckTrue(LCaught, 'Verify(1) should fail when called 2 times');
  finally
    LM.Free;
  end;
end;

{ R6-47: Duplicate Setup overwrites previous return value }

procedure TestSetupDuplicateOverwrite;
var
  LM: TMock;
begin
  LM := TMock.Create;
  try
    LM.Setup('Foo').Returns('1');
    LM.Setup('Foo').Returns('2');
    CheckEqual('2', LM.GetReturn('Foo'));
  finally
    LM.Free;
  end;
end;

{ R6-48: GetReturnInt negative return value }

procedure TestGetReturnIntNegative;
var
  LM: TMock;
begin
  LM := TMock.Create;
  try
    LM.Setup('Foo').Returns('-42');
    CheckEqual(Int64(-42), LM.GetReturnInt('Foo'));
  finally
    LM.Free;
  end;
end;

{ ── Register Tests ───────────────────────────────────────────────────────────── }

var
  Suite: TTestSuite;
  Runner: TTestRunner;
  LResults: specialize TArray<TTestRunResult>;
  LSuccess: Boolean;
begin
  WriteLn('=== test_mock ===');
  Suite := TTestSuite.Create('mock');
  Suite.Test('TestMockStrConstructor', @TestMockStrConstructor);
  Suite.Test('TestMockIntConstructor', @TestMockIntConstructor);
  Suite.Test('TestMockBoolConstructor', @TestMockBoolConstructor);
  Suite.Test('TestMockDoubleConstructor', @TestMockDoubleConstructor);
  Suite.Test('TestSetupReturns', @TestSetupReturns);
  Suite.Test('TestSetupChained', @TestSetupChained);
  Suite.Test('TestSetupMultipleMethods', @TestSetupMultipleMethods);
  Suite.Test('TestRecordCall', @TestRecordCall);
  Suite.Test('TestRecordCallMultiple', @TestRecordCallMultiple);
  Suite.Test('TestVerifyCalledExactly', @TestVerifyCalledExactly);
  Suite.Test('TestVerifyCalledNever', @TestVerifyCalledNever);
  Suite.Test('TestVerifyCalledOnce', @TestVerifyCalledOnce);
  Suite.Test('TestVerifyCalledAtLeast', @TestVerifyCalledAtLeast);
  Suite.Test('TestVerifyCalledAtMost', @TestVerifyCalledAtMost);
  Suite.Test('TestVerifyCalledExactlyFail', @TestVerifyCalledExactlyFail);
  Suite.Test('TestVerifyCalledNeverFail', @TestVerifyCalledNeverFail);
  Suite.Test('TestVerifyCalledOnceFail', @TestVerifyCalledOnceFail);
  Suite.Test('TestVerifyCalledAtLeastFail', @TestVerifyCalledAtLeastFail);
  Suite.Test('TestVerifyCalledAtMostFail', @TestVerifyCalledAtMostFail);
  Suite.Test('TestReturnsInt', @TestReturnsInt);
  Suite.Test('TestReturnsBoolTrue', @TestReturnsBoolTrue);
  Suite.Test('TestReturnsBoolFalse', @TestReturnsBoolFalse);
  Suite.Test('TestGetReturnUnconfigured', @TestGetReturnUnconfigured);
  Suite.Test('TestResetCallsPreservesSetup', @TestResetCallsPreservesSetup);
  Suite.Test('TestStateCallsDirectAccess', @TestStateCallsDirectAccess);
  Suite.Test('TestStateCallsTypedArgsMirrorStrings',
    @TestStateCallsTypedArgsMirrorStrings);
  Suite.Test('TestRecordCallTypedPreservesLegacyArgs',
    @TestRecordCallTypedPreservesLegacyArgs);
  Suite.Test('TestGetReturnTypedFromStringSetup',
    @TestGetReturnTypedFromStringSetup);
  Suite.Test('TestStateGetReturnInt64FromTypedSetup',
    @TestStateGetReturnInt64FromTypedSetup);
  Suite.Test('TestStateGetReturnBoolFromTypedSetup',
    @TestStateGetReturnBoolFromTypedSetup);
  Suite.Test('TestTypedAndLegacyStringReturnCoexist',
    @TestTypedAndLegacyStringReturnCoexist);
  Suite.Test('TestUnsetTypedReturnDefaults',
    @TestUnsetTypedReturnDefaults);
  Suite.Test('TestGetReturnIntNonNumeric', @TestGetReturnIntNonNumeric);

  { R6-46: Verify over-call }
  Suite.Test('TestVerifyCalledExactlyOverCall', @TestVerifyCalledExactlyOverCall);
  { R6-47: Duplicate Setup overwrite }
  Suite.Test('TestSetupDuplicateOverwrite', @TestSetupDuplicateOverwrite);
  { R6-48: GetReturnInt negative }
  Suite.Test('TestGetReturnIntNegative', @TestGetReturnIntNegative);

  Runner := TTestRunner.Create('mock-tests');
  Runner.Add(Suite);
  LSuccess := Runner.RunAllWithResult(LResults);
  WriteLn;
  Runner.Summary;

  if LSuccess then
    WriteLn('ALL PASSED')
  else
  begin
    WriteLn('SOME FAILED');
    Halt(1);
  end;
end.
