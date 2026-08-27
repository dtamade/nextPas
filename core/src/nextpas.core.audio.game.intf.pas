unit nextpas.core.audio.game.intf;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.audio.base,
  nextpas.core.audio.intf,
  nextpas.core.audio.device.intf,
  nextpas.core.audio.graph.intf;

type
  TGameSfxId = Integer;
  TGameVoiceId = Integer;

  TGamePlayParams = record
    Gain: Single;
    Pan: Single;
    Pitch: Single;
    Loop: Boolean;
    Priority: Integer;
    class function Default: TGamePlayParams; static;
  end;

  IGameAudio = interface
    ['{F1A2B3C4-D5E6-7890-ABCD-A00000000050}']
    function GetGraph: IAudioGraph;
    function GetDevice: IAudioDevice;
    function GetMasterGain: Single;
    procedure SetMasterGain(AGain: Single);
    function Load(const ABuffer: TAudioBuffer): TGameSfxId;
    function LoadFromFile(const APath: string): TGameSfxId;
    procedure Unload(AId: TGameSfxId);
    function Play(AId: TGameSfxId): TGameVoiceId; overload;
    function Play(AId: TGameSfxId; const AParams: TGamePlayParams): TGameVoiceId; overload;
    function Play(AId: TGameSfxId; AGain: Single; APan: Single = 0; APitch: Single = 1.0; ALoop: Boolean = False): TGameVoiceId; overload;
    function StopVoice(AVoice: TGameVoiceId): Boolean;
    procedure StopAll;
    function VoiceCount: Integer;
    function SfxCount: Integer;
    property Graph: IAudioGraph read GetGraph;
    property Device: IAudioDevice read GetDevice;
    property MasterGain: Single read GetMasterGain write SetMasterGain;
  end;

implementation

class function TGamePlayParams.Default: TGamePlayParams;
begin
  Result.Gain := 1.0;
  Result.Pan := 0.0;
  Result.Pitch := 1.0;
  Result.Loop := False;
  Result.Priority := 0;
end;

end.
