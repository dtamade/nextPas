program simd_bench;
{$I nextpas.core.settings.inc}{$Q-}{$R-}
uses nextpas.core.bench, nextpas.core.bench.intf,
  nextpas.core.simd.dispatch, nextpas.core.simd.types,
  nextpas.core.simd.sse2, nextpas.core.simd.avx2,
  nextpas.core.simd.scalar_fallback;
const N = 1024 * 256;
var GA, GB, GC: array of Single; GD, GE, GF: array of Double;
procedure InitData;
var LI: Integer;
begin
  SetLength(GA, N); SetLength(GB, N); SetLength(GC, N);
  SetLength(GD, N); SetLength(GE, N); SetLength(GF, N);
  for LI := 0 to N - 1 do begin
    GA[LI] := 1.0 + LI * 0.001; GB[LI] := 2.0 + LI * 0.002; GC[LI] := 0;
    GD[LI] := 1.0 + LI * 0.001; GE[LI] := 2.0 + LI * 0.002; GF[LI] := 0;
  end;
end;
procedure BenchAddF32Scalar(const ACtx: IBenchContext);
begin TSimdScalarFallback.AddF32(@GA[0], @GB[0], @GC[0], N); ACtx.SetBytes(N * 4 * 3); end;
procedure BenchAddF32SSE2(const ACtx: IBenchContext);
begin if not CpuHasSSE2 then begin ACtx.Skip; Exit; end; TSimdSSE2.AddF32(@GA[0], @GB[0], @GC[0], N); ACtx.SetBytes(N * 4 * 3); end;
procedure BenchAddF32AVX2(const ACtx: IBenchContext);
begin if not CpuHasAVX2 then begin ACtx.Skip; Exit; end; TSimdAVX2.AddF32(@GA[0], @GB[0], @GC[0], N); ACtx.SetBytes(N * 4 * 3); end;
procedure BenchMulF32Scalar(const ACtx: IBenchContext);
begin TSimdScalarFallback.MulF32(@GA[0], @GB[0], @GC[0], N); ACtx.SetBytes(N * 4 * 3); end;
procedure BenchMulF32SSE2(const ACtx: IBenchContext);
begin if not CpuHasSSE2 then begin ACtx.Skip; Exit; end; TSimdSSE2.MulF32(@GA[0], @GB[0], @GC[0], N); ACtx.SetBytes(N * 4 * 3); end;
procedure BenchMulF32AVX2(const ACtx: IBenchContext);
begin if not CpuHasAVX2 then begin ACtx.Skip; Exit; end; TSimdAVX2.MulF32(@GA[0], @GB[0], @GC[0], N); ACtx.SetBytes(N * 4 * 3); end;
procedure BenchDotF32Scalar(const ACtx: IBenchContext);
begin TSimdScalarFallback.DotF32(@GA[0], @GB[0], N); ACtx.SetBytes(N * 4 * 2); end;
procedure BenchDotF32SSE2(const ACtx: IBenchContext);
begin if not CpuHasSSE2 then begin ACtx.Skip; Exit; end; TSimdSSE2.DotF32(@GA[0], @GB[0], N); ACtx.SetBytes(N * 4 * 2); end;
procedure BenchDotF32AVX2(const ACtx: IBenchContext);
begin if not CpuHasAVX2 then begin ACtx.Skip; Exit; end; TSimdAVX2.DotF32(@GA[0], @GB[0], N); ACtx.SetBytes(N * 4 * 2); end;
procedure BenchReduceSumF32Scalar(const ACtx: IBenchContext);
begin TSimdScalarFallback.ReduceSumF32(@GA[0], N); ACtx.SetBytes(N * 4); end;
procedure BenchReduceSumF32SSE2(const ACtx: IBenchContext);
begin if not CpuHasSSE2 then begin ACtx.Skip; Exit; end; TSimdSSE2.ReduceSumF32(@GA[0], N); ACtx.SetBytes(N * 4); end;
procedure BenchReduceSumF32AVX2(const ACtx: IBenchContext);
begin if not CpuHasAVX2 then begin ACtx.Skip; Exit; end; TSimdAVX2.ReduceSumF32(@GA[0], N); ACtx.SetBytes(N * 4); end;
procedure BenchAddF64Scalar(const ACtx: IBenchContext);
begin TSimdScalarFallback.AddF64(@GD[0], @GE[0], @GF[0], N); ACtx.SetBytes(N * 8 * 3); end;
procedure BenchAddF64SSE2(const ACtx: IBenchContext);
begin if not CpuHasSSE2 then begin ACtx.Skip; Exit; end; TSimdSSE2.AddF64(@GD[0], @GE[0], @GF[0], N); ACtx.SetBytes(N * 8 * 3); end;
procedure BenchAddF64AVX2(const ACtx: IBenchContext);
begin if not CpuHasAVX2 then begin ACtx.Skip; Exit; end; TSimdAVX2.AddF64(@GD[0], @GE[0], @GF[0], N); ACtx.SetBytes(N * 8 * 3); end;
procedure BenchMulF64Scalar(const ACtx: IBenchContext);
begin TSimdScalarFallback.MulF64(@GD[0], @GE[0], @GF[0], N); ACtx.SetBytes(N * 8 * 3); end;
procedure BenchMulF64SSE2(const ACtx: IBenchContext);
begin if not CpuHasSSE2 then begin ACtx.Skip; Exit; end; TSimdSSE2.MulF64(@GD[0], @GE[0], @GF[0], N); ACtx.SetBytes(N * 8 * 3); end;
procedure BenchMulF64AVX2(const ACtx: IBenchContext);
begin if not CpuHasAVX2 then begin ACtx.Skip; Exit; end; TSimdAVX2.MulF64(@GD[0], @GE[0], @GF[0], N); ACtx.SetBytes(N * 8 * 3); end;
procedure BenchDotF64Scalar(const ACtx: IBenchContext);
begin TSimdScalarFallback.DotF64(@GD[0], @GE[0], N); ACtx.SetBytes(N * 8 * 2); end;
procedure BenchDotF64SSE2(const ACtx: IBenchContext);
begin if not CpuHasSSE2 then begin ACtx.Skip; Exit; end; TSimdSSE2.DotF64(@GD[0], @GE[0], N); ACtx.SetBytes(N * 8 * 2); end;
procedure BenchDotF64AVX2(const ACtx: IBenchContext);
begin if not CpuHasAVX2 then begin ACtx.Skip; Exit; end; TSimdAVX2.DotF64(@GD[0], @GE[0], N); ACtx.SetBytes(N * 8 * 2); end;
procedure BenchReduceSumF64Scalar(const ACtx: IBenchContext);
begin TSimdScalarFallback.ReduceSumF64(@GD[0], N); ACtx.SetBytes(N * 8); end;
procedure BenchReduceSumF64SSE2(const ACtx: IBenchContext);
begin if not CpuHasSSE2 then begin ACtx.Skip; Exit; end; TSimdSSE2.ReduceSumF64(@GD[0], N); ACtx.SetBytes(N * 8); end;
procedure BenchReduceSumF64AVX2(const ACtx: IBenchContext);
begin if not CpuHasAVX2 then begin ACtx.Skip; Exit; end; TSimdAVX2.ReduceSumF64(@GD[0], N); ACtx.SetBytes(N * 8); end;
procedure BenchMinF32Scalar(const ACtx: IBenchContext);
begin TSimdScalarFallback.MinF32(@GA[0], @GB[0], @GC[0], N); ACtx.SetBytes(N * 4 * 3); end;
procedure BenchMinF32AVX2(const ACtx: IBenchContext);
begin if not CpuHasAVX2 then begin ACtx.Skip; Exit; end; TSimdAVX2.MinF32(@GA[0], @GB[0], @GC[0], N); ACtx.SetBytes(N * 4 * 3); end;
procedure BenchMaxF32Scalar(const ACtx: IBenchContext);
begin TSimdScalarFallback.MaxF32(@GA[0], @GB[0], @GC[0], N); ACtx.SetBytes(N * 4 * 3); end;
procedure BenchMaxF32AVX2(const ACtx: IBenchContext);
begin if not CpuHasAVX2 then begin ACtx.Skip; Exit; end; TSimdAVX2.MaxF32(@GA[0], @GB[0], @GC[0], N); ACtx.SetBytes(N * 4 * 3); end;
procedure BenchMulScalarF32Scalar(const ACtx: IBenchContext);
begin TSimdScalarFallback.MulScalarF32(@GA[0], @GB[0], 3.14, N); ACtx.SetBytes(N * 4 * 2); end;
procedure BenchMulScalarF32AVX2(const ACtx: IBenchContext);
begin if not CpuHasAVX2 then begin ACtx.Skip; Exit; end; TSimdAVX2.MulScalarF32(@GA[0], @GB[0], 3.14, N); ACtx.SetBytes(N * 4 * 2); end;
var LSuite: IBenchSuite;
begin
  InitData;
  LSuite := TBenchSuite.Create('simd');
  LSuite.Add('AddF32/Scalar', @BenchAddF32Scalar).Add('AddF32/SSE2', @BenchAddF32SSE2).Add('AddF32/AVX2', @BenchAddF32AVX2)
    .Add('MulF32/Scalar', @BenchMulF32Scalar).Add('MulF32/SSE2', @BenchMulF32SSE2).Add('MulF32/AVX2', @BenchMulF32AVX2)
    .Add('DotF32/Scalar', @BenchDotF32Scalar).Add('DotF32/SSE2', @BenchDotF32SSE2).Add('DotF32/AVX2', @BenchDotF32AVX2)
    .Add('ReduceSumF32/Scalar', @BenchReduceSumF32Scalar).Add('ReduceSumF32/SSE2', @BenchReduceSumF32SSE2).Add('ReduceSumF32/AVX2', @BenchReduceSumF32AVX2)
    .Add('AddF64/Scalar', @BenchAddF64Scalar).Add('AddF64/SSE2', @BenchAddF64SSE2).Add('AddF64/AVX2', @BenchAddF64AVX2)
    .Add('MulF64/Scalar', @BenchMulF64Scalar).Add('MulF64/SSE2', @BenchMulF64SSE2).Add('MulF64/AVX2', @BenchMulF64AVX2)
    .Add('DotF64/Scalar', @BenchDotF64Scalar).Add('DotF64/SSE2', @BenchDotF64SSE2).Add('DotF64/AVX2', @BenchDotF64AVX2)
    .Add('ReduceSumF64/Scalar', @BenchReduceSumF64Scalar).Add('ReduceSumF64/SSE2', @BenchReduceSumF64SSE2).Add('ReduceSumF64/AVX2', @BenchReduceSumF64AVX2)
    .Add('MinF32/Scalar', @BenchMinF32Scalar).Add('MinF32/AVX2', @BenchMinF32AVX2)
    .Add('MaxF32/Scalar', @BenchMaxF32Scalar).Add('MaxF32/AVX2', @BenchMaxF32AVX2)
    .Add('MulScalarF32/Scalar', @BenchMulScalarF32Scalar).Add('MulScalarF32/AVX2', @BenchMulScalarF32AVX2);
  WriteLn(LSuite.Run.PrintToConsole);
end.
