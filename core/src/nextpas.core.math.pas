unit nextpas.core.math;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.math.base,
  nextpas.core.math.scalar,
  nextpas.core.math.trig,
  nextpas.core.math.vec,
  nextpas.core.math.vec.base,
  nextpas.core.math.mat,
  nextpas.core.math.mat.base,
  nextpas.core.math.quat,
  nextpas.core.math.quat.base,
  nextpas.core.math.transform,
  nextpas.core.math.easing,
  nextpas.core.math.random;

type
  { vec types }
  TVec2f = nextpas.core.math.vec.base.TVec2f;
  TVec2d = nextpas.core.math.vec.base.TVec2d;
  TVec3f = nextpas.core.math.vec.base.TVec3f;
  TVec3d = nextpas.core.math.vec.base.TVec3d;
  TVec4f = nextpas.core.math.vec.base.TVec4f;
  TVec4d = nextpas.core.math.vec.base.TVec4d;
  { mat types }
  TMat3f = nextpas.core.math.mat.base.TMat3f;
  TMat3d = nextpas.core.math.mat.base.TMat3d;
  TMat4f = nextpas.core.math.mat.base.TMat4f;
  TMat4d = nextpas.core.math.mat.base.TMat4d;
  { quat types }
  TQuatf = nextpas.core.math.quat.base.TQuatf;
  TQuatd = nextpas.core.math.quat.base.TQuatd;
  { random types }
  TRandomState = nextpas.core.math.random.TRandomState;

{ scalar functions }

function IsAddOverflow(AA, AB: SizeUInt): Boolean; overload; inline;
function IsAddOverflow(AA, AB: UInt32): Boolean; overload; inline;
function IsMulOverflow(AA, AB: SizeUInt): Boolean; overload; inline;
function IsMulOverflow(AA, AB: UInt32): Boolean; overload; inline;

function Min(AA, AB: SizeUInt): SizeUInt; overload; inline;
function Max(AA, AB: SizeUInt): SizeUInt; overload; inline;
function Min(AA, AB: SizeInt): SizeInt; overload; inline;
function Max(AA, AB: SizeInt): SizeInt; overload; inline;
function Min(AA, AB: Double): Double; overload; inline;
function Max(AA, AB: Double): Double; overload; inline;
function Min(AA, AB: Single): Single; overload; inline;
function Max(AA, AB: Single): Single; overload; inline;
function Clamp(const AValue, AMin, AMax: Double): Double; overload; inline;
function Clamp(const AValue, AMin, AMax: Single): Single; overload; inline;
function Clamp(const AValue, AMin, AMax: Int32): Int32; overload; inline;
function Lerp(const AA, AB, AT: Double): Double; overload; inline;
function Lerp(const AA, AB, AT: Single): Single; overload; inline;
function InverseLerp(const AA, AB, AValue: Double): Double; overload; inline;
function InverseLerp(const AA, AB, AValue: Single): Single; overload; inline;
function Wrap(const AValue, AMin, AMax: Double): Double; overload; inline;
function Wrap(const AValue, AMin, AMax: Single): Single; overload; inline;
function SmoothStep(const AEdge0, AEdge1, AValue: Double): Double; overload; inline;
function SmoothStep(const AEdge0, AEdge1, AValue: Single): Single; overload; inline;

function Floor(const AValue: Double): Int64; overload; inline;
function Floor(const AValue: Single): Int64; overload; inline;
function Ceil(const AValue: Double): Int64; overload; inline;
function Ceil(const AValue: Single): Int64; overload; inline;
function Round(const AValue: Double): Int64; overload; inline;
function Round(const AValue: Single): Int64; overload; inline;
function Trunc(const AValue: Double): Int64; overload; inline;
function Trunc(const AValue: Single): Int64; overload; inline;
function Frac(const AValue: Double): Double; overload; inline;
function Frac(const AValue: Single): Single; overload; inline;

function Abs(const AValue: Double): Double; overload; inline;
function Abs(const AValue: Single): Single; overload; inline;
function Abs(const AValue: Int32): Int32; overload; inline;
function Abs(const AValue: Int64): Int64; overload; inline;
function Sign(const AValue: Double): Double; overload; inline;
function Sign(const AValue: Single): Single; overload; inline;
function Sign(const AValue: Int32): Int32; overload; inline;
function Sign(const AValue: Int64): Int64; overload; inline;
function IsNaN(const AValue: Double): Boolean; overload; inline;
function IsNaN(const AValue: Single): Boolean; overload; inline;
function IsInfinite(const AValue: Double): Boolean; overload; inline;
function IsInfinite(const AValue: Single): Boolean; overload; inline;
function FloatEquals(const AA, AB: Double; const AEpsilon: Double): Boolean; overload; inline;
function FloatEquals(const AA, AB: Single; const AEpsilon: Single): Boolean; overload; inline;
function FloatIsZero(const AValue: Double; const AEpsilon: Double): Boolean; overload; inline;
function FloatIsZero(const AValue: Single; const AEpsilon: Single): Boolean; overload; inline;
function DegToRad(const ADegrees: Double): Double; overload; inline;
function DegToRad(const ADegrees: Single): Single; overload; inline;
function RadToDeg(const ARadians: Double): Double; overload; inline;
function RadToDeg(const ARadians: Single): Single; overload; inline;

function GCD(AA, AB: Int64): Int64; inline;
function LCM(AA, AB: Int64): Int64; inline;
function Hypot(const AX, AY: Double): Double; overload; inline;
function Hypot(const AX, AY: Single): Single; overload; inline;
function Fmod(const AX, AY: Double): Double; overload; inline;
function Fmod(const AX, AY: Single): Single; overload; inline;

function Sin(const AX: Double): Double; overload; inline;
function Sin(const AX: Single): Single; overload; inline;
function Cos(const AX: Double): Double; overload; inline;
function Cos(const AX: Single): Single; overload; inline;
function Tan(const AX: Double): Double; overload; inline;
function Tan(const AX: Single): Single; overload; inline;
function ArcSin(const AX: Double): Double; overload; inline;
function ArcSin(const AX: Single): Single; overload; inline;
function ArcCos(const AX: Double): Double; overload; inline;
function ArcCos(const AX: Single): Single; overload; inline;
function ArcTan(const AX: Double): Double; overload; inline;
function ArcTan(const AX: Single): Single; overload; inline;
function ArcTan2(const AY, AX: Double): Double; overload; inline;
function ArcTan2(const AY, AX: Single): Single; overload; inline;
function Exp(const AX: Double): Double; overload; inline;
function Exp(const AX: Single): Single; overload; inline;
function Ln(const AX: Double): Double; overload; inline;
function Ln(const AX: Single): Single; overload; inline;
function Log2(const AX: Double): Double; overload; inline;
function Log2(const AX: Single): Single; overload; inline;
function Log10(const AX: Double): Double; overload; inline;
function Log10(const AX: Single): Single; overload; inline;
function Power(const ABase, AExponent: Double): Double; overload; inline;
function Power(const ABase, AExponent: Single): Single; overload; inline;
function Sqrt(const AX: Double): Double; overload; inline;
function Sqrt(const AX: Single): Single; overload; inline;

function Sinh(const AX: Double): Double; overload; inline;
function Sinh(const AX: Single): Single; overload; inline;
function Cosh(const AX: Double): Double; overload; inline;
function Cosh(const AX: Single): Single; overload; inline;
function Tanh(const AX: Double): Double; overload; inline;
function Tanh(const AX: Single): Single; overload; inline;
function ArcSinh(const AX: Double): Double; overload; inline;
function ArcSinh(const AX: Single): Single; overload; inline;
function ArcCosh(const AX: Double): Double; overload; inline;
function ArcCosh(const AX: Single): Single; overload; inline;
function ArcTanh(const AX: Double): Double; overload; inline;
function ArcTanh(const AX: Single): Single; overload; inline;

function Sec(const AX: Double): Double; overload; inline;
function Sec(const AX: Single): Single; overload; inline;
function Csc(const AX: Double): Double; overload; inline;
function Csc(const AX: Single): Single; overload; inline;

function LogN(const ABase, AX: Double): Double; overload; inline;
function LogN(const ABase, AX: Single): Single; overload; inline;
function IntPower(const ABase: Double; AExponent: Int64): Double; overload; inline;
function IntPower(const ABase: Single; AExponent: Int64): Single; overload; inline;
function Ldexp(const AX: Double; AExp: Integer): Double; overload; inline;
function Ldexp(const AX: Single; AExp: Integer): Single; overload; inline;

{ vec constructors }
function Vec2f(AX, AY: Single): TVec2f; inline;
function Vec3f(AX, AY, AZ: Single): TVec3f; inline;
function Vec4f(AX, AY, AZ, AW: Single): TVec4f; inline;
function Vec2d(AX, AY: Double): TVec2d; inline;
function Vec3d(AX, AY, AZ: Double): TVec3d; inline;
function Vec4d(AX, AY, AZ, AW: Double): TVec4d; inline;

{ mat constructors (column-based) }
function Mat3f(ACol0, ACol1, ACol2: TVec3f): TMat3f; inline;
function Mat4f(ACol0, ACol1, ACol2, ACol3: TVec4f): TMat4f; inline;
function Mat3d(ACol0, ACol1, ACol2: TVec3d): TMat3d; inline;
function Mat4d(ACol0, ACol1, ACol2, ACol3: TVec4d): TMat4d; inline;

{ mat identity/zero }
function Mat3fIdentity: TMat3f; inline;
function Mat4fIdentity: TMat4f; inline;
function Mat3fZero: TMat3f; inline;
function Mat4fZero: TMat4f; inline;
function Mat3dIdentity: TMat3d; inline;
function Mat4dIdentity: TMat4d; inline;
function Mat3dZero: TMat3d; inline;
function Mat4dZero: TMat4d; inline;

{ quat constructors }
function Quatf(AX, AY, AZ, AW: Single): TQuatf; inline;
function Quatd(AX, AY, AZ, AW: Double): TQuatd; inline;
function QuatfIdentity: TQuatf; inline;
function QuatdIdentity: TQuatd; inline;

{ random }
function RandomCreate(ASeed: UInt64): TRandomState; inline;

implementation

function IsAddOverflow(AA, AB: SizeUInt): Boolean;
begin
  Result := nextpas.core.math.scalar.IsAddOverflow(AA, AB);
end;

function IsAddOverflow(AA, AB: UInt32): Boolean;
begin
  Result := nextpas.core.math.scalar.IsAddOverflow(AA, AB);
end;

function IsMulOverflow(AA, AB: SizeUInt): Boolean;
begin
  Result := nextpas.core.math.scalar.IsMulOverflow(AA, AB);
end;

function IsMulOverflow(AA, AB: UInt32): Boolean;
begin
  Result := nextpas.core.math.scalar.IsMulOverflow(AA, AB);
end;

function Min(AA, AB: SizeUInt): SizeUInt;
begin
  Result := nextpas.core.math.scalar.Min(AA, AB);
end;

function Max(AA, AB: SizeUInt): SizeUInt;
begin
  Result := nextpas.core.math.scalar.Max(AA, AB);
end;

function Min(AA, AB: SizeInt): SizeInt;
begin
  Result := nextpas.core.math.scalar.Min(AA, AB);
end;

function Max(AA, AB: SizeInt): SizeInt;
begin
  Result := nextpas.core.math.scalar.Max(AA, AB);
end;

function Min(AA, AB: Single): Single;
begin
  Result := nextpas.core.math.scalar.Min(AA, AB);
end;

function Max(AA, AB: Single): Single;
begin
  Result := nextpas.core.math.scalar.Max(AA, AB);
end;

function Min(AA, AB: Double): Double;
begin
  Result := nextpas.core.math.scalar.Min(AA, AB);
end;

function Max(AA, AB: Double): Double;
begin
  Result := nextpas.core.math.scalar.Max(AA, AB);
end;

function Clamp(const AValue, AMin, AMax: Single): Single;
begin
  Result := nextpas.core.math.scalar.Clamp(AValue, AMin, AMax);
end;

function Clamp(const AValue, AMin, AMax: Double): Double;
begin
  Result := nextpas.core.math.scalar.Clamp(AValue, AMin, AMax);
end;

function Clamp(const AValue, AMin, AMax: Int32): Int32;
begin
  Result := nextpas.core.math.scalar.Clamp(AValue, AMin, AMax);
end;

function Lerp(const AA, AB, AT: Single): Single;
begin
  Result := nextpas.core.math.scalar.Lerp(AA, AB, AT);
end;

function Lerp(const AA, AB, AT: Double): Double;
begin
  Result := nextpas.core.math.scalar.Lerp(AA, AB, AT);
end;

function InverseLerp(const AA, AB, AValue: Single): Single;
begin
  Result := nextpas.core.math.scalar.InverseLerp(AA, AB, AValue);
end;

function InverseLerp(const AA, AB, AValue: Double): Double;
begin
  Result := nextpas.core.math.scalar.InverseLerp(AA, AB, AValue);
end;

function Wrap(const AValue, AMin, AMax: Single): Single;
begin
  Result := nextpas.core.math.scalar.Wrap(AValue, AMin, AMax);
end;

function Wrap(const AValue, AMin, AMax: Double): Double;
begin
  Result := nextpas.core.math.scalar.Wrap(AValue, AMin, AMax);
end;

function SmoothStep(const AEdge0, AEdge1, AValue: Single): Single;
begin
  Result := nextpas.core.math.scalar.SmoothStep(AEdge0, AEdge1, AValue);
end;

function SmoothStep(const AEdge0, AEdge1, AValue: Double): Double;
begin
  Result := nextpas.core.math.scalar.SmoothStep(AEdge0, AEdge1, AValue);
end;

function Floor(const AValue: Single): Int64;
begin
  Result := nextpas.core.math.scalar.Floor(AValue);
end;

function Floor(const AValue: Double): Int64;
begin
  Result := nextpas.core.math.scalar.Floor(AValue);
end;

function Ceil(const AValue: Single): Int64;
begin
  Result := nextpas.core.math.scalar.Ceil(AValue);
end;

function Ceil(const AValue: Double): Int64;
begin
  Result := nextpas.core.math.scalar.Ceil(AValue);
end;

function Round(const AValue: Single): Int64;
begin
  Result := nextpas.core.math.scalar.Round(AValue);
end;

function Round(const AValue: Double): Int64;
begin
  Result := nextpas.core.math.scalar.Round(AValue);
end;

function Trunc(const AValue: Single): Int64;
begin
  Result := nextpas.core.math.scalar.Trunc(AValue);
end;

function Trunc(const AValue: Double): Int64;
begin
  Result := nextpas.core.math.scalar.Trunc(AValue);
end;

function Frac(const AValue: Single): Single;
begin
  Result := nextpas.core.math.scalar.Frac(AValue);
end;

function Frac(const AValue: Double): Double;
begin
  Result := nextpas.core.math.scalar.Frac(AValue);
end;

function Abs(const AValue: Single): Single;
begin
  Result := nextpas.core.math.scalar.Abs(AValue);
end;

function Abs(const AValue: Double): Double;
begin
  Result := nextpas.core.math.scalar.Abs(AValue);
end;

function Abs(const AValue: Int32): Int32;
begin
  Result := nextpas.core.math.scalar.Abs(AValue);
end;

function Abs(const AValue: Int64): Int64;
begin
  Result := nextpas.core.math.scalar.Abs(AValue);
end;

function Sign(const AValue: Single): Single;
begin
  Result := nextpas.core.math.scalar.Sign(AValue);
end;

function Sign(const AValue: Double): Double;
begin
  Result := nextpas.core.math.scalar.Sign(AValue);
end;

function Sign(const AValue: Int32): Int32;
begin
  Result := nextpas.core.math.scalar.Sign(AValue);
end;

function Sign(const AValue: Int64): Int64;
begin
  Result := nextpas.core.math.scalar.Sign(AValue);
end;

function IsNaN(const AValue: Single): Boolean;
begin
  Result := nextpas.core.math.scalar.IsNaN(AValue);
end;

function IsNaN(const AValue: Double): Boolean;
begin
  Result := nextpas.core.math.scalar.IsNaN(AValue);
end;

function IsInfinite(const AValue: Single): Boolean;
begin
  Result := nextpas.core.math.scalar.IsInfinite(AValue);
end;

function IsInfinite(const AValue: Double): Boolean;
begin
  Result := nextpas.core.math.scalar.IsInfinite(AValue);
end;

function FloatEquals(const AA, AB: Single; const AEpsilon: Single): Boolean;
begin
  Result := nextpas.core.math.scalar.FloatEquals(AA, AB, AEpsilon);
end;

function FloatEquals(const AA, AB: Double; const AEpsilon: Double): Boolean;
begin
  Result := nextpas.core.math.scalar.FloatEquals(AA, AB, AEpsilon);
end;

function FloatIsZero(const AValue: Single; const AEpsilon: Single): Boolean;
begin
  Result := nextpas.core.math.scalar.FloatIsZero(AValue, AEpsilon);
end;

function FloatIsZero(const AValue: Double; const AEpsilon: Double): Boolean;
begin
  Result := nextpas.core.math.scalar.FloatIsZero(AValue, AEpsilon);
end;

function DegToRad(const ADegrees: Single): Single;
begin
  Result := nextpas.core.math.scalar.DegToRad(ADegrees);
end;

function DegToRad(const ADegrees: Double): Double;
begin
  Result := nextpas.core.math.scalar.DegToRad(ADegrees);
end;

function RadToDeg(const ARadians: Single): Single;
begin
  Result := nextpas.core.math.scalar.RadToDeg(ARadians);
end;

function RadToDeg(const ARadians: Double): Double;
begin
  Result := nextpas.core.math.scalar.RadToDeg(ARadians);
end;

function GCD(AA, AB: Int64): Int64;
begin
  Result := nextpas.core.math.scalar.GCD(AA, AB);
end;

function LCM(AA, AB: Int64): Int64;
begin
  Result := nextpas.core.math.scalar.LCM(AA, AB);
end;

function Hypot(const AX, AY: Single): Single;
begin
  Result := nextpas.core.math.scalar.Hypot(AX, AY);
end;

function Hypot(const AX, AY: Double): Double;
begin
  Result := nextpas.core.math.scalar.Hypot(AX, AY);
end;

function Fmod(const AX, AY: Single): Single;
begin
  Result := nextpas.core.math.scalar.Fmod(AX, AY);
end;

function Fmod(const AX, AY: Double): Double;
begin
  Result := nextpas.core.math.scalar.Fmod(AX, AY);
end;

function Sin(const AX: Single): Single;
begin
  Result := nextpas.core.math.trig.Sin(AX);
end;

function Sin(const AX: Double): Double;
begin
  Result := nextpas.core.math.trig.Sin(AX);
end;

function Cos(const AX: Single): Single;
begin
  Result := nextpas.core.math.trig.Cos(AX);
end;

function Cos(const AX: Double): Double;
begin
  Result := nextpas.core.math.trig.Cos(AX);
end;

function Tan(const AX: Single): Single;
begin
  Result := nextpas.core.math.trig.Tan(AX);
end;

function Tan(const AX: Double): Double;
begin
  Result := nextpas.core.math.trig.Tan(AX);
end;

function ArcSin(const AX: Single): Single;
begin
  Result := nextpas.core.math.trig.ArcSin(AX);
end;

function ArcSin(const AX: Double): Double;
begin
  Result := nextpas.core.math.trig.ArcSin(AX);
end;

function ArcCos(const AX: Single): Single;
begin
  Result := nextpas.core.math.trig.ArcCos(AX);
end;

function ArcCos(const AX: Double): Double;
begin
  Result := nextpas.core.math.trig.ArcCos(AX);
end;

function ArcTan(const AX: Single): Single;
begin
  Result := nextpas.core.math.trig.ArcTan(AX);
end;

function ArcTan(const AX: Double): Double;
begin
  Result := nextpas.core.math.trig.ArcTan(AX);
end;

function ArcTan2(const AY, AX: Single): Single;
begin
  Result := nextpas.core.math.trig.ArcTan2(AY, AX);
end;

function ArcTan2(const AY, AX: Double): Double;
begin
  Result := nextpas.core.math.trig.ArcTan2(AY, AX);
end;

function Exp(const AX: Single): Single;
begin
  Result := nextpas.core.math.trig.Exp(AX);
end;

function Exp(const AX: Double): Double;
begin
  Result := nextpas.core.math.trig.Exp(AX);
end;

function Ln(const AX: Single): Single;
begin
  Result := nextpas.core.math.trig.Ln(AX);
end;

function Ln(const AX: Double): Double;
begin
  Result := nextpas.core.math.trig.Ln(AX);
end;

function Log2(const AX: Single): Single;
begin
  Result := nextpas.core.math.trig.Log2(AX);
end;

function Log2(const AX: Double): Double;
begin
  Result := nextpas.core.math.trig.Log2(AX);
end;

function Log10(const AX: Single): Single;
begin
  Result := nextpas.core.math.trig.Log10(AX);
end;

function Log10(const AX: Double): Double;
begin
  Result := nextpas.core.math.trig.Log10(AX);
end;

function Power(const ABase, AExponent: Single): Single;
begin
  Result := nextpas.core.math.trig.Power(ABase, AExponent);
end;

function Power(const ABase, AExponent: Double): Double;
begin
  Result := nextpas.core.math.trig.Power(ABase, AExponent);
end;

function Sqrt(const AX: Double): Double;
begin
  Result := nextpas.core.math.trig.Sqrt(AX);
end;

function Sqrt(const AX: Single): Single;
begin
  Result := nextpas.core.math.trig.Sqrt(AX);
end;

function Sinh(const AX: Double): Double;
begin
  Result := nextpas.core.math.trig.Sinh(AX);
end;

function Sinh(const AX: Single): Single;
begin
  Result := nextpas.core.math.trig.Sinh(AX);
end;

function Cosh(const AX: Double): Double;
begin
  Result := nextpas.core.math.trig.Cosh(AX);
end;

function Cosh(const AX: Single): Single;
begin
  Result := nextpas.core.math.trig.Cosh(AX);
end;

function Tanh(const AX: Double): Double;
begin
  Result := nextpas.core.math.trig.Tanh(AX);
end;

function Tanh(const AX: Single): Single;
begin
  Result := nextpas.core.math.trig.Tanh(AX);
end;

function ArcSinh(const AX: Double): Double;
begin
  Result := nextpas.core.math.trig.ArcSinh(AX);
end;

function ArcSinh(const AX: Single): Single;
begin
  Result := nextpas.core.math.trig.ArcSinh(AX);
end;

function ArcCosh(const AX: Double): Double;
begin
  Result := nextpas.core.math.trig.ArcCosh(AX);
end;

function ArcCosh(const AX: Single): Single;
begin
  Result := nextpas.core.math.trig.ArcCosh(AX);
end;

function ArcTanh(const AX: Double): Double;
begin
  Result := nextpas.core.math.trig.ArcTanh(AX);
end;

function ArcTanh(const AX: Single): Single;
begin
  Result := nextpas.core.math.trig.ArcTanh(AX);
end;

function Sec(const AX: Double): Double;
begin
  Result := nextpas.core.math.trig.Sec(AX);
end;

function Sec(const AX: Single): Single;
begin
  Result := nextpas.core.math.trig.Sec(AX);
end;

function Csc(const AX: Double): Double;
begin
  Result := nextpas.core.math.trig.Csc(AX);
end;

function Csc(const AX: Single): Single;
begin
  Result := nextpas.core.math.trig.Csc(AX);
end;

function LogN(const ABase, AX: Double): Double;
begin
  Result := nextpas.core.math.trig.LogN(ABase, AX);
end;

function LogN(const ABase, AX: Single): Single;
begin
  Result := nextpas.core.math.trig.LogN(ABase, AX);
end;

function IntPower(const ABase: Double; AExponent: Int64): Double;
begin
  Result := nextpas.core.math.trig.IntPower(ABase, AExponent);
end;

function IntPower(const ABase: Single; AExponent: Int64): Single;
begin
  Result := nextpas.core.math.trig.IntPower(ABase, AExponent);
end;

function Ldexp(const AX: Double; AExp: Integer): Double;
begin
  Result := nextpas.core.math.trig.Ldexp(AX, AExp);
end;

function Ldexp(const AX: Single; AExp: Integer): Single;
begin
  Result := nextpas.core.math.trig.Ldexp(AX, AExp);
end;

{ Vec constructors }

function Vec2f(AX, AY: Single): TVec2f;
begin
  Result := nextpas.core.math.vec.Vec2f(AX, AY);
end;

function Vec3f(AX, AY, AZ: Single): TVec3f;
begin
  Result := nextpas.core.math.vec.Vec3f(AX, AY, AZ);
end;

function Vec4f(AX, AY, AZ, AW: Single): TVec4f;
begin
  Result := nextpas.core.math.vec.Vec4f(AX, AY, AZ, AW);
end;

function Vec2d(AX, AY: Double): TVec2d;
begin
  Result := nextpas.core.math.vec.Vec2d(AX, AY);
end;

function Vec3d(AX, AY, AZ: Double): TVec3d;
begin
  Result := nextpas.core.math.vec.Vec3d(AX, AY, AZ);
end;

function Vec4d(AX, AY, AZ, AW: Double): TVec4d;
begin
  Result := nextpas.core.math.vec.Vec4d(AX, AY, AZ, AW);
end;

{ Mat constructors (column-based) }

function Mat3f(ACol0, ACol1, ACol2: TVec3f): TMat3f;
begin
  Result[0, 0] := ACol0.X;
  Result[1, 0] := ACol0.Y;
  Result[2, 0] := ACol0.Z;
  Result[0, 1] := ACol1.X;
  Result[1, 1] := ACol1.Y;
  Result[2, 1] := ACol1.Z;
  Result[0, 2] := ACol2.X;
  Result[1, 2] := ACol2.Y;
  Result[2, 2] := ACol2.Z;
end;

function Mat4f(ACol0, ACol1, ACol2, ACol3: TVec4f): TMat4f;
begin
  Result[0, 0] := ACol0.X;
  Result[1, 0] := ACol0.Y;
  Result[2, 0] := ACol0.Z;
  Result[3, 0] := ACol0.W;
  Result[0, 1] := ACol1.X;
  Result[1, 1] := ACol1.Y;
  Result[2, 1] := ACol1.Z;
  Result[3, 1] := ACol1.W;
  Result[0, 2] := ACol2.X;
  Result[1, 2] := ACol2.Y;
  Result[2, 2] := ACol2.Z;
  Result[3, 2] := ACol2.W;
  Result[0, 3] := ACol3.X;
  Result[1, 3] := ACol3.Y;
  Result[2, 3] := ACol3.Z;
  Result[3, 3] := ACol3.W;
end;

function Mat3d(ACol0, ACol1, ACol2: TVec3d): TMat3d;
begin
  Result[0, 0] := ACol0.X;
  Result[1, 0] := ACol0.Y;
  Result[2, 0] := ACol0.Z;
  Result[0, 1] := ACol1.X;
  Result[1, 1] := ACol1.Y;
  Result[2, 1] := ACol1.Z;
  Result[0, 2] := ACol2.X;
  Result[1, 2] := ACol2.Y;
  Result[2, 2] := ACol2.Z;
end;

function Mat4d(ACol0, ACol1, ACol2, ACol3: TVec4d): TMat4d;
begin
  Result[0, 0] := ACol0.X;
  Result[1, 0] := ACol0.Y;
  Result[2, 0] := ACol0.Z;
  Result[3, 0] := ACol0.W;
  Result[0, 1] := ACol1.X;
  Result[1, 1] := ACol1.Y;
  Result[2, 1] := ACol1.Z;
  Result[3, 1] := ACol1.W;
  Result[0, 2] := ACol2.X;
  Result[1, 2] := ACol2.Y;
  Result[2, 2] := ACol2.Z;
  Result[3, 2] := ACol2.W;
  Result[0, 3] := ACol3.X;
  Result[1, 3] := ACol3.Y;
  Result[2, 3] := ACol3.Z;
  Result[3, 3] := ACol3.W;
end;

{ Mat identity/zero }

function Mat3fIdentity: TMat3f;
begin
  Result := nextpas.core.math.mat.base.Mat3fIdentity;
end;

function Mat4fIdentity: TMat4f;
begin
  Result := nextpas.core.math.mat.base.Mat4fIdentity;
end;

function Mat3fZero: TMat3f;
begin
  Result := nextpas.core.math.mat.base.Mat3fZero;
end;

function Mat4fZero: TMat4f;
begin
  Result := nextpas.core.math.mat.base.Mat4fZero;
end;

function Mat3dIdentity: TMat3d;
begin
  Result := nextpas.core.math.mat.base.Mat3dIdentity;
end;

function Mat4dIdentity: TMat4d;
begin
  Result := nextpas.core.math.mat.base.Mat4dIdentity;
end;

function Mat3dZero: TMat3d;
begin
  Result := nextpas.core.math.mat.base.Mat3dZero;
end;

function Mat4dZero: TMat4d;
begin
  Result := nextpas.core.math.mat.base.Mat4dZero;
end;

{ Quat constructors }

function Quatf(AX, AY, AZ, AW: Single): TQuatf;
begin
  Result := nextpas.core.math.quat.Quatf(AX, AY, AZ, AW);
end;

function Quatd(AX, AY, AZ, AW: Double): TQuatd;
begin
  Result := nextpas.core.math.quat.Quatd(AX, AY, AZ, AW);
end;

function QuatfIdentity: TQuatf;
begin
  Result := nextpas.core.math.quat.base.QuatfIdentity;
end;

function QuatdIdentity: TQuatd;
begin
  Result := nextpas.core.math.quat.base.QuatdIdentity;
end;

{ Random }

function RandomCreate(ASeed: UInt64): TRandomState;
begin
  Result := nextpas.core.math.random.RandomCreate(ASeed);
end;

end.
