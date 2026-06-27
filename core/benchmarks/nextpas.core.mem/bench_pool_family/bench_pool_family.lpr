program bench_pool_family;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.bench,
  nextpas.core.mem.base,
  nextpas.core.mem.pool.fixed,
  nextpas.core.mem.blockpool,
  nextpas.core.mem.pool,
  nextpas.core.mem.stack_pool,
  nextpas.core.mem.ring_buffer;

const
  BLOCK_SIZE = 64;
  POOL_CAPACITY = 4096;
  RING_CAPACITY = 1024;

var
  GSink: Pointer;
  GIntSink: Integer;

{ --- TFixedPool --- }

procedure BenchFixedPool_AcquireRelease(aIters: Int64);
var
  LPool: TFixedPool;
  LIt: Int64;
  LPtr: Pointer;
begin
  LPool := TFixedPool.Create(BLOCK_SIZE, POOL_CAPACITY);
  try
    for LIt := 1 to aIters do
    begin
      LPool.Acquire(LPtr);
      GSink := LPtr;
      LPool.Release(LPtr);
    end;
  finally
    LPool.Free;
  end;
end;

procedure BenchFixedPool_Batch16(aIters: Int64);
var
  LPool: TFixedPool;
  LIt: Int64;
  LPtrs: array[0..15] of Pointer;
  LCount: Integer;
begin
  LPool := TFixedPool.Create(BLOCK_SIZE, POOL_CAPACITY);
  try
    for LIt := 1 to aIters do
    begin
      LCount := LPool.AcquireN(LPtrs, 16);
      LPool.ReleaseN(LPtrs, LCount);
    end;
  finally
    LPool.Free;
  end;
end;

{ --- TLocalBlockPool --- }

procedure BenchLocalBlockPool_AcquireRelease(aIters: Int64);
var
  LPool: TLocalBlockPool;
  LIt: Int64;
  LPtr: Pointer;
begin
  LPool := TLocalBlockPool.Create(BLOCK_SIZE, POOL_CAPACITY);
  try
    for LIt := 1 to aIters do
    begin
      LPtr := LPool.Acquire;
      GSink := LPtr;
      LPool.Release(LPtr);
    end;
  finally
    LPool.Free;
  end;
end;

{ --- TBlockPool --- }

procedure BenchBlockPool_AcquireRelease(aIters: Int64);
var
  LPool: TBlockPool;
  LIt: Int64;
  LPtr: Pointer;
begin
  LPool := TBlockPool.Create(BLOCK_SIZE, POOL_CAPACITY);
  try
    for LIt := 1 to aIters do
    begin
      LPtr := LPool.Acquire;
      GSink := LPtr;
      LPool.Release(LPtr);
    end;
  finally
    LPool.Free;
  end;
end;

{ --- TStackPool --- }

procedure BenchStackPool_AllocReset(aIters: Int64);
var
  LPool: TStackPool;
  LIt: Int64;
  LPtr: Pointer;
begin
  LPool := TStackPool.Create(POOL_CAPACITY * BLOCK_SIZE);
  try
    for LIt := 1 to aIters do
    begin
      LPtr := LPool.Alloc(BLOCK_SIZE);
      GSink := LPtr;
      LPool.Reset;
    end;
  finally
    LPool.Free;
  end;
end;

procedure BenchStackPool_StateRestore(aIters: Int64);
var
  LPool: TStackPool;
  LIt: Int64;
  LState: SizeUInt;
  I: Integer;
begin
  LPool := TStackPool.Create(POOL_CAPACITY * BLOCK_SIZE);
  try
    for LIt := 1 to aIters do
    begin
      LState := LPool.SaveState;
      for I := 0 to 15 do
        LPool.Alloc(BLOCK_SIZE);
      LPool.RestoreState(LState);
    end;
  finally
    LPool.Free;
  end;
end;

{ --- TRingBuffer --- }

procedure BenchRingBuffer_PushPop(aIters: Int64);
var
  LBuf: TRingBuffer;
  LIt: Int64;
  LVal: Integer;
begin
  LBuf := TRingBuffer.Create(RING_CAPACITY, SizeOf(Integer));
  try
    LVal := 1;
    for LIt := 1 to aIters do
    begin
      LBuf.Push(@LVal);
      LBuf.Pop(@GIntSink);
    end;
  finally
    LBuf.Free;
  end;
end;

procedure BenchRingBuffer_Batch64(aIters: Int64);
var
  LBuf: TRingBuffer;
  LIt: Int64;
  LData: array[0..63] of Integer;
  LOut: array[0..63] of Integer;
  LPushed, LPopped: SizeUInt;
  I: Integer;
begin
  LBuf := TRingBuffer.Create(RING_CAPACITY, SizeOf(Integer));
  try
    for I := 0 to 63 do
      LData[I] := I;
    for LIt := 1 to aIters do
    begin
      LBuf.Push(@LData[0], 64, LPushed);
      LBuf.Pop(@LOut[0], 64, LPopped);
    end;
  finally
    LBuf.Free;
  end;
end;

{ --- System.GetMem baseline --- }

procedure BenchSystem_GetMemFree(aIters: Int64);
var
  LIt: Int64;
  LPtr: Pointer;
begin
  for LIt := 1 to aIters do
  begin
    GetMem(LPtr, BLOCK_SIZE);
    GSink := LPtr;
    FreeMem(LPtr);
  end;
end;

var
  LResults: IBenchResults;

begin
  LResults := TBenchSuite.Create('nextpas.core.mem.pool_family')
    { System baseline }
    .AddLoop('System.GetMem/FreeMem_64B', @BenchSystem_GetMemFree)
    { TFixedPool }
    .AddLoop('TFixedPool.Acquire/Release_64B', @BenchFixedPool_AcquireRelease)
    .AddLoop('TFixedPool.Batch16_64B', @BenchFixedPool_Batch16)
    { TLocalBlockPool }
    .AddLoop('TLocalBlockPool.Acquire/Release_64B', @BenchLocalBlockPool_AcquireRelease)
    { TBlockPool }
    .AddLoop('TBlockPool.Acquire/Release_64B', @BenchBlockPool_AcquireRelease)
    { TStackPool }
    .AddLoop('TStackPool.Alloc/Reset_64B', @BenchStackPool_AllocReset)
    .AddLoop('TStackPool.SaveState/Restore_x16', @BenchStackPool_StateRestore)
    { TRingBuffer }
    .AddLoop('TRingBuffer.Push/Pop_Int', @BenchRingBuffer_PushPop)
    .AddLoop('TRingBuffer.Batch64_Int', @BenchRingBuffer_Batch64)
    .Run;
  WriteLn(LResults.PrintToConsole);
end.
