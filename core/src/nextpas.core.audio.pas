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
  nextpas.core.audio.codec.wav,
  nextpas.core.audio.codec.aiff,
  nextpas.core.audio.codec.meta,
  nextpas.core.audio.codec.registry,
  nextpas.core.audio.codec.flac,
  nextpas.core.audio.codec.mp3,
  nextpas.core.audio.codec.vorbis,
  nextpas.core.audio.pcm.simd,
  nextpas.core.audio.simd,
  nextpas.core.audio.resample,
  nextpas.core.audio.resample.sinc,
  nextpas.core.audio.mix,
  nextpas.core.audio.dsp.filters,
  nextpas.core.audio.dsp.dynamics,
  nextpas.core.audio.dsp.fft,
  nextpas.core.audio.device.intf,
  nextpas.core.audio.device.null,
  nextpas.core.audio.timeline.intf,
  nextpas.core.audio.game.intf,
  nextpas.core.audio.graph.intf,
  nextpas.core.audio.studio.intf,
  nextpas.core.audio.timeline,
  nextpas.core.audio.game,
  nextpas.core.audio.graph,
  nextpas.core.audio.player,
  nextpas.core.audio.playlist,
  nextpas.core.audio.spatial,
  nextpas.core.audio.bus,
  nextpas.core.audio.bank,
  nextpas.core.audio.studio.project,
  nextpas.core.audio.studio.sequencer,
  nextpas.core.audio.studio.automation;

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

  TDeviceState = nextpas.core.audio.device.intf.TDeviceState;
  TDeviceEvent = nextpas.core.audio.device.intf.TDeviceEvent;
  TAudioDeviceInfoArray = nextpas.core.audio.device.intf.TAudioDeviceInfoArray;
  IAudioDevice = nextpas.core.audio.device.intf.IAudioDevice;
  IAudioDeviceProvider = nextpas.core.audio.device.intf.IAudioDeviceProvider;

  TGameSfxId = nextpas.core.audio.game.intf.TGameSfxId;
  TGameVoiceId = nextpas.core.audio.game.intf.TGameVoiceId;
  TGamePlayParams = nextpas.core.audio.game.intf.TGamePlayParams;
  IAudioTimeline = nextpas.core.audio.timeline.intf.IAudioTimeline;
  IGameAudio = nextpas.core.audio.game.intf.IGameAudio;
  TGraphState = nextpas.core.audio.graph.intf.TGraphState;
  IAudioGraph = nextpas.core.audio.graph.intf.IAudioGraph;
  IAudioPlayer = nextpas.core.audio.graph.intf.IAudioPlayer;
  IAudioPlaylist = nextpas.core.audio.playlist.IAudioPlaylist;
  IAudioBus = nextpas.core.audio.bus.IAudioBus;
  IAudioBusMixer = nextpas.core.audio.bus.IAudioBusMixer;
  TAudioBank = nextpas.core.audio.bank.TAudioBank;
  IStudioProject = nextpas.core.audio.studio.intf.IStudioProject;
  IAudioSequencer = nextpas.core.audio.studio.sequencer.IAudioSequencer;
  TAutomationCurve = nextpas.core.audio.studio.automation.TAutomationCurve;
  TMidiNote = nextpas.core.audio.studio.sequencer.TMidiNote;
  TAudioVector3 = nextpas.core.audio.spatial.TAudioVector3;
  TSimdCaps = nextpas.core.audio.simd.TSimdCaps;

{ ---- base forwarding ---- }

function AudioFormatCreate(ASampleRate, AChannels: Integer;
  ASampleFormat: TAudioSampleFormat): TAudioFormat; inline;
function AudioBytesPerSample(AFormat: TAudioSampleFormat): Integer; inline;
function AudioChannelMaskForLayout(ALayout: TAudioChannelLayout): UInt32; inline;
function AudioChannelLayoutForMask(AMask: UInt32; AChannels: Integer): TAudioChannelLayout; inline;
function AudioBytesForFrames(const AFormat: TAudioFormat; AFrames: Integer): Int64; inline;
function AudioIsValidBuffer(const ABuffer: TAudioBuffer; ARequireF32: Boolean = False): Boolean; inline;
function AudioBufferDataBytes(const ABuffer: TAudioBuffer): Integer; inline;
procedure AudioValidateBuffer(const ABuffer: TAudioBuffer; const AContext: string; ARequireF32: Boolean = False); inline;
function AudioFillMemoryRealtime(const ASrc: TAudioBuffer; var APos: Integer;
  var ABuffer: TAudioBuffer; AFrames: Integer): Integer; inline;
function AudioSilentFill(var ABuffer: TAudioBuffer; const AFormat: TAudioFormat;
  AFrames: Integer): Integer; inline;

{ ---- simd forwarding (realtime-grade, 4-wide) ---- }

function AudioSimdCaps: TSimdCaps; inline;
procedure SimdAddF32(const ASrc: PSingle; ADst: PSingle; ACount: Integer; AGain: Single); inline;
procedure SimdMulF32(const ASrc: PSingle; ADst: PSingle; ACount: Integer; AGain: Single); inline;
function SimdPeakF32(const AData: PSingle; ACount: Integer): Single; inline;
function SimdSumSquaresF32(const AData: PSingle; ACount: Integer): Double; inline;
procedure SimdClampF32(AData: PSingle; ACount: Integer; ALo, AHi: Single); inline;

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

{ ---- resample/mix/dsp forwarding (PR5) ---- }

function AudioResampleLinear(const AInput: TAudioBuffer; ANewRate: Integer): TAudioBuffer; inline;
function CreateLinearResampler: IAudioResampler; inline;
function CreateSincResampler(AQuality: TResampleQuality = rsGood): IAudioResampler; inline;

procedure MixInto(var ADst: TAudioBuffer; const ASrc: TAudioBuffer; AGain: Single; AOffset: Integer); inline;
procedure ApplyGain(var ABuf: TAudioBuffer; AGain: Single); inline;
procedure ApplyGainRamp(var ABuf: TAudioBuffer; AStartGain, AEndGain: Single); inline;
function NormalizePeak(var ABuf: TAudioBuffer; ATarget: Single): Single; inline;
function NormalizeRMS(var ABuf: TAudioBuffer; ATarget: Single): Single; inline;

function WindowHann(N, I: Integer): Single; inline;
procedure FFT(var ARe, AIm: array of Single); inline;
procedure IFFT(var ARe, AIm: array of Single); inline;
function IsPowerOfTwo(N: Integer): Boolean; inline;

function CreateNullAudioProvider: IAudioDeviceProvider; inline;
function CreateAudioGraph(const AFormat: TAudioFormat): IAudioGraph; inline;
function CreateAudioPlayer(const ADevice: IAudioDevice; const AGraph: IAudioGraph): IAudioPlayer; inline;
function CreateAudioPlayerForFormat(const AProvider: IAudioDeviceProvider; const AFormat: TAudioFormat): IAudioPlayer; inline;
function CreateGameAudio(const ADevice: IAudioDevice; const AGraph: IAudioGraph; AMaxVoices: Integer = 32): IGameAudio; inline;
function CreateGameAudioForFormat(const AProvider: IAudioDeviceProvider; const AFormat: TAudioFormat; AMaxVoices: Integer = 32): IGameAudio; inline;
function CreateAudioTimeline(const AFormat: TAudioFormat): IAudioTimeline; inline;
function CreateFlacDecoder: IAudioDecoder; inline;
function CreateMp3Decoder: IAudioDecoder; inline;
function CreateVorbisDecoder: IAudioDecoder; inline;
function FlacProbe(const APrefix: TBytes): TAudioProbeResult; inline;
function Mp3Probe(const APrefix: TBytes): TAudioProbeResult; inline;
function VorbisProbe(const APrefix: TBytes): TAudioProbeResult; inline;
function AlacProbe(const APrefix: TBytes): TAudioProbeResult; inline;
function WavPackProbe(const APrefix: TBytes): TAudioProbeResult; inline;
function OpusProbe(const APrefix: TBytes): TAudioProbeResult; inline;
function AacProbe(const APrefix: TBytes): TAudioProbeResult; inline;
function CreateAudioPlaylist(const AFormat: TAudioFormat): IAudioPlaylist; inline;
function CreateAudioBusMixer: IAudioBusMixer; inline;
function CreateAudioBank: TAudioBank; inline;
function CreateStudioProject(const AName: string; ABpm: Double; const AFormat: TAudioFormat): IStudioProject; inline;
function CreateAudioSequencer(const AFormat: TAudioFormat; ABpm: Double): IAudioSequencer; inline;

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

function AudioBytesForFrames(const AFormat: TAudioFormat; AFrames: Integer): Int64;
begin Result := nextpas.core.audio.base.AudioBytesForFrames(AFormat, AFrames); end;

function AudioIsValidBuffer(const ABuffer: TAudioBuffer; ARequireF32: Boolean): Boolean;
begin Result := nextpas.core.audio.base.AudioIsValidBuffer(ABuffer, ARequireF32); end;

function AudioBufferDataBytes(const ABuffer: TAudioBuffer): Integer;
begin Result := nextpas.core.audio.base.AudioBufferDataBytes(ABuffer); end;

procedure AudioValidateBuffer(const ABuffer: TAudioBuffer; const AContext: string; ARequireF32: Boolean);
begin nextpas.core.audio.base.AudioValidateBuffer(ABuffer, AContext, ARequireF32); end;

function AudioFillMemoryRealtime(const ASrc: TAudioBuffer; var APos: Integer;
  var ABuffer: TAudioBuffer; AFrames: Integer): Integer;
begin Result := nextpas.core.audio.base.AudioFillMemoryRealtime(ASrc, APos, ABuffer, AFrames); end;

function AudioSilentFill(var ABuffer: TAudioBuffer; const AFormat: TAudioFormat;
  AFrames: Integer): Integer;
begin Result := nextpas.core.audio.base.AudioSilentFill(ABuffer, AFormat, AFrames); end;

function AudioSimdCaps: TSimdCaps;
begin Result := nextpas.core.audio.simd.AudioSimdCaps; end;

procedure SimdAddF32(const ASrc: PSingle; ADst: PSingle; ACount: Integer; AGain: Single);
begin nextpas.core.audio.simd.SimdAddF32(ASrc, ADst, ACount, AGain); end;

procedure SimdMulF32(const ASrc: PSingle; ADst: PSingle; ACount: Integer; AGain: Single);
begin nextpas.core.audio.simd.SimdMulF32(ASrc, ADst, ACount, AGain); end;

function SimdPeakF32(const AData: PSingle; ACount: Integer): Single;
begin Result := nextpas.core.audio.simd.SimdPeakF32(AData, ACount); end;

function SimdSumSquaresF32(const AData: PSingle; ACount: Integer): Double;
begin Result := nextpas.core.audio.simd.SimdSumSquaresF32(AData, ACount); end;

procedure SimdClampF32(AData: PSingle; ACount: Integer; ALo, AHi: Single);
begin nextpas.core.audio.simd.SimdClampF32(AData, ACount, ALo, AHi); end;

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

function CreateGameAudio(const ADevice: IAudioDevice; const AGraph: IAudioGraph; AMaxVoices: Integer): IGameAudio;
begin Result := nextpas.core.audio.game.CreateGameAudio(ADevice, AGraph, AMaxVoices); end;

function CreateGameAudioForFormat(const AProvider: IAudioDeviceProvider; const AFormat: TAudioFormat; AMaxVoices: Integer): IGameAudio;
begin Result := nextpas.core.audio.game.CreateGameAudioForFormat(AProvider, AFormat, AMaxVoices); end;

function CreateAudioTimeline(const AFormat: TAudioFormat): IAudioTimeline;
begin Result := nextpas.core.audio.timeline.CreateAudioTimeline(AFormat); end;

function CreateFlacDecoder: IAudioDecoder;
begin Result := nextpas.core.audio.codec.flac.CreateFlacDecoder; end;

function CreateMp3Decoder: IAudioDecoder;
begin Result := nextpas.core.audio.codec.mp3.CreateMp3Decoder; end;

function CreateVorbisDecoder: IAudioDecoder;
begin Result := nextpas.core.audio.codec.vorbis.CreateVorbisDecoder; end;

function FlacProbe(const APrefix: TBytes): TAudioProbeResult;
begin Result := nextpas.core.audio.codec.flac.FlacProbe(APrefix); end;

function Mp3Probe(const APrefix: TBytes): TAudioProbeResult;
begin Result := nextpas.core.audio.codec.mp3.Mp3Probe(APrefix); end;

function VorbisProbe(const APrefix: TBytes): TAudioProbeResult;
begin Result := nextpas.core.audio.codec.vorbis.VorbisProbe(APrefix); end;

function AlacProbe(const APrefix: TBytes): TAudioProbeResult;
begin Result := prUnknown; end;

function WavPackProbe(const APrefix: TBytes): TAudioProbeResult;
begin Result := prUnknown; end;

function OpusProbe(const APrefix: TBytes): TAudioProbeResult;
begin Result := prUnknown; end;

function AacProbe(const APrefix: TBytes): TAudioProbeResult;
begin Result := prUnknown; end;

function CreateAudioPlaylist(const AFormat: TAudioFormat): IAudioPlaylist;
begin Result := nextpas.core.audio.playlist.CreateAudioPlaylist(AFormat); end;

function CreateAudioBusMixer: IAudioBusMixer;
begin Result := nextpas.core.audio.bus.CreateAudioBusMixer; end;

function CreateAudioBank: TAudioBank;
begin Result := nextpas.core.audio.bank.CreateAudioBank; end;

function CreateStudioProject(const AName: string; ABpm: Double; const AFormat: TAudioFormat): IStudioProject;
begin Result := nextpas.core.audio.studio.project.CreateStudioProject(AName, ABpm, AFormat); end;

function CreateAudioSequencer(const AFormat: TAudioFormat; ABpm: Double): IAudioSequencer;
begin Result := nextpas.core.audio.studio.sequencer.CreateAudioSequencer(AFormat, ABpm); end;

procedure AudioRegisterDecoderPlaceholder;
begin
end;

procedure AudioRegisterEncoderPlaceholder;
begin
end;

end.
