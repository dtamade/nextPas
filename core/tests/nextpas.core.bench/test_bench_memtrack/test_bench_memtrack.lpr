program test_bench_memtrack;

{$mode objfpc}{$H+}
{$modeswitch advancedrecords}

uses
  {$ifdef unix}
  cthreads,
  {$endif}
  nextpas.core.math.scalar,
  nextpas.core.bench.memtrack,
  nextpas.core.bench.parallel;

var
  GTestsPassed: Integer = 0;
  GTestsFailed: Integer = 0;
  GParallelTracker: TMemoryTracker;

procedure Check(ACondition: Boolean; const ATestName: string);
begin
  if ACondition then
  begin
    Inc(GTestsPassed);
    WriteLn('  ✓ ', ATestName);
  end
  else
  begin
    Inc(GTestsFailed);
    WriteLn('  ✗ ', ATestName);
  end;
end;

{ === TMemoryTracker Tests === }

procedure Test_Create;
var
  LTracker: TMemoryTracker;
begin
  WriteLn('Test_Create:');
  LTracker := TMemoryTracker.Create(True);
  Check(LTracker.IsEnabled = True, 'Enabled by default');
  Check(LTracker.GetStats.AllocCount = 0, 'Initial AllocCount = 0');
  Check(LTracker.GetStats.FreeCount = 0, 'Initial FreeCount = 0');
  Check(LTracker.GetStats.AllocBytes = 0, 'Initial AllocBytes = 0');
  Check(LTracker.GetStats.FreeBytes = 0, 'Initial FreeBytes = 0');
  Check(LTracker.GetStats.PeakAllocs = 0, 'Initial PeakAllocs = 0');
  Check(LTracker.GetStats.PeakBytes = 0, 'Initial PeakBytes = 0');
  Check(LTracker.GetStats.CurrentAllocs = 0, 'Initial CurrentAllocs = 0');
  Check(LTracker.GetStats.CurrentBytes = 0, 'Initial CurrentBytes = 0');
end;

procedure Test_Create_Disabled;
var
  LTracker: TMemoryTracker;
begin
  WriteLn('Test_Create_Disabled:');
  LTracker := TMemoryTracker.Create(False);
  Check(LTracker.IsEnabled = False, 'Disabled when specified');
end;

procedure Test_RecordAlloc;
var
  LTracker: TMemoryTracker;
  LStats: TMemoryStats;
begin
  WriteLn('Test_RecordAlloc:');
  LTracker := TMemoryTracker.Create(True);

  LTracker.RecordAlloc(100);
  LStats := LTracker.GetStats;
  Check(LStats.AllocCount = 1, 'AllocCount = 1');
  Check(LStats.AllocBytes = 100, 'AllocBytes = 100');
  Check(LStats.CurrentAllocs = 1, 'CurrentAllocs = 1');
  Check(LStats.CurrentBytes = 100, 'CurrentBytes = 100');
  Check(LStats.PeakAllocs = 1, 'PeakAllocs = 1');
  Check(LStats.PeakBytes = 100, 'PeakBytes = 100');

  LTracker.RecordAlloc(200);
  LStats := LTracker.GetStats;
  Check(LStats.AllocCount = 2, 'AllocCount = 2');
  Check(LStats.AllocBytes = 300, 'AllocBytes = 300');
  Check(LStats.CurrentAllocs = 2, 'CurrentAllocs = 2');
  Check(LStats.CurrentBytes = 300, 'CurrentBytes = 300');
  Check(LStats.PeakAllocs = 2, 'PeakAllocs = 2');
  Check(LStats.PeakBytes = 300, 'PeakBytes = 300');
end;

procedure Test_RecordFree;
var
  LTracker: TMemoryTracker;
  LStats: TMemoryStats;
begin
  WriteLn('Test_RecordFree:');
  LTracker := TMemoryTracker.Create(True);

  LTracker.RecordAlloc(100);
  LTracker.RecordAlloc(200);
  LTracker.RecordFree(100);

  LStats := LTracker.GetStats;
  Check(LStats.FreeCount = 1, 'FreeCount = 1');
  Check(LStats.FreeBytes = 100, 'FreeBytes = 100');
  Check(LStats.CurrentAllocs = 1, 'CurrentAllocs = 1');
  Check(LStats.CurrentBytes = 200, 'CurrentBytes = 200');
  Check(LStats.PeakAllocs = 2, 'PeakAllocs = 2');
  Check(LStats.PeakBytes = 300, 'PeakBytes = 300');
end;

procedure Test_Peak;
var
  LTracker: TMemoryTracker;
  LStats: TMemoryStats;
begin
  WriteLn('Test_Peak:');
  LTracker := TMemoryTracker.Create(True);

  // Alloc 100 → Current: 1 alloc, 100 bytes, Peak: 1 alloc, 100 bytes
  LTracker.RecordAlloc(100);
  // Alloc 200 → Current: 2 allocs, 300 bytes, Peak: 2 allocs, 300 bytes
  LTracker.RecordAlloc(200);
  // Free 100 → Current: 1 alloc, 200 bytes, Peak: 2 allocs, 300 bytes
  LTracker.RecordFree(100);
  // Alloc 300 → Current: 2 allocs, 500 bytes, Peak: 2 allocs, 500 bytes
  LTracker.RecordAlloc(300);

  LStats := LTracker.GetStats;
  Check(LStats.PeakAllocs = 2, 'PeakAllocs = 2');
  Check(LStats.PeakBytes = 500, 'PeakBytes = 500');
  Check(LStats.CurrentAllocs = 2, 'CurrentAllocs = 2');
  Check(LStats.CurrentBytes = 500, 'CurrentBytes = 500');
end;

procedure Test_Reset;
var
  LTracker: TMemoryTracker;
  LStats: TMemoryStats;
begin
  WriteLn('Test_Reset:');
  LTracker := TMemoryTracker.Create(True);

  LTracker.RecordAlloc(100);
  LTracker.RecordAlloc(200);
  LTracker.Reset;

  LStats := LTracker.GetStats;
  Check(LStats.AllocCount = 0, 'AllocCount = 0');
  Check(LStats.FreeCount = 0, 'FreeCount = 0');
  Check(LStats.AllocBytes = 0, 'AllocBytes = 0');
  Check(LStats.FreeBytes = 0, 'FreeBytes = 0');
  Check(LStats.PeakAllocs = 0, 'PeakAllocs = 0');
  Check(LStats.PeakBytes = 0, 'PeakBytes = 0');
  Check(LStats.CurrentAllocs = 0, 'CurrentAllocs = 0');
  Check(LStats.CurrentBytes = 0, 'CurrentBytes = 0');
end;

procedure Test_Disabled;
var
  LTracker: TMemoryTracker;
  LStats: TMemoryStats;
begin
  WriteLn('Test_Disabled:');
  LTracker := TMemoryTracker.Create(False);

  LTracker.RecordAlloc(100);
  LTracker.RecordFree(50);

  LStats := LTracker.GetStats;
  Check(LStats.AllocCount = 0, 'AllocCount = 0 (disabled)');
  Check(LStats.FreeCount = 0, 'FreeCount = 0 (disabled)');
  Check(LStats.AllocBytes = 0, 'AllocBytes = 0 (disabled)');
  Check(LStats.FreeBytes = 0, 'FreeBytes = 0 (disabled)');
end;

procedure Test_BytesPerOp;
var
  LTracker: TMemoryTracker;
begin
  WriteLn('Test_BytesPerOp:');
  LTracker := TMemoryTracker.Create(True);

  LTracker.RecordAlloc(100);
  LTracker.RecordAlloc(200);

  Check(Abs(LTracker.BytesPerOp(1) - 300) < 0.01, 'BytesPerOp(1) = 300');
  Check(Abs(LTracker.BytesPerOp(2) - 150) < 0.01, 'BytesPerOp(2) = 150');
  Check(Abs(LTracker.BytesPerOp(0) - 0) < 0.01, 'BytesPerOp(0) = 0');
end;

procedure Test_AllocsPerOp;
var
  LTracker: TMemoryTracker;
begin
  WriteLn('Test_AllocsPerOp:');
  LTracker := TMemoryTracker.Create(True);

  LTracker.RecordAlloc(100);
  LTracker.RecordAlloc(200);
  LTracker.RecordAlloc(300);

  Check(Abs(LTracker.AllocsPerOp(1) - 3) < 0.01, 'AllocsPerOp(1) = 3');
  Check(Abs(LTracker.AllocsPerOp(3) - 1) < 0.01, 'AllocsPerOp(3) = 1');
  Check(Abs(LTracker.AllocsPerOp(0) - 0) < 0.01, 'AllocsPerOp(0) = 0');
end;

procedure ParallelRecordAlloc(AThreadId: Integer; AIterations: Int64);
var
  LIteration: Int64;
begin
  for LIteration := 1 to AIterations do
    GParallelTracker.RecordAlloc(1);
end;

procedure ParallelRecordFree(AThreadId: Integer; AIterations: Int64);
var
  LIteration: Int64;
begin
  for LIteration := 1 to AIterations do
    GParallelTracker.RecordFree(1);
end;

procedure Test_ParallelThreadSafety;
const
  THREAD_COUNT = 8;
  ITERS_PER_THREAD = 200000;
var
  LBench: TParallelBenchmark;
  LStats: TMemoryStats;
begin
  WriteLn('Test_ParallelThreadSafety:');
  GParallelTracker := TMemoryTracker.Create(True);

  LBench := TParallelBenchmark.Create(@ParallelRecordAlloc, THREAD_COUNT,
    ITERS_PER_THREAD, 0);
  LBench.Execute;
  LStats := GParallelTracker.GetStats;
  Check(LStats.AllocCount = THREAD_COUNT * ITERS_PER_THREAD, 'Parallel AllocCount exact');
  Check(LStats.AllocBytes = THREAD_COUNT * ITERS_PER_THREAD, 'Parallel AllocBytes exact');
  Check(LStats.CurrentAllocs = THREAD_COUNT * ITERS_PER_THREAD, 'Parallel CurrentAllocs exact');
  Check(LStats.CurrentBytes = THREAD_COUNT * ITERS_PER_THREAD, 'Parallel CurrentBytes exact');

  LBench := TParallelBenchmark.Create(@ParallelRecordFree, THREAD_COUNT,
    ITERS_PER_THREAD, 0);
  LBench.Execute;
  LStats := GParallelTracker.GetStats;
  Check(LStats.FreeCount = THREAD_COUNT * ITERS_PER_THREAD, 'Parallel FreeCount exact');
  Check(LStats.FreeBytes = THREAD_COUNT * ITERS_PER_THREAD, 'Parallel FreeBytes exact');
  Check(LStats.CurrentAllocs = 0, 'Parallel CurrentAllocs returns to 0');
  Check(LStats.CurrentBytes = 0, 'Parallel CurrentBytes returns to 0');
end;

{ === Run All Tests === }

procedure RunAllTests;
begin
  WriteLn('=== TMemoryTracker Tests ===');
  Test_Create;
  Test_Create_Disabled;
  Test_RecordAlloc;
  Test_RecordFree;
  Test_Peak;
  Test_Reset;
  Test_Disabled;
  Test_BytesPerOp;
  Test_AllocsPerOp;
  Test_ParallelThreadSafety;
end;

begin
  WriteLn('=== nextpas.core.bench.memtrack Test Suite ===');
  WriteLn('');

  RunAllTests;

  WriteLn('');
  WriteLn('=== Test Summary ===');
  WriteLn('Total: ', GTestsPassed + GTestsFailed);
  WriteLn('Passed: ', GTestsPassed);
  WriteLn('Failed: ', GTestsFailed);

  if GTestsFailed > 0 then
  begin
    WriteLn('');
    WriteLn('*** FAILED ***');
    Halt(1);
  end
  else
  begin
    WriteLn('');
    WriteLn('✓ All tests passed!');
  end;
end.
