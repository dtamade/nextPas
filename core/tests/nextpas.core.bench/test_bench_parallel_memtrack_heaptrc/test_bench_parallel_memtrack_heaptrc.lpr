program test_bench_parallel_memtrack_heaptrc;

{$mode objfpc}{$H+}
{$modeswitch advancedrecords}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

uses
  {$ifdef unix}
  cthreads,
  {$endif}
  nextpas.core.exception,
  nextpas.core.sync.mutex,
  nextpas.core.time.sleep,
  nextpas.core.time.base,
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

var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
begin
  GParallelLock := TMutex.Create;
  try
    LSuite := TBenchSuite.Create('ParallelFirst')
      .SetMinDuration(TDuration.FromMilliseconds(1))
      .SetMaxIterations(32)
      .SetMinSamples(1)
      .SetWarmupIters(1);
    LSuite.AddParallel('ParallelObserved', @BenchParallelObserved, 4);
    LResults := LSuite.Run;
    if (LResults.Count <> 1) or (GMaxParallelCalls <= 1) then
      Halt(2);
    LResults := nil;
    LSuite := nil;

    LSuite := TBenchSuite.Create('MemtrackSecond')
      .SetMinDuration(TDuration.FromMilliseconds(1))
      .SetMaxIterations(16)
      .SetMinSamples(1)
      .SetWarmupIters(1)
      .EnableMemoryTracking;
    LSuite.Add('AllocOneBlock', @BenchAllocatesMemory);
    LResults := LSuite.Run;
    if LResults.Count <> 1 then
      Halt(3);
    if LResults.GetByName('AllocOneBlock').AllocsPerOp < 1 then
      Halt(4);

    LResults := nil;
    LSuite := nil;
    WriteLn('PARALLEL_MEMTRACK_OK');
  finally
    GParallelLock.Free;
  end;
end.
