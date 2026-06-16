{
  nextpas.core.math.random.pas
  Deterministic random number generator
}
unit nextpas.core.math.random;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.math.base,
  nextpas.core.math.scalar,
  nextpas.core.math.trig;

type
  { TRandomState - deterministic PRNG state (LCG-based xorshift) }
  TRandomState = record
    FSeed: UInt64;
  end;

{ === Initialization === }

{** Create a new random state seeded with the given value }
function RandomCreate(ASeed: UInt64): TRandomState;

{ === Integer Random === }

{** Return a pseudo-random UInt64 value }
function RandomInt(var AState: TRandomState): UInt64;
{** Return a pseudo-random Int64 in the range [AMin, AMax] }
function RandomIntRange(var AState: TRandomState; AMin, AMax: Int64): Int64;
{** Return a pseudo-random Boolean }
function RandomBool(var AState: TRandomState): Boolean;

{ === Float Random === }

{** Return a pseudo-random Single in [0, 1) }
function RandomFloat(var AState: TRandomState): Single;
{** Return a pseudo-random Single in [0, AMax) }
function RandomFloat(var AState: TRandomState; AMax: Single): Single;
{** Return a pseudo-random Single in [AMin, AMax) }
function RandomFloatRange(var AState: TRandomState; AMin, AMax: Single): Single;
{** Return a pseudo-random Double in [0, 1) }
function RandomDouble(var AState: TRandomState): Double;
{** Return a pseudo-random Double in [0, AMax) }
function RandomDouble(var AState: TRandomState; AMax: Double): Double;
{** Return a pseudo-random Double in [AMin, AMax) }
function RandomDoubleRange(var AState: TRandomState; AMin, AMax: Double): Double;

{ === Vector Random === }

{** Return a random point on the unit circle (2D) }
function RandomPointOnCircle(var AState: TRandomState): TPoint2f;
{** Return a random point on the unit sphere (3D, uniform distribution) }
function RandomPointOnSphere(var AState: TRandomState): TPoint3f;

{ === Distribution === }

{** Return a standard normal (Gaussian) random value via Box-Muller transform }
function RandomGaussian(var AState: TRandomState): Double;

{ === Utility === }

{** Return a random integer in [0, ACount) }
function RandomChoice(var AState: TRandomState; ACount: Integer): Integer;
{** Return a weighted random index; probability proportional to AWeights }
function RandomWeightedChoice(var AState: TRandomState; const AWeights: array of Single): Integer;

implementation

const
  LCG_MULTIPLIER: UInt64 = 6364136223846793005;
  LCG_INCREMENT: UInt64 = 1442695040888963407;

{ === Initialization === }

function RandomCreate(ASeed: UInt64): TRandomState;
begin
  Result.FSeed := ASeed;
end;

{ === Integer Random === }

function RandomInt(var AState: TRandomState): UInt64;
begin
  AState.FSeed := AState.FSeed * LCG_MULTIPLIER + LCG_INCREMENT;
  Result := AState.FSeed shr 33;
end;

function RandomIntRange(var AState: TRandomState; AMin, AMax: Int64): Int64;
var
  LRange: UInt64;
begin
  if AMin > AMax then
  begin
    Result := AMin;
    Exit;
  end;
  LRange := UInt64(AMax - AMin + 1);
  Result := AMin + Int64(RandomInt(AState) mod LRange);
end;

function RandomBool(var AState: TRandomState): Boolean;
begin
  Result := (RandomInt(AState) and 1) = 0;
end;

{ === Float Random === }

function RandomFloat(var AState: TRandomState): Single;
begin
  Result := Single(RandomInt(AState)) / Single(High(UInt64) shr 33);
end;

function RandomFloat(var AState: TRandomState; AMax: Single): Single;
begin
  Result := RandomFloat(AState) * AMax;
end;

function RandomFloatRange(var AState: TRandomState; AMin, AMax: Single): Single;
begin
  Result := AMin + RandomFloat(AState) * (AMax - AMin);
end;

function RandomDouble(var AState: TRandomState): Double;
begin
  Result := Double(RandomInt(AState)) / Double(High(UInt64) shr 33);
end;

function RandomDouble(var AState: TRandomState; AMax: Double): Double;
begin
  Result := RandomDouble(AState) * AMax;
end;

function RandomDoubleRange(var AState: TRandomState; AMin, AMax: Double): Double;
begin
  Result := AMin + RandomDouble(AState) * (AMax - AMin);
end;

{ === Vector Random === }

function RandomPointOnCircle(var AState: TRandomState): TPoint2f;
var
  LAngle: Single;
begin
  LAngle := RandomFloat(AState) * TWO_PI;
  Result.X := Cos(LAngle);
  Result.Y := Sin(LAngle);
end;

function RandomPointOnSphere(var AState: TRandomState): TPoint3f;
var
  LTheta, LPhi, LSinTheta: Single;
begin
  LTheta := ArcCos(2.0 * RandomFloat(AState) - 1.0);
  LPhi := RandomFloat(AState) * TWO_PI;
  LSinTheta := Sin(LTheta);
  Result.X := LSinTheta * Cos(LPhi);
  Result.Y := LSinTheta * Sin(LPhi);
  Result.Z := Cos(LTheta);
end;

{ === Distribution === }

function RandomGaussian(var AState: TRandomState): Double;
var
  LU1, LU2: Double;
begin
  // Box-Muller transform
  LU1 := RandomDouble(AState);
  LU2 := RandomDouble(AState);
  if LU1 < 1e-10 then
    LU1 := 1e-10;
  Result := Sqrt(-2.0 * Ln(LU1)) * Cos(TWO_PI * LU2);
end;

{ === Utility === }

function RandomChoice(var AState: TRandomState; ACount: Integer): Integer;
begin
  if ACount <= 0 then
    Result := 0
  else
    Result := Integer(RandomInt(AState) mod UInt64(ACount));
end;

function RandomWeightedChoice(var AState: TRandomState; const AWeights: array of Single): Integer;
var
  LTotal, LTarget, LCumulative: Single;
  I: Integer;
begin
  LTotal := 0.0;
  for I := Low(AWeights) to High(AWeights) do
    LTotal := LTotal + AWeights[I];

  if LTotal <= 0.0 then
  begin
    Result := Low(AWeights);
    Exit;
  end;

  LTarget := RandomFloat(AState) * LTotal;
  LCumulative := 0.0;
  for I := Low(AWeights) to High(AWeights) do
  begin
    LCumulative := LCumulative + AWeights[I];
    if LTarget <= LCumulative then
    begin
      Result := I;
      Exit;
    end;
  end;
  Result := High(AWeights);
end;

end.
