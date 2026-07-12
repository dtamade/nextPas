program test_compact;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.text.conv,
  nextpas.core.test,
  nextpas.core.mem.base,
  nextpas.core.mem.intf,
  nextpas.core.mem.default,
  nextpas.core.mem.allocator.base,
  nextpas.core.mem.allocator.compact,
  nextpas.core.mem.error;

var
  T: TTestSuite;
  LRunPassed: Boolean;
  GCompactCount: Integer;

procedure OnCompact(AOldPtr, ANewPtr: Pointer; ASize: SizeUInt; AUserData: Pointer);
begin
  Inc(GCompactCount);
end;

procedure TestCreateAndDestroy;
var
  LCompact: TCompactAllocator;
begin
  LCompact := TCompactAllocator.Create(DefaultAllocator);
  try
    Check(LCompact.Inner <> nil, 'Inner should not be nil');
    Check(Abs(LCompact.Threshold - 0.3) < 0.001, 'default threshold should be 0.3');
  finally
    LCompact.Free;
  end;
end;

procedure TestCustomThreshold;
var
  LCompact: TCompactAllocator;
begin
  LCompact := TCompactAllocator.Create(DefaultAllocator, 0.5);
  try
    Check(Abs(LCompact.Threshold - 0.5) < 0.001, 'threshold should be 0.5');
  finally
    LCompact.Free;
  end;
end;

procedure TestInvalidThreshold;
var
  LCompact: TCompactAllocator;
  LRaised: Boolean;
begin
  LRaised := False;
  try
    LCompact := TCompactAllocator.Create(DefaultAllocator, 1.5);
    LCompact.Free;
  except
    on E: Exception do
      LRaised := True;
  end;
  Check(LRaised, 'should raise for invalid threshold');
end;

procedure TestAllocAndFree;
var
  LCompact: TCompactAllocator;
  LPtr: Pointer;
begin
  LCompact := TCompactAllocator.Create(DefaultAllocator);
  try
    LPtr := LCompact.GetMem(1024);
    Check(LPtr <> nil, 'alloc should succeed');
    LCompact.FreeMem(LPtr);
    Check(True, 'free should not crash');
  finally
    LCompact.Free;
  end;
end;

procedure TestFragmentationRatio;
var
  LCompact: TCompactAllocator;
  LPtrs: array[0..9] of Pointer;
  LI: Integer;
begin
  LCompact := TCompactAllocator.Create(DefaultAllocator);
  try
    for LI := 0 to 9 do
      LPtrs[LI] := LCompact.GetMem(128 * (LI + 1));

    { 碎片率应该 > 0 }
    Check(LCompact.FragmentationRatio >= 0.0, 'fragmentation should be >= 0');

    for LI := 9 downto 0 do
      LCompact.FreeMem(LPtrs[LI]);
  finally
    LCompact.Free;
  end;
end;

procedure TestCompact;
var
  LCompact: TCompactAllocator;
  LPtrs: array[0..4] of Pointer;
  LI: Integer;
  LFreed: SizeUInt;
begin
  GCompactCount := 0;
  LCompact := TCompactAllocator.Create(DefaultAllocator);
  try
    LCompact.SetCompactHandler(@OnCompact, nil);

    for LI := 0 to 4 do
      LPtrs[LI] := LCompact.GetMem(256);

    LFreed := LCompact.Compact;
    Check(LFreed > 0, 'should free some bytes');
    Check(GCompactCount = 5, 'should call callback for each alloc');

    { 注意：Compact 后旧指针已失效，不要释放 }
    { Compact 会重新分配所有块，旧块已被释放 }
  finally
    LCompact.Free;
  end;
end;

procedure TestCompactStats;
var
  LCompact: TCompactAllocator;
  LPtr: Pointer;
  LStats: TCompactStats;
begin
  LCompact := TCompactAllocator.Create(DefaultAllocator);
  try
    LPtr := LCompact.GetMem(1024);

    LStats := LCompact.GetStats;
    Check(LStats.TotalCompactions = 0, 'should have 0 compactions before compact');
    LCompact.FreeMem(LPtr);
  finally
    LCompact.Free;
  end;
end;

procedure TestCompactEmpty;
var
  LCompact: TCompactAllocator;
  LFreed: SizeUInt;
begin
  LCompact := TCompactAllocator.Create(DefaultAllocator);
  try
    LFreed := LCompact.Compact;
    Check(LFreed = 0, 'should free 0 bytes when empty');
  finally
    LCompact.Free;
  end;
end;

procedure TestTraits;
var
  LCompact: TCompactAllocator;
  LTraits: TAllocatorTraits;
begin
  LCompact := TCompactAllocator.Create(DefaultAllocator);
  try
    LTraits := LCompact.Traits;
    Check(LTraits.SupportsRealloc, 'should support realloc');
  finally
    LCompact.Free;
  end;
end;

begin
  T := TTestSuite.Create('test_compact');
  T.Test('create_and_destroy', @TestCreateAndDestroy);
  T.Test('custom_threshold', @TestCustomThreshold);
  T.Test('invalid_threshold', @TestInvalidThreshold);
  T.Test('alloc_and_free', @TestAllocAndFree);
  T.Test('fragmentation_ratio', @TestFragmentationRatio);
  T.Test('compact', @TestCompact);
  T.Test('compact_stats', @TestCompactStats);
  T.Test('compact_empty', @TestCompactEmpty);
  T.Test('traits', @TestTraits);
  LRunPassed := T.Run;
  T.Summary;
  if not LRunPassed then
    Halt(1);
end.
