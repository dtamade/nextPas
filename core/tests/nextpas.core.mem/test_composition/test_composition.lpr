program test_composition;
{$I nextpas.core.settings.inc}

uses
  nextpas.core.test,
  nextpas.core.text.conv,
  nextpas.core.mem.base,
  nextpas.core.mem.intf,
  nextpas.core.mem.allocator.base,
  nextpas.core.mem.allocator.foundation,
  nextpas.core.mem.allocator.tracking,
  nextpas.core.mem.allocator.aligned,
  nextpas.core.mem.allocator.stats;

var
  T: TTestSuite;

procedure TestTrackingOverRtl;
var
  LTracking: TTrackingAllocator;
  LPtrs: array[0..9] of Pointer;
  LI: Integer;
begin
  LTracking := TTrackingAllocator.Create(GetRtlAllocator);
  try
    for LI := 0 to 9 do
    begin
      LPtrs[LI] := LTracking.GetMem(128);
      Check(LPtrs[LI] <> nil, 'Alloc #' + IntToStr(LI) + ' failed');
    end;
    Check(LTracking.ActiveAllocCount = 10, 'Should track 10 active allocs');
    Check(LTracking.ActiveAllocBytes = 1280, 'Should track 1280 bytes');

    for LI := 0 to 4 do
      LTracking.FreeMem(LPtrs[LI]);
    Check(LTracking.ActiveAllocCount = 5, 'Should track 5 active allocs after partial free');

    for LI := 5 to 9 do
      LTracking.FreeMem(LPtrs[LI]);
    Check(LTracking.ActiveAllocCount = 0, 'Should track 0 active allocs after all free');
    Check(not LTracking.HasLeaks, 'Should have no leaks');
  finally
    LTracking.Free;
  end;
end;

procedure TestAlignedOverTracking;
var
  LInner: IAllocator;
  LAligned: TAlignedAllocator;
  LPtr: Pointer;
begin
  LInner := TTrackingAllocator.Create(GetRtlAllocator);
  LAligned := TAlignedAllocator.Create(LInner, 64);
  try
    LPtr := LAligned.GetMem(128);
    Check(LPtr <> nil, 'Alloc should succeed');
    Check((PtrUInt(LPtr) mod 64) = 0, 'Should be 64-byte aligned');
    Check((LInner as TTrackingAllocator).ActiveAllocCount = 1, 'Tracking should see 1 alloc');

    LAligned.FreeMem(LPtr);
    Check((LInner as TTrackingAllocator).ActiveAllocCount = 0, 'Tracking should see 0 allocs after free');
  finally
    LAligned.Free;
  end;
end;

procedure TestStatsOverTracking;
var
  LInner: IAllocator;
  LStats: TStatsAllocator;
  LPtr: Pointer;
begin
  LInner := TTrackingAllocator.Create(GetRtlAllocator);
  LStats := TStatsAllocator.Create(LInner);
  try
    LPtr := LStats.GetMem(256);
    Check(LPtr <> nil, 'Alloc should succeed');
    Check((LInner as TTrackingAllocator).ActiveAllocCount = 1, 'Tracking should see 1 alloc');

    LStats.FreeMem(LPtr);
    Check((LInner as TTrackingAllocator).ActiveAllocCount = 0, 'Tracking should see 0 after free');
  finally
    LStats.Free;
  end;
end;

procedure TestTrackingLeakDetection;
var
  LTracking: TTrackingAllocator;
  LPtr: Pointer;
  LLeaks: string;
begin
  LTracking := TTrackingAllocator.Create(GetRtlAllocator);
  try
    LPtr := LTracking.GetMem(64);
    Check(LPtr <> nil, 'Alloc should succeed');
    Check(LTracking.HasLeaks, 'Should detect leak');
    LLeaks := LTracking.ReportLeaks;
    Check(Length(LLeaks) > 0, 'Leak report should not be empty');

    LTracking.FreeMem(LPtr);
    Check(not LTracking.HasLeaks, 'Should have no leaks after free');
  finally
    LTracking.Free;
  end;
end;

procedure TestCompositionChain;
var
  L1: IAllocator;
  L2: IAllocator;
  L3: TAlignedAllocator;
  LPtr: Pointer;
begin
  L1 := TTrackingAllocator.Create(GetRtlAllocator);
  L2 := TStatsAllocator.Create(L1);
  L3 := TAlignedAllocator.Create(L2, 128);
  try
    LPtr := L3.GetMem(256);
    Check(LPtr <> nil, 'Chain alloc should succeed');
    Check((PtrUInt(LPtr) mod 128) = 0, 'Should be 128-byte aligned');
    Check((L1 as TTrackingAllocator).ActiveAllocCount = 1, 'Tracking should see 1 alloc');

    L3.FreeMem(LPtr);
    Check((L1 as TTrackingAllocator).ActiveAllocCount = 0, 'Tracking should see 0 after free');
  finally
    L3.Free;
  end;
end;

begin
  T := TTestSuite.Create('test_composition');
  T.Test('TrackingOverRtl', @TestTrackingOverRtl);
  T.Test('AlignedOverTracking', @TestAlignedOverTracking);
  T.Test('StatsOverTracking', @TestStatsOverTracking);
  T.Test('TrackingLeakDetection', @TestTrackingLeakDetection);
  T.Test('CompositionChain', @TestCompositionChain);
  T.Run;
  T.Summary;
end.
