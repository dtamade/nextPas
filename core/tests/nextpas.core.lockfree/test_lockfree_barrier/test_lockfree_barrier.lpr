program test_lockfree_barrier;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.lockfree.barrier,
  nextpas.core.lockfree,
  nextpas.core.test;

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

  WriteLn;
  WriteLn('All barrier tests passed!');
end.
