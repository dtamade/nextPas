unit nextpas.core.audio.spatial;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.audio.base,
  nextpas.core.audio.spatial.base,
  nextpas.core.audio.spatial.intf,
  nextpas.core.audio.spatial.impl,
  nextpas.core.audio.intf;

type
  TAudioVec3 = nextpas.core.audio.spatial.intf.TAudioVec3;
  TAudioVector3 = nextpas.core.audio.spatial.intf.TAudioVector3;
  TAudioDistanceModel = nextpas.core.audio.spatial.base.TAudioDistanceModel;
  TAudioListener = nextpas.core.audio.spatial.intf.TAudioListener;
  TAudioSpatialParams = nextpas.core.audio.spatial.intf.TAudioSpatialParams;
  TSpatialParams = nextpas.core.audio.spatial.intf.TSpatialParams;
  IAudioSpatialSource = nextpas.core.audio.spatial.intf.IAudioSpatialSource;

function CreateSpatialSource(const ASource: IRealtimeAudioSource; const AListener: TAudioListener; const AParams: TAudioSpatialParams): IAudioSpatialSource; inline;

type
  TAudioVector3Helper = TAudioVec3;
  TSpatialParamsHelper = TAudioSpatialParams;

function SpatialPanFromPosition(const APos: TAudioVector3): Single; inline;
function SpatialGainFromDistance(ADist, AMin, AMax, ARolloff: Single): Single; inline;
function SpatialApply(const ABuffer: TAudioBuffer; const AParams: TSpatialParams): TAudioBuffer; inline;

implementation

function CreateSpatialSource(const ASource: IRealtimeAudioSource; const AListener: TAudioListener; const AParams: TAudioSpatialParams): IAudioSpatialSource; inline;
begin
  Result := nextpas.core.audio.spatial.impl.CreateSpatialSource(ASource, AListener, AParams);
end;

function SpatialPanFromPosition(const APos: TAudioVector3): Single; inline;
begin
  Result := nextpas.core.audio.spatial.intf.SpatialPanFromPosition(APos);
end;

function SpatialGainFromDistance(ADist, AMin, AMax, ARolloff: Single): Single; inline;
begin
  Result := nextpas.core.audio.spatial.intf.SpatialGainFromDistance(ADist, AMin, AMax, ARolloff);
end;

function SpatialApply(const ABuffer: TAudioBuffer; const AParams: TSpatialParams): TAudioBuffer; inline;
begin
  Result := nextpas.core.audio.spatial.intf.SpatialApply(ABuffer, AParams);
end;

end.
