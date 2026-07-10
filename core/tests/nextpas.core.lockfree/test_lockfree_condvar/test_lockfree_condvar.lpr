program test_lockfree_condvar;

{$mode objfpc}{$H+}

uses
  nextpas.core.thread.init,
  SysUtils,
  nextpas.core.lockfree.condvar,
  nextpas.core.lockfree.mutex,
  nextpas.core.lockfree,
  nextpas.core.atomic,
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
  LMutex: TConcurrentMutex;
  LResult: TConditionVariableWaitResult;
begin
  LCondVar := TConditionVariable.Create;
  LMutex := TConcurrentMutex.Create;
  try
    LMutex.Lock;
    LResult := LCondVar.WaitTimeout(LMutex, 1000000); // 1ms
    Check(cvTimeout = LResult, 'Should timeout');
    Check(LMutex.IsLocked, 'Mutex should be re-acquired after timeout');
  finally
    LMutex.Free;
    LCondVar.Free;
  end;
end;

{ --- Concurrent tests --- }

type
  TWaiterArgs = record
    CondVar: TConditionVariable;
    Mutex: TConcurrentMutex;
    Signaled: PBoolean;
    Done: PInt32;
  end;

function WaiterThread(AData: Pointer): PtrInt;
var
  LArgs: TWaiterArgs;
begin
  LArgs := TWaiterArgs(AData^);
  LArgs.Mutex.Lock;
  LArgs.CondVar.Wait(LArgs.Mutex);
  AtomicStore32(LArgs.Done^, 1, moRelease);
  LArgs.Signaled^ := True;
  LArgs.Mutex.Unlock;
  Result := 0;
end;

procedure TestCondVarSignalWakesOne;
var
  LCondVar: TConditionVariable;
  LMutex: TConcurrentMutex;
  LDone1, LDone2: Int32;
  LSignaled1, LSignaled2: Boolean;
  LArgs1, LArgs2: TWaiterArgs;
  LT1, LT2: TThreadID;
  LSpin: Integer;
begin
  LCondVar := TConditionVariable.Create;
  LMutex := TConcurrentMutex.Create;
  LDone1 := 0;
  LDone2 := 0;
  LSignaled1 := False;
  LSignaled2 := False;
  try
    LArgs1.CondVar := LCondVar;
    LArgs1.Mutex := LMutex;
    LArgs1.Signaled := @LSignaled1;
    LArgs1.Done := @LDone1;
    LArgs2.CondVar := LCondVar;
    LArgs2.Mutex := LMutex;
    LArgs2.Signaled := @LSignaled2;
    LArgs2.Done := @LDone2;

    LT1 := BeginThread(@WaiterThread, @LArgs1);
    LT2 := BeginThread(@WaiterThread, @LArgs2);

    { Wait for both threads to be waiting }
    LSpin := 0;
    while (LCondVar.GetWaiterCount < 2) and (LSpin < 1000000) do
    begin
      CpuPause;
      Inc(LSpin);
    end;

    { Signal should wake exactly one }
    LCondVar.Signal;

    { Wait for one thread to complete }
    LSpin := 0;
    while (AtomicLoad32(LDone1, moAcquire) = 0) and
          (AtomicLoad32(LDone2, moAcquire) = 0) and
          (LSpin < 1000000) do
    begin
      CpuPause;
      Inc(LSpin);
    end;

    { One should be signaled, one should still be waiting }
    Check(LSignaled1 or LSignaled2, 'At least one should be signaled');
    Check((AtomicLoad32(LDone1, moAcquire) + AtomicLoad32(LDone2, moAcquire)) = 1,
      'Exactly one waiter should complete after a single Signal');
    CheckEqual(Int32(1), LCondVar.GetWaiterCount, 'One waiter should remain after a single Signal');

    { Signal the second one }
    LCondVar.Signal;
    LSpin := 0;
    while ((AtomicLoad32(LDone1, moAcquire) = 0) or
           (AtomicLoad32(LDone2, moAcquire) = 0)) and
          (LSpin < 1000000) do
    begin
      CpuPause;
      Inc(LSpin);
    end;

    Check(LSignaled1 and LSignaled2, 'Both should be signaled after two Signals');

    WaitForThreadTerminate(LT1, 5000);
    WaitForThreadTerminate(LT2, 5000);
  finally
    LMutex.Free;
    LCondVar.Free;
  end;
end;

procedure TestCondVarBroadcastWakesAll;
var
  LCondVar: TConditionVariable;
  LMutex: TConcurrentMutex;
  LDone1, LDone2: Int32;
  LSignaled1, LSignaled2: Boolean;
  LArgs1, LArgs2: TWaiterArgs;
  LT1, LT2: TThreadID;
  LSpin: Integer;
begin
  LCondVar := TConditionVariable.Create;
  LMutex := TConcurrentMutex.Create;
  LDone1 := 0;
  LDone2 := 0;
  LSignaled1 := False;
  LSignaled2 := False;
  try
    LArgs1.CondVar := LCondVar;
    LArgs1.Mutex := LMutex;
    LArgs1.Signaled := @LSignaled1;
    LArgs1.Done := @LDone1;
    LArgs2.CondVar := LCondVar;
    LArgs2.Mutex := LMutex;
    LArgs2.Signaled := @LSignaled2;
    LArgs2.Done := @LDone2;

    LT1 := BeginThread(@WaiterThread, @LArgs1);
    LT2 := BeginThread(@WaiterThread, @LArgs2);

    { Wait for both threads to be waiting }
    LSpin := 0;
    while (LCondVar.GetWaiterCount < 2) and (LSpin < 1000000) do
    begin
      CpuPause;
      Inc(LSpin);
    end;

    { Broadcast should wake all }
    LCondVar.Broadcast;

    { Wait for both to complete }
    LSpin := 0;
    while ((AtomicLoad32(LDone1, moAcquire) = 0) or
           (AtomicLoad32(LDone2, moAcquire) = 0)) and
          (LSpin < 1000000) do
    begin
      CpuPause;
      Inc(LSpin);
    end;

    Check(LSignaled1 and LSignaled2, 'Both should be signaled by Broadcast');

    WaitForThreadTerminate(LT1, 5000);
    WaitForThreadTerminate(LT2, 5000);
  finally
    LMutex.Free;
    LCondVar.Free;
  end;
end;

procedure TestCondVarMutexReleasedDuringWait;
var
  LCondVar: TConditionVariable;
  LMutex: TConcurrentMutex;
  LGotLock: Boolean;
  LDone: Int32;
  LSignaled: Boolean;
  LArgs: TWaiterArgs;
  LT: TThreadID;
  LSpin: Integer;
begin
  LCondVar := TConditionVariable.Create;
  LMutex := TConcurrentMutex.Create;
  LDone := 0;
  LSignaled := False;
  try
    LArgs.CondVar := LCondVar;
    LArgs.Mutex := LMutex;
    LArgs.Signaled := @LSignaled;
    LArgs.Done := @LDone;

    { Thread acquires mutex and waits }
    LT := BeginThread(@WaiterThread, @LArgs);

    { Wait for thread to be waiting }
    LSpin := 0;
    while (LCondVar.GetWaiterCount < 1) and (LSpin < 1000000) do
    begin
      CpuPause;
      Inc(LSpin);
    end;

    { If Wait properly releases the mutex, we should be able to acquire it }
    LGotLock := LMutex.TryLock;
    Check(LGotLock, 'Mutex should be released during Wait');
    if LGotLock then
      LMutex.Unlock;

    { Signal and clean up }
    LCondVar.Signal;
    WaitForThreadTerminate(LT, 5000);

    Check(LSignaled, 'Thread should be signaled');
  finally
    LMutex.Free;
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

  TestCondVarSignalWakesOne;
  WriteLn('  + Signal wakes exactly one waiter');

  TestCondVarBroadcastWakesAll;
  WriteLn('  + Broadcast wakes all waiters');

  TestCondVarMutexReleasedDuringWait;
  WriteLn('  + Mutex released during Wait');

  WriteLn;
  WriteLn('All condition variable tests passed!');
end.
