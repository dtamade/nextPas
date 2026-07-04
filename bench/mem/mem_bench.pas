program mem_bench;
{$mode objfpc}{$H+}
{$modeswitch advancedrecords}

{
  Memory Allocator Micro-Benchmark: Pascal vs Go vs Rust

  测试小对象 (64B) 和大对象 (1KB) 分配/释放吞吐量。
  Pascal 用 nextpas.core.mem DefaultAllocator (TLS freelist, 23ns/64B)。
}

uses
  nextpas.core.base,
  nextpas.core.time.base,
  nextpas.core.bench,
  nextpas.core.bench.intf,
  nextpas.core.mem,
  nextpas.core.mem.allocator.base;

const
  ALLOC_N       = 10000;
  SMALL_SIZE    = 64;
  LARGE_SIZE    = 1024;
  POOL_N        = 100000;

var
  GAllocator: IAllocator;
  GRawAllocator: TAllocator;

{ === Alloc/Free 64B × 10000 (via interface) === }

procedure BenchAlloc64(const ACtx: IBenchContext);
var I: Integer;
    P: Pointer;
begin
  for I := 1 to ALLOC_N do
  begin
    P := GAllocator.AllocMem(SMALL_SIZE);
    GAllocator.FreeMem(P);
  end;
  ACtx.SetBytes(ALLOC_N * SMALL_SIZE);
end;

{ === Alloc/Free 1KB × 10000 (via interface) === }

procedure BenchAlloc1K(const ACtx: IBenchContext);
var I: Integer;
    P: Pointer;
begin
  for I := 1 to ALLOC_N do
  begin
    P := GAllocator.AllocMem(LARGE_SIZE);
    GAllocator.FreeMem(P);
  end;
  ACtx.SetBytes(ALLOC_N * LARGE_SIZE);
end;

{ === Raw Alloc/Free 64B × 10000 (direct TAllocator, no interface) === }

procedure BenchRawAlloc64(const ACtx: IBenchContext);
var I: Integer;
    P: Pointer;
begin
  for I := 1 to ALLOC_N do
  begin
    P := GRawAllocator.AllocMem(SMALL_SIZE);
    GRawAllocator.FreeMem(P);
  end;
  ACtx.SetBytes(ALLOC_N * SMALL_SIZE);
end;

{ === Raw Alloc/Free 1KB × 10000 (direct TAllocator) === }

procedure BenchRawAlloc1K(const ACtx: IBenchContext);
var I: Integer;
    P: Pointer;
begin
  for I := 1 to ALLOC_N do
  begin
    P := GRawAllocator.AllocMem(LARGE_SIZE);
    GRawAllocator.FreeMem(P);
  end;
  ACtx.SetBytes(ALLOC_N * LARGE_SIZE);
end;

{ === Pool Acquire/Release 64B × 100000 === }

var GPool: IFixedSlabPool;

procedure BenchPool64(const ACtx: IBenchContext);
var I: Integer;
    P: Pointer;
    Dummy: Boolean;
begin
  for I := 1 to POOL_N do
  begin
    Dummy := GPool.TryAcquire(P);
    GPool.Release(P);
  end;
  ACtx.SetBytes(POOL_N * SMALL_SIZE);
end;

var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
begin
  WriteLn('=== nextPas Memory Allocator Benchmark ===');
  WriteLn('DefaultAllocator: TLS freelist + buddy sub-allocator');
  WriteLn('Small: ', SMALL_SIZE, 'B × ', ALLOC_N);
  WriteLn('Large: ', LARGE_SIZE, 'B × ', ALLOC_N);
  WriteLn('Pool: ', SMALL_SIZE, 'B × ', POOL_N);
  WriteLn;

  GAllocator := DefaultAllocator;
  GRawAllocator := TAllocator(GAllocator as TObject);
  GPool := MakeFixedSlabPool(SMALL_SIZE);

  LSuite := TBenchSuite.Create('mem')
    .SetMinDuration(TDuration.FromMilliseconds(100))
    .SetMaxIterations(10000)
    .SetMinSamples(6)
    .SetWarmupIters(3);

  LSuite.Add('Alloc/64B', @BenchAlloc64);
  LSuite.Add('Alloc/1KB', @BenchAlloc1K);
  LSuite.Add('Raw/64B', @BenchRawAlloc64);
  LSuite.Add('Raw/1KB', @BenchRawAlloc1K);
  LSuite.Add('Pool/64B', @BenchPool64);

  LResults := LSuite.Run;

  WriteLn;
  WriteLn('=== benchstat format ===');
  WriteLn(LResults.ToBenchStat);
end.
