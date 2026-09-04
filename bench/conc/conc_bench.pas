program conc_bench;
{$mode objfpc}{$H+}
{$modeswitch advancedrecords}

{
  Concurrent Allocator Benchmark: Pascal vs Go vs Rust

  测试多线程分配/释放吞吐量。
  Pascal 的 DefaultAllocator 使用 TLS freelist，线程间零竞争。
  Go 的 mcache 也是 per-P，Rust 使用系统 allocator。
}

uses
  nextpas.core.thread.init,
  nextpas.core.base,
  nextpas.core.time.base,
  nextpas.core.bench,
  nextpas.core.bench.intf,
  nextpas.core.bench.parallel,
  nextpas.core.mem,
  nextpas.core.text.conv;


const
  OPS_PER_THREAD = 100000;
  SMALL_SIZE     = 64;
  LARGE_SIZE     = 1024;

var
  GAllocator: IAllocator;

{ === Concurrent Alloc/Free 64B === }

procedure ConcAlloc64(AThreadId: Integer; AIterations: Int64);
var I: Integer;
    P: Pointer;
begin
  for I := 1 to AIterations do
  begin
    P := GAllocator.AllocMem(SMALL_SIZE);
    GAllocator.FreeMem(P);
  end;
end;

{ === Concurrent Alloc/Free 1KB === }

procedure ConcAlloc1K(AThreadId: Integer; AIterations: Int64);
var I: Integer;
    P: Pointer;
begin
  for I := 1 to AIterations do
  begin
    P := GAllocator.AllocMem(LARGE_SIZE);
    GAllocator.FreeMem(P);
  end;
end;

procedure PrintResult(const AName: string; const AResult: TParallelBenchResult);
begin
  WriteLn(Format('%-20s %4d threads: %.1f M ops/s (%.1f ns/op, speedup %.1fx)',
    [AName, AResult.Config.ThreadCount,
     AResult.OpsPerSec / 1e6, AResult.NsPerOp, AResult.Speedup]));
end;

var
  LResult: TParallelBenchResult;
begin
  WriteLn('=== nextPas Concurrent Allocator Benchmark ===');
  WriteLn('DefaultAllocator: TLS freelist, zero contention');
  WriteLn('Ops/thread: ', OPS_PER_THREAD);
  WriteLn;

  GAllocator := DefaultAllocator;

  { 4 threads }
  LResult := RunParallelBench(@ConcAlloc64, 4, OPS_PER_THREAD);
  PrintResult('Alloc/64B', LResult);

  LResult := RunParallelBench(@ConcAlloc1K, 4, OPS_PER_THREAD);
  PrintResult('Alloc/1KB', LResult);

  { 8 threads }
  LResult := RunParallelBench(@ConcAlloc64, 8, OPS_PER_THREAD);
  PrintResult('Alloc/64B', LResult);

  LResult := RunParallelBench(@ConcAlloc1K, 8, OPS_PER_THREAD);
  PrintResult('Alloc/1KB', LResult);

  { 16 threads }
  LResult := RunParallelBench(@ConcAlloc64, 16, OPS_PER_THREAD);
  PrintResult('Alloc/64B', LResult);

  LResult := RunParallelBench(@ConcAlloc1K, 16, OPS_PER_THREAD);
  PrintResult('Alloc/1KB', LResult);
end.
