program gemm_bench;
{$I nextpas.core.settings.inc}{$Q-}{$R-}
uses nextpas.core.bench, nextpas.core.bench.intf, nextpas.core.simd.gemm;
const SIZES: array[0..4] of Integer = (64, 128, 256, 512, 1024);
var GA, GB, GC: array of Single;
procedure InitData(ASize: Integer);
var LI: Integer;
begin
  SetLength(GA, ASize * ASize); SetLength(GB, ASize * ASize); SetLength(GC, ASize * ASize);
  for LI := 0 to ASize * ASize - 1 do begin GA[LI] := 1.0 + LI * 0.001; GB[LI] := 2.0 + LI * 0.002; end;
end;
procedure BenchGemm64(const ACtx: IBenchContext);
begin InitData(64); GemmBlockedF32(@GA[0], @GB[0], @GC[0], 64, 64, 64); ACtx.SetBytes(64 * 64 * 4 * 3); end;
procedure BenchGemm128(const ACtx: IBenchContext);
begin InitData(128); GemmBlockedF32(@GA[0], @GB[0], @GC[0], 128, 128, 128); ACtx.SetBytes(128 * 128 * 4 * 3); end;
procedure BenchGemm256(const ACtx: IBenchContext);
begin InitData(256); GemmBlockedF32(@GA[0], @GB[0], @GC[0], 256, 256, 256); ACtx.SetBytes(256 * 256 * 4 * 3); end;
procedure BenchGemm512(const ACtx: IBenchContext);
begin InitData(512); GemmBlockedF32(@GA[0], @GB[0], @GC[0], 512, 512, 512); ACtx.SetBytes(512 * 512 * 4 * 3); end;
procedure BenchGemm1024(const ACtx: IBenchContext);
begin InitData(1024); GemmBlockedF32(@GA[0], @GB[0], @GC[0], 1024, 1024, 1024); ACtx.SetBytes(1024 * 1024 * 4 * 3); end;
var LSuite: IBenchSuite;
begin
  LSuite := TBenchSuite.Create('gemm');
  LSuite.Add('GemmBlockedF32/64', @BenchGemm64).Add('GemmBlockedF32/128', @BenchGemm128)
    .Add('GemmBlockedF32/256', @BenchGemm256).Add('GemmBlockedF32/512', @BenchGemm512).Add('GemmBlockedF32/1024', @BenchGemm1024);
  WriteLn(LSuite.Run.PrintToConsole);
end.
