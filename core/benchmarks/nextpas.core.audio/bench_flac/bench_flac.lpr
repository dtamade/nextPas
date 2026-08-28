program bench_flac;
{**
 * Benchmark for nextpas.core.audio.codec.flac.decoder
 *
 *   Decode/33075f  — DecodeWhole tone_stereo_16.flac (33075 frames, f32)
 *
 * Preloads bytes once so IO does not pollute measurement.
}
{$I nextpas.core.settings.inc}{$Q-}{$R-}
uses
  nextpas.core.bench, nextpas.core.bench.intf,
  nextpas.core.time.base,
  nextpas.core.base,
  nextpas.core.io,
  nextpas.core.fs,
  nextpas.core.audio.base,
  nextpas.core.audio.codec.intf,
  nextpas.core.audio.codec.flac.decoder;

var
  GData: TBytes;
  GSink: UInt64;
  GBytes: Int64;

procedure LoadFixture;
var
  S: IStream;
  LAvail: Int64;
begin
  S := nextpas.core.fs.Open('/home/dtamade/projects/music888/tests/fixtures/tone_stereo_16.flac', [fmRead]);
  LAvail := S.Size;
  SetLength(GData, LAvail);
  if LAvail > 0 then S.Read(GData[0], LongInt(LAvail));
  GBytes := LAvail;
end;

procedure BenchDecode(const ACtx: IBenchContext);
var
  S: IStream;
  Dec: IAudioDecoder;
  Buf: TAudioBuffer;
begin
  S := BytesStream(0);
  if Length(GData) > 0 then S.Write(GData[0], Length(GData));
  S.Position := 0;
  Dec := CreateFlacDecoder;
  Buf := Dec.DecodeWhole(S);
  GSink := GSink xor UInt64(Buf.FrameCount) xor UInt64(Length(Buf.Data));
  ACtx.SetBytes(GBytes);
end;

var
  LResults: IBenchResults;
begin
  LoadFixture;
  GSink := 0;
  LResults := TBenchSuite.Create('flac')
    .SetQuiet(True)
    .SetMinDuration(TDuration.FromMilliseconds(100))
    .SetMinSamples(5)
    .Add('Decode/33k', @BenchDecode)
    .Run;
  WriteLn(LResults.PrintToConsole);
  ForceDirectories('build');
  LResults.SaveToJSON('build/bench-flac.json');
  if GSink = $FFFFFFFF then WriteLn('sink');
end.
