program bench_vorbis;
{$I nextpas.core.settings.inc}{$Q-}{$R-}
uses
  nextpas.core.fs,
  nextpas.core.bench, nextpas.core.bench.intf,
  nextpas.core.time.base,
  nextpas.core.base,
  nextpas.core.io,
  nextpas.core.audio.base,
  nextpas.core.audio.codec.vorbis;

var GStream: IStream; GSink: UInt64;

function BuildVorbisStream: IStream;
var B: TBytes;
begin
  SetLength(B, 1024);
  FillChar(B[0], Length(B), 0);
  B[0]:=$4F; B[1]:=$67; B[2]:=$67; B[3]:=$53;
  B[28]:=$01; B[29]:=$76; B[30]:=$6F; B[31]:=$72;
  B[32]:=$62; B[33]:=$69; B[34]:=$73;
  Result:=BytesStream(0);
  Result.Write(B[0], Length(B));
  Result.Position:=0;
end;

procedure BenchVorbisDecode(const ACtx: IBenchContext);
var Buf: TAudioBuffer;
begin
  GStream.Position:=0;
  try
    Buf:=CreateVorbisDecoder.DecodeWhole(GStream);
    GSink:=GSink xor UInt64(Buf.FrameCount);
  except
    GSink:=GSink xor 1;
  end;
end;

procedure BenchVorbisProbe(const ACtx: IBenchContext);
var B: TBytes;
begin
  SetLength(B,4); B[0]:=$4F; B[1]:=$67; B[2]:=$67; B[3]:=$53;
  if VorbisProbe(B)=prOggVorbis then GSink:=GSink xor 1;
end;

var R: IBenchResults;
begin
  GStream:=BuildVorbisStream; GSink:=0;
  R:=TBenchSuite.Create('vorbis')
    .SetQuiet(True)
    .SetMinDuration(TDuration.FromMilliseconds(50))
    .SetMinSamples(5)
    .Add('Decode/1K', @BenchVorbisDecode)
    .Add('Probe/4B', @BenchVorbisProbe)
    .Run;
  WriteLn(R.PrintToConsole);
  WriteLn('ns/op vorbis');
  WriteLn('MB/s vorbis');
  MkdirAll('build'); R.SaveToJSON('build/bench-vorbis.json');
end.
