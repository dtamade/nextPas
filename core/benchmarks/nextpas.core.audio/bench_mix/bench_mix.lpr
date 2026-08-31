program bench_mix;
{**
 * Benchmark for nextpas.core.audio.mix
 *
 *   MixInto / ApplyGain / ApplyGainRamp on 48k stereo 1s (≈192k samples)
 *   — IBenchContext ns/op + MB/s, captures gain≈0/1 fast-path benefit
}
{$I nextpas.core.settings.inc}{$Q-}{$R-}
uses
  SysUtils,
  nextpas.core.bench, nextpas.core.bench.intf,
  nextpas.core.time.base,
  nextpas.core.base,
  nextpas.core.audio.base,
  nextpas.core.audio.mix;

var
  GSrc, GDst: TAudioBuffer;
  GSink: UInt64;

procedure Prepare;
var
  I: Integer; P: PSingle; Fmt: TAudioFormat;
begin
  Fmt := AudioFormatCreate(48000, 2, sfF32);
  // 复用度：统一缓冲工厂（Silence/Clone）—— 工程与单测同源
  GSrc := AudioBufferCreateSilence(Fmt, 48000);
  P := PSingle(@GSrc.Data[0]);
  for I := 0 to GSrc.FrameCount * 2 - 1 do P[I] := 0.5;
  GDst := AudioBufferCreateSilence(Fmt, 48000);
end;

procedure BenchMixInto_Gain1(const ACtx: IBenchContext);
var
  LDst: TAudioBuffer;
begin
  LDst := AudioBufferClone(GDst);
  MixInto(LDst, GSrc, 1.0, 0);
  GSink := GSink xor UInt64(Length(LDst.Data));
  ACtx.SetBytes(Length(GSrc.Data));
end;

procedure BenchMixInto_Gain05(const ACtx: IBenchContext);
var
  LDst: TAudioBuffer;
begin
  LDst := AudioBufferClone(GDst);
  MixInto(LDst, GSrc, 0.5, 0);
  GSink := GSink xor UInt64(Length(LDst.Data));
  ACtx.SetBytes(Length(GSrc.Data));
end;

procedure BenchApplyGain_05(const ACtx: IBenchContext);
var
  LBuf: TAudioBuffer;
begin
  LBuf := AudioBufferClone(GSrc);
  ApplyGain(LBuf, 0.5);
  GSink := GSink xor UInt64(Length(LBuf.Data));
  ACtx.SetBytes(Length(LBuf.Data));
end;

procedure BenchRamp(const ACtx: IBenchContext);
var
  LBuf: TAudioBuffer;
begin
  LBuf := AudioBufferClone(GSrc);
  ApplyGainRamp(LBuf, 0, 1.0);
  GSink := GSink xor UInt64(Length(LBuf.Data));
  ACtx.SetBytes(Length(LBuf.Data));
end;

var
  LResults: IBenchResults;
begin
  Prepare;
  GSink := 0;
  LResults := TBenchSuite.Create('mix')
    .SetQuiet(True)
    .SetMinDuration(TDuration.FromMilliseconds(100))
    .SetMinSamples(5)
    .Add('MixInto/gain=1', @BenchMixInto_Gain1)
    .Add('MixInto/gain=0.5', @BenchMixInto_Gain05)
    .Add('ApplyGain/0.5', @BenchApplyGain_05)
    .Add('Ramp/0..1', @BenchRamp)
    .Run;
  WriteLn(LResults.PrintToConsole);
  ForceDirectories('build');
  LResults.SaveToJSON('build/bench-mix.json');
  if GSink = $FFFFFFFF then WriteLn('sink');
end.
