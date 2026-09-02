unit nextpas.core.audio.pcm_wav;

{**
 * @desc PCM WAV 兼容壳门面：纯 re-export + inline 转发至 pcm_wav.impl。
 *  四件套：pcm_wav.base ← pcm_wav.impl ← pcm_wav (facade)；无独立 intf 按需存在，
 *  守 L0-L3，重用 bytes.ops 单源，IO 依赖仅 io.intf。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.audio.pcm_wav.base,
  nextpas.core.audio.pcm_wav.impl,
  nextpas.core.io.intf;

type
  TPcmWavBytes = nextpas.core.audio.pcm_wav.base.TPcmWavBytes;
  TPcmWavData = nextpas.core.audio.pcm_wav.base.TPcmWavData;

const
  DefaultPcmWavSampleRate = nextpas.core.audio.pcm_wav.base.DefaultPcmWavSampleRate;
  DefaultPcmWavChannels = nextpas.core.audio.pcm_wav.base.DefaultPcmWavChannels;
  DefaultPcmWavSilenceMs = nextpas.core.audio.pcm_wav.base.DefaultPcmWavSilenceMs;
  PcmWavBitsPerSample = nextpas.core.audio.pcm_wav.base.PcmWavBitsPerSample;

// perf: inline + zero-copy forwarding via bytes.ops single source in impl; facade zero logic
function TryLoadPcmWav(const AFilePath: string; out AData: TPcmWavData): Boolean; inline;
function TryParsePcmWav(const AStream: IStream; out AData: TPcmWavData): Boolean; inline;
procedure WritePcmWav(const AFilePath: string; ASampleRate, AChannels: Integer; const ASamples: array of SmallInt); inline;
procedure WritePcmWavStream(const AStream: IStream; ASampleRate, AChannels: Integer; const ASamples: array of SmallInt); inline;
procedure WriteSilencePcmWav(const AFilePath: string; ASampleRate, AChannels, ADurationMs: Integer); inline;
procedure WriteSilencePcmWavStream(const AStream: IStream; ASampleRate, AChannels, ADurationMs: Integer); inline;

implementation

function TryLoadPcmWav(const AFilePath: string; out AData: TPcmWavData): Boolean; inline;
begin
  Result := nextpas.core.audio.pcm_wav.impl.TryLoadPcmWav(AFilePath, AData);
end;

function TryParsePcmWav(const AStream: IStream; out AData: TPcmWavData): Boolean; inline;
begin
  Result := nextpas.core.audio.pcm_wav.impl.TryParsePcmWav(AStream, AData);
end;

procedure WritePcmWav(const AFilePath: string; ASampleRate, AChannels: Integer; const ASamples: array of SmallInt); inline;
begin
  nextpas.core.audio.pcm_wav.impl.WritePcmWav(AFilePath, ASampleRate, AChannels, ASamples);
end;

procedure WritePcmWavStream(const AStream: IStream; ASampleRate, AChannels: Integer; const ASamples: array of SmallInt); inline;
begin
  nextpas.core.audio.pcm_wav.impl.WritePcmWavStream(AStream, ASampleRate, AChannels, ASamples);
end;

procedure WriteSilencePcmWav(const AFilePath: string; ASampleRate, AChannels, ADurationMs: Integer); inline;
begin
  nextpas.core.audio.pcm_wav.impl.WriteSilencePcmWav(AFilePath, ASampleRate, AChannels, ADurationMs);
end;

procedure WriteSilencePcmWavStream(const AStream: IStream; ASampleRate, AChannels, ADurationMs: Integer); inline;
begin
  nextpas.core.audio.pcm_wav.impl.WriteSilencePcmWavStream(AStream, ASampleRate, AChannels, ADurationMs);
end;

end.
