program bench_mp3;
{**
 * Benchmark for nextpas.core.audio.codec.mp3.decoder
 *
 *   Decode fixtures from music888 if present, else synthetic silence.
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
  nextpas.core.audio.codec.mp3.decoder;

var
  GData: TBytes;
  GSink: UInt64;
  GBytes: Int64;
  GHasData: Boolean;

procedure LoadFixture;
var
  S: IStream;
  LAvail: Int64;
  P: string;
begin
  GHasData := False;
  // try music888 fixtures
  P := '/home/dtamade/projects/music888/tests/fixtures/tone_stereo_16.mp3';
  if FileExists(P) then
  begin
    S := nextpas.core.fs.Open(P, [fmRead]);
    LAvail := S.Size;
    SetLength(GData, LAvail);
    if LAvail > 0 then S.Read(GData[0], LongInt(LAvail));
    GBytes := LAvail;
    GHasData := LAvail > 0;
    Exit;
  end;
  // fallback: empty will be skipped in bench
  SetLength(GData, 0);
end;

procedure BenchDecode(const ACtx: IBenchContext);
var
  S: IStream;
  Dec: IAudioDecoder;
  Buf: TAudioBuffer;
begin
  if not GHasData then Exit;
  S := BytesStream(0);
  if Length(GData) > 0 then S.Write(GData[0], Length(GData));
  S.Position := 0;
  Dec := CreateMp3Decoder;
  Buf := Dec.DecodeWhole(S);
  GSink := GSink xor UInt64(Buf.FrameCount) xor UInt64(Length(Buf.Data));
  ACtx.SetBytes(GBytes);
end;

var
  LResults: IBenchResults;
begin
  LoadFixture;
  GSink := 0;
  if not GHasData then
  begin
    WriteLn('bench_mp3: no fixture, skip');
    Halt(0);
  end;
  LResults := TBenchSuite.Create('mp3')
    .SetQuiet(True)
    .SetMinDuration(TDuration.FromMilliseconds(100))
    .SetMinSamples(5)
    .Add('Decode', @BenchDecode)
    .Run;
  WriteLn(LResults.PrintToConsole);
  ForceDirectories('build');
  LResults.SaveToJSON('build/bench-mp3.json');
  if GSink = $FFFFFFFF then WriteLn('sink');
end.
