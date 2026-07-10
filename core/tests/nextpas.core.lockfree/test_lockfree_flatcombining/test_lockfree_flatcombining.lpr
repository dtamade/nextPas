program test_lockfree_flatcombining;

{$mode objfpc}{$H+}

uses
  nextpas.core.thread.init,
  SysUtils,
  nextpas.core.lockfree.flatcombining,
  nextpas.core.lockfree,
  nextpas.core.atomic,
  nextpas.core.test;

procedure TestFCCounterBasic;
var
  LCounter: TFlatCombiningCounter;
begin
  LCounter := TFlatCombiningCounter.Create(0);
  try
    CheckEqual(Int64(1), LCounter.Increment);
    CheckEqual(Int64(2), LCounter.Increment);
    CheckEqual(Int64(3), LCounter.Increment);

    CheckEqual(Int64(2), LCounter.Decrement);
    CheckEqual(Int64(1), LCounter.Decrement);

    CheckEqual(Int64(11), LCounter.Add(10));
    CheckEqual(Int64(6), LCounter.Sub(5));
  finally
    LCounter.Free;
  end;
end;

procedure TestFCCounterInitialValue;
var
  LCounter: TFlatCombiningCounter;
begin
  LCounter := TFlatCombiningCounter.Create(100);
  try
    CheckEqual(Int64(100), LCounter.GetValue);
    CheckEqual(Int64(101), LCounter.Increment);
    CheckEqual(Int64(100), LCounter.Decrement);
  finally
    LCounter.Free;
  end;
end;

procedure TestFCCounterClose;
var
  LCounter: TFlatCombiningCounter;
begin
  LCounter := TFlatCombiningCounter.Create(0);
  try
    LCounter.Increment;
    LCounter.Close;
    Check(LCounter.IsClosed, 'Should be closed');

    CheckEqual(Int64(1), LCounter.GetValue);
  finally
    LCounter.Free;
  end;
end;

procedure TestFCCounterMultipleOps;
var
  LCounter: TFlatCombiningCounter;
  LI: Integer;
begin
  LCounter := TFlatCombiningCounter.Create(0);
  try
    for LI := 1 to 100 do
      LCounter.Increment;

    CheckEqual(Int64(100), LCounter.GetValue);

    for LI := 1 to 50 do
      LCounter.Decrement;

    CheckEqual(Int64(50), LCounter.GetValue);
  finally
    LCounter.Free;
  end;
end;

procedure TestFCCounterAddSub;
var
  LCounter: TFlatCombiningCounter;
begin
  LCounter := TFlatCombiningCounter.Create(0);
  try
    CheckEqual(Int64(100), LCounter.Add(100));
    CheckEqual(Int64(150), LCounter.Add(50));
    CheckEqual(Int64(100), LCounter.Sub(50));
    CheckEqual(Int64(0), LCounter.Sub(100));
  finally
    LCounter.Free;
  end;
end;

{ --- Concurrent tests --- }

type
  TCounterThreadArgs = record
    Counter: TFlatCombiningCounter;
    OpsPerThread: Integer;
  end;

function CounterThread(AData: Pointer): PtrInt;
var
  LArgs: TCounterThreadArgs;
  LI: Integer;
begin
  LArgs := TCounterThreadArgs(AData^);
  for LI := 1 to LArgs.OpsPerThread do
    LArgs.Counter.Increment;
  Result := 0;
end;

procedure TestFCCounterConcurrent;
var
  LCounter: TFlatCombiningCounter;
  LArgs: array[0..3] of TCounterThreadArgs;
  LThreads: array[0..3] of TThreadID;
  LI: Integer;
  LOpsPerThread: Integer;
begin
  LOpsPerThread := 1000;
  LCounter := TFlatCombiningCounter.Create(0);
  try
    for LI := 0 to 3 do
    begin
      LArgs[LI].Counter := LCounter;
      LArgs[LI].OpsPerThread := LOpsPerThread;
      LThreads[LI] := BeginThread(@CounterThread, @LArgs[LI]);
    end;

    for LI := 0 to 3 do
      WaitForThreadTerminate(LThreads[LI], 10000);

    CheckEqual(Int64(4 * LOpsPerThread), LCounter.GetValue);
  finally
    LCounter.Free;
  end;
end;

{ Verify that multiple instances don't interfere }
procedure TestFCCounterMultipleInstances;
var
  LCounter1, LCounter2: TFlatCombiningCounter;
  LI: Integer;
begin
  LCounter1 := TFlatCombiningCounter.Create(0);
  LCounter2 := TFlatCombiningCounter.Create(0);
  try
    for LI := 1 to 100 do
    begin
      LCounter1.Increment;
      LCounter2.Add(10);
    end;

    CheckEqual(Int64(100), LCounter1.GetValue, 'Counter1 should be 100');
    CheckEqual(Int64(1000), LCounter2.GetValue, 'Counter2 should be 1000');
  finally
    LCounter1.Free;
    LCounter2.Free;
  end;
end;

begin
  WriteLn('=== test_lockfree_flatcombining ===');
  WriteLn;

  TestFCCounterBasic;
  WriteLn('  + Basic operations');

  TestFCCounterInitialValue;
  WriteLn('  + Initial value');

  TestFCCounterClose;
  WriteLn('  + Close semantics');

  TestFCCounterMultipleOps;
  WriteLn('  + Multiple operations');

  TestFCCounterAddSub;
  WriteLn('  + Add/Sub');

  TestFCCounterConcurrent;
  WriteLn('  + Concurrent 4 threads');

  TestFCCounterMultipleInstances;
  WriteLn('  + Multiple instances isolation');

  WriteLn;
  WriteLn('All flat combining tests passed!');
end.
