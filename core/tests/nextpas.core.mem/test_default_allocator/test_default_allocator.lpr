program test_default_allocator;

{$I nextpas.core.settings.inc}

uses
  {$IFDEF UNIX}
  nextpas.core.thread.init,
  {$ENDIF}
  nextpas.core.errors,
  nextpas.core.exception,
  nextpas.core.test,
  nextpas.core.mem,
  nextpas.core.platform.thread;

const
  THREAD_COUNT = 12;
  ITERATION_COUNT = 64;

type
  PDefaultAllocatorThreadData = ^TDefaultAllocatorThreadData;
  TDefaultAllocatorThreadData = record
    Allocator: TAllocator;
    Failed: Boolean;
    StartFlag: PLongInt;
  end;

var
  T: TTestSuite;

function DefaultAllocatorThreadProc(AArg: Pointer): Pointer; cdecl;
var
  LData: PDefaultAllocatorThreadData;
  LIndex: Integer;
  LPtr: Pointer;
begin
  LData := PDefaultAllocatorThreadData(AArg);
  while LData^.StartFlag^ = 0 do
    platform_thread_yield;

  try
    LData^.Allocator := DefaultAllocator;
    for LIndex := 0 to ITERATION_COUNT - 1 do
    begin
      LPtr := LData^.Allocator.GetMem(32);
      if LPtr = nil then
        raise Exception.Create('DefaultAllocator.GetMem returned nil');
      PByte(LPtr)^ := Byte(LIndex);
      LPtr := LData^.Allocator.ReallocMem(LPtr, 64);
      if LPtr = nil then
        raise Exception.Create('DefaultAllocator.ReallocMem returned nil');
      if PByte(LPtr)^ <> Byte(LIndex) then
        raise Exception.Create('DefaultAllocator.ReallocMem did not preserve prefix');
      LData^.Allocator.FreeMem(LPtr);
    end;
  except
    LData^.Failed := True;
  end;
  Result := nil;
end;

procedure TestDefaultAllocatorSingletonSingleThread;
var
  LFirst: TAllocator;
  LSecond: TAllocator;
begin
  LFirst := DefaultAllocator;
  LSecond := DefaultAllocator;

  Check(LFirst <> nil, 'DefaultAllocator should return an allocator');
  Check(LFirst = LSecond, 'DefaultAllocator should return the canonical singleton');
  Check(LFirst.Traits.ThreadSafe, 'DefaultAllocator should publish a thread-safe allocator');
end;

procedure TestDefaultAllocatorConcurrentStart;
var
  LThreads: array[0..THREAD_COUNT - 1] of TPlatformThreadRecord;
  LThreadData: array[0..THREAD_COUNT - 1] of TDefaultAllocatorThreadData;
  LStartFlag: LongInt;
  LIndex: Integer;
  LFirst: TAllocator;
begin
  LStartFlag := 0;
  for LIndex := 0 to High(LThreads) do
  begin
    LThreadData[LIndex].StartFlag := @LStartFlag;
    LThreadData[LIndex].Failed := False;
    LThreadData[LIndex].Allocator := nil;
    platform_thread_spawn(LThreads[LIndex], @DefaultAllocatorThreadProc,
      @LThreadData[LIndex]);
  end;

  LStartFlag := 1;
  for LIndex := 0 to High(LThreads) do
    platform_thread_wait(LThreads[LIndex]);

  LFirst := LThreadData[0].Allocator;
  Check(LFirst <> nil, 'first worker should publish an allocator');
  for LIndex := 0 to High(LThreads) do
  begin
    Check(not LThreadData[LIndex].Failed, 'worker should not fail');
    Check(LThreadData[LIndex].Allocator <> nil, 'worker allocator should be assigned');
    Check(LThreadData[LIndex].Allocator = LFirst, 'all workers should see the same allocator identity');
  end;
end;

procedure TestDefaultAllocatorAllocMem;
var
  LAllocator: TAllocator;
  LPtr: Pointer;
  LI: Integer;
begin
  LAllocator := DefaultAllocator;
  { AllocMem should zero-initialize }
  LPtr := LAllocator.AllocMem(256);
  Check(LPtr <> nil, 'AllocMem should not return nil');
  for LI := 0 to 255 do
    Check(PByte(LPtr)[LI] = 0, 'AllocMem should zero-initialize');
  LAllocator.FreeMem(LPtr);
end;

procedure TestDefaultAllocatorMemSize;
var
  LAllocator: TAllocator;
  LPtr: Pointer;
  LReported: SizeUInt;
begin
  LAllocator := DefaultAllocator;
  LPtr := LAllocator.GetMem(100);
  Check(LPtr <> nil, 'GetMem should not return nil');
  LReported := LAllocator.MemSize(LPtr);
  Check(LReported >= 100, 'MemSize should report >= 100');
  LAllocator.FreeMem(LPtr);
end;

procedure TestDefaultAllocatorReallocPreserves;
var
  LAllocator: TAllocator;
  LPtr: Pointer;
  LI: Integer;
begin
  LAllocator := DefaultAllocator;
  LPtr := LAllocator.GetMem(64);
  Check(LPtr <> nil, 'GetMem should not return nil');
  { Write pattern }
  for LI := 0 to 63 do
    PByte(LPtr)[LI] := Byte(LI);
  { Realloc to larger }
  LPtr := LAllocator.ReallocMem(LPtr, 512);
  Check(LPtr <> nil, 'ReallocMem should not return nil');
  { Verify prefix preserved }
  for LI := 0 to 63 do
    Check(PByte(LPtr)[LI] = Byte(LI), 'ReallocMem should preserve content');
  LAllocator.FreeMem(LPtr);
end;

begin
  T := TTestSuite.Create('nextpas.core.mem.default_allocator');
  T.Test('singleton single-thread', @TestDefaultAllocatorSingletonSingleThread);
  T.Test('concurrent start returns same instance', @TestDefaultAllocatorConcurrentStart);
  T.Test('alloc_mem_zero_initialized', @TestDefaultAllocatorAllocMem);
  T.Test('realloc_preserves_content', @TestDefaultAllocatorReallocPreserves);
  T.Run;

  T.Summary;
end.
