program bench_simd_comprehensive;
{$MODE OBJFPC}{$H+}
{$I ../../src/nextpas.core.settings.inc}
{$OPTIMIZATION LEVEL3}

uses
  {$IFDEF UNIX}cthreads, Unix,{$ENDIF}
  SysUtils,
  nextpas.core.simd,
  nextpas.core.simd.base,
  nextpas.core.simd.dispatch,
  nextpas.core.simd.algorithms;

const
  ARRAY_SIZE = 4096;
  ITERATIONS = 10000;
  WARMUP = 100;

var
  DataA, DataB, DataC: array[0..ARRAY_SIZE-1] of Single;
  StartTick, EndTick: Int64;
  ScalarNs, SimdNs: Double;
  iter: Integer;

function GetNanoTime: Int64;
{$IFDEF UNIX}
var tv: TTimeVal;
begin
  fpGettimeofday(@tv, nil);
  Result := Int64(tv.tv_sec) * 1000000000 + Int64(tv.tv_usec) * 1000;
end;
{$ELSE}
begin
  Result := GetTickCount64 * 1000000;
end;
{$ENDIF}

procedure InitData;
var j: Integer;
begin
  for j := 0 to ARRAY_SIZE - 1 do
  begin
    DataA[j] := (j + 1) * 0.01;
    DataB[j] := (ARRAY_SIZE - j) * 0.01;
  end;
end;

procedure BenchScalarArrayAdd;
var j: Integer;
begin
  for j := 0 to ARRAY_SIZE - 1 do
    DataC[j] := DataA[j] + DataB[j];
end;

procedure BenchScalarReduceSum;
var j: Integer; sum: Single;
begin
  sum := 0;
  for j := 0 to ARRAY_SIZE - 1 do
    sum := sum + DataA[j];
  DataC[0] := sum;
end;

procedure BenchScalarDot;
var j: Integer; sum: Single;
begin
  sum := 0;
  for j := 0 to ARRAY_SIZE - 1 do
    sum := sum + DataA[j] * DataB[j];
  DataC[0] := sum;
end;

procedure BenchScalarAxpy;
var j: Integer;
begin
  for j := 0 to ARRAY_SIZE - 1 do
    DataC[j] := 2.5 * DataA[j] + DataB[j];
end;

procedure RunBench(const aName: string; aScalarProc, aSimdProc: TProcedure);
var
  iter2: Integer;
begin
  // Warmup
  for iter2 := 1 to WARMUP do aScalarProc;
  for iter2 := 1 to WARMUP do aSimdProc;

  // Scalar
  StartTick := GetNanoTime;
  for iter2 := 1 to ITERATIONS do
    aScalarProc;
  EndTick := GetNanoTime;
  ScalarNs := (EndTick - StartTick) / ITERATIONS;

  // SIMD
  StartTick := GetNanoTime;
  for iter2 := 1 to ITERATIONS do
    aSimdProc;
  EndTick := GetNanoTime;
  SimdNs := (EndTick - StartTick) / ITERATIONS;

  WriteLn(Format('  %-20s  scalar=%8.1f ns  simd=%8.1f ns  speedup=%.2fx',
    [aName, ScalarNs, SimdNs, ScalarNs / SimdNs]));
end;

procedure SimdArrayAddWrapper;
begin
  SimdArrayAdd(@DataA[0], @DataB[0], @DataC[0], ARRAY_SIZE);
end;

procedure SimdReduceSumWrapper;
begin
  DataC[0] := SimdReduceSum(@DataA[0], ARRAY_SIZE);
end;

procedure SimdReduceDotWrapper;
begin
  DataC[0] := SimdReduceDot(@DataA[0], @DataB[0], ARRAY_SIZE);
end;

procedure SimdAxpyWrapper;
begin
  SimdArrayAxpy(2.5, @DataA[0], @DataB[0], @DataC[0], ARRAY_SIZE);
end;

begin
  InitData;

  WriteLn('=== nextpas.core.simd Comprehensive Benchmark ===');
  WriteLn(Format('  Array size: %d elements (%d bytes)', [ARRAY_SIZE, ARRAY_SIZE * 4]));
  WriteLn(Format('  Iterations: %d', [ITERATIONS]));
  WriteLn(Format('  Active backend: %d', [Ord(GetActiveBackend)]));
  WriteLn;

  WriteLn('--- Algorithms Layer (width-agnostic) vs Pure Scalar Loop ---');
  RunBench('ArrayAdd', @BenchScalarArrayAdd, @SimdArrayAddWrapper);
  RunBench('ReduceSum', @BenchScalarReduceSum, @SimdReduceSumWrapper);
  RunBench('ReduceDot', @BenchScalarDot, @SimdReduceDotWrapper);
  RunBench('AXPY', @BenchScalarAxpy, @SimdAxpyWrapper);

  WriteLn;
  WriteLn('--- Dispatch Overhead (single vector op) ---');

  // Measure dispatch overhead: call VecF32x4Add in a tight loop
  StartTick := GetNanoTime;
  for iter := 1 to 10000000 do
  begin
    DataC[0] := VecF32x4Add(
      TVecF32x4((@DataA[0])^),
      TVecF32x4((@DataB[0])^)
    ).f[0];
  end;
  EndTick := GetNanoTime;
  WriteLn(Format('  VecF32x4Add dispatch: %.1f ns/call (10M calls)',
    [(EndTick - StartTick) / 10000000.0]));

  WriteLn;
  WriteLn('=== Benchmark Complete ===');
end.
