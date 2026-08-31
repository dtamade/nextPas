program bench_pcm_wav;
{**
 * Benchmarks for nextpas.core.audio — Parse/Write and realtime Graph/Timeline/Device Drive.
 * S9 gate: ns/op + MB/s -O2, Graph/Timeline/Device Drive added.
 * Streams/buffers prebuilt; sink xor keeps calls observable.
 *}
{$I nextpas.core.settings.inc}{$Q-}{$R-}
uses
  nextpas.core.base,
  nextpas.core.bench, nextpas.core.bench.intf,
  nextpas.core.time.base,
  nextpas.core.io,
  nextpas.core.fs,
  nextpas.core.audio.base,
  nextpas.core.audio,
  nextpas.core.audio.timeline.intf,
  nextpas.core.audio.pcm_wav;

type
  TMemoryAudioSource = class(TInterfacedObject, IRealtimeAudioSource)
  private
    FFormat: TAudioFormat;
    FData: TBytes;
    FPos: Integer;
  public
    constructor Create(const AFormat: TAudioFormat; AFrames: Integer);
    function GetFormat: TAudioFormat;
    function Fill(var ABuffer: TAudioBuffer; AFrames: Integer): Integer;
    function SeekTo(AFrame: UInt64): Boolean;
    function FillRealtime(var ABuffer: TAudioBuffer; AFrames: Integer): Integer;
  end;

constructor TMemoryAudioSource.Create(const AFormat: TAudioFormat; AFrames: Integer);
var I: Integer; P: PSingle;
begin
  inherited Create;
  FFormat := AFormat;
  SetLength(FData, AFrames * AFormat.BlockAlign);
  P := PSingle(@FData[0]);
  for I := 0 to AFrames * AFormat.Channels - 1 do
    P[I] := Sin(I * 0.01);
  FPos := 0;
end;
function TMemoryAudioSource.GetFormat: TAudioFormat; begin Result := FFormat; end;
function TMemoryAudioSource.Fill(var ABuffer: TAudioBuffer; AFrames: Integer): Integer; begin Result := FillRealtime(ABuffer, AFrames); end;
function TMemoryAudioSource.SeekTo(AFrame: UInt64): Boolean; begin FPos := Integer(AFrame); Result := True; end;
function TMemoryAudioSource.FillRealtime(var ABuffer: TAudioBuffer; AFrames: Integer): Integer;
var N, Cpy: Integer;
begin
  N := Length(FData) div FFormat.BlockAlign - FPos;
  if N <= 0 then Exit(0);
  if AFrames < N then N := AFrames;
  Cpy := N * FFormat.BlockAlign;
  if Length(ABuffer.Data) >= Cpy then
    Move(FData[FPos * FFormat.BlockAlign], ABuffer.Data[0], Cpy);
  ABuffer.FrameCount := N;
  Inc(FPos, N);
  if FPos >= Length(FData) div FFormat.BlockAlign then FPos := 0;
  Result := N;
end;

var
  GSmall: IStream;
  GLarge: IStream;
  GSink: UInt64;
  GGraph1K: IAudioGraph;
  GGraph4K: IAudioGraph;
  GTimeline1K: IAudioTimeline;
  GTimelineLoop: IAudioTimeline;
  GDevice: IAudioDevice;
  GDevSource: IAudioGraph;
  GOut1K: TAudioBuffer;
  GOut4K: TAudioBuffer;
  GMemSrc1: TMemoryAudioSource;
  GMemSrc2: TMemoryAudioSource;

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

procedure InitRealtimeFixtures;
var
  Fmt: TAudioFormat;
  Src1: IRealtimeAudioSource;
  Clip: TAudioBuffer;
  I: Integer; P: PSingle;
  T1, T2: TTimelineTrackId;
begin
  Fmt := AudioFormatCreate(48000, 2, sfF32);
  // 1K/4K output buffers preallocated (zero alloc in FillRealtime steady state)
  GOut1K.Format := Fmt; GOut1K.FrameCount := 1024; SetLength(GOut1K.Data, 1024 * Fmt.BlockAlign);
  GOut4K.Format := Fmt; GOut4K.FrameCount := 4096; SetLength(GOut4K.Data, 4096 * Fmt.BlockAlign);
  // Graph fixtures: 2 sources each (interface refs keep alive)
  GMemSrc1 := TMemoryAudioSource.Create(Fmt, 48000);
  GMemSrc2 := TMemoryAudioSource.Create(Fmt, 48000);
  GGraph1K := CreateAudioGraph(Fmt);
  GGraph1K.AddSource(GMemSrc1 as IRealtimeAudioSource, 0.9);
  GGraph1K.AddSource(GMemSrc2 as IRealtimeAudioSource, 0.7);
  GGraph4K := CreateAudioGraph(Fmt);
  GGraph4K.AddSource(GMemSrc1 as IRealtimeAudioSource, 0.9);
  GGraph4K.AddSource(GMemSrc2 as IRealtimeAudioSource, 0.7);
  // Timeline fixtures
  GTimeline1K := CreateAudioTimeline(Fmt);
  T1 := GTimeline1K.AddTrack(1.0);
  // one clip 48000 frames sine
  Clip.Format := Fmt; Clip.FrameCount := 48000; SetLength(Clip.Data, 48000 * Fmt.BlockAlign);
  P := PSingle(@Clip.Data[0]);
  for I := 0 to 48000 * 2 - 1 do P[I] := Sin(I * 0.02) * 0.5;
  GTimeline1K.AddClip(T1, Clip, 0);
  GTimelineLoop := CreateAudioTimeline(Fmt);
  T2 := GTimelineLoop.AddTrack(1.0);
  GTimelineLoop.AddClip(T2, Clip, 0);
  GTimelineLoop.Loop := True;
  // Device: graph as source
  GDevSource := CreateAudioGraph(Fmt);
  Src1 := TMemoryAudioSource.Create(Fmt, 48000);
  GDevSource.AddSource(Src1, 1.0);
  GDevice := CreateNullAudioProvider.CreateDefaultDevice(Fmt);
  GDevice.SetSource(GDevSource);
  GDevice.Start;
end;

procedure BenchParse64K(const ACtx: IBenchContext);
var LData: TPcmWavData;
begin
  GSmall.Position := 0;
  if TryParsePcmWav(GSmall, LData) then
    GSink := GSink xor UInt64(Length(LData.Bytes));
end;

procedure BenchParse1M(const ACtx: IBenchContext);
var LData: TPcmWavData;
begin
  GLarge.Position := 0;
  if TryParsePcmWav(GLarge, LData) then
    GSink := GSink xor UInt64(Length(LData.Bytes));
end;

procedure BenchWrite1M(const ACtx: IBenchContext);
var LSamples: array of SmallInt;
begin
  SetLength(LSamples, (1024 * 1024) div SizeOf(SmallInt));
  WritePcmWavStream(GLarge, 44100, 1, LSamples);
  GSink := GSink xor UInt64(Length(LSamples));
end;

procedure BenchGraph1K(const ACtx: IBenchContext);
begin
  GGraph1K.FillRealtime(GOut1K, 1024);
  GSink := GSink xor UInt64(GOut1K.Data[0]);
end;

procedure BenchGraph4K(const ACtx: IBenchContext);
begin
  GGraph4K.FillRealtime(GOut4K, 4096);
  GSink := GSink xor UInt64(GOut4K.Data[0]);
end;

procedure BenchTimeline1K(const ACtx: IBenchContext);
begin
  GTimeline1K.FillRealtime(GOut1K, 1024);
  GSink := GSink xor UInt64(GOut1K.Data[0]);
end;

procedure BenchTimelineLoop1K(const ACtx: IBenchContext);
begin
  GTimelineLoop.FillRealtime(GOut1K, 1024);
  GSink := GSink xor UInt64(GOut1K.Data[0]);
end;

procedure BenchDeviceDrive1K(const ACtx: IBenchContext);
begin
  GDevice.Drive(1024);
  GSink := GSink xor GDevice.GetPosition.Frame;
end;

var
  LResults: IBenchResults;
begin
  GSmall := BuildWavStream(64 * 1024);
  GLarge := BuildWavStream(1024 * 1024);
  GSink := 0;
  InitRealtimeFixtures;
  LResults := TBenchSuite.Create('pcm_wav')
    .SetQuiet(True)
    .SetMinDuration(TDuration.FromMilliseconds(80))
    .SetMinSamples(5)
    .Add('Parse/64KB', @BenchParse64K)
    .Add('Parse/1MB', @BenchParse1M)
    .Add('Write/1MB', @BenchWrite1M)
    .Add('Graph/1K', @BenchGraph1K)
    .Add('Graph/4K', @BenchGraph4K)
    .Add('Timeline/1K', @BenchTimeline1K)
    .Add('TimelineLoop/1K', @BenchTimelineLoop1K)
    .Add('Device.Drive/1K', @BenchDeviceDrive1K)
    .Run;
  WriteLn(LResults.PrintToConsole);
  ForceDirectories('build');
  LResults.SaveToJSON('build/bench-pcm-wav.json');
end.
