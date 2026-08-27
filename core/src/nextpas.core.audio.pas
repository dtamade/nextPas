unit nextpas.core.audio;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.audio.base,
  nextpas.core.audio.errors,
  nextpas.core.audio.intf,
  nextpas.core.audio.codec.intf,
  nextpas.core.audio.pcm,
  nextpas.core.io.intf,
  nextpas.core.audio.codec.wav;

type
  TAudioSampleFormat = nextpas.core.audio.base.TAudioSampleFormat;
  TAudioChannelLayout = nextpas.core.audio.base.TAudioChannelLayout;
  TAudioFormat = nextpas.core.audio.base.TAudioFormat;
  TAudioBuffer = nextpas.core.audio.base.TAudioBuffer;
  TAudioClock = nextpas.core.audio.base.TAudioClock;
  TAudioTagPair = nextpas.core.audio.base.TAudioTagPair;
  TAudioTags = nextpas.core.audio.base.TAudioTags;
  TAudioDeviceInfo = nextpas.core.audio.base.TAudioDeviceInfo;
  TDeviceEventKind = nextpas.core.audio.base.TDeviceEventKind;
  TAudioProbeResult = nextpas.core.audio.base.TAudioProbeResult;

  EAudioError = nextpas.core.audio.errors.EAudioError;
  EAudioDecodeError = nextpas.core.audio.errors.EAudioDecodeError;
  EAudioEncodeError = nextpas.core.audio.errors.EAudioEncodeError;
  EAudioDeviceError = nextpas.core.audio.errors.EAudioDeviceError;
  EAudioGraphError = nextpas.core.audio.errors.EAudioGraphError;
  EAudioTimelineError = nextpas.core.audio.errors.EAudioTimelineError;

  IAudioSource = nextpas.core.audio.intf.IAudioSource;
  IRealtimeAudioSource = nextpas.core.audio.intf.IRealtimeAudioSource;
  IAudioResampler = nextpas.core.audio.intf.IAudioResampler;
  IAudioConverter = nextpas.core.audio.intf.IAudioConverter;
  IAudioProcessor = nextpas.core.audio.intf.IAudioProcessor;

  IAudioDecoder = nextpas.core.audio.codec.intf.IAudioDecoder;
  IAudioEncoder = nextpas.core.audio.codec.intf.IAudioEncoder;
  TAudioEncodeOptions = nextpas.core.audio.codec.intf.TAudioEncodeOptions;

{ ---- base forwarding ---- }

function AudioFormatCreate(ASampleRate, AChannels: Integer;
  ASampleFormat: TAudioSampleFormat): TAudioFormat; inline;
function AudioBytesPerSample(AFormat: TAudioSampleFormat): Integer; inline;
function AudioChannelMaskForLayout(ALayout: TAudioChannelLayout): UInt32; inline;
function AudioChannelLayoutForMask(AMask: UInt32; AChannels: Integer): TAudioChannelLayout; inline;

{ ---- pcm forwarding ---- }

function PcmClampF32(AValue: Single): Single; inline;
function PcmU8ToF32(AValue: Byte): Single; inline;
function PcmF32ToU8(AValue: Single): Byte; inline;
function PcmS16ToF32(AValue: SmallInt): Single; inline;
function PcmF32ToS16(AValue: Single): SmallInt; inline;
function PcmS24ToF32(AValue: Integer): Single; inline;
function PcmF32ToS24(AValue: Single): Integer; inline;
function PcmS32ToF32(AValue: LongInt): Single; inline;
function PcmF32ToS32(AValue: Single): LongInt; inline;

{ ---- wav codec forwarding (decode-first 便利) ---- }

function WavProbe(const APrefix: TBytes): TAudioProbeResult; inline;
procedure AudioEncodeWav(const ABuffer: TAudioBuffer; const AFilePath: string); overload; inline;
procedure AudioEncodeWav(const ABuffer: TAudioBuffer; const ADest: IStream; const AOptions: TAudioEncodeOptions); overload; inline;
procedure AudioEncodeWav(const ABuffer: TAudioBuffer; const ADest: IStream); overload; inline;
function CreateWavDecoder: IAudioDecoder; inline;
function CreateWavEncoder: IAudioEncoder; inline;

{ ---- registry placeholders (零逻辑，占位；真实实现在 codec.registry) ---- }

procedure AudioRegisterDecoderPlaceholder; inline;
procedure AudioRegisterEncoderPlaceholder; inline;

implementation

function AudioFormatCreate(ASampleRate, AChannels: Integer;
  ASampleFormat: TAudioSampleFormat): TAudioFormat;
begin
  Result := nextpas.core.audio.base.AudioFormatCreate(ASampleRate, AChannels, ASampleFormat);
end;

function AudioBytesPerSample(AFormat: TAudioSampleFormat): Integer;
begin
  Result := nextpas.core.audio.base.AudioBytesPerSample(AFormat);
end;

function AudioChannelMaskForLayout(ALayout: TAudioChannelLayout): UInt32;
begin
  Result := nextpas.core.audio.base.AudioChannelMaskForLayout(ALayout);
end;

function AudioChannelLayoutForMask(AMask: UInt32; AChannels: Integer): TAudioChannelLayout;
begin
  Result := nextpas.core.audio.base.AudioChannelLayoutForMask(AMask, AChannels);
end;

function PcmClampF32(AValue: Single): Single;
begin
  Result := nextpas.core.audio.pcm.PcmClampF32(AValue);
end;

function PcmU8ToF32(AValue: Byte): Single;
begin
  Result := nextpas.core.audio.pcm.PcmU8ToF32(AValue);
end;

function PcmF32ToU8(AValue: Single): Byte;
begin
  Result := nextpas.core.audio.pcm.PcmF32ToU8(AValue);
end;

function PcmS16ToF32(AValue: SmallInt): Single;
begin
  Result := nextpas.core.audio.pcm.PcmS16ToF32(AValue);
end;

function PcmF32ToS16(AValue: Single): SmallInt;
begin
  Result := nextpas.core.audio.pcm.PcmF32ToS16(AValue);
end;

function PcmS24ToF32(AValue: Integer): Single;
begin
  Result := nextpas.core.audio.pcm.PcmS24ToF32(AValue);
end;

function PcmF32ToS24(AValue: Single): Integer;
begin
  Result := nextpas.core.audio.pcm.PcmF32ToS24(AValue);
end;

function PcmS32ToF32(AValue: LongInt): Single;
begin
  Result := nextpas.core.audio.pcm.PcmS32ToF32(AValue);
end;

function PcmF32ToS32(AValue: Single): LongInt;
begin
  Result := nextpas.core.audio.pcm.PcmF32ToS32(AValue);
end;

function WavProbe(const APrefix: TBytes): TAudioProbeResult;
begin
  Result := nextpas.core.audio.codec.wav.WavProbe(APrefix);
end;

procedure AudioEncodeWav(const ABuffer: TAudioBuffer; const AFilePath: string);
begin
  nextpas.core.audio.codec.wav.AudioEncodeWav(ABuffer, AFilePath);
end;

procedure AudioEncodeWav(const ABuffer: TAudioBuffer; const ADest: IStream; const AOptions: TAudioEncodeOptions);
begin
  nextpas.core.audio.codec.wav.AudioEncodeWav(ABuffer, ADest, AOptions);
end;

procedure AudioEncodeWav(const ABuffer: TAudioBuffer; const ADest: IStream);
begin
  nextpas.core.audio.codec.wav.AudioEncodeWav(ABuffer, ADest);
end;

function CreateWavDecoder: IAudioDecoder;
begin
  Result := nextpas.core.audio.codec.wav.CreateWavDecoder;
end;

function CreateWavEncoder: IAudioEncoder;
begin
  Result := nextpas.core.audio.codec.wav.CreateWavEncoder;
end;

procedure AudioRegisterDecoderPlaceholder;
begin
end;

procedure AudioRegisterEncoderPlaceholder;
begin
end;

end.
