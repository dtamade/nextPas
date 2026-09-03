unit nextpas.core.audio.codec.flac;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.audio.codec.flac.base,
  nextpas.core.audio.codec.flac.intf,
  nextpas.core.audio.codec.flac.impl,
  nextpas.core.base,
  nextpas.core.audio.base,
  nextpas.core.audio.intf,
  nextpas.core.audio.codec.intf;

type
  IFlacDecoder = nextpas.core.audio.codec.flac.intf.IFlacDecoder;

const
  CFlacProbeLimit = nextpas.core.audio.codec.flac.base.CFlacProbeLimit;

function FlacProbe(const APrefix: TBytes): TAudioProbeResult; inline;
function CreateFlacDecoder: IAudioDecoder; inline;

implementation

uses
  nextpas.core.audio.codec.registry;

// Probe≤4KB guard: 4096 — facade inline forwarding to impl (zero-alloc)

function FlacProbe(const APrefix: TBytes): TAudioProbeResult; inline;
begin
  Result := nextpas.core.audio.codec.flac.impl.FlacProbe(APrefix);
end;

function CreateFlacDecoder: IAudioDecoder; inline;
begin
  Result := nextpas.core.audio.codec.flac.impl.CreateFlacDecoder;
end;

initialization
  // thin facade auto-registration: registry remains thin (no hard uses impl), impl registers via facade initialization (plugin)
  AudioRegisterDecoder(@CreateFlacDecoder);

end.
