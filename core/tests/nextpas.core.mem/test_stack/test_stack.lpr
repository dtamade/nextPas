program test_stack;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.text.conv,
  nextpas.core.test,
  nextpas.core.mem.base,
  nextpas.core.mem.intf,
  nextpas.core.mem.default,
  nextpas.core.mem.allocator.base,
  nextpas.core.mem.allocator.stack,
  nextpas.core.mem.error;

var
  T: TTestSuite;

procedure TestCreateAndDestroy;
var
  LStack: TStackAllocator;
begin
  LStack := TStackAllocator.Create(DefaultAllocator);
  try
    Check(LStack.UsedBytes = 0, 'initial used bytes should be 0');
    Check(LStack.RegionCount >= 1, 'should have at least 1 region');
  finally
    LStack.Free;
  end;
end;

procedure TestBasicAlloc;
var
  LStack: TStackAllocator;
  LPtr1, LPtr2: Pointer;
begin
  LStack := TStackAllocator.Create(DefaultAllocator);
  try
    LPtr1 := LStack.GetMem(64);
    Check(LPtr1 <> nil, 'first alloc should succeed');
    Check(LStack.UsedBytes > 0, 'used bytes should increase');

    LPtr2 := LStack.GetMem(128);
    Check(LPtr2 <> nil, 'second alloc should succeed');
    Check(LPtr2 <> LPtr1, 'pointers should differ');
  finally
    LStack.Free;
  end;
end;

procedure TestAllocMemZeroInit;
var
  LStack: TStackAllocator;
  LPtr: Pointer;
  LI: Integer;
  LAllZero: Boolean;
begin
  LStack := TStackAllocator.Create(DefaultAllocator);
  try
    LPtr := LStack.AllocMem(32);
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
  finally
    LStack.Free;
  end;
end;

procedure TestMarkAndRestore;
var
  LStack: TStackAllocator;
  LMark: TStackMark;
  LPtr1, LPtr2, LPtr3: Pointer;
  LUsedBefore, LUsedAfter: SizeUInt;
begin
  LStack := TStackAllocator.Create(DefaultAllocator, 4096);
  try
    LPtr1 := LStack.GetMem(64);
    Check(LPtr1 <> nil, 'alloc1 should succeed');

    LMark := LStack.Mark;
    LUsedBefore := LStack.UsedBytes;

    LPtr2 := LStack.GetMem(128);
    Check(LPtr2 <> nil, 'alloc2 should succeed');
    LPtr3 := LStack.GetMem(256);
    Check(LPtr3 <> nil, 'alloc3 should succeed');

    Check(LStack.UsedBytes > LUsedBefore, 'used should increase after alloc');

    LStack.Restore(LMark);
    LUsedAfter := LStack.UsedBytes;
    Check(LUsedAfter = LUsedBefore, 'used should return to mark point');

    LPtr2 := LStack.GetMem(64);
    Check(LPtr2 <> nil, 'alloc after restore should succeed');
  finally
    LStack.Free;
  end;
end;

procedure TestExceedRegionCapacity;
var
  LStack: TStackAllocator;
  LPtr: Pointer;
begin
  { 创建小区域 (256B)，分配超过区域容量 }
  LStack := TStackAllocator.Create(DefaultAllocator, 256);
  try
    { 分配超过 256B 应该成功（自动扩展或新区域） }
    LPtr := LStack.GetMem(200);
    Check(LPtr <> nil, 'first alloc should succeed');

    LPtr := LStack.GetMem(200);
    Check(LPtr <> nil, 'second alloc should succeed even exceeding region');

    Check(LStack.UsedBytes >= 400, 'total used should be >= 400');
  finally
    LStack.Free;
  end;
end;

procedure TestReset;
var
  LStack: TStackAllocator;
begin
  LStack := TStackAllocator.Create(DefaultAllocator, 4096);
  try
    LStack.GetMem(1024);
    LStack.GetMem(1024);
    Check(LStack.UsedBytes > 0, 'used should be > 0');

    LStack.Reset;
    Check(LStack.UsedBytes = 0, 'used should be 0 after reset');

    LStack.GetMem(64);
    Check(LStack.UsedBytes > 0, 'alloc after reset should work');
  finally
    LStack.Free;
  end;
end;

procedure TestStats;
var
  LStack: TStackAllocator;
  LStats: TStackStats;
begin
  LStack := TStackAllocator.Create(DefaultAllocator, 4096);
  try
    LStack.GetMem(100);
    LStack.Mark;
    LStack.GetMem(200);

    LStats := LStack.GetStats;
    Check(LStats.RegionSize = 4096, 'region size should be 4096');
    Check(LStats.AllocCount = 2, 'alloc count should be 2');
    Check(LStats.MarkCount = 1, 'mark count should be 1');
  finally
    LStack.Free;
  end;
end;

procedure TestNilInner;
var
  LRaised: Boolean;
begin
  LRaised := False;
  try
    TStackAllocator.Create(nil).Free;
  except
    on E: Exception do
      LRaised := True;
  end;
  Check(LRaised, 'nil inner should raise');
end;

begin
  T := TTestSuite.Create('test_stack');
  T.Test('create_and_destroy', @TestCreateAndDestroy);
  T.Test('basic_alloc', @TestBasicAlloc);
  T.Test('alloc_mem_zero_init', @TestAllocMemZeroInit);
  T.Test('mark_and_restore', @TestMarkAndRestore);
  T.Test('exceed_region_capacity', @TestExceedRegionCapacity);
  T.Test('reset', @TestReset);
  T.Test('stats', @TestStats);
  T.Test('nil_inner', @TestNilInner);
  T.Run;
  T.Summary;
end.
