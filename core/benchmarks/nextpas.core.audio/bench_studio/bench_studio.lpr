program bench_studio;
{$I nextpas.core.settings.inc}{$Q-}{$R-}
uses
  SysUtils,
  nextpas.core.bench, nextpas.core.bench.intf,
  nextpas.core.time.base,
  nextpas.core.audio.base,
  nextpas.core.audio.studio.sequencer,
  nextpas.core.audio.studio.automation,
  nextpas.core.audio.timeline.intf,
  nextpas.core.audio.timeline;

var GSeq: IAudioSequencer; GCurve: TAutomationCurve; GTL: IAudioTimeline; GSink: UInt64;

procedure BenchSequencerFill(const ACtx: IBenchContext);
var B: TAudioBuffer;
begin
  B.Format:=AudioFormatCreate(48000,2,sfF32); B.FrameCount:=256; SetLength(B.Data,256*B.Format.BlockAlign);
  GSeq.FillRealtime(B,256);
  GSink:=GSink xor UInt64(B.FrameCount);
end;

procedure BenchAutomation(const ACtx: IBenchContext);
var V: Single;
begin
  V:=GCurve.ValueAt(100);
  GSink:=GSink xor UInt64(Trunc(V*1000));
end;

procedure BenchTimelineFill(const ACtx: IBenchContext);
var B: TAudioBuffer;
begin
  B.Format:=AudioFormatCreate(48000,2,sfF32); B.FrameCount:=256; SetLength(B.Data,256*B.Format.BlockAlign);
  GTL.FillRealtime(B,256);
  GSink:=GSink xor UInt64(B.FrameCount);
end;

var R: IBenchResults; N: TMidiNote; Buf: TAudioBuffer; Tr: TTimelineTrackId;
begin
  GSeq:=CreateAudioSequencer(AudioFormatCreate(48000,2,sfF32),120);
  N.Pitch:=60; N.Velocity:=100; N.StartFrame:=0; N.DurationFrames:=48000; GSeq.AddNote(N); GSeq.Play;
  GCurve:=TAutomationCurve.Create; GCurve.AddPoint(0,0); GCurve.AddPoint(1000,1);
  GTL:=CreateAudioTimeline(AudioFormatCreate(48000,2,sfF32));
  Tr:=GTL.AddTrack(1.0);
  Buf.Format:=AudioFormatCreate(48000,2,sfF32); Buf.FrameCount:=256; SetLength(Buf.Data,256*Buf.Format.BlockAlign);
  FillChar(Buf.Data[0], Length(Buf.Data), 0);
  GTL.AddClip(Tr, Buf, 0);
  GSink:=0;
  R:=TBenchSuite.Create('studio')
    .SetQuiet(True)
    .SetMinDuration(TDuration.FromMilliseconds(50))
    .SetMinSamples(5)
    .Add('Sequencer/256', @BenchSequencerFill)
    .Add('Automation/1', @BenchAutomation)
    .Add('Timeline/256', @BenchTimelineFill)
    .Run;
  WriteLn(R.PrintToConsole);
  WriteLn('ns/op studio');
  WriteLn('MB/s studio');
  ForceDirectories('build'); R.SaveToJSON('build/bench-studio.json');
  GCurve.Free;
end.
