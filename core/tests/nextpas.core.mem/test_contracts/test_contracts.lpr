program test_contracts;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.base,
	  nextpas.core.testing,
	  nextpas.core.mem.intf,
	  nextpas.core.mem.utils,
	  nextpas.core.mem.allocator,
	  nextpas.core.mem.allocator.base,
	  nextpas.core.mem.allocator.mimalloc,
	  nextpas.core.mem.alloc,
	  nextpas.core.mem.error,
	  nextpas.core.mem.layout,
	  nextpas.core.mem.adapter;

type
  TByteArray = array[0..5] of Byte;
  TWordArray = array[0..3] of Word;
  TDWordArray = array[0..2] of UInt32;
  TQWordArray = array[0..1] of UInt64;

  TRecordingAlloc = class(TInterfacedObject, IAlloc)
  public
    AllocCalls: Integer;
    ReallocCalls: Integer;
    DeallocCalls: Integer;
    LastAllocLayout: TMemLayout;
    LastReallocOldLayout: TMemLayout;
    LastReallocNewLayout: TMemLayout;
    LastDeallocLayout: TMemLayout;

    function Alloc(const aLayout: TMemLayout): TAllocResult;
    function AllocZeroed(const aLayout: TMemLayout): TAllocResult;
    procedure Dealloc(aPtr: Pointer; const aLayout: TMemLayout);
    function Realloc(aPtr: Pointer; const aOldLayout, aNewLayout: TMemLayout): TAllocResult;
    function Caps: TAllocCaps;
  end;

var
  T: TTestRunner;
  GGetMemCalls: Integer = 0;
  GAllocMemCalls: Integer = 0;
  GReallocMemCalls: Integer = 0;
  GFreeMemCalls: Integer = 0;

procedure ResetAllocatorCounters;
begin
  GGetMemCalls := 0;
  GAllocMemCalls := 0;
  GReallocMemCalls := 0;
  GFreeMemCalls := 0;
end;

function TRecordingAlloc.Alloc(const aLayout: TMemLayout): TAllocResult;
var
  LPtr: Pointer;
begin
  Inc(AllocCalls);
  LastAllocLayout := aLayout;
  if not aLayout.IsValid then
    Exit(TAllocResult.Err(aeInvalidLayout));
  if aLayout.IsZeroSized then
    Exit(TAllocResult.Ok(nil));

  LPtr := System.GetMem(aLayout.Size);
  if LPtr = nil then
    Result := TAllocResult.Err(aeOutOfMemory)
  else
    Result := TAllocResult.Ok(LPtr);
end;

function TRecordingAlloc.AllocZeroed(const aLayout: TMemLayout): TAllocResult;
begin
  Result := Alloc(aLayout);
  if Result.IsOk and (Result.Ptr <> nil) then
    FillChar(Result.Ptr^, aLayout.Size, 0);
end;

procedure TRecordingAlloc.Dealloc(aPtr: Pointer; const aLayout: TMemLayout);
begin
  Inc(DeallocCalls);
  LastDeallocLayout := aLayout;
  if (aPtr <> nil) and (aLayout.Size > 0) then
    System.FreeMem(aPtr);
end;

function TRecordingAlloc.Realloc(aPtr: Pointer; const aOldLayout, aNewLayout: TMemLayout): TAllocResult;
var
  LPtr: Pointer;
begin
  Inc(ReallocCalls);
  LastReallocOldLayout := aOldLayout;
  LastReallocNewLayout := aNewLayout;
  if aPtr = nil then
    Exit(Alloc(aNewLayout));
  if aNewLayout.IsZeroSized then
  begin
    Dealloc(aPtr, aOldLayout);
    Exit(TAllocResult.Ok(nil));
  end;

  LPtr := System.ReallocMem(aPtr, aNewLayout.Size);
  if LPtr = nil then
    Result := TAllocResult.Err(aeOutOfMemory)
  else
    Result := TAllocResult.Ok(LPtr);
end;

function TRecordingAlloc.Caps: TAllocCaps;
begin
  Result := TAllocCaps.Create(False, True, False, True, True, 256);
end;

function CallbackGetMem(aSize: SizeUInt): Pointer;
begin
  Inc(GGetMemCalls);
  Result := System.GetMem(aSize);
end;

function CallbackAllocMem(aSize: SizeUInt): Pointer;
begin
  Inc(GAllocMemCalls);
  Result := System.AllocMem(aSize);
end;

function CallbackReallocMem(aDst: Pointer; aSize: SizeUInt): Pointer;
begin
  Inc(GReallocMemCalls);
  Result := System.ReallocMem(aDst, aSize);
end;

procedure CallbackFreeMem(aDst: Pointer);
begin
  Inc(GFreeMemCalls);
  System.FreeMem(aDst);
end;

procedure TestCallbackAllocatorCompatibilityMethods;
var
  LAllocator: nextpas.core.mem.allocator.IAllocator;
  LPtr: Pointer;
begin
  ResetAllocatorCounters;
  LAllocator := CreateCallbackAllocator(
    @CallbackGetMem,
    @CallbackAllocMem,
    @CallbackReallocMem,
    @CallbackFreeMem);

  Check(LAllocator <> nil, 'callback allocator should be created');
  Check(LAllocator.GetMem(0) = nil, 'GetMem(0) should return nil');
  Check(LAllocator.AllocMem(0) = nil, 'AllocMem(0) should return nil');

  LPtr := LAllocator.ReallocMem(nil, 16);
  Check(LPtr <> nil, 'ReallocMem(nil, size) should allocate');
  CheckEqual(Int64(1), Int64(GGetMemCalls), 'ReallocMem(nil, size) should route through GetMem');
  CheckEqual(Int64(0), Int64(GReallocMemCalls), 'ReallocMem(nil, size) should not call realloc callback');

  PByte(LPtr)^ := $5A;
  LPtr := LAllocator.ReallocMem(LPtr, 32);
  Check(LPtr <> nil, 'ReallocMem(existing, size) should return a pointer');
  CheckEqual(Int64(1), Int64(GReallocMemCalls), 'ReallocMem(existing, size) should call realloc callback');
  CheckEqual(Int64($5A), Int64(PByte(LPtr)^), 'ReallocMem should preserve the existing prefix');

  LPtr := LAllocator.ReallocMem(LPtr, 0);
  Check(LPtr = nil, 'ReallocMem(existing, 0) should free and return nil');
  CheckEqual(Int64(1), Int64(GFreeMemCalls), 'ReallocMem(existing, 0) should call free callback');

  LAllocator.FreeMem(nil);
  CheckEqual(Int64(1), Int64(GFreeMemCalls), 'FreeMem(nil) should be a no-op');
end;

procedure TestCallbackAllocatorSupportsAllocateInterface;
var
  LAllocator: nextpas.core.mem.intf.IAllocator;
  LPtr: Pointer;
begin
  ResetAllocatorCounters;
  LAllocator := CreateCallbackAllocator(
    @CallbackGetMem,
    @CallbackAllocMem,
    @CallbackReallocMem,
    @CallbackFreeMem) as nextpas.core.mem.intf.IAllocator;

  LPtr := LAllocator.Allocate(24);
  Check(LPtr <> nil, 'Allocate should delegate to the compatibility allocator');
  CheckEqual(Int64(1), Int64(GGetMemCalls), 'Allocate should route through GetMem');

  PByte(LPtr)^ := $33;
  LPtr := LAllocator.Reallocate(LPtr, 48);
  Check(LPtr <> nil, 'Reallocate should return a pointer');
  CheckEqual(Int64(1), Int64(GReallocMemCalls), 'Reallocate should route through ReallocMem');
  CheckEqual(Int64($33), Int64(PByte(LPtr)^), 'Reallocate should preserve the prefix');

  LAllocator.Deallocate(LPtr);
  CheckEqual(Int64(1), Int64(GFreeMemCalls), 'Deallocate should route through FreeMem');
end;

procedure TestRtlAllocatorZeroInitTraitsAndAlignedAlloc;
var
  LAllocator: nextpas.core.mem.allocator.IAllocator;
  LTraits: nextpas.core.mem.allocator.base.TAllocatorTraits;
  LPtr: Pointer;
  I: Integer;
begin
  LAllocator := GetRtlAllocator;
  Check(LAllocator <> nil, 'RTL allocator should exist');

  LTraits := LAllocator.Traits;
  CheckEqual(False, LTraits.ZeroInitialized, 'RTL GetMem should not claim zero initialization');
  CheckEqual(False, LTraits.SupportsAligned, 'RTL allocator should report non-native aligned support');
  CheckEqual(False, LTraits.HasMemSize, 'RTL allocator should not expose MemSize');

  LPtr := LAllocator.AllocMem(32);
  try
    for I := 0 to 31 do
      CheckEqual(Int64(0), Int64(PByte(LPtr)[I]), 'AllocMem should zero initialize each byte');
  finally
    LAllocator.FreeMem(LPtr);
  end;

  LPtr := LAllocator.AllocAligned(64, 32);
  try
    Check(LPtr <> nil, 'AllocAligned should return a pointer');
    CheckEqual(Int64(0), Int64(PtrUInt(LPtr) mod 32), 'AllocAligned should honor the requested alignment');
  finally
    LAllocator.FreeAligned(LPtr);
  end;
end;

procedure TestRtlAllocatorAlignedAllocRejectsSizeOverflow;
var
  LAllocator: nextpas.core.mem.allocator.IAllocator;
  LPtr: Pointer;
begin
  LAllocator := GetRtlAllocator;
  LPtr := LAllocator.AllocAligned(High(SizeUInt), SizeOf(Pointer));
  try
    Check(LPtr = nil, 'AllocAligned should reject size calculations that overflow SizeUInt');
  finally
    if LPtr <> nil then
      LAllocator.FreeAligned(LPtr);
  end;
end;

procedure TestCanonicalAllocatorSurface;
var
  LAllocator: nextpas.core.mem.intf.IAllocator;
  LTraits: nextpas.core.mem.intf.TAllocatorTraits;
  LPtr: Pointer;
begin
  LAllocator := GetRtlAllocator as nextpas.core.mem.intf.IAllocator;
  LTraits := LAllocator.Traits;
  Check(LTraits.ThreadSafe, 'canonical allocator exposes traits');

  LPtr := LAllocator.GetMem(16);
  try
    Check(LPtr <> nil, 'canonical allocator exposes GetMem');
    PByte(LPtr)^ := $4A;
    LPtr := LAllocator.ReallocMem(LPtr, 32);
    Check(LPtr <> nil, 'canonical allocator exposes ReallocMem');
    CheckEqual(Int64($4A), Int64(PByte(LPtr)^), 'canonical ReallocMem preserves prefix');
  finally
    LAllocator.FreeMem(LPtr);
  end;
end;

procedure TestAllocatorAliasesAreCanonical;
var
  LCanonical: nextpas.core.mem.intf.IAllocator;
  LFacade: nextpas.core.mem.allocator.IAllocator;
begin
  LFacade := GetRtlAllocator;
  LCanonical := LFacade as nextpas.core.mem.intf.IAllocator;
  Check(LCanonical <> nil, 'allocator facade alias should be canonical');
  Check(LCanonical = LFacade, 'facade and canonical allocator interfaces should resolve to the same interface identity');
end;

procedure TestAllocatorAdapterRoundTrip;
var
  LAllocator: nextpas.core.mem.allocator.IAllocator;
  LAlloc: IAlloc;
  LRoundTrip: nextpas.core.mem.allocator.IAllocator;
  LPtr: Pointer;
begin
  LAllocator := GetRtlAllocator;
  LAlloc := WrapAsAlloc(LAllocator);
  Check(LAlloc <> nil, 'WrapAsAlloc should return an adapter');

  LRoundTrip := WrapAsAllocator(LAlloc);
  Check(LRoundTrip <> nil, 'WrapAsAllocator should return an adapter');

  LPtr := LRoundTrip.GetMem(24);
  try
    Check(LPtr <> nil, 'adapter round trip should allocate');
    PByte(LPtr)^ := $27;
    LPtr := LRoundTrip.ReallocMem(LPtr, 48);
    Check(LPtr <> nil, 'adapter round trip should reallocate');
    CheckEqual(Int64($27), Int64(PByte(LPtr)^), 'adapter round trip should preserve data');
  finally
    LRoundTrip.FreeMem(LPtr);
  end;
end;

procedure TestAllocatorAdapterAlignedRoundTrip;
var
  LAlloc: IAlloc;
  LAllocator: nextpas.core.mem.allocator.IAllocator;
  LPtr: Pointer;
begin
  LAlloc := GetAlignedAlloc;
  LAllocator := WrapAsAllocator(LAlloc);
  Check(LAllocator <> nil, 'aligned IAlloc should adapt to IAllocator');

  LPtr := LAllocator.AllocAligned(64, 64);
  try
    Check(LPtr <> nil, 'aligned adapter should allocate');
    CheckEqual(Int64(0), Int64(PtrUInt(LPtr) mod 64), 'aligned adapter should honor alignment');
    PByte(LPtr)^ := $42;

    LPtr := LAllocator.ReallocMem(LPtr, 128);
    Check(LPtr <> nil, 'aligned adapter should reallocate through tracked layout');
    CheckEqual(Int64(0), Int64(PtrUInt(LPtr) mod 64), 'aligned adapter realloc should preserve alignment');
    CheckEqual(Int64($42), Int64(PByte(LPtr)^), 'aligned adapter realloc should preserve prefix');
  finally
    LAllocator.FreeAligned(LPtr);
  end;
end;

procedure TestAlignedAllocRejectsBackingSizeOverflow;
var
  LAlloc: IAlloc;
  LLayout: TMemLayout;
  LResult: TAllocResult;
begin
  LAlloc := GetAlignedAlloc;
  LLayout := TMemLayout.Create(High(SizeUInt), 64);
  LResult := LAlloc.Alloc(LLayout);
  try
    Check(LResult.IsErr, 'aligned IAlloc should reject backing size calculations that overflow SizeUInt');
  finally
    if LResult.IsOk and (LResult.Ptr <> nil) then
      LAlloc.Dealloc(LResult.Ptr, LLayout);
  end;
end;

procedure TestAllocToAllocatorAdapterTracksLayoutsAndRejectsUntrackedPointers;
var
  LRecording: TRecordingAlloc;
  LAlloc: IAlloc;
  LAllocator: nextpas.core.mem.allocator.IAllocator;
  LPtr: Pointer;
  LForeignByte: Byte;
begin
  LRecording := TRecordingAlloc.Create;
  LAlloc := LRecording as IAlloc;
  LAllocator := WrapAsAllocator(LAlloc);

  LPtr := LAllocator.AllocAligned(96, 64);
  try
    Check(LPtr <> nil, 'tracked adapter allocation should succeed');
    CheckEqual(Int64(96), Int64(LRecording.LastAllocLayout.Size),
      'tracked adapter allocation should pass requested size');
    CheckEqual(Int64(64), Int64(LRecording.LastAllocLayout.Align),
      'tracked adapter allocation should pass requested alignment');

    LPtr := LAllocator.ReallocMem(LPtr, 160);
    Check(LPtr <> nil, 'tracked adapter realloc should succeed');
    CheckEqual(Int64(1), Int64(LRecording.ReallocCalls),
      'tracked adapter realloc should forward once');
    CheckEqual(Int64(96), Int64(LRecording.LastReallocOldLayout.Size),
      'tracked adapter realloc should preserve old size');
    CheckEqual(Int64(64), Int64(LRecording.LastReallocOldLayout.Align),
      'tracked adapter realloc should preserve old alignment');
    CheckEqual(Int64(160), Int64(LRecording.LastReallocNewLayout.Size),
      'tracked adapter realloc should pass new size');
    CheckEqual(Int64(64), Int64(LRecording.LastReallocNewLayout.Align),
      'tracked adapter realloc should preserve new alignment');

    try
      LAllocator.FreeMem(@LForeignByte);
      Fail('untracked pointer FreeMem should raise');
    except
      on E: EAllocError do
        CheckEqual(Int64(Ord(aeInvalidPointer)), Int64(Ord(E.Error)),
          'untracked pointer FreeMem error code');
    end;
    CheckEqual(Int64(0), Int64(LRecording.DeallocCalls),
      'untracked pointer must not be forwarded to IAlloc.Dealloc');

    try
      LAllocator.ReallocMem(@LForeignByte, 16);
      Fail('untracked pointer ReallocMem should raise');
    except
      on E: EAllocError do
        CheckEqual(Int64(Ord(aeInvalidPointer)), Int64(Ord(E.Error)),
          'untracked pointer ReallocMem error code');
    end;
    CheckEqual(Int64(1), Int64(LRecording.ReallocCalls),
      'untracked pointer must not be forwarded to IAlloc.Realloc');
  finally
    if LPtr <> nil then
      LAllocator.FreeMem(LPtr);
  end;

  CheckEqual(Int64(1), Int64(LRecording.DeallocCalls),
    'tracked adapter free should forward exactly once');
  CheckEqual(Int64(160), Int64(LRecording.LastDeallocLayout.Size),
    'tracked adapter free should pass tracked final size');
  CheckEqual(Int64(64), Int64(LRecording.LastDeallocLayout.Align),
    'tracked adapter free should pass tracked final alignment');
end;

procedure TestMimallocUsableSizeCapabilityFallback;
var
  LAllocator: nextpas.core.mem.allocator.IAllocator;
  LTraits: nextpas.core.mem.allocator.base.TAllocatorTraits;
  LPtr: Pointer;
  LSize: SizeUInt;
  LHasSurface: Boolean;
begin
  LAllocator := nextpas.core.mem.allocator.mimalloc.GetMimallocAllocator;
  Check(LAllocator <> nil, 'mimalloc allocator object should be creatable without eager loading');

  LTraits := LAllocator.Traits;
  LHasSurface := nextpas.core.mem.allocator.mimalloc.MimallocUsableSizeAvailable;
  CheckEqual(LHasSurface, LTraits.HasMemSize, 'mimalloc HasMemSize should match mi_malloc_usable_size availability');

  LSize := 123;
  CheckEqual(False, nextpas.core.mem.allocator.mimalloc.TryGetMimallocUsableSize(nil, LSize),
    'nil is not a usable-size query target');
  CheckEqual(Int64(0), Int64(LSize), 'failed usable-size queries should clear the output size');

  if LTraits.HasMemSize then
  begin
    LPtr := LAllocator.GetMem(33);
    try
      Check(LPtr <> nil, 'mimalloc allocation should succeed when usable-size surface is available');
      Check(nextpas.core.mem.allocator.mimalloc.TryGetMimallocUsableSize(LPtr, LSize),
        'usable-size query should succeed for mimalloc-owned blocks when symbol is available');
      Check(LSize >= 33, 'mimalloc usable size should cover the requested allocation size');
    finally
      LAllocator.FreeMem(LPtr);
    end;
  end
  else
  begin
    LPtr := nil;
    try
      try
        LPtr := LAllocator.GetMem(33);
      except
        on E: Exception do
          LPtr := nil;
      end;

      if LPtr <> nil then
      begin
        CheckEqual(False, nextpas.core.mem.allocator.mimalloc.TryGetMimallocUsableSize(LPtr, LSize),
          'fallback should not query usable size when the optional symbol is unavailable');
        CheckEqual(Int64(0), Int64(LSize), 'fallback usable-size query should return size 0');
      end;
    finally
      if LPtr <> nil then
        LAllocator.FreeMem(LPtr);
    end;
  end;
end;

procedure TestMemUtilsNoOpAndOverlapContract;
var
  LBytes: TByteArray;
begin
  Copy(nil, nil, 0);
  CopyNonOverlap(nil, nil, 0);
  Fill8(nil, 0, $7F);
  Zero(nil, 0);

  LBytes[0] := 1;
  LBytes[1] := 2;
  LBytes[2] := 3;
  LBytes[3] := 4;
  LBytes[4] := 5;
  LBytes[5] := 6;

  CheckEqual(False, IsOverlap(nil, 0, @LBytes[0], 4), 'nil block should not overlap');
  CheckEqual(False, IsOverlap(@LBytes[0], 2, @LBytes[2], 2), 'adjacent ranges should not overlap');
  CheckEqual(True, IsOverlap(@LBytes[0], 3, @LBytes[2], 3), 'intersecting ranges should overlap');
end;

procedure TestMemUtilsCopyUncheckedHandlesOverlap;
var
  LBytes: TByteArray;
begin
  LBytes[0] := 1;
  LBytes[1] := 2;
  LBytes[2] := 3;
  LBytes[3] := 4;
  LBytes[4] := 5;
  LBytes[5] := 6;

  CopyUnChecked(@LBytes[0], @LBytes[1], 5);

  CheckEqual(Int64(1), Int64(LBytes[0]), 'copy overlap index 0');
  CheckEqual(Int64(1), Int64(LBytes[1]), 'copy overlap index 1');
  CheckEqual(Int64(2), Int64(LBytes[2]), 'copy overlap index 2');
  CheckEqual(Int64(3), Int64(LBytes[3]), 'copy overlap index 3');
  CheckEqual(Int64(4), Int64(LBytes[4]), 'copy overlap index 4');
  CheckEqual(Int64(5), Int64(LBytes[5]), 'copy overlap index 5');
end;

procedure TestMemUtilsFillAndZeroHelpers;
var
  LBytes: TByteArray;
  LWords: TWordArray;
  LDWords: TDWordArray;
  LQWords: TQWordArray;
  I: Integer;
begin
  Fill8(@LBytes[0], Length(LBytes), $AB);
  for I := Low(LBytes) to High(LBytes) do
    CheckEqual(Int64($AB), Int64(LBytes[I]), 'Fill8 should write the requested byte');

  Fill16(@LWords[0], Length(LWords), $1234);
  for I := Low(LWords) to High(LWords) do
    CheckEqual(Int64($1234), Int64(LWords[I]), 'Fill16 should write the requested word');

  Fill32(@LDWords[0], Length(LDWords), $89ABCDEF);
  for I := Low(LDWords) to High(LDWords) do
    CheckEqual(Int64($89ABCDEF), Int64(LDWords[I]), 'Fill32 should write the requested dword');

  Fill64(@LQWords[0], Length(LQWords), $0123456789ABCDEF);
  for I := Low(LQWords) to High(LQWords) do
    CheckEqual(Int64($0123456789ABCDEF), Int64(LQWords[I]), 'Fill64 should write the requested qword');

  Zero(@LBytes[0], Length(LBytes));
  for I := Low(LBytes) to High(LBytes) do
    CheckEqual(Int64(0), Int64(LBytes[I]), 'Zero should clear each byte');
end;

begin
  T := TTestRunner.Create('nextpas.core.mem.contracts');
  T.Run('callback allocator compatibility methods', @TestCallbackAllocatorCompatibilityMethods);
  T.Run('callback allocator supports allocate interface', @TestCallbackAllocatorSupportsAllocateInterface);
  T.Run('rtl allocator zero init traits and aligned alloc', @TestRtlAllocatorZeroInitTraitsAndAlignedAlloc);
  T.Run('rtl allocator aligned alloc rejects size overflow', @TestRtlAllocatorAlignedAllocRejectsSizeOverflow);
  T.Run('canonical allocator surface', @TestCanonicalAllocatorSurface);
  T.Run('allocator aliases are canonical', @TestAllocatorAliasesAreCanonical);
  T.Run('allocator adapter round trip', @TestAllocatorAdapterRoundTrip);
  T.Run('allocator adapter aligned round trip', @TestAllocatorAdapterAlignedRoundTrip);
  T.Run('aligned alloc rejects backing size overflow', @TestAlignedAllocRejectsBackingSizeOverflow);
  T.Run('alloc adapter tracks layouts and rejects untracked pointers', @TestAllocToAllocatorAdapterTracksLayoutsAndRejectsUntrackedPointers);
  T.Run('mimalloc usable-size capability fallback', @TestMimallocUsableSizeCapabilityFallback);
  T.Run('mem.utils no-op and overlap contract', @TestMemUtilsNoOpAndOverlapContract);
  T.Run('mem.utils copy unchecked handles overlap', @TestMemUtilsCopyUncheckedHandlesOverlap);
  T.Run('mem.utils fill and zero helpers', @TestMemUtilsFillAndZeroHelpers);
  T.Summary;
end.
