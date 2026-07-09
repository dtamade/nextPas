program test_prefix_allocator;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.test,
  nextpas.core.text.conv,
  nextpas.core.mem.base,
  nextpas.core.mem.intf,
  nextpas.core.mem.allocator.base,
  nextpas.core.mem.allocator.foundation,
  nextpas.core.mem.allocator.prefix;

var
  T: TTestSuite;

procedure TestBasicAlloc;
var
  LAlloc: TPrefixAllocator;
  LPtr: Pointer;
begin
  LAlloc := TPrefixAllocator.Create(GetRtlAllocator);
  try
    LPtr := LAlloc.GetMem(64);
    Check(LPtr <> nil, 'allocated');
    LAlloc.FreeMem(LPtr);
  finally
    LAlloc.Free;
  end;
end;

procedure TestGetAllocationSize;
var
  LAlloc: TPrefixAllocator;
  LPtr: Pointer;
begin
  LAlloc := TPrefixAllocator.Create(GetRtlAllocator);
  try
    LPtr := LAlloc.GetMem(64);
    Check(LPtr <> nil, 'allocated');
    Check(LAlloc.GetAllocationSize(LPtr) = 64, 'size 64');
    LAlloc.FreeMem(LPtr);

    LPtr := LAlloc.GetMem(128);
    Check(LAlloc.GetAllocationSize(LPtr) = 128, 'size 128');
    LAlloc.FreeMem(LPtr);
  finally
    LAlloc.Free;
  end;
end;

procedure TestMultipleSizes;
var
  LAlloc: TPrefixAllocator;
  LPtrs: array[0..3] of Pointer;
  LSizes: array[0..3] of SizeUInt;
  LIdx: Integer;
begin
  LAlloc := TPrefixAllocator.Create(GetRtlAllocator);
  try
    LSizes[0] := 16;
    LSizes[1] := 32;
    LSizes[2] := 64;
    LSizes[3] := 128;

    for LIdx := 0 to 3 do
    begin
      LPtrs[LIdx] := LAlloc.GetMem(LSizes[LIdx]);
      Check(LPtrs[LIdx] <> nil, 'alloc ' + IntToStr(LIdx));
      Check(LAlloc.GetAllocationSize(LPtrs[LIdx]) = LSizes[LIdx],
        'size match ' + IntToStr(LIdx));
    end;

    for LIdx := 0 to 3 do
      LAlloc.FreeMem(LPtrs[LIdx]);
  finally
    LAlloc.Free;
  end;
end;

procedure TestAllocMemZeroed;
var
  LAlloc: TPrefixAllocator;
  LPtr: Pointer;
  LIdx: Integer;
begin
  LAlloc := TPrefixAllocator.Create(GetRtlAllocator);
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

procedure TestStats;
var
  LAlloc: TPrefixAllocator;
  LStats: TPrefixStats;
begin
  LAlloc := TPrefixAllocator.Create(GetRtlAllocator);
  try
    LAlloc.GetMem(64);
    LAlloc.GetMem(32);

    LStats := LAlloc.GetStats;
    Check(LStats.AllocCount >= 2, 'allocs');
    Check(LStats.ActiveAllocs >= 2, 'active');
    Check(LStats.TotalBytes >= 96, 'total bytes');

    LAlloc.FreeMem(nil); // no-op
    LStats := LAlloc.GetStats;
    Check(LStats.FreeCount >= 0, 'frees');
  finally
    LAlloc.Free;
  end;
end;

procedure TestRealloc;
var
  LAlloc: TPrefixAllocator;
  LPtr, LNewPtr: Pointer;
begin
  LAlloc := TPrefixAllocator.Create(GetRtlAllocator);
  try
    LPtr := LAlloc.GetMem(32);
    PByte(LPtr)^ := $BB;
    Check(LAlloc.GetAllocationSize(LPtr) = 32, 'orig size');

    LNewPtr := LAlloc.ReallocMem(LPtr, 128);
    Check(LNewPtr <> nil, 'realloc ok');
    Check(LAlloc.GetAllocationSize(LNewPtr) = 128, 'new size');
    Check(PByte(LNewPtr)^ = $BB, 'data preserved');
    LAlloc.FreeMem(LNewPtr);
  finally
    LAlloc.Free;
  end;
end;

procedure TestNilSize;
var
  LAlloc: TPrefixAllocator;
begin
  LAlloc := TPrefixAllocator.Create(GetRtlAllocator);
  try
    Check(LAlloc.GetAllocationSize(nil) = 0, 'nil returns 0');
  finally
    LAlloc.Free;
  end;
end;

begin
  T := TTestSuite.Create('test_prefix_allocator');
  T.Test('BasicAlloc', @TestBasicAlloc);
  T.Test('GetAllocationSize', @TestGetAllocationSize);
  T.Test('MultipleSizes', @TestMultipleSizes);
  T.Test('AllocMemZeroed', @TestAllocMemZeroed);
  T.Test('Stats', @TestStats);
  T.Test('Realloc', @TestRealloc);
  T.Test('NilSize', @TestNilSize);
  T.Run;
  T.Summary;
end.
