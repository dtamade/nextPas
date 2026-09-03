unit nextpas.core.audio.event;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.audio.base,
  nextpas.core.audio.event.base,
  nextpas.core.audio.event.intf,
  nextpas.core.audio.event.impl,
  nextpas.core.audio.spatial.intf;

type
  TAudioEventId = nextpas.core.audio.event.base.TAudioEventId;
  TAudioEventInstanceId = nextpas.core.audio.event.base.TAudioEventInstanceId;
  TAudioEventParamId = nextpas.core.audio.event.base.TAudioEventParamId;
  TAudioEventDesc = nextpas.core.audio.event.intf.TAudioEventDesc;
  IAudioEventSystem = nextpas.core.audio.event.intf.IAudioEventSystem;

function CreateAudioEventSystem(const AFormat: TAudioFormat; AMaxVoices: Integer = 32): IAudioEventSystem; inline;

implementation

function CreateAudioEventSystem(const AFormat: TAudioFormat; AMaxVoices: Integer): IAudioEventSystem; inline;
begin
  Result := nextpas.core.audio.event.impl.CreateAudioEventSystem(AFormat, AMaxVoices);
end;

end.
