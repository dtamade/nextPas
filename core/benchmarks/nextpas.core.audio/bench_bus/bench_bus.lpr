program bench_bus;
{$I nextpas.core.settings.inc}{$Q-}{$R-}
uses
  nextpas.core.fs,
  nextpas.core.bench, nextpas.core.bench.intf,
  nextpas.core.time.base,
  nextpas.core.base,
  nextpas.core.audio.base,
  nextpas.core.audio.bus;

var GMixer1, GMixer4: IAudioBusMixer;
    GBus1, GBus4a, GBus4b: IAudioBus;
    GOut1K, GOut4K: TAudioBuffer;
    GSink: UInt64;

procedure BenchBus1K(const ACtx: IBenchContext);
begin
  GMixer1.MixRealtime(GOut1K,1024);
  GSink:=GSink xor UInt64(GOut1K.Data[0]);
end;

procedure BenchBus4K(const ACtx: IBenchContext);
begin
  GMixer4.MixRealtime(GOut4K,4096);
  GSink:=GSink xor UInt64(GOut4K.Data[0]);
end;

procedure BenchBusSingle(const ACtx: IBenchContext);
var Tmp: TAudioBuffer;
begin
  Tmp.Format:=GOut1K.Format; Tmp.FrameCount:=256; SetLength(Tmp.Data,256*Tmp.Format.BlockAlign);
  GMixer1.MixRealtime(Tmp,256);
  GSink:=GSink xor UInt64(Tmp.Data[0]);
end;

var R: IBenchResults; Fmt: TAudioFormat;
begin
  Fmt:=AudioFormatCreate(48000,2,sfF32);
  GOut1K.Format:=Fmt; GOut1K.FrameCount:=1024; SetLength(GOut1K.Data,1024*Fmt.BlockAlign);
  GOut4K.Format:=Fmt; GOut4K.FrameCount:=4096; SetLength(GOut4K.Data,4096*Fmt.BlockAlign);
  GMixer1:=CreateAudioBusMixer;
  GBus1:=GMixer1.CreateBus(Fmt);
  GMixer4:=CreateAudioBusMixer;
  GBus4a:=GMixer4.CreateBus(Fmt);
  GBus4b:=GMixer4.CreateBus(Fmt);
  GSink:=0;
  R:=TBenchSuite.Create('bus')
    .SetQuiet(True)
    .SetMinDuration(TDuration.FromMilliseconds(50))
    .SetMinSamples(5)
    .Add('Mix/1K', @BenchBus1K)
    .Add('Mix/4K/2bus', @BenchBus4K)
    .Add('Single/256', @BenchBusSingle)
    .Run;
  WriteLn(R.PrintToConsole);
  WriteLn('ns/op bus');
  WriteLn('MB/s bus');
  MkdirAll('build'); R.SaveToJSON('build/bench-bus.json');
end.
