program test_slab_pool;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.testing,
  nextpas.core.mem.error,
  nextpas.core.mem.allocator.base,
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
    FreeAlignedCalls: Integer;
    function GetMem(ASize: SizeUInt): Pointer;
    function AllocMem(ASize: SizeUInt): Pointer;
    function ReallocMem(ADst: Pointer; ASize: SizeUInt): Pointer;
    procedure FreeMem(ADst: Pointer);
    function MemSize(APtr: Pointer): SizeUInt;
    function AllocAligned(ASize, AAlignment: SizeUInt): Pointer;
    procedure FreeAligned(APtr: Pointer);
    function Traits: TAllocatorTraits;
  end;

var
  T: TTestRunner;
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
      CheckEqual(Int64(Ord(AExpected)), Int64(Ord(E.Error)), AName + ': error code');
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
  Result := System.GetMem(ASize);
  Track(Result);
end;

function TFixedSlabRecordingAllocator.AllocMem(ASize: SizeUInt): Pointer;
begin
  if ASize = 0 then Exit(nil);
  Result := System.AllocMem(ASize);
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
  Result := System.ReallocMem(ADst, ASize);
  FPtrs[LIndex] := Result;
end;

procedure TFixedSlabRecordingAllocator.FreeMem(ADst: Pointer);
begin
  if ADst = nil then Exit;
  if Untrack(ADst) then
    System.FreeMem(ADst);
end;

function TFixedSlabRecordingAllocator.MemSize(APtr: Pointer): SizeUInt;
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
  Result.HasMemSize := False;
  Result.SupportsAligned := True;
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
    CheckEqual(Int64(1), Int64(LStats.SegmentCount), 'initial segment count');
    Check(LStats.TotalCapacity >= 4096, 'initial capacity should cover requested bytes');
    CheckEqual(Int64(0), Int64(LStats.TotalUsed), 'initial used bytes');
    CheckEqual(Int64(0), Int64(LStats.FallbackAllocCount), 'initial fallback count');

    LTraits := LPool.Traits;
    CheckEqual(True, LTraits.ZeroInitialized, 'AllocMem should promise zero initialization');
    CheckEqual(False, LTraits.ThreadSafe, 'plain slab pool should not claim thread safety');
    CheckEqual(True, LTraits.HasMemSize, 'slab pool should expose mem size');
    CheckEqual(False, LTraits.SupportsAligned, 'slab pool should not claim generic aligned support');

    LPerf := LPool.GetPerfCounters;
    CheckEqual(Int64(0), Int64(LPerf.AllocCalls), 'initial alloc calls');
    CheckEqual(Int64(0), Int64(LPerf.FreeCalls), 'initial free calls');
    CheckEqual(Int64(0), Int64(LPerf.AllocTime), 'L0 slab pool should not sample alloc time directly');
    CheckEqual(Int64(0), Int64(LPerf.FreeTime), 'L0 slab pool should not sample free time directly');
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
    CheckEqual(Int64(64), Int64(LPool.MemSizeOf(LPtr)), 'MemSizeOf should report slab chunk size');

    LPerf := LPool.GetPerfCounters;
    CheckEqual(Int64(1), Int64(LPerf.AllocCalls), 'alloc calls after one allocation');
    CheckEqual(Int64(0), Int64(LPerf.FreeCalls), 'free calls before release');
    CheckEqual(Int64(0), Int64(LPerf.AllocTime), 'alloc time remains zero without L1 timing dependency');

    LStats := LPool.Stats;
    Check(LStats.TotalUsed >= 64, 'used bytes should grow after allocation');

    LPool.FreeMem(LPtr);
    LPerf := LPool.GetPerfCounters;
    CheckEqual(Int64(1), Int64(LPerf.AllocCalls), 'alloc calls should stay stable after free');
    CheckEqual(Int64(1), Int64(LPerf.FreeCalls), 'free calls after release');
    CheckEqual(Int64(0), Int64(LPerf.FreeTime), 'free time remains zero without L1 timing dependency');

    LStats := LPool.Stats;
    CheckEqual(Int64(0), Int64(LStats.FallbackAllocCount), 'slab path should not create fallback allocation');
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
        CheckEqual(Int64(CHUNK_SIZES[LIndex]), Int64(LPool.MemSizeOf(LPtr)), 'exact pointer should report slab chunk size');
        Check(not LPool.Owns(LPtr + 1), 'pool should not own interior pointer diagnostically');
        CheckEqual(Int64(0), Int64(LPool.MemSizeOf(LPtr + 1)), 'interior pointer should not report chunk size');
      finally
        LPool.FreeMem(LPtr);
      end;
      Check(not LPool.Owns(LPtr), 'pool should not own released allocation pointer');
      CheckEqual(Int64(0), Int64(LPool.MemSizeOf(LPtr)), 'released pointer should not report chunk size');
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
    CheckEqual(Int64(64), Int64(GPool.MemSizeOf(GPtr)), 'invalid FreeMem should preserve exact pointer size');

    CheckRaisesAllocError(@ReallocInteriorSlabPointer, aeInvalidPointer, 'interior ReallocMem');
    Check(GPool.Owns(GPtr), 'invalid ReallocMem should not release exact pointer');
    CheckEqual(Int64(64), Int64(GPool.MemSizeOf(GPtr)), 'invalid ReallocMem should preserve exact pointer size');

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
    CheckEqual(Int64(0), Int64(GPool.MemSizeOf(GPtr)),
      'top-level slab released pointer should not report chunk size');
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
      CheckEqual(Int64(96), Int64(LSize), 'tracked fallback size');
      CheckEqual(Int64(256), Int64(LAlign), 'tracked fallback alignment');

      LStats := LPool.Stats;
      CheckEqual(Int64(1), Int64(LStats.FallbackAllocCount), 'fallback allocation count');
      CheckEqual(Int64(96), Int64(LStats.FallbackBytes), 'fallback byte count');
    finally
      LPool.FreeAligned(LPtr);
    end;

    LStats := LPool.Stats;
    CheckEqual(Int64(0), Int64(LStats.FallbackAllocCount), 'fallback allocation count after free');
    CheckEqual(Int64(0), Int64(LStats.FallbackBytes), 'fallback byte count after free');
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
      CheckEqual(Int64(LGetCallsBefore), Int64(LAllocator.GetCalls),
        'overflowing aligned fallback request must not call backing allocator');
      LStats := LPool.Stats;
      CheckEqual(Int64(0), Int64(LStats.FallbackAllocCount),
        'overflowing aligned fallback request must not be tracked');
      CheckEqual(Int64(0), Int64(LStats.FallbackBytes),
        'overflowing aligned fallback request must not change fallback bytes');
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
        CheckEqual(Int64(Ord(aeInvalidLayout)), Int64(Ord(E.Error)),
          'fixed slab overflow capacity error');
      end;
    end;

    Check(LRaised, 'fixed slab overflow capacity must fail closed');
    CheckEqual(Int64(0), Int64(LAllocator.GetCalls),
      'fixed slab overflow capacity must not call backing allocator');
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
    CheckEqual(Int64(64), Int64(GFixedSlabPool.MemSizeOf(GPtr)),
      'fixed slab invalid FreeMem should preserve exact pointer size');

    CheckRaisesAllocError(@ReallocInteriorFixedSlabPointer, aeInvalidPointer,
      'fixed slab interior ReallocMem');
    Check(GFixedSlabPool.Owns(GPtr),
      'fixed slab invalid ReallocMem should not release exact pointer');
    CheckEqual(Int64(64), Int64(GFixedSlabPool.MemSizeOf(GPtr)),
      'fixed slab invalid ReallocMem should preserve exact pointer size');

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
    CheckEqual(Int64(1), Int64(GFixedSlabFallback.FreeAlignedCalls),
      'foreign FreeAligned must not delegate to backing allocator');
  finally
    GPtr := nil;
    GFixedSlabPool.Free;
    GFixedSlabPool := nil;
    GFixedSlabFallback := nil;
  end;
end;

begin
  T := TTestRunner.Create('nextpas.core.mem.slab_pool');
  T.Run('create stats and traits', @TestCreateStatsAndTraits);
  T.Run('alloc free and perf counters', @TestAllocFreeAndPerfCounters);
  T.Run('ownership diagnostics reject interior pointer', @TestOwnershipDiagnosticsRejectInteriorPointer);
  T.Run('release and realloc reject interior pointer', @TestReleaseAndReallocRejectInteriorPointer);
  T.Run('top-level slab double free fails closed', @TestTopLevelSlabDoubleFreeFailsClosed);
  T.Run('aligned fallback tracking', @TestAllocAlignedFallsBackAndTracksStats);
  T.Run('aligned fallback rejects backing size overflow', @TestSlabAlignedFallbackRejectsBackingSizeOverflow);
  T.Run('fixed slab rejects capacity overflow', @TestFixedSlabCreateRejectsCapacityOverflow);
  T.Run('fixed slab direct api fails closed', @TestFixedSlabDirectApiFailsClosed);
  T.Run('fixed slab aligned direct fails closed', @TestFixedSlabAlignedDirectFailsClosed);
  T.Run('fixed slab aligned fallback fails closed', @TestFixedSlabAlignedFallbackFailsClosed);
  T.Summary;
end.
