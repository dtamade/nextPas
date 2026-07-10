program test_lockfree_barrier;

{$mode objfpc}{$H+}

uses
  nextpas.core.thread.init,
  SysUtils,
  nextpas.core.lockfree.barrier,
  nextpas.core.atomic,
  nextpas.core.lockfree,
  nextpas.core.test;

type
  PBarrierArgs = ^TBarrierArgs;
  TBarrierArgs = record
    Barrier: TCyclicBarrier;
    Result: TCyclicBarrierWaitResult;
    Done: PInt32;
  end;

function BarrierThread(AData: Pointer): PtrInt;
var
  LArgs: PBarrierArgs;
begin
  LArgs := PBarrierArgs(AData);
  LArgs^.Result := LArgs^.Barrier.AwaitTimeout(50000000);
  AtomicStore32(LArgs^.Done^, 1, moRelease);
  Result := 0;
end;

procedure TestBarrierBasic;
var
  LBarrier: TCyclicBarrier;
  LResult: TCyclicBarrierWaitResult;
begin
  LBarrier := TCyclicBarrier.Create(1);
  try
    CheckEqual(Int64(1), LBarrier.GetParties);
    Check(not LBarrier.IsClosed, 'Should not be closed');

    // Single party - should arrive immediately
    LResult := LBarrier.Await;
    Check(bwArrived = LResult, 'Should arrive');
  finally
    LBarrier.Free;
  end;
end;

procedure TestBarrierTwoParties;
var
  LBarrier: TCyclicBarrier;
begin
  LBarrier := TCyclicBarrier.Create(2);
  try
    CheckEqual(Int64(2), LBarrier.GetParties);
    CheckEqual(Int64(0), LBarrier.GetNumberWaiting);
  finally
    LBarrier.Free;
  end;
end;

procedure TestBarrierTimeout;
var
  LBarrier: TCyclicBarrier;
  LResult: TCyclicBarrierWaitResult;
begin
  LBarrier := TCyclicBarrier.Create(2);
  try
    // Timeout since only 1 party waiting
    LResult := LBarrier.AwaitTimeout(1000000); // 1ms
    Check(bwTimeout = LResult, 'Should timeout');
  finally
    LBarrier.Free;
  end;
end;

procedure TestBarrierReset;
var
  LBarrier: TCyclicBarrier;
begin
  LBarrier := TCyclicBarrier.Create(3);
  try
    LBarrier.Reset;
    CheckEqual(Int64(3), LBarrier.GetParties);
    Check(not LBarrier.IsClosed, 'Should not be closed');
  finally
    LBarrier.Free;
  end;
end;

procedure TestBarrierClose;
var
  LBarrier: TCyclicBarrier;
  LResult: TCyclicBarrierWaitResult;
begin
  LBarrier := TCyclicBarrier.Create(2);
  try
    LBarrier.Close;
    Check(LBarrier.IsClosed, 'Should be closed');

    LResult := LBarrier.Await;
    Check(bwClosed = LResult, 'Should return closed');
  finally
    LBarrier.Free;
  end;
end;

procedure TestBarrierRecoversAfterTimeout;
var
  LBarrier: TCyclicBarrier;
  LArgs: TBarrierArgs;
  LThread: TThreadID;
  LDone: Int32;
  LMainResult: TCyclicBarrierWaitResult;
  LSpin: Integer;
begin
  LBarrier := TCyclicBarrier.Create(2);
  LDone := 0;
  try
    Check(bwTimeout = LBarrier.AwaitTimeout(1000000), 'Initial single waiter should time out');
    CheckEqual(Int64(0), LBarrier.GetNumberWaiting, 'Timed out waiter must not stay registered');

    LArgs.Barrier := LBarrier;
    LArgs.Result := bwBroken;
    LArgs.Done := @LDone;
    LThread := BeginThread(@BarrierThread, @LArgs);

    LMainResult := LBarrier.AwaitTimeout(50000000);
    Check(bwArrived = LMainResult, 'Barrier should still be reusable after timeout');

    LSpin := 0;
    while (AtomicLoad32(LDone, moAcquire) = 0) and (LSpin < 1000000) do
    begin
      CpuPause;
      Inc(LSpin);
    end;
    Check(bwArrived = LArgs.Result, 'Peer waiter should also arrive after timeout recovery');
    WaitForThreadTerminate(LThread, 5000);
  finally
    LBarrier.Free;
  end;
end;

begin
  WriteLn('=== test_lockfree_barrier ===');
  WriteLn;

  TestBarrierBasic;
  WriteLn('  + Basic single party');

  TestBarrierTwoParties;
  WriteLn('  + Two parties');

  TestBarrierTimeout;
  WriteLn('  + Timeout');

  TestBarrierReset;
  WriteLn('  + Reset');

  TestBarrierClose;
  WriteLn('  + Close semantics');

  TestBarrierRecoversAfterTimeout;
  WriteLn('  + Timeout recovery');

  WriteLn;
  WriteLn('All barrier tests passed!');
end.
