unit nextpas.core.audio.game.intf;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.audio.sfx.intf;

// 薄转发兼容层：game → sfx 的平滑迁移，保留一版 deprecated
// sfx 为 canonical，game 仅为别名，避免 L2 出现领域耦合

type
  TGameSfxId = TSfxId deprecated 'use TSfxId';
  TGameVoiceId = TVoiceId deprecated 'use TVoiceId';
  TGamePlayParams = TSfxPlayParams deprecated 'use TSfxPlayParams';
  IGameAudio = ISfxAudio deprecated 'use ISfxAudio';

implementation

end.
