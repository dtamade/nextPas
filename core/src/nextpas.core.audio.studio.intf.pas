unit nextpas.core.audio.studio.intf;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.audio.base,
  nextpas.core.audio.intf;

type
  IAudioStudio = interface
    ['{F1A2B3C4-D5E6-7890-ABCD-A00000000070}']
    function GetFormat: TAudioFormat;
    function GetBpm: Double;
    procedure SetBpm(ABpm: Double);
    function GetSource: IRealtimeAudioSource;
    function FillRealtime(var ABuffer: TAudioBuffer; AFrames: Integer): Integer;
    property Format: TAudioFormat read GetFormat;
    property Bpm: Double read GetBpm write SetBpm;
  end;

  IStudioProject = interface
    ['{F1A2B3C4-D5E6-7890-ABCD-A00000000071}']
    function GetName: string;
    procedure SetName(const AName: string);
    function GetBpm: Double;
    procedure SetBpm(ABpm: Double);
    property Name: string read GetName write SetName;
    property Bpm: Double read GetBpm write SetBpm;
  end;

function StudioBpmToFramesPerBeat(ABpm: Double; ASampleRate: Integer): Integer;
function StudioQuantizeFrame(AFrame: UInt64; ABpm: Double; ASampleRate: Integer): UInt64;

implementation

function StudioBpmToFramesPerBeat(ABpm: Double; ASampleRate: Integer): Integer;
begin
  if ABpm <= 0 then Exit(0);
  Result := Round(ASampleRate * 60.0 / ABpm);
end;

function StudioQuantizeFrame(AFrame: UInt64; ABpm: Double; ASampleRate: Integer): UInt64;
var FPB: Integer; Beat: UInt64;
begin
  FPB := StudioBpmToFramesPerBeat(ABpm, ASampleRate);
  if FPB <= 0 then Exit(AFrame);
  Beat := (AFrame + UInt64(FPB div 2)) div UInt64(FPB);
  Result := Beat * UInt64(FPB);
end;

end.
