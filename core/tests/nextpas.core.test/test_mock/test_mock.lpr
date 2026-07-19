{ test_mock — TMock/TMockState tests
  =========================================================
  Validates: Setup, RecordCall, Verify, Returns variants,
             ResetCalls, CallCount, unconfigured return

  Usage pattern — Three-step mock workflow:
    1. Create mock instance:
       LMock := TMock.Create;

    2. Configure behavior (optional):
       LMock.When('MethodName').WithArgs([MockStr('input')]).ReturnStr('output');
       LMock.When('MethodName').ReturnInt(42);      // default return for any args

    3. Exercise + Verify:
       LMock.Mock.Method('MethodName', [MockStr('input')]);
       LMock.Verify('MethodName').CalledExactly(1);

    ⚠ When/Returns/RecordCall all use string-based method names.
       Typos in method names are NOT caught at compile time.
       Verify calls CompareText (case-insensitive) — 'Foo' matches 'foo'.

    VerifyAll checks all methods configured via Setup (Returns/When).
       If you need to verify a method was called but don't need Setup, use:
       LMock.Verify('MethodName').CalledExactly(1);  // explicit verify
 }
program test_mock;

{$mode objfpc}{$H+}{$J-}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

uses
  nextpas.core.thread.init,
  nextpas.core.text.conv,
  nextpas.core.test;

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

procedure TestSetupReturnsImpl(AMock: TMock);
begin
    AMock.Setup('Foo').Returns('bar');
    CheckEqual('bar', AMock.GetReturn('Foo'));
end;

procedure TestSetupReturns;
begin
  WithMock(@TestSetupReturnsImpl);
end;

procedure TestSetupChainedImpl(AMock: TMock);
begin
    AMock.Setup('A').Returns('x').Returns('y');
    { Last .Returns wins }
    CheckEqual('y', AMock.GetReturn('A'));
end;

procedure TestSetupChained;
begin
  WithMock(@TestSetupChainedImpl);
end;

procedure TestSetupMultipleMethodsImpl(AMock: TMock);
begin
    AMock.Setup('Foo').Returns('hello');
    AMock.Setup('Bar').Returns('world');
    CheckEqual('hello', AMock.GetReturn('Foo'));
    CheckEqual('world', AMock.GetReturn('Bar'));
end;

procedure TestSetupMultipleMethods;
begin
  WithMock(@TestSetupMultipleMethodsImpl);
end;

procedure TestRecordCallImpl(AMock: TMock);
begin
    AMock.RecordCall('Foo', ['a', 'b']);
    CheckEqual(1, AMock.CallCount('Foo'));
    CheckEqual(0, AMock.CallCount('Bar'));
end;

procedure TestRecordCall;
begin
  WithMock(@TestRecordCallImpl);
end;

procedure TestRecordCallMultipleImpl(AMock: TMock);
begin
    AMock.RecordCall('Foo', []);
    AMock.RecordCall('Bar', []);
    AMock.RecordCall('Foo', []);
    CheckEqual(2, AMock.CallCount('Foo'));
    CheckEqual(1, AMock.CallCount('Bar'));
end;

procedure TestRecordCallMultiple;
begin
  WithMock(@TestRecordCallMultipleImpl);
end;

procedure TestVerifyCalledExactlyImpl(AMock: TMock);
begin
    AMock.RecordCall('Foo', []);
    AMock.RecordCall('Foo', []);
    { Should not raise }
    AMock.Verify('Foo').CalledExactly(2);
end;

procedure TestVerifyCalledExactly;
begin
  WithMock(@TestVerifyCalledExactlyImpl);
end;

procedure TestVerifyCalledNeverImpl(AMock: TMock);
begin
    { Should not raise — Foo never called }
    AMock.Verify('Foo').CalledNever;
end;

procedure TestVerifyCalledNever;
begin
  WithMock(@TestVerifyCalledNeverImpl);
end;

procedure TestVerifyCalledOnceImpl(AMock: TMock);
begin
    AMock.RecordCall('Foo', []);
    AMock.Verify('Foo').CalledOnce;
end;

procedure TestVerifyCalledOnce;
begin
  WithMock(@TestVerifyCalledOnceImpl);
end;

procedure TestVerifyCalledAtLeastImpl(AMock: TMock);
begin
    AMock.RecordCall('Foo', []);
    AMock.RecordCall('Foo', []);
    AMock.RecordCall('Foo', []);
    { 3 >= 2 → ok }
    AMock.Verify('Foo').CalledAtLeast(2);
end;

procedure TestVerifyCalledAtLeast;
begin
  WithMock(@TestVerifyCalledAtLeastImpl);
end;

procedure TestVerifyCalledAtMostImpl(AMock: TMock);
begin
    AMock.RecordCall('Foo', []);
    AMock.RecordCall('Foo', []);
    { 2 <= 3 → ok }
    AMock.Verify('Foo').CalledAtMost(3);
end;

procedure TestVerifyCalledAtMost;
begin
  WithMock(@TestVerifyCalledAtMostImpl);
end;

procedure TestReturnsIntImpl(AMock: TMock);
begin
    AMock.Setup('Val').ReturnsInt(42);
    CheckEqual(42, AMock.GetReturnInt('Val'));
end;

procedure TestReturnsInt;
begin
  WithMock(@TestReturnsIntImpl);
end;

procedure TestReturnsBoolTrueImpl(AMock: TMock);
begin
    AMock.Setup('Flag').ReturnsBool(True);
    CheckTrue(AMock.GetReturnBool('Flag'), 'expected True');
end;

procedure TestReturnsBoolTrue;
begin
  WithMock(@TestReturnsBoolTrueImpl);
end;

procedure TestReturnsBoolFalseImpl(AMock: TMock);
begin
    AMock.Setup('Flag').ReturnsBool(False);
    CheckFalse(AMock.GetReturnBool('Flag'), 'expected False');
end;

procedure TestReturnsBoolFalse;
begin
  WithMock(@TestReturnsBoolFalseImpl);
end;

procedure TestReturnsDoubleImpl(AMock: TMock);
var
  LValue: TMockValue;
begin
    AMock.Setup('Pi').ReturnsDouble(3.14);
    LValue := AMock.State.GetReturnTyped('Pi', []);
    CheckTrue(LValue.Kind = mvDouble, 'expected mvDouble return kind');
    CheckNear(3.14, LValue.DblVal, 1e-12, 'expected 3.14 typed return');
end;

procedure TestReturnsDouble;
begin
  WithMock(@TestReturnsDoubleImpl);
end;

procedure TestGetTypedReturnOverloadsWithArgsImpl(AMock: TMock);
begin
    AMock.Setup('Count').ReturnsInt(7);
    AMock.Setup('Flag').ReturnsBool(True);
    CheckEqual(Int64(7), AMock.GetReturnInt('Count', ['legacy']));
    CheckTrue(AMock.GetReturnBool('Flag', ['legacy']),
      'bool overload with args should preserve configured value');
end;

procedure TestGetTypedReturnOverloadsWithArgs;
begin
  WithMock(@TestGetTypedReturnOverloadsWithArgsImpl);
end;

procedure TestGetReturnUnconfiguredImpl(AMock: TMock);
begin
    CheckEqual('', AMock.GetReturn('NoSuch'));
    CheckEqual(0, AMock.GetReturnInt('NoSuch'));
    CheckFalse(AMock.GetReturnBool('NoSuch'), 'unconfigured bool should be False');
end;

procedure TestGetReturnUnconfigured;
begin
  WithMock(@TestGetReturnUnconfiguredImpl);
end;

procedure TestResetCallsPreservesSetupImpl(AMock: TMock);
begin
    AMock.Setup('Foo').Returns('keep');
    AMock.RecordCall('Foo', []);
    AMock.RecordCall('Foo', []);
    CheckEqual(2, AMock.CallCount('Foo'));

    AMock.ResetCalls;
    CheckTrue(AMock.CallCount('Foo') = 0, 'calls should be cleared');
    CheckEqual('keep', AMock.GetReturn('Foo'));
end;

procedure TestResetCallsPreservesSetup;
begin
  WithMock(@TestResetCallsPreservesSetupImpl);
end;

procedure TestVerifyCalledExactlyFailImpl(AMock: TMock);
begin
    AMock.RecordCall('Foo', []);
  ExpectFail(procedure
  begin
      AMock.Verify('Foo').CalledExactly(3);
  end, 'exactly');
end;

procedure TestVerifyCalledExactlyFail;
begin
  WithMock(@TestVerifyCalledExactlyFailImpl);
end;

procedure TestVerifyCalledNeverFailImpl(AMock: TMock);
begin
    AMock.RecordCall('Foo', []);
  ExpectFail(procedure
  begin
      AMock.Verify('Foo').CalledNever;
  end, 'exactly');
end;

procedure TestVerifyCalledNeverFail;
begin
  WithMock(@TestVerifyCalledNeverFailImpl);
end;

procedure TestVerifyCalledOnceFailImpl(AMock: TMock);
begin
    AMock.RecordCall('Foo', []);
    AMock.RecordCall('Foo', []);
  ExpectFail(procedure
  begin
      AMock.Verify('Foo').CalledOnce;
  end, 'exactly');
end;

procedure TestVerifyCalledOnceFail;
begin
  WithMock(@TestVerifyCalledOnceFailImpl);
end;

procedure TestVerifyCalledAtLeastFailImpl(AMock: TMock);
begin
    AMock.RecordCall('Foo', []);
  ExpectFail(procedure
  begin
      AMock.Verify('Foo').CalledAtLeast(5);
  end, 'at least');
end;

procedure TestVerifyCalledAtLeastFail;
begin
  WithMock(@TestVerifyCalledAtLeastFailImpl);
end;

procedure TestVerifyCalledAtMostFailImpl(AMock: TMock);
begin
    AMock.RecordCall('Foo', []);
    AMock.RecordCall('Foo', []);
    AMock.RecordCall('Foo', []);
  ExpectFail(procedure
  begin
      AMock.Verify('Foo').CalledAtMost(1);
  end, 'at most');
end;

procedure TestVerifyCalledAtMostFail;
begin
  WithMock(@TestVerifyCalledAtMostFailImpl);
end;

procedure TestGetReturnIntNonNumericImpl(AMock: TMock);
begin
    AMock.Setup('Val').Returns('not_a_number');
    { GetReturnInt on non-numeric string should return 0 }
    CheckEqual(0, AMock.GetReturnInt('Val'));
end;

procedure TestGetReturnIntNonNumeric;
begin
  WithMock(@TestGetReturnIntNonNumericImpl);
end;

procedure TestStateCallsDirectAccessImpl(AMock: TMock);
begin
    AMock.RecordCall('A', ['x']);
    AMock.RecordCall('B', ['y', 'z']);
    CheckEqual(2, Length(AMock.State.Calls));
    CheckEqual('A', AMock.State.Calls[0].MethodName);
    CheckEqual(1, Length(AMock.State.Calls[0].Args));
    CheckEqual('x', AMock.State.Calls[0].Args[0]);
    CheckEqual('B', AMock.State.Calls[1].MethodName);
    CheckEqual(2, Length(AMock.State.Calls[1].Args));
end;

procedure TestStateCallsDirectAccess;
begin
  WithMock(@TestStateCallsDirectAccessImpl);
end;

procedure TestStateCallsTypedArgsMirrorStringsImpl(AMock: TMock);
begin
    AMock.RecordCall('Mirror', ['left', 'right']);
    CheckEqual(2, Length(AMock.State.Calls[0].TypedArgs));
    CheckTrue(AMock.State.Calls[0].TypedArgs[0].Kind = mvString,
      'first typed arg kind');
    CheckEqual('left', AMock.State.Calls[0].TypedArgs[0].StrVal);
    CheckTrue(AMock.State.Calls[0].TypedArgs[1].Kind = mvString,
      'second typed arg kind');
    CheckEqual('right', AMock.State.Calls[0].TypedArgs[1].StrVal);
end;

procedure TestStateCallsTypedArgsMirrorStrings;
begin
  WithMock(@TestStateCallsTypedArgsMirrorStringsImpl);
end;

procedure TestRecordCallTypedPreservesLegacyArgsImpl(AMock: TMock);
begin
    AMock.State.RecordCallTyped('TypedCall', [
      MockStr('alpha'),
      MockInt(42),
      MockBool(True)
    ]);
    CheckEqual(1, AMock.CallCount('TypedCall'));
    CheckEqual(3, Length(AMock.State.Calls[0].TypedArgs));
    CheckTrue(AMock.State.Calls[0].TypedArgs[0].Kind = mvString,
      'typed string arg kind');
    CheckEqual('alpha', AMock.State.Calls[0].TypedArgs[0].StrVal);
    CheckTrue(AMock.State.Calls[0].TypedArgs[1].Kind = mvInt64,
      'typed int arg kind');
    CheckEqual(Int64(42), AMock.State.Calls[0].TypedArgs[1].IntVal);
    CheckTrue(AMock.State.Calls[0].TypedArgs[2].Kind = mvBool,
      'typed bool arg kind');
    CheckTrue(AMock.State.Calls[0].TypedArgs[2].BoolVal, 'typed bool arg value');
    CheckEqual('alpha', AMock.State.Calls[0].Args[0]);
    CheckEqual('42', AMock.State.Calls[0].Args[1]);
    CheckEqual('true', AMock.State.Calls[0].Args[2]);
end;

procedure TestRecordCallTypedPreservesLegacyArgs;
begin
  WithMock(@TestRecordCallTypedPreservesLegacyArgsImpl);
end;

procedure TestRecordCallTypedOnMockImpl(AMock: TMock);
begin
    AMock.RecordCallTyped('Foo', [MockStr('a'), MockInt(42)]);
    CheckEqual(1, AMock.CallCount('Foo'));
    CheckEqual(1, Length(AMock.State.Calls));
    CheckEqual('Foo', AMock.State.Calls[0].MethodName);
    CheckEqual(2, Length(AMock.State.Calls[0].TypedArgs));
    CheckTrue(AMock.State.Calls[0].TypedArgs[0].Kind = mvString,
      'typed string arg kind');
    CheckEqual('a', AMock.State.Calls[0].TypedArgs[0].StrVal);
    CheckTrue(AMock.State.Calls[0].TypedArgs[1].Kind = mvInt64,
      'typed int arg kind');
    CheckEqual(Int64(42), AMock.State.Calls[0].TypedArgs[1].IntVal);
end;

procedure TestRecordCallTypedOnMock;
begin
  WithMock(@TestRecordCallTypedOnMockImpl);
end;

procedure TestGetReturnTypedFromStringSetupImpl(AMock: TMock);
var
  LValue: TMockValue;
begin
    AMock.Setup('Echo').Returns('typed');
    LValue := AMock.State.GetReturnTyped('Echo', [MockStr('ignored')]);
    CheckTrue(LValue.Kind = mvString, 'typed return kind');
    CheckEqual('typed', LValue.StrVal);
end;

procedure TestGetReturnTypedFromStringSetup;
begin
  WithMock(@TestGetReturnTypedFromStringSetupImpl);
end;

procedure TestStateGetReturnInt64FromTypedSetupImpl(AMock: TMock);
var
  LValue: TMockValue;
begin
    AMock.Setup('Count').ReturnsInt(42);
    LValue := AMock.State.GetReturnTyped('Count', []);
    CheckTrue(LValue.Kind = mvInt64, 'typed int return kind');
    CheckEqual(Int64(42), LValue.IntVal);
    CheckEqual(Int64(42), AMock.State.GetReturnInt64('Count', ['legacy']));
end;

procedure TestStateGetReturnInt64FromTypedSetup;
begin
  WithMock(@TestStateGetReturnInt64FromTypedSetupImpl);
end;

procedure TestStateGetReturnBoolFromTypedSetupImpl(AMock: TMock);
var
  LValue: TMockValue;
begin
    AMock.Setup('Flag').ReturnsBool(True);
    LValue := AMock.State.GetReturnTyped('Flag', []);
    CheckTrue(LValue.Kind = mvBool, 'typed bool return kind');
    CheckTrue(LValue.BoolVal, 'typed bool return value');
    CheckTrue(AMock.State.GetReturnBool('Flag', ['legacy']),
      'state typed bool getter');
end;

procedure TestStateGetReturnBoolFromTypedSetup;
begin
  WithMock(@TestStateGetReturnBoolFromTypedSetupImpl);
end;

procedure TestTypedAndLegacyStringReturnCoexistImpl(AMock: TMock);
var
  LValue: TMockValue;
begin
    AMock.State.SetReturn('LegacyInt', '42');
    AMock.State.SetReturn('LegacyFlag', 'true');

    LValue := AMock.State.GetReturnTyped('LegacyInt', [MockStr('legacy')]);
    CheckTrue(LValue.Kind = mvString, 'legacy int typed kind');
    CheckEqual('42', LValue.StrVal);
    CheckEqual('42', AMock.GetReturn('LegacyInt'));
    CheckEqual(Int64(42), AMock.State.GetReturnInt64('LegacyInt', ['legacy']));

    LValue := AMock.State.GetReturnTyped('LegacyFlag', [MockStr('legacy')]);
    CheckTrue(LValue.Kind = mvString, 'legacy bool typed kind');
    CheckEqual('true', LValue.StrVal);
    CheckTrue(AMock.State.GetReturnBool('LegacyFlag', ['legacy']),
      'legacy bool fallback');
end;

procedure TestTypedAndLegacyStringReturnCoexist;
begin
  WithMock(@TestTypedAndLegacyStringReturnCoexistImpl);
end;

procedure TestUnsetTypedReturnDefaultsImpl(AMock: TMock);
var
  LValue: TMockValue;
begin
    LValue := AMock.State.GetReturnTyped('Missing', []);
    CheckTrue(LValue.Kind = mvUnset, 'unset typed kind');
    CheckEqual('', AMock.GetReturn('Missing'));
    CheckEqual(Int64(0), AMock.State.GetReturnInt64('Missing', []));
    CheckFalse(AMock.State.GetReturnBool('Missing', []),
      'unset bool should be false');
end;

procedure TestUnsetTypedReturnDefaults;
begin
  WithMock(@TestUnsetTypedReturnDefaultsImpl);
end;

procedure TestVerifyCalledExactlyOverCallImpl(AMock: TMock);
begin
    AMock.Setup('Foo').Returns('1');
    AMock.RecordCall('Foo', []);
    AMock.RecordCall('Foo', []);
  ExpectFail(procedure
  begin
      AMock.Verify('Foo').CalledExactly(1);
  end);
end;

procedure TestVerifyCalledExactlyOverCall;
begin
  WithMock(@TestVerifyCalledExactlyOverCallImpl);
end;

procedure TestSetupDuplicateOverwriteImpl(AMock: TMock);
begin
    AMock.Setup('Foo').Returns('1');
    AMock.Setup('Foo').Returns('2');
    CheckEqual('2', AMock.GetReturn('Foo'));
end;

procedure TestSetupDuplicateOverwrite;
begin
  WithMock(@TestSetupDuplicateOverwriteImpl);
end;

procedure TestGetReturnIntNegativeImpl(AMock: TMock);
begin
    AMock.Setup('Foo').Returns('-42');
    CheckEqual(Int64(-42), AMock.GetReturnInt('Foo'));
end;

procedure TestGetReturnIntNegative;
begin
  WithMock(@TestGetReturnIntNegativeImpl);
end;

procedure TestTimesSuccessImpl(AMock: TMock);
begin
    AMock.RecordCall('Foo', []);
    AMock.RecordCall('Foo', []);
    AMock.RecordCall('Foo', []);
    { Times(3) should not raise }
    AMock.Verify('Foo').Times(3);
end;

procedure TestTimesSuccess;
begin
  WithMock(@TestTimesSuccessImpl);
end;

procedure TestTimesFailImpl(AMock: TMock);
begin
    AMock.RecordCall('Foo', []);
  ExpectFail(procedure
  begin
      AMock.Verify('Foo').Times(5);
  end);
end;

procedure TestTimesFail;
begin
  WithMock(@TestTimesFailImpl);
end;

procedure TestInOrderSetupImpl(AMock: TMock);
begin
    { InOrder is a fluent marker — should not raise }
    AMock.Setup('Foo').InOrder.Returns('bar');
    CheckEqual('bar', AMock.GetReturn('Foo'));
end;

procedure TestInOrderSetup;
begin
  WithMock(@TestInOrderSetupImpl);
end;

procedure TestCallOrderTrackingImpl(AMock: TMock);
begin
    AMock.RecordCall('A', []);
    AMock.RecordCall('B', []);
    AMock.RecordCall('C', []);
    AMock.RecordCall('A', []);
    CheckEqual(4, Length(AMock.State.CallOrder));
    CheckEqual('A', AMock.State.CallOrder[0]);
    CheckEqual('B', AMock.State.CallOrder[1]);
    CheckEqual('C', AMock.State.CallOrder[2]);
    CheckEqual('A', AMock.State.CallOrder[3]);
end;

procedure TestCallOrderTracking;
begin
  WithMock(@TestCallOrderTrackingImpl);
end;

procedure TestCalledBeforeSuccessImpl(AMock: TMock);
begin
    AMock.RecordCall('Setup', []);
    AMock.RecordCall('Execute', []);
    AMock.RecordCall('Cleanup', []);
    { Setup was called before Execute — should not raise }
    AMock.Verify('Setup').CalledBefore('Execute');
end;

procedure TestCalledBeforeSuccess;
begin
  WithMock(@TestCalledBeforeSuccessImpl);
end;

procedure TestCalledBeforeFailImpl(AMock: TMock);
begin
    AMock.RecordCall('Execute', []);
    AMock.RecordCall('Setup', []);
  ExpectFail(procedure
  begin
      AMock.Verify('Setup').CalledBefore('Execute');
  end);
end;

procedure TestCalledBeforeFail;
begin
  WithMock(@TestCalledBeforeFailImpl);
end;

procedure TestCalledAfterSuccessImpl(AMock: TMock);
begin
    AMock.RecordCall('Setup', []);
    AMock.RecordCall('Execute', []);
    AMock.RecordCall('Cleanup', []);
    { Cleanup was called after Execute — should not raise }
    AMock.Verify('Cleanup').CalledAfter('Execute');
end;

procedure TestCalledAfterSuccess;
begin
  WithMock(@TestCalledAfterSuccessImpl);
end;

procedure TestCalledAfterFailImpl(AMock: TMock);
begin
    AMock.RecordCall('Cleanup', []);
    AMock.RecordCall('Execute', []);
  ExpectFail(procedure
  begin
      AMock.Verify('Cleanup').CalledAfter('Execute');
  end);
end;

procedure TestCalledAfterFail;
begin
  WithMock(@TestCalledAfterFailImpl);
end;

procedure TestCalledBeforeNeverCalledImpl(AMock: TMock);
begin
    AMock.RecordCall('Foo', []);
  ExpectFail(procedure
  begin
      AMock.Verify('Foo').CalledBefore('Bar');
  end);
end;

procedure TestCalledBeforeNeverCalled;
begin
  WithMock(@TestCalledBeforeNeverCalledImpl);
end;

procedure TestCallOrderResetImpl(AMock: TMock);
begin
    AMock.RecordCall('A', []);
    AMock.RecordCall('B', []);
    CheckEqual(2, Length(AMock.State.CallOrder));
    AMock.ResetCalls;
    CheckEqual(0, Length(AMock.State.CallOrder));
end;

procedure TestCallOrderReset;
begin
  WithMock(@TestCallOrderResetImpl);
end;

{ ── CalledInOrder (TODO resolution) ───────────────────────────────────────── }

procedure TestCalledInOrderSuccessImpl(AMock: TMock);
begin
    AMock.RecordCall('Init', []);
    AMock.RecordCall('Execute', []);
    AMock.RecordCall('Cleanup', []);
    AMock.Verify('Init').CalledInOrder(['Init', 'Execute', 'Cleanup']);
end;

procedure TestCalledInOrderSuccess;
begin
  WithMock(@TestCalledInOrderSuccessImpl);
end;

procedure TestCalledInOrderFailWrongOrderImpl(AMock: TMock);
begin
    AMock.RecordCall('Execute', []);
    AMock.RecordCall('Init', []);
    AMock.RecordCall('Cleanup', []);
  ExpectFail(procedure
  begin
      AMock.Verify('Execute').CalledInOrder(['Init', 'Execute', 'Cleanup']);
  end);
end;

procedure TestCalledInOrderFailWrongOrder;
begin
  WithMock(@TestCalledInOrderFailWrongOrderImpl);
end;

procedure TestCalledInOrderFailMissingImpl(AMock: TMock);
begin
    AMock.RecordCall('Init', []);
    AMock.RecordCall('Cleanup', []);
  ExpectFail(procedure
  begin
      AMock.Verify('Init').CalledInOrder(['Init', 'Execute', 'Cleanup']);
  end);
end;

procedure TestCalledInOrderFailMissing;
begin
  WithMock(@TestCalledInOrderFailMissingImpl);
end;

procedure TestCalledInOrderSingleMethodImpl(AMock: TMock);
begin
    AMock.RecordCall('Foo', []);
    AMock.Verify('Foo').CalledInOrder(['Foo']);
end;

procedure TestCalledInOrderSingleMethod;
begin
  WithMock(@TestCalledInOrderSingleMethodImpl);
end;

procedure TestCalledInOrderWithInterveningCallsImpl(AMock: TMock);
begin
    { Other methods called between the ones we verify }
    AMock.RecordCall('Init', []);
    AMock.RecordCall('Log', []);
    AMock.RecordCall('Execute', []);
    AMock.RecordCall('Debug', []);
    AMock.RecordCall('Cleanup', []);
    AMock.Verify('Init').CalledInOrder(['Init', 'Execute', 'Cleanup']);
end;

procedure TestCalledInOrderWithInterveningCalls;
begin
  WithMock(@TestCalledInOrderWithInterveningCallsImpl);
end;

procedure TestCalledInOrderEmptyImpl(AMock: TMock);
begin
    { Empty order list — should pass vacuously }
    AMock.RecordCall('Foo', []);
    AMock.Verify('Foo').CalledInOrder([]);
end;

procedure TestCalledInOrderEmpty;
begin
  WithMock(@TestCalledInOrderEmptyImpl);
end;

{ ── VerifyInOrder (TMock method) ─────────────────────────────────────────── }

procedure TestVerifyInOrderSuccessImpl(AMock: TMock);
begin
    AMock.RecordCall('Init', []);
    AMock.RecordCall('Execute', []);
    AMock.RecordCall('Cleanup', []);
    AMock.VerifyInOrder(['Init', 'Execute', 'Cleanup']);
end;

procedure TestVerifyInOrderSuccess;
begin
  WithMock(@TestVerifyInOrderSuccessImpl);
end;

procedure TestVerifyInOrderFailWrongOrderImpl(AMock: TMock);
begin
    AMock.RecordCall('Execute', []);
    AMock.RecordCall('Init', []);
    AMock.RecordCall('Cleanup', []);
  ExpectFail(procedure
  begin
      AMock.VerifyInOrder(['Init', 'Execute', 'Cleanup']);
  end);
end;

procedure TestVerifyInOrderFailWrongOrder;
begin
  WithMock(@TestVerifyInOrderFailWrongOrderImpl);
end;

procedure TestVerifyInOrderFailMissingImpl(AMock: TMock);
begin
    AMock.RecordCall('Init', []);
    AMock.RecordCall('Cleanup', []);
  ExpectFail(procedure
  begin
      AMock.VerifyInOrder(['Init', 'Execute', 'Cleanup']);
  end);
end;

procedure TestVerifyInOrderFailMissing;
begin
  WithMock(@TestVerifyInOrderFailMissingImpl);
end;

procedure TestVerifyInOrderSingleMethodImpl(AMock: TMock);
begin
    AMock.RecordCall('Foo', []);
    AMock.VerifyInOrder(['Foo']);
end;

procedure TestVerifyInOrderSingleMethod;
begin
  WithMock(@TestVerifyInOrderSingleMethodImpl);
end;

procedure TestVerifyInOrderEmptyImpl(AMock: TMock);
begin
    { Empty order list — should pass vacuously }
    AMock.RecordCall('Foo', []);
    AMock.VerifyInOrder([]);
end;

procedure TestVerifyInOrderEmpty;
begin
  WithMock(@TestVerifyInOrderEmptyImpl);
end;

{ ── GetCallHistory ───────────────────────────────────────────────────────── }

procedure TestGetCallHistoryEmptyImpl(AMock: TMock);
var
  LHistory: string;
begin
    LHistory := AMock.GetCallHistory;
    CheckTrue(Pos('no calls', LHistory) > 0, 'history says no calls when empty');
end;

procedure TestGetCallHistoryEmpty;
begin
  WithMock(@TestGetCallHistoryEmptyImpl);
end;

procedure TestGetCallHistoryRecordsImpl(AMock: TMock);
var
  LHistory: string;
begin
    AMock.RecordCall('Foo', ['a']);
    AMock.RecordCall('Bar', ['b', 'c']);
    LHistory := AMock.GetCallHistory;
    CheckTrue(Pos('Foo', LHistory) > 0, 'history contains Foo');
    CheckTrue(Pos('Bar', LHistory) > 0, 'history contains Bar');
    CheckTrue(Pos('a', LHistory) > 0, 'history contains arg a');
end;

procedure TestGetCallHistoryRecords;
begin
  WithMock(@TestGetCallHistoryRecordsImpl);
end;

procedure TestCalledWithSuccessImpl(AMock: TMock);
begin
    AMock.RecordCall('Foo', ['bar', 'baz']);
    AMock.RecordCall('Foo', ['other', 'args']);
    AMock.Verify('Foo').CalledWith(['bar', 'baz']);
end;

procedure TestCalledWithSuccess;
begin
  WithMock(@TestCalledWithSuccessImpl);
end;

procedure TestCalledWithFailImpl(AMock: TMock);
begin
    AMock.RecordCall('Foo', ['bar']);
  ExpectFail(procedure
  begin
      AMock.Verify('Foo').CalledWith(['nonexistent']);
  end);
end;

procedure TestCalledWithFail;
begin
  WithMock(@TestCalledWithFailImpl);
end;

procedure TestCalledExactlyWithSuccessImpl(AMock: TMock);
begin
    AMock.RecordCall('Foo', ['a']);
    AMock.RecordCall('Foo', ['b']);
    AMock.RecordCall('Foo', ['a']);
    AMock.Verify('Foo').CalledExactlyWith(2, ['a']);
end;

procedure TestCalledExactlyWithSuccess;
begin
  WithMock(@TestCalledExactlyWithSuccessImpl);
end;

procedure TestCalledExactlyWithFailImpl(AMock: TMock);
begin
    AMock.RecordCall('Foo', ['a']);
    AMock.RecordCall('Foo', ['b']);
  ExpectFail(procedure
  begin
      AMock.Verify('Foo').CalledExactlyWith(2, ['a']);
  end);
end;

procedure TestCalledExactlyWithFail;
begin
  WithMock(@TestCalledExactlyWithFailImpl);
end;

procedure TestCalledWithEmptyArgsImpl(AMock: TMock);
var
  LEmpty: array of string;
begin
    LEmpty := nil;
    AMock.RecordCall('Foo', []);
    AMock.RecordCall('Foo', []);
    { CalledWith([]) should match both no-arg calls }
    AMock.Verify('Foo').CalledWith(LEmpty);
end;

procedure TestCalledWithEmptyArgs;
begin
  WithMock(@TestCalledWithEmptyArgsImpl);
end;

procedure TestCalledExactlyWithZeroTimesImpl(AMock: TMock);
begin
    AMock.RecordCall('Foo', ['a']);
    { 0 times with ['b'] — method was called with ['a'], not ['b'] }
    AMock.Verify('Foo').CalledExactlyWith(0, ['b']);
    { 0 times with ['a'] should FAIL since we recorded ['a'] once }
  ExpectFail(procedure
  begin
      AMock.Verify('Foo').CalledExactlyWith(0, ['a']);
      CheckTrue(False, 'CalledExactlyWith(0) should fail when args were recorded');
  end);
end;

procedure TestCalledExactlyWithZeroTimes;
begin
  WithMock(@TestCalledExactlyWithZeroTimesImpl);
end;

{ F-04: Typed CalledWith / CalledExactlyWith }

procedure TestCalledWithTypedSuccessImpl(AMock: TMock);
begin
    AMock.RecordCallTyped('Calc', [MockInt(42), MockStr('hello')]);
    AMock.Verify('Calc').CalledWith([MockInt(42), MockStr('hello')]);
end;

procedure TestCalledWithTypedSuccess;
begin
  WithMock(@TestCalledWithTypedSuccessImpl);
end;

procedure TestCalledWithTypedDistinguishesTypesImpl(AMock: TMock);
begin
    AMock.RecordCallTyped('Calc', [MockInt(42)]);
    { MockStr('42') should NOT match MockInt(42) — different kind }
    AMock.Verify('Calc').CalledWith([MockStr('42')]);
    CheckTrue(False, 'Should fail: MockStr(''42'') ≠ MockInt(42)');
end;

procedure TestCalledWithTypedDistinguishesTypes;
begin
  ExpectFailWithMock(@TestCalledWithTypedDistinguishesTypesImpl);
end;

procedure TestCalledExactlyWithTypedSuccessImpl(AMock: TMock);
begin
    AMock.RecordCallTyped('Calc', [MockInt(1)]);
    AMock.RecordCallTyped('Calc', [MockInt(1)]);
    AMock.RecordCallTyped('Calc', [MockInt(2)]);
    AMock.Verify('Calc').CalledExactlyWith(2, [MockInt(1)]);
end;

procedure TestCalledExactlyWithTypedSuccess;
begin
  WithMock(@TestCalledExactlyWithTypedSuccessImpl);
end;

procedure TestCalledExactlyWithTypedFailImpl(AMock: TMock);
begin
    AMock.RecordCallTyped('Calc', [MockInt(1)]);
    AMock.RecordCallTyped('Calc', [MockInt(2)]);
    AMock.Verify('Calc').CalledExactlyWith(3, [MockInt(1)]);
    CheckTrue(False, 'Should fail: only 1 call with MockInt(1)');
end;

procedure TestCalledExactlyWithTypedFail;
begin
  ExpectFailWithMock(@TestCalledExactlyWithTypedFailImpl);
end;

procedure TestRecordCallTypedAllTypesImpl(AMock: TMock);
var
  LCall: TMockCall;
begin
    AMock.RecordCallTyped('Op', [
      MockStr('hello'),
      MockInt(42),
      MockBool(True),
      MockDouble(3.14)
    ]);
    LCall := AMock.State.Calls[0];
    CheckTrue(Length(LCall.TypedArgs) = 4, 'typed args count');
    CheckTrue(LCall.TypedArgs[0].Kind = mvString, 'arg[0] kind');
    CheckTrue(LCall.TypedArgs[0].StrVal = 'hello', 'arg[0] str');
    CheckTrue(LCall.TypedArgs[1].Kind = mvInt64, 'arg[1] kind');
    CheckTrue(LCall.TypedArgs[1].IntVal = 42, 'arg[1] int');
    CheckTrue(LCall.TypedArgs[2].Kind = mvBool, 'arg[2] kind');
    CheckTrue(LCall.TypedArgs[2].BoolVal, 'arg[2] bool');
    CheckTrue(LCall.TypedArgs[3].Kind = mvDouble, 'arg[3] kind');
    CheckTrue(Abs(LCall.TypedArgs[3].DblVal - 3.14) < 1e-12, 'arg[3] double');
end;

procedure TestRecordCallTypedAllTypes;
begin
  WithMock(@TestRecordCallTypedAllTypesImpl);
end;

procedure TestGetReturnIntEmptyStringImpl(AMock: TMock);
begin
    AMock.Setup('Val').Returns('');
    CheckTrue(AMock.GetReturnInt('Val') = 0, 'empty string → 0');
end;

procedure TestGetReturnIntEmptyString;
begin
  WithMock(@TestGetReturnIntEmptyStringImpl);
end;

procedure TestGetReturnBoolFromStringImpl(AMock: TMock);
begin
    AMock.Setup('Flag').Returns('true');
    CheckTrue(AMock.GetReturnBool('Flag'), '"true" → True');
    AMock.Setup('Flag').Returns('True');
    CheckTrue(AMock.GetReturnBool('Flag'), '"True" → True');
    AMock.Setup('Flag').Returns('TRUE');
    CheckTrue(AMock.GetReturnBool('Flag'), '"TRUE" → True');
    AMock.Setup('Flag').Returns('false');
    CheckFalse(AMock.GetReturnBool('Flag'), '"false" → False');
    AMock.Setup('Flag').Returns('1');
    CheckFalse(AMock.GetReturnBool('Flag'), '"1" → False (not "true")');
    AMock.Setup('Flag').Returns('');
    CheckFalse(AMock.GetReturnBool('Flag'), '"" → False');
end;

procedure TestGetReturnBoolFromString;
begin
  WithMock(@TestGetReturnBoolFromStringImpl);
end;

{ ── T-02: Typed return tests via TMock public API ─────────────────────── }

procedure TestReturnsDoubleTypedImpl(AMock: TMock);
var
  LValue: TMockValue;
begin
    AMock.Setup('Pi').ReturnsDouble(3.14159);
    { GetReturn should contain the string representation }
    CheckTrue(AMock.GetReturn('Pi') <> '', 'double return string non-empty');
    { Typed retrieval via State should be mvDouble }
    LValue := AMock.State.GetReturnTyped('Pi', []);
    CheckTrue(LValue.Kind = mvDouble, 'ReturnsDouble → typed kind mvDouble');
    CheckTrue(Abs(LValue.DblVal - 3.14159) < 1e-12, 'ReturnsDouble → typed value');
    { GetReturnInt64 on a double setup should return 0 (kind mismatch) }
    CheckEqual(Int64(0), AMock.GetReturnInt('Pi'));
end;

procedure TestReturnsDoubleTyped;
begin
  WithMock(@TestReturnsDoubleTypedImpl);
end;

procedure TestReturnsIntTypedImpl(AMock: TMock);
var
  LValue: TMockValue;
begin
    AMock.Setup('Count').ReturnsInt(999);
    { TMock.GetReturnInt should read typed value }
    CheckEqual(Int64(999), AMock.GetReturnInt('Count'));
    { Typed retrieval should be mvInt64 }
    LValue := AMock.State.GetReturnTyped('Count', []);
    CheckTrue(LValue.Kind = mvInt64, 'ReturnsInt → typed kind mvInt64');
    CheckEqual(Int64(999), LValue.IntVal);
    { String fallback should work too }
    CheckEqual('999', AMock.GetReturn('Count'));
end;

procedure TestReturnsIntTyped;
begin
  WithMock(@TestReturnsIntTypedImpl);
end;

procedure TestReturnsBoolTypedImpl(AMock: TMock);
var
  LValue: TMockValue;
begin
    AMock.Setup('Enabled').ReturnsBool(True);
    CheckTrue(AMock.GetReturnBool('Enabled'));
    LValue := AMock.State.GetReturnTyped('Enabled', []);
    CheckTrue(LValue.Kind = mvBool, 'ReturnsBool → typed kind mvBool');
    CheckTrue(LValue.BoolVal, 'ReturnsBool → typed value True');

    AMock.Setup('Disabled').ReturnsBool(False);
    CheckFalse(AMock.GetReturnBool('Disabled'));
    LValue := AMock.State.GetReturnTyped('Disabled', []);
    CheckTrue(LValue.Kind = mvBool, 'ReturnsBool false → typed kind mvBool');
    CheckFalse(LValue.BoolVal, 'ReturnsBool false → typed value False');
end;

procedure TestReturnsBoolTyped;
begin
  WithMock(@TestReturnsBoolTypedImpl);
end;

procedure TestRecordCallTypedViaMockImpl(AMock: TMock);
begin
    AMock.RecordCallTyped('Calc', [MockInt(10), MockDouble(2.5), MockBool(False)]);
    CheckEqual(1, AMock.CallCount('Calc'));
    CheckTrue(AMock.State.Calls[0].TypedArgs[0].Kind = mvInt64, 'arg0 kind');
    CheckEqual(Int64(10), AMock.State.Calls[0].TypedArgs[0].IntVal);
    CheckTrue(AMock.State.Calls[0].TypedArgs[1].Kind = mvDouble, 'arg1 kind');
    CheckTrue(Abs(AMock.State.Calls[0].TypedArgs[1].DblVal - 2.5) < 1e-12, 'arg1 dbl');
    CheckTrue(AMock.State.Calls[0].TypedArgs[2].Kind = mvBool, 'arg2 kind');
    CheckFalse(AMock.State.Calls[0].TypedArgs[2].BoolVal, 'arg2 bool');
    { Legacy string args should be auto-converted }
    CheckEqual('10', AMock.State.Calls[0].Args[0]);
    CheckTrue(AMock.State.Calls[0].Args[1] <> '', 'legacy arg1 non-empty');
    CheckEqual('false', AMock.State.Calls[0].Args[2]);
end;

procedure TestRecordCallTypedViaMock;
begin
  WithMock(@TestRecordCallTypedViaMockImpl);
end;

procedure TestGetReturnIntWithArgsImpl(AMock: TMock);
begin
    AMock.Setup('Lookup').ReturnsInt(77);
    { GetReturnInt with args — typed path should still return 77 }
    CheckEqual(Int64(77), AMock.GetReturnInt('Lookup', ['key']));
    { No args path should also work }
    CheckEqual(Int64(77), AMock.GetReturnInt('Lookup'));
end;

procedure TestGetReturnIntWithArgs;
begin
  WithMock(@TestGetReturnIntWithArgsImpl);
end;

procedure TestTypedSetupOverwriteImpl(AMock: TMock);
var
  LValue: TMockValue;
begin
    AMock.Setup('Counter').ReturnsInt(1);
    AMock.Setup('Counter').ReturnsInt(2);
    CheckEqual(Int64(2), AMock.GetReturnInt('Counter'));
    LValue := AMock.State.GetReturnTyped('Counter', []);
    CheckEqual(Int64(2), LValue.IntVal);

    AMock.Setup('Flag').ReturnsBool(True);
    AMock.Setup('Flag').ReturnsBool(False);
    CheckFalse(AMock.GetReturnBool('Flag'), 'bool overwrite');
    LValue := AMock.State.GetReturnTyped('Flag', []);
    CheckFalse(LValue.BoolVal, 'typed bool overwrite');
end;

procedure TestTypedSetupOverwrite;
begin
  WithMock(@TestTypedSetupOverwriteImpl);
end;

procedure TestMixedTypeSetupOnSameMethodImpl(AMock: TMock);
var
  LValue: TMockValue;
begin
    { Setup as int, then overwrite as double — last write wins }
    AMock.Setup('Mixed').ReturnsInt(42);
    AMock.Setup('Mixed').ReturnsDouble(3.14);
    LValue := AMock.State.GetReturnTyped('Mixed', []);
    CheckTrue(LValue.Kind = mvDouble, 'overwritten kind should be mvDouble');
    CheckTrue(Abs(LValue.DblVal - 3.14) < 1e-12, 'overwritten double value');
    { GetReturnInt should return 0 (kind mismatch after overwrite) }
    CheckEqual(Int64(0), AMock.GetReturnInt('Mixed'));
end;

procedure TestMixedTypeSetupOnSameMethod;
begin
  WithMock(@TestMixedTypeSetupOnSameMethodImpl);
end;

{ ── F-07: Mock.ResetAll ───────────────────────────────────────────────────── }

procedure TestMockResetAllClearsSetups;
var
  LM: TMock;
begin
  LM := TMock.Create;
  try
    LM.Setup('Foo').Returns('bar');
    LM.RecordCall('Foo', []);
    CheckEqual('bar', LM.GetReturn('Foo'));
    CheckEqual(1, LM.CallCount('Foo'));
    LM.ResetAll;
    { After ResetAll: calls cleared }
    CheckEqual(0, LM.CallCount('Foo'));
    { After ResetAll: setups also cleared — GetReturn returns '' }
    CheckEqual('', LM.GetReturn('Foo'));
  finally
    LM.Free;
  end;
end;

procedure TestMockResetCallsKeepsSetups;
var
  LM: TMock;
begin
  LM := TMock.Create;
  try
    LM.Setup('Foo').Returns('bar');
    LM.RecordCall('Foo', []);
    LM.ResetCalls;
    { After ResetCalls: calls cleared but setups preserved }
    CheckEqual(0, LM.CallCount('Foo'));
    CheckEqual('bar', LM.GetReturn('Foo'));
  finally
    LM.Free;
  end;
end;

{ F-05: VerifyAll }

procedure TestVerifyAllPass;
var
  LM: TMock;
begin
  LM := TMock.Create;
  try
    LM.Setup('Foo').Returns('bar');
    LM.Setup('Baz').Returns('qux');
    LM.RecordCall('Foo', []);
    LM.RecordCall('Baz', []);
    LM.VerifyAll; { should not fail }
  finally
    LM.Free;
  end;
end;

procedure TestVerifyAllFailUncalled;
var
  LM: TMock;
begin
  LM := TMock.Create;
  try
    LM.Setup('Foo').Returns('bar');
    LM.Setup('Baz').Returns('qux');
    LM.RecordCall('Foo', []);
    { Baz was set up but never called — should fail }
    ExpectFail(procedure begin LM.VerifyAll; end, 'Baz');
  finally
    LM.Free;
  end;
end;

procedure TestVerifyAllNoSetups;
var
  LM: TMock;
begin
  LM := TMock.Create;
  try
    { No setups at all — VerifyAll should pass vacuously }
    LM.VerifyAll;
  finally
    LM.Free;
  end;
end;

procedure TestVerifyAllWhenOnly;
var
  LM: TMock;
begin
  LM := TMock.Create;
  try
    { P0 #3: When-only config should be visible to VerifyAll }
    LM.Setup('Foo').When([MockInt(1)]).ReturnsInt(10);
    LM.RecordCall('Foo', ['1']);
    LM.VerifyAll; { should pass — Foo was called }
  finally
    LM.Free;
  end;
end;

procedure TestVerifyAllWhenOnlyFail;
var
  LM: TMock;
begin
  LM := TMock.Create;
  try
    { P0 #3: When-only config should be visible to VerifyAll }
    LM.Setup('Foo').When([MockInt(1)]).ReturnsInt(10);
    { Don't call Foo — VerifyAll should fail }
    ExpectFail(procedure begin LM.VerifyAll; end, 'Foo');
  finally
    LM.Free;
  end;
end;

procedure TestVerifyErrorMessage;
var
  LM: TMock;
begin
  LM := TMock.Create;
  try
    LM.Setup('Foo').Returns('bar');
    LM.Setup('Baz').Returns('qux');
    LM.RecordCall('Foo', []);
    LM.RecordCall('Baz', []);
    { Verify wrong count — error message should include call details }
    ExpectFail(procedure begin LM.Verify('Foo').CalledExactly(5); end, 'calls to Foo');
  finally
    LM.Free;
  end;
end;

{ ── E-09: Mock When API ────────────────────────────────────────────────────── }

procedure TestWhenBasicImpl(AMock: TMock);
begin
    AMock.Setup('Add').When([MockInt(1)]).ReturnsInt(10);
    AMock.Setup('Add').When([MockInt(2)]).ReturnsInt(20);
    CheckEqual(Int64(10), AMock.GetReturnInt('Add', [MockInt(1)]));
    CheckEqual(Int64(20), AMock.GetReturnInt('Add', [MockInt(2)]));
end;

procedure TestWhenBasic;
begin
  WithMock(@TestWhenBasicImpl);
end;

procedure TestWhenFallbackImpl(AMock: TMock);
begin
    AMock.Setup('Foo').Returns('default');
    AMock.Setup('Foo').When([MockStr('special')]).Returns('override');
    CheckEqual('override', AMock.State.GetReturnTyped('Foo', [MockStr('special')]).StrVal);
    CheckEqual('default', AMock.GetReturn('Foo'));
end;

procedure TestWhenFallback;
begin
  WithMock(@TestWhenFallbackImpl);
end;

procedure TestWhenMultipleArgsImpl(AMock: TMock);
begin
    AMock.Setup('Calc').When([MockInt(1), MockInt(2)]).ReturnsInt(3);
    AMock.Setup('Calc').When([MockInt(10), MockInt(20)]).ReturnsInt(30);
    CheckEqual(Int64(3), AMock.GetReturnInt('Calc', [MockInt(1), MockInt(2)]));
    CheckEqual(Int64(30), AMock.GetReturnInt('Calc', [MockInt(10), MockInt(20)]));
end;

procedure TestWhenMultipleArgs;
begin
  WithMock(@TestWhenMultipleArgsImpl);
end;

procedure TestWhenTypeMismatchImpl(AMock: TMock);
begin
    AMock.Setup('Val').When([MockInt(42)]).ReturnsInt(100);
    { MockStr('42') should NOT match MockInt(42) }
    CheckEqual(Int64(0), AMock.GetReturnInt('Val', [MockStr('42')]));
end;

procedure TestWhenTypeMismatch;
begin
  WithMock(@TestWhenTypeMismatchImpl);
end;

procedure TestWhenBoolReturnImpl(AMock: TMock);
begin
    AMock.Setup('Flag').When([MockStr('yes')]).ReturnsBool(True);
    AMock.Setup('Flag').When([MockStr('no')]).ReturnsBool(False);
    CheckTrue(AMock.GetReturnBool('Flag', [MockStr('yes')]), 'yes → True');
    CheckFalse(AMock.GetReturnBool('Flag', [MockStr('no')]), 'no → False');
end;

procedure TestWhenBoolReturn;
begin
  WithMock(@TestWhenBoolReturnImpl);
end;

procedure TestWhenDoubleReturnImpl(AMock: TMock);
var
  LValue: TMockValue;
begin
    AMock.Setup('Pi').When([MockInt(1)]).ReturnsDouble(3.14);
    LValue := AMock.State.GetReturnTyped('Pi', [MockInt(1)]);
    CheckTrue(LValue.Kind = mvDouble, 'When double kind');
    CheckTrue(Abs(LValue.DblVal - 3.14) < 1e-12, 'When double value');
end;

procedure TestWhenDoubleReturn;
begin
  WithMock(@TestWhenDoubleReturnImpl);
end;

procedure TestWhenResetAllClearsImpl(AMock: TMock);
begin
    AMock.Setup('Foo').When([MockInt(1)]).ReturnsInt(10);
    AMock.ResetAll;
    CheckEqual(Int64(0), AMock.GetReturnInt('Foo', [MockInt(1)]));
end;

procedure TestWhenResetAllClears;
begin
  WithMock(@TestWhenResetAllClearsImpl);
end;

{ ── R48: Mock type safety - all types coverage ───────────────────────────── }

procedure TestCalledWithBoolTypeImpl(AMock: TMock);
begin
  AMock.RecordCallTyped('Check', [MockBool(True)]);
  AMock.Verify('Check').CalledWith([MockBool(True)]);
end;

procedure TestCalledWithBoolType;
begin
  WithMock(@TestCalledWithBoolTypeImpl);
end;

procedure TestCalledWithBoolTypeMismatchImpl(AMock: TMock);
begin
  AMock.RecordCallTyped('Check', [MockBool(True)]);
  { MockStr('true') should NOT match MockBool(True) }
  AMock.Verify('Check').CalledWith([MockStr('true')]);
  CheckTrue(False, 'Should fail: MockStr(''true'') ≠ MockBool(True)');
end;

procedure TestCalledWithBoolTypeMismatch;
begin
  ExpectFailWithMock(@TestCalledWithBoolTypeMismatchImpl);
end;

procedure TestCalledWithDoubleTypeImpl(AMock: TMock);
begin
  AMock.RecordCallTyped('Calc', [MockDouble(3.14)]);
  AMock.Verify('Calc').CalledWith([MockDouble(3.14)]);
end;

procedure TestCalledWithDoubleType;
begin
  WithMock(@TestCalledWithDoubleTypeImpl);
end;

procedure TestCalledWithDoubleTypeMismatchImpl(AMock: TMock);
begin
  AMock.RecordCallTyped('Calc', [MockDouble(3.14)]);
  { MockStr('3.14') should NOT match MockDouble(3.14) }
  AMock.Verify('Calc').CalledWith([MockStr('3.14')]);
  CheckTrue(False, 'Should fail: MockStr(''3.14'') ≠ MockDouble(3.14)');
end;

procedure TestCalledWithDoubleTypeMismatch;
begin
  ExpectFailWithMock(@TestCalledWithDoubleTypeMismatchImpl);
end;

procedure TestCalledExactlyWithMultipleTypedArgsImpl(AMock: TMock);
begin
  AMock.RecordCallTyped('Op', [MockInt(1), MockStr('a')]);
  AMock.RecordCallTyped('Op', [MockInt(1), MockStr('a')]);
  AMock.RecordCallTyped('Op', [MockInt(2), MockStr('b')]);
  AMock.Verify('Op').CalledExactlyWith(2, [MockInt(1), MockStr('a')]);
end;

procedure TestCalledExactlyWithMultipleTypedArgs;
begin
  WithMock(@TestCalledExactlyWithMultipleTypedArgsImpl);
end;

{ ── R51: VerifyNoMoreInteractions ───────────────────────────────────────────── }

procedure TestVerifyNoMoreInteractionsPass;
var
  LM: TMock;
begin
  LM := TMock.Create;
  try
    LM.Setup('Foo').Returns('bar');
    LM.Setup('Baz').Returns('qux');
    LM.RecordCall('Foo', []);
    LM.RecordCall('Baz', []);
    { All set-up methods called, no unexpected calls }
    LM.VerifyNoMoreInteractions;
  finally
    LM.Free;
  end;
end;

procedure TestVerifyNoMoreInteractionsFailUncalled;
var
  LM: TMock;
begin
  LM := TMock.Create;
  try
    LM.Setup('Foo').Returns('bar');
    LM.Setup('Baz').Returns('qux');
    LM.RecordCall('Foo', []);
    { Baz was never called }
    ExpectFail(procedure begin
      LM.VerifyNoMoreInteractions;
    end, 'never called');
  finally
    LM.Free;
  end;
end;

procedure TestVerifyNoMoreInteractionsFailUnexpected;
var
  LM: TMock;
begin
  LM := TMock.Create;
  try
    LM.Setup('Foo').Returns('bar');
    LM.RecordCall('Foo', []);
    LM.RecordCall('Bar', []);  { Bar was never set up }
    ExpectFail(procedure begin
      LM.VerifyNoMoreInteractions;
    end, 'unexpected');
  finally
    LM.Free;
  end;
end;

procedure TestVerifyNoMoreInteractionsFailBoth;
var
  LM: TMock;
begin
  LM := TMock.Create;
  try
    LM.Setup('Foo').Returns('bar');
    LM.Setup('Baz').Returns('qux');
    LM.RecordCall('Foo', []);
    LM.RecordCall('Qux', []);  { Baz uncalled, Qux unexpected }
    ExpectFail(procedure begin
      LM.VerifyNoMoreInteractions;
    end, 'never called');
  finally
    LM.Free;
  end;
end;

{ ── B5 fail-path / edge contracts ─────────────────────────────────────────── }

procedure TestB5VerifyNeverAfterCall;
var
  LM: TMock;
begin
  LM := TMock.Create;
  try
    LM.RecordCall('X', []);
    ExpectFail(procedure begin
      LM.Verify('X').CalledNever;
    end, '0 time');
  finally
    LM.Free;
  end;
end;

procedure TestB5CalledOnceFailMsg;
var
  LM: TMock;
begin
  LM := TMock.Create;
  try
    LM.RecordCall('X', []);
    LM.RecordCall('X', []);
    ExpectFail(procedure begin
      LM.Verify('X').CalledOnce;
    end, 'exactly 1');
  finally
    LM.Free;
  end;
end;

procedure TestB5SetupNeverCalled;
var
  LM: TMock;
begin
  LM := TMock.Create;
  try
    LM.Setup('NeedMe').Returns('v');
    ExpectFail(procedure begin
      LM.VerifyAll;
    end, 'NeedMe');
  finally
    LM.Free;
  end;
end;

procedure TestB5ResetCallsKeepsSetup;
var
  LM: TMock;
begin
  LM := TMock.Create;
  try
    LM.Setup('Foo').Returns('bar');
    LM.RecordCall('Foo', []);
    LM.ResetCalls;
    CheckEqual('bar', LM.GetReturn('Foo'));
  finally
    LM.Free;
  end;
end;

procedure TestB5CalledWithWrongArg;
var
  LM: TMock;
  LArgs: array[0..0] of string;
begin
  LM := TMock.Create;
  try
    LArgs[0] := 'a';
    LM.RecordCall('M', LArgs);
    LArgs[0] := 'b';
    ExpectFail(procedure begin
      LM.Verify('M').CalledWith(LArgs);
    end, 'b');
  finally
    LM.Free;
  end;
end;

procedure TestB5DoubleSetupOverwrite;
var
  LM: TMock;
begin
  LM := TMock.Create;
  try
    LM.Setup('Foo').Returns('one');
    LM.Setup('Foo').Returns('two');
    CheckEqual('two', LM.GetReturn('Foo'));
  finally
    LM.Free;
  end;
end;

procedure TestB5VerifyInOrderEmpty;
var
  LM: TMock;
begin
  LM := TMock.Create;
  try
    LM.VerifyInOrder([]);
  finally
    LM.Free;
  end;
end;

procedure TestB5GetCallHistoryEmpty;
var
  LM: TMock;
begin
  LM := TMock.Create;
  try
    CheckContains(LM.GetCallHistory, 'no calls');
  finally
    LM.Free;
  end;
end;

procedure TestB5ReturnsDefaultEmpty;
var
  LM: TMock;
begin
  LM := TMock.Create;
  try
    CheckEqual('', LM.GetReturn('NoSetup'));
  finally
    LM.Free;
  end;
end;

procedure TestB5CalledTimesZero;
var
  LM: TMock;
begin
  LM := TMock.Create;
  try
    LM.Verify('Never').CalledExactly(0);
  finally
    LM.Free;
  end;
end;

{ ── B8 v8.10: cross-thread isolation (not thread-safe by contract) ────────── }

type
  TMockCrossOp = (mcoRecordCall, mcoGetReturn, mcoVerify);
  PMockThreadCtx = ^TMockThreadCtx;
  TMockThreadCtx = record
    Mock: TMock;
    Op: TMockCrossOp;
    Caught: Boolean;
    Msg: string;
  end;

function MockCrossThreadWorker(P: Pointer): PtrInt;
var
  C: PMockThreadCtx;
  LArgs: array of string;
begin
  C := PMockThreadCtx(P);
  C^.Caught := False;
  C^.Msg := '';
  SetLength(LArgs, 0);
  try
    case C^.Op of
      mcoRecordCall:
        C^.Mock.RecordCall('Cross', LArgs);
      mcoGetReturn:
        C^.Mock.GetReturn('bind');
      mcoVerify:
        C^.Mock.Verify('bind').CalledExactly(1);
    end;
  except
    on E: EAssertionFailed do
    begin
      C^.Caught := True;
      C^.Msg := E.Message;
    end;
  end;
  Result := 0;
end;

procedure RunMockCrossThread(AOp: TMockCrossOp; const ALabel: string);
var
  LM: TMock;
  Ctx: TMockThreadCtx;
  TID: TThreadID;
  LArgs: array of string;
begin
  LM := TMock.Create;
  try
    SetLength(LArgs, 0);
    LM.Setup('bind').Returns('v');
    LM.RecordCall('bind', LArgs); { bind owner thread }
    Ctx.Mock := LM;
    Ctx.Op := AOp;
    Ctx.Caught := False;
    Ctx.Msg := '';
    TID := BeginThread(@MockCrossThreadWorker, @Ctx);
    CheckTrue(TID <> TThreadID(0), 'BeginThread ok');
    WaitForThreadTerminate(TID, 10000);
    CheckTrue(Ctx.Caught, ALabel + ' must raise on other thread');
    CheckContains(LowerCase(Ctx.Msg), 'not thread-safe');
  finally
    LM.Free;
  end;
end;

procedure TestMockCrossThreadNotSafe;
begin
  RunMockCrossThread(mcoRecordCall, 'RecordCall');
end;

procedure TestMockCrossThreadGetReturn;
begin
  RunMockCrossThread(mcoGetReturn, 'GetReturn');
end;

procedure TestMockCrossThreadVerify;
begin
  RunMockCrossThread(mcoVerify, 'Verify');
end;

procedure TestMockSameThreadOk;
var
  LM: TMock;
  LArgs: array of string;
begin
  LM := TMock.Create;
  try
    SetLength(LArgs, 0);
    LM.RecordCall('A', LArgs);
    LM.RecordCall('A', LArgs);
    LM.Verify('A').CalledExactly(2);
  finally
    LM.Free;
  end;
end;

{ ── TMockCaptor tests ─────────────────────────────────────────────────────── }

procedure TestCaptorCaptureFrom;
var
  LM: TMock;
  LC: TMockCaptor;
begin
  LM := TMock.Create;
  LC := TMockCaptor.Create;
  try
    LM.RecordCall('Foo', ['hello', 'world']);
    LC.CaptureFrom(LM, 'Foo', 0);
    CheckEqual('hello', LC.Value);
    CheckEqual(1, LC.Count);
    LC.CaptureFrom(LM, 'Foo', 1);
    CheckEqual('world', LC.Value);
  finally
    LC.Free;
    LM.Free;
  end;
end;

procedure TestCaptorCaptureAllFrom;
var
  LM: TMock;
  LC: TMockCaptor;
begin
  LM := TMock.Create;
  LC := TMockCaptor.Create;
  try
    LM.RecordCall('Foo', ['a']);
    LM.RecordCall('Bar', ['x']);
    LM.RecordCall('Foo', ['b']);
    LC.CaptureAllFrom(LM, 'Foo', 0);
    CheckEqual(2, LC.Count);
    CheckEqual('a', LC.Values[0]);
    CheckEqual('b', LC.Values[1]);
  finally
    LC.Free;
    LM.Free;
  end;
end;

procedure TestCaptorCaptureTyped;
var
  LM: TMock;
  LC: TMockCaptor;
begin
  LM := TMock.Create;
  LC := TMockCaptor.Create;
  try
    LM.RecordCallTyped('Foo', [MockInt(42), MockStr('test')]);
    LC.CaptureTypedFrom(LM, 'Foo', 0);
    CheckTrue(LC.TypedValue.Kind = mvInt64, 'kind');
    CheckEqual(42, LC.TypedValue.IntVal);
    LC.CaptureTypedFrom(LM, 'Foo', 1);
    CheckTrue(LC.TypedValue.Kind = mvString, 'kind');
    CheckEqual('test', LC.TypedValue.StrVal);
  finally
    LC.Free;
    LM.Free;
  end;
end;

procedure TestCaptorReset;
var
  LM: TMock;
  LC: TMockCaptor;
begin
  LM := TMock.Create;
  LC := TMockCaptor.Create;
  try
    LM.RecordCall('Foo', ['hello']);
    LC.CaptureFrom(LM, 'Foo', 0);
    CheckEqual(1, LC.Count);
    LC.Reset;
    CheckEqual(0, LC.Count);
  finally
    LC.Free;
    LM.Free;
  end;
end;

procedure TestCaptorNoCallsFail;
var
  LM: TMock;
  LC: TMockCaptor;
begin
  LM := TMock.Create;
  LC := TMockCaptor.Create;
  try
    ExpectFail(procedure begin
      LC.CaptureFrom(LM, 'Foo', 0);
    end, 'no calls');
  finally
    LC.Free;
    LM.Free;
  end;
end;

procedure TestCaptorIndexOutOfRange;
var
  LM: TMock;
  LC: TMockCaptor;
begin
  LM := TMock.Create;
  LC := TMockCaptor.Create;
  try
    LM.RecordCall('Foo', ['a']);
    ExpectFail(procedure begin
      LC.CaptureFrom(LM, 'Foo', 5);
    end, 'out of range');
  finally
    LC.Free;
    LM.Free;
  end;
end;

{ ── B14: mock fail-path table ──────────────────────────────────────────────── }

procedure TestB14MockCalledTimesFailPath(const AC: TTestCase);
{ Data: expected call count (int). Mock never called → CalledExactly must fail. }
var
  LM: TMock;
  LExpect: Integer;
  LArgs: specialize TArray<string>;
begin
  LExpect := StrToInt(AC.Data);
  LM := TMock.Create;
  try
    SetLength(LArgs, 0);
    ExpectFail(procedure
      begin
        LM.Verify('Never').CalledExactly(LExpect);
      end, 'time');
  finally
    LM.Free;
  end;
end;

{ ── Register Tests ───────────────────────────────────────────────────────────── }

var
  Suite: TTestSuite;
  Runner: TSuiteRunner;
  LResults: specialize TArray<TTestRunResult>;
  LSuccess: Boolean;
  LB14Cases: specialize TArray<TTestCase>;
  LB14I: Integer;
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
  Suite.Test('TestReturnsDouble', @TestReturnsDouble);
  Suite.Test('TestGetTypedReturnOverloadsWithArgs',
    @TestGetTypedReturnOverloadsWithArgs);
  Suite.Test('TestGetReturnUnconfigured', @TestGetReturnUnconfigured);
  Suite.Test('TestResetCallsPreservesSetup', @TestResetCallsPreservesSetup);
  Suite.Test('TestStateCallsDirectAccess', @TestStateCallsDirectAccess);
  Suite.Test('TestStateCallsTypedArgsMirrorStrings',
    @TestStateCallsTypedArgsMirrorStrings);
  Suite.Test('TestRecordCallTypedPreservesLegacyArgs',
    @TestRecordCallTypedPreservesLegacyArgs);
  Suite.Test('TestRecordCallTypedOnMock', @TestRecordCallTypedOnMock);
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

  { Phase 3: Times / InOrder / CalledBefore / CalledAfter }
  Suite.Test('TestTimesSuccess', @TestTimesSuccess);
  Suite.Test('TestTimesFail', @TestTimesFail);
  Suite.Test('TestInOrderSetup', @TestInOrderSetup);
  Suite.Test('TestCallOrderTracking', @TestCallOrderTracking);
  Suite.Test('TestCalledBeforeSuccess', @TestCalledBeforeSuccess);
  Suite.Test('TestCalledBeforeFail', @TestCalledBeforeFail);
  Suite.Test('TestCalledAfterSuccess', @TestCalledAfterSuccess);
  Suite.Test('TestCalledAfterFail', @TestCalledAfterFail);
  Suite.Test('TestCalledBeforeNeverCalled', @TestCalledBeforeNeverCalled);
  Suite.Test('TestCallOrderReset', @TestCallOrderReset);

  { CalledInOrder — full ordered verification }
  Suite.Test('TestCalledInOrderSuccess', @TestCalledInOrderSuccess);
  Suite.Test('TestCalledInOrderFailWrongOrder', @TestCalledInOrderFailWrongOrder);
  Suite.Test('TestCalledInOrderFailMissing', @TestCalledInOrderFailMissing);
  Suite.Test('TestCalledInOrderSingleMethod', @TestCalledInOrderSingleMethod);
  Suite.Test('TestCalledInOrderWithInterveningCalls', @TestCalledInOrderWithInterveningCalls);
  Suite.Test('TestCalledInOrderEmpty', @TestCalledInOrderEmpty);

  { VerifyInOrder — TMock method }
  Suite.Test('TestVerifyInOrderSuccess', @TestVerifyInOrderSuccess);
  Suite.Test('TestVerifyInOrderFailWrongOrder', @TestVerifyInOrderFailWrongOrder);
  Suite.Test('TestVerifyInOrderFailMissing', @TestVerifyInOrderFailMissing);
  Suite.Test('TestVerifyInOrderSingleMethod', @TestVerifyInOrderSingleMethod);
  Suite.Test('TestVerifyInOrderEmpty', @TestVerifyInOrderEmpty);

  { GetCallHistory }
  Suite.Test('TestGetCallHistoryEmpty', @TestGetCallHistoryEmpty);
  Suite.Test('TestGetCallHistoryRecords', @TestGetCallHistoryRecords);

  { v3.1: CalledWith / CalledExactlyWith }
  Suite.Test('TestCalledWithSuccess', @TestCalledWithSuccess);
  Suite.Test('TestCalledWithFail', @TestCalledWithFail);
  Suite.Test('TestCalledExactlyWithSuccess', @TestCalledExactlyWithSuccess);
  Suite.Test('TestCalledExactlyWithFail', @TestCalledExactlyWithFail);

  { G1: Coverage gaps }
  Suite.Test('TestCalledWithEmptyArgs', @TestCalledWithEmptyArgs);
  Suite.Test('TestCalledExactlyWithZeroTimes', @TestCalledExactlyWithZeroTimes);

  { F-04: Typed CalledWith / CalledExactlyWith }
  Suite.Test('TestCalledWithTypedSuccess', @TestCalledWithTypedSuccess);
  Suite.Test('TestCalledWithTypedDistinguishesTypes', @TestCalledWithTypedDistinguishesTypes);
  Suite.Test('TestCalledExactlyWithTypedSuccess', @TestCalledExactlyWithTypedSuccess);
  Suite.Test('TestCalledExactlyWithTypedFail', @TestCalledExactlyWithTypedFail);

  { R48: Mock type safety - all types coverage }
  Suite.Test('TestCalledWithBoolType', @TestCalledWithBoolType);
  Suite.Test('TestCalledWithBoolTypeMismatch', @TestCalledWithBoolTypeMismatch);
  Suite.Test('TestCalledWithDoubleType', @TestCalledWithDoubleType);
  Suite.Test('TestCalledWithDoubleTypeMismatch', @TestCalledWithDoubleTypeMismatch);
  Suite.Test('TestCalledExactlyWithMultipleTypedArgs', @TestCalledExactlyWithMultipleTypedArgs);

  { R51: VerifyNoMoreInteractions }
  Suite.Test('TestVerifyNoMoreInteractionsPass', @TestVerifyNoMoreInteractionsPass);
  Suite.Test('TestVerifyNoMoreInteractionsFailUncalled', @TestVerifyNoMoreInteractionsFailUncalled);
  Suite.Test('TestVerifyNoMoreInteractionsFailUnexpected', @TestVerifyNoMoreInteractionsFailUnexpected);
  Suite.Test('TestVerifyNoMoreInteractionsFailBoth', @TestVerifyNoMoreInteractionsFailBoth);

  { G2: Mock type paths }
  Suite.Test('TestRecordCallTypedAllTypes', @TestRecordCallTypedAllTypes);
  Suite.Test('TestGetReturnIntEmptyString', @TestGetReturnIntEmptyString);
  Suite.Test('TestGetReturnBoolFromString', @TestGetReturnBoolFromString);

  { T-02: Typed return tests via TMock public API }
  Suite.Test('TestReturnsDoubleTyped', @TestReturnsDoubleTyped);
  Suite.Test('TestReturnsIntTyped', @TestReturnsIntTyped);
  Suite.Test('TestReturnsBoolTyped', @TestReturnsBoolTyped);
  Suite.Test('TestRecordCallTypedViaMock', @TestRecordCallTypedViaMock);
  Suite.Test('TestGetReturnIntWithArgs', @TestGetReturnIntWithArgs);
  Suite.Test('TestTypedSetupOverwrite', @TestTypedSetupOverwrite);
  Suite.Test('TestMixedTypeSetupOnSameMethod', @TestMixedTypeSetupOnSameMethod);

  { F-07: Mock.ResetAll }
  Suite.Test('TestMockResetAllClearsSetups', @TestMockResetAllClearsSetups);
  Suite.Test('TestMockResetCallsKeepsSetups', @TestMockResetCallsKeepsSetups);

  { F-05: VerifyAll + error messages }
  Suite.Test('TestVerifyAllPass', @TestVerifyAllPass);
  Suite.Test('TestVerifyAllFailUncalled', @TestVerifyAllFailUncalled);
  Suite.Test('TestVerifyAllNoSetups', @TestVerifyAllNoSetups);
  Suite.Test('TestVerifyAllWhenOnly', @TestVerifyAllWhenOnly);
  Suite.Test('TestVerifyAllWhenOnlyFail', @TestVerifyAllWhenOnlyFail);
  Suite.Test('TestVerifyErrorMessage', @TestVerifyErrorMessage);

  { E-09: Mock When API }
  Suite.Test('TestWhenBasic', @TestWhenBasic);
  Suite.Test('TestWhenFallback', @TestWhenFallback);
  Suite.Test('TestWhenMultipleArgs', @TestWhenMultipleArgs);
  Suite.Test('TestWhenTypeMismatch', @TestWhenTypeMismatch);
  Suite.Test('TestWhenBoolReturn', @TestWhenBoolReturn);
  Suite.Test('TestWhenDoubleReturn', @TestWhenDoubleReturn);
  Suite.Test('TestWhenResetAllClears', @TestWhenResetAllClears);

  { TMockCaptor }
  Suite.Test('TestCaptorCaptureFrom', @TestCaptorCaptureFrom);
  Suite.Test('TestCaptorCaptureAllFrom', @TestCaptorCaptureAllFrom);
  Suite.Test('TestCaptorCaptureTyped', @TestCaptorCaptureTyped);
  Suite.Test('TestCaptorReset', @TestCaptorReset);
  Suite.Test('TestCaptorNoCallsFail', @TestCaptorNoCallsFail);
  Suite.Test('TestCaptorIndexOutOfRange', @TestCaptorIndexOutOfRange);

  { B5: additional fail-path / edge contracts }
  Suite.Test('B5 VerifyNever after call fails', @TestB5VerifyNeverAfterCall);
  Suite.Test('B5 CalledOnce fail message', @TestB5CalledOnceFailMsg);
  Suite.Test('B5 Setup then never called VerifyAll', @TestB5SetupNeverCalled);
  Suite.Test('B5 ResetCalls keeps setup', @TestB5ResetCallsKeepsSetup);
  Suite.Test('B5 CalledWith wrong arg fail', @TestB5CalledWithWrongArg);
  Suite.Test('B5 Double setup overwrite', @TestB5DoubleSetupOverwrite);
  Suite.Test('B5 VerifyInOrder empty pass', @TestB5VerifyInOrderEmpty);
  Suite.Test('B5 GetCallHistory empty', @TestB5GetCallHistoryEmpty);
  Suite.Test('B5 Returns default empty', @TestB5ReturnsDefaultEmpty);
  Suite.Test('B5 CalledTimes zero', @TestB5CalledTimesZero);

  { B8/B9 mock isolation (not thread-safe by contract) }
  Suite.Test('B8 cross-thread RecordCall', @TestMockCrossThreadNotSafe);
  Suite.Test('B9 cross-thread GetReturn', @TestMockCrossThreadGetReturn);
  Suite.Test('B9 cross-thread Verify', @TestMockCrossThreadVerify);
  Suite.Test('B8 same-thread ok', @TestMockSameThreadOk);

  { B14: meaningful fail-path table — CalledTimes mismatch messages }
  SetLength(LB14Cases, 300);
  for LB14I := 0 to High(LB14Cases) do
  begin
    LB14Cases[LB14I].Name := 'mock-fail-' + IntToStr(LB14I);
    { expected count = 1, actual will be 0 → fail path }
    LB14Cases[LB14I].Data := '1';
  end;
  Suite.TestTable('B14 mock CalledTimes fail-path', LB14Cases,
    @TestB14MockCalledTimesFailPath);

  Runner := TSuiteRunner.Create('mock-tests');
  Runner.Add(Suite);
  LSuccess := Runner.RunAllWithResult(LResults);
  WriteLn;
  Runner.Summary;

  if LSuccess then
    PassTest('ALL PASSED')
  else
    FailTest('SOME FAILED');

  { Release closures before heaptrc reports }
  Runner := Default(TSuiteRunner);
  Suite := Default(TTestSuite);
  LResults := nil;
end.
