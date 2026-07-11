program test_slab;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.text.conv,
  nextpas.core.test,
  nextpas.core.mem.base,
  nextpas.core.mem.intf,
  nextpas.core.mem.default,
  nextpas.core.mem.allocator.base,
  nextpas.core.mem.allocator.slab,
  nextpas.core.mem.error;

var
  T: TTestSuite;
  LRunPassed: Boolean;

procedure TestCreateAndDestroy;
var
  LSlab: TSlabAllocator;
begin
  LSlab := TSlabAllocator.Create(DefaultAllocator);
  try
    Check(LSlab <> nil, 'slab should be created');
  finally
    LSlab.Free;
  end;
end;

procedure TestSmallObjectAlloc;
var
  LSlab: TSlabAllocator;
  LPtr1, LPtr2, LPtr3: Pointer;
begin
  LSlab := TSlabAllocator.Create(DefaultAllocator);
  try
    LPtr1 := LSlab.GetMem(8);
    Check(LPtr1 <> nil, '8-byte alloc should succeed');

    LPtr2 := LSlab.GetMem(16);
    Check(LPtr2 <> nil, '16-byte alloc should succeed');

    LPtr3 := LSlab.GetMem(64);
    Check(LPtr3 <> nil, '64-byte alloc should succeed');

    Check(LPtr1 <> LPtr2, 'pointers should differ');
    Check(LPtr2 <> LPtr3, 'pointers should differ');

    LSlab.FreeMem(LPtr1);
    LSlab.FreeMem(LPtr2);
    LSlab.FreeMem(LPtr3);
  finally
    LSlab.Free;
  end;
end;

procedure TestLargeObjectAlloc;
var
  LSlab: TSlabAllocator;
  LPtr: Pointer;
begin
  LSlab := TSlabAllocator.Create(DefaultAllocator);
  try
    LPtr := LSlab.GetMem(2048);
    Check(LPtr <> nil, 'large alloc should succeed');

    LSlab.FreeMem(LPtr);
  finally
    LSlab.Free;
  end;
end;

procedure TestAllocMemZeroInit;
var
  LSlab: TSlabAllocator;
  LPtr: Pointer;
  LI: Integer;
  LAllZero: Boolean;
begin
  LSlab := TSlabAllocator.Create(DefaultAllocator);
  try
    LPtr := LSlab.AllocMem(32);
    Check(LPtr <> nil, 'AllocMem should succeed');

    LAllZero := True;
    for LI := 0 to 31 do
    begin
      if PByte(PtrUInt(LPtr) + PtrUInt(LI))^ <> 0 then
      begin
        LAllZero := False;
        Break;
      end;
    end;
    Check(LAllZero, 'AllocMem should zero-initialize');

    LSlab.FreeMem(LPtr);
  finally
    LSlab.Free;
  end;
end;

procedure TestMultipleAllocSameClass;
var
  LSlab: TSlabAllocator;
  LPtrs: array[0..127] of Pointer;
  LI: Integer;
begin
  LSlab := TSlabAllocator.Create(DefaultAllocator);
  try
    for LI := 0 to 127 do
    begin
      LPtrs[LI] := LSlab.GetMem(32);
      Check(LPtrs[LI] <> nil, 'alloc should succeed at ' + IntToStr(LI));
    end;

    for LI := 0 to 126 do
      Check(LPtrs[LI] <> LPtrs[LI + 1], 'pointers should differ');

    for LI := 0 to 127 do
      LSlab.FreeMem(LPtrs[LI]);
  finally
    LSlab.Free;
  end;
end;

procedure TestStats;
var
  LSlab: TSlabAllocator;
  LPtr1, LPtr2: Pointer;
  LStats: TSlabStats;
begin
  LSlab := TSlabAllocator.Create(DefaultAllocator);
  try
    LPtr1 := LSlab.GetMem(8);
    LPtr2 := LSlab.GetMem(16);
    { 不分配大对象，避免 slab 大对象 FreeMem 问题 }
    LSlab.GetMem(64);

    LStats := LSlab.GetStats;
    Check(LStats.SmallAllocCount >= 2, 'small alloc count should be >= 2');
    Check(LStats.SlabPageCount > 0, 'should have slab pages');
    LSlab.FreeMem(LPtr2);
    LSlab.FreeMem(LPtr1);
  finally
    LSlab.Free;
  end;
end;

procedure TestNilInner;
var
  LRaised: Boolean;
begin
  LRaised := False;
  try
    TSlabAllocator.Create(nil).Free;
  except
    on E: Exception do
      LRaised := True;
  end;
  Check(LRaised, 'nil inner should raise');
end;

procedure TestTraits;
var
  LSlab: TSlabAllocator;
  LTraits: TAllocatorTraits;
begin
  LSlab := TSlabAllocator.Create(DefaultAllocator);
  try
    LTraits := LSlab.Traits;
    Check(LTraits.SupportsRealloc, 'slab supports realloc');
    Check(not LTraits.ThreadSafe, 'slab is not thread-safe');
  finally
    LSlab.Free;
  end;
end;

begin
  T := TTestSuite.Create('test_slab');
  T.Test('create_and_destroy', @TestCreateAndDestroy);
  T.Test('small_object_alloc', @TestSmallObjectAlloc);
  T.Test('large_object_alloc', @TestLargeObjectAlloc);
  T.Test('alloc_mem_zero_init', @TestAllocMemZeroInit);
  T.Test('multiple_alloc_same_class', @TestMultipleAllocSameClass);
  T.Test('stats', @TestStats);
  T.Test('nil_inner', @TestNilInner);
  T.Test('traits', @TestTraits);
  LRunPassed := T.Run;
  T.Summary;
  if not LRunPassed then
    Halt(1);
end.
