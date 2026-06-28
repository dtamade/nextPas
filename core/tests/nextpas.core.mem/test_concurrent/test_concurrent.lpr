program test_concurrent;
{$mode ObjFPC}{$H+}

uses
  cthreads,
  SysUtils,
  nextpas.core.test,
  nextpas.core.mem.sizeclass,
  nextpas.core.mem.allocator.growing;

var
  T: TTestSuite;

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
      Sleep(1);
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
      Sleep(1);
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
      Sleep(1);
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
      Sleep(1);
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

{ ── Main ── }

begin
  T := TTestSuite.Create('test_concurrent');

  T.Test('same_size_class', @TestSameSizeClass);
  T.Test('mixed_sizes', @TestMixedSizes);
  T.Test('high_contention_8_threads', @TestHighContention);
  T.Test('cross_thread_free', @TestCrossThreadFree);

  T.Run;
  T.Summary;
end.
