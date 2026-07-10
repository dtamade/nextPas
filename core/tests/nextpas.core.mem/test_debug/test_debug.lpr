program test_debug;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.text.conv,
  nextpas.core.test,
  nextpas.core.mem.base,
  nextpas.core.mem.intf,
  nextpas.core.mem.default,
  nextpas.core.mem.allocator.base,
  nextpas.core.mem.allocator.debug_alloc,
  nextpas.core.mem.error;

var
  T: TTestSuite;
  LRunPassed: Boolean;

procedure TestCreateAndDestroy;
var
  LDebug: TDebugAllocator;
begin
  LDebug := TDebugAllocator.Create(DefaultAllocator);
  try
    Check(LDebug <> nil, 'debug allocator should be created');
  finally
    LDebug.Free;
  end;
end;

procedure TestBasicAlloc;
var
  LDebug: TDebugAllocator;
  LPtr: Pointer;
begin
  LDebug := TDebugAllocator.Create(DefaultAllocator);
  try
    LPtr := LDebug.GetMem(64);
    Check(LPtr <> nil, 'alloc should succeed');

    LDebug.FreeMem(LPtr);
  finally
    LDebug.Free;
  end;
end;

procedure TestGetMemWithSource;
var
  LDebug: TDebugAllocator;
  LPtr: Pointer;
  LSource: TAllocSource;
begin
  LDebug := TDebugAllocator.Create(DefaultAllocator);
  try
    LPtr := LDebug.GetMemWithSource(128, 'test_debug.lpr', 42);
    Check(LPtr <> nil, 'alloc should succeed');

    Check(LDebug.GetSource(LPtr, LSource), 'should find source');
    Check(LSource.FileName = 'test_debug.lpr', 'file name should match');
    Check(LSource.LineNum = 42, 'line number should match');
    Check(LSource.AllocSize = 128, 'size should match');

    LDebug.FreeMem(LPtr);
  finally
    LDebug.Free;
  end;
end;

procedure TestLeakReport;
var
  LDebug: TDebugAllocator;
  LPtr1, LPtr2: Pointer;
  LReport: string;
begin
  LDebug := TDebugAllocator.Create(DefaultAllocator);
  try
    LPtr1 := LDebug.GetMemWithSource(64, 'main.pas', 10);
    LPtr2 := LDebug.GetMemWithSource(128, 'utils.pas', 20);

    LReport := LDebug.ReportLeaks;
    Check(Pos('2 block(s)', LReport) > 0, 'should report 2 blocks');
    Check(Pos('main.pas', LReport) > 0, 'should mention main.pas');
    Check(Pos('utils.pas', LReport) > 0, 'should mention utils.pas');

    LDebug.FreeMem(LPtr1);
    LDebug.FreeMem(LPtr2);

    LReport := LDebug.ReportLeaks;
    Check(Pos('No leaks', LReport) > 0, 'should report no leaks after free');
  finally
    LDebug.Free;
  end;
end;

procedure TestStats;
var
  LDebug: TDebugAllocator;
  LStats: TDebugAllocStats;
begin
  LDebug := TDebugAllocator.Create(DefaultAllocator);
  try
    LDebug.GetMem(64);
    LDebug.GetMem(128);

    LStats := LDebug.GetStats;
    Check(LStats.TotalAllocs = 2, 'total allocs should be 2');
    Check(LStats.ActiveAllocs = 2, 'active allocs should be 2');
    Check(LStats.ActiveBytes = 192, 'active bytes should be 192');
    Check(LStats.PeakAllocs = 2, 'peak allocs should be 2');
  finally
    LDebug.Free;
  end;
end;

procedure TestAllocMemZeroInit;
var
  LDebug: TDebugAllocator;
  LPtr: Pointer;
  LI: Integer;
  LAllZero: Boolean;
begin
  LDebug := TDebugAllocator.Create(DefaultAllocator);
  try
    LPtr := LDebug.AllocMem(32);
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

    LDebug.FreeMem(LPtr);
  finally
    LDebug.Free;
  end;
end;

procedure TestNilInner;
var
  LRaised: Boolean;
begin
  LRaised := False;
  try
    TDebugAllocator.Create(nil).Free;
  except
    on E: Exception do
      LRaised := True;
  end;
  Check(LRaised, 'nil inner should raise');
end;

begin
  T := TTestSuite.Create('test_debug');
  T.Test('create_and_destroy', @TestCreateAndDestroy);
  T.Test('basic_alloc', @TestBasicAlloc);
  T.Test('get_mem_with_source', @TestGetMemWithSource);
  T.Test('leak_report', @TestLeakReport);
  T.Test('stats', @TestStats);
  T.Test('alloc_mem_zero_init', @TestAllocMemZeroInit);
  T.Test('nil_inner', @TestNilInner);
  LRunPassed := T.Run;
  T.Summary;
  if not LRunPassed then
    Halt(1);
end.
