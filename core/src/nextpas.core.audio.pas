unit nextpas.core.audio;

{$I nextpas.core.settings.inc}

{ Root facade God Facade 注记：聚合 ~26 core units (base/errors/intf/codec/resample/mix/dsp/device/graph/sfx/timeline)
  候选拆分路径：codec → L2 codec, dsp/mix/resample → L2 dsp, device/graph/player/timeline/sfx → L2 pipeline
  52 扩展候选已在 CONTRACT 标注 (check_source_contract.sh 78 files: core 26 + extension 52)，待抽独立 L2 模块
  当前保持单门面以兼容；bytes.ops 单源收敛，hygiene 无野指针；不新增 GUID/ffi，守单源 }

interface

uses
  nextpas.core.base,
  nextpas.core.audio.base,
  nextpas.core.audio.errors,
  nextpas.core.audio.intf,
  nextpas.core.audio.codec.intf,
  nextpas.core.audio.pcm,
  nextpas.core.io.intf,
  nextpas.core.audio.codec.wav,
  nextpas.core.audio.codec.aiff,
  nextpas.core.audio.codec.meta,
  nextpas.core.audio.codec.registry,
  nextpas.core.audio.resample,
  nextpas.core.audio.resample.sinc,
  nextpas.core.audio.mix,
  nextpas.core.audio.dsp.filters,
  nextpas.core.audio.dsp.dynamics,
  nextpas.core.audio.dsp.fft,
  nextpas.core.audio.device.intf,
  nextpas.core.audio.device.null,
  nextpas.core.audio.timeline.intf,
  nextpas.core.audio.sfx.intf,
  nextpas.core.audio.graph.intf,
  nextpas.core.audio.timeline,
  nextpas.core.audio.sfx,
  nextpas.core.audio.game,
  nextpas.core.audio.graph,
  nextpas.core.audio.player,
  nextpas.core.audio.bank.intf,
  nextpas.core.audio.bank.impl,
  nextpas.core.audio.resource.intf,
  nextpas.core.audio.resource.impl,
  nextpas.core.audio.event.intf,
  nextpas.core.audio.event.impl,
  nextpas.core.audio.playlist.intf,
  nextpas.core.audio.playlist.impl,
  nextpas.core.audio.spatial.intf,
  nextpas.core.audio.spatial.impl,
  nextpas.core.audio.bus.intf,
  nextpas.core.audio.bus.impl,
  nextpas.core.audio.studio.intf,
  nextpas.core.audio.studio.project,
  nextpas.core.audio.studio.sequencer,
  nextpas.core.audio.studio.automation,
  nextpas.core.audio.simd;

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
  TDecoderFactory = nextpas.core.audio.codec.registry.TDecoderFactory;

  TResampleQuality = nextpas.core.audio.resample.sinc.TResampleQuality;
  TBiquadType = nextpas.core.audio.dsp.filters.TBiquadType;
  TBiquad = nextpas.core.audio.dsp.filters.TBiquad;
  TCompressor = nextpas.core.audio.dsp.dynamics.TCompressor;
  TSingleArray = nextpas.core.audio.dsp.fft.TSingleArray;
  TAudioPanGains = nextpas.core.audio.mix.TAudioPanGains;

  TDeviceState = nextpas.core.audio.device.intf.TDeviceState;
  TDeviceEvent = nextpas.core.audio.device.intf.TDeviceEvent;
  TAudioDeviceInfoArray = nextpas.core.audio.device.intf.TAudioDeviceInfoArray;
  IAudioDevice = nextpas.core.audio.device.intf.IAudioDevice;
  IAudioDeviceProvider = nextpas.core.audio.device.intf.IAudioDeviceProvider;

  TSfxId = nextpas.core.audio.sfx.intf.TSfxId;
  TVoiceId = nextpas.core.audio.sfx.intf.TVoiceId;
  TSfxPlayParams = nextpas.core.audio.sfx.intf.TSfxPlayParams;
  ISfxAudio = nextpas.core.audio.sfx.intf.ISfxAudio;
  TGameSfxId = TSfxId deprecated 'use TSfxId';
  TGameVoiceId = TVoiceId deprecated 'use TVoiceId';
  TGamePlayParams = TSfxPlayParams deprecated 'use TSfxPlayParams';
  IAudioTimeline = nextpas.core.audio.timeline.intf.IAudioTimeline;
  IGameAudio = ISfxAudio deprecated 'use ISfxAudio';
  TGraphState = nextpas.core.audio.graph.intf.TGraphState;
  IAudioGraph = nextpas.core.audio.graph.intf.IAudioGraph;
  IAudioPlayer = nextpas.core.audio.graph.intf.IAudioPlayer;

{ ---- base forwarding ---- }

function AudioFormatCreate(ASampleRate, AChannels: Integer;
  ASampleFormat: TAudioSampleFormat): TAudioFormat; inline;
function AudioBytesPerSample(AFormat: TAudioSampleFormat): Integer; inline;
function AudioChannelMaskForLayout(ALayout: TAudioChannelLayout): UInt32; inline;
function AudioChannelLayoutForMask(AMask: UInt32; AChannels: Integer): TAudioChannelLayout; inline;
function AudioBufferCreateSilence(const AFormat: TAudioFormat; AFrames: Integer): TAudioBuffer; inline;
function AudioBufferClone(const ABuffer: TAudioBuffer): TAudioBuffer; inline;
function AudioBytesForFrames(const AFormat: TAudioFormat; AFrames: Integer): Int64; inline;
function AudioSilentFill(var ABuffer: TAudioBuffer; const AFormat: TAudioFormat; AFrames: Integer): Integer; inline;

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

function AiffProbe(const APrefix: TBytes): TAudioProbeResult; inline;
function CreateAiffDecoder: IAudioDecoder; inline;

function TryParseID3v2(const APrefix: TBytes; out ATags: TAudioTags; out ASkipped: Integer): Boolean; inline;
function TryParseVorbisComment(const AData: TBytes; out ATags: TAudioTags): Boolean; inline;
function TryParseRiffInfo(const AStream: IStream; ALimit: Int64; out ATags: TAudioTags): Boolean; inline;
function MergeTags(const APrimary, AFallback: TAudioTags): TAudioTags; inline;

function AudioDetectProbe(const APrefix: TBytes): TAudioProbeResult; inline;
function AudioDetectProbeFromStream(const AStream: IStream): TAudioProbeResult; inline;
procedure AudioRegisterDecoder(AFactory: TDecoderFactory); inline;
function TryDecodeWhole(ADecoder: IAudioDecoder; const AStream: IStream; out ABuffer: TAudioBuffer): Boolean; inline;
function TryDecodeWholeFile(const APath: string; out ABuffer: TAudioBuffer; out ATags: TAudioTags): Boolean; inline;
function AudioOpenFileStreaming(const APath: string): IAudioSource; inline;

{ ---- resample/mix/dsp forwarding ---- }

function AudioResampleLinear(const AInput: TAudioBuffer; ANewRate: Integer): TAudioBuffer; inline;
function CreateLinearResampler: IAudioResampler; inline;
function CreateSincResampler(AQuality: TResampleQuality = rsGood): IAudioResampler; inline;

procedure MixInto(var ADst: TAudioBuffer; const ASrc: TAudioBuffer; AGain: Single; AOffset: Integer); inline;
procedure ApplyGain(var ABuf: TAudioBuffer; AGain: Single); inline;
procedure ApplyGainRamp(var ABuf: TAudioBuffer; AStartGain, AEndGain: Single); inline;
function NormalizePeak(var ABuf: TAudioBuffer; ATarget: Single): Single; inline;
function NormalizeRMS(var ABuf: TAudioBuffer; ATarget: Single): Single; inline;
function PanLawGains(APan: Single): TAudioPanGains; inline; overload;
function PanLawGains(APan: Single; ALawDB: Single): TAudioPanGains; inline; overload; deprecated 'PanLaw fixed to -3dB equal-power; prefer single-arg overload';
function PanLawGains0dB(APan: Single): TAudioPanGains; inline;

function WindowHann(N, I: Integer): Single; inline;
procedure FFT(var ARe, AIm: array of Single); inline;
procedure IFFT(var ARe, AIm: array of Single); inline;
function IsPowerOfTwo(N: Integer): Boolean; inline;

function CreateNullAudioProvider: IAudioDeviceProvider; inline;
function CreateAudioGraph(const AFormat: TAudioFormat): IAudioGraph; inline;
function CreateAudioPlayer(const ADevice: IAudioDevice; const AGraph: IAudioGraph): IAudioPlayer; inline;
function CreateAudioPlayerForFormat(const AProvider: IAudioDeviceProvider; const AFormat: TAudioFormat): IAudioPlayer; inline;
function CreateSfxAudio(const ADevice: IAudioDevice; const AGraph: IAudioGraph; AMaxVoices: Integer = 32): ISfxAudio; inline;
function CreateSfxAudioForFormat(const AProvider: IAudioDeviceProvider; const AFormat: TAudioFormat; AMaxVoices: Integer = 32): ISfxAudio; inline;
function CreateGameAudio(const ADevice: IAudioDevice; const AGraph: IAudioGraph; AMaxVoices: Integer = 32): IGameAudio; inline; deprecated 'use CreateSfxAudio';
function CreateGameAudioForFormat(const AProvider: IAudioDeviceProvider; const AFormat: TAudioFormat; AMaxVoices: Integer = 32): IGameAudio; inline; deprecated 'use CreateSfxAudioForFormat';
function CreateAudioTimeline(const AFormat: TAudioFormat): IAudioTimeline; inline;

// ---- extension re-exports (52 ext, thin inline forwarding; spatial/bus keep via their own facades) ----
type
  IAudioBank = nextpas.core.audio.bank.intf.IAudioBank;
  IAudioResourceManager = nextpas.core.audio.resource.intf.IAudioResourceManager;
  TAudioResourceState = nextpas.core.audio.resource.intf.TAudioResourceState;
  IAudioEventSystem = nextpas.core.audio.event.intf.IAudioEventSystem;
  IAudioPlaylist = nextpas.core.audio.playlist.intf.IAudioPlaylist;

function CreateAudioBank(const AFormat: TAudioFormat): IAudioBank; inline;
function CreateAudioResourceManager: IAudioResourceManager; inline;
function CreateAudioEventSystem(const AFormat: TAudioFormat; AMaxVoices: Integer = 32): IAudioEventSystem; inline;
function CreateAudioPlaylist(const AFormat: TAudioFormat): IAudioPlaylist; inline;

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

function AiffProbe(const APrefix: TBytes): TAudioProbeResult;
begin
  Result := nextpas.core.audio.codec.aiff.AiffProbe(APrefix);
end;

function CreateAiffDecoder: IAudioDecoder;
begin
  Result := nextpas.core.audio.codec.aiff.CreateAiffDecoder;
end;

function TryParseID3v2(const APrefix: TBytes; out ATags: TAudioTags; out ASkipped: Integer): Boolean;
begin
  Result := nextpas.core.audio.codec.meta.TryParseID3v2(APrefix, ATags, ASkipped);
end;

function TryParseVorbisComment(const AData: TBytes; out ATags: TAudioTags): Boolean;
begin
  Result := nextpas.core.audio.codec.meta.TryParseVorbisComment(AData, ATags);
end;

function TryParseRiffInfo(const AStream: IStream; ALimit: Int64; out ATags: TAudioTags): Boolean;
begin
  Result := nextpas.core.audio.codec.meta.TryParseRiffInfo(AStream, ALimit, ATags);
end;

function MergeTags(const APrimary, AFallback: TAudioTags): TAudioTags;
begin
  Result := nextpas.core.audio.codec.meta.MergeTags(APrimary, AFallback);
end;

function AudioDetectProbe(const APrefix: TBytes): TAudioProbeResult;
begin
  Result := nextpas.core.audio.codec.registry.AudioDetectProbe(APrefix);
end;

function AudioDetectProbeFromStream(const AStream: IStream): TAudioProbeResult;
begin
  Result := nextpas.core.audio.codec.registry.AudioDetectProbeFromStream(AStream);
end;

procedure AudioRegisterDecoder(AFactory: TDecoderFactory);
begin
  nextpas.core.audio.codec.registry.AudioRegisterDecoder(AFactory);
end;

function TryDecodeWhole(ADecoder: IAudioDecoder; const AStream: IStream; out ABuffer: TAudioBuffer): Boolean;
begin
  Result := nextpas.core.audio.codec.registry.TryDecodeWhole(ADecoder, AStream, ABuffer);
end;

function TryDecodeWholeFile(const APath: string; out ABuffer: TAudioBuffer; out ATags: TAudioTags): Boolean;
begin
  Result := nextpas.core.audio.codec.registry.TryDecodeWholeFile(APath, ABuffer, ATags);
end;

function AudioOpenFileStreaming(const APath: string): IAudioSource;
begin
  Result := nextpas.core.audio.codec.registry.AudioOpenFileStreaming(APath);
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

function AudioResampleLinear(const AInput: TAudioBuffer; ANewRate: Integer): TAudioBuffer;
begin Result := nextpas.core.audio.resample.AudioResampleLinear(AInput, ANewRate); end;

function CreateLinearResampler: IAudioResampler;
begin Result := nextpas.core.audio.resample.CreateLinearResampler; end;

function CreateSincResampler(AQuality: TResampleQuality): IAudioResampler;
begin Result := nextpas.core.audio.resample.sinc.CreateSincResampler(AQuality); end;

procedure MixInto(var ADst: TAudioBuffer; const ASrc: TAudioBuffer; AGain: Single; AOffset: Integer);
begin nextpas.core.audio.mix.MixInto(ADst, ASrc, AGain, AOffset); end;

procedure ApplyGain(var ABuf: TAudioBuffer; AGain: Single);
begin nextpas.core.audio.mix.ApplyGain(ABuf, AGain); end;

procedure ApplyGainRamp(var ABuf: TAudioBuffer; AStartGain, AEndGain: Single);
begin nextpas.core.audio.mix.ApplyGainRamp(ABuf, AStartGain, AEndGain); end;

function NormalizePeak(var ABuf: TAudioBuffer; ATarget: Single): Single;
begin Result := nextpas.core.audio.mix.NormalizePeak(ABuf, ATarget); end;

function NormalizeRMS(var ABuf: TAudioBuffer; ATarget: Single): Single;
begin Result := nextpas.core.audio.mix.NormalizeRMS(ABuf, ATarget); end;

function PanLawGains(APan: Single): TAudioPanGains;
begin Result := nextpas.core.audio.mix.PanLawGains(APan); end;

function PanLawGains(APan: Single; ALawDB: Single): TAudioPanGains;
begin Result := nextpas.core.audio.mix.PanLawGains(APan, ALawDB); end;

function PanLawGains0dB(APan: Single): TAudioPanGains;
begin Result := nextpas.core.audio.mix.PanLawGains0dB(APan); end;

function WindowHann(N, I: Integer): Single;
begin Result := nextpas.core.audio.dsp.fft.WindowHann(N, I); end;

procedure FFT(var ARe, AIm: array of Single);
begin nextpas.core.audio.dsp.fft.FFT(ARe, AIm); end;

procedure IFFT(var ARe, AIm: array of Single);
begin nextpas.core.audio.dsp.fft.IFFT(ARe, AIm); end;

function IsPowerOfTwo(N: Integer): Boolean;
begin Result := nextpas.core.audio.dsp.fft.IsPowerOfTwo(N); end;

function CreateNullAudioProvider: IAudioDeviceProvider;
begin Result := nextpas.core.audio.device.null.CreateNullAudioProvider; end;

function CreateAudioGraph(const AFormat: TAudioFormat): IAudioGraph;
begin Result := nextpas.core.audio.graph.CreateAudioGraph(AFormat); end;

function CreateAudioPlayer(const ADevice: IAudioDevice; const AGraph: IAudioGraph): IAudioPlayer;
begin Result := nextpas.core.audio.player.CreateAudioPlayer(ADevice, AGraph); end;

function CreateAudioPlayerForFormat(const AProvider: IAudioDeviceProvider; const AFormat: TAudioFormat): IAudioPlayer;
begin Result := nextpas.core.audio.player.CreateAudioPlayerForFormat(AProvider, AFormat); end;

function CreateSfxAudio(const ADevice: IAudioDevice; const AGraph: IAudioGraph; AMaxVoices: Integer): ISfxAudio;
begin Result := nextpas.core.audio.sfx.CreateSfxAudio(ADevice, AGraph, AMaxVoices); end;

function CreateSfxAudioForFormat(const AProvider: IAudioDeviceProvider; const AFormat: TAudioFormat; AMaxVoices: Integer): ISfxAudio;
begin Result := nextpas.core.audio.sfx.CreateSfxAudioForFormat(AProvider, AFormat, AMaxVoices); end;

function CreateGameAudio(const ADevice: IAudioDevice; const AGraph: IAudioGraph; AMaxVoices: Integer): IGameAudio;
begin Result := CreateSfxAudio(ADevice, AGraph, AMaxVoices); end;

function CreateGameAudioForFormat(const AProvider: IAudioDeviceProvider; const AFormat: TAudioFormat; AMaxVoices: Integer): IGameAudio;
begin Result := CreateSfxAudioForFormat(AProvider, AFormat, AMaxVoices); end;

function CreateAudioTimeline(const AFormat: TAudioFormat): IAudioTimeline;
begin Result := nextpas.core.audio.timeline.CreateAudioTimeline(AFormat); end;

function AudioBufferCreateSilence(const AFormat: TAudioFormat; AFrames: Integer): TAudioBuffer;
begin Result := nextpas.core.audio.base.AudioBufferCreateSilence(AFormat, AFrames); end;

function AudioBufferClone(const ABuffer: TAudioBuffer): TAudioBuffer;
begin Result := nextpas.core.audio.base.AudioBufferClone(ABuffer); end;

function AudioBytesForFrames(const AFormat: TAudioFormat; AFrames: Integer): Int64;
begin Result := nextpas.core.audio.base.AudioBytesForFrames(AFormat, AFrames); end;

function AudioSilentFill(var ABuffer: TAudioBuffer; const AFormat: TAudioFormat; AFrames: Integer): Integer;
begin Result := nextpas.core.audio.base.AudioSilentFill(ABuffer, AFormat, AFrames); end;

function CreateAudioBank(const AFormat: TAudioFormat): IAudioBank;
begin Result := nextpas.core.audio.bank.impl.CreateAudioBank(AFormat); end;

function CreateAudioResourceManager: IAudioResourceManager;
begin Result := nextpas.core.audio.resource.impl.CreateAudioResourceManager; end;

function CreateAudioEventSystem(const AFormat: TAudioFormat; AMaxVoices: Integer): IAudioEventSystem;
begin Result := nextpas.core.audio.event.impl.CreateAudioEventSystem(AFormat, AMaxVoices); end;

function CreateAudioPlaylist(const AFormat: TAudioFormat): IAudioPlaylist;
begin Result := nextpas.core.audio.playlist.impl.CreateAudioPlaylist(AFormat); end;

end.
