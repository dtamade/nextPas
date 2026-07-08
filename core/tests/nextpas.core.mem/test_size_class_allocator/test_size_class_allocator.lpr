program test_size_class_allocator;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.test,
  nextpas.core.text.conv,
  nextpas.core.mem.base,
  nextpas.core.mem.intf,
  nextpas.core.mem.allocator.base,
  nextpas.core.mem.allocator.foundation,
  nextpas.core.mem.allocator.size_class;

var
  T: TTestSuite;

procedure TestBasicAlloc;
var
  LAlloc: TSizeClassAllocator;
  LPtr: Pointer;
begin
  LAlloc := TSizeClassAllocator.Create(GetRtlAllocator);
  try
    LPtr := LAlloc.GetMem(32);
    Check(LPtr <> nil, 'allocated');
    LAlloc.FreeMem(LPtr);
  finally
    LAlloc.Free;
  end;
end;

procedure TestSizeClasses;
var
  LAlloc: TSizeClassAllocator;
  LPtrs: array[0..15] of Pointer;
  LIdx: Integer;
begin
  LAlloc := TSizeClassAllocator.Create(GetRtlAllocator);
  try
    // Allocate one from each size class
    for LIdx := 0 to 15 do
    begin
      LPtrs[LIdx] := LAlloc.GetMem(8 shl LIdx);
      Check(LPtrs[LIdx] <> nil, 'class ' + IntToStr(LIdx));
    end;
    for LIdx := 0 to 15 do
      LAlloc.FreeMem(LPtrs[LIdx]);
  finally
    LAlloc.Free;
  end;
end;

procedure TestFreelistRecycle;
var
  LAlloc: TSizeClassAllocator;
  LPtr1, LPtr2: Pointer;
begin
  LAlloc := TSizeClassAllocator.Create(GetRtlAllocator);
  try
    LPtr1 := LAlloc.GetMem(32);
    LAlloc.FreeMem(LPtr1);

    LPtr2 := LAlloc.GetMem(32);
    Check(LPtr2 <> nil, 'recycled');
    // Should reuse same slot
    Check(LPtr1 = LPtr2, 'same slot');
    LAlloc.FreeMem(LPtr2);
  finally
    LAlloc.Free;
  end;
end;

procedure TestAllocMemZeroed;
var
  LAlloc: TSizeClassAllocator;
  LPtr: Pointer;
  LIdx: Integer;
begin
  LAlloc := TSizeClassAllocator.Create(GetRtlAllocator);
  try
    LPtr := LAlloc.AllocMem(64);
    Check(LPtr <> nil, 'allocated');
    for LIdx := 0 to 63 do
      CheckEqual(PByte(LPtr)[LIdx], Byte(0), 'zeroed');
    LAlloc.FreeMem(LPtr);
  finally
    LAlloc.Free;
  end;
end;

procedure TestLargeAlloc;
var
  LAlloc: TSizeClassAllocator;
  LPtr: Pointer;
begin
  LAlloc := TSizeClassAllocator.Create(GetRtlAllocator);
  try
    // Larger than max size class (64KB)
    LPtr := LAlloc.GetMem(128 * 1024);
    Check(LPtr <> nil, 'large alloc');
    LAlloc.FreeMem(LPtr);
  finally
    LAlloc.Free;
  end;
end;

procedure TestStats;
var
  LAlloc: TSizeClassAllocator;
  LStats: TSizeClassStats;
begin
  LAlloc := TSizeClassAllocator.Create(GetRtlAllocator);
  try
    LAlloc.GetMem(8);
    LAlloc.GetMem(16);
    LAlloc.GetMem(32);
    // Max class = 8 * 2^15 = 256KB; use 512KB to be "large"
    LAlloc.GetMem(512 * 1024);

    LStats := LAlloc.GetStats;
    Check(LStats.TotalAlloc >= 4, 'total allocs');
    Check(LStats.LargeAllocCount >= 1, 'large alloc');
  finally
    LAlloc.Free;
  end;
end;

procedure TestRealloc;
var
  LAlloc: TSizeClassAllocator;
  LPtr, LNewPtr: Pointer;
begin
  LAlloc := TSizeClassAllocator.Create(GetRtlAllocator);
  try
    LPtr := LAlloc.GetMem(16);
    PByte(LPtr)^ := $DD;

    LNewPtr := LAlloc.ReallocMem(LPtr, 64);
    Check(LNewPtr <> nil, 'realloc ok');
    Check(PByte(LNewPtr)^ = $DD, 'data preserved');
    LAlloc.FreeMem(LNewPtr);
  finally
    LAlloc.Free;
  end;
end;

begin
  T := TTestSuite.Create('test_size_class_allocator');
  T.Test('BasicAlloc', @TestBasicAlloc);
  T.Test('SizeClasses', @TestSizeClasses);
  T.Test('FreelistRecycle', @TestFreelistRecycle);
  T.Test('AllocMemZeroed', @TestAllocMemZeroed);
  T.Test('LargeAlloc', @TestLargeAlloc);
  T.Test('Stats', @TestStats);
  T.Test('Realloc', @TestRealloc);
  T.Run;
  T.Summary;
end.
