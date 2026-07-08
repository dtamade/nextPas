program test_leak_check_allocator;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.test,
  nextpas.core.text.conv,
  nextpas.core.mem.base,
  nextpas.core.mem.intf,
  nextpas.core.mem.allocator.base,
  nextpas.core.mem.allocator.foundation,
  nextpas.core.mem.allocator.tracking,
  nextpas.core.mem.allocator.leak_check;

var
  T: TTestSuite;

procedure NoLeakProc(AAllocator: IAllocator);
var
  LPtr: Pointer;
begin
  LPtr := AAllocator.GetMem(64);
  AAllocator.FreeMem(LPtr);
end;

procedure LeakProc(AAllocator: IAllocator);
var
  LPtr: Pointer;
begin
  LPtr := AAllocator.GetMem(64);
  // Intentionally not freeing
end;

procedure TestNoLeak;
var
  LResult: TLeakCheckResult;
begin
  LResult := RunTestWithLeakCheck(@NoLeakProc);
  Check(not LResult.HasLeaks, 'no leaks');
  Check(LResult.AllocCount = 0, 'zero active');
  Check(LResult.AllocBytes = 0, 'zero bytes');
end;

procedure TestLeakDetected;
var
  LResult: TLeakCheckResult;
begin
  LResult := RunTestWithLeakCheck(@LeakProc);
  Check(LResult.HasLeaks, 'has leaks');
  Check(LResult.AllocCount >= 1, 'one active');
  Check(LResult.AllocBytes >= 64, '64 bytes leaked');
  Check(Length(LResult.Report) > 0, 'has report');
end;

procedure TestReportContent;
var
  LResult: TLeakCheckResult;
begin
  LResult := RunTestWithLeakCheck(@LeakProc);
  Check(Pos('block', LResult.Report) > 0, 'report has block info');
end;

procedure TestMultipleLeaks;
var
  LResult: TLeakCheckResult;
begin
  LResult := RunTestWithLeakCheck(procedure(AAllocator: IAllocator)
  begin
    AAllocator.GetMem(32);
    AAllocator.GetMem(64);
    AAllocator.GetMem(128);
  end);
  Check(LResult.HasLeaks, 'has leaks');
  Check(LResult.AllocCount >= 3, 'three leaks');
  Check(LResult.AllocBytes >= 224, 'total bytes');
end;

procedure TestCustomAllocator;
var
  LResult: TLeakCheckResult;
begin
  // Pass nil to use default allocator
  LResult := RunTestWithLeakCheck(@NoLeakProc, nil);
  Check(not LResult.HasLeaks, 'no leaks with custom');
end;

procedure TestCleanReport;
var
  LResult: TLeakCheckResult;
begin
  LResult := RunTestWithLeakCheck(@NoLeakProc);
  Check(Pos('No leaks', LResult.Report) > 0, 'clean report');
end;

procedure TestZeroSizeLeak;
var
  LResult: TLeakCheckResult;
begin
  LResult := RunTestWithLeakCheck(procedure(AAllocator: IAllocator)
  begin
    AAllocator.GetMem(1);
  end);
  Check(LResult.HasLeaks, '1 byte leak');
  Check(LResult.AllocBytes >= 1, '1 byte');
end;

begin
  T := TTestSuite.Create('test_leak_check_allocator');
  T.Test('NoLeak', @TestNoLeak);
  T.Test('LeakDetected', @TestLeakDetected);
  T.Test('ReportContent', @TestReportContent);
  T.Test('MultipleLeaks', @TestMultipleLeaks);
  T.Test('CustomAllocator', @TestCustomAllocator);
  T.Test('CleanReport', @TestCleanReport);
  T.Test('ZeroSizeLeak', @TestZeroSizeLeak);
  T.Run;
  T.Summary;
end.
