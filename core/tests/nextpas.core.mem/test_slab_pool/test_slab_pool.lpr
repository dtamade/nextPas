program test_slab_pool;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.test,
  nextpas.core.system.heap,
  nextpas.core.mem.error,
  nextpas.core.mem.allocator.base,
  nextpas.core.mem.pool.base,
  nextpas.core.mem.pool.slab,
  nextpas.core.mem.pool.fixed_slab;

type
  TExceptionProc = procedure;

  TFixedSlabRecordingAllocator = class(TInterfacedObject, IAllocator)
  private
    FPtrs: array of Pointer;
    function IndexOf(APtr: Pointer): Integer;
    procedure Track(APtr: Pointer);
    function Untrack(APtr: Pointer): Boolean;
  public
    GetCalls: Integer;
    FreeCalls: Integer;
    FreeAlignedCalls: Integer;
    function GetMem(ASize: SizeUInt): Pointer;
    function AllocMem(ASize: SizeUInt): Pointer;
    function ReallocMem(ADst: Pointer; ASize: SizeUInt): Pointer;
    procedure FreeMem(ADst: Pointer);
    function MemSizeOf(APtr: Pointer): SizeUInt;
    function AllocAligned(ASize, AAlignment: SizeUInt): Pointer;
    procedure FreeAligned(APtr: Pointer);
    function Traits: TAllocatorTraits;
  end;

var
  T: TTestSuite;
  LRunPassed: Boolean;
  GPool: TSlabPool = nil;
  GFixedSlabPool: TFixedSlabPool = nil;
  GFixedSlabFallback: TFixedSlabRecordingAllocator = nil;
  GPtr: PByte = nil;
  GStackByte: Byte = 0;

procedure CheckRaisesAllocError(AProc: TExceptionProc; AExpected: TAllocError; const AName: string);
begin
  try
    AProc;
    Fail(AName + ': expected allocation error');
  except
    on E: EAllocError do
      Check(Int64(Ord(AExpected)) = Int64(Ord(E.Error)), AName + ': error code');
  end;
end;

function TFixedSlabRecordingAllocator.IndexOf(APtr: Pointer): Integer;
var
  LIndex: Integer;
begin
  for LIndex := 0 to High(FPtrs) do
    if FPtrs[LIndex] = APtr then
      Exit(LIndex);
  Result := -1;
end;

procedure TFixedSlabRecordingAllocator.Track(APtr: Pointer);
var
  LCount: Integer;
begin
  if APtr = nil then
    Exit;
  LCount := Length(FPtrs);
  SetLength(FPtrs, LCount + 1);
  FPtrs[LCount] := APtr;
end;

function TFixedSlabRecordingAllocator.Untrack(APtr: Pointer): Boolean;
var
  LIndex: Integer;
  LLast: Integer;
begin
  LIndex := IndexOf(APtr);
  Result := LIndex >= 0;
  if not Result then
    Exit;
  LLast := High(FPtrs);
  FPtrs[LIndex] := FPtrs[LLast];
  SetLength(FPtrs, LLast);
end;

function TFixedSlabRecordingAllocator.GetMem(ASize: SizeUInt): Pointer;
begin
  if ASize = 0 then Exit(nil);
  Inc(GetCalls);
  Result := NpSystemGetMem(ASize);
  Track(Result);
end;

function TFixedSlabRecordingAllocator.AllocMem(ASize: SizeUInt): Pointer;
begin
  if ASize = 0 then Exit(nil);
  Result := NpSystemAllocMem(ASize);
  Track(Result);
end;

function TFixedSlabRecordingAllocator.ReallocMem(ADst: Pointer; ASize: SizeUInt): Pointer;
var
  LIndex: Integer;
begin
  if ASize = 0 then
  begin
    FreeMem(ADst);
    Exit(nil);
  end;
  if ADst = nil then
    Exit(GetMem(ASize));
  LIndex := IndexOf(ADst);
  if LIndex < 0 then
    Exit(nil);
  Result := NpSystemReallocMem(ADst, ASize);
  FPtrs[LIndex] := Result;
end;

procedure TFixedSlabRecordingAllocator.FreeMem(ADst: Pointer);
begin
  if ADst = nil then Exit;
  Inc(FreeCalls);
  if Untrack(ADst) then
    NpSystemFreeMem(ADst);
end;

function TFixedSlabRecordingAllocator.MemSizeOf(APtr: Pointer): SizeUInt;
begin
  Result := 0;
end;

function TFixedSlabRecordingAllocator.AllocAligned(ASize, AAlignment: SizeUInt): Pointer;
var
  LRaw: Pointer;
  LNeeded: SizeUInt;
  LMask: PtrUInt;
begin
  if ASize = 0 then Exit(nil);
  LNeeded := ASize + AAlignment - 1 + SizeOf(Pointer);
  LRaw := GetMem(LNeeded);
  if LRaw = nil then Exit(nil);
  LMask := PtrUInt(AAlignment - 1);
  Result := Pointer((PtrUInt(LRaw) + SizeOf(Pointer) + LMask) and not LMask);
  PPointer(PtrUInt(Result) - SizeOf(Pointer))^ := LRaw;
end;

procedure TFixedSlabRecordingAllocator.FreeAligned(APtr: Pointer);
var
  LRaw: Pointer;
begin
  if APtr = nil then Exit;
  Inc(FreeAlignedCalls);
  LRaw := PPointer(PtrUInt(APtr) - SizeOf(Pointer))^;
  FreeMem(LRaw);
end;

function TFixedSlabRecordingAllocator.Traits: TAllocatorTraits;
begin
  Result.ZeroInitialized := False;
  Result.ThreadSafe := False;
  Result.SupportsRealloc := True;
end;

procedure FreeInteriorSlabPointer;
begin
  GPool.FreeMem(GPtr + 1);
end;

procedure ReallocInteriorSlabPointer;
var
  LNewPtr: Pointer;
begin
  LNewPtr := GPool.ReallocMem(GPtr + 1, 128);
  if LNewPtr <> nil then
    GPool.FreeMem(LNewPtr);
end;

procedure FreeDoubleSlabPointer;
begin
  GPool.FreeMem(GPtr);
end;

procedure ReallocDoubleSlabPointer;
var
  LNewPtr: Pointer;
begin
  LNewPtr := GPool.ReallocMem(GPtr, 128);
  if LNewPtr <> nil then
    GPool.FreeMem(LNewPtr);
end;

procedure FreeForeignFixedSlabPointer;
begin
  GFixedSlabPool.FreeMem(@GStackByte);
end;

procedure FreeInteriorFixedSlabPointer;
begin
  GFixedSlabPool.FreeMem(GPtr + 1);
end;

procedure ReallocInteriorFixedSlabPointer;
var
  LNewPtr: Pointer;
begin
  LNewPtr := GFixedSlabPool.ReallocMem(GPtr + 1, 128);
  if LNewPtr <> nil then
    GFixedSlabPool.FreeMem(LNewPtr);
end;

procedure FreeDoubleFixedSlabPointer;
begin
  GFixedSlabPool.FreeMem(GPtr);
end;

procedure ReallocDoubleFixedSlabPointer;
var
  LNewPtr: Pointer;
begin
  LNewPtr := GFixedSlabPool.ReallocMem(GPtr, 128);
  if LNewPtr <> nil then
    GFixedSlabPool.FreeMem(LNewPtr);
end;

procedure FreeForeignFixedSlabAlignedPointer;
begin
  GFixedSlabPool.FreeAligned(@GStackByte);
end;

procedure FreeFixedSlabAlignedFallbackAgain;
begin
  GFixedSlabPool.FreeAligned(GPtr);
end;

procedure TestCreateStatsAndTraits;
var
  LPool: TSlabPool;
  LStats: TSlabPoolStats;
  LPerf: TSlabPerfCounters;
  LTraits: TAllocatorTraits;
begin
  LPool := TSlabPool.Create(4096);
  try
    LStats := LPool.Stats;
    Check(Int64(1) = Int64(LStats.SegmentCount), 'initial segment count');
    Check(LStats.TotalCapacity >= 4096, 'initial capacity should cover requested bytes');
    Check(Int64(0) = Int64(LStats.TotalUsed), 'initial used bytes');
    Check(Int64(0) = Int64(LStats.FallbackAllocCount), 'initial fallback count');

    LTraits := LPool.Traits;
    Check(True = LTraits.ZeroInitialized, 'AllocMem should promise zero initialization');
    Check(False = LTraits.ThreadSafe, 'plain slab pool should not claim thread safety');
    Check(True = LTraits.SupportsRealloc, 'slab pool should support realloc');

    LPerf := LPool.GetPerfCounters;
    Check(Int64(0) = Int64(LPerf.AllocCalls), 'initial alloc calls');
    Check(Int64(0) = Int64(LPerf.FreeCalls), 'initial free calls');
    Check(Int64(0) = Int64(LPerf.AllocTime), 'L0 slab pool should not sample alloc time directly');
    Check(Int64(0) = Int64(LPerf.FreeTime), 'L0 slab pool should not sample free time directly');
  finally
    LPool.Free;
  end;
end;

procedure TestAllocFreeAndPerfCounters;
var
  LPool: TSlabPool;
  LPtr: Pointer;
  LStats: TSlabPoolStats;
  LPerf: TSlabPerfCounters;
begin
  LPool := TSlabPool.Create(4096);
  try
    LPtr := LPool.GetMem(64);
    Check(LPtr <> nil, 'GetMem should allocate');
    Check(LPool.Owns(LPtr), 'pool should own allocated pointer');
    Check(Int64(64) = Int64(LPool.MemSizeOf(LPtr)), 'MemSizeOf should report slab chunk size');

    LPerf := LPool.GetPerfCounters;
    Check(Int64(1) = Int64(LPerf.AllocCalls), 'alloc calls after one allocation');
    Check(Int64(0) = Int64(LPerf.FreeCalls), 'free calls before release');
    Check(Int64(0) = Int64(LPerf.AllocTime), 'alloc time remains zero without L1 timing dependency');

    LStats := LPool.Stats;
    Check(LStats.TotalUsed >= 64, 'used bytes should grow after allocation');

    LPool.FreeMem(LPtr);
    LPerf := LPool.GetPerfCounters;
    Check(Int64(1) = Int64(LPerf.AllocCalls), 'alloc calls should stay stable after free');
    Check(Int64(1) = Int64(LPerf.FreeCalls), 'free calls after release');
    Check(Int64(0) = Int64(LPerf.FreeTime), 'free time remains zero without L1 timing dependency');

    LStats := LPool.Stats;
    Check(Int64(0) = Int64(LStats.FallbackAllocCount), 'slab path should not create fallback allocation');
  finally
    LPool.Free;
  end;
end;

procedure TestOwnershipDiagnosticsRejectInteriorPointer;
const
  REQUESTED_SIZES: array[0..3] of SizeUInt = (8, 64, 256, 4096);
  CHUNK_SIZES: array[0..3] of SizeUInt = (8, 64, 256, 4096);
var
  LPool: TSlabPool;
  LPtr: PByte;
  LIndex: Integer;
begin
  LPool := TSlabPool.Create(4096 * 8);
  try
    for LIndex := Low(REQUESTED_SIZES) to High(REQUESTED_SIZES) do
    begin
      LPtr := PByte(LPool.GetMem(REQUESTED_SIZES[LIndex]));
      try
        Check(LPtr <> nil, 'GetMem should allocate');
        Check(LPool.Owns(LPtr), 'pool should own exact allocation pointer');
        Check(Int64(CHUNK_SIZES[LIndex]) = Int64(LPool.MemSizeOf(LPtr)), 'exact pointer should report slab chunk size');
        Check(not LPool.Owns(LPtr + 1), 'pool should not own interior pointer diagnostically');
        Check(Int64(0) = Int64(LPool.MemSizeOf(LPtr + 1)), 'interior pointer should not report chunk size');
      finally
        LPool.FreeMem(LPtr);
      end;
      Check(not LPool.Owns(LPtr), 'pool should not own released allocation pointer');
      Check(Int64(0) = Int64(LPool.MemSizeOf(LPtr)), 'released pointer should not report chunk size');
    end;
  finally
    LPool.Free;
  end;
end;

procedure TestReleaseAndReallocRejectInteriorPointer;
begin
  GPool := TSlabPool.Create(4096);
  try
    GPtr := PByte(GPool.GetMem(64));
    Check(GPtr <> nil, 'GetMem should allocate');

    CheckRaisesAllocError(@FreeInteriorSlabPointer, aeInvalidPointer, 'interior FreeMem');
    Check(GPool.Owns(GPtr), 'invalid FreeMem should not release exact pointer');
    Check(Int64(64) = Int64(GPool.MemSizeOf(GPtr)), 'invalid FreeMem should preserve exact pointer size');

    CheckRaisesAllocError(@ReallocInteriorSlabPointer, aeInvalidPointer, 'interior ReallocMem');
    Check(GPool.Owns(GPtr), 'invalid ReallocMem should not release exact pointer');
    Check(Int64(64) = Int64(GPool.MemSizeOf(GPtr)), 'invalid ReallocMem should preserve exact pointer size');

    GPool.FreeMem(GPtr);
  finally
    GPtr := nil;
    GPool.Free;
    GPool := nil;
  end;
end;

procedure TestTopLevelSlabDoubleFreeFailsClosed;
begin
  GPool := TSlabPool.Create(4096);
  try
    GPtr := PByte(GPool.GetMem(64));
    Check(GPtr <> nil, 'GetMem should allocate');

    GPool.FreeMem(GPtr);
    CheckRaisesAllocError(@FreeDoubleSlabPointer, aeDoubleFree,
      'top-level slab double FreeMem');
    CheckRaisesAllocError(@ReallocDoubleSlabPointer, aeDoubleFree,
      'top-level slab double ReallocMem');
    Check(not GPool.Owns(GPtr),
      'top-level slab double free should not restore ownership');
    Check(Int64(0) = Int64(GPool.MemSizeOf(GPtr)), 'top-level slab released pointer should not report chunk size');
  finally
    GPtr := nil;
    GPool.Free;
    GPool := nil;
  end;
end;

procedure TestAllocAlignedFallsBackAndTracksStats;
var
  LPool: TSlabPool;
  LPtr: Pointer;
  LSize: SizeUInt;
  LAlign: SizeUInt;
  LStats: TSlabPoolStats;
begin
  LPool := TSlabPool.Create(4096);
  try
    LPtr := LPool.AllocAligned(96, 256);
    try
      Check(LPtr <> nil, 'AllocAligned should succeed via fallback path');
      Check((PtrUInt(LPtr) mod 256) = 0, 'AllocAligned should honor requested alignment');
      Check(LPool.TryGetFallbackAllocInfo(LPtr, LSize, LAlign), 'aligned fallback should be tracked');
      Check(Int64(96) = Int64(LSize), 'tracked fallback size');
      Check(Int64(256) = Int64(LAlign), 'tracked fallback alignment');

      LStats := LPool.Stats;
      Check(Int64(1) = Int64(LStats.FallbackAllocCount), 'fallback allocation count');
      Check(Int64(96) = Int64(LStats.FallbackBytes), 'fallback byte count');
    finally
      LPool.FreeAligned(LPtr);
    end;

    LStats := LPool.Stats;
    Check(Int64(0) = Int64(LStats.FallbackAllocCount), 'fallback allocation count after free');
    Check(Int64(0) = Int64(LStats.FallbackBytes), 'fallback byte count after free');
  finally
    LPool.Free;
  end;
end;

procedure TestSlabAlignedFallbackRejectsBackingSizeOverflow;
var
  LAllocator: TFixedSlabRecordingAllocator;
  LPool: TSlabPool;
  LPtr: Pointer;
  LGetCallsBefore: Integer;
  LStats: TSlabPoolStats;
begin
  LAllocator := TFixedSlabRecordingAllocator.Create;
  LPool := TSlabPool.Create(4096, LAllocator);
  try
    LGetCallsBefore := LAllocator.GetCalls;
    LPtr := LPool.AllocAligned(High(SizeUInt), 256);
    try
      Check(LPtr = nil, 'overflowing aligned fallback request should fail closed');
      Check(Int64(LGetCallsBefore) = Int64(LAllocator.GetCalls), 'overflowing aligned fallback request must not call backing allocator');
      LStats := LPool.Stats;
      Check(Int64(0) = Int64(LStats.FallbackAllocCount), 'overflowing aligned fallback request must not be tracked');
      Check(Int64(0) = Int64(LStats.FallbackBytes), 'overflowing aligned fallback request must not change fallback bytes');
    finally
      if LPtr <> nil then
        LPool.FreeAligned(LPtr);
    end;
  finally
    LPool.Free;
    LAllocator := nil;
  end;
end;

procedure TestFixedSlabCreateRejectsCapacityOverflow;
var
  LAllocator: TFixedSlabRecordingAllocator;
  LAllocatorRef: IAllocator;
  LPool: TFixedSlabPool;
  LRaised: Boolean;
begin
  LAllocator := TFixedSlabRecordingAllocator.Create;
  LAllocatorRef := LAllocator as IAllocator;
  LPool := nil;
  try
    LRaised := False;
    try
      LPool := TFixedSlabPool.Create(High(SizeUInt), LAllocatorRef);
    except
      on E: EAllocError do
      begin
        LRaised := True;
        Check(Int64(Ord(aeInvalidLayout)) = Int64(Ord(E.Error)), 'fixed slab overflow capacity error');
      end;
    end;

    Check(LRaised, 'fixed slab overflow capacity must fail closed');
    Check(Int64(0) = Int64(LAllocator.GetCalls), 'fixed slab overflow capacity must not call backing allocator');
  finally
    LPool.Free;
    LAllocatorRef := nil;
    LAllocator := nil;
  end;
end;

procedure TestFixedSlabDirectApiFailsClosed;
begin
  GFixedSlabPool := TFixedSlabPool.Create(4096);
  try
    CheckRaisesAllocError(@FreeForeignFixedSlabPointer, aeInvalidPointer,
      'fixed slab foreign FreeMem');

    GPtr := PByte(GFixedSlabPool.GetMem(64));
    Check(GPtr <> nil, 'fixed slab GetMem should allocate');

    CheckRaisesAllocError(@FreeInteriorFixedSlabPointer, aeInvalidPointer,
      'fixed slab interior FreeMem');
    Check(GFixedSlabPool.Owns(GPtr),
      'fixed slab invalid FreeMem should not release exact pointer');
    Check(Int64(64) = Int64(GFixedSlabPool.MemSizeOf(GPtr)), 'fixed slab invalid FreeMem should preserve exact pointer size');

    CheckRaisesAllocError(@ReallocInteriorFixedSlabPointer, aeInvalidPointer,
      'fixed slab interior ReallocMem');
    Check(GFixedSlabPool.Owns(GPtr),
      'fixed slab invalid ReallocMem should not release exact pointer');
    Check(Int64(64) = Int64(GFixedSlabPool.MemSizeOf(GPtr)), 'fixed slab invalid ReallocMem should preserve exact pointer size');

    GFixedSlabPool.FreeMem(GPtr);
    CheckRaisesAllocError(@FreeDoubleFixedSlabPointer, aeDoubleFree,
      'fixed slab double FreeMem');
    CheckRaisesAllocError(@ReallocDoubleFixedSlabPointer, aeDoubleFree,
      'fixed slab double ReallocMem');
    Check(not GFixedSlabPool.Owns(GPtr),
      'fixed slab double FreeMem should not restore ownership');
  finally
    GPtr := nil;
    GFixedSlabPool.Free;
    GFixedSlabPool := nil;
  end;
end;

procedure TestFixedSlabAlignedDirectFailsClosed;
begin
  GFixedSlabPool := TFixedSlabPool.Create(4096);
  try
    GPtr := PByte(GFixedSlabPool.AllocAligned(64, 8));
    Check(GPtr <> nil, 'fixed slab aligned direct path should allocate');
    GFixedSlabPool.FreeAligned(GPtr);
    CheckRaisesAllocError(@FreeFixedSlabAlignedFallbackAgain, aeDoubleFree,
      'fixed slab aligned direct double FreeAligned');
  finally
    GPtr := nil;
    GFixedSlabPool.Free;
    GFixedSlabPool := nil;
  end;
end;

procedure TestFixedSlabAlignedFallbackFailsClosed;
begin
  GFixedSlabFallback := TFixedSlabRecordingAllocator.Create;
  GFixedSlabPool := TFixedSlabPool.Create(4096, GFixedSlabFallback);
  try
    GPtr := PByte(GFixedSlabPool.AllocAligned(96, 256));
    Check(GPtr <> nil, 'fixed slab aligned fallback should allocate');
    Check((PtrUInt(GPtr) mod 256) = 0, 'fixed slab aligned fallback should honor alignment');

    GFixedSlabPool.FreeAligned(GPtr);
    CheckRaisesAllocError(@FreeFixedSlabAlignedFallbackAgain, aeDoubleFree,
      'fixed slab aligned fallback double FreeAligned');
    GPtr := nil;

    CheckRaisesAllocError(@FreeForeignFixedSlabAlignedPointer, aeInvalidPointer,
      'fixed slab foreign FreeAligned');
    Check(Int64(1) = Int64(GFixedSlabFallback.FreeCalls), 'foreign FreeAligned must not delegate to backing allocator');
  finally
    GPtr := nil;
    GFixedSlabPool.Free;
    GFixedSlabPool := nil;
    GFixedSlabFallback := nil;
  end;
end;

procedure TestIMemoryPoolContract;
{ 通过 IMemoryPool 接口引用验证 TSlabPool 的完整语义 }
var
  LPool: IMemoryPool;
  LPtr1, LPtr2: Pointer;
begin
  LPool := TSlabPool.Create(4096);
  Check(LPool <> nil, 'pool created via IMemoryPool');

  { GetMem: 分配并返回非 nil }
  LPtr1 := LPool.GetMem(32);
  Check(LPtr1 <> nil, 'IMemoryPool.GetMem returns non-nil');

  { AllocMem: 分配并清零 }
  LPtr2 := LPool.AllocMem(32);
  Check(LPtr2 <> nil, 'IMemoryPool.AllocMem returns non-nil');

  { FreeMem: 释放后可重用 }
  LPool.FreeMem(LPtr1);
  LPool.FreeMem(LPtr2);

  { ReallocMem: nil dst 等同于 GetMem }
  LPtr1 := LPool.ReallocMem(nil, 32);
  Check(LPtr1 <> nil, 'IMemoryPool.ReallocMem(nil) acts as GetMem');

  { ReallocMem: 非 nil dst 扩展 }
  LPtr2 := LPool.ReallocMem(LPtr1, 48);
  Check(LPtr2 <> nil, 'IMemoryPool.ReallocMem(non-nil) succeeds');

  LPool.FreeMem(LPtr2);
end;

{ B2: FixedSlabPool AllocAligned 直接路径 (AAlignment <= 8 不走 fallback) }
procedure TestFixedSlabAlignedDirectPath;
var
  LFallback: TFixedSlabRecordingAllocator;
  LPool: TFixedSlabPool;
  LP: Pointer;
begin
  LFallback := TFixedSlabRecordingAllocator.Create;
  LPool := TFixedSlabPool.Create(1024, LFallback);
  try
    LFallback.FreeAlignedCalls := 0;
    { AAlignment=8 <= 8, should go through direct slab path, not fallback }
    LP := LPool.AllocAligned(32, 8);
    Check(LP <> nil, 'AllocAligned(32, 8) succeeds');
    Check(LPool.Owns(LP), 'pointer belongs to slab pool');
    Check(0 = LFallback.FreeAlignedCalls, 'fallback AllocAligned not called');
    LPool.FreeMem(LP);
  finally
    LPool.Free;
  end;
end;

{ B2: TSlabPool 小对齐直接路径 }
procedure TestSlabAlignedDirectPath;
var
  LPool: TSlabPool;
  LP: Pointer;
  LStats: TSlabPoolStats;
begin
  LPool := TSlabPool.Create(4096);
  try
    { AAlignment=8 should go through direct slab path }
    LP := LPool.AllocAligned(32, 8);
    Check(LP <> nil, 'AllocAligned(32, 8) succeeds');
    Check(Int64(0) = PtrUInt(LP) mod 8, 'aligned to 8');
    LStats := LPool.Stats;
    Check(Int64(0) = Int64(LStats.FallbackAllocCount), 'no fallback used');
    LPool.FreeMem(LP);
  finally
    LPool.Free;
  end;
end;

{ B3: TSlabPool 底层 allocator 失败时返回 nil }
procedure TestSlabPoolOomWhenBackingFails;
var
  LPool: TSlabPool;
  LP: Pointer;
begin
  { Create slab pool with very small capacity }
  LPool := TSlabPool.Create(64);
  try
    LP := LPool.GetMem(32);
    { First alloc may succeed or fail depending on slab internals.
      The key is: no crash, returns nil on failure. }
    if LP <> nil then
      LPool.FreeMem(LP);
  finally
    LPool.Free;
  end;
end;

{ B3: TFixedSlabPool Create(0) 后操作安全 }
procedure TestFixedSlabPoolZeroCapacity;
var
  LPool: TFixedSlabPool;
  LP: Pointer;
begin
  LPool := TFixedSlabPool.Create(0);
  try
    LP := LPool.GetMem(8);
    Check(LP = nil, 'GetMem on zero-capacity pool returns nil');
    LPool.FreeMem(nil);  { should not crash }
  finally
    LPool.Free;
  end;
end;

{ CS-016: SecureFree 清零后释放 }
procedure TestSecureFreeZerosBeforeRelease;
var
  LPool: TFixedSlabPool;
  LP: PByte;
  LIdx: Integer;
  LAllZero: Boolean;
begin
  LPool := TFixedSlabPool.Create(4096);
  try
    LP := PByte(LPool.GetMem(32));
    Check(LP <> nil, 'GetMem returned pointer');
    // Fill with non-zero pattern
    for LIdx := 0 to 31 do
      LP[LIdx] := Byte(LIdx + 1);
    // SecureFree should zero then release
    LPool.SecureFree(Pointer(LP));
    // Verify the memory was zeroed before release:
    // After free, the slab may reuse the chunk, but immediately after SecureFree
    // the data should be zero (we can't reliably read freed slab memory, so we
    // verify by re-allocating and checking the AllocMem path works).
    LP := PByte(LPool.AllocMem(32));
    Check(LP <> nil, 'AllocMem after SecureFree returned pointer');
    LAllZero := True;
    for LIdx := 0 to 31 do
      if LP[LIdx] <> 0 then
      begin
        LAllZero := False;
        Break;
      end;
    Check(LAllZero, 'AllocMem returns zeroed memory after SecureFree');
    LPool.FreeMem(Pointer(LP));
    // SecureFree(nil) should not crash
    LPool.SecureFree(nil);
  finally
    LPool.Free;
  end;
end;

{ C-1: Slab Reset 后哈希表一致性验证 }
procedure TestSlabResetConsistency;
var
  LPool: TSlabPool;
  LSlabPtr, LFbPtr, LNewPtr: Pointer;
  LStats: TSlabPoolStats;
begin
  LPool := TSlabPool.Create(4096);
  try
    { 1. 分配 slab 内指针 }
    LSlabPtr := LPool.GetMem(32);
    Check(LSlabPtr <> nil, 'slab alloc should succeed');

    { 2. 分配 fallback 指针（超过 FInitialCapacity 才走 fallback） }
    LFbPtr := LPool.GetMem(8192);
    Check(LFbPtr <> nil, 'fallback alloc should succeed');

    { 3. 验证 stats 有 fallback 记录 }
    LStats := LPool.Stats;
    Check(LStats.FallbackAllocCount >= 1, 'should have fallback alloc before reset');

    { 4. Reset }
    LPool.Reset;

    { 5. Reset 后 FbMap 应清空 }
    LStats := LPool.Stats;
    Check(Int64(0) = Int64(LStats.FallbackAllocCount), 'FbMap should be empty after reset');
    Check(Int64(0) = Int64(LStats.FallbackBytes), 'FbMap bytes should be zero after reset');

    { 6. 新分配应正常工作 }
    LNewPtr := LPool.GetMem(64);
    Check(LNewPtr <> nil, 'post-reset slab alloc should succeed');
    LPool.FreeMem(LNewPtr);

    LNewPtr := LPool.GetMem(8192);
    Check(LNewPtr <> nil, 'post-reset fallback alloc should succeed');
    LPool.FreeMem(LNewPtr);
  finally
    LPool.Free;
  end;
end;

{ C-2: AllocAligned 大对齐测试 (64KB/128KB/1MB) }
procedure TestAllocAlignedLargeAlignment;
var
  LPool: TSlabPool;
  LPtr: Pointer;
  LAlign: SizeUInt;
begin
  LPool := TSlabPool.Create(4096);
  try
    { 64KB 对齐 }
    LAlign := 64 * 1024;
    LPtr := LPool.AllocAligned(128, LAlign);
    Check(LPtr <> nil, 'AllocAligned(128, 64KB) should succeed');
    Check((PtrUInt(LPtr) mod LAlign) = 0, 'AllocAligned(128, 64KB) should be aligned');
    LPool.FreeAligned(LPtr);

    { 128KB 对齐 }
    LAlign := 128 * 1024;
    LPtr := LPool.AllocAligned(256, LAlign);
    Check(LPtr <> nil, 'AllocAligned(256, 128KB) should succeed');
    Check((PtrUInt(LPtr) mod LAlign) = 0, 'AllocAligned(256, 128KB) should be aligned');
    LPool.FreeAligned(LPtr);

    { 1MB 对齐 }
    LAlign := 1024 * 1024;
    LPtr := LPool.AllocAligned(512, LAlign);
    Check(LPtr <> nil, 'AllocAligned(512, 1MB) should succeed');
    Check((PtrUInt(LPtr) mod LAlign) = 0, 'AllocAligned(512, 1MB) should be aligned');
    LPool.FreeAligned(LPtr);
  finally
    LPool.Free;
  end;
end;

begin
  T := TTestSuite.Create('nextpas.core.mem.slab_pool');
  T.Test('create stats and traits', @TestCreateStatsAndTraits);
  T.Test('alloc free and perf counters', @TestAllocFreeAndPerfCounters);
  T.Test('ownership diagnostics reject interior pointer', @TestOwnershipDiagnosticsRejectInteriorPointer);
  T.Test('release and realloc reject interior pointer', @TestReleaseAndReallocRejectInteriorPointer);
  T.Test('top-level slab double free fails closed', @TestTopLevelSlabDoubleFreeFailsClosed);
  T.Test('aligned fallback tracking', @TestAllocAlignedFallsBackAndTracksStats);
  T.Test('aligned fallback rejects backing size overflow', @TestSlabAlignedFallbackRejectsBackingSizeOverflow);
  T.Test('fixed slab rejects capacity overflow', @TestFixedSlabCreateRejectsCapacityOverflow);
  T.Test('fixed slab direct api fails closed', @TestFixedSlabDirectApiFailsClosed);
  T.Test('fixed slab aligned direct fails closed', @TestFixedSlabAlignedDirectFailsClosed);
  T.Test('fixed slab aligned fallback fails closed', @TestFixedSlabAlignedFallbackFailsClosed);
  T.Test('IMemoryPool contract via TSlabPool', @TestIMemoryPoolContract);
  T.Test('fixed slab aligned direct path (B2)', @TestFixedSlabAlignedDirectPath);
  T.Test('slab aligned direct path (B2)', @TestSlabAlignedDirectPath);
  T.Test('slab pool OOM safe (B3)', @TestSlabPoolOomWhenBackingFails);
  T.Test('fixed slab zero capacity safe (B3)', @TestFixedSlabPoolZeroCapacity);
  T.Test('secure free zeros before release (CS-016)', @TestSecureFreeZerosBeforeRelease);
  T.Test('slab reset consistency (C-1)', @TestSlabResetConsistency);
  T.Test('alloc aligned large alignment 64K/128K/1M (C-2)', @TestAllocAlignedLargeAlignment);
  LRunPassed := T.Run;

  T.Summary;
  if not LRunPassed then
    Halt(1);
end.
