program test_contract_matrix;
{**
 * Contract Conformance Matrix (STDLIB-QUALITY-PLAN §5)
 *
 * Shared cases C01–C12 for Tier-0 surfaces:
 *   - IAllocator: RTL (full matrix), TFixedSlabPool (C01–C05/C07/C10)
 *   - TGrowingAllocator / DefaultHeap: native API (adapted)
 *   - TLocalArena / TChunkedArena: C11–C12 (+ Alloc(0))
 *   - TLocalBlockPool: Release(nil) no-op + double-free raises
 *
 * Fail injection (C06) and SupportsRealloc=False (C09) use Tier-1/0 wrappers.
 *}

{$I nextpas.core.settings.inc}

uses
  nextpas.core.thread.init,
  nextpas.core.platform.thread,
  nextpas.core.base,
  nextpas.core.atomic.core,
  nextpas.core.test,
  nextpas.core.mem.intf,
  nextpas.core.mem.error,
  nextpas.core.mem.default,
  nextpas.core.mem.allocator.rtl,
  nextpas.core.mem.allocator.growing,
  nextpas.core.mem.allocator.fail,
  nextpas.core.mem.allocator.arena,
  nextpas.core.mem.allocator.tracking,
  nextpas.core.mem.arena.base,
  nextpas.core.mem.arena.intf,
  nextpas.core.mem.arena.local,
  nextpas.core.mem.arena.chunked,
  nextpas.core.mem.pool,
  nextpas.core.mem.pool.fixed_slab;

var
  T: TTestSuite;
  LRunPassed: Boolean;

{ --- helpers --- }

function IsAligned(APtr: Pointer; AAlign: SizeUInt): Boolean;
begin
  if (APtr = nil) or (AAlign = 0) then
    Exit(False);
  Result := (PtrUInt(APtr) and (AAlign - 1)) = 0;
end;

procedure CheckAllZero(APtr: Pointer; ASize: SizeUInt; const AMsg: string);
var
  I: SizeUInt;
  LBytes: PByte;
begin
  LBytes := PByte(APtr);
  for I := 0 to ASize - 1 do
    if LBytes[I] <> 0 then
    begin
      Check(False, AMsg);
      Exit;
    end;
  Check(True, AMsg);
end;

{ --- C01–C05 / C07 / C10 on IAllocator --- }

procedure RunIAllocatorNilZeroContracts(const AAlloc: IAllocator; const AName: string);
var
  LPtr: Pointer;
  LInt: PInteger;
begin
  Check(AAlloc.GetMem(0) = nil, AName + ' C01 GetMem(0)=nil');
  Check(AAlloc.AllocMem(0) = nil, AName + ' C01 AllocMem(0)=nil');

  AAlloc.FreeMem(nil);
  Check(True, AName + ' C02 FreeMem(nil) no-op');

  LPtr := AAlloc.ReallocMem(nil, 64);
  Check(LPtr <> nil, AName + ' C03 ReallocMem(nil,n) allocates');
  LInt := PInteger(LPtr);
  LInt^ := 42;
  Check(LInt^ = 42, AName + ' C03 write survives');
  LPtr := AAlloc.ReallocMem(LPtr, 0);
  Check(LPtr = nil, AName + ' C04 ReallocMem(p,0)=nil');

  Check(AAlloc.ReallocMem(nil, 0) = nil, AName + ' C05 ReallocMem(nil,0)=nil');
end;

procedure RunIAllocatorZeroedAndRoundtrip(const AAlloc: IAllocator; const AName: string);
var
  LTraits: TAllocatorTraits;
  LPtr: Pointer;
  LInt: PInteger;
begin
  LTraits := AAlloc.Traits;
  LPtr := AAlloc.AllocMem(128);
  Check(LPtr <> nil, AName + ' C07 AllocMem non-nil');
  if LTraits.ZeroInitialized then
    CheckAllZero(LPtr, 128, AName + ' C07 AllocMem zero-filled');
  LInt := PInteger(LPtr);
  LInt^ := $11223344;
  Check(LInt^ = $11223344, AName + ' C10 write/read');
  AAlloc.FreeMem(LPtr);
end;

procedure RunIAllocatorOomPreservesPtr(const AInner: IAllocator; const AName: string);
var
  LFail: IAllocator;
  LFailObj: TFailAllocator;
  LPtr, LNew: Pointer;
  LInt: PInteger;
begin
  { Fail on 2nd attempt: GetMem succeeds, ReallocMem fails and returns nil. }
  LFailObj := TFailAllocator.Create(AInner, 2);
  LFail := LFailObj;
  LPtr := LFail.GetMem(64);
  Check(LPtr <> nil, AName + ' C06 GetMem before fail');
  LInt := PInteger(LPtr);
  LInt^ := 99;
  LNew := LFail.ReallocMem(LPtr, 256);
  Check(LNew = nil, AName + ' C06 Realloc OOM returns nil');
  Check(LInt^ = 99, AName + ' C06 original pointer still valid');
  LFail.FreeMem(LPtr);
end;

procedure RunIAllocatorSupportsReallocFalse(const AName: string);
var
  LObj: TVirtualArenaAllocator;
  LAlloc: IAllocator;
  LTraits: TAllocatorTraits;
  LPtr: Pointer;
  LRaised: Boolean;
begin
  LObj := TVirtualArenaAllocator.Create;
  LAlloc := LObj;
  LTraits := LAlloc.Traits;
  Check(not LTraits.SupportsRealloc, AName + ' C09 SupportsRealloc=False');
  LPtr := LAlloc.GetMem(32);
  Check(LPtr <> nil, AName + ' C09 GetMem');
  LRaised := False;
  try
    LAlloc.ReallocMem(LPtr, 64);
  except
    on E: EAllocError do
      LRaised := True;
  end;
  Check(LRaised, AName + ' C09 Realloc raises aeReallocNotSupported path');
  LAlloc.FreeMem(LPtr);
  LObj.Reset;
  LAlloc := nil;
end;

procedure RunIAllocatorLeakFree(const AInner: IAllocator; const AName: string);
var
  LTrack: TTrackingAllocator;
  LAlloc: IAllocator;
  LPtr: Pointer;
  I: Integer;
begin
  LTrack := TTrackingAllocator.Create(AInner);
  LAlloc := LTrack;
  for I := 1 to 16 do
  begin
    LPtr := LAlloc.GetMem(32 + SizeUInt(I));
    Check(LPtr <> nil, AName + ' C10 alloc');
    LAlloc.FreeMem(LPtr);
  end;
  Check(not LTrack.HasLeaks, AName + ' C10 no leaks after free');
end;

{ --- concurrent smoke for ThreadSafe (C08) --- }

const
  C08_THREADS = 4;
  C08_ITERS = 500;

type
  PRtlWorkerCtx = ^TRtlWorkerCtx;
  TRtlWorkerCtx = record
    Alloc: IAllocator;
    Failed: Boolean;
  end;

function RtlWorker(AParam: Pointer): Pointer; cdecl;
var
  LCtx: PRtlWorkerCtx;
  I: Integer;
  LPtr: Pointer;
begin
  Result := nil;
  LCtx := PRtlWorkerCtx(AParam);
  try
    for I := 1 to C08_ITERS do
    begin
      LPtr := LCtx^.Alloc.GetMem(64);
      if LPtr = nil then
      begin
        LCtx^.Failed := True;
        Exit;
      end;
      PInteger(LPtr)^ := I;
      if PInteger(LPtr)^ <> I then
      begin
        LCtx^.Failed := True;
        LCtx^.Alloc.FreeMem(LPtr);
        Exit;
      end;
      LCtx^.Alloc.FreeMem(LPtr);
    end;
  except
    LCtx^.Failed := True;
  end;
end;

procedure RunIAllocatorThreadSafeSmoke(const AAlloc: IAllocator; const AName: string);
var
  LTraits: TAllocatorTraits;
  LIds: array[0..C08_THREADS - 1] of TPlatformThreadRecord;
  LCtx: array[0..C08_THREADS - 1] of TRtlWorkerCtx;
  I: Integer;
  LAnyFail: Boolean;
begin
  LTraits := AAlloc.Traits;
  if not LTraits.ThreadSafe then
  begin
    Check(True, AName + ' C08 N/A (ThreadSafe=False)');
    Exit;
  end;
  for I := 0 to C08_THREADS - 1 do
  begin
    LCtx[I].Alloc := AAlloc;
    LCtx[I].Failed := False;
    Check(platform_thread_spawn(LIds[I], @RtlWorker, @LCtx[I]) = 0,
      'spawn RtlWorker');
  end;
  for I := 0 to C08_THREADS - 1 do
    Check(platform_thread_wait(LIds[I]) = 0, 'join RtlWorker');
  LAnyFail := False;
  for I := 0 to C08_THREADS - 1 do
    if LCtx[I].Failed then
      LAnyFail := True;
  Check(not LAnyFail, AName + ' C08 concurrent GetMem/FreeMem');
end;

{ --- Growing native surface (adapted; not IAllocator) --- }

procedure RunGrowingNilZeroContracts;
var
  LAlloc: TGrowingAllocator;
  LPtr: Pointer;
begin
  LAlloc := TGrowingAllocator.Create;
  try
    Check(LAlloc.GetMem(0) = nil, 'Growing C01 GetMem(0)=nil');
    Check(LAlloc.AllocMem(0) = nil, 'Growing C01 AllocMem(0)=nil');
    LAlloc.FreeMem(nil);
    Check(True, 'Growing C02 FreeMem(nil) no-op');

    LPtr := LAlloc.ReallocMem(nil, 0, 64);
    Check(LPtr <> nil, 'Growing C03 ReallocMem(nil,*,n) allocates');
    PInteger(LPtr)^ := 7;
    Check(PInteger(LPtr)^ = 7, 'Growing C03 write');
    LPtr := LAlloc.ReallocMem(LPtr, 64, 0);
    Check(LPtr = nil, 'Growing C04 ReallocMem(p,*,0)=nil');

    Check(LAlloc.ReallocMem(nil, 0, 0) = nil, 'Growing C05 ReallocMem(nil,*,0)=nil');
  finally
    LAlloc.Free;
  end;
end;

procedure RunGrowingZeroedAndRoundtrip;
var
  LAlloc: TGrowingAllocator;
  LPtr: Pointer;
begin
  LAlloc := TGrowingAllocator.Create;
  try
    LPtr := LAlloc.AllocMem(128);
    Check(LPtr <> nil, 'Growing C07 AllocMem');
    CheckAllZero(LPtr, 128, 'Growing C07 zero-filled');
    PInteger(LPtr)^ := $55AA55AA;
    Check(PInteger(LPtr)^ = $55AA55AA, 'Growing C10 write/read');
    LAlloc.FreeMem(LPtr, 128);
  finally
    LAlloc.Free;
  end;
end;

type
  PGrowWorkerCtx = ^TGrowWorkerCtx;
  TGrowWorkerCtx = record
    Alloc: TGrowingAllocator;
    Failed: Boolean;
  end;

function GrowWorker(AParam: Pointer): Pointer; cdecl;
var
  LCtx: PGrowWorkerCtx;
  I: Integer;
  LPtr: Pointer;
begin
  Result := nil;
  LCtx := PGrowWorkerCtx(AParam);
  try
    for I := 1 to C08_ITERS do
    begin
      LPtr := LCtx^.Alloc.GetMem(64);
      if LPtr = nil then
      begin
        LCtx^.Failed := True;
        Exit;
      end;
      PInteger(LPtr)^ := I;
      if PInteger(LPtr)^ <> I then
      begin
        LCtx^.Failed := True;
        LCtx^.Alloc.FreeMem(LPtr, 64);
        Exit;
      end;
      LCtx^.Alloc.FreeMem(LPtr, 64);
    end;
  except
    LCtx^.Failed := True;
  end;
end;

procedure RunGrowingThreadSafeSmoke;
var
  LAlloc: TGrowingAllocator;
  LIds: array[0..C08_THREADS - 1] of TPlatformThreadRecord;
  LCtx: array[0..C08_THREADS - 1] of TGrowWorkerCtx;
  I: Integer;
  LAnyFail: Boolean;
begin
  LAlloc := TGrowingAllocator.Create;
  try
    for I := 0 to C08_THREADS - 1 do
    begin
      LCtx[I].Alloc := LAlloc;
      LCtx[I].Failed := False;
      Check(platform_thread_spawn(LIds[I], @GrowWorker, @LCtx[I]) = 0,
        'spawn GrowWorker');
    end;
    for I := 0 to C08_THREADS - 1 do
      Check(platform_thread_wait(LIds[I]) = 0, 'join GrowWorker');
    LAnyFail := False;
    for I := 0 to C08_THREADS - 1 do
      if LCtx[I].Failed then
        LAnyFail := True;
    Check(not LAnyFail, 'Growing C08 concurrent GetMem/FreeMem');
  finally
    LAlloc.Free;
  end;
end;

{ --- Arena C11–C12 --- }

procedure RunLocalArenaAlignedAndMark;
var
  LIface: IArena;
  LPtr, LPtr2: Pointer;
  LMark: TArenaMark;
  LUsed: SizeUInt;
begin
  LIface := TLocalArena.Create(64 * 1024);

  LPtr := LIface.AllocAligned(32, 64);
  Check(LPtr <> nil, 'Arena C11 AllocAligned power-of-two');
  Check(IsAligned(LPtr, 64), 'Arena C11 pointer aligned to 64');

  LPtr2 := LIface.AllocAligned(16, 3);
  Check(LPtr2 = nil, 'Arena C11 non-power-of-two returns nil');

  LMark := LIface.SaveMark;
  LUsed := LIface.UsedSize;
  LPtr2 := LIface.Alloc(128);
  Check(LPtr2 <> nil, 'Arena C12 alloc after mark');
  Check(LIface.UsedSize > LUsed, 'Arena C12 used grows');
  LIface.RestoreToMark(LMark);
  Check(LIface.UsedSize = LUsed, 'Arena C12 restore mark');

  LIface.Reset;
  Check(LIface.UsedSize = 0, 'Arena C12 Reset clears used');
  LPtr := LIface.Alloc(64);
  Check(LPtr <> nil, 'Arena C12 alloc after Reset');
  LIface := nil;
end;

{ --- suite entry points --- }

procedure TestRtl_C01_C05;
begin
  RunIAllocatorNilZeroContracts(GetRtlAllocator, 'RTL');
end;

procedure TestRtl_C07_C10;
begin
  RunIAllocatorZeroedAndRoundtrip(GetRtlAllocator, 'RTL');
end;

procedure TestRtl_C06_Oom;
begin
  RunIAllocatorOomPreservesPtr(GetRtlAllocator, 'RTL+Fail');
end;

procedure TestRtl_C08_Concurrent;
begin
  RunIAllocatorThreadSafeSmoke(GetRtlAllocator, 'RTL');
end;

procedure TestRtl_C10_Tracking;
begin
  RunIAllocatorLeakFree(GetRtlAllocator, 'RTL+Track');
end;

procedure TestRtl_Traits;
var
  LTraits: TAllocatorTraits;
begin
  LTraits := GetRtlAllocator.Traits;
  Check(LTraits.ZeroInitialized, 'RTL Traits.ZeroInitialized');
  Check(LTraits.ThreadSafe, 'RTL Traits.ThreadSafe');
  Check(LTraits.SupportsRealloc, 'RTL Traits.SupportsRealloc');
end;

procedure TestC09_SupportsReallocFalse;
begin
  RunIAllocatorSupportsReallocFalse('ArenaAlloc');
end;

procedure TestGrowing_C01_C05;
begin
  RunGrowingNilZeroContracts;
end;

procedure TestGrowing_C07_C10;
begin
  RunGrowingZeroedAndRoundtrip;
end;

procedure TestGrowing_C08;
begin
  RunGrowingThreadSafeSmoke;
end;

procedure TestLocalArena_C11_C12;
begin
  RunLocalArenaAlignedAndMark;
end;

{ --- ChunkedArena C11–C12 + zero-size --- }

procedure RunChunkedArenaContracts;
var
  LIface: IArena;
  LPtr, LPtr2: Pointer;
  LMark: TArenaMark;
  LUsed: SizeUInt;
begin
  LIface := TChunkedArena.Create(4 * 1024, 0);
  Check(LIface.Alloc(0) = nil, 'ChunkedArena Alloc(0)=nil');

  LPtr := LIface.AllocAligned(32, 64);
  Check(LPtr <> nil, 'ChunkedArena C11 AllocAligned');
  Check(IsAligned(LPtr, 64), 'ChunkedArena C11 aligned');
  Check(LIface.AllocAligned(8, 3) = nil, 'ChunkedArena C11 bad align=nil');

  LMark := LIface.SaveMark;
  LUsed := LIface.UsedSize;
  LPtr2 := LIface.Alloc(256);
  Check(LPtr2 <> nil, 'ChunkedArena C12 alloc');
  Check(LIface.UsedSize > LUsed, 'ChunkedArena C12 used grows');
  LIface.RestoreToMark(LMark);
  Check(LIface.UsedSize = LUsed, 'ChunkedArena C12 restore');
  LIface.Reset;
  Check(LIface.UsedSize = 0, 'ChunkedArena C12 Reset');
  LIface := nil;
end;

procedure TestChunkedArena_Contracts;
begin
  RunChunkedArenaContracts;
end;

{ --- FixedSlab as IAllocator (nil/0 + zeroed) --- }

procedure TestFixedSlab_IAllocatorContracts;
var
  LPool: TFixedSlabPool;
  LAlloc: IAllocator;
begin
  LPool := TFixedSlabPool.Create(64 * 1024);
  LAlloc := LPool;
  RunIAllocatorNilZeroContracts(LAlloc, 'FixedSlab');
  RunIAllocatorZeroedAndRoundtrip(LAlloc, 'FixedSlab');
  LAlloc := nil;
end;

{ --- LocalBlockPool release contracts --- }

procedure TestLocalBlockPool_ReleaseContracts;
var
  LPool: TLocalBlockPool;
  LPtr: Pointer;
  LRaised: Boolean;
begin
  LPool := TLocalBlockPool.Create(64, 32);
  try
    LPool.Release(nil);
    Check(True, 'LocalBlockPool Release(nil) no-op');

    LPtr := LPool.Acquire;
    Check(LPtr <> nil, 'LocalBlockPool Acquire');
    LPool.Release(LPtr);

    LRaised := False;
    try
      LPool.Release(LPtr);
    except
      on E: EAllocError do
        LRaised := True;
    end;
    Check(LRaised, 'LocalBlockPool double free raises');
  finally
    LPool.Free;
  end;
end;

{ --- DefaultHeap process path (D1 dual-track hot path) --- }

procedure RunDefaultHeapNilZeroContracts;
var
  LHeap: TGrowingAllocator;
  LPtr: Pointer;
begin
  LHeap := DefaultHeap;
  Check(LHeap <> nil, 'DefaultHeap non-nil');
  Check(LHeap = DefaultGrowingAllocator, 'DefaultHeap alias');

  Check(LHeap.GetMem(0) = nil, 'DefaultHeap C01 GetMem(0)=nil');
  Check(LHeap.AllocMem(0) = nil, 'DefaultHeap C01 AllocMem(0)=nil');
  LHeap.FreeMem(nil);
  Check(True, 'DefaultHeap C02 FreeMem(nil)');

  LPtr := LHeap.ReallocMem(nil, 0, 64);
  Check(LPtr <> nil, 'DefaultHeap C03 ReallocMem(nil,*,n)');
  PInteger(LPtr)^ := 11;
  Check(PInteger(LPtr)^ = 11, 'DefaultHeap C03 write');
  LPtr := LHeap.ReallocMem(LPtr, 64, 0);
  Check(LPtr = nil, 'DefaultHeap C04 ReallocMem(p,*,0)=nil');
  Check(LHeap.ReallocMem(nil, 0, 0) = nil, 'DefaultHeap C05');
end;

procedure RunDefaultHeapZeroedAndSizedFree;
var
  LHeap: TGrowingAllocator;
  LPtr: Pointer;
begin
  LHeap := DefaultHeap;
  LPtr := LHeap.AllocMem(96);
  Check(LPtr <> nil, 'DefaultHeap C07 AllocMem');
  CheckAllZero(LPtr, 96, 'DefaultHeap C07 zero');
  PInteger(LPtr)^ := $CAFEBABE;
  Check(PInteger(LPtr)^ = Integer($CAFEBABE), 'DefaultHeap C10 write');
  LHeap.FreeMem(LPtr, 96);
  { unknown-size free path (span scan) }
  LPtr := LHeap.GetMem(48);
  Check(LPtr <> nil, 'DefaultHeap GetMem for FreeMem(ptr)');
  LHeap.FreeMem(LPtr);
  Check(True, 'DefaultHeap FreeMem(ptr) scan path');
end;

type
  PHeapCrossCtx = ^THeapCrossCtx;
  THeapCrossCtx = record
    Heap: TGrowingAllocator;
    Ptrs: array[0..127] of Pointer;
    Count: Integer;
    Ready: LongInt;
    Error: LongInt;
  end;

function HeapCrossProducer(AParam: Pointer): Pointer; cdecl;
var
  LCtx: PHeapCrossCtx;
  I: Integer;
begin
  LCtx := PHeapCrossCtx(AParam);
  try
    for I := 0 to LCtx^.Count - 1 do
    begin
      LCtx^.Ptrs[I] := LCtx^.Heap.GetMem(64);
      if LCtx^.Ptrs[I] = nil then
      begin
        InterlockedExchange(LCtx^.Error, 1);
        Exit(Pointer(1));
      end;
      PByte(LCtx^.Ptrs[I])^ := Byte(I);
    end;
    ReadWriteBarrier;
    InterlockedExchange(LCtx^.Ready, 1);
    Result := nil;
  except
    InterlockedExchange(LCtx^.Error, 1);
    Result := Pointer(1);
  end;
end;

function HeapCrossConsumer(AParam: Pointer): Pointer; cdecl;
var
  LCtx: PHeapCrossCtx;
  I: Integer;
begin
  LCtx := PHeapCrossCtx(AParam);
  try
    while InterlockedCompareExchange(LCtx^.Ready, 0, 0) = 0 do
      ; { spin until producer fills }
    ReadWriteBarrier;
    for I := 0 to LCtx^.Count - 1 do
    begin
      if (LCtx^.Ptrs[I] = nil) or (PByte(LCtx^.Ptrs[I])^ <> Byte(I)) then
      begin
        InterlockedExchange(LCtx^.Error, 1);
        Exit(Pointer(1));
      end;
      LCtx^.Heap.FreeMem(LCtx^.Ptrs[I], 64);
      LCtx^.Ptrs[I] := nil;
    end;
    Result := nil;
  except
    InterlockedExchange(LCtx^.Error, 1);
    Result := Pointer(1);
  end;
end;

procedure RunDefaultHeapCrossThreadFree;
var
  LCtx: THeapCrossCtx;
  LProd, LCons: TPlatformThreadRecord;
  I: Integer;
begin
  FillChar(LCtx, SizeOf(LCtx), 0);
  LCtx.Heap := DefaultHeap;
  LCtx.Count := 128;
  LCtx.Ready := 0;
  LCtx.Error := 0;
  for I := 0 to LCtx.Count - 1 do
    LCtx.Ptrs[I] := nil;

  Check(platform_thread_spawn(LProd, @HeapCrossProducer, @LCtx) = 0,
    'spawn HeapCrossProducer');
  Check(platform_thread_spawn(LCons, @HeapCrossConsumer, @LCtx) = 0,
    'spawn HeapCrossConsumer');
  Check(platform_thread_wait(LProd) = 0, 'join HeapCrossProducer');
  Check(platform_thread_wait(LCons) = 0, 'join HeapCrossConsumer');
  Check(LCtx.Error = 0, 'DefaultHeap cross-thread free (M2-1)');
end;

procedure TestDefaultHeap_C01_C05;
begin
  RunDefaultHeapNilZeroContracts;
end;

procedure TestDefaultHeap_C07_C10;
begin
  RunDefaultHeapZeroedAndSizedFree;
end;

procedure TestDefaultHeap_CrossThread;
begin
  RunDefaultHeapCrossThreadFree;
end;

procedure TestFormatAllocErrorMsgHelpers;
var
  LMsg: string;
begin
  LMsg := FormatAllocErrorMsg('TLocalArenaAllocator', 'FreeMem',
    'arena block; use Reset (ARENA_STRICT)');
  Check(IsWellFormedAllocErrorMsg(LMsg), 'FormatAllocErrorMsg well-formed');
  Check(LMsg = 'TLocalArenaAllocator.FreeMem: arena block; use Reset (ARENA_STRICT)',
    'FormatAllocErrorMsg exact stem');
  Check(not IsWellFormedAllocErrorMsg('broken'), 'reject non Type.Method form');
end;

procedure TestArenaAllocatorFreeMemDefaultNoOp;
var
  LAlloc: IAllocator;
  LPtr: Pointer;
begin
  { C02-style: default arena FreeMem is no-op (compatible inject path). }
  LAlloc := TLocalArenaAllocator.Create(4096);
  LPtr := LAlloc.GetMem(64);
  Check(LPtr <> nil, 'arena GetMem');
  LAlloc.FreeMem(LPtr);
  LAlloc.FreeMem(nil);
  Check(LPtr <> nil, 'default FreeMem no-op leaves ptr value');
end;

begin
  T := TTestSuite.Create('nextpas.core.mem.contract_matrix');
  T.Test('RTL C01-C05 nil/0', @TestRtl_C01_C05);
  T.Test('RTL Traits', @TestRtl_Traits);
  T.Test('RTL C07/C10 zeroed+roundtrip', @TestRtl_C07_C10);
  T.Test('RTL C06 OOM preserves ptr', @TestRtl_C06_Oom);
  T.Test('RTL C08 concurrent smoke', @TestRtl_C08_Concurrent);
  T.Test('RTL C10 tracking leak-free', @TestRtl_C10_Tracking);
  T.Test('C09 SupportsRealloc=False raises', @TestC09_SupportsReallocFalse);
  T.Test('Growing C01-C05 nil/0 (native)', @TestGrowing_C01_C05);
  T.Test('Growing C07/C10 zeroed+roundtrip', @TestGrowing_C07_C10);
  T.Test('Growing C08 concurrent smoke', @TestGrowing_C08);
  T.Test('DefaultHeap C01-C05 (process path)', @TestDefaultHeap_C01_C05);
  T.Test('DefaultHeap C07/C10 + FreeMem(ptr)', @TestDefaultHeap_C07_C10);
  T.Test('DefaultHeap cross-thread free', @TestDefaultHeap_CrossThread);
  T.Test('LocalArena C11-C12 align+mark', @TestLocalArena_C11_C12);
  T.Test('ChunkedArena Alloc0+C11-C12', @TestChunkedArena_Contracts);
  T.Test('FixedSlab IAllocator C01-C05/C07', @TestFixedSlab_IAllocatorContracts);
  T.Test('LocalBlockPool Release nil+double-free', @TestLocalBlockPool_ReleaseContracts);
  T.Test('FormatAllocErrorMsg helpers', @TestFormatAllocErrorMsgHelpers);
  T.Test('Arena IAllocator FreeMem default no-op', @TestArenaAllocatorFreeMemDefaultNoOp);
  LRunPassed := T.Run;
  T.Summary;
  if not LRunPassed then
    Halt(1);
end.
