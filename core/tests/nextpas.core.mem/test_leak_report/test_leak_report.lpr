program test_leak_report;
{$mode ObjFPC}{$H+}

uses
  nextpas.core.text.conv,
  nextpas.core.test,
  nextpas.core.mem.error,
  nextpas.core.mem.allocator.base,
  nextpas.core.mem.allocator.crt,
  nextpas.core.mem.allocator.leak_report;

var
  T: TTestSuite;

{ ── Basic alloc/free ── }

procedure TestGetMem;
var
  LAlloc: TLeakReportAllocator;
  LPtr: Pointer;
begin
  LAlloc := TLeakReportAllocator.Create(TCrtAllocator.Create);
  try
    LPtr := LAlloc.GetMem(64);
    Check(LPtr <> nil, 'GetMem(64)');
    Check(LAlloc.HasLeaks, 'has leak after alloc (not freed yet)');
    Check(LAlloc.ActiveAllocCount = 1, 'active = 1');
    LAlloc.FreeMem(LPtr);
    Check(not LAlloc.HasLeaks, 'no leaks after free');
  finally
    LAlloc.Free;
  end;
end;

procedure TestAllocMemZeroed;
var
  LAlloc: TLeakReportAllocator;
  LPtr: PByte;
  LI: Int32;
begin
  LAlloc := TLeakReportAllocator.Create(TCrtAllocator.Create);
  try
    LPtr := PByte(LAlloc.AllocMem(128));
    Check(LPtr <> nil, 'AllocMem(128)');
    for LI := 0 to 127 do
      Check(LPtr[LI] = 0, 'byte[' + IntToStr(LI) + '] = 0');
    LAlloc.FreeMem(LPtr);
  finally
    LAlloc.Free;
  end;
end;

procedure TestReallocPreservesData;
var
  LAlloc: TLeakReportAllocator;
  LPtr, LNew: PByte;
  LI: Int32;
begin
  LAlloc := TLeakReportAllocator.Create(TCrtAllocator.Create);
  try
    LPtr := PByte(LAlloc.GetMem(64));
    for LI := 0 to 63 do
      LPtr[LI] := Byte(LI);
    LNew := PByte(LAlloc.ReallocMem(LPtr, 256));
    Check(LNew <> nil, 'ReallocMem(256)');
    for LI := 0 to 63 do
      Check(LNew[LI] = Byte(LI), 'data preserved');
    LAlloc.FreeMem(LNew);
  finally
    LAlloc.Free;
  end;
end;

{ ── Leak detection ── }

procedure TestLeakDetection;
var
  LAlloc: TLeakReportAllocator;
  LPtr1, LPtr2: Pointer;
begin
  LAlloc := TLeakReportAllocator.Create(TCrtAllocator.Create);
  try
    LPtr1 := LAlloc.GetMem(64);
    LPtr2 := LAlloc.GetMem(128);
    Check(LAlloc.HasLeaks, 'has leaks');
    Check(LAlloc.ActiveAllocCount = 2, 'active = 2');
    Check(LAlloc.ActiveAllocBytes = 192, 'bytes = 192');
    LAlloc.FreeMem(LPtr1);
    Check(LAlloc.ActiveAllocCount = 1, 'active = 1 after free');
    LAlloc.FreeMem(LPtr2);
    Check(not LAlloc.HasLeaks, 'no leaks after all freed');
  finally
    LAlloc.Free;
  end;
end;

{ ── Tag tracking ── }

procedure TestTagTracking;
var
  LAlloc: TLeakReportAllocator;
  LPtr1, LPtr2: Pointer;
  LReport: TLeakReportResult;
begin
  LAlloc := TLeakReportAllocator.Create(TCrtAllocator.Create);
  try
    LAlloc.SetTag('buffers');
    LPtr1 := LAlloc.GetMem(64);
    LAlloc.SetTag('strings');
    LPtr2 := LAlloc.GetMem(128);

    LReport := LAlloc.ReportByTag;
    Check(LReport.TotalLeaks = 2, 'total leaks = 2');
    Check(LReport.TotalLeakBytes = 192, 'total bytes = 192');
    Check(LReport.TagCount = 2, 'tag count = 2');

    LAlloc.FreeMem(LPtr1);
    LAlloc.FreeMem(LPtr2);
  finally
    LAlloc.Free;
  end;
end;

{ ── Leak entries ── }

procedure TestGetLeakEntries;
var
  LAlloc: TLeakReportAllocator;
  LPtr1, LPtr2: Pointer;
  LEntries: array[0..15] of TLeakEntry;
  LCount: Integer;
  LFound32, LFound64: Boolean;
  LI: Integer;
begin
  LAlloc := TLeakReportAllocator.Create(TCrtAllocator.Create);
  try
    LAlloc.SetTag('test');
    LPtr1 := LAlloc.GetMem(32);
    LPtr2 := LAlloc.GetMem(64);

    LAlloc.GetLeakEntries(LEntries, LCount);
    Check(LCount = 2, 'entry count = 2');
    LFound32 := False;
    LFound64 := False;
    for LI := 0 to LCount - 1 do
    begin
      if LEntries[LI].Size = 32 then LFound32 := True;
      if LEntries[LI].Size = 64 then LFound64 := True;
    end;
    Check(LFound32, 'found 32-byte entry');
    Check(LFound64, 'found 64-byte entry');
    Check(LEntries[0].Tag = 'test', 'tag = test');

    LAlloc.FreeMem(LPtr1);
    LAlloc.FreeMem(LPtr2);
  finally
    LAlloc.Free;
  end;
end;

{ ── Caller address tracking ── }

procedure TestCallerAddress;
var
  LAlloc: TLeakReportAllocator;
  LPtr: Pointer;
  LEntries: array[0..15] of TLeakEntry;
  LCount: Integer;
begin
  LAlloc := TLeakReportAllocator.Create(TCrtAllocator.Create);
  try
    LPtr := LAlloc.GetMem(64);
    LAlloc.GetLeakEntries(LEntries, LCount);
    Check(LCount = 1, 'entry count = 1');
    Check(LEntries[0].CallerAddr <> 0, 'caller addr captured');
    LAlloc.FreeMem(LPtr);
  finally
    LAlloc.Free;
  end;
end;

{ ── Timestamp tracking ── }

procedure TestTimestamp;
var
  LAlloc: TLeakReportAllocator;
  LPtr: Pointer;
  LEntries: array[0..15] of TLeakEntry;
  LCount: Integer;
begin
  LAlloc := TLeakReportAllocator.Create(TCrtAllocator.Create);
  try
    LPtr := LAlloc.GetMem(64);
    LAlloc.GetLeakEntries(LEntries, LCount);
    Check(LCount = 1, 'entry count = 1');
    Check(LEntries[0].AllocTimeMs < 1000, 'alloc time < 1000ms');
    LAlloc.FreeMem(LPtr);
  finally
    LAlloc.Free;
  end;
end;

{ ── Multiple allocations same tag ── }

procedure TestAggregationByTag;
var
  LAlloc: TLeakReportAllocator;
  LPtrs: array[0..9] of Pointer;
  LReport: TLeakReportResult;
  LI: Int32;
begin
  LAlloc := TLeakReportAllocator.Create(TCrtAllocator.Create);
  try
    LAlloc.SetTag('pool');
    for LI := 0 to 9 do
      LPtrs[LI] := LAlloc.GetMem(32);

    LReport := LAlloc.ReportByTag;
    Check(LReport.TotalLeaks = 10, 'total = 10');
    Check(LReport.TagCount = 1, 'tag count = 1');
    Check(LReport.Tags[0].Count = 10, 'tag[0].count = 10');
    Check(LReport.Tags[0].TotalBytes = 320, 'tag[0].bytes = 320');

    for LI := 0 to 9 do
      LAlloc.FreeMem(LPtrs[LI]);
  finally
    LAlloc.Free;
  end;
end;

{ ── Double-free detection ── }

procedure TestDoubleFree;
var
  LAlloc: TLeakReportAllocator;
  LPtr: Pointer;
  LRaised: Boolean;
begin
  LAlloc := TLeakReportAllocator.Create(TCrtAllocator.Create);
  try
    LPtr := LAlloc.GetMem(64);
    LAlloc.FreeMem(LPtr);
    LRaised := False;
    try
      LAlloc.FreeMem(LPtr);
    except
      on E: EDoubleFree do
        LRaised := True;
    end;
    Check(LRaised, 'double free raises EDoubleFree');
  finally
    LAlloc.Free;
  end;
end;

{ ── Nil handling ── }

procedure TestNilHandling;
var
  LAlloc: TLeakReportAllocator;
begin
  LAlloc := TLeakReportAllocator.Create(TCrtAllocator.Create);
  try
    Check(LAlloc.GetMem(0) = nil, 'GetMem(0) = nil');
    LAlloc.FreeMem(nil);
  finally
    LAlloc.Free;
  end;
end;

{ ── Traits ── }

procedure TestTraits;
var
  LAlloc: TLeakReportAllocator;
  LTraits: TAllocatorTraits;
begin
  LAlloc := TLeakReportAllocator.Create(TCrtAllocator.Create);
  try
    LTraits := LAlloc.Traits;
    Check(LTraits.ThreadSafe, 'ThreadSafe = True');
    Check(LTraits.ZeroInitialized, 'ZeroInitialized = True');
  finally
    LAlloc.Free;
  end;
end;

{ ── Main ── }

begin
  T := TTestSuite.Create('test_leak_report');

  T.Test('get_mem', @TestGetMem);
  T.Test('alloc_mem_zeroed', @TestAllocMemZeroed);
  T.Test('realloc_preserves_data', @TestReallocPreservesData);
  T.Test('leak_detection', @TestLeakDetection);
  T.Test('tag_tracking', @TestTagTracking);
  T.Test('get_leak_entries', @TestGetLeakEntries);
  T.Test('caller_address', @TestCallerAddress);
  T.Test('timestamp', @TestTimestamp);
  T.Test('aggregation_by_tag', @TestAggregationByTag);
  T.Test('double_free', @TestDoubleFree);
  T.Test('nil_handling', @TestNilHandling);
  T.Test('traits', @TestTraits);

  T.Run;
  T.Summary;
end.
