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
  nextpas.core.math.scalar;

function SingleEquals(const AA, AB, AEpsilon: Single): Boolean; inline;
begin
  Result := (AEpsilon >= 0.0) and nextpas.core.math.scalar.FloatEquals(AA, AB, AEpsilon);
end;

function DoubleEquals(const AA, AB, AEpsilon: Double): Boolean; inline;
begin
  Result := (AEpsilon >= 0.0) and nextpas.core.math.scalar.FloatEquals(AA, AB, AEpsilon);
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

function StableVec3Length(const AX, AY, AZ: Single): Single; inline;
begin
  Result := StableVec4Length(AX, AY, AZ, Single(0.0));
end;

function StableVec3Length(const AX, AY, AZ: Double): Double; inline;
begin
  Result := StableVec4Length(AX, AY, AZ, 0.0);
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
  Result := TVec2f.Create(AValue.X / AScalar, AValue.Y / AScalar);
end;

class function TVec2f.MulComponents(const AA, AB: TVec2f): TVec2f;
begin
  Result := TVec2f.Create(AA.X * AB.X, AA.Y * AB.Y);
end;

class function TVec2f.DivComponents(const AA, AB: TVec2f): TVec2f;
begin
  Result := TVec2f.Create(AA.X / AB.X, AA.Y / AB.Y);
end;

class function TVec2f.Dot(const AA, AB: TVec2f): Single;
begin
  Result := AA.X * AB.X + AA.Y * AB.Y;
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
  Result := Dot(Self, Self);
end;

function TVec2f.Length: Single;
begin
  Result := StableVec2Length(X, Y);
end;

function TVec2f.Normalize: TVec2f;
var
  LLength: Single;
begin
  LLength := Length;
  if LLength = 0.0 then
    Exit(Zero);
  Result := Self / LLength;
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
  Result := TVec3f.Create(AValue.X / AScalar, AValue.Y / AScalar, AValue.Z / AScalar);
end;

class function TVec3f.MulComponents(const AA, AB: TVec3f): TVec3f;
begin
  Result := TVec3f.Create(AA.X * AB.X, AA.Y * AB.Y, AA.Z * AB.Z);
end;

class function TVec3f.DivComponents(const AA, AB: TVec3f): TVec3f;
begin
  Result := TVec3f.Create(AA.X / AB.X, AA.Y / AB.Y, AA.Z / AB.Z);
end;

class function TVec3f.Dot(const AA, AB: TVec3f): Single;
begin
  Result := AA.X * AB.X + AA.Y * AB.Y + AA.Z * AB.Z;
end;

class function TVec3f.Cross(const AA, AB: TVec3f): TVec3f;
begin
  Result := TVec3f.Create(
    AA.Y * AB.Z - AA.Z * AB.Y,
    AA.Z * AB.X - AA.X * AB.Z,
    AA.X * AB.Y - AA.Y * AB.X);
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
  Result := Dot(Self, Self);
end;

function TVec3f.Length: Single;
begin
  Result := StableVec3Length(X, Y, Z);
end;

function TVec3f.Normalize: TVec3f;
var
  LLength: Single;
begin
  LLength := Length;
  if LLength = 0.0 then
    Exit(Zero);
  Result := Self / LLength;
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
  Result := TVec4f.Create(AValue.X / AScalar, AValue.Y / AScalar,
    AValue.Z / AScalar, AValue.W / AScalar);
end;

class function TVec4f.MulComponents(const AA, AB: TVec4f): TVec4f;
begin
  Result := TVec4f.Create(AA.X * AB.X, AA.Y * AB.Y, AA.Z * AB.Z, AA.W * AB.W);
end;

class function TVec4f.DivComponents(const AA, AB: TVec4f): TVec4f;
begin
  Result := TVec4f.Create(AA.X / AB.X, AA.Y / AB.Y, AA.Z / AB.Z, AA.W / AB.W);
end;

class function TVec4f.Dot(const AA, AB: TVec4f): Single;
begin
  Result := AA.X * AB.X + AA.Y * AB.Y + AA.Z * AB.Z + AA.W * AB.W;
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
  Result := Dot(Self, Self);
end;

function TVec4f.Length: Single;
begin
  Result := StableVec4Length(X, Y, Z, W);
end;

function TVec4f.Normalize: TVec4f;
var
  LLength: Single;
begin
  LLength := Length;
  if LLength = 0.0 then
    Exit(Zero);
  Result := Self / LLength;
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
  Result := TVec2d.Create(AValue.X / AScalar, AValue.Y / AScalar);
end;

class function TVec2d.MulComponents(const AA, AB: TVec2d): TVec2d;
begin
  Result := TVec2d.Create(AA.X * AB.X, AA.Y * AB.Y);
end;

class function TVec2d.DivComponents(const AA, AB: TVec2d): TVec2d;
begin
  Result := TVec2d.Create(AA.X / AB.X, AA.Y / AB.Y);
end;

class function TVec2d.Dot(const AA, AB: TVec2d): Double;
begin
  Result := AA.X * AB.X + AA.Y * AB.Y;
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
  Result := Dot(Self, Self);
end;

function TVec2d.Length: Double;
begin
  Result := StableVec2Length(X, Y);
end;

function TVec2d.Normalize: TVec2d;
var
  LLength: Double;
begin
  LLength := Length;
  if LLength = 0.0 then
    Exit(Zero);
  Result := Self / LLength;
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
  Result := TVec3d.Create(AValue.X / AScalar, AValue.Y / AScalar, AValue.Z / AScalar);
end;

class function TVec3d.MulComponents(const AA, AB: TVec3d): TVec3d;
begin
  Result := TVec3d.Create(AA.X * AB.X, AA.Y * AB.Y, AA.Z * AB.Z);
end;

class function TVec3d.DivComponents(const AA, AB: TVec3d): TVec3d;
begin
  Result := TVec3d.Create(AA.X / AB.X, AA.Y / AB.Y, AA.Z / AB.Z);
end;

class function TVec3d.Dot(const AA, AB: TVec3d): Double;
begin
  Result := AA.X * AB.X + AA.Y * AB.Y + AA.Z * AB.Z;
end;

class function TVec3d.Cross(const AA, AB: TVec3d): TVec3d;
begin
  Result := TVec3d.Create(
    AA.Y * AB.Z - AA.Z * AB.Y,
    AA.Z * AB.X - AA.X * AB.Z,
    AA.X * AB.Y - AA.Y * AB.X);
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
  Result := Dot(Self, Self);
end;

function TVec3d.Length: Double;
begin
  Result := StableVec3Length(X, Y, Z);
end;

function TVec3d.Normalize: TVec3d;
var
  LLength: Double;
begin
  LLength := Length;
  if LLength = 0.0 then
    Exit(Zero);
  Result := Self / LLength;
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
  Result := TVec4d.Create(AValue.X / AScalar, AValue.Y / AScalar,
    AValue.Z / AScalar, AValue.W / AScalar);
end;

class function TVec4d.MulComponents(const AA, AB: TVec4d): TVec4d;
begin
  Result := TVec4d.Create(AA.X * AB.X, AA.Y * AB.Y, AA.Z * AB.Z, AA.W * AB.W);
end;

class function TVec4d.DivComponents(const AA, AB: TVec4d): TVec4d;
begin
  Result := TVec4d.Create(AA.X / AB.X, AA.Y / AB.Y, AA.Z / AB.Z, AA.W / AB.W);
end;

class function TVec4d.Dot(const AA, AB: TVec4d): Double;
begin
  Result := AA.X * AB.X + AA.Y * AB.Y + AA.Z * AB.Z + AA.W * AB.W;
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
  Result := Dot(Self, Self);
end;

function TVec4d.Length: Double;
begin
  Result := StableVec4Length(X, Y, Z, W);
end;

function TVec4d.Normalize: TVec4d;
var
  LLength: Double;
begin
  LLength := Length;
  if LLength = 0.0 then
    Exit(Zero);
  Result := Self / LLength;
end;

end.
