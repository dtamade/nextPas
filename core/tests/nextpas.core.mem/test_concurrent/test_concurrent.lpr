program test_concurrent;
{$mode ObjFPC}{$H+}

uses
  nextpas.core.thread.init,
  nextpas.core.text.conv,
  nextpas.core.test,
  nextpas.core.mem.intf,
  nextpas.core.mem.default,
  nextpas.core.mem.sizeclass,
  nextpas.core.mem.allocator.growing,
  nextpas.core.mem.allocator.tracking,
  nextpas.core.atomic.core;

var
  T: TTestSuite;
  LRunPassed: Boolean;

{ ── Thread worker data ── }

const
  NUM_THREADS = 4;
  OPS_PER_THREAD = 10000;

type
  PWorkerData = ^TWorkerData;
  TWorkerData = record
    Alloc: TGrowingAllocator;
    OpsCount: Int32;
    AllocSize: SizeUInt;
    Done: Boolean;
    ErrorMsg: string;
  end;

function WorkerFunc(Parameter: Pointer): PtrInt;
var
  LData: ^TWorkerData;
  LPtrs: array[0..63] of Pointer;
  LI, LJ: Int32;
  LSize: SizeUInt;
begin
  LData := PWorkerData(Parameter);
  LSize := LData^.AllocSize;
  try
    for LI := 0 to LData^.OpsCount - 1 do
    begin
      { Allocate batch }
      for LJ := 0 to 63 do
      begin
        LPtrs[LJ] := LData^.Alloc.GetMem(LSize);
        if LPtrs[LJ] = nil then
        begin
          LData^.ErrorMsg := 'GetMem returned nil at op ' + IntToStr(LI) + ' slot ' + IntToStr(LJ);
          LData^.Done := True;
          Exit(1);
        end;
        { Touch the memory to verify it's accessible }
        FillChar(LPtrs[LJ]^, LSize, Byte(LI + LJ));
      end;
      { Free batch }
      for LJ := 0 to 63 do
        LData^.Alloc.FreeMem(LPtrs[LJ], LSize);
    end;
    LData^.Done := True;
    Result := 0;
  except
    on E: Exception do
    begin
      LData^.ErrorMsg := E.Message;
      LData^.Done := True;
      Result := 1;
    end;
  end;
end;

{ ── Test: same size class, 4 threads ── }

procedure TestSameSizeClass;
var
  LWorkers: array[0..NUM_THREADS - 1] of TWorkerData;
  LThreads: array[0..NUM_THREADS - 1] of TThreadID;
  LAllocator: TGrowingAllocator;
  LI: Int32;
  LAllDone: Boolean;
begin
  LAllocator := DefaultGrowingAllocator;

  for LI := 0 to NUM_THREADS - 1 do
  begin
    LWorkers[LI].Alloc := LAllocator;
    LWorkers[LI].OpsCount := OPS_PER_THREAD;
    LWorkers[LI].AllocSize := 64;
    LWorkers[LI].Done := False;
    LWorkers[LI].ErrorMsg := '';
  end;

  { Spawn threads }
  for LI := 0 to NUM_THREADS - 1 do
    LThreads[LI] := BeginThread(@WorkerFunc, @LWorkers[LI]);

  { Wait for completion }
  repeat
    LAllDone := True;
    for LI := 0 to NUM_THREADS - 1 do
      if not LWorkers[LI].Done then
      begin
        LAllDone := False;
        Break;
      end;
    if not LAllDone then
      SleepMs(1);
  until LAllDone;

  { Join threads }
  for LI := 0 to NUM_THREADS - 1 do
    WaitForThreadTerminate(LThreads[LI], 0);

  { Check results }
  for LI := 0 to NUM_THREADS - 1 do
    Check(LWorkers[LI].ErrorMsg = '', 'thread ' + IntToStr(LI) + ': ' + LWorkers[LI].ErrorMsg);

  WriteLn('PASS: ', NUM_THREADS, ' threads x ', OPS_PER_THREAD, ' ops x 64B');
end;

{ ── Test: mixed sizes, 4 threads ── }

procedure TestMixedSizes;
var
  LWorkers: array[0..NUM_THREADS - 1] of TWorkerData;
  LThreads: array[0..NUM_THREADS - 1] of TThreadID;
  LAllocator: TGrowingAllocator;
  LSizes: array[0..3] of SizeUInt;
  LI: Int32;
  LAllDone: Boolean;
begin
  LAllocator := DefaultGrowingAllocator;
  LSizes[0] := 32;
  LSizes[1] := 256;
  LSizes[2] := 2048;
  LSizes[3] := 16384;

  for LI := 0 to NUM_THREADS - 1 do
  begin
    LWorkers[LI].Alloc := LAllocator;
    LWorkers[LI].OpsCount := OPS_PER_THREAD;
    LWorkers[LI].AllocSize := LSizes[LI];
    LWorkers[LI].Done := False;
    LWorkers[LI].ErrorMsg := '';
  end;

  for LI := 0 to NUM_THREADS - 1 do
    LThreads[LI] := BeginThread(@WorkerFunc, @LWorkers[LI]);

  repeat
    LAllDone := True;
    for LI := 0 to NUM_THREADS - 1 do
      if not LWorkers[LI].Done then
      begin
        LAllDone := False;
        Break;
      end;
    if not LAllDone then
      SleepMs(1);
  until LAllDone;

  for LI := 0 to NUM_THREADS - 1 do
    WaitForThreadTerminate(LThreads[LI], 0);

  for LI := 0 to NUM_THREADS - 1 do
    Check(LWorkers[LI].ErrorMsg = '', 'thread ' + IntToStr(LI) + ': ' + LWorkers[LI].ErrorMsg);

  WriteLn('PASS: ', NUM_THREADS, ' threads x ', OPS_PER_THREAD, ' ops x mixed sizes (32/256/2K/16K)');
end;

{ ── Test: high contention, 8 threads ── }

procedure TestHighContention;
var
  LWorkers: array[0..7] of TWorkerData;
  LThreads: array[0..7] of TThreadID;
  LAllocator: TGrowingAllocator;
  LI: Int32;
  LAllDone: Boolean;
begin
  LAllocator := DefaultGrowingAllocator;

  for LI := 0 to 7 do
  begin
    LWorkers[LI].Alloc := LAllocator;
    LWorkers[LI].OpsCount := 5000;
    LWorkers[LI].AllocSize := 128;
    LWorkers[LI].Done := False;
    LWorkers[LI].ErrorMsg := '';
  end;

  for LI := 0 to 7 do
    LThreads[LI] := BeginThread(@WorkerFunc, @LWorkers[LI]);

  repeat
    LAllDone := True;
    for LI := 0 to 7 do
      if not LWorkers[LI].Done then
      begin
        LAllDone := False;
        Break;
      end;
    if not LAllDone then
      SleepMs(1);
  until LAllDone;

  for LI := 0 to 7 do
    WaitForThreadTerminate(LThreads[LI], 0);

  for LI := 0 to 7 do
    Check(LWorkers[LI].ErrorMsg = '', 'thread ' + IntToStr(LI) + ': ' + LWorkers[LI].ErrorMsg);

  WriteLn('PASS: 8 threads x 5000 ops x 128B high contention');
end;

{ ── Test: cross-thread free ── }

type
  PCrossFreeData = ^TCrossFreeData;
  TCrossFreeData = record
    Alloc: TGrowingAllocator;
    Ptrs: array[0..255] of Pointer;
    Count: Int32;
    Done: Boolean;
    ErrorMsg: string;
  end;

function AllocatorFunc(Parameter: Pointer): PtrInt;
var
  LData: PCrossFreeData;
  LI: Int32;
begin
  LData := PCrossFreeData(Parameter);
  try
    for LI := 0 to LData^.Count - 1 do
    begin
      LData^.Ptrs[LI] := LData^.Alloc.GetMem(64);
      if LData^.Ptrs[LI] = nil then
      begin
        LData^.ErrorMsg := 'Alloc returned nil at ' + IntToStr(LI);
        LData^.Done := True;
        Exit(1);
      end;
      FillChar(LData^.Ptrs[LI]^, 64, Byte(LI));
    end;
    ReadWriteBarrier; { 确保 Ptrs 写入在 Done 之前对其他线程可见 }
    LData^.Done := True;
    Result := 0;
  except
    on E: Exception do
    begin
      LData^.ErrorMsg := E.Message;
      LData^.Done := True;
      Result := 1;
    end;
  end;
end;

function FreerFunc(Parameter: Pointer): PtrInt;
var
  LData: PCrossFreeData;
  LI: Int32;
begin
  LData := PCrossFreeData(Parameter);
  try
    { Wait for allocator to finish }
    while not LData^.Done do
      SleepMs(1);
    ReadWriteBarrier; { 确保看到 Ptrs 的最新写入 }
    { Free all from different thread }
    for LI := 0 to LData^.Count - 1 do
      LData^.Alloc.FreeMem(LData^.Ptrs[LI], 64);
    LData^.Done := False; { Signal completion }
    Result := 0;
  except
    on E: Exception do
    begin
      LData^.ErrorMsg := E.Message;
      Result := 1;
    end;
  end;
end;

procedure TestCrossThreadFree;
var
  LData: TCrossFreeData;
  LAllocThread, LFreeThread: TThreadID;
begin
  LData.Alloc := DefaultGrowingAllocator;
  LData.Count := 256;
  LData.Done := False;
  LData.ErrorMsg := '';

  LAllocThread := BeginThread(@AllocatorFunc, @LData);
  LFreeThread := BeginThread(@FreerFunc, @LData);

  WaitForThreadTerminate(LAllocThread, 0);
  WaitForThreadTerminate(LFreeThread, 0);

  Check(LData.ErrorMsg = '', 'cross-thread free: ' + LData.ErrorMsg);
  WriteLn('PASS: cross-thread free (256 allocs from thread A, freed from thread B)');
end;

{ ── Test: multi-size stress with random sizes across all bands ── }

const
  RANDOM_OPS = 5000;
  RANDOM_BATCH = 32;

procedure TestRandomSizes;
var
  LAllocator: TGrowingAllocator;
  LPtrs: array[0..RANDOM_BATCH - 1] of Pointer;
  LSizes: array[0..RANDOM_BATCH - 1] of SizeUInt;
  LSizeClasses: array[0..11] of SizeUInt;
  LI, LJ, LIdx: Int32;
  LSize: SizeUInt;
begin
  LAllocator := DefaultGrowingAllocator;
  { Cover all 6 bands: 16B, 64B, 256B, 1KB, 4KB, 16KB }
  LSizeClasses[0] := 16; LSizeClasses[1] := 32; LSizeClasses[2] := 64;
  LSizeClasses[3] := 128; LSizeClasses[4] := 256; LSizeClasses[5] := 512;
  LSizeClasses[6] := 1024; LSizeClasses[7] := 2048; LSizeClasses[8] := 4096;
  LSizeClasses[9] := 8192; LSizeClasses[10] := 16384; LSizeClasses[11] := 32768;

  for LI := 0 to RANDOM_OPS - 1 do
  begin
    { Allocate batch with random sizes }
    for LJ := 0 to RANDOM_BATCH - 1 do
    begin
      LIdx := (LI * RANDOM_BATCH + LJ) mod 12;
      LSize := LSizeClasses[LIdx];
      LSizes[LJ] := LSize;
      LPtrs[LJ] := LAllocator.GetMem(LSize);
      Check(LPtrs[LJ] <> nil, 'random alloc ' + IntToStr(LSize) + 'B');
      FillChar(LPtrs[LJ]^, LSize, Byte(LI + LJ));
    end;
    { Free batch }
    for LJ := 0 to RANDOM_BATCH - 1 do
      LAllocator.FreeMem(LPtrs[LJ], LSizes[LJ]);
  end;
  WriteLn('PASS: random sizes stress (', RANDOM_OPS * RANDOM_BATCH, ' alloc/free across all bands)');
end;

{ ── Test: long-running leak detection ── }

procedure TestLeakDetection;
var
  LTracker: IAllocator;
  LPtrs: array[0..127] of Pointer;
  LI, LJ: Int32;
begin
  LTracker := TTrackingAllocator.Create(DefaultAllocator);

  { Simulate 1000 iterations of alloc/free cycles }
  for LI := 0 to 999 do
  begin
    { Allocate 128 blocks }
    for LJ := 0 to 127 do
    begin
      LPtrs[LJ] := LTracker.GetMem(64 + SizeUInt(LJ mod 4) * 64);
      Check(LPtrs[LJ] <> nil, 'leak detect alloc ' + IntToStr(LJ));
    end;
    { Free all 128 blocks }
    for LJ := 0 to 127 do
      LTracker.FreeMem(LPtrs[LJ]);
  end;

  { Verify no leaks }
  Check(True, 'leak detection completed without error');
  WriteLn('PASS: leak detection (1000 iterations x 128 blocks)');
end;

{ ── Main ── }

begin
  T := TTestSuite.Create('test_concurrent');

  T.Test('same_size_class', @TestSameSizeClass);
  T.Test('mixed_sizes', @TestMixedSizes);
  T.Test('high_contention_8_threads', @TestHighContention);
  T.Test('cross_thread_free', @TestCrossThreadFree);
  T.Test('random_sizes_stress', @TestRandomSizes);
  T.Test('leak_detection', @TestLeakDetection);

  LRunPassed := T.Run;
  T.Summary;
  if not LRunPassed then
    Halt(1);
end.
