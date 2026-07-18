program test_lockfree_ringbuffer;

{$mode objfpc}{$H+}

uses
  nextpas.core.lockfree.ringbuffer,
  nextpas.core.lockfree,
  nextpas.core.test;

type
  TIntRingBuffer = specialize TRingBufferImpl<Integer>;

procedure TestRingBufferBasic;
var
  LBuf: TIntRingBuffer;
begin
  LBuf := TIntRingBuffer.Create(4);
  try
    Check(not LBuf.IsClosed, 'Should not be closed');
    Check(LBuf.IsEmpty, 'Should be empty');
    Check(not LBuf.IsFull, 'Should not be full');
    CheckEqual(Int64(4), LBuf.GetCapacity, 'Capacity should be 4');
    CheckEqual(Int64(0), LBuf.Count, 'Count should be 0');
  finally
    LBuf.Free;
  end;
end;

procedure TestRingBufferWriteRead;
var
  LBuf: TIntRingBuffer;
  LValue: Integer;
  LResult: TLockFreeRingBufferResult;
begin
  LBuf := TIntRingBuffer.Create(4);
  try
    // Write
    LResult := LBuf.TryWrite(10);
    Check(rbWritten = LResult, 'Write should succeed');
    LResult := LBuf.TryWrite(20);
    Check(rbWritten = LResult, 'Write should succeed');
    CheckEqual(Int64(2), LBuf.Count, 'Count should be 2');

    // Read
    LResult := LBuf.TryRead(LValue);
    Check(rbWritten = LResult, 'Read should succeed');
    CheckEqual(10, LValue, 'First value should be 10');
    LResult := LBuf.TryRead(LValue);
    Check(rbWritten = LResult, 'Read should succeed');
    CheckEqual(20, LValue, 'Second value should be 20');
    Check(LBuf.IsEmpty, 'Should be empty');
  finally
    LBuf.Free;
  end;
end;

procedure TestRingBufferFull;
var
  LBuf: TIntRingBuffer;
  LResult: TLockFreeRingBufferResult;
begin
  LBuf := TIntRingBuffer.Create(4);
  try
    // Per-slot sequence generations make all four slots usable.
    LResult := LBuf.TryWrite(1);
    Check(rbWritten = LResult, 'Write 1');
    LResult := LBuf.TryWrite(2);
    Check(rbWritten = LResult, 'Write 2');
    LResult := LBuf.TryWrite(3);
    Check(rbWritten = LResult, 'Write 3');
    LResult := LBuf.TryWrite(4);
    Check(rbWritten = LResult, 'Write 4');

    // Buffer is full
    Check(LBuf.IsFull, 'Should be full');
    LResult := LBuf.TryWrite(5);
    Check(rbFull = LResult, 'Should return full');
  finally
    LBuf.Free;
  end;
end;

procedure TestRingBufferEmpty;
var
  LBuf: TIntRingBuffer;
  LValue: Integer;
  LResult: TLockFreeRingBufferResult;
begin
  LBuf := TIntRingBuffer.Create(4);
  try
    LResult := LBuf.TryRead(LValue);
    Check(rbEmpty = LResult, 'Should return empty');
  finally
    LBuf.Free;
  end;
end;

procedure TestRingBufferClose;
var
  LBuf: TIntRingBuffer;
  LValue: Integer;
  LResult: TLockFreeRingBufferResult;
begin
  LBuf := TIntRingBuffer.Create(4);
  try
    LBuf.TryWrite(42);
    LBuf.Close;
    Check(LBuf.IsClosed, 'Should be closed');

    // Can still read existing data
    LResult := LBuf.TryRead(LValue);
    Check(rbWritten = LResult, 'Should read existing data');
    CheckEqual(42, LValue, 'Value should be 42');

    // Cannot write after close
    LResult := LBuf.TryWrite(100);
    Check(rbClosed = LResult, 'Should return closed');
  finally
    LBuf.Free;
  end;
end;

procedure TestRingBufferWrapAround;
var
  LBuf: TIntRingBuffer;
  LValue: Integer;
  LResult: TLockFreeRingBufferResult;
  LI: Integer;
begin
  LBuf := TIntRingBuffer.Create(4);
  try
    // Fill and drain multiple times to test wrap-around
    for LI := 1 to 10 do
    begin
      LResult := LBuf.TryWrite(LI);
      Check(rbWritten = LResult, 'Write should succeed');
      LResult := LBuf.TryRead(LValue);
      Check(rbWritten = LResult, 'Read should succeed');
      CheckEqual(LI, LValue, 'Value should match');
    end;
  finally
    LBuf.Free;
  end;
end;

procedure TestRingBufferPowerOf2;
var
  LBuf: TIntRingBuffer;
begin
  // Non-power-of-2 capacity should be rounded up
  LBuf := TIntRingBuffer.Create(5);
  try
    CheckEqual(Int64(8), LBuf.GetCapacity, 'Capacity should be rounded to 8');
  finally
    LBuf.Free;
  end;
end;

begin
  WriteLn('=== test_lockfree_ringbuffer ===');
  WriteLn;

  TestRingBufferBasic;
  WriteLn('  + Basic state');

  TestRingBufferWriteRead;
  WriteLn('  + Write/Read');

  TestRingBufferFull;
  WriteLn('  + Full');

  TestRingBufferEmpty;
  WriteLn('  + Empty');

  TestRingBufferClose;
  WriteLn('  + Close semantics');

  TestRingBufferWrapAround;
  WriteLn('  + Wrap-around');

  TestRingBufferPowerOf2;
  WriteLn('  + Power-of-2 rounding');

  WriteLn;
  WriteLn('All ring buffer tests passed!');
end.
