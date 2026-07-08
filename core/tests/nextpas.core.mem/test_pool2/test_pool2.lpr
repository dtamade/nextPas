{ nextpas - test: pool2 allocator }

{$I nextpas.core.settings.inc}

program test_pool2;

uses
  nextpas.core.text.conv,
  nextpas.core.test,
  nextpas.core.mem.base,
  nextpas.core.mem.intf,
  nextpas.core.mem.default,
  nextpas.core.mem.allocator.base,
  nextpas.core.mem.allocator.pool2;

procedure Test_BasicAlloc;
var
  LPool: TPool2Allocator;
  LPtr1, LPtr2: Pointer;
begin
  LPool := TPool2Allocator.Create(DefaultAllocator, 64);
  try
    LPtr1 := LPool.GetMem(32);
    Assert(LPtr1 <> nil, 'alloc 32B');
    LPtr2 := LPool.GetMem(64);
    Assert(LPtr2 <> nil, 'alloc 64B');
    Assert(LPtr1 <> LPtr2, 'different pointers');
  finally
    LPool.Free;
  end;
end;

procedure Test_ZeroReturnsNil;
var
  LPool: TPool2Allocator;
begin
  LPool := TPool2Allocator.Create(DefaultAllocator, 64);
  try
    Assert(LPool.GetMem(0) = nil, 'zero alloc returns nil');
  finally
    LPool.Free;
  end;
end;

procedure Test_ExceedBlockSizeReturnsNil;
var
  LPool: TPool2Allocator;
begin
  LPool := TPool2Allocator.Create(DefaultAllocator, 64);
  try
    Assert(LPool.GetMem(128) = nil, 'oversized alloc returns nil');
  finally
    LPool.Free;
  end;
end;

procedure Test_FreeAndRealloc;
var
  LPool: TPool2Allocator;
  LPtr1, LPtr2: Pointer;
begin
  LPool := TPool2Allocator.Create(DefaultAllocator, 128);
  try
    LPtr1 := LPool.GetMem(100);
    Assert(LPtr1 <> nil, 'alloc');
    LPool.FreeMem(LPtr1);
    LPtr2 := LPool.GetMem(100);
    Assert(LPtr2 <> nil, 'reuses freed block');
  finally
    LPool.Free;
  end;
end;

procedure Test_DoubleFreeDetection;
var
  LPool: TPool2Allocator;
  LPtr: Pointer;
  LStats: TPool2Stats;
begin
  LPool := TPool2Allocator.Create(DefaultAllocator, 64);
  try
    LPtr := LPool.GetMem(32);
    LPool.FreeMem(LPtr);
    LPool.FreeMem(LPtr);
    LStats := LPool.GetStats;
    Assert(LStats.DoubleFreeDetected >= 1, 'double free detected');
  finally
    LPool.Free;
  end;
end;

procedure Test_Stats;
var
  LPool: TPool2Allocator;
  LStats: TPool2Stats;
begin
  LPool := TPool2Allocator.Create(DefaultAllocator, 64, 16, 32);
  try
    LPool.GetMem(32);
    LPool.GetMem(32);
    LStats := LPool.GetStats;
    Assert(LStats.AllocCount = 2, 'alloc count = 2');
    Assert(LStats.TotalBlocks >= 32, 'total blocks >= 32');
    Assert(LStats.FreeBlocks >= 30, 'free blocks >= 30');
    Assert(LStats.BlockSize = 64, 'block size = 64');
  finally
    LPool.Free;
  end;
end;

procedure Test_CustomAlignment;
var
  LPool: TPool2Allocator;
  LPtr: Pointer;
begin
  LPool := TPool2Allocator.Create(DefaultAllocator, 64, 64);
  try
    LPtr := LPool.GetMem(32);
    Assert(LPtr <> nil, 'alloc with 64B alignment');
    Assert(SizeUInt(LPtr) mod 64 = 0, 'pointer is 64B aligned');
  finally
    LPool.Free;
  end;
end;

var T: TTestSuite;
begin
  T := TTestSuite.Create('test_pool2');
  T.Test('basic_alloc', @Test_BasicAlloc);
  T.Test('zero_returns_nil', @Test_ZeroReturnsNil);
  T.Test('exceed_block_returns_nil', @Test_ExceedBlockSizeReturnsNil);
  T.Test('free_and_realloc', @Test_FreeAndRealloc);
  T.Test('double_free_detection', @Test_DoubleFreeDetection);
  T.Test('stats', @Test_Stats);
  T.Test('custom_alignment', @Test_CustomAlignment);
  T.Run;
  T.Summary;
end.
