unit nextpas.core.audio.resource;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.audio.base,
  nextpas.core.audio.resource.base,
  nextpas.core.audio.resource.intf,
  nextpas.core.audio.resource.impl;

type
  TAudioResourceState = nextpas.core.audio.resource.base.TAudioResourceState;
  TAudioResourceId = nextpas.core.audio.resource.base.TAudioResourceId;
  IAudioResourceManager = nextpas.core.audio.resource.intf.IAudioResourceManager;

function CreateAudioResourceManager: IAudioResourceManager; inline;

implementation

function CreateAudioResourceManager: IAudioResourceManager; inline;
begin
  Result := nextpas.core.audio.resource.impl.CreateAudioResourceManager;
end;

end.
