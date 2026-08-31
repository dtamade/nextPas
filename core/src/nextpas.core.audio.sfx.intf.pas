unit nextpas.core.audio.sfx.intf;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.audio.base,
  nextpas.core.audio.intf,
  nextpas.core.audio.device.intf,
  nextpas.core.audio.graph.intf;

type
  TSfxId = Integer;
  TVoiceId = Integer;

  TSfxPlayParams = record
    Gain: Single;
    Pan: Single;
    Pitch: Single;
    Loop: Boolean;
    Priority: Integer;
    class function Default: TSfxPlayParams; static;
  end;

  ISfxAudio = interface
    ['{F1A2B3C4-D5E6-7890-ABCD-A00000000050}']
    function GetGraph: IAudioGraph;
    function GetDevice: IAudioDevice;
    function GetMasterGain: Single;
    procedure SetMasterGain(AGain: Single);
    function Load(const ABuffer: TAudioBuffer): TSfxId;
    function LoadFromFile(const APath: string): TSfxId;
    procedure Unload(AId: TSfxId);
    function Play(AId: TSfxId): TVoiceId; overload;
    function Play(AId: TSfxId; const AParams: TSfxPlayParams): TVoiceId; overload;
    function Play(AId: TSfxId; AGain: Single; APan: Single = 0; APitch: Single = 1.0; ALoop: Boolean = False): TVoiceId; overload;
    function StopVoice(AVoice: TVoiceId): Boolean;
    procedure StopAll;
    function VoiceCount: Integer;
    function SfxCount: Integer;
    property Graph: IAudioGraph read GetGraph;
    property Device: IAudioDevice read GetDevice;
    property MasterGain: Single read GetMasterGain write SetMasterGain;
  end;

  // 兼容别名：game → sfx 的平滑迁移，保留一版 deprecated
  TGameSfxId = TSfxId deprecated 'use TSfxId';
  TGameVoiceId = TVoiceId deprecated 'use TVoiceId';
  TGamePlayParams = TSfxPlayParams deprecated 'use TSfxPlayParams';
  IGameAudio = ISfxAudio deprecated 'use ISfxAudio';

implementation

class function TSfxPlayParams.Default: TSfxPlayParams;
begin
  Result.Gain := 1.0;
  Result.Pan := 0.0;
  Result.Pitch := 1.0;
  Result.Loop := False;
  Result.Priority := 0;
end;

end.
