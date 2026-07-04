program fft_bench;
{$I nextpas.core.settings.inc}{$Q-}{$R-}
uses nextpas.core.bench, nextpas.core.bench.intf,
  nextpas.core.simd.fft, nextpas.core.simd.types;
const SIZES: array[0..5] of Integer = (256, 1024, 4096, 16384, 65536, 262144);
var GInput: array of Single; GBuf: array of Single;
procedure InitData;
var LI: Integer;
begin
  SetLength(GInput, 262144); SetLength(GBuf, 262144 * 2);
  for LI := 0 to 262143 do GInput[LI] := Sin(LI * 0.01) + Cos(LI * 0.023);
end;
procedure BenchFftRadix2F32_256(const ACtx: IBenchContext);
begin FftRadix2F32(@GInput[0], @GBuf[0], 256); ACtx.SetBytes(256 * 4); end;
procedure BenchFftRadix2F32_1024(const ACtx: IBenchContext);
begin FftRadix2F32(@GInput[0], @GBuf[0], 1024); ACtx.SetBytes(1024 * 4); end;
procedure BenchFftRadix2F32_4096(const ACtx: IBenchContext);
begin FftRadix2F32(@GInput[0], @GBuf[0], 4096); ACtx.SetBytes(4096 * 4); end;
procedure BenchFftRadix2F32_16384(const ACtx: IBenchContext);
begin FftRadix2F32(@GInput[0], @GBuf[0], 16384); ACtx.SetBytes(16384 * 4); end;
procedure BenchFftRadix2F32_65536(const ACtx: IBenchContext);
begin FftRadix2F32(@GInput[0], @GBuf[0], 65536); ACtx.SetBytes(65536 * 4); end;
procedure BenchFftRadix2F32_262144(const ACtx: IBenchContext);
begin FftRadix2F32(@GInput[0], @GBuf[0], 262144); ACtx.SetBytes(262144 * 4); end;
var LSuite: IBenchSuite;
begin
  InitData;
  LSuite := TBenchSuite.Create('fft');
  LSuite.Add('FftRadix2F32/256', @BenchFftRadix2F32_256).Add('FftRadix2F32/1024', @BenchFftRadix2F32_1024)
    .Add('FftRadix2F32/4096', @BenchFftRadix2F32_4096).Add('FftRadix2F32/16384', @BenchFftRadix2F32_16384)
    .Add('FftRadix2F32/65536', @BenchFftRadix2F32_65536).Add('FftRadix2F32/262144', @BenchFftRadix2F32_262144);
  WriteLn(LSuite.Run.PrintToConsole);
end.
