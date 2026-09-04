program bench_opus;
{$I nextpas.core.settings.inc}{$Q-}{$R-}
uses
  nextpas.core.fs,
  nextpas.core.bench, nextpas.core.bench.intf,
  nextpas.core.time.base,
  nextpas.core.base,
  nextpas.core.io,
  nextpas.core.audio.base,
  nextpas.core.audio.codec.opus;

var GStream: IStream; GSink: UInt64;

function BuildOpusStream: IStream;
var B: TBytes;
begin
  SetLength(B, 1024);
  FillChar(B[0], Length(B), 0);
  B[0]:=$4F; B[1]:=$67; B[2]:=$67; B[3]:=$53;
  B[28]:=$4F; B[29]:=$70; B[30]:=$75; B[31]:=$73;
  B[32]:=$48; B[33]:=$65; B[34]:=$61; B[35]:=$64;
  Result:=BytesStream(0);
  Result.Write(B[0], Length(B));
  Result.Position:=0;
end;

procedure BenchOpusDecode(const ACtx: IBenchContext);
var Buf: TAudioBuffer;
begin
  GStream.Position:=0;
  try
    Buf:=CreateOpusDecoder.DecodeWhole(GStream);
    GSink:=GSink xor UInt64(Buf.FrameCount);
  except
    GSink:=GSink xor 1;
  end;
end;

procedure BenchOpusProbe(const ACtx: IBenchContext);
var B: TBytes;
begin
  SetLength(B,8);
  B[0]:=$4F; B[1]:=$67; B[2]:=$67; B[3]:=$53;
  B[4]:=$4F; B[5]:=$70; B[6]:=$75; B[7]:=$73;
  if OpusProbe(B)=prOggOpus then GSink:=GSink xor 1;
end;

var R: IBenchResults;
begin
  GStream:=BuildOpusStream; GSink:=0;
  R:=TBenchSuite.Create('opus')
    .SetQuiet(True)
    .SetMinDuration(TDuration.FromMilliseconds(50))
    .SetMinSamples(5)
    .Add('Decode/1K', @BenchOpusDecode)
    .Add('Probe/8B', @BenchOpusProbe)
    .Run;
  WriteLn(R.PrintToConsole);
  WriteLn('ns/op opus');
  WriteLn('MB/s opus');
  MkdirAll('build'); R.SaveToJSON('build/bench-opus.json');
end.
