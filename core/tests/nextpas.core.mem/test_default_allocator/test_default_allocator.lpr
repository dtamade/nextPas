program test_default_allocator;
{**
 * Default dual-track (S5):
 *   DefaultHeap / GetMem — Growing hot path (concrete, no vtable)
 *   DefaultAllocator     — IAllocator plug-in surface (Growing IAllocator root)
 *}

{$I nextpas.core.settings.inc}

uses
  nextpas.core.thread.init,
  nextpas.core.errors,
  nextpas.core.exception,
  nextpas.core.test,
  nextpas.core.mem,
  nextpas.core.mem.allocator.growing_ia,
  nextpas.core.mem.allocator.rtl,
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

  PHeapThreadData = ^THeapThreadData;
  THeapThreadData = record
    Failed: Boolean;
    StartFlag: PLongInt;
  end;

var
  T: TTestSuite;
  LRunPassed: Boolean;

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

function HeapThreadProc(AArg: Pointer): Pointer; cdecl;
var
  LData: PHeapThreadData;
  LIndex: Integer;
  LPtr: Pointer;
  LHeap: TGrowingAllocator;
begin
  LData := PHeapThreadData(AArg);
  while LData^.StartFlag^ = 0 do
    platform_thread_yield;

  try
    LHeap := DefaultHeap;
    for LIndex := 0 to ITERATION_COUNT - 1 do
    begin
      LPtr := LHeap.GetMem(32);
      if LPtr = nil then
        raise Exception.Create('DefaultHeap.GetMem returned nil');
      PByte(LPtr)^ := Byte(LIndex);
      LPtr := LHeap.ReallocMem(LPtr, 32, 64);
      if LPtr = nil then
        raise Exception.Create('DefaultHeap.ReallocMem returned nil');
      if PByte(LPtr)^ <> Byte(LIndex) then
        raise Exception.Create('DefaultHeap.ReallocMem did not preserve prefix');
      LHeap.FreeMem(LPtr, 64);
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

procedure TestDefaultHeapSingleton;
var
  LFirst, LSecond: TGrowingAllocator;
begin
  LFirst := DefaultHeap;
  LSecond := DefaultHeap;
  Check(LFirst <> nil, 'DefaultHeap non-nil');
  Check(LFirst = LSecond, 'DefaultHeap singleton');
  Check(DefaultGrowingAllocator = LFirst, 'DefaultGrowingAllocator aliases DefaultHeap');
end;

procedure TestProcessGetMemUsesHeap;
var
  LPtr: Pointer;
  LInt: PInteger;
begin
  LPtr := GetMem(64);
  Check(LPtr <> nil, 'GetMem via DefaultHeap');
  LInt := PInteger(LPtr);
  LInt^ := $12345678;
  Check(LInt^ = $12345678, 'write survives');
  FreeMem(LPtr, 64);

  LPtr := AllocMem(32);
  Check(LPtr <> nil, 'AllocMem');
  Check(PByte(LPtr)^ = 0, 'AllocMem zeroed');
  FreeMem(LPtr, 32);

  LPtr := GetMem(16);
  Check(LPtr <> nil, 'GetMem for realloc');
  LPtr := ReallocMem(LPtr, 16, 128);
  Check(LPtr <> nil, 'ReallocMem sized');
  FreeMem(LPtr, 128);

  LPtr := GetMem(48);
  Check(LPtr <> nil, 'GetMem for unknown-size free');
  FreeMem(LPtr);
  Check(True, 'FreeMem(ptr) via span scan');
end;

procedure TestDefaultHeapConcurrent;
var
  LThreads: array[0..THREAD_COUNT - 1] of TPlatformThreadRecord;
  LThreadData: array[0..THREAD_COUNT - 1] of THeapThreadData;
  LStartFlag: LongInt;
  LIndex: Integer;
begin
  LStartFlag := 0;
  for LIndex := 0 to High(LThreads) do
  begin
    LThreadData[LIndex].StartFlag := @LStartFlag;
    LThreadData[LIndex].Failed := False;
    platform_thread_spawn(LThreads[LIndex], @HeapThreadProc, @LThreadData[LIndex]);
  end;
  LStartFlag := 1;
  for LIndex := 0 to High(LThreads) do
    platform_thread_wait(LThreads[LIndex]);
  for LIndex := 0 to High(LThreads) do
    Check(not LThreadData[LIndex].Failed, 'heap worker should not fail');
end;

procedure TestDualTrackSeparation;
var
  LHeap: TGrowingAllocator;
  LAlloc: IAllocator;
  LPtr: Pointer;
begin
  LHeap := DefaultHeap;
  LAlloc := DefaultAllocator;
  Check(LHeap <> nil, 'heap present');
  Check(LAlloc <> nil, 'allocator present');
  Check(LAlloc = GetGrowingIAllocator, 'DefaultAllocator is Growing IAllocator root');
  Check(LAlloc <> GetRtlAllocator, 'DefaultAllocator is not RTL');
  { Plugin path still works independently (vtable surface). }
  LPtr := LAlloc.GetMem(64);
  Check(LPtr <> nil, 'DefaultAllocator.GetMem');
  LAlloc.FreeMem(LPtr);
  LPtr := LHeap.GetMem(64);
  Check(LPtr <> nil, 'DefaultHeap.GetMem');
  LHeap.FreeMem(LPtr, 64);
end;

procedure TestSameHeapPluginAndHot;
var
  LHeap: TGrowingAllocator;
  LAlloc: IAllocator;
  LPtr: Pointer;
  LSz: SizeUInt;
begin
  LHeap := DefaultHeap;
  LAlloc := DefaultAllocator;
  { Alloc via plugin, free via hot FreeMem(ptr) — same Growing heap. }
  LPtr := LAlloc.GetMem(48);
  Check(LPtr <> nil, 'plugin GetMem');
  Check(LHeap.TryBlockSize(LPtr, LSz), 'block owned by DefaultHeap');
  Check(LSz >= 48, 'size class covers request');
  LHeap.FreeMem(LPtr);

  { Alloc via hot, free via plugin FreeMem(ptr). }
  LPtr := LHeap.GetMem(24);
  Check(LPtr <> nil, 'heap GetMem');
  LAlloc.FreeMem(LPtr);
  Check(True, 'cross free both directions');
end;

procedure TestResolveAllocatorUsesProcessHeap;
var
  LNil, LExpl: IAllocator;
begin
  LNil := ResolveAllocator(nil);
  Check(LNil = GetGrowingIAllocator, 'ResolveAllocator(nil) → Growing root');
  LExpl := GetRtlAllocator;
  Check(ResolveAllocator(LExpl) = LExpl, 'ResolveAllocator identity for explicit');
end;

begin
  T := TTestSuite.Create('nextpas.core.mem.default_allocator');
  T.Test('IAllocator singleton single-thread', @TestDefaultAllocatorSingletonSingleThread);
  T.Test('IAllocator concurrent start same instance', @TestDefaultAllocatorConcurrentStart);
  T.Test('DefaultHeap singleton', @TestDefaultHeapSingleton);
  T.Test('process GetMem uses DefaultHeap', @TestProcessGetMemUsesHeap);
  T.Test('DefaultHeap concurrent', @TestDefaultHeapConcurrent);
  T.Test('dual-track separation', @TestDualTrackSeparation);
  T.Test('same heap plugin and hot', @TestSameHeapPluginAndHot);
  T.Test('ResolveAllocator process heap', @TestResolveAllocatorUsesProcessHeap);
  LRunPassed := T.Run;

  T.Summary;
  if not LRunPassed then
    Halt(1);
end.
