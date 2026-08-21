program bench_pcm_wav;
{**
 * Benchmarks for nextpas.core.audio.pcm_wav.
 *
 *   Parse/64KB  — TryParsePcmWav over an in-memory mono 16-bit stream
 *   Parse/1MB   — same, 1 MiB payload
 *   Write/1MB   — WritePcmWavStream, 1 MiB payload
 *
 * Streams are prebuilt in memory so file IO does not pollute the measurement;
 * a sink xor keeps the parse/write calls observable.
 *}
{$I nextpas.core.settings.inc}{$Q-}{$R-}
uses
  nextpas.core.bench, nextpas.core.bench.intf,
  nextpas.core.time.base,
  nextpas.core.io,
  nextpas.core.fs,
  nextpas.core.audio.pcm_wav;

var
  GSmall: IStream;
  GLarge: IStream;
  GSink: UInt64;

function BuildWavStream(APayloadBytes: Integer): IStream;
var
  LSamples: array of SmallInt;
  LIdx: Integer;
begin
  SetLength(LSamples, APayloadBytes div SizeOf(SmallInt));
  for LIdx := 0 to Length(LSamples) - 1 do
    LSamples[LIdx] := SmallInt((LIdx * 37) and $FFFF);
  Result := BytesStream(APayloadBytes + 44);
  WritePcmWavStream(Result, 44100, 1, LSamples);
  Result.Position := 0;
end;

procedure BenchParse64K(const ACtx: IBenchContext);
var
  LData: TPcmWavData;
begin
  GSmall.Position := 0;
  if TryParsePcmWav(GSmall, LData) then
    GSink := GSink xor UInt64(Length(LData.Bytes));
end;

procedure BenchParse1M(const ACtx: IBenchContext);
var
  LData: TPcmWavData;
begin
  GLarge.Position := 0;
  if TryParsePcmWav(GLarge, LData) then
    GSink := GSink xor UInt64(Length(LData.Bytes));
end;

procedure BenchWrite1M(const ACtx: IBenchContext);
var
  LSamples: array of SmallInt;
begin
  SetLength(LSamples, (1024 * 1024) div SizeOf(SmallInt));
  WritePcmWavStream(GLarge, 44100, 1, LSamples);
  GSink := GSink xor UInt64(Length(LSamples));
end;

var
  LResults: IBenchResults;
begin
  GSmall := BuildWavStream(64 * 1024);
  GLarge := BuildWavStream(1024 * 1024);
  GSink := 0;
  LResults := TBenchSuite.Create('pcm_wav')
    .SetQuiet(True)
    .SetMinDuration(TDuration.FromMilliseconds(50))
    .SetMinSamples(5)
    .Add('Parse/64KB', @BenchParse64K)
    .Add('Parse/1MB', @BenchParse1M)
    .Add('Write/1MB', @BenchWrite1M)
    .Run;
  WriteLn(LResults.PrintToConsole);
  ForceDirectories('build');
  LResults.SaveToJSON('build/bench-pcm-wav.json');
end.
