unit nextpas.core.audio.codec.wav;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.audio.codec.wav.base,
  nextpas.core.audio.codec.wav.intf,
  nextpas.core.audio.codec.wav.impl,
  nextpas.core.base,
  nextpas.core.audio.base,
  nextpas.core.audio.intf,
  nextpas.core.audio.codec.intf,
  nextpas.core.io.intf;

type
  IWavDecoder = nextpas.core.audio.codec.wav.intf.IWavDecoder;
  IWavEncoder = nextpas.core.audio.codec.wav.intf.IWavEncoder;

const
  CWavProbeLimit = nextpas.core.audio.codec.wav.base.CWavProbeLimit;

// Probe≤4KB guard: 4096 — facade inline forwarding to impl (zero-alloc)
function WavProbe(const APrefix: TBytes): TAudioProbeResult; inline;
function CreateWavDecoder: IAudioDecoder; inline;
function CreateWavEncoder: IAudioEncoder; inline;
procedure AudioEncodeWav(const ABuffer: TAudioBuffer; const AFilePath: string); overload; inline;
procedure AudioEncodeWav(const ABuffer: TAudioBuffer; const ADest: IStream;
  const AOptions: TAudioEncodeOptions); overload; inline;
procedure AudioEncodeWav(const ABuffer: TAudioBuffer; const ADest: IStream); overload; inline;

implementation

uses
  nextpas.core.fs;

function WavProbe(const APrefix: TBytes): TAudioProbeResult; inline;
begin
  Result := nextpas.core.audio.codec.wav.impl.WavProbe(APrefix);
end;

function CreateWavDecoder: IAudioDecoder; inline;
begin
  Result := nextpas.core.audio.codec.wav.impl.CreateWavDecoder;
end;

function CreateWavEncoder: IAudioEncoder; inline;
begin
  Result := nextpas.core.audio.codec.wav.impl.CreateWavEncoder;
end;

procedure AudioEncodeWav(const ABuffer: TAudioBuffer; const AFilePath: string);
var
  LStream: IStream;
  LOpts: TAudioEncodeOptions;
begin
  // stability: LStream refcounted, auto-released; no leak on exception
  LStream := nextpas.core.fs.Create(AFilePath);
  LOpts.SampleFormat := ABuffer.Format.SampleFormat;
  LOpts.ApplyDither := False;
  nextpas.core.audio.codec.wav.impl.WavEncode(ABuffer, LStream, LOpts);
end;

procedure AudioEncodeWav(const ABuffer: TAudioBuffer; const ADest: IStream;
  const AOptions: TAudioEncodeOptions);
begin
  // perf: inline forwarding to impl, zero-copy via stream Write, single source bytes.ops not needed for stream path
  nextpas.core.audio.codec.wav.impl.WavEncode(ABuffer, ADest, AOptions);
end;

procedure AudioEncodeWav(const ABuffer: TAudioBuffer; const ADest: IStream);
var
  LOpts: TAudioEncodeOptions;
begin
  LOpts.SampleFormat := ABuffer.Format.SampleFormat;
  LOpts.ApplyDither := False;
  AudioEncodeWav(ABuffer, ADest, LOpts);
end;

end.
