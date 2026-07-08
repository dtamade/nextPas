{ nextpas - test: aligned allocator }

{$I nextpas.core.settings.inc}

program test_aligned;

uses
  nextpas.core.text.conv,
  nextpas.core.test,
  nextpas.core.mem.base,
  nextpas.core.mem.intf,
  nextpas.core.mem.default,
  nextpas.core.mem.allocator.base,
  nextpas.core.mem.allocator.aligned;

var
  T: TTestSuite;

procedure TestBasicAlloc;
var
  LAlloc: TAlignedAllocator;
  LPtr1, LPtr2: Pointer;
begin
  LAlloc := TAlignedAllocator.Create(DefaultAllocator, 64);
  try
    LPtr1 := LAlloc.GetMem(64);
    Assert(LPtr1 <> nil, 'alloc 64B');
    LPtr2 := LAlloc.GetMem(128);
    Assert(LPtr2 <> nil, 'alloc 128B');
    Assert(LPtr1 <> LPtr2, 'different pointers');
    LAlloc.FreeMem(LPtr1);
    LAlloc.FreeMem(LPtr2);
  finally
    LAlloc.Free;
  end;
end;

procedure TestZeroReturnsNil;
var
  LAlloc: TAlignedAllocator;
begin
  LAlloc := TAlignedAllocator.Create(DefaultAllocator, 64);
  try
    Assert(LAlloc.GetMem(0) = nil, 'zero alloc returns nil');
  finally
    LAlloc.Free;
  end;
end;

procedure TestAlignment64;
var
  LAlloc: TAlignedAllocator;
  LPtr: Pointer;
begin
  LAlloc := TAlignedAllocator.Create(DefaultAllocator, 64);
  try
    LPtr := LAlloc.GetMem(100);
    Assert(LPtr <> nil, 'alloc');
    Assert(SizeUInt(LPtr) mod 64 = 0, '64B aligned');
    LAlloc.FreeMem(LPtr);
  finally
    LAlloc.Free;
  end;
end;

procedure TestAlignment256;
var
  LAlloc: TAlignedAllocator;
  LPtr: Pointer;
begin
  LAlloc := TAlignedAllocator.Create(DefaultAllocator, 256);
  try
    LPtr := LAlloc.GetMem(100);
    Assert(LPtr <> nil, 'alloc');
    Assert(SizeUInt(LPtr) mod 256 = 0, '256B aligned');
    LAlloc.FreeMem(LPtr);
  finally
    LAlloc.Free;
  end;
end;

procedure TestAlignment4096;
var
  LAlloc: TAlignedAllocator;
  LPtr: Pointer;
begin
  LAlloc := TAlignedAllocator.Create(DefaultAllocator, 4096);
  try
    LPtr := LAlloc.GetMem(100);
    Assert(LPtr <> nil, 'alloc');
    Assert(SizeUInt(LPtr) mod 4096 = 0, '4KB aligned');
    LAlloc.FreeMem(LPtr);
  finally
    LAlloc.Free;
  end;
end;

procedure TestStats;
var
  LAlloc: TAlignedAllocator;
  LStats: TAlignedStats;
begin
  LAlloc := TAlignedAllocator.Create(DefaultAllocator, 64);
  try
    LAlloc.GetMem(100);
    LStats := LAlloc.GetStats;
    Assert(LStats.AllocCount = 1, 'alloc count = 1');
    Assert(LStats.ActiveAllocs = 1, 'active = 1');
    Assert(LStats.Alignment = 64, 'alignment = 64');
    LAlloc.FreeMem(LAlloc.GetMem(100));
  finally
    LAlloc.Free;
  end;
end;

procedure TestMultipleAligned;
var
  LAlloc: TAlignedAllocator;
  LPtrs: array[0..9] of Pointer;
  I: Integer;
begin
  LAlloc := TAlignedAllocator.Create(DefaultAllocator, 128);
  try
    for I := 0 to 9 do
    begin
      LPtrs[I] := LAlloc.GetMem(64);
      Assert(LPtrs[I] <> nil, 'alloc #' + IntToStr(I));
      Assert(SizeUInt(LPtrs[I]) mod 128 = 0, 'aligned #' + IntToStr(I));
    end;
    for I := 0 to 9 do
      LAlloc.FreeMem(LPtrs[I]);
  finally
    LAlloc.Free;
  end;
end;

begin
  T := TTestSuite.Create('test_aligned');
  T.Test('basic_alloc', @TestBasicAlloc);
  T.Test('zero_returns_nil', @TestZeroReturnsNil);
  T.Test('alignment_64', @TestAlignment64);
  T.Test('alignment_256', @TestAlignment256);
  T.Test('alignment_4096', @TestAlignment4096);
  T.Test('stats', @TestStats);
  T.Test('multiple_aligned', @TestMultipleAligned);
  T.Run;
  T.Summary;
end.
