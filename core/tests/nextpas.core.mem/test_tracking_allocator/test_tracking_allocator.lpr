program test_tracking_allocator;

{$I nextpas.core.settings.inc}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  nextpas.core.text.conv,
  Classes,
  nextpas.core.testing,
  nextpas.core.mem.base,
  nextpas.core.mem.intf,
  nextpas.core.mem.allocator.base,
  nextpas.core.mem.allocator.rtl,
  nextpas.core.mem.allocator.arena,
  nextpas.core.mem.allocator.tracking,
  nextpas.core.mem.allocator.leak_check,
  nextpas.core.mem.arena.virtual;

var
  T: TTestRunner;
  { 全局 tracker 供线程测试使用 }
  GTracker: TTrackingAllocator;

{ --- TTrackingAllocator tests --- }

procedure TestBasicTrack;
var
  LTracker: TTrackingAllocator;
  LP: Pointer;
begin
  LTracker := TTrackingAllocator.Create(GetRtlAllocator);
  try
    LP := LTracker.GetMem(128);
    Check(LP <> nil, 'GetMem should return non-nil');
    Check(LTracker.ActiveAllocCount = 1, 'ActiveAllocCount should be 1');
  finally
    LTracker.Free;
  end;
end;

procedure TestFreeRemoves;
var
  LTracker: TTrackingAllocator;
  LP: Pointer;
begin
  LTracker := TTrackingAllocator.Create(GetRtlAllocator);
  try
    LP := LTracker.GetMem(64);
    Check(LTracker.ActiveAllocCount = 1, 'before free: count=1');
    LTracker.FreeMem(LP);
    Check(LTracker.ActiveAllocCount = 0, 'after free: count=0');
  finally
    LTracker.Free;
  end;
end;

procedure TestMultipleAllocs;
var
  LTracker: TTrackingAllocator;
  LP1, LP2, LP3: Pointer;
begin
  LTracker := TTrackingAllocator.Create(GetRtlAllocator);
  try
    LP1 := LTracker.GetMem(32);
    LP2 := LTracker.GetMem(64);
    LP3 := LTracker.GetMem(128);
    Check(LTracker.ActiveAllocCount = 3, 'should have 3 active allocs');

    LTracker.FreeMem(LP2);
    Check(LTracker.ActiveAllocCount = 2, 'after freeing middle: count=2');

    LTracker.FreeMem(LP1);
    LTracker.FreeMem(LP3);
    Check(LTracker.ActiveAllocCount = 0, 'after freeing all: count=0');
  finally
    LTracker.Free;
  end;
end;

procedure TestReallocTracks;
var
  LTracker: TTrackingAllocator;
  LP, LP2: PInteger;
begin
  LTracker := TTrackingAllocator.Create(GetRtlAllocator);
  try
    LP := PInteger(LTracker.GetMem(4));
    Check(LTracker.ActiveAllocCount = 1, 'before realloc: count=1');
    LP^ := 42;

    LP2 := PInteger(LTracker.ReallocMem(LP, 256));
    Check(LP2 <> nil, 'ReallocMem should succeed');
    Check(LP2^ = 42, 'data preserved after realloc');
    Check(LTracker.ActiveAllocCount = 1, 'after realloc: count=1');

    LTracker.FreeMem(LP2);
    Check(LTracker.ActiveAllocCount = 0, 'after free: count=0');
  finally
    LTracker.Free;
  end;
end;

procedure TestLeakDetection;
var
  LTracker: TTrackingAllocator;
begin
  LTracker := TTrackingAllocator.Create(GetRtlAllocator);
  try
    LTracker.GetMem(128);
    LTracker.GetMem(256);
    Check(LTracker.HasLeaks, 'should report leaks');
    Check(LTracker.ActiveAllocCount = 2, 'should have 2 leaks');
  finally
    LTracker.Free;
  end;
end;

procedure TestNoLeak;
var
  LTracker: TTrackingAllocator;
  LP1, LP2: Pointer;
begin
  LTracker := TTrackingAllocator.Create(GetRtlAllocator);
  try
    LP1 := LTracker.GetMem(128);
    LP2 := LTracker.GetMem(256);
    LTracker.FreeMem(LP1);
    LTracker.FreeMem(LP2);
    Check(not LTracker.HasLeaks, 'should not have leaks');
    Check(LTracker.ActiveAllocCount = 0, 'count should be 0');
  finally
    LTracker.Free;
  end;
end;

procedure TestReportLeaks;
var
  LTracker: TTrackingAllocator;
  LReport: string;
begin
  LTracker := TTrackingAllocator.Create(GetRtlAllocator);
  try
    LTracker.GetMem(100);
    LTracker.GetMem(200);
    LReport := LTracker.ReportLeaks;
    Check(Pos('100', LReport) > 0, 'report should contain size 100');
    Check(Pos('200', LReport) > 0, 'report should contain size 200');
    Check(Pos('Leak report', LReport) > 0, 'report should have header');
  finally
    LTracker.Free;
  end;
end;

procedure TestByteCount;
var
  LTracker: TTrackingAllocator;
  LP1, LP2: Pointer;
begin
  LTracker := TTrackingAllocator.Create(GetRtlAllocator);
  try
    LP1 := LTracker.GetMem(100);
    Check(LTracker.ActiveAllocBytes = 100, 'bytes after first alloc');
    LP2 := LTracker.GetMem(200);
    Check(LTracker.ActiveAllocBytes = 300, 'bytes after second alloc');

    LTracker.FreeMem(LP1);
    Check(LTracker.ActiveAllocBytes = 200, 'bytes after freeing first');
    LTracker.FreeMem(LP2);
    Check(LTracker.ActiveAllocBytes = 0, 'bytes after freeing all');
  finally
    LTracker.Free;
  end;
end;

{ 线程过程：使用全局 GTracker 进行分配释放 }
function ThreadAllocAndFree(arg: Pointer): PtrInt;
var
  LPtrs: array[0..99] of Pointer;
  J: Integer;
begin
  Result := 0;
  for J := 0 to 99 do
    LPtrs[J] := GTracker.GetMem(16);
  for J := 0 to 99 do
    GTracker.FreeMem(LPtrs[J]);
end;

procedure TestThreadSafety;
const
  THREAD_COUNT = 4;
var
  LThreads: array[0..THREAD_COUNT - 1] of TThreadID;
  I: Integer;
begin
  GTracker := TTrackingAllocator.Create(GetRtlAllocator);
  try
    for I := 0 to THREAD_COUNT - 1 do
      LThreads[I] := BeginThread(@ThreadAllocAndFree, nil);

    for I := 0 to THREAD_COUNT - 1 do
      WaitForThreadTerminate(LThreads[I], 0);

    Check(GTracker.ActiveAllocCount = 0,
      'after all threads done: count=0, got ' + IntToStr(GTracker.ActiveAllocCount));
    Check(not GTracker.HasLeaks, 'no leaks after multi-thread test');
  finally
    GTracker.Free;
    GTracker := nil;
  end;
end;

procedure TestAllocMemZeroed;
var
  LTracker: TTrackingAllocator;
  LP: PByte;
  I: Integer;
begin
  LTracker := TTrackingAllocator.Create(GetRtlAllocator);
  try
    LP := PByte(LTracker.AllocMem(64));
    Check(LP <> nil, 'AllocMem should succeed');
    Check(LTracker.ActiveAllocCount = 1, 'should track AllocMem');
    for I := 0 to 63 do
      Check(LP[I] = 0, 'byte ' + IntToStr(I) + ' should be zero');
    LTracker.FreeMem(LP);
  finally
    LTracker.Free;
  end;
end;

procedure TestInnerAllocatorUsed;
var
  LInner: IAllocator;
  LTracker: TTrackingAllocator;
  LP: Pointer;
  LTrackerTraits: TAllocatorTraits;
begin
  LInner := GetRtlAllocator;
  LTracker := TTrackingAllocator.Create(LInner);
  try
    LTrackerTraits := LTracker.Traits;
    Check(LTrackerTraits.ThreadSafe = True, 'Tracker should be ThreadSafe');
    Check(LTrackerTraits.HasMemSize = LInner.Traits.HasMemSize,
      'Tracker HasMemSize should delegate to inner');

    LP := LTracker.GetMem(128);
    Check(LP <> nil, 'should succeed through inner allocator');
    Check(LTracker.Inner = LInner, 'Inner property should match');
    LTracker.FreeMem(LP);
  finally
    LTracker.Free;
  end;
end;

{ --- NEXTPAS_ARENA_LEAK_CHECK test --- }

procedure TestArenaLeakCheck;
var
  LArena: TVirtualArena;
begin
  TVirtualArena_Init(LArena);
  try
    {$IFDEF NEXTPAS_ARENA_LEAK_CHECK}
    Check(GArenaInstanceCount >= 1, 'GArenaInstanceCount should be >= 1 after Init');
    {$ENDIF}
    Check(LArena.Alloc(64) <> nil, 'should allocate normally');
  finally
    TVirtualArena_Release(LArena);
  end;
  {$IFDEF NEXTPAS_ARENA_LEAK_CHECK}
  Check(GArenaInstanceCount = 0, 'GArenaInstanceCount should be 0 after Release');
  {$ENDIF}
end;

{ --- TTrackingAllocator wrapping TArenaAllocator --- }

procedure TestTrackingWithArena;
var
  LArena: IAllocator;
  LTracker: TTrackingAllocator;
  LP: Pointer;
begin
  LArena := TFastArenaAllocator.Create;
  LTracker := TTrackingAllocator.Create(LArena);
  try
    LP := LTracker.GetMem(256);
    Check(LP <> nil, 'alloc through tracking arena should succeed');
    Check(LTracker.ActiveAllocCount = 1, 'should track arena alloc');

    { Arena FreeMem is no-op, but tracker still removes the record }
    LTracker.FreeMem(LP);
    Check(LTracker.ActiveAllocCount = 0, 'should remove record after FreeMem');
  finally
    LTracker.Free;
  end;
end;

{ --- RunTestWithLeakCheck tests --- }

{ 有意泄漏的回调 }
procedure DoLeakTest(AAllocator: IAllocator);
var
  LP: Pointer;
begin
  LP := AAllocator.GetMem(128);
  { 故意不释放 }
end;

{ 不泄漏的回调 }
procedure DoNoLeakTest(AAllocator: IAllocator);
var
  LP: Pointer;
begin
  LP := AAllocator.GetMem(64);
  AAllocator.FreeMem(LP);
end;

procedure TestLeakCheckApi;
var
  LResult: TLeakCheckResult;
begin
  LResult := RunTestWithLeakCheck(@DoLeakTest);
  Check(LResult.HasLeaks, 'should detect leaks');
  Check(LResult.AllocCount = 1, 'should report 1 leaked block');
  Check(LResult.AllocBytes = 128, 'should report 128 bytes');
  Check(Pos('128', LResult.Report) > 0, 'report should mention size');
end;

procedure TestLeakCheckNoLeak;
var
  LResult: TLeakCheckResult;
begin
  LResult := RunTestWithLeakCheck(@DoNoLeakTest);
  Check(not LResult.HasLeaks, 'should not have leaks');
  Check(LResult.AllocCount = 0, 'alloc count should be 0');
  Check(LResult.AllocBytes = 0, 'alloc bytes should be 0');
end;

{ --- Additional tests --- }

procedure TestReallocNilIsGetMem;
var
  LTracker: TTrackingAllocator;
  LP: Pointer;
begin
  LTracker := TTrackingAllocator.Create(GetRtlAllocator);
  try
    LP := LTracker.ReallocMem(nil, 64);
    Check(LP <> nil, 'ReallocMem(nil) should work');
    Check(LTracker.ActiveAllocCount = 1, 'should track as alloc');
    LTracker.FreeMem(LP);
  finally
    LTracker.Free;
  end;
end;

procedure TestReallocToZeroIsFree;
var
  LTracker: TTrackingAllocator;
  LP: Pointer;
begin
  LTracker := TTrackingAllocator.Create(GetRtlAllocator);
  try
    LP := LTracker.GetMem(64);
    Check(LTracker.ActiveAllocCount = 1, 'before realloc: count=1');
    LTracker.ReallocMem(LP, 0);
    Check(LTracker.ActiveAllocCount = 0, 'after realloc to 0: count=0');
  finally
    LTracker.Free;
  end;
end;

procedure TestReportNoLeaks;
var
  LTracker: TTrackingAllocator;
  LReport: string;
begin
  LTracker := TTrackingAllocator.Create(GetRtlAllocator);
  try
    LReport := LTracker.ReportLeaks;
    Check(Pos('No leaks', LReport) > 0, 'report should say no leaks');
  finally
    LTracker.Free;
  end;
end;

begin
  T := TTestRunner.Create('nextpas.core.mem.allocator.tracking');

  { TTrackingAllocator core tests }
  T.Run('basic_track', @TestBasicTrack);
  T.Run('free_removes', @TestFreeRemoves);
  T.Run('multiple_allocs', @TestMultipleAllocs);
  T.Run('realloc_tracks', @TestReallocTracks);
  T.Run('leak_detection', @TestLeakDetection);
  T.Run('no_leak', @TestNoLeak);
  T.Run('report_leaks', @TestReportLeaks);
  T.Run('byte_count', @TestByteCount);
  T.Run('thread_safety', @TestThreadSafety);
  T.Run('alloc_mem_zeroed', @TestAllocMemZeroed);
  T.Run('inner_allocator_used', @TestInnerAllocatorUsed);

  { Arena leak check }
  T.Run('arena_leak_check', @TestArenaLeakCheck);

  { Tracking with arena }
  T.Run('tracking_with_arena', @TestTrackingWithArena);

  { RunTestWithLeakCheck API }
  T.Run('leak_check_api', @TestLeakCheckApi);
  T.Run('leak_check_no_leak', @TestLeakCheckNoLeak);

  { Additional edge case tests }
  T.Run('realloc_nil_is_getmem', @TestReallocNilIsGetMem);
  T.Run('realloc_to_zero_is_free', @TestReallocToZeroIsFree);
  T.Run('report_no_leaks', @TestReportNoLeaks);

  T.Summary;
end.
