unit nextpas.core.math.vec;

{$I nextpas.core.settings.inc}

interface

type
  TVec2f = packed record
  public
    type
      TIndex = 0..1;
    class function Create(const AX, AY: Single): TVec2f; static; inline;
    class function Zero: TVec2f; static; inline;
    class operator + (const AA, AB: TVec2f): TVec2f; inline;
    class operator - (const AA, AB: TVec2f): TVec2f; inline;
    class operator - (const AValue: TVec2f): TVec2f; inline;
    class operator * (const AValue: TVec2f; const AScalar: Single): TVec2f; inline;
    class operator * (const AScalar: Single; const AValue: TVec2f): TVec2f; inline;
    class operator / (const AValue: TVec2f; const AScalar: Single): TVec2f; inline;
    class function MulComponents(const AA, AB: TVec2f): TVec2f; static; inline;
    class function DivComponents(const AA, AB: TVec2f): TVec2f; static; inline;
    class function Dot(const AA, AB: TVec2f): Single; static; inline;
    class function Lerp(const AA, AB: TVec2f; const AT: Single): TVec2f; static; inline;
    class function Equals(const AA, AB: TVec2f; const AEpsilon: Single): Boolean; static; inline;
    function LengthSqr: Single; inline;
    function Length: Single; inline;
    function Normalize: TVec2f; inline;
    var
      case Integer of
        0: (X, Y: Single);
        1: (Data: array[TIndex] of Single);
  end;

  TVec3f = packed record
  public
    type
      TIndex = 0..2;
    class function Create(const AX, AY, AZ: Single): TVec3f; static; inline;
    class function Zero: TVec3f; static; inline;
    class operator + (const AA, AB: TVec3f): TVec3f; inline;
    class operator - (const AA, AB: TVec3f): TVec3f; inline;
    class operator - (const AValue: TVec3f): TVec3f; inline;
    class operator * (const AValue: TVec3f; const AScalar: Single): TVec3f; inline;
    class operator * (const AScalar: Single; const AValue: TVec3f): TVec3f; inline;
    class operator / (const AValue: TVec3f; const AScalar: Single): TVec3f; inline;
    class function MulComponents(const AA, AB: TVec3f): TVec3f; static; inline;
    class function DivComponents(const AA, AB: TVec3f): TVec3f; static; inline;
    class function Dot(const AA, AB: TVec3f): Single; static; inline;
    class function Cross(const AA, AB: TVec3f): TVec3f; static; inline;
    class function Lerp(const AA, AB: TVec3f; const AT: Single): TVec3f; static; inline;
    class function Equals(const AA, AB: TVec3f; const AEpsilon: Single): Boolean; static; inline;
    function LengthSqr: Single; inline;
    function Length: Single; inline;
    function Normalize: TVec3f; inline;
    var
      case Integer of
        0: (X, Y, Z: Single);
        1: (Data: array[TIndex] of Single);
  end;

  TVec4f = packed record
  public
    type
      TIndex = 0..3;
    class function Create(const AX, AY, AZ, AW: Single): TVec4f; static; inline;
    class function Zero: TVec4f; static; inline;
    class operator + (const AA, AB: TVec4f): TVec4f; inline;
    class operator - (const AA, AB: TVec4f): TVec4f; inline;
    class operator - (const AValue: TVec4f): TVec4f; inline;
    class operator * (const AValue: TVec4f; const AScalar: Single): TVec4f; inline;
    class operator * (const AScalar: Single; const AValue: TVec4f): TVec4f; inline;
    class operator / (const AValue: TVec4f; const AScalar: Single): TVec4f; inline;
    class function MulComponents(const AA, AB: TVec4f): TVec4f; static; inline;
    class function DivComponents(const AA, AB: TVec4f): TVec4f; static; inline;
    class function Dot(const AA, AB: TVec4f): Single; static; inline;
    class function Lerp(const AA, AB: TVec4f; const AT: Single): TVec4f; static; inline;
    class function Equals(const AA, AB: TVec4f; const AEpsilon: Single): Boolean; static; inline;
    function LengthSqr: Single; inline;
    function Length: Single; inline;
    function Normalize: TVec4f; inline;
    var
      case Integer of
        0: (X, Y, Z, W: Single);
        1: (Data: array[TIndex] of Single);
  end;

  TVec2d = packed record
  public
    type
      TIndex = 0..1;
    class function Create(const AX, AY: Double): TVec2d; static; inline;
    class function Zero: TVec2d; static; inline;
    class operator + (const AA, AB: TVec2d): TVec2d; inline;
    class operator - (const AA, AB: TVec2d): TVec2d; inline;
    class operator - (const AValue: TVec2d): TVec2d; inline;
    class operator * (const AValue: TVec2d; const AScalar: Double): TVec2d; inline;
    class operator * (const AScalar: Double; const AValue: TVec2d): TVec2d; inline;
    class operator / (const AValue: TVec2d; const AScalar: Double): TVec2d; inline;
    class function MulComponents(const AA, AB: TVec2d): TVec2d; static; inline;
    class function DivComponents(const AA, AB: TVec2d): TVec2d; static; inline;
    class function Dot(const AA, AB: TVec2d): Double; static; inline;
    class function Lerp(const AA, AB: TVec2d; const AT: Double): TVec2d; static; inline;
    class function Equals(const AA, AB: TVec2d; const AEpsilon: Double): Boolean; static; inline;
    function LengthSqr: Double; inline;
    function Length: Double; inline;
    function Normalize: TVec2d; inline;
    var
      case Integer of
        0: (X, Y: Double);
        1: (Data: array[TIndex] of Double);
  end;

  TVec3d = packed record
  public
    type
      TIndex = 0..2;
    class function Create(const AX, AY, AZ: Double): TVec3d; static; inline;
    class function Zero: TVec3d; static; inline;
    class operator + (const AA, AB: TVec3d): TVec3d; inline;
    class operator - (const AA, AB: TVec3d): TVec3d; inline;
    class operator - (const AValue: TVec3d): TVec3d; inline;
    class operator * (const AValue: TVec3d; const AScalar: Double): TVec3d; inline;
    class operator * (const AScalar: Double; const AValue: TVec3d): TVec3d; inline;
    class operator / (const AValue: TVec3d; const AScalar: Double): TVec3d; inline;
    class function MulComponents(const AA, AB: TVec3d): TVec3d; static; inline;
    class function DivComponents(const AA, AB: TVec3d): TVec3d; static; inline;
    class function Dot(const AA, AB: TVec3d): Double; static; inline;
    class function Cross(const AA, AB: TVec3d): TVec3d; static; inline;
    class function Lerp(const AA, AB: TVec3d; const AT: Double): TVec3d; static; inline;
    class function Equals(const AA, AB: TVec3d; const AEpsilon: Double): Boolean; static; inline;
    function LengthSqr: Double; inline;
    function Length: Double; inline;
    function Normalize: TVec3d; inline;
    var
      case Integer of
        0: (X, Y, Z: Double);
        1: (Data: array[TIndex] of Double);
  end;

  TVec4d = packed record
  public
    type
      TIndex = 0..3;
    class function Create(const AX, AY, AZ, AW: Double): TVec4d; static; inline;
    class function Zero: TVec4d; static; inline;
    class operator + (const AA, AB: TVec4d): TVec4d; inline;
    class operator - (const AA, AB: TVec4d): TVec4d; inline;
    class operator - (const AValue: TVec4d): TVec4d; inline;
    class operator * (const AValue: TVec4d; const AScalar: Double): TVec4d; inline;
    class operator * (const AScalar: Double; const AValue: TVec4d): TVec4d; inline;
    class operator / (const AValue: TVec4d; const AScalar: Double): TVec4d; inline;
    class function MulComponents(const AA, AB: TVec4d): TVec4d; static; inline;
    class function DivComponents(const AA, AB: TVec4d): TVec4d; static; inline;
    class function Dot(const AA, AB: TVec4d): Double; static; inline;
    class function Lerp(const AA, AB: TVec4d; const AT: Double): TVec4d; static; inline;
    class function Equals(const AA, AB: TVec4d; const AEpsilon: Double): Boolean; static; inline;
    function LengthSqr: Double; inline;
    function Length: Double; inline;
    function Normalize: TVec4d; inline;
    var
      case Integer of
        0: (X, Y, Z, W: Double);
        1: (Data: array[TIndex] of Double);
  end;

implementation

uses
  nextpas.core.errors,
  nextpas.core.math.scalar;

const
  MAX_SINGLE_VALUE: Double = 3.40282346638528859812e38;
  MAX_DOUBLE_VALUE: Double = 1.79769313486231570815e308;
  LN_MAX_DOUBLE_VALUE: Double = 709.78271289338397310;

type
  TSingleBitCast = packed record
    case Integer of
      0: (Value: Single);
      1: (Bits: UInt32);
  end;

  TDoubleBitCast = packed record
    case Integer of
      0: (Value: Double);
      1: (Bits: UInt64);
  end;

function SingleSignedInfinity(const ANegative: Boolean): Single; inline;
var
  LValue: TSingleBitCast;
begin
  if ANegative then
    LValue.Bits := UInt32($FF800000)
  else
    LValue.Bits := UInt32($7F800000);
  Result := LValue.Value;
end;

function SinglePositiveInfinity: Single; inline;
begin
  Result := SingleSignedInfinity(False);
end;

function DoubleSignedInfinity(const ANegative: Boolean): Double; inline;
var
  LValue: TDoubleBitCast;
begin
  if ANegative then
    LValue.Bits := UInt64($FFF0000000000000)
  else
    LValue.Bits := UInt64($7FF0000000000000);
  Result := LValue.Value;
end;

function DoublePositiveInfinity: Double; inline;
begin
  Result := DoubleSignedInfinity(False);
end;

function SingleEquals(const AA, AB, AEpsilon: Single): Boolean; inline;
begin
  Result := (AEpsilon >= 0.0) and nextpas.core.math.scalar.FloatEquals(AA, AB, AEpsilon);
end;

function DoubleEquals(const AA, AB, AEpsilon: Double): Boolean; inline;
begin
  Result := (AEpsilon >= 0.0) and nextpas.core.math.scalar.FloatEquals(AA, AB, AEpsilon);
end;

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

function IsFinite(const AValue: TVec2f): Boolean; overload; inline;
begin
  Result := IsFinite(AValue.X) and IsFinite(AValue.Y);
end;

function IsFinite(const AValue: TVec3f): Boolean; overload; inline;
begin
  Result := IsFinite(AValue.X) and IsFinite(AValue.Y) and IsFinite(AValue.Z);
end;

function IsFinite(const AValue: TVec4f): Boolean; overload; inline;
begin
  Result := IsFinite(AValue.X) and IsFinite(AValue.Y) and
    IsFinite(AValue.Z) and IsFinite(AValue.W);
end;

function IsFinite(const AValue: TVec2d): Boolean; overload; inline;
begin
  Result := IsFinite(AValue.X) and IsFinite(AValue.Y);
end;

function IsFinite(const AValue: TVec3d): Boolean; overload; inline;
begin
  Result := IsFinite(AValue.X) and IsFinite(AValue.Y) and IsFinite(AValue.Z);
end;

function IsFinite(const AValue: TVec4d): Boolean; overload; inline;
begin
  Result := IsFinite(AValue.X) and IsFinite(AValue.Y) and
    IsFinite(AValue.Z) and IsFinite(AValue.W);
end;

procedure ValidateVectorInput(const AFunctionName: string; const AValue: TVec2f); overload; inline;
begin
  if not IsFinite(AValue) then
    raise EArgumentError.Create(AFunctionName + ': vector must be finite');
end;

procedure ValidateVectorInput(const AFunctionName: string; const AValue: TVec3f); overload; inline;
begin
  if not IsFinite(AValue) then
    raise EArgumentError.Create(AFunctionName + ': vector must be finite');
end;

procedure ValidateVectorInput(const AFunctionName: string; const AValue: TVec4f); overload; inline;
begin
  if not IsFinite(AValue) then
    raise EArgumentError.Create(AFunctionName + ': vector must be finite');
end;

procedure ValidateVectorInput(const AFunctionName: string; const AValue: TVec2d); overload; inline;
begin
  if not IsFinite(AValue) then
    raise EArgumentError.Create(AFunctionName + ': vector must be finite');
end;

procedure ValidateVectorInput(const AFunctionName: string; const AValue: TVec3d); overload; inline;
begin
  if not IsFinite(AValue) then
    raise EArgumentError.Create(AFunctionName + ': vector must be finite');
end;

procedure ValidateVectorInput(const AFunctionName: string; const AValue: TVec4d); overload; inline;
begin
  if not IsFinite(AValue) then
    raise EArgumentError.Create(AFunctionName + ': vector must be finite');
end;

procedure ValidateScalarDivisor(const AFunctionName: string; const AValue: Single); overload; inline;
begin
  if not IsFinite(AValue) then
    raise EArgumentError.Create(AFunctionName + ': scalar divisor must be finite and non-zero');
  if AValue = 0.0 then
    raise EArgumentError.Create(AFunctionName + ': scalar divisor must be finite and non-zero');
end;

procedure ValidateScalarDivisor(const AFunctionName: string; const AValue: Double); overload; inline;
begin
  if not IsFinite(AValue) then
    raise EArgumentError.Create(AFunctionName + ': scalar divisor must be finite and non-zero');
  if AValue = 0.0 then
    raise EArgumentError.Create(AFunctionName + ': scalar divisor must be finite and non-zero');
end;

procedure ValidateComponentDivisor(const AFunctionName: string; const AValue: TVec2f); overload; inline;
begin
  if not IsFinite(AValue) then
    raise EArgumentError.Create(AFunctionName + ': divisor vector must be finite and non-zero');
  if (AValue.X = 0.0) or (AValue.Y = 0.0) then
    raise EArgumentError.Create(AFunctionName + ': divisor vector must be finite and non-zero');
end;

procedure ValidateComponentDivisor(const AFunctionName: string; const AValue: TVec3f); overload; inline;
begin
  if not IsFinite(AValue) then
    raise EArgumentError.Create(AFunctionName + ': divisor vector must be finite and non-zero');
  if (AValue.X = 0.0) or (AValue.Y = 0.0) or (AValue.Z = 0.0) then
    raise EArgumentError.Create(AFunctionName + ': divisor vector must be finite and non-zero');
end;

procedure ValidateComponentDivisor(const AFunctionName: string; const AValue: TVec4f); overload; inline;
begin
  if not IsFinite(AValue) then
    raise EArgumentError.Create(AFunctionName + ': divisor vector must be finite and non-zero');
  if (AValue.X = 0.0) or (AValue.Y = 0.0) or (AValue.Z = 0.0) or (AValue.W = 0.0) then
    raise EArgumentError.Create(AFunctionName + ': divisor vector must be finite and non-zero');
end;

procedure ValidateComponentDivisor(const AFunctionName: string; const AValue: TVec2d); overload; inline;
begin
  if not IsFinite(AValue) then
    raise EArgumentError.Create(AFunctionName + ': divisor vector must be finite and non-zero');
  if (AValue.X = 0.0) or (AValue.Y = 0.0) then
    raise EArgumentError.Create(AFunctionName + ': divisor vector must be finite and non-zero');
end;

procedure ValidateComponentDivisor(const AFunctionName: string; const AValue: TVec3d); overload; inline;
begin
  if not IsFinite(AValue) then
    raise EArgumentError.Create(AFunctionName + ': divisor vector must be finite and non-zero');
  if (AValue.X = 0.0) or (AValue.Y = 0.0) or (AValue.Z = 0.0) then
    raise EArgumentError.Create(AFunctionName + ': divisor vector must be finite and non-zero');
end;

procedure ValidateComponentDivisor(const AFunctionName: string; const AValue: TVec4d); overload; inline;
begin
  if not IsFinite(AValue) then
    raise EArgumentError.Create(AFunctionName + ': divisor vector must be finite and non-zero');
  if (AValue.X = 0.0) or (AValue.Y = 0.0) or (AValue.Z = 0.0) or (AValue.W = 0.0) then
    raise EArgumentError.Create(AFunctionName + ': divisor vector must be finite and non-zero');
end;

function StableVec4Length(const AX, AY, AZ, AW: Single): Single; inline;
var
  LX: Single;
  LY: Single;
  LZ: Single;
  LW: Single;
  LMax: Single;
  LScaledX: Single;
  LScaledY: Single;
  LScaledZ: Single;
  LScaledW: Single;
begin
  if nextpas.core.math.scalar.IsNaN(AX) or nextpas.core.math.scalar.IsNaN(AY) or
    nextpas.core.math.scalar.IsNaN(AZ) or nextpas.core.math.scalar.IsNaN(AW) then
    Exit(((AX + AY) + AZ) + AW);
  LX := nextpas.core.math.scalar.Abs(AX);
  LY := nextpas.core.math.scalar.Abs(AY);
  LZ := nextpas.core.math.scalar.Abs(AZ);
  LW := nextpas.core.math.scalar.Abs(AW);
  if nextpas.core.math.scalar.IsInfinite(LX) or nextpas.core.math.scalar.IsInfinite(LY) or
    nextpas.core.math.scalar.IsInfinite(LZ) or nextpas.core.math.scalar.IsInfinite(LW) then
    Exit(((LX + LY) + LZ) + LW);
  LMax := nextpas.core.math.scalar.Max(LX,
    nextpas.core.math.scalar.Max(LY, nextpas.core.math.scalar.Max(LZ, LW)));
  if LMax = 0.0 then
    Exit(0.0);
  LScaledX := LX / LMax;
  LScaledY := LY / LMax;
  LScaledZ := LZ / LMax;
  LScaledW := LW / LMax;
  Result := LMax * Single(System.Sqrt(
    LScaledX * LScaledX + LScaledY * LScaledY +
    LScaledZ * LScaledZ + LScaledW * LScaledW));
end;

function StableVec4Length(const AX, AY, AZ, AW: Double): Double; inline;
var
  LX: Double;
  LY: Double;
  LZ: Double;
  LW: Double;
  LMax: Double;
  LScaledX: Double;
  LScaledY: Double;
  LScaledZ: Double;
  LScaledW: Double;
begin
  if nextpas.core.math.scalar.IsNaN(AX) or nextpas.core.math.scalar.IsNaN(AY) or
    nextpas.core.math.scalar.IsNaN(AZ) or nextpas.core.math.scalar.IsNaN(AW) then
    Exit(((AX + AY) + AZ) + AW);
  LX := nextpas.core.math.scalar.Abs(AX);
  LY := nextpas.core.math.scalar.Abs(AY);
  LZ := nextpas.core.math.scalar.Abs(AZ);
  LW := nextpas.core.math.scalar.Abs(AW);
  if nextpas.core.math.scalar.IsInfinite(LX) or nextpas.core.math.scalar.IsInfinite(LY) or
    nextpas.core.math.scalar.IsInfinite(LZ) or nextpas.core.math.scalar.IsInfinite(LW) then
    Exit(((LX + LY) + LZ) + LW);
  LMax := nextpas.core.math.scalar.Max(LX,
    nextpas.core.math.scalar.Max(LY, nextpas.core.math.scalar.Max(LZ, LW)));
  if LMax = 0.0 then
    Exit(0.0);
  LScaledX := LX / LMax;
  LScaledY := LY / LMax;
  LScaledZ := LZ / LMax;
  LScaledW := LW / LMax;
  Result := LMax * System.Sqrt(
    LScaledX * LScaledX + LScaledY * LScaledY +
    LScaledZ * LScaledZ + LScaledW * LScaledW);
end;

function StableVec2Length(const AX, AY: Single): Single; inline;
begin
  Result := StableVec4Length(AX, AY, Single(0.0), Single(0.0));
end;

function StableVec2Length(const AX, AY: Double): Double; inline;
begin
  Result := StableVec4Length(AX, AY, 0.0, 0.0);
end;

function StableVec4LengthSqr(const AX, AY, AZ, AW: Single): Single; inline;
var
  LX: Double;
  LY: Double;
  LZ: Double;
  LW: Double;
  LMax: Double;
  LScaledX: Double;
  LScaledY: Double;
  LScaledZ: Double;
  LScaledW: Double;
  LScaledSum: Double;
begin
  if nextpas.core.math.scalar.IsNaN(AX) or nextpas.core.math.scalar.IsNaN(AY) or
    nextpas.core.math.scalar.IsNaN(AZ) or nextpas.core.math.scalar.IsNaN(AW) then
    Exit(((AX + AY) + AZ) + AW);
  if nextpas.core.math.scalar.IsInfinite(AX) or nextpas.core.math.scalar.IsInfinite(AY) or
    nextpas.core.math.scalar.IsInfinite(AZ) or nextpas.core.math.scalar.IsInfinite(AW) then
    Exit(SinglePositiveInfinity);
  LX := nextpas.core.math.scalar.Abs(AX);
  LY := nextpas.core.math.scalar.Abs(AY);
  LZ := nextpas.core.math.scalar.Abs(AZ);
  LW := nextpas.core.math.scalar.Abs(AW);
  LMax := LX;
  if LY > LMax then
    LMax := LY;
  if LZ > LMax then
    LMax := LZ;
  if LW > LMax then
    LMax := LW;
  if LMax = 0.0 then
    Exit(0.0);
  LScaledX := LX / LMax;
  LScaledY := LY / LMax;
  LScaledZ := LZ / LMax;
  LScaledW := LW / LMax;
  LScaledSum := LScaledX * LScaledX + LScaledY * LScaledY +
    LScaledZ * LScaledZ + LScaledW * LScaledW;
  if LMax > System.Sqrt(MAX_SINGLE_VALUE / LScaledSum) then
    Exit(SinglePositiveInfinity);
  Result := Single((LMax * LMax) * LScaledSum);
end;

function StableVec4LengthSqr(const AX, AY, AZ, AW: Double): Double; inline;
var
  LX: Double;
  LY: Double;
  LZ: Double;
  LW: Double;
  LMax: Double;
  LScaledX: Double;
  LScaledY: Double;
  LScaledZ: Double;
  LScaledW: Double;
  LScaledSum: Double;
begin
  if nextpas.core.math.scalar.IsNaN(AX) or nextpas.core.math.scalar.IsNaN(AY) or
    nextpas.core.math.scalar.IsNaN(AZ) or nextpas.core.math.scalar.IsNaN(AW) then
    Exit(((AX + AY) + AZ) + AW);
  LX := nextpas.core.math.scalar.Abs(AX);
  LY := nextpas.core.math.scalar.Abs(AY);
  LZ := nextpas.core.math.scalar.Abs(AZ);
  LW := nextpas.core.math.scalar.Abs(AW);
  if nextpas.core.math.scalar.IsInfinite(LX) or nextpas.core.math.scalar.IsInfinite(LY) or
    nextpas.core.math.scalar.IsInfinite(LZ) or nextpas.core.math.scalar.IsInfinite(LW) then
    Exit(DoublePositiveInfinity);
  LMax := LX;
  if LY > LMax then
    LMax := LY;
  if LZ > LMax then
    LMax := LZ;
  if LW > LMax then
    LMax := LW;
  if LMax = 0.0 then
    Exit(0.0);
  LScaledX := LX / LMax;
  LScaledY := LY / LMax;
  LScaledZ := LZ / LMax;
  LScaledW := LW / LMax;
  LScaledSum := LScaledX * LScaledX + LScaledY * LScaledY +
    LScaledZ * LScaledZ + LScaledW * LScaledW;
  if LMax > System.Sqrt(MAX_DOUBLE_VALUE / LScaledSum) then
    Exit(DoublePositiveInfinity);
  Result := (LMax * LMax) * LScaledSum;
end;

function StableVec2LengthSqr(const AX, AY: Single): Single; inline;
begin
  Result := StableVec4LengthSqr(AX, AY, Single(0.0), Single(0.0));
end;

function StableVec2LengthSqr(const AX, AY: Double): Double; inline;
begin
  Result := StableVec4LengthSqr(AX, AY, 0.0, 0.0);
end;

function StableVec3LengthSqr(const AX, AY, AZ: Single): Single; inline;
begin
  Result := StableVec4LengthSqr(AX, AY, AZ, Single(0.0));
end;

function StableVec3LengthSqr(const AX, AY, AZ: Double): Double; inline;
begin
  Result := StableVec4LengthSqr(AX, AY, AZ, 0.0);
end;

function StableVec3Length(const AX, AY, AZ: Single): Single; inline;
begin
  Result := StableVec4Length(AX, AY, AZ, Single(0.0));
end;

function StableVec3Length(const AX, AY, AZ: Double): Double; inline;
begin
  Result := StableVec4Length(AX, AY, AZ, 0.0);
end;

function NormalizeFiniteVec2(const AValue: TVec2f): TVec2f; overload; inline;
var
  LX: Single;
  LY: Single;
  LMax: Single;
  LScaledX: Single;
  LScaledY: Single;
  LScaledLength: Single;
begin
  LX := nextpas.core.math.scalar.Abs(AValue.X);
  LY := nextpas.core.math.scalar.Abs(AValue.Y);
  LMax := nextpas.core.math.scalar.Max(LX, LY);
  if LMax = 0.0 then
    Exit(TVec2f.Zero);
  LScaledX := AValue.X / LMax;
  LScaledY := AValue.Y / LMax;
  LScaledLength := Single(System.Sqrt(LScaledX * LScaledX + LScaledY * LScaledY));
  Result := TVec2f.Create(LScaledX / LScaledLength, LScaledY / LScaledLength);
end;

function NormalizeFiniteVec3(const AValue: TVec3f): TVec3f; overload; inline;
var
  LX: Single;
  LY: Single;
  LZ: Single;
  LMax: Single;
  LScaledX: Single;
  LScaledY: Single;
  LScaledZ: Single;
  LScaledLength: Single;
begin
  LX := nextpas.core.math.scalar.Abs(AValue.X);
  LY := nextpas.core.math.scalar.Abs(AValue.Y);
  LZ := nextpas.core.math.scalar.Abs(AValue.Z);
  LMax := nextpas.core.math.scalar.Max(LX, nextpas.core.math.scalar.Max(LY, LZ));
  if LMax = 0.0 then
    Exit(TVec3f.Zero);
  LScaledX := AValue.X / LMax;
  LScaledY := AValue.Y / LMax;
  LScaledZ := AValue.Z / LMax;
  LScaledLength := Single(System.Sqrt(
    LScaledX * LScaledX + LScaledY * LScaledY + LScaledZ * LScaledZ));
  Result := TVec3f.Create(
    LScaledX / LScaledLength,
    LScaledY / LScaledLength,
    LScaledZ / LScaledLength);
end;

function NormalizeFiniteVec4(const AValue: TVec4f): TVec4f; overload; inline;
var
  LX: Single;
  LY: Single;
  LZ: Single;
  LW: Single;
  LMax: Single;
  LScaledX: Single;
  LScaledY: Single;
  LScaledZ: Single;
  LScaledW: Single;
  LScaledLength: Single;
begin
  LX := nextpas.core.math.scalar.Abs(AValue.X);
  LY := nextpas.core.math.scalar.Abs(AValue.Y);
  LZ := nextpas.core.math.scalar.Abs(AValue.Z);
  LW := nextpas.core.math.scalar.Abs(AValue.W);
  LMax := nextpas.core.math.scalar.Max(LX,
    nextpas.core.math.scalar.Max(LY, nextpas.core.math.scalar.Max(LZ, LW)));
  if LMax = 0.0 then
    Exit(TVec4f.Zero);
  LScaledX := AValue.X / LMax;
  LScaledY := AValue.Y / LMax;
  LScaledZ := AValue.Z / LMax;
  LScaledW := AValue.W / LMax;
  LScaledLength := Single(System.Sqrt(
    LScaledX * LScaledX + LScaledY * LScaledY +
    LScaledZ * LScaledZ + LScaledW * LScaledW));
  Result := TVec4f.Create(
    LScaledX / LScaledLength,
    LScaledY / LScaledLength,
    LScaledZ / LScaledLength,
    LScaledW / LScaledLength);
end;

function NormalizeFiniteVec2(const AValue: TVec2d): TVec2d; overload; inline;
var
  LX: Double;
  LY: Double;
  LMax: Double;
  LScaledX: Double;
  LScaledY: Double;
  LScaledLength: Double;
begin
  LX := nextpas.core.math.scalar.Abs(AValue.X);
  LY := nextpas.core.math.scalar.Abs(AValue.Y);
  LMax := nextpas.core.math.scalar.Max(LX, LY);
  if LMax = 0.0 then
    Exit(TVec2d.Zero);
  LScaledX := AValue.X / LMax;
  LScaledY := AValue.Y / LMax;
  LScaledLength := System.Sqrt(LScaledX * LScaledX + LScaledY * LScaledY);
  Result := TVec2d.Create(LScaledX / LScaledLength, LScaledY / LScaledLength);
end;

function NormalizeFiniteVec3(const AValue: TVec3d): TVec3d; overload; inline;
var
  LX: Double;
  LY: Double;
  LZ: Double;
  LMax: Double;
  LScaledX: Double;
  LScaledY: Double;
  LScaledZ: Double;
  LScaledLength: Double;
begin
  LX := nextpas.core.math.scalar.Abs(AValue.X);
  LY := nextpas.core.math.scalar.Abs(AValue.Y);
  LZ := nextpas.core.math.scalar.Abs(AValue.Z);
  LMax := nextpas.core.math.scalar.Max(LX, nextpas.core.math.scalar.Max(LY, LZ));
  if LMax = 0.0 then
    Exit(TVec3d.Zero);
  LScaledX := AValue.X / LMax;
  LScaledY := AValue.Y / LMax;
  LScaledZ := AValue.Z / LMax;
  LScaledLength := System.Sqrt(
    LScaledX * LScaledX + LScaledY * LScaledY + LScaledZ * LScaledZ);
  Result := TVec3d.Create(
    LScaledX / LScaledLength,
    LScaledY / LScaledLength,
    LScaledZ / LScaledLength);
end;

function NormalizeFiniteVec4(const AValue: TVec4d): TVec4d; overload; inline;
var
  LX: Double;
  LY: Double;
  LZ: Double;
  LW: Double;
  LMax: Double;
  LScaledX: Double;
  LScaledY: Double;
  LScaledZ: Double;
  LScaledW: Double;
  LScaledLength: Double;
begin
  LX := nextpas.core.math.scalar.Abs(AValue.X);
  LY := nextpas.core.math.scalar.Abs(AValue.Y);
  LZ := nextpas.core.math.scalar.Abs(AValue.Z);
  LW := nextpas.core.math.scalar.Abs(AValue.W);
  LMax := nextpas.core.math.scalar.Max(LX,
    nextpas.core.math.scalar.Max(LY, nextpas.core.math.scalar.Max(LZ, LW)));
  if LMax = 0.0 then
    Exit(TVec4d.Zero);
  LScaledX := AValue.X / LMax;
  LScaledY := AValue.Y / LMax;
  LScaledZ := AValue.Z / LMax;
  LScaledW := AValue.W / LMax;
  LScaledLength := System.Sqrt(
    LScaledX * LScaledX + LScaledY * LScaledY +
    LScaledZ * LScaledZ + LScaledW * LScaledW);
  Result := TVec4d.Create(
    LScaledX / LScaledLength,
    LScaledY / LScaledLength,
    LScaledZ / LScaledLength,
    LScaledW / LScaledLength);
end;

function StableVec4Dot(const AX, AY, AZ, AW, BX, BY, BZ, BW: Single): Single; inline;
var
  LScaleA: Double;
  LScaleB: Double;
  LScaledSum: Double;
  LMagnitude: Double;
begin
  if nextpas.core.math.scalar.IsNaN(AX) or nextpas.core.math.scalar.IsNaN(AY) or
    nextpas.core.math.scalar.IsNaN(AZ) or nextpas.core.math.scalar.IsNaN(AW) or
    nextpas.core.math.scalar.IsNaN(BX) or nextpas.core.math.scalar.IsNaN(BY) or
    nextpas.core.math.scalar.IsNaN(BZ) or nextpas.core.math.scalar.IsNaN(BW) or
    nextpas.core.math.scalar.IsInfinite(AX) or nextpas.core.math.scalar.IsInfinite(AY) or
    nextpas.core.math.scalar.IsInfinite(AZ) or nextpas.core.math.scalar.IsInfinite(AW) or
    nextpas.core.math.scalar.IsInfinite(BX) or nextpas.core.math.scalar.IsInfinite(BY) or
    nextpas.core.math.scalar.IsInfinite(BZ) or nextpas.core.math.scalar.IsInfinite(BW) then
    Exit(((AX * BX + AY * BY) + AZ * BZ) + AW * BW);

  LScaleA := nextpas.core.math.scalar.Max(nextpas.core.math.scalar.Abs(AX),
    nextpas.core.math.scalar.Max(nextpas.core.math.scalar.Abs(AY),
    nextpas.core.math.scalar.Max(nextpas.core.math.scalar.Abs(AZ),
    nextpas.core.math.scalar.Abs(AW))));
  LScaleB := nextpas.core.math.scalar.Max(nextpas.core.math.scalar.Abs(BX),
    nextpas.core.math.scalar.Max(nextpas.core.math.scalar.Abs(BY),
    nextpas.core.math.scalar.Max(nextpas.core.math.scalar.Abs(BZ),
    nextpas.core.math.scalar.Abs(BW))));
  if (LScaleA = 0.0) or (LScaleB = 0.0) then
    Exit(0.0);

  LScaledSum :=
    (Double(AX) / LScaleA) * (Double(BX) / LScaleB) +
    (Double(AY) / LScaleA) * (Double(BY) / LScaleB) +
    (Double(AZ) / LScaleA) * (Double(BZ) / LScaleB) +
    (Double(AW) / LScaleA) * (Double(BW) / LScaleB);
  if LScaledSum = 0.0 then
    Exit(0.0);

  LMagnitude := (LScaleA * LScaleB) * nextpas.core.math.scalar.Abs(LScaledSum);
  if LMagnitude > MAX_SINGLE_VALUE then
    Exit(SingleSignedInfinity(LScaledSum < 0.0));
  Result := Single(LMagnitude);
  if LScaledSum < 0.0 then
    Result := -Result;
end;

function StableVec4Dot(const AX, AY, AZ, AW, BX, BY, BZ, BW: Double): Double; inline;
var
  LScaleA: Double;
  LScaleB: Double;
  LScaledSum: Double;
  LAbsScaledSum: Double;
  LProduct: Double;
  LLogMagnitude: Double;
begin
  if nextpas.core.math.scalar.IsNaN(AX) or nextpas.core.math.scalar.IsNaN(AY) or
    nextpas.core.math.scalar.IsNaN(AZ) or nextpas.core.math.scalar.IsNaN(AW) or
    nextpas.core.math.scalar.IsNaN(BX) or nextpas.core.math.scalar.IsNaN(BY) or
    nextpas.core.math.scalar.IsNaN(BZ) or nextpas.core.math.scalar.IsNaN(BW) or
    nextpas.core.math.scalar.IsInfinite(AX) or nextpas.core.math.scalar.IsInfinite(AY) or
    nextpas.core.math.scalar.IsInfinite(AZ) or nextpas.core.math.scalar.IsInfinite(AW) or
    nextpas.core.math.scalar.IsInfinite(BX) or nextpas.core.math.scalar.IsInfinite(BY) or
    nextpas.core.math.scalar.IsInfinite(BZ) or nextpas.core.math.scalar.IsInfinite(BW) then
    Exit(((AX * BX + AY * BY) + AZ * BZ) + AW * BW);

  LScaleA := nextpas.core.math.scalar.Max(nextpas.core.math.scalar.Abs(AX),
    nextpas.core.math.scalar.Max(nextpas.core.math.scalar.Abs(AY),
    nextpas.core.math.scalar.Max(nextpas.core.math.scalar.Abs(AZ),
    nextpas.core.math.scalar.Abs(AW))));
  LScaleB := nextpas.core.math.scalar.Max(nextpas.core.math.scalar.Abs(BX),
    nextpas.core.math.scalar.Max(nextpas.core.math.scalar.Abs(BY),
    nextpas.core.math.scalar.Max(nextpas.core.math.scalar.Abs(BZ),
    nextpas.core.math.scalar.Abs(BW))));
  if (LScaleA = 0.0) or (LScaleB = 0.0) then
    Exit(0.0);

  LScaledSum :=
    (AX / LScaleA) * (BX / LScaleB) +
    (AY / LScaleA) * (BY / LScaleB) +
    (AZ / LScaleA) * (BZ / LScaleB) +
    (AW / LScaleA) * (BW / LScaleB);
  if LScaledSum = 0.0 then
    Exit(0.0);

  LAbsScaledSum := nextpas.core.math.scalar.Abs(LScaledSum);
  if LScaleA <= MAX_DOUBLE_VALUE / LScaleB then
  begin
    LProduct := LScaleA * LScaleB;
    if LProduct = 0.0 then
      Exit(0.0);
    if LAbsScaledSum > MAX_DOUBLE_VALUE / LProduct then
      Exit(DoubleSignedInfinity(LScaledSum < 0.0));
    Result := LProduct * LScaledSum;
    Exit;
  end;

  LLogMagnitude := System.Ln(LScaleA) + System.Ln(LScaleB) + System.Ln(LAbsScaledSum);
  if LLogMagnitude >= LN_MAX_DOUBLE_VALUE then
    Exit(DoubleSignedInfinity(LScaledSum < 0.0));
  Result := System.Exp(LLogMagnitude);
  if LScaledSum < 0.0 then
    Result := -Result;
end;

function StableVec2Dot(const AX, AY, BX, BY: Single): Single; inline;
begin
  Result := StableVec4Dot(AX, AY, Single(0.0), Single(0.0), BX, BY, Single(0.0), Single(0.0));
end;

function StableVec2Dot(const AX, AY, BX, BY: Double): Double; inline;
begin
  Result := StableVec4Dot(AX, AY, 0.0, 0.0, BX, BY, 0.0, 0.0);
end;

function StableVec3Dot(const AX, AY, AZ, BX, BY, BZ: Single): Single; inline;
begin
  Result := StableVec4Dot(AX, AY, AZ, Single(0.0), BX, BY, BZ, Single(0.0));
end;

function StableVec3Dot(const AX, AY, AZ, BX, BY, BZ: Double): Double; inline;
begin
  Result := StableVec4Dot(AX, AY, AZ, 0.0, BX, BY, BZ, 0.0);
end;

function StableCrossComponentSingle(const AU, AV, BU, BV: Single): Single; inline;
var
  LValue: Double;
  LAbsValue: Double;
begin
  LValue := Double(AU) * Double(BV) - Double(AV) * Double(BU);
  if LValue = 0.0 then
    Exit(0.0);

  LAbsValue := nextpas.core.math.scalar.Abs(LValue);
  if LAbsValue > MAX_SINGLE_VALUE then
    Exit(SingleSignedInfinity(LValue < 0.0));

  Result := Single(LValue);
end;

function CanSubtractAsDouble(const ALeft, ARight: Double): Boolean; inline;
begin
  if (ALeft > 0.0) and (ARight < 0.0) then
    Exit(-ARight <= MAX_DOUBLE_VALUE - ALeft);
  if (ALeft < 0.0) and (ARight > 0.0) then
    Exit(ARight <= MAX_DOUBLE_VALUE + ALeft);
  Result := True;
end;

function CanAddAsDouble(const ALeft, ARight: Double): Boolean; inline;
begin
  if (ALeft > 0.0) and (ARight > 0.0) then
    Exit(ARight <= MAX_DOUBLE_VALUE - ALeft);
  if (ALeft < 0.0) and (ARight < 0.0) then
    Exit(-ARight <= MAX_DOUBLE_VALUE + ALeft);
  Result := True;
end;

function TryCrossDifferenceCandidateDouble(const AFactor, ALeft, ARight: Double;
  var AValue: Double): Boolean; inline;
var
  LDiff: Extended;
  LAbsFactor: Extended;
  LAbsDiff: Extended;
  LCandidate: Extended;
  LAbsCandidate: Extended;
begin
  if not CanSubtractAsDouble(ALeft, ARight) then
    Exit(False);

  LDiff := Extended(ALeft) - Extended(ARight);
  if LDiff <> LDiff then
    Exit(False);
  if LDiff = 0.0 then
  begin
    AValue := 0.0;
    Exit(True);
  end;

  LAbsFactor := Extended(AFactor);
  if LAbsFactor < 0.0 then
    LAbsFactor := -LAbsFactor;
  if LAbsFactor = 0.0 then
  begin
    AValue := 0.0;
    Exit(True);
  end;

  LAbsDiff := LDiff;
  if LAbsDiff < 0.0 then
    LAbsDiff := -LAbsDiff;
  if (LAbsFactor > 1.0) and (LAbsDiff > MAX_DOUBLE_VALUE / LAbsFactor) then
    Exit(False);

  LCandidate := Extended(AFactor) * LDiff;
  if LCandidate <> LCandidate then
    Exit(False);

  LAbsCandidate := LCandidate;
  if LAbsCandidate < 0.0 then
    LAbsCandidate := -LAbsCandidate;
  if LAbsCandidate > MAX_DOUBLE_VALUE then
    Exit(False);

  AValue := Double(LCandidate);
  Result := IsFinite(AValue);
end;

function TryCrossSumCandidateDouble(const AFactor, ALeft, ARight: Double;
  var AValue: Double): Boolean; inline;
var
  LSum: Extended;
  LAbsFactor: Extended;
  LAbsSum: Extended;
  LCandidate: Extended;
  LAbsCandidate: Extended;
begin
  if not CanAddAsDouble(ALeft, ARight) then
    Exit(False);

  LSum := Extended(ALeft) + Extended(ARight);
  if LSum <> LSum then
    Exit(False);
  if LSum = 0.0 then
  begin
    AValue := 0.0;
    Exit(True);
  end;

  LAbsFactor := Extended(AFactor);
  if LAbsFactor < 0.0 then
    LAbsFactor := -LAbsFactor;
  if LAbsFactor = 0.0 then
  begin
    AValue := 0.0;
    Exit(True);
  end;

  LAbsSum := LSum;
  if LAbsSum < 0.0 then
    LAbsSum := -LAbsSum;
  if (LAbsFactor > 1.0) and (LAbsSum > MAX_DOUBLE_VALUE / LAbsFactor) then
    Exit(False);

  LCandidate := Extended(AFactor) * LSum;
  if LCandidate <> LCandidate then
    Exit(False);

  LAbsCandidate := LCandidate;
  if LAbsCandidate < 0.0 then
    LAbsCandidate := -LAbsCandidate;
  if LAbsCandidate > MAX_DOUBLE_VALUE then
    Exit(False);

  AValue := Double(LCandidate);
  Result := IsFinite(AValue);
end;

procedure KeepCrossCandidateDouble(const ACandidate: Double; var ABest: Double;
  var AHasBest: Boolean); inline;
begin
  if not IsFinite(ACandidate) then
    Exit;
  if not AHasBest then
  begin
    ABest := ACandidate;
    AHasBest := True;
    Exit;
  end;

  if (ABest = 0.0) and (ACandidate <> 0.0) then
  begin
    ABest := ACandidate;
    Exit;
  end;

  if (ACandidate <> 0.0) and (ABest <> 0.0) and
    (nextpas.core.math.scalar.Abs(ACandidate) < nextpas.core.math.scalar.Abs(ABest)) then
    ABest := ACandidate;
end;

function StableCrossComponentDouble(const AU, AV, BU, BV: Double): Double; inline;
var
  LCandidate: Extended;
  LAbsCandidate: Extended;
  LLeftProduct: Extended;
  LRightProduct: Extended;
  LBestCandidate: Double;
  LDoubleCandidate: Double;
  LHasCandidate: Boolean;
  LScaleA: Double;
  LScaleB: Double;
  LScaledDiff: Double;
  LAbsScaledDiff: Double;
  LProduct: Double;
  LLogMagnitude: Double;
begin
  LHasCandidate := False;

  if AU = BU then
    if TryCrossDifferenceCandidateDouble(AU, BV, AV, LDoubleCandidate) then
      KeepCrossCandidateDouble(LDoubleCandidate, LBestCandidate, LHasCandidate);
  if AV = BV then
    if TryCrossDifferenceCandidateDouble(BV, AU, BU, LDoubleCandidate) then
      KeepCrossCandidateDouble(LDoubleCandidate, LBestCandidate, LHasCandidate);
  if AU = -BU then
    if TryCrossSumCandidateDouble(AU, BV, AV, LDoubleCandidate) then
      KeepCrossCandidateDouble(LDoubleCandidate, LBestCandidate, LHasCandidate);
  if AV = -BV then
    if TryCrossSumCandidateDouble(BV, AU, BU, LDoubleCandidate) then
      KeepCrossCandidateDouble(LDoubleCandidate, LBestCandidate, LHasCandidate);

  if LHasCandidate then
    Exit(LBestCandidate);

  LLeftProduct := Extended(AU);
  LLeftProduct := LLeftProduct * Extended(BV);
  LRightProduct := Extended(AV);
  LRightProduct := LRightProduct * Extended(BU);
  LCandidate := LLeftProduct - LRightProduct;
  if LCandidate = 0.0 then
    Exit(0.0)
  else
  if LCandidate = LCandidate then
  begin
    LAbsCandidate := LCandidate;
    if LAbsCandidate < 0.0 then
      LAbsCandidate := -LAbsCandidate;
    if LAbsCandidate <= MAX_DOUBLE_VALUE then
      Exit(Double(LCandidate));
  end;

  LScaleA := nextpas.core.math.scalar.Max(nextpas.core.math.scalar.Abs(AU),
    nextpas.core.math.scalar.Abs(AV));
  LScaleB := nextpas.core.math.scalar.Max(nextpas.core.math.scalar.Abs(BU),
    nextpas.core.math.scalar.Abs(BV));
  if (LScaleA = 0.0) or (LScaleB = 0.0) then
    Exit(0.0);

  LScaledDiff := (AU / LScaleA) * (BV / LScaleB) -
    (AV / LScaleA) * (BU / LScaleB);
  if LScaledDiff = 0.0 then
    Exit(0.0);

  LAbsScaledDiff := nextpas.core.math.scalar.Abs(LScaledDiff);
  if LScaleA <= MAX_DOUBLE_VALUE / LScaleB then
  begin
    LProduct := LScaleA * LScaleB;
    if LProduct = 0.0 then
      Exit(0.0);
    if LAbsScaledDiff > MAX_DOUBLE_VALUE / LProduct then
      Exit(DoubleSignedInfinity(LScaledDiff < 0.0));
    Exit(LProduct * LScaledDiff);
  end;

  LLogMagnitude := System.Ln(LScaleA) + System.Ln(LScaleB) + System.Ln(LAbsScaledDiff);
  if LLogMagnitude >= LN_MAX_DOUBLE_VALUE then
    Exit(DoubleSignedInfinity(LScaledDiff < 0.0));

  Result := System.Exp(LLogMagnitude);
  if LScaledDiff < 0.0 then
    Result := -Result;
end;

function StableVec3Cross(const AX, AY, AZ, BX, BY, BZ: Single): TVec3f; inline;
begin
  if (not IsFinite(AX)) or (not IsFinite(AY)) or (not IsFinite(AZ)) or
    (not IsFinite(BX)) or (not IsFinite(BY)) or (not IsFinite(BZ)) then
    Exit(TVec3f.Create(
      AY * BZ - AZ * BY,
      AZ * BX - AX * BZ,
      AX * BY - AY * BX));

  Result := TVec3f.Create(
    StableCrossComponentSingle(AY, AZ, BY, BZ),
    StableCrossComponentSingle(AZ, AX, BZ, BX),
    StableCrossComponentSingle(AX, AY, BX, BY));
end;

function StableVec3Cross(const AX, AY, AZ, BX, BY, BZ: Double): TVec3d; inline;
begin
  if (not IsFinite(AX)) or (not IsFinite(AY)) or (not IsFinite(AZ)) or
    (not IsFinite(BX)) or (not IsFinite(BY)) or (not IsFinite(BZ)) then
    Exit(TVec3d.Create(
      AY * BZ - AZ * BY,
      AZ * BX - AX * BZ,
      AX * BY - AY * BX));

  Result := TVec3d.Create(
    StableCrossComponentDouble(AY, AZ, BY, BZ),
    StableCrossComponentDouble(AZ, AX, BZ, BX),
    StableCrossComponentDouble(AX, AY, BX, BY));
end;

class function TVec2f.Create(const AX, AY: Single): TVec2f;
begin
  Result.X := AX;
  Result.Y := AY;
end;

class function TVec2f.Zero: TVec2f;
begin
  Result := TVec2f.Create(0.0, 0.0);
end;

class operator TVec2f.+ (const AA, AB: TVec2f): TVec2f;
begin
  Result := TVec2f.Create(AA.X + AB.X, AA.Y + AB.Y);
end;

class operator TVec2f.- (const AA, AB: TVec2f): TVec2f;
begin
  Result := TVec2f.Create(AA.X - AB.X, AA.Y - AB.Y);
end;

class operator TVec2f.- (const AValue: TVec2f): TVec2f;
begin
  Result := TVec2f.Create(-AValue.X, -AValue.Y);
end;

class operator TVec2f.* (const AValue: TVec2f; const AScalar: Single): TVec2f;
begin
  Result := TVec2f.Create(AValue.X * AScalar, AValue.Y * AScalar);
end;

class operator TVec2f.* (const AScalar: Single; const AValue: TVec2f): TVec2f;
begin
  Result := AValue * AScalar;
end;

class operator TVec2f./ (const AValue: TVec2f; const AScalar: Single): TVec2f;
begin
  ValidateScalarDivisor('TVec2f./', AScalar);
  Result := TVec2f.Create(AValue.X / AScalar, AValue.Y / AScalar);
end;

class function TVec2f.MulComponents(const AA, AB: TVec2f): TVec2f;
begin
  Result := TVec2f.Create(AA.X * AB.X, AA.Y * AB.Y);
end;

class function TVec2f.DivComponents(const AA, AB: TVec2f): TVec2f;
begin
  ValidateComponentDivisor('TVec2f.DivComponents', AB);
  Result := TVec2f.Create(AA.X / AB.X, AA.Y / AB.Y);
end;

class function TVec2f.Dot(const AA, AB: TVec2f): Single;
begin
  Result := StableVec2Dot(AA.X, AA.Y, AB.X, AB.Y);
end;

class function TVec2f.Lerp(const AA, AB: TVec2f; const AT: Single): TVec2f;
begin
  Result := TVec2f.Create(
    nextpas.core.math.scalar.Lerp(AA.X, AB.X, AT),
    nextpas.core.math.scalar.Lerp(AA.Y, AB.Y, AT));
end;

class function TVec2f.Equals(const AA, AB: TVec2f; const AEpsilon: Single): Boolean;
begin
  Result := SingleEquals(AA.X, AB.X, AEpsilon) and SingleEquals(AA.Y, AB.Y, AEpsilon);
end;

function TVec2f.LengthSqr: Single;
begin
  Result := StableVec2LengthSqr(X, Y);
end;

function TVec2f.Length: Single;
begin
  Result := StableVec2Length(X, Y);
end;

function TVec2f.Normalize: TVec2f;
begin
  ValidateVectorInput('TVec2f.Normalize', Self);
  Result := NormalizeFiniteVec2(Self);
end;

class function TVec3f.Create(const AX, AY, AZ: Single): TVec3f;
begin
  Result.X := AX;
  Result.Y := AY;
  Result.Z := AZ;
end;

class function TVec3f.Zero: TVec3f;
begin
  Result := TVec3f.Create(0.0, 0.0, 0.0);
end;

class operator TVec3f.+ (const AA, AB: TVec3f): TVec3f;
begin
  Result := TVec3f.Create(AA.X + AB.X, AA.Y + AB.Y, AA.Z + AB.Z);
end;

class operator TVec3f.- (const AA, AB: TVec3f): TVec3f;
begin
  Result := TVec3f.Create(AA.X - AB.X, AA.Y - AB.Y, AA.Z - AB.Z);
end;

class operator TVec3f.- (const AValue: TVec3f): TVec3f;
begin
  Result := TVec3f.Create(-AValue.X, -AValue.Y, -AValue.Z);
end;

class operator TVec3f.* (const AValue: TVec3f; const AScalar: Single): TVec3f;
begin
  Result := TVec3f.Create(AValue.X * AScalar, AValue.Y * AScalar, AValue.Z * AScalar);
end;

class operator TVec3f.* (const AScalar: Single; const AValue: TVec3f): TVec3f;
begin
  Result := AValue * AScalar;
end;

class operator TVec3f./ (const AValue: TVec3f; const AScalar: Single): TVec3f;
begin
  ValidateScalarDivisor('TVec3f./', AScalar);
  Result := TVec3f.Create(AValue.X / AScalar, AValue.Y / AScalar, AValue.Z / AScalar);
end;

class function TVec3f.MulComponents(const AA, AB: TVec3f): TVec3f;
begin
  Result := TVec3f.Create(AA.X * AB.X, AA.Y * AB.Y, AA.Z * AB.Z);
end;

class function TVec3f.DivComponents(const AA, AB: TVec3f): TVec3f;
begin
  ValidateComponentDivisor('TVec3f.DivComponents', AB);
  Result := TVec3f.Create(AA.X / AB.X, AA.Y / AB.Y, AA.Z / AB.Z);
end;

class function TVec3f.Dot(const AA, AB: TVec3f): Single;
begin
  Result := StableVec3Dot(AA.X, AA.Y, AA.Z, AB.X, AB.Y, AB.Z);
end;

class function TVec3f.Cross(const AA, AB: TVec3f): TVec3f;
begin
  Result := StableVec3Cross(AA.X, AA.Y, AA.Z, AB.X, AB.Y, AB.Z);
end;

class function TVec3f.Lerp(const AA, AB: TVec3f; const AT: Single): TVec3f;
begin
  Result := TVec3f.Create(
    nextpas.core.math.scalar.Lerp(AA.X, AB.X, AT),
    nextpas.core.math.scalar.Lerp(AA.Y, AB.Y, AT),
    nextpas.core.math.scalar.Lerp(AA.Z, AB.Z, AT));
end;

class function TVec3f.Equals(const AA, AB: TVec3f; const AEpsilon: Single): Boolean;
begin
  Result := SingleEquals(AA.X, AB.X, AEpsilon) and
    SingleEquals(AA.Y, AB.Y, AEpsilon) and
    SingleEquals(AA.Z, AB.Z, AEpsilon);
end;

function TVec3f.LengthSqr: Single;
begin
  Result := StableVec3LengthSqr(X, Y, Z);
end;

function TVec3f.Length: Single;
begin
  Result := StableVec3Length(X, Y, Z);
end;

function TVec3f.Normalize: TVec3f;
begin
  ValidateVectorInput('TVec3f.Normalize', Self);
  Result := NormalizeFiniteVec3(Self);
end;

class function TVec4f.Create(const AX, AY, AZ, AW: Single): TVec4f;
begin
  Result.X := AX;
  Result.Y := AY;
  Result.Z := AZ;
  Result.W := AW;
end;

class function TVec4f.Zero: TVec4f;
begin
  Result := TVec4f.Create(0.0, 0.0, 0.0, 0.0);
end;

class operator TVec4f.+ (const AA, AB: TVec4f): TVec4f;
begin
  Result := TVec4f.Create(AA.X + AB.X, AA.Y + AB.Y, AA.Z + AB.Z, AA.W + AB.W);
end;

class operator TVec4f.- (const AA, AB: TVec4f): TVec4f;
begin
  Result := TVec4f.Create(AA.X - AB.X, AA.Y - AB.Y, AA.Z - AB.Z, AA.W - AB.W);
end;

class operator TVec4f.- (const AValue: TVec4f): TVec4f;
begin
  Result := TVec4f.Create(-AValue.X, -AValue.Y, -AValue.Z, -AValue.W);
end;

class operator TVec4f.* (const AValue: TVec4f; const AScalar: Single): TVec4f;
begin
  Result := TVec4f.Create(AValue.X * AScalar, AValue.Y * AScalar,
    AValue.Z * AScalar, AValue.W * AScalar);
end;

class operator TVec4f.* (const AScalar: Single; const AValue: TVec4f): TVec4f;
begin
  Result := AValue * AScalar;
end;

class operator TVec4f./ (const AValue: TVec4f; const AScalar: Single): TVec4f;
begin
  ValidateScalarDivisor('TVec4f./', AScalar);
  Result := TVec4f.Create(AValue.X / AScalar, AValue.Y / AScalar,
    AValue.Z / AScalar, AValue.W / AScalar);
end;

class function TVec4f.MulComponents(const AA, AB: TVec4f): TVec4f;
begin
  Result := TVec4f.Create(AA.X * AB.X, AA.Y * AB.Y, AA.Z * AB.Z, AA.W * AB.W);
end;

class function TVec4f.DivComponents(const AA, AB: TVec4f): TVec4f;
begin
  ValidateComponentDivisor('TVec4f.DivComponents', AB);
  Result := TVec4f.Create(AA.X / AB.X, AA.Y / AB.Y, AA.Z / AB.Z, AA.W / AB.W);
end;

class function TVec4f.Dot(const AA, AB: TVec4f): Single;
begin
  Result := StableVec4Dot(AA.X, AA.Y, AA.Z, AA.W, AB.X, AB.Y, AB.Z, AB.W);
end;

class function TVec4f.Lerp(const AA, AB: TVec4f; const AT: Single): TVec4f;
begin
  Result := TVec4f.Create(
    nextpas.core.math.scalar.Lerp(AA.X, AB.X, AT),
    nextpas.core.math.scalar.Lerp(AA.Y, AB.Y, AT),
    nextpas.core.math.scalar.Lerp(AA.Z, AB.Z, AT),
    nextpas.core.math.scalar.Lerp(AA.W, AB.W, AT));
end;

class function TVec4f.Equals(const AA, AB: TVec4f; const AEpsilon: Single): Boolean;
begin
  Result := SingleEquals(AA.X, AB.X, AEpsilon) and
    SingleEquals(AA.Y, AB.Y, AEpsilon) and
    SingleEquals(AA.Z, AB.Z, AEpsilon) and
    SingleEquals(AA.W, AB.W, AEpsilon);
end;

function TVec4f.LengthSqr: Single;
begin
  Result := StableVec4LengthSqr(X, Y, Z, W);
end;

function TVec4f.Length: Single;
begin
  Result := StableVec4Length(X, Y, Z, W);
end;

function TVec4f.Normalize: TVec4f;
begin
  ValidateVectorInput('TVec4f.Normalize', Self);
  Result := NormalizeFiniteVec4(Self);
end;

class function TVec2d.Create(const AX, AY: Double): TVec2d;
begin
  Result.X := AX;
  Result.Y := AY;
end;

class function TVec2d.Zero: TVec2d;
begin
  Result := TVec2d.Create(0.0, 0.0);
end;

class operator TVec2d.+ (const AA, AB: TVec2d): TVec2d;
begin
  Result := TVec2d.Create(AA.X + AB.X, AA.Y + AB.Y);
end;

class operator TVec2d.- (const AA, AB: TVec2d): TVec2d;
begin
  Result := TVec2d.Create(AA.X - AB.X, AA.Y - AB.Y);
end;

class operator TVec2d.- (const AValue: TVec2d): TVec2d;
begin
  Result := TVec2d.Create(-AValue.X, -AValue.Y);
end;

class operator TVec2d.* (const AValue: TVec2d; const AScalar: Double): TVec2d;
begin
  Result := TVec2d.Create(AValue.X * AScalar, AValue.Y * AScalar);
end;

class operator TVec2d.* (const AScalar: Double; const AValue: TVec2d): TVec2d;
begin
  Result := AValue * AScalar;
end;

class operator TVec2d./ (const AValue: TVec2d; const AScalar: Double): TVec2d;
begin
  ValidateScalarDivisor('TVec2d./', AScalar);
  Result := TVec2d.Create(AValue.X / AScalar, AValue.Y / AScalar);
end;

class function TVec2d.MulComponents(const AA, AB: TVec2d): TVec2d;
begin
  Result := TVec2d.Create(AA.X * AB.X, AA.Y * AB.Y);
end;

class function TVec2d.DivComponents(const AA, AB: TVec2d): TVec2d;
begin
  ValidateComponentDivisor('TVec2d.DivComponents', AB);
  Result := TVec2d.Create(AA.X / AB.X, AA.Y / AB.Y);
end;

class function TVec2d.Dot(const AA, AB: TVec2d): Double;
begin
  Result := StableVec2Dot(AA.X, AA.Y, AB.X, AB.Y);
end;

class function TVec2d.Lerp(const AA, AB: TVec2d; const AT: Double): TVec2d;
begin
  Result := TVec2d.Create(
    nextpas.core.math.scalar.Lerp(AA.X, AB.X, AT),
    nextpas.core.math.scalar.Lerp(AA.Y, AB.Y, AT));
end;

class function TVec2d.Equals(const AA, AB: TVec2d; const AEpsilon: Double): Boolean;
begin
  Result := DoubleEquals(AA.X, AB.X, AEpsilon) and DoubleEquals(AA.Y, AB.Y, AEpsilon);
end;

function TVec2d.LengthSqr: Double;
begin
  Result := StableVec2LengthSqr(X, Y);
end;

function TVec2d.Length: Double;
begin
  Result := StableVec2Length(X, Y);
end;

function TVec2d.Normalize: TVec2d;
begin
  ValidateVectorInput('TVec2d.Normalize', Self);
  Result := NormalizeFiniteVec2(Self);
end;

class function TVec3d.Create(const AX, AY, AZ: Double): TVec3d;
begin
  Result.X := AX;
  Result.Y := AY;
  Result.Z := AZ;
end;

class function TVec3d.Zero: TVec3d;
begin
  Result := TVec3d.Create(0.0, 0.0, 0.0);
end;

class operator TVec3d.+ (const AA, AB: TVec3d): TVec3d;
begin
  Result := TVec3d.Create(AA.X + AB.X, AA.Y + AB.Y, AA.Z + AB.Z);
end;

class operator TVec3d.- (const AA, AB: TVec3d): TVec3d;
begin
  Result := TVec3d.Create(AA.X - AB.X, AA.Y - AB.Y, AA.Z - AB.Z);
end;

class operator TVec3d.- (const AValue: TVec3d): TVec3d;
begin
  Result := TVec3d.Create(-AValue.X, -AValue.Y, -AValue.Z);
end;

class operator TVec3d.* (const AValue: TVec3d; const AScalar: Double): TVec3d;
begin
  Result := TVec3d.Create(AValue.X * AScalar, AValue.Y * AScalar, AValue.Z * AScalar);
end;

class operator TVec3d.* (const AScalar: Double; const AValue: TVec3d): TVec3d;
begin
  Result := AValue * AScalar;
end;

class operator TVec3d./ (const AValue: TVec3d; const AScalar: Double): TVec3d;
begin
  ValidateScalarDivisor('TVec3d./', AScalar);
  Result := TVec3d.Create(AValue.X / AScalar, AValue.Y / AScalar, AValue.Z / AScalar);
end;

class function TVec3d.MulComponents(const AA, AB: TVec3d): TVec3d;
begin
  Result := TVec3d.Create(AA.X * AB.X, AA.Y * AB.Y, AA.Z * AB.Z);
end;

class function TVec3d.DivComponents(const AA, AB: TVec3d): TVec3d;
begin
  ValidateComponentDivisor('TVec3d.DivComponents', AB);
  Result := TVec3d.Create(AA.X / AB.X, AA.Y / AB.Y, AA.Z / AB.Z);
end;

class function TVec3d.Dot(const AA, AB: TVec3d): Double;
begin
  Result := StableVec3Dot(AA.X, AA.Y, AA.Z, AB.X, AB.Y, AB.Z);
end;

class function TVec3d.Cross(const AA, AB: TVec3d): TVec3d;
begin
  Result := StableVec3Cross(AA.X, AA.Y, AA.Z, AB.X, AB.Y, AB.Z);
end;

class function TVec3d.Lerp(const AA, AB: TVec3d; const AT: Double): TVec3d;
begin
  Result := TVec3d.Create(
    nextpas.core.math.scalar.Lerp(AA.X, AB.X, AT),
    nextpas.core.math.scalar.Lerp(AA.Y, AB.Y, AT),
    nextpas.core.math.scalar.Lerp(AA.Z, AB.Z, AT));
end;

class function TVec3d.Equals(const AA, AB: TVec3d; const AEpsilon: Double): Boolean;
begin
  Result := DoubleEquals(AA.X, AB.X, AEpsilon) and
    DoubleEquals(AA.Y, AB.Y, AEpsilon) and
    DoubleEquals(AA.Z, AB.Z, AEpsilon);
end;

function TVec3d.LengthSqr: Double;
begin
  Result := StableVec3LengthSqr(X, Y, Z);
end;

function TVec3d.Length: Double;
begin
  Result := StableVec3Length(X, Y, Z);
end;

function TVec3d.Normalize: TVec3d;
begin
  ValidateVectorInput('TVec3d.Normalize', Self);
  Result := NormalizeFiniteVec3(Self);
end;

class function TVec4d.Create(const AX, AY, AZ, AW: Double): TVec4d;
begin
  Result.X := AX;
  Result.Y := AY;
  Result.Z := AZ;
  Result.W := AW;
end;

class function TVec4d.Zero: TVec4d;
begin
  Result := TVec4d.Create(0.0, 0.0, 0.0, 0.0);
end;

class operator TVec4d.+ (const AA, AB: TVec4d): TVec4d;
begin
  Result := TVec4d.Create(AA.X + AB.X, AA.Y + AB.Y, AA.Z + AB.Z, AA.W + AB.W);
end;

class operator TVec4d.- (const AA, AB: TVec4d): TVec4d;
begin
  Result := TVec4d.Create(AA.X - AB.X, AA.Y - AB.Y, AA.Z - AB.Z, AA.W - AB.W);
end;

class operator TVec4d.- (const AValue: TVec4d): TVec4d;
begin
  Result := TVec4d.Create(-AValue.X, -AValue.Y, -AValue.Z, -AValue.W);
end;

class operator TVec4d.* (const AValue: TVec4d; const AScalar: Double): TVec4d;
begin
  Result := TVec4d.Create(AValue.X * AScalar, AValue.Y * AScalar,
    AValue.Z * AScalar, AValue.W * AScalar);
end;

class operator TVec4d.* (const AScalar: Double; const AValue: TVec4d): TVec4d;
begin
  Result := AValue * AScalar;
end;

class operator TVec4d./ (const AValue: TVec4d; const AScalar: Double): TVec4d;
begin
  ValidateScalarDivisor('TVec4d./', AScalar);
  Result := TVec4d.Create(AValue.X / AScalar, AValue.Y / AScalar,
    AValue.Z / AScalar, AValue.W / AScalar);
end;

class function TVec4d.MulComponents(const AA, AB: TVec4d): TVec4d;
begin
  Result := TVec4d.Create(AA.X * AB.X, AA.Y * AB.Y, AA.Z * AB.Z, AA.W * AB.W);
end;

class function TVec4d.DivComponents(const AA, AB: TVec4d): TVec4d;
begin
  ValidateComponentDivisor('TVec4d.DivComponents', AB);
  Result := TVec4d.Create(AA.X / AB.X, AA.Y / AB.Y, AA.Z / AB.Z, AA.W / AB.W);
end;

class function TVec4d.Dot(const AA, AB: TVec4d): Double;
begin
  Result := StableVec4Dot(AA.X, AA.Y, AA.Z, AA.W, AB.X, AB.Y, AB.Z, AB.W);
end;

class function TVec4d.Lerp(const AA, AB: TVec4d; const AT: Double): TVec4d;
begin
  Result := TVec4d.Create(
    nextpas.core.math.scalar.Lerp(AA.X, AB.X, AT),
    nextpas.core.math.scalar.Lerp(AA.Y, AB.Y, AT),
    nextpas.core.math.scalar.Lerp(AA.Z, AB.Z, AT),
    nextpas.core.math.scalar.Lerp(AA.W, AB.W, AT));
end;

class function TVec4d.Equals(const AA, AB: TVec4d; const AEpsilon: Double): Boolean;
begin
  Result := DoubleEquals(AA.X, AB.X, AEpsilon) and
    DoubleEquals(AA.Y, AB.Y, AEpsilon) and
    DoubleEquals(AA.Z, AB.Z, AEpsilon) and
    DoubleEquals(AA.W, AB.W, AEpsilon);
end;

function TVec4d.LengthSqr: Double;
begin
  Result := StableVec4LengthSqr(X, Y, Z, W);
end;

function TVec4d.Length: Double;
begin
  Result := StableVec4Length(X, Y, Z, W);
end;

function TVec4d.Normalize: TVec4d;
begin
  ValidateVectorInput('TVec4d.Normalize', Self);
  Result := NormalizeFiniteVec4(Self);
end;

end.
