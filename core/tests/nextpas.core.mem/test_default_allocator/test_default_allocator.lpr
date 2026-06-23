program test_default_allocator;

{$I nextpas.core.settings.inc}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  nextpas.core.errors,
  nextpas.core.testing,
  nextpas.core.mem,
  nextpas.core.platform.thread;

const
  THREAD_COUNT = 12;
  ITERATION_COUNT = 64;

type
  PDefaultAllocatorThreadData = ^TDefaultAllocatorThreadData;
  TDefaultAllocatorThreadData = record
    Allocator: IAllocator;
    Failed: Boolean;
    StartFlag: PLongInt;
  end;

var
  T: TTestRunner;

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
  LFirst: IAllocator;
  LSecond: IAllocator;
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
  LFirst: IAllocator;
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

begin
  T := TTestRunner.Create('nextpas.core.mem.default_allocator');
  T.Run('singleton single-thread', @TestDefaultAllocatorSingletonSingleThread);
  T.Run('concurrent start returns same instance', @TestDefaultAllocatorConcurrentStart);
  T.Summary;
end.
