// P12: TAudioSpatialParams canonical in base (spatial.intf alias kept for compatibility)
unit nextpas.core.audio.event.intf;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.audio.base,
  nextpas.core.audio.intf,
  nextpas.core.audio.spatial.intf;

type
  TAudioEventId = Integer;
  TAudioEventInstanceId = Integer;
  TAudioEventParamId = Integer;

const
  CAudioMaxEventParams = 8;

type
  TAudioEventDesc = record
    Name: string;
    Buffer: TAudioBuffer;
    Spatial: TAudioSpatialParams;
    BaseGain: Single;
    BasePitch: Single;
    Loop: Boolean;
    MaxInstances: Integer; // 0 = unlimited (bounded by system MaxVoices)
    class function Create(const ABuffer: TAudioBuffer; const ASpatial: TAudioSpatialParams; AGain: Single = 1.0; APitch: Single = 1.0; ALoop: Boolean = False): TAudioEventDesc; static;
  end;

  IAudioEventSystem = interface(IRealtimeAudioSource)
    ['{F1A2B3C4-D5E6-7890-ABCD-A00000000052}']
    function GetFormat: TAudioFormat;
    function RegisterEvent(const ADesc: TAudioEventDesc): TAudioEventId;
    procedure Unregister(AId: TAudioEventId);
    function GetEventCount: Integer;
    function Play(AEvent: TAudioEventId): TAudioEventInstanceId; overload;
    function Play(AEvent: TAudioEventId; AGain: Single; APitch: Single; const APos: TAudioVec3): TAudioEventInstanceId; overload;
    function Play(AEvent: TAudioEventId; const AParams: TAudioSpatialParams; AGain: Single = 1.0; APitch: Single = 1.0): TAudioEventInstanceId; overload;
    function SetInstanceParam(AInstance: TAudioEventInstanceId; AParam: TAudioEventParamId; AValue: Single): Boolean;
    function GetInstanceParam(AInstance: TAudioEventInstanceId; AParam: TAudioEventParamId): Single;
    function SetInstancePosition(AInstance: TAudioEventInstanceId; const APos: TAudioVec3): Boolean;
    function GetInstancePosition(AInstance: TAudioEventInstanceId): TAudioVec3;
    function StopInstance(AInstance: TAudioEventInstanceId): Boolean;
    procedure StopAll;
    function IsPlaying(AInstance: TAudioEventInstanceId): Boolean;
    function GetInstanceCount: Integer;
    // RTPC globals
    function SetGlobalParam(AParam: TAudioEventParamId; AValue: Single): Boolean;
    function GetGlobalParam(AParam: TAudioEventParamId): Single;
    // listener
    procedure SetListener(const AListener: TAudioListener);
    function GetListener: TAudioListener;
  end;

implementation

class function TAudioEventDesc.Create(const ABuffer: TAudioBuffer; const ASpatial: TAudioSpatialParams; AGain: Single; APitch: Single; ALoop: Boolean): TAudioEventDesc;
begin
  Result.Name := '';
  Result.Buffer := ABuffer;
  Result.Spatial := ASpatial;
  Result.BaseGain := AGain;
  Result.BasePitch := APitch;
  Result.Loop := ALoop;
  Result.MaxInstances := 0;
end;

end.
