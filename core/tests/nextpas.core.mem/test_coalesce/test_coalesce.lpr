program test_coalesce;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.text.conv,
  nextpas.core.test,
  nextpas.core.mem.base,
  nextpas.core.mem.intf,
  nextpas.core.mem.default,
  nextpas.core.mem.allocator.base,
  nextpas.core.mem.allocator.coalesce,
  nextpas.core.mem.error;

var
  T: TTestSuite;

procedure TestCreateAndDestroy;
var
  LCoalesce: TCoalesceAllocator;
begin
  LCoalesce := TCoalesceAllocator.Create(DefaultAllocator);
  try
    Check(LCoalesce.UsedBytes = 0, 'initial used should be 0');
    Check(LCoalesce.FreeBytes > 0, 'should have free bytes');
  finally
    LCoalesce.Free;
  end;
end;

procedure TestBasicAllocAndFree;
var
  LCoalesce: TCoalesceAllocator;
  LPtr1, LPtr2: Pointer;
  LUsedBefore: SizeUInt;
begin
  LCoalesce := TCoalesceAllocator.Create(DefaultAllocator);
  try
    LPtr1 := LCoalesce.GetMem(128);
    Check(LPtr1 <> nil, 'first alloc should succeed');

    LPtr2 := LCoalesce.GetMem(256);
    Check(LPtr2 <> nil, 'second alloc should succeed');
    Check(LCoalesce.UsedBytes > 0, 'used should increase');

    LUsedBefore := LCoalesce.UsedBytes;
    LCoalesce.FreeMem(LPtr1);
    Check(LCoalesce.UsedBytes < LUsedBefore, 'used should decrease after free');

    LCoalesce.FreeMem(LPtr2);
  finally
    LCoalesce.Free;
  end;
end;

procedure TestAllocMemZeroInit;
var
  LCoalesce: TCoalesceAllocator;
  LPtr: Pointer;
  LI: Integer;
  LAllZero: Boolean;
begin
  LCoalesce := TCoalesceAllocator.Create(DefaultAllocator);
  try
    LPtr := LCoalesce.AllocMem(64);
    Check(LPtr <> nil, 'AllocMem should succeed');

    LAllZero := True;
    for LI := 0 to 63 do
    begin
      if PByte(PtrUInt(LPtr) + PtrUInt(LI))^ <> 0 then
      begin
        LAllZero := False;
        Break;
      end;
    end;
    Check(LAllZero, 'AllocMem should zero-initialize');

    LCoalesce.FreeMem(LPtr);
  finally
    LCoalesce.Free;
  end;
end;

procedure TestMerge;
var
  LCoalesce: TCoalesceAllocator;
  LPtrs: array[0..3] of Pointer;
  LStats: TCoalesceStats;
  LI: Integer;
begin
  LCoalesce := TCoalesceAllocator.Create(DefaultAllocator);
  try
    for LI := 0 to 3 do
    begin
      LPtrs[LI] := LCoalesce.GetMem(128);
      Check(LPtrs[LI] <> nil, 'alloc should succeed');
    end;

    for LI := 0 to 3 do
      LCoalesce.FreeMem(LPtrs[LI]);

    LStats := LCoalesce.GetStats;
    Check(LStats.MergeCount > 0, 'should have merged blocks');
    Check(LStats.FreeCount = 4, 'free count should be 4');
  finally
    LCoalesce.Free;
  end;
end;

procedure TestGrowRegion;
var
  LCoalesce: TCoalesceAllocator;
  LPtr: Pointer;
  LRegionsBefore: UInt64;
  LStats: TCoalesceStats;
begin
  LCoalesce := TCoalesceAllocator.Create(DefaultAllocator, 1024);
  try
    LStats := LCoalesce.GetStats;
    LRegionsBefore := LStats.RegionCount;

    LPtr := LCoalesce.GetMem(800);
    Check(LPtr <> nil, 'large alloc should succeed');

    LPtr := LCoalesce.GetMem(800);
    Check(LPtr <> nil, 'second alloc should succeed');

    LStats := LCoalesce.GetStats;
    Check(LStats.RegionCount > LRegionsBefore, 'should have added regions');

    LCoalesce.FreeMem(LPtr);
  finally
    LCoalesce.Free;
  end;
end;

procedure TestRealloc;
var
  LCoalesce: TCoalesceAllocator;
  LPtr, LNewPtr: Pointer;
  LI: Integer;
begin
  LCoalesce := TCoalesceAllocator.Create(DefaultAllocator);
  try
    LPtr := LCoalesce.GetMem(64);
    Check(LPtr <> nil, 'alloc should succeed');

    for LI := 0 to 63 do
      PByte(PtrUInt(LPtr) + PtrUInt(LI))^ := Byte(LI and $FF);

    LNewPtr := LCoalesce.ReallocMem(LPtr, 128);
    Check(LNewPtr <> nil, 'realloc should succeed');

    for LI := 0 to 63 do
      Check(PByte(PtrUInt(LNewPtr) + PtrUInt(LI))^ = Byte(LI and $FF), 'data should be preserved');

    LCoalesce.FreeMem(LNewPtr);
  finally
    LCoalesce.Free;
  end;
end;

procedure TestStats;
var
  LCoalesce: TCoalesceAllocator;
  LStats: TCoalesceStats;
begin
  LCoalesce := TCoalesceAllocator.Create(DefaultAllocator);
  try
    LCoalesce.GetMem(100);
    LCoalesce.GetMem(200);

    LStats := LCoalesce.GetStats;
    Check(LStats.AllocCount = 2, 'alloc count should be 2');
    Check(LStats.UsedBytes > 0, 'used bytes should be > 0');
    Check(LStats.FragmentCount > 0, 'should have fragments');
  finally
    LCoalesce.Free;
  end;
end;

procedure TestNilInner;
var
  LRaised: Boolean;
begin
  LRaised := False;
  try
    TCoalesceAllocator.Create(nil).Free;
  except
    on E: Exception do
      LRaised := True;
  end;
  Check(LRaised, 'nil inner should raise');
end;

procedure TestTraits;
var
  LCoalesce: TCoalesceAllocator;
  LTraits: TAllocatorTraits;
begin
  LCoalesce := TCoalesceAllocator.Create(DefaultAllocator);
  try
    LTraits := LCoalesce.Traits;
    Check(LTraits.SupportsRealloc, 'coalesce supports realloc');
    Check(not LTraits.ThreadSafe, 'coalesce is not thread-safe');
  finally
    LCoalesce.Free;
  end;
end;

begin
  T := TTestSuite.Create('test_coalesce');
  T.Test('create_and_destroy', @TestCreateAndDestroy);
  T.Test('basic_alloc_and_free', @TestBasicAllocAndFree);
  T.Test('alloc_mem_zero_init', @TestAllocMemZeroInit);
  T.Test('merge', @TestMerge);
  T.Test('grow_region', @TestGrowRegion);
  T.Test('realloc', @TestRealloc);
  T.Test('stats', @TestStats);
  T.Test('nil_inner', @TestNilInner);
  T.Test('traits', @TestTraits);
  T.Run;
  T.Summary;
end.
