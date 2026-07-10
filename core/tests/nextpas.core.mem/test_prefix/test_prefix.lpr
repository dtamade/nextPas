{ nextpas - test: prefix allocator }

{$I nextpas.core.settings.inc}

program test_prefix;

uses
  nextpas.core.text.conv,
  nextpas.core.test,
  nextpas.core.mem.base,
  nextpas.core.mem.intf,
  nextpas.core.mem.default,
  nextpas.core.mem.allocator.base,
  nextpas.core.mem.allocator.prefix;

var
  T: TTestSuite;
  LRunPassed: Boolean;

procedure TestBasicAlloc;
var
  LAlloc: TPrefixAllocator;
  LPtr1, LPtr2: Pointer;
begin
  LAlloc := TPrefixAllocator.Create(DefaultAllocator);
  try
    LPtr1 := LAlloc.GetMem(64);
    Check(LPtr1 <> nil, 'alloc 64B');
    LPtr2 := LAlloc.GetMem(128);
    Check(LPtr2 <> nil, 'alloc 128B');
    Check(LPtr1 <> LPtr2, 'different pointers');
    LAlloc.FreeMem(LPtr1);
    LAlloc.FreeMem(LPtr2);
  finally
    LAlloc.Free;
  end;
end;

procedure TestZeroReturnsNil;
var
  LAlloc: TPrefixAllocator;
begin
  LAlloc := TPrefixAllocator.Create(DefaultAllocator);
  try
    Check(LAlloc.GetMem(0) = nil, 'zero alloc returns nil');
  finally
    LAlloc.Free;
  end;
end;

procedure TestGetAllocationSize;
var
  LAlloc: TPrefixAllocator;
  LPtr: Pointer;
begin
  LAlloc := TPrefixAllocator.Create(DefaultAllocator);
  try
    LPtr := LAlloc.GetMem(100);
    Check(LAlloc.GetAllocationSize(LPtr) = 100, 'size = 100');
    LAlloc.FreeMem(LPtr);
  finally
    LAlloc.Free;
  end;
end;

procedure TestMultipleSizes;
var
  LAlloc: TPrefixAllocator;
  LPtrs: array[0..4] of Pointer;
  LSizes: array[0..4] of SizeUInt;
  I: Integer;
begin
  LAlloc := TPrefixAllocator.Create(DefaultAllocator);
  try
    LSizes[0] := 8;
    LSizes[1] := 16;
    LSizes[2] := 32;
    LSizes[3] := 64;
    LSizes[4] := 128;

    for I := 0 to 4 do
    begin
      LPtrs[I] := LAlloc.GetMem(LSizes[I]);
      Check(LPtrs[I] <> nil, 'alloc #' + IntToStr(I));
    end;

    for I := 0 to 4 do
      Check(LAlloc.GetAllocationSize(LPtrs[I]) = LSizes[I],
        'size match #' + IntToStr(I));

    for I := 0 to 4 do
      LAlloc.FreeMem(LPtrs[I]);
  finally
    LAlloc.Free;
  end;
end;

procedure TestNilSize;
var
  LAlloc: TPrefixAllocator;
begin
  LAlloc := TPrefixAllocator.Create(DefaultAllocator);
  try
    Check(LAlloc.GetAllocationSize(nil) = 0, 'nil size = 0');
  finally
    LAlloc.Free;
  end;
end;

procedure TestStats;
var
  LAlloc: TPrefixAllocator;
  LStats: TPrefixStats;
  LPtr: Pointer;
begin
  LAlloc := TPrefixAllocator.Create(DefaultAllocator);
  try
    LPtr := LAlloc.GetMem(100);
    LStats := LAlloc.GetStats;
    Check(LStats.AllocCount = 1, 'alloc count = 1');
    Check(LStats.ActiveAllocs = 1, 'active = 1');
    Check(LStats.TotalBytes = 100, 'total bytes = 100');

    LAlloc.FreeMem(LPtr);
    LStats := LAlloc.GetStats;
    Check(LStats.FreeCount = 1, 'free count = 1');
    Check(LStats.ActiveAllocs = 0, 'active = 0');
    Check(LStats.TotalBytes = 0, 'total bytes = 0');
  finally
    LAlloc.Free;
  end;
end;

procedure TestReallocGrowth;
var
  LAlloc: TPrefixAllocator;
  LPtr: Pointer;
begin
  LAlloc := TPrefixAllocator.Create(DefaultAllocator);
  try
    LPtr := LAlloc.GetMem(64);
    Check(LAlloc.GetAllocationSize(LPtr) = 64, 'initial size = 64');
    LPtr := LAlloc.ReallocMem(LPtr, 256);
    Check(LAlloc.GetAllocationSize(LPtr) = 256, 'after realloc = 256');
    LAlloc.FreeMem(LPtr);
  finally
    LAlloc.Free;
  end;
end;

begin
  T := TTestSuite.Create('test_prefix');
  T.Test('basic_alloc', @TestBasicAlloc);
  T.Test('zero_returns_nil', @TestZeroReturnsNil);
  T.Test('get_allocation_size', @TestGetAllocationSize);
  T.Test('multiple_sizes', @TestMultipleSizes);
  T.Test('nil_size', @TestNilSize);
  T.Test('stats', @TestStats);
  T.Test('realloc_growth', @TestReallocGrowth);
  LRunPassed := T.Run;
  T.Summary;
  if not LRunPassed then
    Halt(1);
end.
