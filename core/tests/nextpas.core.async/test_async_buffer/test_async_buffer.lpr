program test_async_buffer;
{$mode ObjFPC}{$H+}{$J-}

uses
  nextpas.core.text.conv,
  nextpas.core.base, nextpas.core.errors,
  nextpas.core.async.buffer;

const
  HEAPTRC_ACTIVE =
    {$IFDEF HEAPTRC_ACTIVE} True {$ELSE} False {$ENDIF};

var
  GTestsPassed: Integer = 0;
  GTestsFailed: Integer = 0;

procedure Check(ACondition: Boolean; const ATestName: string);
begin
  if ACondition then
  begin
    Inc(GTestsPassed);
    WriteLn('  ✓ ', ATestName);
  end
  else
  begin
    Inc(GTestsFailed);
    WriteLn('  ✗ FAIL: ', ATestName);
  end;
end;

{ Test 1: Basic buffer allocation }
procedure TestBufferAlloc;
var
  LBuf: TAsyncBuffer;
begin
  WriteLn('TestBufferAlloc:');
  LBuf := AsyncBufferAlloc(1024);
  Check(LBuf.Data <> nil, 'data allocated');
  Check(LBuf.Len = 1024, 'length is 1024');
  Check(LBuf.Cap = 1024, 'capacity is 1024');
  Check(LBuf.Owner = True, 'owner is true');
  AsyncBufferFree(LBuf);
  Check(LBuf.Data = nil, 'data freed');
  Check(LBuf.Len = 0, 'length is 0');
end;

{ Test 2: Buffer from data (zero-copy) }
procedure TestBufferFromData;
var
  LData: array[0..9] of Byte;
  LBuf: TAsyncBuffer;
begin
  WriteLn('TestBufferFromData:');
  FillChar(LData, SizeOf(LData), 42);
  LBuf := AsyncBufferFromData(@LData[0], 10);
  Check(LBuf.Data = @LData[0], 'data points to original');
  Check(LBuf.Len = 10, 'length is 10');
  Check(LBuf.Owner = False, 'owner is false (zero-copy)');
  { Don't free - we don't own it }
end;

{ Test 3: Buffer copy }
procedure TestBufferCopy;
var
  LSrc, LDst: TAsyncBuffer;
  LI: Integer;
begin
  WriteLn('TestBufferCopy:');
  LSrc := AsyncBufferAlloc(100);
  FillChar(LSrc.Data^, 100, 42);

  LDst := AsyncBufferCopy(LSrc);
  Check(LDst.Data <> nil, 'copy data allocated');
  Check(LDst.Len = 100, 'copy length is 100');
  Check(LDst.Owner = True, 'copy owner is true');
  Check(LDst.Data <> LSrc.Data, 'different pointer');

  { Verify content }
  for LI := 0 to 99 do
    if PByte(LDst.Data)[LI] <> 42 then
    begin
      Check(False, 'content mismatch at ' + IntToStr(LI));
      Break;
    end;
  Check(True, 'content matches');

  AsyncBufferFree(LSrc);
  AsyncBufferFree(LDst);
end;

{ Test 4: Buffer pool creation }
procedure TestBufferPoolCreate;
var
  LPool: IAsyncBufferPool;
begin
  WriteLn('TestBufferPoolCreate:');
  LPool := CreateAsyncBufferPool(4096, 1024);
  Check(LPool <> nil, 'pool created');
  Check(LPool.Capacity = 1024, 'capacity is 1024');
  Check(LPool.ActiveCount = 0, 'initial active count is 0');
end;

{ Test 5: Buffer pool alloc and free }
procedure TestBufferPoolAllocFree;
var
  LPool: IAsyncBufferPool;
  LBuf: TAsyncBuffer;
begin
  WriteLn('TestBufferPoolAllocFree:');
  LPool := CreateAsyncBufferPool(4096, 1024);

  LBuf := LPool.Alloc(1024);
  Check(LBuf.Data <> nil, 'buffer allocated');
  Check(LBuf.Len = 1024, 'length is 1024');
  Check(LBuf.Cap = 4096, 'capacity is chunk size (4096)');
  Check(LPool.ActiveCount = 1, 'active count is 1');

  LPool.Free(LBuf);
  Check(LBuf.Data = nil, 'buffer freed');
  Check(LPool.ActiveCount = 0, 'active count is 0');
end;

{ Test 6: Buffer pool reuse }
procedure TestBufferPoolReuse;
var
  LPool: IAsyncBufferPool;
  LBuf1, LBuf2: TAsyncBuffer;
  LAllocated, LFreed, LActive, LPooled: UInt64;
begin
  WriteLn('TestBufferPoolReuse:');
  LPool := CreateAsyncBufferPool(4096, 1024);

  { Alloc and free }
  LBuf1 := LPool.Alloc(1024);
  LPool.Free(LBuf1);

  { Alloc again - should reuse from pool }
  LBuf2 := LPool.Alloc(1024);
  Check(LBuf2.Data <> nil, 'buffer allocated from pool');
  Check(LBuf2.Cap = 4096, 'capacity is chunk size');

  LPool.Free(LBuf2);

  { Check stats }
  LPool.GetStats(LAllocated, LFreed, LActive, LPooled);
  Check(LAllocated = 2, 'allocated count is 2');
  Check(LFreed = 2, 'freed count is 2');
  Check(LActive = 0, 'active count is 0');
  Check(LPooled = 2, 'pooled count is 2 (1 returned + 1 reused)');
end;

{ Test 7: Buffer pool with large allocation }
procedure TestBufferPoolLargeAlloc;
var
  LPool: IAsyncBufferPool;
  LBuf: TAsyncBuffer;
begin
  WriteLn('TestBufferPoolLargeAlloc:');
  LPool := CreateAsyncBufferPool(4096, 1024);

  { Alloc larger than chunk size }
  LBuf := LPool.Alloc(8192);
  Check(LBuf.Data <> nil, 'large buffer allocated');
  Check(LBuf.Len = 8192, 'length is 8192');
  Check(LBuf.Cap = 8192, 'capacity is 8192 (not pooled)');

  LPool.Free(LBuf);
  Check(LPool.ActiveCount = 0, 'active count is 0');
end;

{ Test 8: Buffer pool stats }
procedure TestBufferPoolStats;
var
  LPool: IAsyncBufferPool;
  LBuf1, LBuf2: TAsyncBuffer;
  LAllocated, LFreed, LActive, LPooled: UInt64;
begin
  WriteLn('TestBufferPoolStats:');
  LPool := CreateAsyncBufferPool(4096, 1024);

  LBuf1 := LPool.Alloc(1024);
  LBuf2 := LPool.Alloc(2048);

  LPool.GetStats(LAllocated, LFreed, LActive, LPooled);
  Check(LAllocated = 2, 'allocated count is 2');
  Check(LFreed = 0, 'freed count is 0');
  Check(LActive = 2, 'active count is 2');

  LPool.Free(LBuf1);
  LPool.Free(LBuf2);

  LPool.GetStats(LAllocated, LFreed, LActive, LPooled);
  Check(LAllocated = 2, 'allocated count is 2');
  Check(LFreed = 2, 'freed count is 2');
  Check(LActive = 0, 'active count is 0');
end;

{ Test 9: Buffer pool capacity limit }
procedure TestBufferPoolCapacity;
var
  LPool: IAsyncBufferPool;
  LBufs: array[0..2] of TAsyncBuffer;
  LI: Integer;
  LAllocated, LFreed, LActive, LPooled: UInt64;
begin
  WriteLn('TestBufferPoolCapacity:');
  LPool := CreateAsyncBufferPool(4096, 2); { Capacity = 2 }

  { Alloc 3 buffers }
  for LI := 0 to 2 do
    LBufs[LI] := LPool.Alloc(1024);

  { Free all - only 2 should be pooled }
  for LI := 0 to 2 do
    LPool.Free(LBufs[LI]);

  LPool.GetStats(LAllocated, LFreed, LActive, LPooled);
  Check(LAllocated = 3, 'allocated count is 3');
  Check(LFreed = 3, 'freed count is 3');
  Check(LPooled = 2, 'pooled count is 2 (capacity limit)');
end;

{ Test 10: Buffer write and read }
procedure TestBufferReadWrite;
var
  LBuf: TAsyncBuffer;
  LI: Integer;
begin
  WriteLn('TestBufferReadWrite:');
  LBuf := AsyncBufferAlloc(100);

  { Write pattern }
  for LI := 0 to 99 do
    PByte(LBuf.Data)[LI] := LI mod 256;

  { Read and verify }
  for LI := 0 to 99 do
    if PByte(LBuf.Data)[LI] <> (LI mod 256) then
    begin
      Check(False, 'mismatch at ' + IntToStr(LI));
      Break;
    end;
  Check(True, 'data matches');

  AsyncBufferFree(LBuf);
end;

{ Main }
begin
  WriteLn('=== test_async_buffer ===');
  WriteLn;

  TestBufferAlloc;
  WriteLn;

  TestBufferFromData;
  WriteLn;

  TestBufferCopy;
  WriteLn;

  TestBufferPoolCreate;
  WriteLn;

  TestBufferPoolAllocFree;
  WriteLn;

  TestBufferPoolReuse;
  WriteLn;

  TestBufferPoolLargeAlloc;
  WriteLn;

  TestBufferPoolStats;
  WriteLn;

  TestBufferPoolCapacity;
  WriteLn;

  TestBufferReadWrite;
  WriteLn;

  WriteLn('=== Results ===');
  WriteLn('Passed: ', GTestsPassed);
  WriteLn('Failed: ', GTestsFailed);
  WriteLn('Total:  ', GTestsPassed + GTestsFailed);
  WriteLn;

  if GTestsFailed > 0 then
  begin
    WriteLn('FAILED');
    Halt(1);
  end
  else
    WriteLn('OK');
end.
