unit nextpas.core.audio.codec.mp3;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.audio.codec.mp3.base,
  nextpas.core.audio.codec.mp3.intf,
  nextpas.core.audio.codec.mp3.impl,
  nextpas.core.base,
  nextpas.core.audio.base,
  nextpas.core.audio.intf,
  nextpas.core.audio.codec.intf;

type
  IMp3Decoder = nextpas.core.audio.codec.mp3.intf.IMp3Decoder;

const
  CMp3ProbeLimit = nextpas.core.audio.codec.mp3.base.CMp3ProbeLimit;

function Mp3Probe(const APrefix: TBytes): TAudioProbeResult; inline;
function CreateMp3Decoder: IAudioDecoder; inline;

implementation

uses
  nextpas.core.audio.codec.registry;

// Probe≤4KB guard: 4096 — facade inline forwarding to impl

function Mp3Probe(const APrefix: TBytes): TAudioProbeResult; inline;
begin
  Result := nextpas.core.audio.codec.mp3.impl.Mp3Probe(APrefix);
end;

function CreateMp3Decoder: IAudioDecoder; inline;
begin
  Result := nextpas.core.audio.codec.mp3.impl.CreateMp3Decoder;
end;

initialization
  AudioRegisterDecoder(@CreateMp3Decoder);

end.
