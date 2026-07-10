program test_hotswap;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.text.conv,
  nextpas.core.test,
  nextpas.core.mem.base,
  nextpas.core.mem.intf,
  nextpas.core.mem.default,
  nextpas.core.mem.allocator.base,
  nextpas.core.mem.allocator.hotswap,
  nextpas.core.mem.error;

type
  TDestroyTrackingAllocator = class(TInterfacedObject, IAllocator)
  public
    destructor Destroy; override;
    function GetMem(ASize: SizeUInt): Pointer;
    function AllocMem(ASize: SizeUInt): Pointer;
    function ReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer;
    procedure FreeMem(APtr: Pointer);
    function Traits: TAllocatorTraits;
  end;

var
  T: TTestSuite;
  GDestroyedAllocatorCount: Integer;
  GRunPassed: Boolean;

{ TDestroyTrackingAllocator }

destructor TDestroyTrackingAllocator.Destroy;
begin
  Inc(GDestroyedAllocatorCount);
  inherited Destroy;
end;

function TDestroyTrackingAllocator.GetMem(ASize: SizeUInt): Pointer;
begin
  if ASize = 0 then
    Exit(nil);
  Result := System.GetMem(ASize);
end;

function TDestroyTrackingAllocator.AllocMem(ASize: SizeUInt): Pointer;
begin
  if ASize = 0 then
    Exit(nil);
  Result := System.AllocMem(ASize);
end;

function TDestroyTrackingAllocator.ReallocMem(APtr: Pointer;
  ASize: SizeUInt): Pointer;
begin
  if ASize = 0 then
  begin
    FreeMem(APtr);
    Exit(nil);
  end;
  if APtr = nil then
    Exit(GetMem(ASize));
  Result := System.ReallocMem(APtr, ASize);
end;

procedure TDestroyTrackingAllocator.FreeMem(APtr: Pointer);
begin
  if APtr <> nil then
    System.FreeMem(APtr);
end;

function TDestroyTrackingAllocator.Traits: TAllocatorTraits;
begin
  Result.ZeroInitialized := False;
  Result.ThreadSafe := False;
  Result.SupportsRealloc := True;
end;

{ Keep managed interface temporaries inside helper scope for lifetime checks. }
procedure FreeHotswapBlock(const AHotswap: THotswapAllocator;
  const APtr: Pointer); noinline;
begin
  AHotswap.FreeMem(APtr);
end;

function GrowHotswapBlock(const AHotswap: THotswapAllocator;
  const APtr: Pointer): Pointer; noinline;
begin
  Result := AHotswap.ReallocMem(APtr, 64);
end;

procedure CreateTrackedHotswapBlock(out AHotswap: THotswapAllocator;
  out APtr: Pointer); noinline;
var
  LOrigin: IAllocator;
begin
  LOrigin := TDestroyTrackingAllocator.Create;
  AHotswap := THotswapAllocator.Create(LOrigin);
  APtr := AHotswap.GetMem(16);
  AHotswap.Swap(DefaultAllocator);
  LOrigin := nil;
end;

procedure TestCreateAndDestroy;
var
  LHotswap: THotswapAllocator;
begin
  LHotswap := THotswapAllocator.Create(DefaultAllocator);
  try
    Check(LHotswap.Current <> nil, 'Current should not be nil');
    Check(LHotswap.SwapCount = 0, 'SwapCount should be 0');
  finally
    LHotswap.Free;
  end;
end;

procedure TestSwap;
var
  LHotswap: THotswapAllocator;
  LNewAlloc: IAllocator;
begin
  LHotswap := THotswapAllocator.Create(DefaultAllocator);
  try
    LNewAlloc := DefaultAllocator;
    LHotswap.Swap(LNewAlloc);
    Check(LHotswap.SwapCount = 1, 'SwapCount should be 1');
    Check(LHotswap.Current = LNewAlloc, 'Current should be new allocator');
  finally
    LHotswap.Free;
  end;
end;

procedure TestMultipleSwaps;
var
  LHotswap: THotswapAllocator;
begin
  LHotswap := THotswapAllocator.Create(DefaultAllocator);
  try
    LHotswap.Swap(DefaultAllocator);
    LHotswap.Swap(DefaultAllocator);
    LHotswap.Swap(DefaultAllocator);
    Check(LHotswap.SwapCount = 3, 'SwapCount should be 3');
  finally
    LHotswap.Free;
  end;
end;

procedure TestAllocBeforeSwap;
var
  LHotswap: THotswapAllocator;
  LPtr: Pointer;
begin
  LHotswap := THotswapAllocator.Create(DefaultAllocator);
  try
    LPtr := LHotswap.GetMem(1024);
    Check(LPtr <> nil, 'alloc should succeed before swap');
    LHotswap.FreeMem(LPtr);
  finally
    LHotswap.Free;
  end;
end;

procedure TestAllocAfterSwap;
var
  LHotswap: THotswapAllocator;
  LPtr: Pointer;
begin
  LHotswap := THotswapAllocator.Create(DefaultAllocator);
  try
    LHotswap.Swap(DefaultAllocator);
    LPtr := LHotswap.GetMem(1024);
    Check(LPtr <> nil, 'alloc should succeed after swap');
    LHotswap.FreeMem(LPtr);
  finally
    LHotswap.Free;
  end;
end;

procedure TestFreeReleasesOriginReference;
var
  LHotswap: THotswapAllocator;
  LPtr: Pointer;
begin
  GDestroyedAllocatorCount := 0;
  LHotswap := nil;
  LPtr := nil;
  CreateTrackedHotswapBlock(LHotswap, LPtr);
  try
    Check(LPtr <> nil, 'allocation should succeed');
    Check(GDestroyedAllocatorCount = 0,
      'outstanding block should retain its origin allocator');

    FreeHotswapBlock(LHotswap, LPtr);
    LPtr := nil;
    Check(GDestroyedAllocatorCount = 1,
      'free should release the block origin reference');
  finally
    if LPtr <> nil then
      LHotswap.FreeMem(LPtr);
    if LHotswap <> nil then
      LHotswap.Free;
  end;
end;

procedure TestGrowingReallocReleasesOriginReference;
var
  LHotswap: THotswapAllocator;
  LPtr: Pointer;
  LNewPtr: Pointer;
begin
  GDestroyedAllocatorCount := 0;
  LHotswap := nil;
  LPtr := nil;
  CreateTrackedHotswapBlock(LHotswap, LPtr);
  try
    Check(LPtr <> nil, 'allocation should succeed');
    Check(GDestroyedAllocatorCount = 0,
      'outstanding block should retain its origin allocator');

    LNewPtr := GrowHotswapBlock(LHotswap, LPtr);
    if LNewPtr <> nil then
      LPtr := LNewPtr;
    Check(LNewPtr <> nil, 'growing realloc should succeed');
    Check(GDestroyedAllocatorCount = 1,
      'growing realloc should release the old block origin reference');
  finally
    if LPtr <> nil then
      LHotswap.FreeMem(LPtr);
    if LHotswap <> nil then
      LHotswap.Free;
  end;
end;

procedure TestNilInitialRaises;
var
  LHotswap: THotswapAllocator;
  LRaised: Boolean;
begin
  LRaised := False;
  try
    LHotswap := THotswapAllocator.Create(nil);
    LHotswap.Free;
  except
    on E: Exception do
      LRaised := True;
  end;
  Check(LRaised, 'should raise for nil initial');
end;

procedure TestNilSwapRaises;
var
  LHotswap: THotswapAllocator;
  LRaised: Boolean;
begin
  LHotswap := THotswapAllocator.Create(DefaultAllocator);
  try
    LRaised := False;
    try
      LHotswap.Swap(nil);
    except
      on E: Exception do
        LRaised := True;
    end;
    Check(LRaised, 'should raise for nil swap');
  finally
    LHotswap.Free;
  end;
end;

procedure TestTraits;
var
  LHotswap: THotswapAllocator;
  LTraits: TAllocatorTraits;
begin
  LHotswap := THotswapAllocator.Create(DefaultAllocator);
  try
    LTraits := LHotswap.Traits;
    { Hotswap delegates Traits to inner; RTL allocator is not thread-safe }
    Check(not LTraits.ThreadSafe, 'RTL allocator is not thread-safe');
    Check(LTraits.SupportsRealloc, 'should support realloc');
  finally
    LHotswap.Free;
  end;
end;

begin
  T := TTestSuite.Create('test_hotswap');
  T.Test('create_and_destroy', @TestCreateAndDestroy);
  T.Test('swap', @TestSwap);
  T.Test('multiple_swaps', @TestMultipleSwaps);
  T.Test('alloc_before_swap', @TestAllocBeforeSwap);
  T.Test('alloc_after_swap', @TestAllocAfterSwap);
  T.Test('free_releases_origin_reference',
    @TestFreeReleasesOriginReference);
  T.Test('growing_realloc_releases_origin_reference',
    @TestGrowingReallocReleasesOriginReference);
  T.Test('nil_initial_raises', @TestNilInitialRaises);
  T.Test('nil_swap_raises', @TestNilSwapRaises);
  T.Test('traits', @TestTraits);
  GRunPassed := T.Run;
  T.Summary;
  if not GRunPassed then
    Halt(1);
end.
