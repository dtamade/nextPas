unit nextpas.core.math.random;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.math.vec;

type
  TRandomState = record
    S0: UInt64;
    S1: UInt64;
  end;

  TRandomGen = class
  private
    FState: TRandomState;
    function NextUInt64: UInt64; inline;
  public
    constructor Create(const ASeed: UInt64 = 0);
    procedure SetSeed(const ASeed: UInt64);

    function NextInt: Integer; inline;
    function NextIntRange(const AMin, AMax: Integer): Integer;
    function NextFloat: Single; inline;
    function NextFloatRange(const AMin, AMax: Single): Single;
    function NextDouble: Double; inline;
    function NextBool(const AProbability: Single = 0.5): Boolean;
    function NextGaussian: Single;
    function NextVec2InCircle: TVec2f;
    function NextVec2OnCircle: TVec2f;
    function Roll(const ASides: Integer): Integer;
    function RollMultiple(const ADice, ASides: Integer): Integer;
    function WeightedChoice(const AWeights: array of Single): Integer;
    procedure Shuffle(var AValues: array of Integer);

    property State: TRandomState read FState write FState;
  end;

  TNoiseGen = class
  private
    FPerm: array[0..511] of Byte;
    class procedure ValidateFBMInputs(const AFunctionName: string; const AOctaves: Integer;
      const ALacunarity, AGain: Double); static;
    class procedure ValidateCoordinateInput(const AFunctionName, AParamName: string;
      const AValue: Double); static;
    class function ScaleOctaveCoordinate(const AFunctionName, AParamName: string;
      const AValue, AScale: Double): Double; static;
    function Fade(const AT: Double): Double; inline;
    function Lerp(const AT, AA, AB: Double): Double; inline;
    function Grad1D(const AHash: Integer; const AX: Double): Double; inline;
    function Grad2D(const AHash: Integer; const AX, AY: Double): Double; inline;
    function Grad3D(const AHash: Integer; const AX, AY, AZ: Double): Double; inline;
  public
    constructor Create(const ASeed: UInt64 = 0);
    procedure SetSeed(const ASeed: UInt64);

    function Noise1D(const AX: Double): Double;
    function Noise2D(const AX, AY: Double): Double;
    function Noise3D(const AX, AY, AZ: Double): Double;
    function FBM1D(const AX: Double; const AOctaves: Integer;
      const ALacunarity: Double = 2.0; const AGain: Double = 0.5): Double;
    function FBM2D(const AX, AY: Double; const AOctaves: Integer;
      const ALacunarity: Double = 2.0; const AGain: Double = 0.5): Double;
    function FBM3D(const AX, AY, AZ: Double; const AOctaves: Integer;
      const ALacunarity: Double = 2.0; const AGain: Double = 0.5): Double;
  end;

implementation

uses
  nextpas.core.errors,
  nextpas.core.math.scalar,
  nextpas.core.math.trig;

const
  DEFAULT_RANDOM_SEED: UInt64 = (UInt64($DEADBEEF) shl 32) or UInt64($CAFEBABE);
  SEED_SCRAMBLE: UInt64 = (UInt64($6A09E667) shl 32) or UInt64($F3BCC908);
  FLOAT_DENOMINATOR: Single = 16777216.0;
  DOUBLE_DENOMINATOR: Double = 9007199254740992.0;
  MAX_DOUBLE_MAGNITUDE: Double = 1.7976931348623157e308;

function IsFinite(const AValue: Single): Boolean; overload; inline;
begin
  Result := (not nextpas.core.math.scalar.IsNaN(AValue)) and
    (not nextpas.core.math.scalar.IsInfinite(AValue));
end;

function IsFinite(const AValue: Double): Boolean; overload; inline;
begin
  Result := (not nextpas.core.math.scalar.IsNaN(AValue)) and
    (not nextpas.core.math.scalar.IsInfinite(AValue));
end;

function NormalizeSeed(const ASeed: UInt64): UInt64; inline;
begin
  if ASeed = 0 then
    Result := DEFAULT_RANDOM_SEED
  else
    Result := ASeed;
end;

function FloorValue(const AValue: Double): Double; inline;
begin
  Result := System.Int(AValue);
  if (AValue < 0.0) and (AValue <> Result) then
    Result := Result - 1.0;
end;

function PermutationIndex(const AFloorValue: Double): Integer; inline;
var
  LWrapped: Double;
begin
  LWrapped := nextpas.core.math.scalar.Fmod(AFloorValue, 256.0);
  if LWrapped < 0.0 then
    LWrapped := LWrapped + 256.0;
  Result := Integer(nextpas.core.math.scalar.Round(LWrapped)) and 255;
end;

function TryScaleCoordinate(const AValue, AScale: Double; out AScaledValue: Double): Boolean; inline;
var
  LAbsValue: Double;
begin
  if AValue = 0.0 then
  begin
    AScaledValue := 0.0;
    Exit(True);
  end;

  LAbsValue := nextpas.core.math.scalar.Abs(AValue);
  if LAbsValue > (MAX_DOUBLE_MAGNITUDE / AScale) then
    Exit(False);

  AScaledValue := AValue * AScale;
  Result := IsFinite(AScaledValue);
end;

{ TRandomGen }

constructor TRandomGen.Create(const ASeed: UInt64);
begin
  inherited Create;
  SetSeed(ASeed);
end;

procedure TRandomGen.SetSeed(const ASeed: UInt64);
var
  LSeed: UInt64;
begin
  LSeed := NormalizeSeed(ASeed);
  FState.S0 := LSeed;
  FState.S1 := LSeed xor SEED_SCRAMBLE;
  NextUInt64;
  NextUInt64;
end;

function TRandomGen.NextUInt64: UInt64;
var
  LS0: UInt64;
  LS1: UInt64;
begin
  LS0 := FState.S0;
  LS1 := FState.S1;
  Result := LS0 + LS1;
  LS1 := LS1 xor LS0;
  FState.S0 := ((LS0 shl 24) or (LS0 shr 40)) xor LS1 xor (LS1 shl 16);
  FState.S1 := (LS1 shl 37) or (LS1 shr 27);
end;

function TRandomGen.NextInt: Integer;
begin
  Result := Integer(NextUInt64 shr 33);
end;

function TRandomGen.NextIntRange(const AMin, AMax: Integer): Integer;
var
  LRange: UInt64;
  LOffset: Int64;
begin
  if AMin > AMax then
    raise EArgumentError.Create('TRandomGen.NextIntRange: AMin must be <= AMax');
  if AMin = AMax then
    Exit(AMin);

  LRange := UInt64(Int64(AMax) - Int64(AMin)) + UInt64(1);
  LOffset := Int64(NextUInt64 mod LRange);
  Result := Integer(Int64(AMin) + LOffset);
end;

function TRandomGen.NextFloat: Single;
begin
  Result := (NextUInt64 shr 40) / FLOAT_DENOMINATOR;
end;

function TRandomGen.NextFloatRange(const AMin, AMax: Single): Single;
begin
  if not IsFinite(AMin) then
    raise EArgumentError.Create('TRandomGen.NextFloatRange: AMin must be finite');
  if not IsFinite(AMax) then
    raise EArgumentError.Create('TRandomGen.NextFloatRange: AMax must be finite');
  if AMin > AMax then
    raise EArgumentError.Create('TRandomGen.NextFloatRange: AMin must be <= AMax');
  if AMin = AMax then
    Exit(AMin);
  Result := Single(Double(AMin) + Double(NextFloat) * (Double(AMax) - Double(AMin)));
end;

function TRandomGen.NextDouble: Double;
begin
  Result := (NextUInt64 shr 11) / DOUBLE_DENOMINATOR;
end;

function TRandomGen.NextBool(const AProbability: Single): Boolean;
begin
  if not IsFinite(AProbability) then
    raise EArgumentError.Create('TRandomGen.NextBool: AProbability must be finite');
  if AProbability <= 0.0 then
    Exit(False);
  if AProbability >= 1.0 then
    Exit(True);
  Result := NextFloat < AProbability;
end;

function TRandomGen.NextGaussian: Single;
var
  LU1: Single;
  LU2: Single;
begin
  LU1 := NextFloat;
  if LU1 < 1e-10 then
    LU1 := 1e-10;
  LU2 := NextFloat;
  Result := nextpas.core.math.trig.Sqrt(Single(-2.0) * nextpas.core.math.trig.Ln(LU1)) *
    nextpas.core.math.trig.Cos(Single(2.0 * PI_VALUE) * LU2);
end;

function TRandomGen.NextVec2InCircle: TVec2f;
var
  LAngle: Single;
  LRadius: Single;
begin
  LAngle := NextFloat * Single(2.0 * PI_VALUE);
  LRadius := nextpas.core.math.trig.Sqrt(NextFloat);
  Result := TVec2f.Create(
    nextpas.core.math.trig.Cos(LAngle) * LRadius,
    nextpas.core.math.trig.Sin(LAngle) * LRadius);
end;

function TRandomGen.NextVec2OnCircle: TVec2f;
var
  LAngle: Single;
begin
  LAngle := NextFloat * Single(2.0 * PI_VALUE);
  Result := TVec2f.Create(
    nextpas.core.math.trig.Cos(LAngle),
    nextpas.core.math.trig.Sin(LAngle));
end;

function TRandomGen.Roll(const ASides: Integer): Integer;
begin
  if ASides <= 0 then
    Exit(0);
  Result := NextIntRange(1, ASides);
end;

function TRandomGen.RollMultiple(const ADice, ASides: Integer): Integer;
var
  I: Integer;
begin
  Result := 0;
  if (ADice <= 0) or (ASides <= 0) then
    Exit;
  for I := 1 to ADice do
    Inc(Result, Roll(ASides));
end;

function TRandomGen.WeightedChoice(const AWeights: array of Single): Integer;
var
  LTotal: Double;
  LPick: Double;
  LAccumulated: Double;
  I: Integer;
begin
  if Length(AWeights) = 0 then
    raise EArgumentError.Create('TRandomGen.WeightedChoice: weights must not be empty');

  LTotal := 0.0;
  for I := 0 to High(AWeights) do
  begin
    if not IsFinite(AWeights[I]) then
      raise EArgumentError.Create('TRandomGen.WeightedChoice: weights must be finite');
    if AWeights[I] < 0.0 then
      raise EArgumentError.Create('TRandomGen.WeightedChoice: weights must be non-negative');
    LTotal := LTotal + Double(AWeights[I]);
  end;

  if LTotal <= 0.0 then
    raise EArgumentError.Create('TRandomGen.WeightedChoice: at least one weight must be positive');

  LPick := NextFloat * LTotal;
  LAccumulated := 0.0;
  for I := 0 to High(AWeights) do
  begin
    LAccumulated := LAccumulated + Double(AWeights[I]);
    if LPick < LAccumulated then
      Exit(I);
  end;
  Result := High(AWeights);
end;

procedure TRandomGen.Shuffle(var AValues: array of Integer);
var
  I: Integer;
  J: Integer;
  LTemp: Integer;
begin
  for I := High(AValues) downto 1 do
  begin
    J := NextIntRange(0, I);
    LTemp := AValues[I];
    AValues[I] := AValues[J];
    AValues[J] := LTemp;
  end;
end;

{ TNoiseGen }

constructor TNoiseGen.Create(const ASeed: UInt64);
begin
  inherited Create;
  SetSeed(ASeed);
end;

class procedure TNoiseGen.ValidateFBMInputs(const AFunctionName: string; const AOctaves: Integer;
  const ALacunarity, AGain: Double);
begin
  if AOctaves <= 0 then
    raise EArgumentError.Create(AFunctionName + ': AOctaves must be positive');
  if (ALacunarity <= 0.0) or (not IsFinite(ALacunarity)) then
    raise EArgumentError.Create(AFunctionName + ': ALacunarity must be positive');
  if (AGain <= 0.0) or (not IsFinite(AGain)) then
    raise EArgumentError.Create(AFunctionName + ': AGain must be positive');
end;

class procedure TNoiseGen.ValidateCoordinateInput(const AFunctionName, AParamName: string;
  const AValue: Double);
begin
  if not IsFinite(AValue) then
    raise EArgumentError.Create(AFunctionName + ': ' + AParamName + ' must be finite');
end;

class function TNoiseGen.ScaleOctaveCoordinate(const AFunctionName, AParamName: string;
  const AValue, AScale: Double): Double;
begin
  if not TryScaleCoordinate(AValue, AScale, Result) then
    raise EArgumentError.Create(AFunctionName + ': octave ' + AParamName + ' must be finite');
end;

procedure TNoiseGen.SetSeed(const ASeed: UInt64);
var
  LRng: TRandomGen;
  I: Integer;
  J: Integer;
  LTemp: Byte;
begin
  LRng := TRandomGen.Create(ASeed);
  try
    for I := 0 to 255 do
      FPerm[I] := Byte(I);
    for I := 255 downto 1 do
    begin
      J := LRng.NextIntRange(0, I);
      LTemp := FPerm[I];
      FPerm[I] := FPerm[J];
      FPerm[J] := LTemp;
    end;
    for I := 0 to 255 do
      FPerm[256 + I] := FPerm[I];
  finally
    LRng.Free;
  end;
end;

function TNoiseGen.Fade(const AT: Double): Double;
begin
  Result := AT * AT * AT * (AT * (AT * 6.0 - 15.0) + 10.0);
end;

function TNoiseGen.Lerp(const AT, AA, AB: Double): Double;
begin
  Result := AA + AT * (AB - AA);
end;

function TNoiseGen.Grad1D(const AHash: Integer; const AX: Double): Double;
begin
  if (AHash and 1) = 0 then
    Result := AX
  else
    Result := -AX;
end;

function TNoiseGen.Grad2D(const AHash: Integer; const AX, AY: Double): Double;
begin
  case AHash and 3 of
    0: Result := AX + AY;
    1: Result := -AX + AY;
    2: Result := AX - AY;
  else
    Result := -AX - AY;
  end;
end;

function TNoiseGen.Grad3D(const AHash: Integer; const AX, AY, AZ: Double): Double;
var
  LH: Integer;
  LU: Double;
  LV: Double;
begin
  LH := AHash and 15;
  if LH < 8 then
    LU := AX
  else
    LU := AY;

  if LH < 4 then
    LV := AY
  else if (LH = 12) or (LH = 14) then
    LV := AX
  else
    LV := AZ;

  if (LH and 1) = 0 then
    Result := LU
  else
    Result := -LU;
  if (LH and 2) = 0 then
    Result := Result + LV
  else
    Result := Result - LV;
end;

function TNoiseGen.Noise1D(const AX: Double): Double;
var
  LXi: Integer;
  LFloorX: Double;
  LXf: Double;
  LU: Double;
begin
  ValidateCoordinateInput('TNoiseGen.Noise1D', 'AX', AX);
  LFloorX := FloorValue(AX);
  LXi := PermutationIndex(LFloorX);
  LXf := AX - LFloorX;
  LU := Fade(LXf);
  Result := Lerp(LU,
    Grad1D(FPerm[LXi], LXf),
    Grad1D(FPerm[LXi + 1], LXf - 1.0));
end;

function TNoiseGen.Noise2D(const AX, AY: Double): Double;
var
  LXi: Integer;
  LYi: Integer;
  LFloorX: Double;
  LFloorY: Double;
  LXf: Double;
  LYf: Double;
  LU: Double;
  LV: Double;
  LAA: Integer;
  LAB: Integer;
  LBA: Integer;
  LBB: Integer;
begin
  ValidateCoordinateInput('TNoiseGen.Noise2D', 'AX', AX);
  ValidateCoordinateInput('TNoiseGen.Noise2D', 'AY', AY);
  LFloorX := FloorValue(AX);
  LFloorY := FloorValue(AY);
  LXi := PermutationIndex(LFloorX);
  LYi := PermutationIndex(LFloorY);
  LXf := AX - LFloorX;
  LYf := AY - LFloorY;
  LU := Fade(LXf);
  LV := Fade(LYf);

  LAA := FPerm[FPerm[LXi] + LYi];
  LAB := FPerm[FPerm[LXi] + LYi + 1];
  LBA := FPerm[FPerm[LXi + 1] + LYi];
  LBB := FPerm[FPerm[LXi + 1] + LYi + 1];

  Result := Lerp(LV,
    Lerp(LU, Grad2D(LAA, LXf, LYf), Grad2D(LBA, LXf - 1.0, LYf)),
    Lerp(LU, Grad2D(LAB, LXf, LYf - 1.0), Grad2D(LBB, LXf - 1.0, LYf - 1.0)));
end;

function TNoiseGen.Noise3D(const AX, AY, AZ: Double): Double;
var
  LXi: Integer;
  LYi: Integer;
  LZi: Integer;
  LFloorX: Double;
  LFloorY: Double;
  LFloorZ: Double;
  LXf: Double;
  LYf: Double;
  LZf: Double;
  LU: Double;
  LV: Double;
  LW: Double;
  LA: Integer;
  LB: Integer;
  LAA: Integer;
  LAB: Integer;
  LBA: Integer;
  LBB: Integer;
begin
  ValidateCoordinateInput('TNoiseGen.Noise3D', 'AX', AX);
  ValidateCoordinateInput('TNoiseGen.Noise3D', 'AY', AY);
  ValidateCoordinateInput('TNoiseGen.Noise3D', 'AZ', AZ);
  LFloorX := FloorValue(AX);
  LFloorY := FloorValue(AY);
  LFloorZ := FloorValue(AZ);
  LXi := PermutationIndex(LFloorX);
  LYi := PermutationIndex(LFloorY);
  LZi := PermutationIndex(LFloorZ);
  LXf := AX - LFloorX;
  LYf := AY - LFloorY;
  LZf := AZ - LFloorZ;
  LU := Fade(LXf);
  LV := Fade(LYf);
  LW := Fade(LZf);

  LA := FPerm[LXi] + LYi;
  LB := FPerm[LXi + 1] + LYi;
  LAA := FPerm[LA] + LZi;
  LAB := FPerm[LA + 1] + LZi;
  LBA := FPerm[LB] + LZi;
  LBB := FPerm[LB + 1] + LZi;

  Result := Lerp(LW,
    Lerp(LV,
      Lerp(LU, Grad3D(FPerm[LAA], LXf, LYf, LZf),
        Grad3D(FPerm[LBA], LXf - 1.0, LYf, LZf)),
      Lerp(LU, Grad3D(FPerm[LAB], LXf, LYf - 1.0, LZf),
        Grad3D(FPerm[LBB], LXf - 1.0, LYf - 1.0, LZf))),
    Lerp(LV,
      Lerp(LU, Grad3D(FPerm[LAA + 1], LXf, LYf, LZf - 1.0),
        Grad3D(FPerm[LBA + 1], LXf - 1.0, LYf, LZf - 1.0)),
      Lerp(LU, Grad3D(FPerm[LAB + 1], LXf, LYf - 1.0, LZf - 1.0),
        Grad3D(FPerm[LBB + 1], LXf - 1.0, LYf - 1.0, LZf - 1.0))));
end;

function TNoiseGen.FBM1D(const AX: Double; const AOctaves: Integer;
  const ALacunarity: Double; const AGain: Double): Double;
var
  I: Integer;
  LAmp: Double;
  LCoordX: Double;
begin
  ValidateFBMInputs('TNoiseGen.FBM1D', AOctaves, ALacunarity, AGain);
  ValidateCoordinateInput('TNoiseGen.FBM1D', 'AX', AX);
  Result := 0.0;
  LAmp := 1.0;
  LCoordX := AX;
  for I := 0 to AOctaves - 1 do
  begin
    Result := Result + LAmp * Noise1D(LCoordX);
    if I < AOctaves - 1 then
    begin
      LCoordX := ScaleOctaveCoordinate('TNoiseGen.FBM1D', 'AX', LCoordX, ALacunarity);
      LAmp := LAmp * AGain;
    end;
  end;
end;

function TNoiseGen.FBM2D(const AX, AY: Double; const AOctaves: Integer;
  const ALacunarity: Double; const AGain: Double): Double;
var
  I: Integer;
  LAmp: Double;
  LCoordX: Double;
  LCoordY: Double;
begin
  ValidateFBMInputs('TNoiseGen.FBM2D', AOctaves, ALacunarity, AGain);
  ValidateCoordinateInput('TNoiseGen.FBM2D', 'AX', AX);
  ValidateCoordinateInput('TNoiseGen.FBM2D', 'AY', AY);
  Result := 0.0;
  LAmp := 1.0;
  LCoordX := AX;
  LCoordY := AY;
  for I := 0 to AOctaves - 1 do
  begin
    Result := Result + LAmp * Noise2D(LCoordX, LCoordY);
    if I < AOctaves - 1 then
    begin
      LCoordX := ScaleOctaveCoordinate('TNoiseGen.FBM2D', 'AX', LCoordX, ALacunarity);
      LCoordY := ScaleOctaveCoordinate('TNoiseGen.FBM2D', 'AY', LCoordY, ALacunarity);
      LAmp := LAmp * AGain;
    end;
  end;
end;

function TNoiseGen.FBM3D(const AX, AY, AZ: Double; const AOctaves: Integer;
  const ALacunarity: Double; const AGain: Double): Double;
var
  I: Integer;
  LAmp: Double;
  LCoordX: Double;
  LCoordY: Double;
  LCoordZ: Double;
begin
  ValidateFBMInputs('TNoiseGen.FBM3D', AOctaves, ALacunarity, AGain);
  ValidateCoordinateInput('TNoiseGen.FBM3D', 'AX', AX);
  ValidateCoordinateInput('TNoiseGen.FBM3D', 'AY', AY);
  ValidateCoordinateInput('TNoiseGen.FBM3D', 'AZ', AZ);
  Result := 0.0;
  LAmp := 1.0;
  LCoordX := AX;
  LCoordY := AY;
  LCoordZ := AZ;
  for I := 0 to AOctaves - 1 do
  begin
    Result := Result + LAmp * Noise3D(LCoordX, LCoordY, LCoordZ);
    if I < AOctaves - 1 then
    begin
      LCoordX := ScaleOctaveCoordinate('TNoiseGen.FBM3D', 'AX', LCoordX, ALacunarity);
      LCoordY := ScaleOctaveCoordinate('TNoiseGen.FBM3D', 'AY', LCoordY, ALacunarity);
      LCoordZ := ScaleOctaveCoordinate('TNoiseGen.FBM3D', 'AZ', LCoordZ, ALacunarity);
      LAmp := LAmp * AGain;
    end;
  end;
end;

end.
