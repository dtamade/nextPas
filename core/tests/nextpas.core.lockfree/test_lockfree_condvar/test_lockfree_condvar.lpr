program test_lockfree_condvar;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.lockfree.condvar,
  nextpas.core.lockfree,
  nextpas.core.test;

procedure TestCondVarBasic;
var
  LCondVar: TConditionVariable;
begin
  LCondVar := TConditionVariable.Create;
  try
    Check(not LCondVar.IsClosed, 'Should not be closed');
    CheckEqual(Int32(0), LCondVar.GetWaiterCount);
  finally
    LCondVar.Free;
  end;
end;

procedure TestCondVarSignal;
var
  LCondVar: TConditionVariable;
begin
  LCondVar := TConditionVariable.Create;
  try
    // Signal with no waiters - should be safe
    LCondVar.Signal;
    LCondVar.Signal;
    LCondVar.Signal;
    Check(not LCondVar.IsClosed, 'Should not be closed');
  finally
    LCondVar.Free;
  end;
end;

procedure TestCondVarBroadcast;
var
  LCondVar: TConditionVariable;
begin
  LCondVar := TConditionVariable.Create;
  try
    // Broadcast with no waiters - should be safe
    LCondVar.Broadcast;
    Check(not LCondVar.IsClosed, 'Should not be closed');
  finally
    LCondVar.Free;
  end;
end;

procedure TestCondVarClose;
var
  LCondVar: TConditionVariable;
begin
  LCondVar := TConditionVariable.Create;
  try
    LCondVar.Close;
    Check(LCondVar.IsClosed, 'Should be closed');
  finally
    LCondVar.Free;
  end;
end;

procedure TestCondVarWaitTimeout;
var
  LCondVar: TConditionVariable;
  LResult: TConditionVariableWaitResult;
begin
  LCondVar := TConditionVariable.Create;
  try
    // Timeout with no signal
    LResult := LCondVar.WaitTimeout(1000000); // 1ms
    Check(cvTimeout = LResult, 'Should timeout');
  finally
    LCondVar.Free;
  end;
end;

begin
  WriteLn('=== test_lockfree_condvar ===');
  WriteLn;

  TestCondVarBasic;
  WriteLn('  + Basic state');

  TestCondVarSignal;
  WriteLn('  + Signal (no waiters)');

  TestCondVarBroadcast;
  WriteLn('  + Broadcast (no waiters)');

  TestCondVarClose;
  WriteLn('  + Close semantics');

  TestCondVarWaitTimeout;
  WriteLn('  + Wait timeout');

  WriteLn;
  WriteLn('All condition variable tests passed!');
end.
