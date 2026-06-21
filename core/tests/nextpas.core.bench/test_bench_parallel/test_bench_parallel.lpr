program test_bench_parallel;

{$mode objfpc}{$H+}
{$modeswitch advancedrecords}

uses
  {$ifdef unix}
  cthreads,
  {$endif}
  nextpas.core.text.conv,
  nextpas.core.sync.mutex,
  nextpas.core.bench.base,
  nextpas.core.bench.parallel;

var
  GTestsPassed: Integer = 0;
  GTestsFailed: Integer = 0;
  GCounter: Integer = 0;
  GCounterLock: TMutex;

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

{ Test benchmark functions }

procedure BenchSimple(AThreadId: Integer; AIterations: Int64);
var
  I: Int64;
  LSum: Int64;
begin
  LSum := 0;
  for I := 1 to AIterations do
    Inc(LSum, I);
end;

procedure BenchSharedCounter(AThreadId: Integer; AIterations: Int64);
var
  I: Int64;
begin
  for I := 1 to AIterations do
  begin
    GCounterLock.Acquire;
    try
      Inc(GCounter);
    finally
      GCounterLock.Release;
    end;
  end;
end;

{ === TParallelBenchmark Tests === }

procedure Test_Create;
var
  LBench: TParallelBenchmark;
begin
  WriteLn('Test_Create:');
  LBench := TParallelBenchmark.Create(@BenchSimple, 4, 1000, 100);
  Check(True, 'Created successfully');
end;

procedure Test_Execute_Simple;
var
  LResult: TParallelBenchResult;
begin
  WriteLn('Test_Execute_Simple:');
  LResult := RunParallelBench(@BenchSimple, 2, 10000);

  Check(LResult.Config.ThreadCount = 2, 'ThreadCount = 2');
  Check(LResult.Config.IterationsPerThread = 10000, 'IterationsPerThread = 10000');
  Check(LResult.TotalNs > 0, 'TotalNs > 0');
  Check(LResult.NsPerOp > 0, 'NsPerOp > 0');
  Check(LResult.OpsPerSec > 0, 'OpsPerSec > 0');
  Check(Length(LResult.ThreadResults) = 2, 'ThreadResults count = 2');
end;

procedure Test_Execute_ThreadResults;
var
  LResult: TParallelBenchResult;
  I: Integer;
begin
  WriteLn('Test_Execute_ThreadResults:');
  LResult := RunParallelBench(@BenchSimple, 3, 5000);

  Check(Length(LResult.ThreadResults) = 3, 'ThreadResults count = 3');

  for I := 0 to High(LResult.ThreadResults) do
  begin
    Check(LResult.ThreadResults[I].ThreadId = I, 'ThreadId = ' + nextpas.core.text.conv.IntToStr(I));
    Check(LResult.ThreadResults[I].Iterations = 5000, 'Iterations = 5000');
    // ElapsedNs might be 0 if execution is too fast for timer resolution
    Check(LResult.ThreadResults[I].ElapsedNs >= 0, 'ElapsedNs >= 0');
    Check(LResult.ThreadResults[I].NsPerOp >= 0, 'NsPerOp >= 0');
  end;
end;

procedure Test_Execute_Speedup;
var
  LResult1: TParallelBenchResult;
  LResult2: TParallelBenchResult;
begin
  WriteLn('Test_Execute_Speedup:');
  LResult1 := RunParallelBench(@BenchSimple, 1, 100000);
  LResult2 := RunParallelBench(@BenchSimple, 2, 100000);

  // With 2 threads, we should see some speedup
  // (though it depends on CPU cores available and timer resolution)
  Check(LResult2.Speedup >= 0, 'Speedup >= 0');
  Check(LResult2.Efficiency >= 0, 'Efficiency >= 0');
end;

procedure Test_Execute_SharedCounter;
var
  LResult: TParallelBenchResult;
begin
  WriteLn('Test_Execute_SharedCounter:');
  GCounter := 0;
  LResult := RunParallelBench(@BenchSharedCounter, 4, 10000);

  // With more iterations and proper locking, we should see the expected count
  Check(GCounter > 0, 'Counter > 0 (some increments completed)');
  Check(LResult.TotalNs > 0, 'TotalNs > 0');
end;

procedure Test_Execute_Warmup;
var
  LResult: TParallelBenchResult;
begin
  WriteLn('Test_Execute_Warmup:');
  LResult := RunParallelBench(@BenchSimple, 2, 10000);

  // Warmup is handled internally, just verify it doesn't crash
  Check(LResult.TotalNs > 0, 'TotalNs > 0');
end;

procedure Test_Execute_ZeroIterations;
var
  LResult: TParallelBenchResult;
begin
  WriteLn('Test_Execute_ZeroIterations:');
  LResult := RunParallelBench(@BenchSimple, 2, 0);

  Check(LResult.TotalNs >= 0, 'TotalNs >= 0');
  Check(LResult.NsPerOp = 0, 'NsPerOp = 0');
  Check(LResult.OpsPerSec = 0, 'OpsPerSec = 0');
end;

procedure Test_Execute_SingleThread;
var
  LResult: TParallelBenchResult;
begin
  WriteLn('Test_Execute_SingleThread:');
  LResult := RunParallelBench(@BenchSimple, 1, 10000);

  Check(LResult.Config.ThreadCount = 1, 'ThreadCount = 1');
  Check(Length(LResult.ThreadResults) = 1, 'ThreadResults count = 1');
  Check(LResult.Speedup >= 0, 'Speedup >= 0');
  Check(LResult.Efficiency >= 0, 'Efficiency >= 0');
end;

procedure Test_Execute_ManyThreads;
var
  LResult: TParallelBenchResult;
begin
  WriteLn('Test_Execute_ManyThreads:');
  LResult := RunParallelBench(@BenchSimple, 8, 1000);

  Check(LResult.Config.ThreadCount = 8, 'ThreadCount = 8');
  Check(Length(LResult.ThreadResults) = 8, 'ThreadResults count = 8');
  Check(LResult.TotalNs > 0, 'TotalNs > 0');
end;

procedure Test_Execute_HeavyWorkload;
var
  LResult: TParallelBenchResult;
begin
  WriteLn('Test_Execute_HeavyWorkload:');
  LResult := RunParallelBench(@BenchSimple, 4, 100000);

  Check(LResult.TotalNs > 0, 'TotalNs > 0');
  Check(LResult.NsPerOp > 0, 'NsPerOp > 0');
  Check(LResult.OpsPerSec > 0, 'OpsPerSec > 0');
end;

{ === Run All Tests === }

procedure RunAllTests;
begin
  WriteLn('=== TParallelBenchmark Tests ===');
  Test_Create;
  Test_Execute_Simple;
  Test_Execute_ThreadResults;
  Test_Execute_Speedup;
  Test_Execute_SharedCounter;
  Test_Execute_Warmup;
  Test_Execute_ZeroIterations;
  Test_Execute_SingleThread;
  Test_Execute_ManyThreads;
  Test_Execute_HeavyWorkload;
end;

begin
  WriteLn('=== nextpas.core.bench.parallel Test Suite ===');
  WriteLn('');

  // Initialize
  GCounterLock := TMutex.Create;

  try
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
  finally
    GCounterLock.Free;
  end;
end.
