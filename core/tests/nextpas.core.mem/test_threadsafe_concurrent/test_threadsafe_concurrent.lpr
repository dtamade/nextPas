program test_threadsafe_concurrent;
{$I nextpas.core.settings.inc}

uses
  nextpas.core.thread.init,
  nextpas.core.test,
  nextpas.core.text.conv,
  nextpas.core.mem.base,
  nextpas.core.mem.intf,
  nextpas.core.mem.allocator.base,
  nextpas.core.mem.allocator.foundation,
  nextpas.core.mem.allocator.thread_safe,
  nextpas.core.platform.thread;

var
  T: TTestSuite;
  LRunPassed: Boolean;

const
  NUM_THREADS = 4;
  OPS_PER_THREAD = 1000;

type
  PWorkerData = ^TWorkerData;
  TWorkerData = record
    Alloc: TThreadSafeAllocator;
    OpsCount: Int32;
    Done: Boolean;
    ErrorMsg: string;
  end;

function WorkerFunc(Parameter: Pointer): PtrInt;
var
  LData: PWorkerData;
  LPtrs: array[0..31] of Pointer;
  LI, LJ: Int32;
begin
  LData := PWorkerData(Parameter);
  try
    for LI := 0 to LData^.OpsCount - 1 do
    begin
      for LJ := 0 to 31 do
      begin
        LPtrs[LJ] := LData^.Alloc.GetMem(64);
        if LPtrs[LJ] = nil then
        begin
          LData^.ErrorMsg := 'GetMem returned nil at op ' + IntToStr(LI);
          LData^.Done := True;
          Exit(1);
        end;
        FillChar(LPtrs[LJ]^, 64, Byte(LI + LJ));
      end;
      for LJ := 0 to 31 do
        LData^.Alloc.FreeMem(LPtrs[LJ]);
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

procedure TestConcurrentAllocFree;
var
  LAlloc: TThreadSafeAllocator;
  LWorkers: array[0..NUM_THREADS - 1] of TWorkerData;
  LThreads: array[0..NUM_THREADS - 1] of TThreadID;
  LI: Integer;
  LAllDone: Boolean;
begin
  LAlloc := TThreadSafeAllocator.Create(GetRtlAllocator);
  try
    for LI := 0 to NUM_THREADS - 1 do
    begin
      LWorkers[LI].Alloc := LAlloc;
      LWorkers[LI].OpsCount := OPS_PER_THREAD;
      LWorkers[LI].Done := False;
      LWorkers[LI].ErrorMsg := '';
      LThreads[LI] := BeginThread(@WorkerFunc, @LWorkers[LI]);
    end;

    { Wait for all threads }
    repeat
      LAllDone := True;
      for LI := 0 to NUM_THREADS - 1 do
        if not LWorkers[LI].Done then
        begin
          LAllDone := False;
          platform_thread_yield;
        end;
    until LAllDone;

    for LI := 0 to NUM_THREADS - 1 do
    begin
      WaitForThreadTerminate(LThreads[LI], 0);
      Check(LWorkers[LI].ErrorMsg = '', 'Thread ' + IntToStr(LI) + ': ' + LWorkers[LI].ErrorMsg);
    end;
  finally
    LAlloc.Free;
  end;
end;

procedure TestConcurrentMixedSizes;
var
  LAlloc: TThreadSafeAllocator;
  LPtrs: array[0..99] of Pointer;
  LI: Integer;
begin
  LAlloc := TThreadSafeAllocator.Create(GetRtlAllocator);
  try
    { Different sizes from same thread }
    for LI := 0 to 99 do
    begin
      LPtrs[LI] := LAlloc.GetMem(32 + SizeUInt(LI) * 8);
      Check(LPtrs[LI] <> nil, 'Mixed size alloc #' + IntToStr(LI) + ' failed');
      FillChar(LPtrs[LI]^, 32 + SizeUInt(LI) * 8, Byte(LI));
    end;
    for LI := 0 to 99 do
      LAlloc.FreeMem(LPtrs[LI]);
  finally
    LAlloc.Free;
  end;
end;

procedure TestTraits;
var
  LAlloc: TThreadSafeAllocator;
begin
  LAlloc := TThreadSafeAllocator.Create(GetRtlAllocator);
  try
    Check(LAlloc.Traits.ThreadSafe, 'ThreadSafe should be True');
  finally
    LAlloc.Free;
  end;
end;

procedure TestAllocMemZeroed;
var
  LAlloc: TThreadSafeAllocator;
  LPtr: Pointer;
  LI: Integer;
begin
  LAlloc := TThreadSafeAllocator.Create(GetRtlAllocator);
  try
    LPtr := LAlloc.AllocMem(512);
    Check(LPtr <> nil, 'AllocMem should succeed');
    for LI := 0 to 511 do
      Check(PByte(LPtr)[LI] = 0, 'AllocMem should be zeroed');
    LAlloc.FreeMem(LPtr);
  finally
    LAlloc.Free;
  end;
end;

begin
  T := TTestSuite.Create('test_threadsafe_concurrent');
  T.Test('ConcurrentAllocFree', @TestConcurrentAllocFree);
  T.Test('ConcurrentMixedSizes', @TestConcurrentMixedSizes);
  T.Test('Traits', @TestTraits);
  T.Test('AllocMemZeroed', @TestAllocMemZeroed);
  LRunPassed := T.Run;
  T.Summary;
  if not LRunPassed then
    Halt(1);
end.
