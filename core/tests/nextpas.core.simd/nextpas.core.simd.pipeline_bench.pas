program nextpas.core.simd.pipeline_bench;

{$I ../../src/nextpas.core.settings.inc}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  nextpas.core.simd,
  nextpas.core.simd.base,
  nextpas.core.simd.dispatch,
  nextpas.core.simd.alloc,
  nextpas.core.simd.arrays.typed,
  nextpas.core.simd.pipeline;

const
  WARMUP = 100;
  ITERS  = 10000;

var
  g_Src, g_Dst, g_Tmp, g_Y: PSingle;
  g_Count: SizeUInt;

function RdTsc: Int64; assembler; nostackframe;
asm
  rdtsc
  shl rdx, 32
  or rax, rdx
end;

procedure Setup(aCount: SizeUInt);
var i: SizeUInt;
begin
  g_Count := aCount;
  g_Src := PSingle(SimdAlloc(aCount * SizeOf(Single)));
  g_Dst := PSingle(SimdAlloc(aCount * SizeOf(Single)));
  g_Tmp := PSingle(SimdAlloc(aCount * SizeOf(Single)));
  g_Y   := PSingle(SimdAlloc(aCount * SizeOf(Single)));
  for i := 0 to aCount - 1 do
  begin
    g_Src[i] := (i mod 1000) * 0.001;
    g_Y[i] := 1.0;
  end;
end;

procedure Teardown;
begin
  SimdFree(g_Src); SimdFree(g_Dst); SimdFree(g_Tmp); SimdFree(g_Y);
end;

procedure BenchLinearReLU;
var
  i: Integer;
  t0, t1: Int64;
  LManual, LPipeline: Double;
begin
  for i := 0 to WARMUP - 1 do
  begin
    ArrayLinearF32(g_Src, g_Tmp, g_Count, 2.0, -0.5);
    ArrayReLUF32(g_Tmp, g_Dst, g_Count);
  end;
  t0 := RdTsc;
  for i := 0 to ITERS - 1 do
  begin
    ArrayLinearF32(g_Src, g_Tmp, g_Count, 2.0, -0.5);
    ArrayReLUF32(g_Tmp, g_Dst, g_Count);
  end;
  t1 := RdTsc;
  LManual := (t1 - t0) / ITERS / g_Count;

  for i := 0 to WARMUP - 1 do
    TSimdF32Pipeline.From(g_Src, g_Count).Linear(2.0, -0.5).ReLU.Into(g_Dst);
  t0 := RdTsc;
  for i := 0 to ITERS - 1 do
    TSimdF32Pipeline.From(g_Src, g_Count).Linear(2.0, -0.5).ReLU.Into(g_Dst);
  t1 := RdTsc;
  LPipeline := (t1 - t0) / ITERS / g_Count;

  WriteLn('  Linear+ReLU:');
  WriteLn('    Manual (2 pass): ', LManual:0:3, ' cyc/elem');
  WriteLn('    Pipeline fused:  ', LPipeline:0:3, ' cyc/elem');
  WriteLn('    Speedup:         ', LManual/LPipeline:0:2, 'x');
end;

procedure BenchAxpy;
var
  i: Integer;
  t0, t1: Int64;
  LManual, LPipeline: Double;
begin
  for i := 0 to WARMUP - 1 do
  begin
    ArrayMulScalarF32(g_Src, g_Tmp, g_Count, 3.0);
    ArrayAddF32(g_Tmp, g_Y, g_Dst, g_Count);
  end;
  t0 := RdTsc;
  for i := 0 to ITERS - 1 do
  begin
    ArrayMulScalarF32(g_Src, g_Tmp, g_Count, 3.0);
    ArrayAddF32(g_Tmp, g_Y, g_Dst, g_Count);
  end;
  t1 := RdTsc;
  LManual := (t1 - t0) / ITERS / g_Count;

  for i := 0 to WARMUP - 1 do
    TSimdF32Pipeline.From(g_Src, g_Count).MulScalar(3.0).Add(g_Y).Into(g_Dst);
  t0 := RdTsc;
  for i := 0 to ITERS - 1 do
    TSimdF32Pipeline.From(g_Src, g_Count).MulScalar(3.0).Add(g_Y).Into(g_Dst);
  t1 := RdTsc;
  LPipeline := (t1 - t0) / ITERS / g_Count;

  WriteLn('  Axpy (3*X+Y):');
  WriteLn('    Manual (2 pass): ', LManual:0:3, ' cyc/elem');
  WriteLn('    Pipeline fused:  ', LPipeline:0:3, ' cyc/elem');
  WriteLn('    Speedup:         ', LManual/LPipeline:0:2, 'x');
end;

procedure BenchAbsDiff;
var
  i: Integer;
  t0, t1: Int64;
  LManual, LPipeline: Double;
begin
  for i := 0 to WARMUP - 1 do
  begin
    ArraySubF32(g_Src, g_Y, g_Tmp, g_Count);
    ArrayAbsF32(g_Tmp, g_Dst, g_Count);
  end;
  t0 := RdTsc;
  for i := 0 to ITERS - 1 do
  begin
    ArraySubF32(g_Src, g_Y, g_Tmp, g_Count);
    ArrayAbsF32(g_Tmp, g_Dst, g_Count);
  end;
  t1 := RdTsc;
  LManual := (t1 - t0) / ITERS / g_Count;

  for i := 0 to WARMUP - 1 do
    TSimdF32Pipeline.From(g_Src, g_Count).Sub(g_Y).Abs.Into(g_Dst);
  t0 := RdTsc;
  for i := 0 to ITERS - 1 do
    TSimdF32Pipeline.From(g_Src, g_Count).Sub(g_Y).Abs.Into(g_Dst);
  t1 := RdTsc;
  LPipeline := (t1 - t0) / ITERS / g_Count;

  WriteLn('  AbsDiff (|X-Y|):');
  WriteLn('    Manual (2 pass): ', LManual:0:3, ' cyc/elem');
  WriteLn('    Pipeline fused:  ', LPipeline:0:3, ' cyc/elem');
  WriteLn('    Speedup:         ', LManual/LPipeline:0:2, 'x');
end;

procedure BenchChainedAffine;
var
  i: Integer;
  t0, t1: Int64;
  LManual, LPipeline: Double;
begin
  for i := 0 to WARMUP - 1 do
  begin
    ArrayMulScalarF32(g_Src, g_Tmp, g_Count, 2.0);
    ArrayMulScalarF32(g_Tmp, g_Tmp, g_Count, 3.0);
    ArrayAddScalarF32(g_Tmp, g_Dst, g_Count, 5.0);
  end;
  t0 := RdTsc;
  for i := 0 to ITERS - 1 do
  begin
    ArrayMulScalarF32(g_Src, g_Tmp, g_Count, 2.0);
    ArrayMulScalarF32(g_Tmp, g_Tmp, g_Count, 3.0);
    ArrayAddScalarF32(g_Tmp, g_Dst, g_Count, 5.0);
  end;
  t1 := RdTsc;
  LManual := (t1 - t0) / ITERS / g_Count;

  for i := 0 to WARMUP - 1 do
    TSimdF32Pipeline.From(g_Src, g_Count).MulScalar(2).MulScalar(3).AddScalar(5).Into(g_Dst);
  t0 := RdTsc;
  for i := 0 to ITERS - 1 do
    TSimdF32Pipeline.From(g_Src, g_Count).MulScalar(2).MulScalar(3).AddScalar(5).Into(g_Dst);
  t1 := RdTsc;
  LPipeline := (t1 - t0) / ITERS / g_Count;

  WriteLn('  Chained Affine (Mul*2, Mul*3, Add+5 -> Linear(6,5)):');
  WriteLn('    Manual (3 pass): ', LManual:0:3, ' cyc/elem');
  WriteLn('    Pipeline fused:  ', LPipeline:0:3, ' cyc/elem');
  WriteLn('    Speedup:         ', LManual/LPipeline:0:2, 'x');
end;

begin
  WriteLn('[Pipeline Fusion Benchmark]');
  WriteLn('Backend: ', GetBackendInfo(GetActiveBackend).Name);
  WriteLn('');

  WriteLn('--- L1 fit (4K floats = 16 KB) ---');
  Setup(4096);
  BenchLinearReLU;
  BenchAxpy;
  BenchAbsDiff;
  BenchChainedAffine;
  Teardown;

  WriteLn('');
  WriteLn('--- L2 fit (64K floats = 256 KB) ---');
  Setup(65536);
  BenchLinearReLU;
  BenchAxpy;
  BenchAbsDiff;
  BenchChainedAffine;
  Teardown;

  WriteLn('');
  WriteLn('--- Memory bound (4M floats = 16 MB) ---');
  Setup(4 * 1024 * 1024);
  BenchLinearReLU;
  BenchAxpy;
  BenchAbsDiff;
  BenchChainedAffine;
  Teardown;
end.
