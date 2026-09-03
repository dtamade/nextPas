unit nextpas.core.audio.codec.vorbis;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.audio.codec.vorbis.base,
  nextpas.core.audio.codec.vorbis.intf,
  nextpas.core.audio.codec.vorbis.impl,
  nextpas.core.base,
  nextpas.core.audio.base,
  nextpas.core.audio.intf,
  nextpas.core.audio.codec.intf;

type
  IVorbisDecoder = nextpas.core.audio.codec.vorbis.intf.IVorbisDecoder;

const
  CVorbisProbeLimit = nextpas.core.audio.codec.vorbis.base.CVorbisProbeLimit;

function VorbisProbe(const APrefix: TBytes): TAudioProbeResult; inline;
function CreateVorbisDecoder: IAudioDecoder; inline;

implementation

uses
  nextpas.core.audio.codec.registry;

// Probe≤4KB guard: 4096 — facade inline forwarding to impl

function VorbisProbe(const APrefix: TBytes): TAudioProbeResult; inline;
begin
  Result := nextpas.core.audio.codec.vorbis.impl.VorbisProbe(APrefix);
end;

function CreateVorbisDecoder: IAudioDecoder; inline;
begin
  Result := nextpas.core.audio.codec.vorbis.impl.CreateVorbisDecoder;
end;

initialization
  AudioRegisterDecoder(@CreateVorbisDecoder);

end.
