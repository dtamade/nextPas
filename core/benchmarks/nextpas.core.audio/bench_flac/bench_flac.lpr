program bench_flac;
{$I nextpas.core.settings.inc}{$Q-}{$R-}
uses
  nextpas.core.fs,
  nextpas.core.bench, nextpas.core.bench.intf,
  nextpas.core.time.base,
  nextpas.core.base,
  nextpas.core.io,
  nextpas.core.audio.base,
  nextpas.core.audio.codec.flac,
  nextpas.core.audio.codec.flac.decoder;

var
  GStream: IStream;
  GSink: UInt64;

function BuildFlacStream: IStream;
var B: TBytes;
begin
  SetLength(B, 1024);
  FillChar(B[0], Length(B), 0);
  B[0]:=$66; B[1]:=$4C; B[2]:=$61; B[3]:=$43;
  Result:=BytesStream(0);
  Result.Write(B[0], Length(B));
  Result.Position:=0;
end;

procedure BenchFlacDecode(const ACtx: IBenchContext);
var Buf: TAudioBuffer;
begin
  GStream.Position:=0;
  Buf:=CreateFlacDecoder.DecodeWhole(GStream);
  GSink:=GSink xor UInt64(Buf.FrameCount);
end;

procedure BenchFlacProbe(const ACtx: IBenchContext);
var B: TBytes;
begin
  SetLength(B,4); B[0]:=$66; B[1]:=$4C; B[2]:=$61; B[3]:=$43;
  if FlacProbe(B)=prFlac then GSink:=GSink xor 1;
end;

var R: IBenchResults;
begin
  GStream:=BuildFlacStream;
  GSink:=0;
  R:=TBenchSuite.Create('flac')
    .SetQuiet(True)
    .SetMinDuration(TDuration.FromMilliseconds(50))
    .SetMinSamples(5)
    .Add('Decode/1K', @BenchFlacDecode)
    .Add('Probe/4B', @BenchFlacProbe)
    .Run;
  WriteLn(R.PrintToConsole);
  WriteLn('ns/op flac');
  WriteLn('MB/s flac');
  MkdirAll('build');
  R.SaveToJSON('build/bench-flac.json');
end.
