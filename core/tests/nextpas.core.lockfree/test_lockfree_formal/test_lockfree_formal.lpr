program test_lockfree_formal;

{$mode objfpc}{$H+}

uses
  nextpas.core.text.conv,
  nextpas.core.atomic,
  nextpas.core.lockfree.spsc,
  nextpas.core.lockfree.mpmc,
  nextpas.core.lockfree.channel;

const
  TEST_CAPACITY = 4;
  TEST_ITERATIONS = 100;

var
  GTestCount: Integer = 0;
  GPassCount: Integer = 0;
  GFailCount: Integer = 0;

procedure Check(ACondition: Boolean; const ATestName: string);
begin
  Inc(GTestCount);
  if ACondition then
  begin
    Inc(GPassCount);
    WriteLn('  + ', ATestName);
  end
  else
  begin
    Inc(GFailCount);
    WriteLn('  - ', ATestName, ' FAILED');
  end;
end;

{==============================================================================
  SPSC Queue Tests (from TLA+ model)
==============================================================================}

procedure TestSpscQueueTypeOK;
var
  LQueue: specialize TSpscQueueImpl<UInt64>;
begin
  WriteLn('TestSpscQueueTypeOK:');
  LQueue := specialize TSpscQueueImpl<UInt64>.Create(TEST_CAPACITY);
  try
    // TypeOK: queue capacity is positive
    Check(LQueue.Capacity > 0, 'Capacity > 0');

    // TypeOK: initial count is 0
    Check(LQueue.ApproxCount = 0, 'Initial count = 0');

    // TypeOK: initial state is empty
    Check(LQueue.IsEmpty, 'Initial state is empty');
  finally
    LQueue.Free;
  end;
end;

procedure TestSpscQueueFifoOrder;
var
  LQueue: specialize TSpscQueueImpl<UInt64>;
  I: Integer;
  LValue: UInt64;
begin
  WriteLn('TestSpscQueueFifoOrder:');
  LQueue := specialize TSpscQueueImpl<UInt64>.Create(TEST_CAPACITY);
  try
    // Enqueue items in order
    for I := 1 to TEST_CAPACITY do
      Check(LQueue.TryEnqueue(UInt64(I)), 'Enqueue ' + IntToStr(I));

    // Dequeue items should be in FIFO order
    for I := 1 to TEST_CAPACITY do
    begin
      Check(LQueue.TryDequeue(LValue), 'Dequeue ' + IntToStr(I));
      Check(LValue = UInt64(I), 'FIFO order: expected ' + IntToStr(I) + ', got ' + IntToStr(LValue));
    end;
  finally
    LQueue.Free;
  end;
end;

procedure TestSpscQueueBounds;
var
  LQueue: specialize TSpscQueueImpl<UInt64>;
  I: Integer;
begin
  WriteLn('TestSpscQueueBounds:');
  LQueue := specialize TSpscQueueImpl<UInt64>.Create(TEST_CAPACITY);
  try
    // Fill queue to capacity
    for I := 1 to TEST_CAPACITY do
      Check(LQueue.TryEnqueue(UInt64(I)), 'Enqueue ' + IntToStr(I));

    // Queue should be full
    Check(not LQueue.TryEnqueue(999), 'Reject enqueue when full');

    // Count should be at capacity
    Check(LQueue.ApproxCount = TEST_CAPACITY, 'Count = capacity');
  finally
    LQueue.Free;
  end;
end;

procedure TestSpscQueueEmpty;
var
  LQueue: specialize TSpscQueueImpl<UInt64>;
  LValue: UInt64;
begin
  WriteLn('TestSpscQueueEmpty:');
  LQueue := specialize TSpscQueueImpl<UInt64>.Create(TEST_CAPACITY);
  try
    // Empty queue should reject dequeue
    Check(not LQueue.TryDequeue(LValue), 'Reject dequeue when empty');

    // Count should be 0
    Check(LQueue.ApproxCount = 0, 'Count = 0');
  finally
    LQueue.Free;
  end;
end;

{==============================================================================
  MPMC Queue Tests (from TLA+ model)
==============================================================================}

procedure TestMpmcQueueTypeOK;
var
  LQueue: specialize TMpmcQueueImpl<UInt64>;
begin
  WriteLn('TestMpmcQueueTypeOK:');
  LQueue := specialize TMpmcQueueImpl<UInt64>.Create(TEST_CAPACITY);
  try
    // TypeOK: queue capacity is positive
    Check(LQueue.Capacity > 0, 'Capacity > 0');

    // TypeOK: initial count is 0
    Check(LQueue.ApproxCount = 0, 'Initial count = 0');

    // TypeOK: initial state is empty
    Check(LQueue.IsEmpty, 'Initial state is empty');
  finally
    LQueue.Free;
  end;
end;

procedure TestMpmcQueueFifoOrder;
var
  LQueue: specialize TMpmcQueueImpl<UInt64>;
  I: Integer;
  LValue: UInt64;
begin
  WriteLn('TestMpmcQueueFifoOrder:');
  LQueue := specialize TMpmcQueueImpl<UInt64>.Create(TEST_CAPACITY);
  try
    // Enqueue items in order
    for I := 1 to TEST_CAPACITY do
      Check(LQueue.TryEnqueue(UInt64(I)), 'Enqueue ' + IntToStr(I));

    // Dequeue items should be in FIFO order
    for I := 1 to TEST_CAPACITY do
    begin
      Check(LQueue.TryDequeue(LValue), 'Dequeue ' + IntToStr(I));
      Check(LValue = UInt64(I), 'FIFO order: expected ' + IntToStr(I) + ', got ' + IntToStr(LValue));
    end;
  finally
    LQueue.Free;
  end;
end;

procedure TestMpmcQueueBounds;
var
  LQueue: specialize TMpmcQueueImpl<UInt64>;
  I: Integer;
begin
  WriteLn('TestMpmcQueueBounds:');
  LQueue := specialize TMpmcQueueImpl<UInt64>.Create(TEST_CAPACITY);
  try
    // Fill queue to capacity
    for I := 1 to TEST_CAPACITY do
      Check(LQueue.TryEnqueue(UInt64(I)), 'Enqueue ' + IntToStr(I));

    // Queue should be full
    Check(not LQueue.TryEnqueue(999), 'Reject enqueue when full');

    // Count should be at capacity
    Check(LQueue.ApproxCount = TEST_CAPACITY, 'Count = capacity');
  finally
    LQueue.Free;
  end;
end;

procedure TestMpmcQueueEmpty;
var
  LQueue: specialize TMpmcQueueImpl<UInt64>;
  LValue: UInt64;
begin
  WriteLn('TestMpmcQueueEmpty:');
  LQueue := specialize TMpmcQueueImpl<UInt64>.Create(TEST_CAPACITY);
  try
    // Empty queue should reject dequeue
    Check(not LQueue.TryDequeue(LValue), 'Reject dequeue when empty');

    // Count should be 0
    Check(LQueue.ApproxCount = 0, 'Count = 0');
  finally
    LQueue.Free;
  end;
end;

{==============================================================================
  Channel Tests (from TLA+ model)
==============================================================================}

procedure TestChannelTypeOK;
var
  LChannel: specialize TLockFreeChannelImpl<UInt64>;
begin
  WriteLn('TestChannelTypeOK:');
  LChannel := specialize TLockFreeChannelImpl<UInt64>.Create(TEST_CAPACITY);
  try
    // TypeOK: channel capacity is positive
    Check(LChannel.Capacity > 0, 'Capacity > 0');

    // TypeOK: initial state is empty
    Check(LChannel.IsEmpty, 'Initial state is empty');

    // TypeOK: channel is not closed
    Check(not LChannel.IsClosed, 'Initial state is not closed');
  finally
    LChannel.Free;
  end;
end;

procedure TestChannelBufferBounds;
var
  LChannel: specialize TLockFreeChannelImpl<UInt64>;
  I: Integer;
begin
  WriteLn('TestChannelBufferBounds:');
  LChannel := specialize TLockFreeChannelImpl<UInt64>.Create(TEST_CAPACITY);
  try
    // Fill channel to capacity
    for I := 1 to TEST_CAPACITY do
      Check(LChannel.TrySend(UInt64(I)), 'Send ' + IntToStr(I));

    // Channel should be full
    Check(not LChannel.TrySend(999), 'Reject send when full');
  finally
    LChannel.Free;
  end;
end;

procedure TestChannelEmpty;
var
  LChannel: specialize TLockFreeChannelImpl<UInt64>;
  LValue: UInt64;
begin
  WriteLn('TestChannelEmpty:');
  LChannel := specialize TLockFreeChannelImpl<UInt64>.Create(TEST_CAPACITY);
  try
    // Empty channel should reject receive
    Check(not LChannel.TryReceive(LValue), 'Reject receive when empty');
  finally
    LChannel.Free;
  end;
end;

procedure TestChannelCloseSemantics;
var
  LChannel: specialize TLockFreeChannelImpl<UInt64>;
  LValue: UInt64;
begin
  WriteLn('TestChannelCloseSemantics:');
  LChannel := specialize TLockFreeChannelImpl<UInt64>.Create(TEST_CAPACITY);
  try
    // Send some data
    Check(LChannel.TrySend(100), 'Send before close');
    Check(LChannel.TrySend(200), 'Send before close');

    // Close channel
    LChannel.Close;
    Check(LChannel.IsClosed, 'Channel is closed');

    // Cannot send after close
    Check(not LChannel.TrySend(300), 'Reject send after close');

    // Can receive remaining data
    Check(LChannel.TryReceive(LValue), 'Receive after close');
    Check(LValue = 100, 'Receive value 100');

    Check(LChannel.TryReceive(LValue), 'Receive after close');
    Check(LValue = 200, 'Receive value 200');

    // Cannot receive from closed empty channel
    Check(not LChannel.TryReceive(LValue), 'Reject receive from closed empty channel');
  finally
    LChannel.Free;
  end;
end;

procedure TestChannelFifoOrder;
var
  LChannel: specialize TLockFreeChannelImpl<UInt64>;
  I: Integer;
  LValue: UInt64;
begin
  WriteLn('TestChannelFifoOrder:');
  LChannel := specialize TLockFreeChannelImpl<UInt64>.Create(TEST_CAPACITY);
  try
    // Send items in order
    for I := 1 to TEST_CAPACITY do
      Check(LChannel.TrySend(UInt64(I)), 'Send ' + IntToStr(I));

    // Receive items should be in FIFO order
    for I := 1 to TEST_CAPACITY do
    begin
      Check(LChannel.TryReceive(LValue), 'Receive ' + IntToStr(I));
      Check(LValue = UInt64(I), 'FIFO order: expected ' + IntToStr(I) + ', got ' + IntToStr(LValue));
    end;
  finally
    LChannel.Free;
  end;
end;

procedure TestChannelResizeSafety;
var
  LChannel: specialize TLockFreeChannelImpl<UInt64>;
  I: Integer;
  LValue: UInt64;
begin
  WriteLn('TestChannelResizeSafety:');
  LChannel := specialize TLockFreeChannelImpl<UInt64>.Create(TEST_CAPACITY);
  try
    // Send some data
    for I := 1 to 2 do
      Check(LChannel.TrySend(UInt64(I)), 'Send ' + IntToStr(I));

    // Resize channel
    Check(LChannel.TryResize(TEST_CAPACITY * 2), 'Resize channel');

    // Data should be preserved
    for I := 1 to 2 do
    begin
      Check(LChannel.TryReceive(LValue), 'Receive after resize');
      Check(LValue = UInt64(I), 'Data preserved after resize');
    end;
  finally
    LChannel.Free;
  end;
end;

{==============================================================================
  Main Test Suite
==============================================================================}

begin
  WriteLn('=== Formal Verification Tests ===');
  WriteLn('Based on TLA+ models: SpscQueue, MpmcQueue, LockFreeChannel');
  WriteLn;

  // SPSC Queue Tests
  WriteLn('--- SPSC Queue ---');
  TestSpscQueueTypeOK;
  TestSpscQueueFifoOrder;
  TestSpscQueueBounds;
  TestSpscQueueEmpty;
  WriteLn;

  // MPMC Queue Tests
  WriteLn('--- MPMC Queue ---');
  TestMpmcQueueTypeOK;
  TestMpmcQueueFifoOrder;
  TestMpmcQueueBounds;
  TestMpmcQueueEmpty;
  WriteLn;

  // Channel Tests
  WriteLn('--- Channel ---');
  TestChannelTypeOK;
  TestChannelBufferBounds;
  TestChannelEmpty;
  TestChannelCloseSemantics;
  TestChannelFifoOrder;
  TestChannelResizeSafety;
  WriteLn;

  WriteLn(Format('Results: %d passed, %d failed, %d total', [GPassCount, GFailCount, GTestCount]));

  if GFailCount > 0 then
    Halt(1);
end.
