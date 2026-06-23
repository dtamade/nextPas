program test_sizeclass_pool;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.text.conv,
  nextpas.core.testing,
  nextpas.core.mem.base,
  nextpas.core.mem.error,
  nextpas.core.mem.pool.sizeclass;

var
  T: TTestRunner;

{ ---------------------------------------------------------------------------
  基本生命周期
  --------------------------------------------------------------------------- }

procedure TestCreateDestroy;
var
  LP: TSizeClassPool;
begin
  LP := TSizeClassPool.Create;
  try
    CheckEqual(Int64(0), Int64(LP.PageCount), 'initial pages');
    CheckEqual(Int64(0), Int64(LP.TotalAllocCount), 'initial allocs');
  finally
    LP.Free;
  end;
end;

{ ---------------------------------------------------------------------------
  SizeClassIndex 函数
  --------------------------------------------------------------------------- }

procedure TestSizeClassIndexLookup;
begin
  CheckEqual(0, SizeClassIndex(0), '0B -> class 0');
  CheckEqual(0, SizeClassIndex(1), '1B -> class 0');
  CheckEqual(0, SizeClassIndex(8), '8B -> class 0');
  CheckEqual(1, SizeClassIndex(9), '9B -> class 1');
  CheckEqual(1, SizeClassIndex(16), '16B -> class 1');
  CheckEqual(2, SizeClassIndex(17), '17B -> class 2');
  CheckEqual(2, SizeClassIndex(32), '32B -> class 2');
  CheckEqual(3, SizeClassIndex(33), '33B -> class 3');
  CheckEqual(3, SizeClassIndex(64), '64B -> class 3');
  CheckEqual(4, SizeClassIndex(65), '65B -> class 4');
  CheckEqual(4, SizeClassIndex(128), '128B -> class 4');
  CheckEqual(5, SizeClassIndex(129), '129B -> class 5');
  CheckEqual(5, SizeClassIndex(256), '256B -> class 5');
  CheckEqual(6, SizeClassIndex(257), '257B -> class 6');
  CheckEqual(6, SizeClassIndex(512), '512B -> class 6');
  CheckEqual(-1, SizeClassIndex(513), '513B -> no class');
  CheckEqual(-1, SizeClassIndex(1024), '1024B -> no class');
end;

{ ---------------------------------------------------------------------------
  基本分配释放
  --------------------------------------------------------------------------- }

procedure TestAllocSmall;
var
  LP: TSizeClassPool;
  LP1, LP2: Pointer;
begin
  LP := TSizeClassPool.Create;
  try
    LP1 := LP.Alloc(8);
    Check(LP1 <> nil, 'alloc 8B');
    CheckEqual(Int64(1), Int64(LP.PageCount), 'one page allocated');

    LP2 := LP.Alloc(8);
    Check(LP2 <> nil, 'alloc 8B again');
    Check(LP1 <> LP2, 'different pointers');

    LP.Release(LP1, 8);
    LP.Release(LP2, 8);
  finally
    LP.Free;
  end;
end;

procedure TestAllocVariousSizes;
var
  LP: TSizeClassPool;
  LPtrs: array[0..6] of Pointer;
  I: Integer;
begin
  LP := TSizeClassPool.Create;
  try
    for I := 0 to 6 do
    begin
      LPtrs[I] := LP.Alloc(SIZE_CLASSES[TSizeClassIndex(I)]);
      Check(LPtrs[I] <> nil, 'alloc class ' + IntToStr(I));
    end;

    { 每个大小类应有独立的页 }
    Check(LP.PageCount >= 1, 'at least one page');

    for I := 0 to 6 do
      LP.Release(LPtrs[I], SIZE_CLASSES[TSizeClassIndex(I)]);
  finally
    LP.Free;
  end;
end;

procedure TestFreeReuse;
var
  LP: TSizeClassPool;
  LP1, LP2: Pointer;
begin
  LP := TSizeClassPool.Create;
  try
    LP1 := LP.Alloc(32);
    LP.Release(LP1, 32);

    LP2 := LP.Alloc(32);
    { Free 后分配应该复用同一地址 }
    Check(LP1 = LP2, 'free/reuse same address');
    LP.Release(LP2, 32);
  finally
    LP.Free;
  end;
end;

procedure TestZeroAlloc;
var
  LP: TSizeClassPool;
begin
  LP := TSizeClassPool.Create;
  try
    Check(LP.Alloc(0) = nil, 'zero alloc returns nil');
    CheckEqual(Int64(0), Int64(LP.PageCount), 'no pages allocated');
  finally
    LP.Free;
  end;
end;

procedure TestOversizeAlloc;
var
  LP: TSizeClassPool;
begin
  LP := TSizeClassPool.Create;
  try
    try
      LP.Alloc(513);
      Check(False, 'should raise exception');
    except
      on E: EOutOfMemory do
        Check(True, 'correct exception type');
    end;
  finally
    LP.Free;
  end;
end;

{ ---------------------------------------------------------------------------
  Write/Read 验证
  --------------------------------------------------------------------------- }

procedure TestWriteRead;
var
  LP: TSizeClassPool;
  LP1: PInteger;
  LP2: PByte;
  I: Integer;
begin
  LP := TSizeClassPool.Create;
  try
    LP1 := PInteger(LP.Alloc(4));
    LP1^ := 42;
    CheckEqual(42, LP1^, 'integer write/read');

    LP2 := PByte(LP.Alloc(8));
    for I := 0 to 7 do
      LP2[I] := Byte(I + 10);
    for I := 0 to 7 do
      CheckEqual(I + 10, LP2[I], 'byte write/read at ' + IntToStr(I));

    LP.Release(LP1, 4);
    LP.Release(LP2, 8);
  finally
    LP.Free;
  end;
end;

{ ---------------------------------------------------------------------------
  Reset 测试
  --------------------------------------------------------------------------- }

procedure TestReset;
var
  LP: TSizeClassPool;
  LPtrs: array[0..9] of Pointer;
  LFreeBefore, LFreeAfter: SizeUInt;
  I: Integer;
begin
  LP := TSizeClassPool.Create;
  try
    { 分配 10 个 slot }
    for I := 0 to 9 do
      LPtrs[I] := LP.Alloc(32);

    LFreeBefore := LP.FreeCount(2); { class 2 = 32B }

    { Reset 应该回收所有 slot }
    LP.Reset;
    LFreeAfter := LP.FreeCount(2);
    Check(LFreeAfter > LFreeBefore, 'free count increased after reset');

    { 分配应该复用已回收的 slot }
    for I := 0 to 9 do
    begin
      LPtrs[I] := LP.Alloc(32);
      Check(LPtrs[I] <> nil, 'alloc after reset');
    end;

    LP.Reset;
  finally
    LP.Free;
  end;
end;

{ ---------------------------------------------------------------------------
  自动扩容测试
  --------------------------------------------------------------------------- }

procedure TestAutoPageGrowth;
var
  LP: TSizeClassPool;
  LPagesBefore, LPagesAfter: SizeUInt;
  I: Integer;
begin
  LP := TSizeClassPool.Create;
  try
    LPagesBefore := LP.PageCount;

    { 分配超过一页容量: 4096/8 = 512 slots per page }
    for I := 1 to 600 do
      LP.Alloc(8);

    LPagesAfter := LP.PageCount;
    Check(LPagesAfter > LPagesBefore, 'auto page growth: ' +
      IntToStr(LPagesBefore) + ' -> ' + IntToStr(LPagesAfter));
    Check(LP.PageCount >= 2, 'at least 2 pages');
  finally
    LP.Free;
  end;
end;

procedure TestLargeAllocCount;
var
  LP: TSizeClassPool;
  I: Integer;
begin
  LP := TSizeClassPool.Create;
  try
    { 5000 次分配, 跨多个页 }
    for I := 1 to 5000 do
      Check(LP.Alloc(16) <> nil, 'alloc 16B #' + IntToStr(I));

    Check(LP.TotalAllocCount >= 5000, 'total alloc count');
    Check(LP.PageCount >= 2, 'multiple pages');
  finally
    LP.Free;
  end;
end;

{ ---------------------------------------------------------------------------
  边界条件
  --------------------------------------------------------------------------- }

procedure TestFreeNil;
var
  LP: TSizeClassPool;
begin
  LP := TSizeClassPool.Create;
  try
    LP.Release(nil, 8); { 不崩溃 }
    LP.Release(nil, 0); { 不崩溃 }
    Check(True, 'free nil does not crash');
  finally
    LP.Free;
  end;
end;

procedure TestFreeZeroSize;
var
  LP: TSizeClassPool;
  LP1: Pointer;
begin
  LP := TSizeClassPool.Create;
  try
    LP1 := LP.Alloc(8);
    LP.Release(LP1, 0); { size=0 应安全 }
    Check(True, 'free with zero size does not crash');
    LP.Release(LP1, 8); { 正确释放 }
  finally
    LP.Free;
  end;
end;

procedure TestSlotSizeQuery;
var
  LP: TSizeClassPool;
begin
  LP := TSizeClassPool.Create;
  try
    CheckEqual(Int64(8), Int64(LP.SlotSize(0)), 'class 0 slot size');
    CheckEqual(Int64(16), Int64(LP.SlotSize(1)), 'class 1 slot size');
    CheckEqual(Int64(32), Int64(LP.SlotSize(2)), 'class 2 slot size');
    CheckEqual(Int64(64), Int64(LP.SlotSize(3)), 'class 3 slot size');
    CheckEqual(Int64(128), Int64(LP.SlotSize(4)), 'class 4 slot size');
    CheckEqual(Int64(256), Int64(LP.SlotSize(5)), 'class 5 slot size');
    CheckEqual(Int64(512), Int64(LP.SlotSize(6)), 'class 6 slot size');
  finally
    LP.Free;
  end;
end;

{ ---------------------------------------------------------------------------
  混合大小类分配
  --------------------------------------------------------------------------- }

procedure TestMixedSizeClasses;
var
  LP: TSizeClassPool;
  LP8, LP16, LP32, LP64, LP128, LP256, LP512: Pointer;
begin
  LP := TSizeClassPool.Create;
  try
    { 交替分配不同大小类 }
    LP8 := LP.Alloc(1);
    LP16 := LP.Alloc(9);
    LP32 := LP.Alloc(17);
    LP64 := LP.Alloc(33);
    LP128 := LP.Alloc(65);
    LP256 := LP.Alloc(129);
    LP512 := LP.Alloc(257);

    Check(LP8 <> nil, '1B alloc');
    Check(LP16 <> nil, '9B alloc');
    Check(LP32 <> nil, '17B alloc');
    Check(LP64 <> nil, '33B alloc');
    Check(LP128 <> nil, '65B alloc');
    Check(LP256 <> nil, '129B alloc');
    Check(LP512 <> nil, '257B alloc');

    { 释放顺序反向 }
    LP.Release(LP512, 257);
    LP.Release(LP256, 129);
    LP.Release(LP128, 65);
    LP.Release(LP64, 33);
    LP.Release(LP32, 17);
    LP.Release(LP16, 9);
    LP.Release(LP8, 1);

    Check(True, 'mixed alloc/free completed');
  finally
    LP.Free;
  end;
end;

procedure TestAllocStress;
var
  LP: TSizeClassPool;
  LPtrs: array[0..999] of Pointer;
  I: Integer;
begin
  LP := TSizeClassPool.Create;
  try
    { 分配 1000 个 32B 块 }
    for I := 0 to 999 do
    begin
      LPtrs[I] := LP.Alloc(32);
      Check(LPtrs[I] <> nil, 'stress alloc #' + IntToStr(I));
      PByte(LPtrs[I])^ := Byte(I);
    end;

    { 验证 }
    for I := 0 to 999 do
      Check(PByte(LPtrs[I])^ = Byte(I), 'stress verify #' + IntToStr(I));

    { 释放全部 }
    for I := 0 to 999 do
      LP.Release(LPtrs[I], 32);

    { 再次分配应复用 }
    for I := 0 to 999 do
    begin
      LPtrs[I] := LP.Alloc(32);
      Check(LPtrs[I] <> nil, 'stress re-alloc #' + IntToStr(I));
    end;

    LP.Reset;
    Check(True, 'stress test completed');
  finally
    LP.Free;
  end;
end;

{ ---------------------------------------------------------------------------
  Runner
  --------------------------------------------------------------------------- }

begin
  T := TTestRunner.Create('nextpas.core.mem.pool.sizeclass');

  { 生命周期 }
  T.Run('Create/Destroy', @TestCreateDestroy);

  { SizeClassIndex }
  T.Run('SizeClassIndex lookup', @TestSizeClassIndexLookup);

  { 基本分配 }
  T.Run('Alloc small', @TestAllocSmall);
  T.Run('Alloc various sizes', @TestAllocVariousSizes);
  T.Run('Free reuse', @TestFreeReuse);
  T.Run('Zero alloc', @TestZeroAlloc);
  T.Run('Oversize alloc', @TestOversizeAlloc);

  { Write/Read }
  T.Run('Write/Read', @TestWriteRead);

  { Reset }
  T.Run('Reset', @TestReset);

  { 自动扩容 }
  T.Run('Auto page growth', @TestAutoPageGrowth);
  T.Run('Large alloc count', @TestLargeAllocCount);

  { 边界 }
  T.Run('Free nil', @TestFreeNil);
  T.Run('Free zero size', @TestFreeZeroSize);
  T.Run('Slot size query', @TestSlotSizeQuery);

  { 混合 }
  T.Run('Mixed size classes', @TestMixedSizeClasses);
  T.Run('Alloc stress', @TestAllocStress);

  T.Summary;
end.
