program fafafa_core_simd_batch_bench;

{$I ../../src/nextpas.core.settings.inc}
{$CODEPAGE UTF8}

uses
  {$IFDEF UNIX}
  cthreads, BaseUnix, Unix,
  {$ENDIF}
  {$IFDEF WINDOWS}
  Windows,
  {$ENDIF}
  nextpas.core.text.conv, Math,
  nextpas.core.simd,
  nextpas.core.simd.base,
  nextpas.core.simd.scalar,
  nextpas.core.simd.dispatch;

const
  N = 4096;
  WARMUP = 1000;
  ITERS = 50000;

var
  A, B, C, Dst: array[0..N-1] of Single;

procedure FillRandom;
var i: Integer;
begin
  for i := 0 to N-1 do
  begin
    A[i] := Sin(i * 0.7) * 50.0;
    B[i] := Cos(i * 1.1) * 30.0 + 1.0;
    C[i] := Sin(i * 0.3) * 10.0;
  end;
end;

function GetNanoTime: Int64;
{$IFDEF UNIX}
var tv: TTimeVal;
begin
  fpgettimeofday(@tv, nil);
  Result := Int64(tv.tv_sec) * 1000000000 + Int64(tv.tv_usec) * 1000;
end;
{$ELSE}
var f, c: Int64;
begin
  QueryPerformanceFrequency(f);
  QueryPerformanceCounter(c);
  Result := c * 1000000000 div f;
end;
{$ENDIF}

function BenchDispatch(const aName: string; aProc: TProcedure): Double;
var t0, t1: Int64; j: Integer;
begin
  for j := 0 to WARMUP-1 do aProc();
  t0 := GetNanoTime;
  for j := 0 to ITERS-1 do aProc();
  t1 := GetNanoTime;
  Result := (t1 - t0) / ITERS / N;
end;

// PLACEHOLDER_BENCH_PROCS

type
  TBenchProc = procedure;

procedure DoAdd; begin GetDispatchTable^.ArrayAddF32(@A[0], @B[0], @Dst[0], N); end;
procedure DoSub; begin GetDispatchTable^.ArraySubF32(@A[0], @B[0], @Dst[0], N); end;
procedure DoMul; begin GetDispatchTable^.ArrayMulF32(@A[0], @B[0], @Dst[0], N); end;
procedure DoDiv; begin GetDispatchTable^.ArrayDivF32(@A[0], @B[0], @Dst[0], N); end;
procedure DoMin; begin GetDispatchTable^.ArrayMinF32(@A[0], @B[0], @Dst[0], N); end;
procedure DoMax; begin GetDispatchTable^.ArrayMaxF32(@A[0], @B[0], @Dst[0], N); end;
procedure DoAbs; begin GetDispatchTable^.ArrayAbsF32(@A[0], @Dst[0], N); end;
procedure DoNeg; begin GetDispatchTable^.ArrayNegF32(@A[0], @Dst[0], N); end;
procedure DoSqrt;
var i: Integer;
begin
  for i := 0 to N-1 do Dst[i] := Abs(A[i]);
  GetDispatchTable^.ArraySqrtF32(@Dst[0], @Dst[0], N);
end;
procedure DoAddScalar; begin GetDispatchTable^.ArrayAddScalarF32(@A[0], @Dst[0], N, 3.14); end;
procedure DoMulScalar; begin GetDispatchTable^.ArrayMulScalarF32(@A[0], @Dst[0], N, 2.5); end;
procedure DoClamp; begin GetDispatchTable^.ArrayClampF32(@A[0], @Dst[0], N, -10.0, 25.0); end;
procedure DoFma; begin GetDispatchTable^.ArrayFmaF32(@A[0], @B[0], @C[0], @Dst[0], N); end;
procedure DoAxpy; begin GetDispatchTable^.ArrayAxpyF32(2.5, @A[0], @B[0], @Dst[0], N); end;
procedure DoReduceSum;
var r: Single;
begin r := GetDispatchTable^.ReduceSumF32(@A[0], N); if r = 0 then; end;
procedure DoReduceDot;
var r: Single;
begin r := GetDispatchTable^.ReduceDotF32(@A[0], @B[0], N); if r = 0 then; end;
procedure DoReduceMin;
var r: Single;
begin r := GetDispatchTable^.ReduceMinF32(@A[0], N); if r = 0 then; end;
procedure DoReduceMax;
var r: Single;
begin r := GetDispatchTable^.ReduceMaxF32(@A[0], N); if r = 0 then; end;

procedure DoScalarAdd; begin ScalarArrayAddF32(@A[0], @B[0], @Dst[0], N); end;
procedure DoScalarMul; begin ScalarArrayMulF32(@A[0], @B[0], @Dst[0], N); end;
procedure DoScalarReduceSum;
var r: Single;
begin r := ScalarReduceSumF32(@A[0], N); if r = 0 then; end;

procedure RunBench(const aName: string; aDispatch, aScalar: TBenchProc);
var
  tDisp, tScalar: Double;
begin
  tDisp := BenchDispatch(aName, TProcedure(aDispatch));
  tScalar := BenchDispatch(aName + '_scalar', TProcedure(aScalar));
  WriteLn(Format('  %-16s %6.2f ns/elem  (scalar: %6.2f ns/elem, speedup: %.1fx)',
    [aName, tDisp, tScalar, tScalar / tDisp]));
end;

procedure RunBenchSingle(const aName: string; aProc: TBenchProc);
var t: Double;
begin
  t := BenchDispatch(aName, TProcedure(aProc));
  WriteLn(Format('  %-16s %6.2f ns/elem', [aName, t]));
end;

begin
  SetExceptionMask([exInvalidOp, exDenormalized, exZeroDivide, exOverflow, exUnderflow, exPrecision]);
  FillRandom;

  WriteLn('[Batch F32 Benchmark] N=', N, ' ITERS=', ITERS);
  WriteLn('  Backend: ', GetBackendInfo(GetActiveBackend).Name);
  WriteLn('');

  RunBench('ArrayAddF32', @DoAdd, @DoScalarAdd);
  RunBench('ArrayMulF32', @DoMul, @DoScalarMul);
  RunBenchSingle('ArraySubF32', @DoSub);
  RunBenchSingle('ArrayDivF32', @DoDiv);
  RunBenchSingle('ArrayMinF32', @DoMin);
  RunBenchSingle('ArrayMaxF32', @DoMax);
  RunBenchSingle('ArrayAbsF32', @DoAbs);
  RunBenchSingle('ArrayNegF32', @DoNeg);
  RunBenchSingle('ArraySqrtF32', @DoSqrt);
  RunBenchSingle('ArrayAddScalar', @DoAddScalar);
  RunBenchSingle('ArrayMulScalar', @DoMulScalar);
  RunBenchSingle('ArrayClampF32', @DoClamp);
  RunBenchSingle('ArrayFmaF32', @DoFma);
  RunBenchSingle('ArrayAxpyF32', @DoAxpy);
  WriteLn('');
  RunBench('ReduceSumF32', @DoReduceSum, @DoScalarReduceSum);
  RunBenchSingle('ReduceDotF32', @DoReduceDot);
  RunBenchSingle('ReduceMinF32', @DoReduceMin);
  RunBenchSingle('ReduceMaxF32', @DoReduceMax);

  WriteLn('');
  WriteLn('[DONE]');
end.
