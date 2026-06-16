program nextpas.core.simd.avx512_bench;

{$I ../../src/nextpas.core.settings.inc}
{$CODEPAGE UTF8}

uses
  {$IFDEF UNIX}
  cthreads, Unix,
  {$ENDIF}
  {$IFDEF WINDOWS}
  Windows,
  {$ENDIF}
  nextpas.core.text.conv, Math,
  nextpas.core.simd,
  nextpas.core.simd.base,
  nextpas.core.simd.dispatch;

const
  N = 65536;
  ITERS = 5000;

var
  Src1, Src2, Dst: array[0..N-1] of Single;

function BoolToYesNo(const AValue: Boolean): string; inline;
begin
  if AValue then
    Result := 'YES'
  else
    Result := 'NO';
end;

function GetTimeUs: Int64;
{$IFDEF UNIX}
var tv: timeval;
begin
  fpgettimeofday(@tv, nil);
  Result := Int64(tv.tv_sec) * 1000000 + tv.tv_usec;
end;
{$ENDIF}
{$IFDEF WINDOWS}
var freq, cnt: Int64;
begin
  QueryPerformanceFrequency(freq);
  QueryPerformanceCounter(cnt);
  Result := cnt * 1000000 div freq;
end;
{$ENDIF}

procedure BenchOp(const aName: string; aIters: Integer);
var
  t0, t1: Int64;
  ns_per_elem: Double;
  total_elems: Int64;
begin
  total_elems := Int64(aIters) * N;
  t0 := GetTimeUs;

  // The caller already ran the operation in a loop before calling this
  // This function just formats the timing result
  t1 := GetTimeUs;
  ns_per_elem := (t1 - t0) * 1000.0 / total_elems;
  WriteLn(Format('  %-20s %6.2f ns/elem  (%d M elems/sec)',
    [aName, ns_per_elem, Round(1000.0 / ns_per_elem)]));
end;

procedure RunBench(const aName: string; aBackend: TSimdBackend);
var
  i: Integer;
  t0, t1: Int64;

  procedure Report(const opName: string; startUs, endUs: Int64);
  var ns: Double;
  begin
    ns := (endUs - startUs) * 1000.0 / (Int64(ITERS) * N);
    WriteLn(Format('  %-20s %6.2f ns/elem  (%d M elems/sec)',
      [opName, ns, Round(1000.0 / ns)]));
  end;

begin
  if not TrySetActiveBackend(aBackend) then
  begin
    WriteLn(Format('  [SKIP] %s backend not available', [aName]));
    WriteLn('');
    Exit;
  end;

  WriteLn(Format('--- %s (N=%d, ITERS=%d) ---', [aName, N, ITERS]));

  // Warmup
  for i := 0 to 2 do ArrayAddF32(@Src1[0], @Src2[0], @Dst[0], N);

  // ArrayAddF32
  t0 := GetTimeUs;
  for i := 0 to ITERS - 1 do ArrayAddF32(@Src1[0], @Src2[0], @Dst[0], N);
  t1 := GetTimeUs;
  Report('ArrayAddF32', t0, t1);

  // ArrayMulF32
  t0 := GetTimeUs;
  for i := 0 to ITERS - 1 do ArrayMulF32(@Src1[0], @Src2[0], @Dst[0], N);
  t1 := GetTimeUs;
  Report('ArrayMulF32', t0, t1);

  // ArrayDivF32
  t0 := GetTimeUs;
  for i := 0 to ITERS - 1 do ArrayDivF32(@Src1[0], @Src2[0], @Dst[0], N);
  t1 := GetTimeUs;
  Report('ArrayDivF32', t0, t1);

  // ArrayAbsF32
  t0 := GetTimeUs;
  for i := 0 to ITERS - 1 do ArrayAbsF32(@Src1[0], @Dst[0], N);
  t1 := GetTimeUs;
  Report('ArrayAbsF32', t0, t1);

  // ArrayNegF32
  t0 := GetTimeUs;
  for i := 0 to ITERS - 1 do ArrayNegF32(@Src1[0], @Dst[0], N);
  t1 := GetTimeUs;
  Report('ArrayNegF32', t0, t1);

  // ArraySqrtF32
  t0 := GetTimeUs;
  for i := 0 to ITERS - 1 do ArraySqrtF32(@Src1[0], @Dst[0], N);
  t1 := GetTimeUs;
  Report('ArraySqrtF32', t0, t1);

  // ReduceSumF32
  t0 := GetTimeUs;
  for i := 0 to ITERS - 1 do ReduceSumF32(@Src1[0], N);
  t1 := GetTimeUs;
  Report('ReduceSumF32', t0, t1);

  // ArrayExpF32
  t0 := GetTimeUs;
  for i := 0 to ITERS - 1 do ArrayExpF32(@Src1[0], @Dst[0], N);
  t1 := GetTimeUs;
  Report('ArrayExpF32', t0, t1);

  // ArrayLogF32
  t0 := GetTimeUs;
  for i := 0 to ITERS - 1 do ArrayLogF32(@Src1[0], @Dst[0], N);
  t1 := GetTimeUs;
  Report('ArrayLogF32', t0, t1);

  // === Fused vs Separate comparison ===
  // Linear (fused): dst = src*scale+bias — 1 pass
  t0 := GetTimeUs;
  for i := 0 to ITERS - 1 do ArrayLinearF32(@Src1[0], @Dst[0], N, 2.5, 1.0);
  t1 := GetTimeUs;
  Report('Linear(fused)', t0, t1);

  // Linear (separate): MulScalar + AddScalar — 2 passes
  t0 := GetTimeUs;
  for i := 0 to ITERS - 1 do
  begin
    ArrayMulScalarF32(@Src1[0], @Dst[0], N, 2.5);
    ArrayAddScalarF32(@Dst[0], @Dst[0], N, 1.0);
  end;
  t1 := GetTimeUs;
  Report('Linear(2-pass)', t0, t1);

  // ReLU
  t0 := GetTimeUs;
  for i := 0 to ITERS - 1 do ArrayReLUF32(@Src1[0], @Dst[0], N);
  t1 := GetTimeUs;
  Report('ReLU(fused)', t0, t1);

  WriteLn('');
  ResetToAutomaticBackend;
end;

var i: Integer;
begin
  SetExceptionMask([exInvalidOp, exDenormalized, exZeroDivide, exOverflow, exUnderflow, exPrecision]);

  WriteLn('=== AVX-512 Performance Benchmark ===');
  WriteLn(Format('Platform: %s', [{$IFDEF WINDOWS}'Windows'{$ELSE}'Linux'{$ENDIF}]));
  WriteLn(Format('Default backend: %s', [GetBackendInfo(GetActiveBackend).Name]));
  WriteLn('');

  // CPU feature detection
  WriteLn('CPU Feature Detection:');
  WriteLn('  SSE2:    ', BoolToYesNo(IsBackendRegistered(sbSSE2)));
  WriteLn('  AVX2:    ', BoolToYesNo(IsBackendRegistered(sbAVX2)));
  WriteLn('  AVX-512: ', BoolToYesNo(IsBackendRegistered(sbAVX512)));
  WriteLn('');

  if not IsBackendRegistered(sbAVX512) then
  begin
    WriteLn('[ERROR] This CPU does NOT support AVX-512!');
    WriteLn('        This benchmark requires AVX-512F hardware.');
    WriteLn('[RESULT] SKIPPED (no AVX-512)');
    Halt(2);
  end;

  // Init data
  for i := 0 to N - 1 do
  begin
    Src1[i] := Sin(i * 0.001) * 10 + 0.1;
    Src2[i] := Cos(i * 0.001) * 5 + 1.0;
  end;

  // Benchmark each backend
  RunBench('Scalar', sbScalar);
  RunBench('SSE2', sbSSE2);
  RunBench('AVX2', sbAVX2);
  RunBench('AVX-512', sbAVX512);

  WriteLn('=== Done ===');
end.
