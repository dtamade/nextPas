program bench_mix;
{$I nextpas.core.settings.inc}{$Q-}{$R-}
uses
  SysUtils,
  nextpas.core.bench, nextpas.core.bench.intf,
  nextpas.core.time.base,
  nextpas.core.audio.base,
  nextpas.core.audio.mix,
  nextpas.core.audio.simd;

var GDst, GSrc: TAudioBuffer; GSink: UInt64;

procedure BenchMixInto(const ACtx: IBenchContext);
var LDst: TAudioBuffer;
begin
  LDst:=GDst;
  MixInto(LDst, GSrc, 0.5, 0);
  GSink:=GSink xor UInt64(LDst.FrameCount);
end;

procedure BenchApplyGain(const ACtx: IBenchContext);
var L: TAudioBuffer;
begin
  L:=GSrc;
  ApplyGain(L, 0.8);
  GSink:=GSink xor UInt64(L.FrameCount);
end;

procedure BenchSimdAdd(const ACtx: IBenchContext);
var D: array[0..255] of Single; S: array[0..255] of Single; I: Integer;
begin
  for I:=0 to 255 do begin D[I]:=0.5; S[I]:=0.2; end;
  SimdAddF32(@S[0], @D[0], 256, 1.0);
  GSink:=GSink xor UInt64(Trunc(D[0]*1000));
end;

var R: IBenchResults; Fmt: TAudioFormat; I: Integer;
begin
  Fmt:=AudioFormatCreate(48000,2,sfF32);
  GDst.Format:=Fmt; GDst.FrameCount:=1024; SetLength(GDst.Data,1024*Fmt.BlockAlign);
  GSrc.Format:=Fmt; GSrc.FrameCount:=1024; SetLength(GSrc.Data,1024*Fmt.BlockAlign);
  for I:=0 to 2047 do PSingle(@GSrc.Data[I*4])^:=0.1;
  GSink:=0;
  R:=TBenchSuite.Create('mix')
    .SetQuiet(True)
    .SetMinDuration(TDuration.FromMilliseconds(50))
    .SetMinSamples(5)
    .Add('MixInto/1K', @BenchMixInto)
    .Add('ApplyGain/1K', @BenchApplyGain)
    .Add('SimdAdd/256', @BenchSimdAdd)
    .Run;
  WriteLn(R.PrintToConsole);
  WriteLn('ns/op mix');
  WriteLn('MB/s mix');
  ForceDirectories('build'); R.SaveToJSON('build/bench-mix.json');
end.
