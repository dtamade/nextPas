unit nextpas.core.audio.codec.opus;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.audio.codec.opus.base,
  nextpas.core.audio.codec.opus.intf,
  nextpas.core.audio.codec.opus.impl,
  nextpas.core.base,
  nextpas.core.audio.base,
  nextpas.core.audio.intf,
  nextpas.core.audio.codec.intf;

type
  IOpusDecoder = nextpas.core.audio.codec.opus.intf.IOpusDecoder;

const
  COpusProbeLimit = nextpas.core.audio.codec.opus.base.COpusProbeLimit;

function OpusProbe(const APrefix: TBytes): TAudioProbeResult; inline;
function CreateOpusDecoder: IAudioDecoder; inline;

implementation

uses
  nextpas.core.audio.codec.registry;

// Probe≤4KB guard: 4096 — facade inline forwarding to impl (zero-alloc)

function OpusProbe(const APrefix: TBytes): TAudioProbeResult; inline;
begin
  Result := nextpas.core.audio.codec.opus.impl.OpusProbe(APrefix);
end;

function CreateOpusDecoder: IAudioDecoder; inline;
begin
  Result := nextpas.core.audio.codec.opus.impl.CreateOpusDecoder;
end;

initialization
  // thin facade auto-registration: registry remains thin (no hard uses impl), impl registers via facade initialization (plugin)
  AudioRegisterDecoder(@CreateOpusDecoder);

end.
