unit nextpas.core.audio.bus;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.audio.bus.base,
  nextpas.core.audio.bus.intf,
  nextpas.core.audio.bus.impl,
  nextpas.core.audio.base,
  nextpas.core.audio.intf;

type
  TAudioBusId = nextpas.core.audio.bus.base.TAudioBusId;
  IAudioBus = nextpas.core.audio.bus.intf.IAudioBus;
  IAudioBusMixer = nextpas.core.audio.bus.intf.IAudioBusMixer;

function CreateAudioBusMixer: IAudioBusMixer; inline;

implementation

function CreateAudioBusMixer: IAudioBusMixer; inline;
begin
  Result := nextpas.core.audio.bus.impl.CreateAudioBusMixer;
end;

end.
