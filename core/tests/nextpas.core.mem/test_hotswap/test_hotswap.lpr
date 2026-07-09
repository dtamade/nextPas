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

var
  T: TTestSuite;

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
    Check(LTraits.ThreadSafe, 'should be thread-safe');
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
  T.Test('nil_initial_raises', @TestNilInitialRaises);
  T.Test('nil_swap_raises', @TestNilSwapRaises);
  T.Test('traits', @TestTraits);
  T.Run;
  T.Summary;
end.
