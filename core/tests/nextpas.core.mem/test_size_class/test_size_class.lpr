{ nextpas - test: size-class allocator }

{$I nextpas.core.settings.inc}

program test_size_class;

uses
  nextpas.core.text.conv,
  nextpas.core.test,
  nextpas.core.mem.base,
  nextpas.core.mem.intf,
  nextpas.core.mem.default,
  nextpas.core.mem.allocator.base,
  nextpas.core.mem.allocator.size_class;

procedure Test_BasicAlloc;
var
  LAlloc: TSizeClassAllocator;
  LPtr1, LPtr2: Pointer;
begin
  LAlloc := TSizeClassAllocator.Create(DefaultAllocator);
  try
    LPtr1 := LAlloc.GetMem(8);
    Assert(LPtr1 <> nil, 'alloc 8B');
    LPtr2 := LAlloc.GetMem(16);
    Assert(LPtr2 <> nil, 'alloc 16B');
    Assert(LPtr1 <> LPtr2, 'different pointers');
  finally
    LAlloc.Free;
  end;
end;

procedure Test_ZeroReturnsNil;
var
  LAlloc: TSizeClassAllocator;
begin
  LAlloc := TSizeClassAllocator.Create(DefaultAllocator);
  try
    Assert(LAlloc.GetMem(0) = nil, 'zero alloc returns nil');
  finally
    LAlloc.Free;
  end;
end;

procedure Test_AllSizeClasses;
var
  LAlloc: TSizeClassAllocator;
  LSize: SizeUInt;
  LPtr: Pointer;
begin
  LAlloc := TSizeClassAllocator.Create(DefaultAllocator);
  try
    LSize := 4;
    while LSize <= 32768 do
    begin
      LPtr := LAlloc.GetMem(LSize);
      Assert(LPtr <> nil, 'alloc ' + IntToStr(LSize) + 'B');
      LSize := LSize * 2;
    end;
  finally
    LAlloc.Free;
  end;
end;

procedure Test_FreeAndReuse;
var
  LAlloc: TSizeClassAllocator;
  LPtr1, LPtr2: Pointer;
begin
  LAlloc := TSizeClassAllocator.Create(DefaultAllocator);
  try
    LPtr1 := LAlloc.GetMem(64);
    Assert(LPtr1 <> nil, 'alloc 64B');
    LAlloc.FreeMem(LPtr1);
    LPtr2 := LAlloc.GetMem(64);
    Assert(LPtr2 <> nil, 'reuse freed block');
  finally
    LAlloc.Free;
  end;
end;

procedure Test_LargeObjectDelegation;
var
  LAlloc: TSizeClassAllocator;
  LPtr: Pointer;
  LStats: TSizeClassStats;
begin
  LAlloc := TSizeClassAllocator.Create(DefaultAllocator);
  try
    LPtr := LAlloc.GetMem(131072);
    Assert(LPtr <> nil, 'large alloc succeeds');
    LStats := LAlloc.GetStats;
    Assert(LStats.LargeAllocCount >= 1, 'delegated to inner');
  finally
    LAlloc.Free;
  end;
end;

procedure Test_Stats;
var
  LAlloc: TSizeClassAllocator;
  LStats: TSizeClassStats;
begin
  LAlloc := TSizeClassAllocator.Create(DefaultAllocator);
  try
    LAlloc.GetMem(8);
    LAlloc.GetMem(16);
    LAlloc.GetMem(64);
    LStats := LAlloc.GetStats;
    Assert(LStats.TotalAlloc >= 3, 'total alloc >= 3');
    Assert(LStats.ClassSizes[0] = 8, 'class 0 = 8B');
    Assert(LStats.ClassSizes[1] = 16, 'class 1 = 16B');
  finally
    LAlloc.Free;
  end;
end;

procedure Test_ManyAllocations;
var
  LAlloc: TSizeClassAllocator;
  LPtrs: array[0..99] of Pointer;
  I: Integer;
begin
  LAlloc := TSizeClassAllocator.Create(DefaultAllocator);
  try
    for I := 0 to 99 do
    begin
      LPtrs[I] := LAlloc.GetMem(32);
      Assert(LPtrs[I] <> nil, 'alloc #' + IntToStr(I));
    end;
    for I := 0 to 49 do
      LAlloc.FreeMem(LPtrs[I]);
    for I := 0 to 49 do
    begin
      LPtrs[I] := LAlloc.GetMem(32);
      Assert(LPtrs[I] <> nil, 'realloc #' + IntToStr(I));
    end;
  finally
    LAlloc.Free;
  end;
end;

var T: TTestSuite;
begin
  T := TTestSuite.Create('test_size_class');
  T.Test('basic_alloc', @Test_BasicAlloc);
  T.Test('zero_returns_nil', @Test_ZeroReturnsNil);
  T.Test('all_size_classes', @Test_AllSizeClasses);
  T.Test('free_and_reuse', @Test_FreeAndReuse);
  T.Test('large_object_delegation', @Test_LargeObjectDelegation);
  T.Test('stats', @Test_Stats);
  T.Test('many_allocations', @Test_ManyAllocations);
  T.Run;
  T.Summary;
end.
