unit nextpas.core.audio.spatial.intf;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.audio.base,
  nextpas.core.audio.intf;

type
  TAudioVec3 = record
    X, Y, Z: Single;
  end;

  TAudioDistanceModel = (dmInverse, dmLinear, dmExponent);

  TAudioListener = record
    Position: TAudioVec3;
    Velocity: TAudioVec3;
    Forward: TAudioVec3; // normalized, default (0,0,-1)
    Up: TAudioVec3;      // normalized, default (0,1,0)
    Gain: Single;        // master listener gain, default 1.0
  end;

  TAudioSpatialParams = record
    Position: TAudioVec3;
    Velocity: TAudioVec3;
    MinDistance: Single; // default 1.0
    MaxDistance: Single; // default 100.0
    Rolloff: Single;     // default 1.0
    DistanceModel: TAudioDistanceModel;
    DopplerFactor: Single; // default 1.0, 0 = disable
    ConeInnerAngle: Single; // degrees, not used v1
    ConeOuterAngle: Single;
    ConeOuterGain: Single;
  end;

  // Spatialized source — 3D panner wrapping a mono/stereo source (pure 3D, zero-alloc FillRealtime)
  IAudioSpatialSource = interface(IRealtimeAudioSource)
    ['{F1A2B3C4-D5E6-7890-ABCD-A00000000051}']
    procedure SetPosition(const APos: TAudioVec3);
    function GetPosition: TAudioVec3;
    procedure SetVelocity(const AVel: TAudioVec3);
    function GetVelocity: TAudioVec3;
    procedure SetSpatialParams(const AParams: TAudioSpatialParams);
    function GetSpatialParams: TAudioSpatialParams;
    procedure SetListener(const AListener: TAudioListener);
    function GetListener: TAudioListener;
  end;

function AudioVec3Create(AX, AY, AZ: Single): TAudioVec3; inline;
function AudioVec3Zero: TAudioVec3; inline;
function AudioVec3Length(const A: TAudioVec3): Single; inline;
function AudioVec3Distance(const A, B: TAudioVec3): Single; inline;
function AudioVec3Dot(const A, B: TAudioVec3): Single; inline;
function AudioVec3Normalize(const A: TAudioVec3): TAudioVec3; inline;

function AudioListenerDefault: TAudioListener; inline;
function AudioSpatialParamsDefault: TAudioSpatialParams; inline;

function AudioComputeAttenuation(const AListener: TAudioListener; const ASource: TAudioSpatialParams): Single; inline;
function AudioComputePan(const AListener: TAudioListener; const ASourcePos: TAudioVec3): Single; // -1..1
function AudioComputeDoppler(const AListener: TAudioListener; const ASource: TAudioSpatialParams): Single; // pitch factor

// Combined: out AGain (distance * listener gain), APan (-1..1), ADoppler (pitch)
procedure AudioSpatialize(const AListener: TAudioListener; const ASource: TAudioSpatialParams; out AGain, APan, ADoppler: Single); inline;

implementation

uses Math;

function AudioVec3Create(AX, AY, AZ: Single): TAudioVec3; inline;
begin
  Result.X := AX; Result.Y := AY; Result.Z := AZ;
end;

function AudioVec3Zero: TAudioVec3; inline;
begin
  Result.X := 0; Result.Y := 0; Result.Z := 0;
end;

function AudioVec3Length(const A: TAudioVec3): Single; inline;
begin
  Result := Sqrt(A.X*A.X + A.Y*A.Y + A.Z*A.Z);
end;

function AudioVec3Distance(const A, B: TAudioVec3): Single; inline;
begin
  Result := Sqrt((A.X-B.X)*(A.X-B.X) + (A.Y-B.Y)*(A.Y-B.Y) + (A.Z-B.Z)*(A.Z-B.Z));
end;

function AudioVec3Dot(const A, B: TAudioVec3): Single; inline;
begin
  Result := A.X*B.X + A.Y*B.Y + A.Z*B.Z;
end;

function AudioVec3Normalize(const A: TAudioVec3): TAudioVec3; inline;
var L: Single;
begin
  L := AudioVec3Length(A);
  if L <= 1e-6 then Exit(AudioVec3Zero);
  Result.X := A.X / L; Result.Y := A.Y / L; Result.Z := A.Z / L;
end;

function AudioListenerDefault: TAudioListener; inline;
begin
  Result.Position := AudioVec3Zero;
  Result.Velocity := AudioVec3Zero;
  Result.Forward := AudioVec3Create(0, 0, -1);
  Result.Up := AudioVec3Create(0, 1, 0);
  Result.Gain := 1.0;
end;

function AudioSpatialParamsDefault: TAudioSpatialParams; inline;
begin
  Result.Position := AudioVec3Zero;
  Result.Velocity := AudioVec3Zero;
  Result.MinDistance := 1.0;
  Result.MaxDistance := 100.0;
  Result.Rolloff := 1.0;
  Result.DistanceModel := dmInverse;
  Result.DopplerFactor := 1.0;
  Result.ConeInnerAngle := 360;
  Result.ConeOuterAngle := 360;
  Result.ConeOuterGain := 0;
end;

function AudioComputeAttenuation(const AListener: TAudioListener; const ASource: TAudioSpatialParams): Single; inline;
var D, MinD, MaxD, R: Single;
begin
  D := AudioVec3Distance(AListener.Position, ASource.Position);
  MinD := ASource.MinDistance; MaxD := ASource.MaxDistance; R := ASource.Rolloff;
  if MinD < 0.001 then MinD := 0.001;
  if MaxD < MinD + 0.001 then MaxD := MinD + 0.001;
  if R < 0 then R := 0;
  if R > 4 then R := 4;
  if D <= MinD then Exit(1.0);
  if D >= MaxD then
  begin
    case ASource.DistanceModel of
      dmInverse: Result := MinD / (MinD + R*(MaxD - MinD));
      dmLinear: Result := 1.0 - R * (MaxD - MinD) / (MaxD - MinD);
      dmExponent: Result := Power(D / MinD, -R);
    else Result := MinD / (MinD + R*(D - MinD));
    end;
    if Result < 0 then Result := 0;
    Exit;
  end;
  case ASource.DistanceModel of
    dmInverse: Result := MinD / (MinD + R*(D - MinD));
    dmLinear: Result := 1.0 - R * (D - MinD) / (MaxD - MinD);
    dmExponent: Result := Power(D / MinD, -R);
  else Result := MinD / (MinD + R*(D - MinD));
  end;
  if Result < 0 then Result := 0 else if Result > 1 then Result := 1;
end;

function AudioComputePan(const AListener: TAudioListener; const ASourcePos: TAudioVec3): Single;
var LDir: TAudioVec3; LRight: TAudioVec3; LNorm: Single;
begin
  // right = forward × up (listener basis), pan = dot(dir, right)
  LDir.X := ASourcePos.X - AListener.Position.X;
  LDir.Y := ASourcePos.Y - AListener.Position.Y;
  LDir.Z := ASourcePos.Z - AListener.Position.Z;
  LNorm := AudioVec3Length(LDir);
  if LNorm < 1e-6 then Exit(0);
  LDir.X := LDir.X / LNorm; LDir.Y := LDir.Y / LNorm; LDir.Z := LDir.Z / LNorm;
  // right = cross(forward, up)
  LRight.X := AListener.Forward.Y * AListener.Up.Z - AListener.Forward.Z * AListener.Up.Y;
  LRight.Y := AListener.Forward.Z * AListener.Up.X - AListener.Forward.X * AListener.Up.Z;
  LRight.Z := AListener.Forward.X * AListener.Up.Y - AListener.Forward.Y * AListener.Up.X;
  LNorm := AudioVec3Length(LRight);
  if LNorm > 1e-6 then begin LRight.X := LRight.X / LNorm; LRight.Y := LRight.Y / LNorm; LRight.Z := LRight.Z / LNorm; end
  else begin LRight := AudioVec3Create(1,0,0); end;
  Result := AudioVec3Dot(LDir, LRight);
  if Result < -1 then Result := -1 else if Result > 1 then Result := 1;
end;

function AudioComputeDoppler(const AListener: TAudioListener; const ASource: TAudioSpatialParams): Single;
const CSound = 343.3; // m/s
var LDir: TAudioVec3; LNorm, Vls, Vss, Dop: Single;
begin
  if ASource.DopplerFactor <= 1e-6 then Exit(1.0);
  LDir.X := ASource.Position.X - AListener.Position.X;
  LDir.Y := ASource.Position.Y - AListener.Position.Y;
  LDir.Z := ASource.Position.Z - AListener.Position.Z;
  LNorm := AudioVec3Length(LDir);
  if LNorm < 1e-6 then Exit(1.0);
  LDir.X := LDir.X / LNorm; LDir.Y := LDir.Y / LNorm; LDir.Z := LDir.Z / LNorm;
  Vls := AudioVec3Dot(AListener.Velocity, LDir);
  Vss := AudioVec3Dot(ASource.Velocity, LDir);
  Dop := (CSound + Vls * ASource.DopplerFactor) / (CSound + Vss * ASource.DopplerFactor);
  if Dop < 0.25 then Dop := 0.25 else if Dop > 4.0 then Dop := 4.0;
  Result := Dop;
end;

procedure AudioSpatialize(const AListener: TAudioListener; const ASource: TAudioSpatialParams; out AGain, APan, ADoppler: Single); inline;
begin
  AGain := AudioComputeAttenuation(AListener, ASource) * AListener.Gain;
  APan := AudioComputePan(AListener, ASource.Position);
  ADoppler := AudioComputeDoppler(AListener, ASource);
end;

end.
