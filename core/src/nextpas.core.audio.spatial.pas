unit nextpas.core.audio.spatial;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.audio.base;

type
  TAudioVector3 = record
    X, Y, Z: Single;
    class function Create(AX, AY, AZ: Single): TAudioVector3; static;
  end;

  TSpatialParams = record
    Position: TAudioVector3;
    Distance: Single;
    MinDistance: Single;
    MaxDistance: Single;
    Rolloff: Single;
    Doppler: Single;
  end;

function SpatialPanFromPosition(const APos: TAudioVector3): Single;
function SpatialGainFromDistance(ADist, AMin, AMax, ARolloff: Single): Single;
function SpatialApply(const ABuffer: TAudioBuffer; const AParams: TSpatialParams): TAudioBuffer;

implementation

uses
  Math;

class function TAudioVector3.Create(AX, AY, AZ: Single): TAudioVector3;
begin
  Result.X := AX; Result.Y := AY; Result.Z := AZ;
end;

function SpatialPanFromPosition(const APos: TAudioVector3): Single;
begin
  // simple azimuth pan: X in [-1..1] -> pan [-1..1]
  Result := APos.X;
  if Result < -1 then Result := -1 else if Result > 1 then Result := 1;
end;

function SpatialGainFromDistance(ADist, AMin, AMax, ARolloff: Single): Single;
var L: Single;
begin
  if ADist <= AMin then Exit(1.0);
  if ADist >= AMax then Exit(0.0);
  if AMax - AMin = 0 then Exit(1.0);
  L := (ADist - AMin) / (AMax - AMin);
  Result := 1.0 - L * ARolloff;
  if Result < 0 then Result := 0 else if Result > 1 then Result := 1;
end;

function SpatialApply(const ABuffer: TAudioBuffer; const AParams: TSpatialParams): TAudioBuffer;
var
  LGain, LPan, LL, LR: Single;
  I, N: Integer;
  PSrc, PDst: PSingle;
begin
  Result := Default(TAudioBuffer);
  if not ABuffer.Format.IsValid then Exit;
  if ABuffer.Format.Channels <> 2 then
  begin
    Result := ABuffer;
    Exit;
  end;
  LGain := SpatialGainFromDistance(AParams.Distance, AParams.MinDistance, AParams.MaxDistance, AParams.Rolloff);
  LPan := SpatialPanFromPosition(AParams.Position);
  AudioPanLawGains(LPan, LL, LR);
  LL := LL * LGain; LR := LR * LGain;
  Result.Format := ABuffer.Format;
  Result.FrameCount := ABuffer.FrameCount;
  SetLength(Result.Data, Length(ABuffer.Data));
  if Length(ABuffer.Data) > 0 then
    Move(ABuffer.Data[0], Result.Data[0], Length(ABuffer.Data));
  N := ABuffer.FrameCount;
  PSrc := PSingle(@ABuffer.Data[0]);
  PDst := PSingle(@Result.Data[0]);
  // 4-wide unrolled pan/gain (stereo interleaved)
  I := 0;
  while I + 3 < N do
  begin
    PDst[I*2] := PSrc[I*2]*LL; PDst[I*2+1] := PSrc[I*2+1]*LR;
    PDst[(I+1)*2] := PSrc[(I+1)*2]*LL; PDst[(I+1)*2+1] := PSrc[(I+1)*2+1]*LR;
    PDst[(I+2)*2] := PSrc[(I+2)*2]*LL; PDst[(I+2)*2+1] := PSrc[(I+2)*2+1]*LR;
    PDst[(I+3)*2] := PSrc[(I+3)*2]*LL; PDst[(I+3)*2+1] := PSrc[(I+3)*2+1]*LR;
    Inc(I, 4);
  end;
  while I < N do
  begin
    PDst[I*2] := PSrc[I*2]*LL;
    PDst[I*2+1] := PSrc[I*2+1]*LR;
    Inc(I);
  end;
end;

end.
