program bench_mp3;
{$I nextpas.core.settings.inc}{$Q-}{$R-}
uses
  nextpas.core.fs,
  nextpas.core.bench, nextpas.core.bench.intf,
  nextpas.core.time.base,
  nextpas.core.base,
  nextpas.core.io,
  nextpas.core.audio.base,
  nextpas.core.audio.codec.mp3;

var GStream: IStream; GSink: UInt64;

function BuildMp3Stream: IStream;
var B: TBytes;
begin
  SetLength(B, 1024); FillChar(B[0], Length(B), 0); B[0]:=$FF; B[1]:=$FB;
  Result:=BytesStream(0); Result.Write(B[0], Length(B)); Result.Position:=0;
end;

procedure BenchMp3Decode(const ACtx: IBenchContext);
var Buf: TAudioBuffer;
begin
  GStream.Position:=0; Buf:=CreateMp3Decoder.DecodeWhole(GStream); GSink:=GSink xor UInt64(Buf.FrameCount);
end;

procedure BenchMp3Probe(const ACtx: IBenchContext);
var B: TBytes;
begin
  SetLength(B,2); B[0]:=$FF; B[1]:=$FB; if Mp3Probe(B)=prMp3 then GSink:=GSink xor 1;
end;

var R: IBenchResults;
begin
  GStream:=BuildMp3Stream; GSink:=0;
  R:=TBenchSuite.Create('mp3')
    .SetQuiet(True)
    .SetMinDuration(TDuration.FromMilliseconds(50))
    .SetMinSamples(5)
    .Add('Decode/1K', @BenchMp3Decode)
    .Add('Probe/2B', @BenchMp3Probe)
    .Run;
  WriteLn(R.PrintToConsole);
  WriteLn('ns/op mp3');
  WriteLn('MB/s mp3');
  MkdirAll('build'); R.SaveToJSON('build/bench-mp3.json');
end.
