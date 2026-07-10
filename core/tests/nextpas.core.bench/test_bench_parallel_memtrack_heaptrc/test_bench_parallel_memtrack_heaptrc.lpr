program test_bench_parallel_memtrack_heaptrc;

{$I nextpas.core.settings.inc}

uses
  {$ifdef unix}
  nextpas.core.thread.init,
  {$endif}
  nextpas.core.exception,
  nextpas.core.sync.mutex,
  nextpas.core.time.sleep,
  nextpas.core.time.base,
  nextpas.core.test,
  nextpas.core.bench;

var
  GParallelLock: TMutex;
  GActiveParallelCalls: Integer;
  GMaxParallelCalls: Integer;

procedure BenchParallelObserved(const ACtx: IBenchContext);
begin
  GParallelLock.Acquire;
  try
    Inc(GActiveParallelCalls);
    if GActiveParallelCalls > GMaxParallelCalls then
      GMaxParallelCalls := GActiveParallelCalls;
  finally
    GParallelLock.Release;
  end;

  TSleep.ForDuration(TDuration.FromMilliseconds(1));

  GParallelLock.Acquire;
  try
    Dec(GActiveParallelCalls);
  finally
    GParallelLock.Release;
  end;
end;

procedure BenchAllocatesMemory(const ACtx: IBenchContext);
var
  LPtr: Pointer;
begin
  LPtr := GetMem(64);
  try
    PByte(LPtr)^ := 42;
  finally
    FreeMem(LPtr);
  end;
end;

procedure BenchMultiAlloc(const ACtx: IBenchContext);
var
  I: Integer;
  LPtrs: array[0..3] of Pointer;
begin
  for I := 0 to 3 do
    LPtrs[I] := GetMem(32);
  for I := 3 downto 0 do
    FreeMem(LPtrs[I]);
end;

procedure BenchAllocWithPeak(const ACtx: IBenchContext);
var
  LPtr1, LPtr2: Pointer;
begin
  LPtr1 := GetMem(128);
  LPtr2 := GetMem(256);
  try
    PByte(LPtr1)^ := 1;
    PByte(LPtr2)^ := 2;
  finally
    FreeMem(LPtr2);
    FreeMem(LPtr1);
  end;
end;

{ Test 1: parallel observed concurrency (original) }
procedure TestParallelObserved;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
begin
  GMaxParallelCalls := 0;
  GActiveParallelCalls := 0;

  LSuite := TBenchSuite.Create('ParallelFirst')
    .SetMinDuration(TDuration.FromMilliseconds(1))
    .SetMaxIterations(32)
    .SetMinSamples(1)
    .SetWarmupIters(1);
  LSuite.AddParallel('ParallelObserved', @BenchParallelObserved, 4);
  LResults := LSuite.Run;

  Check(LResults.Count = 1, 'expected exactly 1 benchmark result');
  CheckTrue(GMaxParallelCalls > 1, 'expected parallel calls > 1');
end;

{ Test 2: memtrack single alloc (original) }
procedure TestMemtrackAllocOneBlock;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
begin
  LSuite := TBenchSuite.Create('MemtrackSecond')
    .SetMinDuration(TDuration.FromMilliseconds(1))
    .SetMaxIterations(16)
    .SetMinSamples(1)
    .SetWarmupIters(1)
    .EnableMemoryTracking;
  LSuite.Add('AllocOneBlock', @BenchAllocatesMemory);
  LResults := LSuite.Run;

  Check(LResults.Count = 1, 'expected exactly 1 benchmark result');
  Check(LResults.GetByName('AllocOneBlock').AllocsPerOp >= 1,
    'expected AllocsPerOp >= 1');
end;

{ Test 3: parallel + memtrack combined (memtrack is process-level, parallel may not track accurately) }
procedure TestParallelMemtrackCombined;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
begin
  LSuite := TBenchSuite.Create('ParallelMemtrack')
    .SetMinDuration(TDuration.FromMilliseconds(1))
    .SetMaxIterations(16)
    .SetMinSamples(1)
    .SetWarmupIters(1)
    .EnableMemoryTracking;
  LSuite.AddParallel('ParallelAlloc', @BenchAllocatesMemory, 2);
  LResults := LSuite.Run;

  Check(LResults.Count = 1, 'Combined: 1 result');
  Check(LResults.GetByName('ParallelAlloc').NsPerOp > 0,
    'Combined: NsPerOp > 0');
end;

{ Test 4: multiple allocs per iteration }
procedure TestMemtrackMultipleAllocs;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
begin
  LSuite := TBenchSuite.Create('MultiAlloc')
    .SetMinDuration(TDuration.FromMilliseconds(1))
    .SetMaxIterations(16)
    .SetMinSamples(1)
    .SetWarmupIters(1)
    .EnableMemoryTracking;
  LSuite.Add('MultiAlloc', @BenchMultiAlloc);
  LResults := LSuite.Run;

  Check(LResults.Count = 1, 'MultiAlloc: 1 result');
  Check(LResults.GetByName('MultiAlloc').AllocsPerOp >= 4,
    'MultiAlloc: AllocsPerOp >= 4');
end;

{ Test 5: peak bytes tracking }
procedure TestMemtrackPeakBytes;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
  LResult: TBenchResult;
begin
  LSuite := TBenchSuite.Create('PeakBytes')
    .SetMinDuration(TDuration.FromMilliseconds(1))
    .SetMaxIterations(16)
    .SetMinSamples(1)
    .SetWarmupIters(1)
    .EnableMemoryTracking;
  LSuite.Add('PeakAlloc', @BenchAllocWithPeak);
  LResults := LSuite.Run;

  LResult := LResults.GetByName('PeakAlloc');
  Check(LResult.AllocsPerOp >= 2, 'PeakBytes: AllocsPerOp >= 2');
  Check(LResult.BytesPerOp >= 384, 'PeakBytes: BytesPerOp >= 384 (128+256)');
end;

var
  T: TTestSuite;
  LRunPassed: Boolean;
begin
  GParallelLock := TMutex.Create;
  try
    T := TTestSuite.Create('nextpas.core.bench.parallel.memtrack.heaptrc');
    T.Test('parallel observed', @TestParallelObserved);
    T.Test('memtrack alloc one block', @TestMemtrackAllocOneBlock);
    T.Test('parallel + memtrack combined', @TestParallelMemtrackCombined);
    T.Test('memtrack multiple allocs', @TestMemtrackMultipleAllocs);
    T.Test('memtrack peak bytes', @TestMemtrackPeakBytes);
  LRunPassed := T.Run;
    T.Summary;
  if not LRunPassed then
    Halt(1);
  finally
    GParallelLock.Free;
  end;
end.
