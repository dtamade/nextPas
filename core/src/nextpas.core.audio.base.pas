unit nextpas.core.audio.base;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base;

const
  MinAudioSampleRate = 8000;
  MaxAudioSampleRate = 192000;
  MaxAudioChannels = 8;

  { WAVEFORMATEXTENSIBLE speaker bits (subset). }
  AudioMaskFrontLeft = UInt32($1);
  AudioMaskFrontRight = UInt32($2);
  AudioMaskFrontCenter = UInt32($4);
  AudioMaskLowFrequency = UInt32($8);
  AudioMaskBackLeft = UInt32($10);
  AudioMaskBackRight = UInt32($20);
  AudioMaskFrontLeftOfCenter = UInt32($40);
  AudioMaskFrontRightOfCenter = UInt32($80);
  AudioMaskBackCenter = UInt32($100);
  AudioMaskSideLeft = UInt32($200);
  AudioMaskSideRight = UInt32($400);

type
  { sfS24 = 3 字节紧排小端（packed 3-byte LE），无填充容器；
    BlockAlign 因此恒等于 Channels * BytesPerSample }
  TAudioSampleFormat = (sfU8, sfS16, sfS24, sfS32, sfF32);

  { 便捷提示值；真值源是 ChannelMask（位含义与 WAVEFORMATEXTENSIBLE
    dwChannelMask 一致：bit0=FL, bit1=FR, bit2=FC, bit3=LFE, bit4=BL ...）}
  TAudioChannelLayout = (clMono, clStereo, clQuad, clSurround51, clSurround71);

  TAudioFormat = record
    SampleRate: Integer;                    // [8000..192000]
    Channels: Integer;                      // [1..8]
    SampleFormat: TAudioSampleFormat;
    ChannelMask: UInt32;                    // 声道位置掩码，编解码往返的真值源
    ChannelLayout: TAudioChannelLayout;     // 由 Mask 推导的便捷提示
    function BlockAlign: Integer; inline;   // Channels * BytesPerSample
    function BytesPerSample: Integer; inline;
    function ByteRate: Int64; inline;       // SampleRate * BlockAlign（Int64 防溢出）
    function FramesForMs(AMs: Integer): Integer; inline;
    function IsValid: Boolean;
    function Equals(const AOther: TAudioFormat): Boolean; inline;
  end;

  TAudioBuffer = record                     // 值语义；Data 为交织 PCM
    Format: TAudioFormat;
    FrameCount: Integer;                    // 帧数（每帧 = Channels 个样本）
    Data: TBytes;                           // Length = FrameCount * BlockAlign
    function IsEmpty: Boolean; inline;
    function SampleCount: Integer; inline;
  end;

  { 采样精确时钟：采样面唯一时间表达 }
  TAudioClock = record
    Frame: UInt64;
    SampleRate: Integer;                    // 与 TAudioFormat.SampleRate 同型
    function ToDurationNs: Int64; inline;   // 仅调度面使用
  end;

  TAudioTagPair = record                    // 命名类型：FPC objfpc 无匿名 record
    Key: string;
    Value: string;
  end;

  TAudioTags = record                       // ID3v2/VorbisComment/RIFF INFO 归一结果
    Title: string;
    Artist: string;
    Album: string;
    Date: string;
    TrackNo: Integer;
    Extra: array of TAudioTagPair;          // 未映射键保留（含 bext 等 chunk 透传）
  end;

  TAudioDeviceInfo = record
    ID: string;                             // provider 内稳定标识
    Name: string;                           // 人类可读
    IsDefault: Boolean;
    MaxChannels: Integer;
    DefaultFormat: TAudioFormat;
  end;

  { 设备生命周期事件分类（经 MPSC 上报） }
  TDeviceEventKind = (
    devStarted,        // Start 完成
    devStopped,        // Stop 完成
    devUnderrun,       // 连续欠载越限（计数器同时递增）
    devDeviceError,    // 后端报错，流不可继续
    devDeviceLost      // 设备消失（v1 仅上报，不做自动迁移）
  );

  TAudioProbeResult = (
    prUnknown,
    prWav,
    prAiff,
    prFlac,
    prMp3,
    prOggVorbis,
    prOggOpus
  );

function AudioChannelMaskForLayout(ALayout: TAudioChannelLayout): UInt32; inline;
function AudioChannelLayoutForMask(AMask: UInt32; AChannels: Integer): TAudioChannelLayout; inline;
function AudioBytesPerSample(AFormat: TAudioSampleFormat): Integer; inline;
function AudioFormatCreate(ASampleRate, AChannels: Integer;
  ASampleFormat: TAudioSampleFormat): TAudioFormat; inline;

{ ---- Realtime helpers (zero-alloc, lock-free, no IO) ---- }
// 单一真值：供 wav/aiff/timeline/bus/graph/playlist/game/sequencer 复用
function AudioFillMemoryRealtime(const ASrc: TAudioBuffer; var APos: Integer;
  var ABuffer: TAudioBuffer; AFrames: Integer): Integer; inline;
function AudioSilentFill(var ABuffer: TAudioBuffer; const AFormat: TAudioFormat;
  AFrames: Integer): Integer; inline;

implementation

{$PUSH}
{$WARNINGS OFF}
{$HINTS OFF}

function AudioBytesPerSample(AFormat: TAudioSampleFormat): Integer;
begin
  case AFormat of
    sfU8: Result := 1;
    sfS16: Result := 2;
    sfS24: Result := 3;
    sfS32: Result := 4;
    sfF32: Result := 4;
  else
    Result := 0;
  end;
end;

function AudioChannelMaskForLayout(ALayout: TAudioChannelLayout): UInt32;
begin
  case ALayout of
    clMono: Result := AudioMaskFrontCenter; // 0x4
    clStereo: Result := AudioMaskFrontLeft or AudioMaskFrontRight; // 0x3
    clQuad: Result := AudioMaskFrontLeft or AudioMaskFrontRight or
      AudioMaskBackLeft or AudioMaskBackRight; // 0x33
    clSurround51: Result := AudioMaskFrontLeft or AudioMaskFrontRight or
      AudioMaskFrontCenter or AudioMaskLowFrequency or
      AudioMaskBackLeft or AudioMaskBackRight; // 0x3F
    clSurround71: Result := AudioMaskFrontLeft or AudioMaskFrontRight or
      AudioMaskFrontCenter or AudioMaskLowFrequency or
      AudioMaskBackLeft or AudioMaskBackRight or
      AudioMaskSideLeft or AudioMaskSideRight; // 0x63F
  else
    Result := 0;
  end;
end;

function AudioChannelLayoutForMask(AMask: UInt32; AChannels: Integer): TAudioChannelLayout;
begin
  { Exact match first. }
  if AMask = AudioChannelMaskForLayout(clMono) then Exit(clMono);
  if AMask = AudioChannelMaskForLayout(clStereo) then Exit(clStereo);
  if AMask = AudioChannelMaskForLayout(clQuad) then Exit(clQuad);
  if AMask = AudioChannelMaskForLayout(clSurround51) then Exit(clSurround51);
  if AMask = AudioChannelMaskForLayout(clSurround71) then Exit(clSurround71);
  { Fallback: pick closest by channel count, keep mask as truth. }
  case AChannels of
    1: Result := clMono;
    2: Result := clStereo;
    3, 4: Result := clQuad;
    5, 6: Result := clSurround51;
    7, 8: Result := clSurround71;
  else
    Result := clStereo;
  end;
end;

function AudioFormatCreate(ASampleRate, AChannels: Integer;
  ASampleFormat: TAudioSampleFormat): TAudioFormat;
var
  LMask: UInt32;
  LLayout: TAudioChannelLayout;
begin
  if (ASampleRate < MinAudioSampleRate) or (ASampleRate > MaxAudioSampleRate) then
    raise EInvalidArgument.CreateFmt('AudioFormatCreate: SampleRate %d out of range [%d..%d]',
      [ASampleRate, MinAudioSampleRate, MaxAudioSampleRate]);
  if (AChannels < 1) or (AChannels > MaxAudioChannels) then
    raise EInvalidArgument.CreateFmt('AudioFormatCreate: Channels %d out of range [1..%d]',
      [AChannels, MaxAudioChannels]);
  if (Ord(ASampleFormat) < Ord(Low(TAudioSampleFormat))) or
     (Ord(ASampleFormat) > Ord(High(TAudioSampleFormat))) then
    raise EInvalidArgument.Create('AudioFormatCreate: invalid SampleFormat');

  case AChannels of
    1: LLayout := clMono;
    2: LLayout := clStereo;
    4: LLayout := clQuad;
    6: LLayout := clSurround51;
    8: LLayout := clSurround71;
  else
    { For 3,5,7 choose closest layout but keep channel count truth }
    if AChannels <= 2 then LLayout := clStereo
    else if AChannels <= 4 then LLayout := clQuad
    else if AChannels <= 6 then LLayout := clSurround51
    else LLayout := clSurround71;
  end;
  LMask := AudioChannelMaskForLayout(LLayout);
  { For non-standard channel counts (3,5,7) mask is still a hint;
    codec layer may override mask for extensible formats. }
  if AChannels = 3 then
    LMask := AudioMaskFrontLeft or AudioMaskFrontRight or AudioMaskFrontCenter
  else if AChannels = 5 then
    LMask := AudioMaskFrontLeft or AudioMaskFrontRight or AudioMaskFrontCenter or
      AudioMaskBackLeft or AudioMaskBackRight
  else if AChannels = 7 then
    LMask := AudioMaskFrontLeft or AudioMaskFrontRight or AudioMaskFrontCenter or
      AudioMaskLowFrequency or AudioMaskBackLeft or AudioMaskBackRight or
      AudioMaskSideLeft;

  Result.SampleRate := ASampleRate;
  Result.Channels := AChannels;
  Result.SampleFormat := ASampleFormat;
  Result.ChannelMask := LMask;
  Result.ChannelLayout := LLayout;
  { Normalize layout via mask for canonical cases }
  if (AChannels in [1, 2, 4, 6, 8]) then
    Result.ChannelLayout := AudioChannelLayoutForMask(Result.ChannelMask, Result.Channels);
end;

{ TAudioFormat }

function TAudioFormat.BytesPerSample: Integer;
begin
  Result := AudioBytesPerSample(SampleFormat);
end;

function TAudioFormat.BlockAlign: Integer;
begin
  Result := Channels * BytesPerSample;
end;

function TAudioFormat.ByteRate: Int64;
begin
  Result := Int64(SampleRate) * Int64(BlockAlign);
end;

function TAudioFormat.FramesForMs(AMs: Integer): Integer;
begin
  if AMs <= 0 then
    Exit(0);
  Result := Integer((Int64(SampleRate) * Int64(AMs)) div 1000);
end;

function TAudioFormat.IsValid: Boolean;
begin
  Result := False;
  if (SampleRate < MinAudioSampleRate) or (SampleRate > MaxAudioSampleRate) then Exit;
  if (Channels < 1) or (Channels > MaxAudioChannels) then Exit;
  if (Ord(SampleFormat) < Ord(Low(TAudioSampleFormat))) or
     (Ord(SampleFormat) > Ord(High(TAudioSampleFormat))) then Exit;
  if BytesPerSample <= 0 then Exit;
  if BlockAlign <= 0 then Exit;
  { ByteRate fits in Int64 always given bounds, but check overflow guard }
  if ByteRate <= 0 then Exit;
  Result := True;
end;

function TAudioFormat.Equals(const AOther: TAudioFormat): Boolean;
begin
  Result := (SampleRate = AOther.SampleRate) and
    (Channels = AOther.Channels) and
    (SampleFormat = AOther.SampleFormat) and
    (ChannelMask = AOther.ChannelMask) and
    (ChannelLayout = AOther.ChannelLayout);
end;

{ TAudioBuffer }

function TAudioBuffer.IsEmpty: Boolean;
begin
  Result := (FrameCount <= 0) or (Length(Data) = 0);
end;

function TAudioBuffer.SampleCount: Integer;
begin
  Result := FrameCount * Format.Channels;
end;

{ TAudioClock }

function TAudioClock.ToDurationNs: Int64;
begin
  if SampleRate <= 0 then
    Exit(0);
  Result := Int64((Frame * UInt64(1000000000)) div UInt64(SampleRate));
end;

function AudioFillMemoryRealtime(const ASrc: TAudioBuffer; var APos: Integer;
  var ABuffer: TAudioBuffer; AFrames: Integer): Integer;
var LAvail, LToCopy: Integer; LBytesNeeded, LBytesToCopy: Int64; LBlockAlign: Integer;
begin
  Result:=0; if AFrames<=0 then Exit(0);
  LBlockAlign:=ASrc.Format.BlockAlign; if LBlockAlign<=0 then Exit(0);
  LBytesNeeded:=Int64(AFrames)*Int64(LBlockAlign);
  if (LBytesNeeded>High(Integer)) or (Length(ABuffer.Data)<LBytesNeeded) then Exit(0);
  if (APos<0) or (APos>ASrc.FrameCount) then APos:=ASrc.FrameCount;
  LAvail:=ASrc.FrameCount-APos;
  if LAvail<=0 then begin FillChar(ABuffer.Data[0],Integer(LBytesNeeded),0); ABuffer.Format:=ASrc.Format; ABuffer.FrameCount:=AFrames; Exit(AFrames); end;
  LToCopy:=AFrames; if LToCopy>LAvail then LToCopy:=LAvail;
  LBytesToCopy:=Int64(LToCopy)*Int64(LBlockAlign);
  if LBytesToCopy>0 then Move(ASrc.Data[Int64(APos)*Int64(LBlockAlign)],ABuffer.Data[0],Integer(LBytesToCopy));
  if LToCopy<AFrames then FillChar(ABuffer.Data[Integer(LBytesToCopy)],Integer(LBytesNeeded-LBytesToCopy),0);
  ABuffer.Format:=ASrc.Format; ABuffer.FrameCount:=AFrames; APos:=APos+LToCopy; Result:=AFrames;
end;

function AudioSilentFill(var ABuffer: TAudioBuffer; const AFormat: TAudioFormat;
  AFrames: Integer): Integer;
var LBytes: Int64;
begin
  Result:=0; if AFrames<=0 then Exit(0); if not AFormat.IsValid then Exit(0);
  LBytes:=Int64(AFrames)*Int64(AFormat.BlockAlign);
  if (LBytes>High(Integer)) or (Length(ABuffer.Data)<LBytes) then Exit(0);
  FillChar(ABuffer.Data[0],Integer(LBytes),0); ABuffer.Format:=AFormat; ABuffer.FrameCount:=AFrames; Result:=AFrames;
end;

{$POP}

end.
