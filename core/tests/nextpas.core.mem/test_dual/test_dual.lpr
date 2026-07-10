program test_dual;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.mem.intf,
  nextpas.core.exception,
  nextpas.core.text.conv,
  nextpas.core.test,
  nextpas.core.base,
  nextpas.core.mem.base,
  nextpas.core.mem.error,
  nextpas.core.mem.default,
  nextpas.core.mem.allocator.dual;

var
  T: TTestSuite;
  LRunPassed: Boolean;

{ --- 基础生命周期 Basic lifecycle --- }

procedure TestCreateDestroy;
var
  LSmall, LLarge: IAllocator;
  LAlloc: TDualAllocator;
begin
  LSmall := DefaultAllocator;
  LLarge := DefaultAllocator;
  try
    LAlloc := TDualAllocator.Create(LSmall, LLarge, 1024);
    try
      Check(LAlloc <> nil, 'created');
    finally
      LAlloc.Free;
    end;
  finally
    
    
  end;
end;

procedure TestSmallAllocation;
var
  LSmall, LLarge: IAllocator;
  LAlloc: TDualAllocator;
  LP: Pointer;
begin
  LSmall := DefaultAllocator;
  LLarge := DefaultAllocator;
  try
    LAlloc := TDualAllocator.Create(LSmall, LLarge, 1024);
    try
      LP := LAlloc.GetMem(512);
      Check(LP <> nil, 'small allocation returned pointer');
      LAlloc.FreeMem(LP);
    finally
      LAlloc.Free;
    end;
  finally
    
    
  end;
end;

procedure TestLargeAllocation;
var
  LSmall, LLarge: IAllocator;
  LAlloc: TDualAllocator;
  LP: Pointer;
begin
  LSmall := DefaultAllocator;
  LLarge := DefaultAllocator;
  try
    LAlloc := TDualAllocator.Create(LSmall, LLarge, 1024);
    try
      LP := LAlloc.GetMem(2048);
      Check(LP <> nil, 'large allocation returned pointer');
      LAlloc.FreeMem(LP);
    finally
      LAlloc.Free;
    end;
  finally
    
    
  end;
end;

procedure TestBoundarySize;
var
  LSmall, LLarge: IAllocator;
  LAlloc: TDualAllocator;
  LP: Pointer;
begin
  LSmall := DefaultAllocator;
  LLarge := DefaultAllocator;
  try
    LAlloc := TDualAllocator.Create(LSmall, LLarge, 1024);
    try
      LP := LAlloc.GetMem(1024);
      Check(LP <> nil, 'boundary allocation returned pointer');
      LAlloc.FreeMem(LP);

      LP := LAlloc.GetMem(1025);
      Check(LP <> nil, 'above-boundary allocation returned pointer');
      LAlloc.FreeMem(LP);
    finally
      LAlloc.Free;
    end;
  finally
    
    
  end;
end;

procedure TestGetMemZeroReturnsNil;
var
  LSmall, LLarge: IAllocator;
  LAlloc: TDualAllocator;
begin
  LSmall := DefaultAllocator;
  LLarge := DefaultAllocator;
  try
    LAlloc := TDualAllocator.Create(LSmall, LLarge, 1024);
    try
      Check(LAlloc.GetMem(0) = nil, 'GetMem(0) returns nil');
    finally
      LAlloc.Free;
    end;
  finally
    
    
  end;
end;

procedure TestFreeMemNilNoOp;
var
  LSmall, LLarge: IAllocator;
  LAlloc: TDualAllocator;
begin
  LSmall := DefaultAllocator;
  LLarge := DefaultAllocator;
  try
    LAlloc := TDualAllocator.Create(LSmall, LLarge, 1024);
    try
      LAlloc.FreeMem(nil);
      Check(True, 'FreeMem(nil) did not crash');
    finally
      LAlloc.Free;
    end;
  finally
    
    
  end;
end;

procedure TestAllocMemSmall;
var
  LSmall, LLarge: IAllocator;
  LAlloc: TDualAllocator;
  LP: Pointer;
  I: Integer;
begin
  LSmall := DefaultAllocator;
  LLarge := DefaultAllocator;
  try
    LAlloc := TDualAllocator.Create(LSmall, LLarge, 1024);
    try
      LP := LAlloc.AllocMem(256);
      Check(LP <> nil, 'AllocMem returned pointer');
      for I := 0 to 255 do
        Check(PByte(LP)[I] = 0, 'zero-initialized byte ' + IntToStr(I));
      LAlloc.FreeMem(LP);
    finally
      LAlloc.Free;
    end;
  finally
    
    
  end;
end;

procedure TestReallocMemSmall;
var
  LSmall, LLarge: IAllocator;
  LAlloc: TDualAllocator;
  LP: Pointer;
begin
  LSmall := DefaultAllocator;
  LLarge := DefaultAllocator;
  try
    LAlloc := TDualAllocator.Create(LSmall, LLarge, 1024);
    try
      LP := LAlloc.GetMem(32);
      Check(LP <> nil, 'GetMem returned pointer');
      LP := LAlloc.ReallocMem(LP, 64);
      Check(LP <> nil, 'ReallocMem returned pointer');
      LAlloc.FreeMem(LP);
    finally
      LAlloc.Free;
    end;
  finally
    
    
  end;
end;

procedure TestStats;
var
  LSmall, LLarge: IAllocator;
  LAlloc: TDualAllocator;
  LP: Pointer;
  LStats: TDualStats;
begin
  LSmall := DefaultAllocator;
  LLarge := DefaultAllocator;
  try
    LAlloc := TDualAllocator.Create(LSmall, LLarge, 1024);
    try
      LP := LAlloc.GetMem(512);
      LStats := LAlloc.GetStats;
      Check(LStats.SmallAllocCount >= 1, 'small alloc count >= 1');
      LAlloc.FreeMem(LP);

      LP := LAlloc.GetMem(2048);
      LStats := LAlloc.GetStats;
      Check(LStats.LargeAllocCount >= 1, 'large alloc count >= 1');
      LAlloc.FreeMem(LP);
    finally
      LAlloc.Free;
    end;
  finally
    
    
  end;
end;

procedure TestTraits;
var
  LSmall, LLarge: IAllocator;
  LAlloc: TDualAllocator;
  LTraits: TAllocatorTraits;
begin
  LSmall := DefaultAllocator;
  LLarge := DefaultAllocator;
  try
    LAlloc := TDualAllocator.Create(LSmall, LLarge, 1024);
    try
      LTraits := LAlloc.Traits;
      Check(not LTraits.SupportsRealloc, 'does not support realloc');
    finally
      LAlloc.Free;
    end;
  finally
    
    
  end;
end;

{ --- 注册 Register --- }

begin
  T := TTestSuite.Create('test_dual');
  T.Test('create_destroy', @TestCreateDestroy);
  T.Test('small_allocation', @TestSmallAllocation);
  T.Test('large_allocation', @TestLargeAllocation);
  T.Test('boundary_size', @TestBoundarySize);
  T.Test('getmem_zero_returns_nil', @TestGetMemZeroReturnsNil);
  T.Test('freemem_nil_noop', @TestFreeMemNilNoOp);
  T.Test('allocmem_small', @TestAllocMemSmall);
  T.Test('reallocmem_small', @TestReallocMemSmall);
  T.Test('stats', @TestStats);
  T.Test('traits', @TestTraits);
  LRunPassed := T.Run;
  T.Summary;
  if not LRunPassed then
    Halt(1);
end.
