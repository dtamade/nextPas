unit nextpas.core.audio.game;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.audio.base,
  nextpas.core.audio.intf,
  nextpas.core.audio.device.intf,
  nextpas.core.audio.graph.intf,
  nextpas.core.audio.sfx.intf,
  nextpas.core.audio.sfx;

// 薄转发兼容层：game → sfx 的平滑迁移，保留一版 deprecated
// sfx 为 canonical，game 仅为别名，避免 L2 出现领域耦合

type
  TGameVoiceSource = TSfxVoiceSource deprecated 'use TSfxVoiceSource';
  TGameAudio = TSfxAudio deprecated 'use TSfxAudio';

function CreateGameAudio(const ADevice: IAudioDevice; const AGraph: IAudioGraph; AMaxVoices: Integer = 32): IGameAudio; inline; deprecated 'use CreateSfxAudio';
function CreateGameAudioForFormat(const AProvider: IAudioDeviceProvider; const AFormat: TAudioFormat; AMaxVoices: Integer = 32): IGameAudio; inline; deprecated 'use CreateSfxAudioForFormat';

implementation

function CreateGameAudio(const ADevice: IAudioDevice; const AGraph: IAudioGraph; AMaxVoices: Integer): IGameAudio;
begin
  Result := CreateSfxAudio(ADevice, AGraph, AMaxVoices);
end;

function CreateGameAudioForFormat(const AProvider: IAudioDeviceProvider; const AFormat: TAudioFormat; AMaxVoices: Integer): IGameAudio;
begin
  Result := CreateSfxAudioForFormat(AProvider, AFormat, AMaxVoices);
end;

end.
