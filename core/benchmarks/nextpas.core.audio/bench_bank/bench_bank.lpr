program bench_bank;
{$I nextpas.core.settings.inc}{$Q-}{$R-}
uses
  SysUtils,
  nextpas.core.bench, nextpas.core.bench.intf,
  nextpas.core.time.base,
  nextpas.core.audio.base,
  nextpas.core.audio.bank;

var GBank: IAudioBank;
    GOut1K, GOut4K: TAudioBuffer;
    GSink: UInt64;

procedure BenchBank1K(const ACtx: IBenchContext);
begin
  GBank.FillRealtime(GOut1K,1024);
  GSink:=GSink xor UInt64(GOut1K.Data[0]);
end;

procedure BenchBank4K(const ACtx: IBenchContext);
begin
  GBank.FillRealtime(GOut4K,4096);
  GSink:=GSink xor UInt64(GOut4K.Data[0]);
end;

procedure BenchBankPlay(const ACtx: IBenchContext);
var Id: TAudioBankId; V: TBankVoiceId;
begin
  Id:=GBank.FindByName('tone');
  V:=GBank.Play(Id,0.9,0,1.0,False);
  GBank.StopVoice(V);
  GSink:=GSink xor UInt64(V);
end;

var R: IBenchResults; Fmt: TAudioFormat; Buf: TAudioBuffer; I: Integer; P: PSingle;
begin
  Fmt:=AudioFormatCreate(48000,2,sfF32);
  GOut1K.Format:=Fmt; GOut1K.FrameCount:=1024; SetLength(GOut1K.Data,1024*Fmt.BlockAlign);
  GOut4K.Format:=Fmt; GOut4K.FrameCount:=4096; SetLength(GOut4K.Data,4096*Fmt.BlockAlign);
  GBank:=CreateAudioBank(Fmt);
  Buf.Format:=Fmt; Buf.FrameCount:=1024; SetLength(Buf.Data,1024*Fmt.BlockAlign);
  P:=PSingle(@Buf.Data[0]);
  for I:=0 to 1024*2-1 do P[I]:=Sin(I*0.02)*0.5;
  GBank.Add('tone',Buf);
  GBank.Play(GBank.FindByName('tone'));
  GSink:=0;
  R:=TBenchSuite.Create('bank')
    .SetQuiet(True)
    .SetMinDuration(TDuration.FromMilliseconds(50))
    .SetMinSamples(5)
    .Add('Fill/1K', @BenchBank1K)
    .Add('Fill/4K', @BenchBank4K)
    .Add('Play/Stop', @BenchBankPlay)
    .Run;
  WriteLn(R.PrintToConsole);
  WriteLn('ns/op bank');
  WriteLn('MB/s bank');
  ForceDirectories('build'); R.SaveToJSON('build/bench-bank.json');
end.
