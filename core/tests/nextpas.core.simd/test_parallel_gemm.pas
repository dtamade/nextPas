program test_parallel;
{$I nextpas.core.settings.inc}
{$I nextpas.core.simd.settings.inc}
uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  SysUtils, Unix, BaseUnix,
  nextpas.core.simd,
  nextpas.core.simd.alloc,
  nextpas.core.simd.linalg.gemm,
  nextpas.core.simd.linalg.gemm.parallel;

function GetTimeUs: Int64;
var LTs: TTimeVal;
begin
  fpgettimeofday(@LTs, nil);
  Result := Int64(LTs.tv_sec) * 1000000 + LTs.tv_usec;
end;

var
  LA, LB, LC, LRef: PSingle;
  LI: SizeUInt;
  LT0: Int64;
  LMaxErr: Single;
  LErr: Single;
const
  M = 512; N = 512; K = 512;
begin
  LA := PSingle(SimdAlloc(M * K * 4));
  LB := PSingle(SimdAlloc(K * N * 4));
  LC := PSingle(SimdAlloc(M * N * 4));
  LRef := PSingle(SimdAlloc(M * N * 4));

  for LI := 0 to M*K-1 do LA[LI] := (LI mod 7) * 0.1 - 0.3;
  for LI := 0 to K*N-1 do LB[LI] := (LI mod 11) * 0.1 - 0.5;

  // Reference: single-threaded
  GemmBlockedF32(LA, LB, LRef, M, N, K, K, N, N);

  // Parallel
  GemmParallelF32(LA, LB, LC, M, N, K, K, N, N, 4);

  // Verify
  LMaxErr := 0;
  for LI := 0 to M*N-1 do
  begin
    LErr := System.Abs(LC[LI] - LRef[LI]);
    if LErr > LMaxErr then LMaxErr := LErr;
  end;
  WriteLn('Max error: ', LMaxErr:0:8);
  if LMaxErr > 1e-4 then
  begin
    WriteLn('FAIL: parallel GEMM mismatch');
    Halt(1);
  end;

  // Benchmark
  LT0 := GetTimeUs;
  for LI := 0 to 2 do
    GemmBlockedF32(LA, LB, LRef, M, N, K, K, N, N);
  WriteLn('Single-thread 512x512: ', (GetTimeUs - LT0) div 3, ' us');

  LT0 := GetTimeUs;
  for LI := 0 to 2 do
    GemmParallelF32(LA, LB, LC, M, N, K, K, N, N, 4);
  WriteLn('4-thread 512x512: ', (GetTimeUs - LT0) div 3, ' us');

  SimdFree(LRef); SimdFree(LC); SimdFree(LB); SimdFree(LA);
  WriteLn('PASS');
end.
