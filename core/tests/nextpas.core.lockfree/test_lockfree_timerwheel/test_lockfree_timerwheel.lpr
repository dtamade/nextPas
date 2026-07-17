program test_lockfree_timerwheel;

{$mode objfpc}{$H+}

uses
  nextpas.core.lockfree.timerwheel,
  nextpas.core.lockfree,
  nextpas.core.test;

var
  GCallbackCount: Int64;

procedure TestCallback(AData: Pointer);
begin
  Inc(GCallbackCount);
end;

procedure TestTimerWheelBasic;
var
  LWheel: TTimerWheel;
begin
  LWheel := TTimerWheel.Create(16, 1000000); // 16 slots, 1ms tick
  try
    Check(not LWheel.IsClosed, 'Should not be closed');
    CheckEqual(Int64(0), LWheel.GetCurrentSlot, 'Initial slot should be 0');
    CheckEqual(Int64(0), LWheel.GetTotalTicks, 'Initial ticks should be 0');
    CheckEqual(Int64(1000000), LWheel.GetTickIntervalNs, 'Tick interval should be 1ms');
  finally
    LWheel.Free;
  end;
end;

procedure TestTimerWheelSchedule;
var
  LWheel: TTimerWheel;
  LId: Int64;
begin
  LWheel := TTimerWheel.Create(16, 1000000);
  try
    LId := LWheel.Schedule(@TestCallback, nil, 5);
    Check(LId >= 0, 'Timer ID should be non-negative');
  finally
    LWheel.Free;
  end;
end;

procedure TestTimerWheelTick;
var
  LWheel: TTimerWheel;
begin
  LWheel := TTimerWheel.Create(16, 1000000);
  try
    LWheel.Tick;
    CheckEqual(Int64(1), LWheel.GetTotalTicks, 'Ticks should be 1');
    CheckEqual(Int64(1), LWheel.GetCurrentSlot, 'Current slot should be 1');

    LWheel.Tick;
    CheckEqual(Int64(2), LWheel.GetTotalTicks, 'Ticks should be 2');
    CheckEqual(Int64(2), LWheel.GetCurrentSlot, 'Current slot should be 2');
  finally
    LWheel.Free;
  end;
end;

procedure TestTimerWheelTickN;
var
  LWheel: TTimerWheel;
begin
  LWheel := TTimerWheel.Create(16, 1000000);
  try
    LWheel.TickN(5);
    CheckEqual(Int64(5), LWheel.GetTotalTicks, 'Ticks should be 5');
    CheckEqual(Int64(5), LWheel.GetCurrentSlot, 'Current slot should be 5');
  finally
    LWheel.Free;
  end;
end;

procedure TestTimerWheelExpired;
var
  LWheel: TTimerWheel;
  LExpired: Int64;
begin
  GCallbackCount := 0;
  LWheel := TTimerWheel.Create(8, 1000000);
  try
    // Schedule timer for 3 ticks
    LWheel.Schedule(@TestCallback, nil, 3);

    // Tick 1 - not expired
    LWheel.Tick;
    LExpired := LWheel.ProcessExpired;
    CheckEqual(Int64(0), LExpired, 'Should not expire yet');

    // Tick 2 - not expired
    LWheel.Tick;
    LExpired := LWheel.ProcessExpired;
    CheckEqual(Int64(0), LExpired, 'Should not expire yet');

    // Tick 3 - expired
    LWheel.Tick;
    LExpired := LWheel.ProcessExpired;
    CheckEqual(Int64(1), LExpired, 'Should expire 1 timer');
    CheckEqual(Int64(1), GCallbackCount, 'Callback should be called once');
  finally
    LWheel.Free;
  end;
end;

procedure TestTimerWheelCancel;
var
  LWheel: TTimerWheel;
  LId: Int64;
  LResult: TLockFreeTimerResult;
begin
  GCallbackCount := 0;
  LWheel := TTimerWheel.Create(8, 1000000);
  try
    LId := LWheel.Schedule(@TestCallback, nil, 3);

    // Cancel
    LResult := LWheel.Cancel(LId);
    Check(twCancelled = LResult, 'Should cancel');

    // Cancel again
    LResult := LWheel.Cancel(LId);
    Check(twNotFound = LResult, 'Should not find');

    // Tick until would have expired
    LWheel.TickN(3);
    LWheel.ProcessExpired;
    CheckEqual(Int64(0), GCallbackCount, 'Callback should not be called');
  finally
    LWheel.Free;
  end;
end;

procedure TestTimerWheelWrapAround;
var
  LWheel: TTimerWheel;
begin
  LWheel := TTimerWheel.Create(4, 1000000);
  try
    // Tick past the wheel size
    LWheel.TickN(10);
    CheckEqual(Int64(10), LWheel.GetTotalTicks, 'Ticks should be 10');
    CheckEqual(Int64(2), LWheel.GetCurrentSlot, 'Slot should wrap: 10 mod 4 = 2');
  finally
    LWheel.Free;
  end;
end;

procedure TestTimerWheelExactFullRotation;
var
  LWheel: TTimerWheel;
  LExpired: Int64;
begin
  GCallbackCount := 0;
  LWheel := TTimerWheel.Create(4, 1000000);
  try
    LWheel.Schedule(@TestCallback, nil, 4);
    LWheel.TickN(4);
    LExpired := LWheel.ProcessExpired;
    CheckEqual(Int64(1), LExpired, 'Should expire after exactly one full rotation');
    CheckEqual(Int64(1), GCallbackCount, 'Callback should fire on exact rotation');
  finally
    LWheel.Free;
  end;
end;

procedure TestTimerWheelClose;
var
  LWheel: TTimerWheel;
begin
  LWheel := TTimerWheel.Create(8, 1000000);
  try
    LWheel.Close;
    Check(LWheel.IsClosed, 'Should be closed');

    CheckEqual(Int64(-1), LWheel.Schedule(@TestCallback, nil, 1), 'Should return -1');
  finally
    LWheel.Free;
  end;
end;

begin
  WriteLn('=== test_lockfree_timerwheel ===');
  WriteLn;

  TestTimerWheelBasic;
  WriteLn('  + Basic state');

  TestTimerWheelSchedule;
  WriteLn('  + Schedule');

  TestTimerWheelTick;
  WriteLn('  + Tick');

  TestTimerWheelTickN;
  WriteLn('  + TickN');

  TestTimerWheelExpired;
  WriteLn('  + Expired');

  TestTimerWheelCancel;
  WriteLn('  + Cancel');

  TestTimerWheelWrapAround;
  WriteLn('  + Wrap-around');

  TestTimerWheelExactFullRotation;
  WriteLn('  + Exact full rotation');

  TestTimerWheelClose;
  WriteLn('  + Close semantics');

  WriteLn;
  WriteLn('All timer wheel tests passed!');
end.
