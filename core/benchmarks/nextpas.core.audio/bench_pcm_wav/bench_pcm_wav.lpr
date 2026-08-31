program bench_pcm_wav;
{**
 * Benchmarks for nextpas.core.audio — pcm_wav + Graph/Timeline/Device/Bank/Resource (10项).
 *
 *   Parse/64KB, Parse/1MB, Write/1MB — pcm_wav 容器
 *   Graph/1K, Graph/4K               — Graph 快照混音，零分配
 *   Timeline/1K, TimelineLoop/1K     — Timeline 排序混音，零分配
 *   Device.Drive/1K                  — Null Device Drive → FillRealtime
 *   Bank/1K                          — Bank FillRealtime (2 voices)，零分配
 *   Resource/TryGet                  — Resource TryGetBuffer (ready)，零分配
 *
 * Streams/Buffers 预建，sink xor 防优化消除。
 * Bank/Resource 与 Graph/Timeline 同 discipline：预建对象 + 缓冲复用，
 * FillRealtime/TryGetBuffer 热路径快照化 + EnsureScratch/锁内零分配，HEAPTRC稳态0 alloc。
 *}
{$I nextpas.core.settings.inc}{$Q-}{$R-}
uses
  cthreads,
  SysUtils,
  nextpas.core.bench, nextpas.core.bench.intf,
  nextpas.core.time.base,
  nextpas.core.io,
  nextpas.core.fs,
  nextpas.core.audio.base,
  nextpas.core.audio.intf,
  nextpas.core.audio.pcm_wav,
  nextpas.core.audio.graph.intf,
  nextpas.core.audio.graph,
  nextpas.core.audio.timeline.intf,
  nextpas.core.audio.timeline,
  nextpas.core.audio.device.intf,
  nextpas.core.audio.device.null,
  nextpas.core.audio.bank.intf,
  nextpas.core.audio.bank,
  nextpas.core.audio.resource.intf,
  nextpas.core.audio.resource;

type
  TBenchSrc = class(TInterfacedObject, IRealtimeAudioSource, IAudioSource)
  private
    FBuf: TAudioBuffer;
  public
    constructor Create(const ABuf: TAudioBuffer);
    function GetFormat: TAudioFormat;
    function Fill(var ABuffer: TAudioBuffer; AFrames: Integer): Integer;
    function FillRealtime(var ABuffer: TAudioBuffer; AFrames: Integer): Integer;
    function SeekTo(AFrame: UInt64): Boolean;
  end;

constructor TBenchSrc.Create(const ABuf: TAudioBuffer);
begin inherited Create; FBuf := ABuf; end;
function TBenchSrc.GetFormat: TAudioFormat; begin Result := FBuf.Format; end;
function TBenchSrc.Fill(var ABuffer: TAudioBuffer; AFrames: Integer): Integer; begin Result := FillRealtime(ABuffer, AFrames); end;
function TBenchSrc.SeekTo(AFrame: UInt64): Boolean; begin Result := True; end;
function TBenchSrc.FillRealtime(var ABuffer: TAudioBuffer; AFrames: Integer): Integer;
var N: Integer;
begin
  N := AFrames * FBuf.Format.BlockAlign;
  if Length(ABuffer.Data) < N then N := Length(ABuffer.Data);
  if N > Length(FBuf.Data) then N := Length(FBuf.Data);
  if N > 0 then Move(FBuf.Data[0], ABuffer.Data[0], N);
  if N < AFrames * FBuf.Format.BlockAlign then
    FillChar((PByte(@ABuffer.Data[0]) + N)^, AFrames * FBuf.Format.BlockAlign - N, 0);
  ABuffer.FrameCount := AFrames;
  ABuffer.Format := FBuf.Format;
  Result := AFrames;
end;

var
  GSmall: IStream;
  GLarge: IStream;
  GSink: UInt64;
  GGraph: IAudioGraph;
  GGraphBuf1K: TAudioBuffer;
  GGraphBuf4K: TAudioBuffer;
  GTimeline: IAudioTimeline;
  GTimelineLoop: IAudioTimeline;
  GTimelineBuf1K: TAudioBuffer;
  GDevice: IAudioDevice;
  GBank: IAudioBank;
  GBankBuf1K: TAudioBuffer;
  GResourceMgr: IAudioResourceManager;
  GResourceId: TAudioResourceId;
  GResourceTmpPath: string;

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

function MakeF32Buffer(AFrames, AChannels: Integer; AVal: Single): TAudioBuffer;
var P: PSingle; I: Integer;
begin
  Result.Format := AudioFormatCreate(48000, AChannels, sfF32);
  Result.FrameCount := AFrames;
  SetLength(Result.Data, AFrames * Result.Format.BlockAlign);
  P := PSingle(@Result.Data[0]);
  for I := 0 to AFrames * AChannels - 1 do P[I] := AVal;
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

procedure BenchGraph1K(const ACtx: IBenchContext);
begin
  GGraph.FillRealtime(GGraphBuf1K, 1024);
  GSink := GSink xor UInt64(GGraphBuf1K.Data[0]);
end;

procedure BenchGraph4K(const ACtx: IBenchContext);
begin
  GGraph.FillRealtime(GGraphBuf4K, 4096);
  GSink := GSink xor UInt64(GGraphBuf4K.Data[0]);
end;

procedure BenchTimeline1K(const ACtx: IBenchContext);
begin
  (GTimeline as IRealtimeAudioSource).FillRealtime(GTimelineBuf1K, 1024);
  GSink := GSink xor UInt64(GTimelineBuf1K.Data[0]);
end;

procedure BenchTimelineLoop1K(const ACtx: IBenchContext);
begin
  (GTimelineLoop as IRealtimeAudioSource).FillRealtime(GTimelineBuf1K, 1024);
  GSink := GSink xor UInt64(GTimelineBuf1K.Data[0]);
end;

procedure BenchDeviceDrive1K(const ACtx: IBenchContext);
begin
  GDevice.Drive(1024);
  GSink := GSink xor GDevice.GetPosition.Frame;
end;

procedure BenchBank1K(const ACtx: IBenchContext);
begin
  { Bank FillRealtime: two-phase snapshot + EnsureScratch 零分配，与 Graph/Timeline 同 discipline }
  GBank.FillRealtime(GBankBuf1K, 1024);
  GSink := GSink xor UInt64(GBankBuf1K.Data[0]);
end;

procedure BenchResourceTryGet(const ACtx: IBenchContext);
var
  LBuf: TAudioBuffer;
begin
  { Resource TryGetBuffer: 锁内零分配，refcounted share，与 Bank 同 discipline }
  if GResourceMgr.TryGetBuffer(GResourceId, LBuf) then
    GSink := GSink xor UInt64(Length(LBuf.Data))
  else
    GSink := GSink xor 1;
end;

var
  LResults: IBenchResults;
  LBufA, LBufB: TAudioBuffer;
  LProv: IAudioDeviceProvider;
  LTrk: TTimelineTrackId;
  LBankIdA, LBankIdB: TAudioBankId;
  LResSamples: array of SmallInt;
  LIdx, LWait: Integer;
begin
  GSmall := BuildWavStream(64 * 1024);
  GLarge := BuildWavStream(1024 * 1024);
  GSink := 0;
  // 预建 Graph：2 源 + 1 processor 空链，Format 48k/2ch/sfF32
  GGraph := CreateAudioGraph(AudioFormatCreate(48000, 2, sfF32));
  LBufA := MakeF32Buffer(2048, 2, 0.2);
  LBufB := MakeF32Buffer(2048, 2, -0.1);
  GGraph.AddSource(TBenchSrc.Create(LBufA) as IRealtimeAudioSource, 1.0);
  GGraph.AddSource(TBenchSrc.Create(LBufB) as IRealtimeAudioSource, 0.8);
  GGraphBuf1K.Format := AudioFormatCreate(48000, 2, sfF32);
  GGraphBuf1K.FrameCount := 1024;
  SetLength(GGraphBuf1K.Data, 1024 * GGraphBuf1K.Format.BlockAlign);
  GGraphBuf4K.Format := AudioFormatCreate(48000, 2, sfF32);
  GGraphBuf4K.FrameCount := 4096;
  SetLength(GGraphBuf4K.Data, 4096 * GGraphBuf4K.Format.BlockAlign);
  // 预建 Timeline：1 轨 2 clips，Loop=false / Loop=true 各一实例
  GTimeline := CreateAudioTimeline(AudioFormatCreate(48000, 2, sfF32));
  LTrk := GTimeline.AddTrack(1.0);
  GTimeline.AddClip(LTrk, LBufA, 0);
  GTimeline.AddClip(LTrk, LBufB, 512);
  GTimelineLoop := CreateAudioTimeline(AudioFormatCreate(48000, 2, sfF32));
  LTrk := GTimelineLoop.AddTrack(1.0);
  GTimelineLoop.AddClip(LTrk, LBufA, 0);
  GTimelineLoop.AddClip(LTrk, LBufB, 512);
  GTimelineLoop.Loop := True;
  GTimelineBuf1K.Format := AudioFormatCreate(48000, 2, sfF32);
  GTimelineBuf1K.FrameCount := 1024;
  SetLength(GTimelineBuf1K.Data, 1024 * GTimelineBuf1K.Format.BlockAlign);
  // 预建 Device：Null provider + Graph 源
  LProv := CreateNullAudioProvider;
  GDevice := LProv.CreateDefaultDevice(AudioFormatCreate(48000, 2, sfF32));
  GDevice.SetSource(GGraph as IRealtimeAudioSource);
  GDevice.Start;
  // 预建 Bank：2 entries + 2 voices，FillRealtime 零分配（two-phase snapshot + EnsureScratch）
  GBank := CreateAudioBank(AudioFormatCreate(48000, 2, sfF32));
  LBankIdA := GBank.Add('bank_a', LBufA);
  LBankIdB := GBank.Add('bank_b', LBufB);
  GBank.Play(LBankIdA, 1.0, 0, 1.0, False);
  GBank.Play(LBankIdB, 0.8, 0, 1.0, False);
  GBankBuf1K.Format := AudioFormatCreate(48000, 2, sfF32);
  GBankBuf1K.FrameCount := 1024;
  SetLength(GBankBuf1K.Data, 1024 * GBankBuf1K.Format.BlockAlign);
  // 预建 Resource：落盘 wav → AsyncLoad → 轮询至 ready，TryGetBuffer 热路径零分配（锁内零分配 ref 共享）
  GResourceMgr := CreateAudioResourceManager;
  GResourceTmpPath := 'build/bench-resource-tmp.wav';
  ForceDirectories('build');
  SetLength(LResSamples, 2048);
  for LIdx := 0 to High(LResSamples) do
    LResSamples[LIdx] := SmallInt((LIdx * 37) and $FFFF);
  // 写临时 wav 供 ResourceManager 预加载（单次 IO，非热路径）
  try
    WritePcmWav(GResourceTmpPath, 44100, 1, LResSamples);
  except
    // 降级：若写文件失败，仍以空路径占位，TryGet 将走 failed 分支（仍零分配）
    GResourceTmpPath := '';
  end;
  if GResourceTmpPath <> '' then
  begin
    GResourceId := GResourceMgr.AsyncLoad(GResourceTmpPath);
    LWait := 0;
    while (LWait < 200) and (GResourceMgr.GetState(GResourceId) = arsLoading) do
    begin
      Sleep(10);
      Inc(LWait);
    end;
    // 若仍 loading/failed，保留 Id 供 bench 测 miss 分支（同零分配）
  end
  else
  begin
    // 无文件场景：用空路径触发参数校验外的 miss 查询
    GResourceId := 0;
  end;
  LResults := TBenchSuite.Create('pcm_wav')
    .SetQuiet(True)
    .SetMinDuration(TDuration.FromMilliseconds(50))
    .SetMinSamples(5)
    .Add('Parse/64KB', @BenchParse64K)
    .Add('Parse/1MB', @BenchParse1M)
    .Add('Write/1MB', @BenchWrite1M)
    .Add('Graph/1K', @BenchGraph1K)
    .Add('Graph/4K', @BenchGraph4K)
    .Add('Timeline/1K', @BenchTimeline1K)
    .Add('TimelineLoop/1K', @BenchTimelineLoop1K)
    .Add('Device.Drive/1K', @BenchDeviceDrive1K)
    .Add('Bank/1K', @BenchBank1K)
    .Add('Resource/TryGet', @BenchResourceTryGet)
    .Run;
  WriteLn(LResults.PrintToConsole);
  ForceDirectories('build');
  LResults.SaveToJSON('build/bench-pcm-wav.json');
end.
