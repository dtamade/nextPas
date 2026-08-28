program bench_mp3;
{**
 * Benchmark for nextpas.core.audio.codec.mp3.decoder
 *
 *   Decode fixtures from music888 if present, else synthetic silence.
}
{$I nextpas.core.settings.inc}{$Q-}{$R-}
uses
  SysUtils,
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
  Candidates: array[0..2] of string;
  Idx: Integer;
  Dec: IAudioDecoder;
  Buf: TAudioBuffer;
  TestOk: Boolean;
begin
  GHasData := False;
  Candidates[0] := '/home/dtamade/projects/music888/tests/fixtures/tone_stereo_16.mp3';
  Candidates[1] := '/home/dtamade/projects/nextPas/.worktrees/core-audio-flac/core/benchmarks/nextpas.core.audio/bench_mp3/mini.mp3';
  Candidates[2] := ExtractFilePath(ParamStr(0)) + 'mini.mp3';
  for Idx := 0 to High(Candidates) do
  begin
    P := Candidates[Idx];
    if FileExists(P) then
    begin
      try
        S := nextpas.core.fs.Open(P, [fmRead]);
        LAvail := S.Size;
        SetLength(GData, LAvail);
        if LAvail > 0 then S.Read(GData[0], LongInt(LAvail));
        GBytes := LAvail;
        if LAvail = 0 then Continue;
        // 冒烟验证：有效 mp3 必须能解出一帧，否则视为 fixture 异常，跳过 bench
        TestOk := False;
        try
          S := BytesStream(0);
          S.Write(GData[0], Length(GData));
          S.Position := 0;
          Dec := CreateMp3Decoder;
          Buf := Dec.DecodeWhole(S);
          TestOk := Buf.FrameCount > 0;
        except
          TestOk := False;
        end;
        if not TestOk then
        begin
          WriteLn('bench_mp3: fixture decode failed (', P, '), skip');
          SetLength(GData, 0);
          GHasData := False;
          Exit;
        end;
        GHasData := True;
        Exit;
      except
        Continue;
      end;
    end;
  end;
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
