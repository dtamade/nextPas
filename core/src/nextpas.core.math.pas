unit nextpas.core.math;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.math.base,
  nextpas.core.math.scalar,
  nextpas.core.math.trig,
  nextpas.core.math.vec,
  nextpas.core.math.mat,
  nextpas.core.math.quat,
  nextpas.core.math.transform,
  nextpas.core.math.easing,
  nextpas.core.math.random;

type
  { vec types }
  TVec2f = nextpas.core.math.vec.TVec2f;
  TVec2d = nextpas.core.math.vec.TVec2d;
  TVec3f = nextpas.core.math.vec.TVec3f;
  TVec3d = nextpas.core.math.vec.TVec3d;
  TVec4f = nextpas.core.math.vec.TVec4f;
  TVec4d = nextpas.core.math.vec.TVec4d;
  { mat types }
  TMat3f = nextpas.core.math.mat.TMat3f;
  TMat3d = nextpas.core.math.mat.TMat3d;
  TMat4f = nextpas.core.math.mat.TMat4f;
  TMat4d = nextpas.core.math.mat.TMat4d;
  { quat types }
  TQuatf = nextpas.core.math.quat.TQuatf;
  TQuatd = nextpas.core.math.quat.TQuatd;
  { easing/random types }
  TEasingFunction = nextpas.core.math.easing.TEasingFunction;
  TRandomState = nextpas.core.math.random.TRandomState;
  TRandomGen = nextpas.core.math.random.TRandomGen;
  TNoiseGen = nextpas.core.math.random.TNoiseGen;

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
{$IF SizeOf(Extended) > SizeOf(Double)}
function Fmod(const AX, AY: Extended): Extended; overload; inline;
{$ENDIF}

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

function Ortho(const ALeft, ARight, ABottom, ATop, ANear, AFar: Single): TMat4f; overload; inline;
function Ortho(const ALeft, ARight, ABottom, ATop, ANear, AFar: Double): TMat4d; overload; inline;
function Perspective(const AFovYRad, AAspect, ANear, AFar: Single): TMat4f; overload; inline;
function Perspective(const AFovYRad, AAspect, ANear, AFar: Double): TMat4d; overload; inline;
function LookAt(const AEye, ATarget, AUp: TVec3f): TMat4f; overload; inline;
function LookAt(const AEye, ATarget, AUp: TVec3d): TMat4d; overload; inline;
function Translate(const AX, AY, AZ: Single): TMat4f; overload; inline;
function Translate(const AX, AY, AZ: Double): TMat4d; overload; inline;
function Scale(const AX, AY, AZ: Single): TMat4f; overload; inline;
function Scale(const AX, AY, AZ: Double): TMat4d; overload; inline;
function RotateX(const ARadians: Single): TMat4f; overload; inline;
function RotateX(const ARadians: Double): TMat4d; overload; inline;
function RotateY(const ARadians: Single): TMat4f; overload; inline;
function RotateY(const ARadians: Double): TMat4d; overload; inline;
function RotateZ(const ARadians: Single): TMat4f; overload; inline;
function RotateZ(const ARadians: Double): TMat4d; overload; inline;
function Camera2D(const ACenterX, ACenterY, AZoom: Single;
  const AViewportWidth, AViewportHeight: Integer): TMat4f; overload; inline;
function Camera2D(const ACenterX, ACenterY, AZoom: Double;
  const AViewportWidth, AViewportHeight: Integer): TMat4d; overload; inline;

function EaseLinear(const AT: Double): Double; inline;
function EaseInQuad(const AT: Double): Double; inline;
function EaseOutQuad(const AT: Double): Double; inline;
function EaseInOutQuad(const AT: Double): Double; inline;
function EaseInCubic(const AT: Double): Double; inline;
function EaseOutCubic(const AT: Double): Double; inline;
function EaseInOutCubic(const AT: Double): Double; inline;
function EaseInQuart(const AT: Double): Double; inline;
function EaseOutQuart(const AT: Double): Double; inline;
function EaseInOutQuart(const AT: Double): Double; inline;
function EaseInExpo(const AT: Double): Double; inline;
function EaseOutExpo(const AT: Double): Double; inline;
function EaseInOutExpo(const AT: Double): Double; inline;
function EaseInElastic(const AT: Double): Double; inline;
function EaseOutElastic(const AT: Double): Double; inline;
function EaseInOutElastic(const AT: Double): Double; inline;
function EaseInBack(const AT: Double): Double; inline;
function EaseOutBack(const AT: Double): Double; inline;
function EaseInOutBack(const AT: Double): Double; inline;
function EaseInBounce(const AT: Double): Double; inline;
function EaseOutBounce(const AT: Double): Double; inline;
function EaseInOutBounce(const AT: Double): Double; inline;

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

{$IF SizeOf(Extended) > SizeOf(Double)}
function Fmod(const AX, AY: Extended): Extended;
begin
  Result := nextpas.core.math.scalar.Fmod(AX, AY);
end;
{$ENDIF}

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

function Ortho(const ALeft, ARight, ABottom, ATop, ANear, AFar: Single): TMat4f;
begin
  Result := nextpas.core.math.transform.Ortho(ALeft, ARight, ABottom, ATop, ANear, AFar);
end;

function Ortho(const ALeft, ARight, ABottom, ATop, ANear, AFar: Double): TMat4d;
begin
  Result := nextpas.core.math.transform.Ortho(ALeft, ARight, ABottom, ATop, ANear, AFar);
end;

function Perspective(const AFovYRad, AAspect, ANear, AFar: Single): TMat4f;
begin
  Result := nextpas.core.math.transform.Perspective(AFovYRad, AAspect, ANear, AFar);
end;

function Perspective(const AFovYRad, AAspect, ANear, AFar: Double): TMat4d;
begin
  Result := nextpas.core.math.transform.Perspective(AFovYRad, AAspect, ANear, AFar);
end;

function LookAt(const AEye, ATarget, AUp: TVec3f): TMat4f;
begin
  Result := nextpas.core.math.transform.LookAt(AEye, ATarget, AUp);
end;

function LookAt(const AEye, ATarget, AUp: TVec3d): TMat4d;
begin
  Result := nextpas.core.math.transform.LookAt(AEye, ATarget, AUp);
end;

function Translate(const AX, AY, AZ: Single): TMat4f;
begin
  Result := nextpas.core.math.transform.Translate(AX, AY, AZ);
end;

function Translate(const AX, AY, AZ: Double): TMat4d;
begin
  Result := nextpas.core.math.transform.Translate(AX, AY, AZ);
end;

function Scale(const AX, AY, AZ: Single): TMat4f;
begin
  Result := nextpas.core.math.transform.Scale(AX, AY, AZ);
end;

function Scale(const AX, AY, AZ: Double): TMat4d;
begin
  Result := nextpas.core.math.transform.Scale(AX, AY, AZ);
end;

function RotateX(const ARadians: Single): TMat4f;
begin
  Result := nextpas.core.math.transform.RotateX(ARadians);
end;

function RotateX(const ARadians: Double): TMat4d;
begin
  Result := nextpas.core.math.transform.RotateX(ARadians);
end;

function RotateY(const ARadians: Single): TMat4f;
begin
  Result := nextpas.core.math.transform.RotateY(ARadians);
end;

function RotateY(const ARadians: Double): TMat4d;
begin
  Result := nextpas.core.math.transform.RotateY(ARadians);
end;

function RotateZ(const ARadians: Single): TMat4f;
begin
  Result := nextpas.core.math.transform.RotateZ(ARadians);
end;

function RotateZ(const ARadians: Double): TMat4d;
begin
  Result := nextpas.core.math.transform.RotateZ(ARadians);
end;

function Camera2D(const ACenterX, ACenterY, AZoom: Single;
  const AViewportWidth, AViewportHeight: Integer): TMat4f;
begin
  Result := nextpas.core.math.transform.Camera2D(ACenterX, ACenterY, AZoom, AViewportWidth,
    AViewportHeight);
end;

function Camera2D(const ACenterX, ACenterY, AZoom: Double;
  const AViewportWidth, AViewportHeight: Integer): TMat4d;
begin
  Result := nextpas.core.math.transform.Camera2D(ACenterX, ACenterY, AZoom, AViewportWidth,
    AViewportHeight);
end;

function EaseLinear(const AT: Double): Double;
begin
  Result := nextpas.core.math.easing.EaseLinear(AT);
end;

function EaseInQuad(const AT: Double): Double;
begin
  Result := nextpas.core.math.easing.EaseInQuad(AT);
end;

function EaseOutQuad(const AT: Double): Double;
begin
  Result := nextpas.core.math.easing.EaseOutQuad(AT);
end;

function EaseInOutQuad(const AT: Double): Double;
begin
  Result := nextpas.core.math.easing.EaseInOutQuad(AT);
end;

function EaseInCubic(const AT: Double): Double;
begin
  Result := nextpas.core.math.easing.EaseInCubic(AT);
end;

function EaseOutCubic(const AT: Double): Double;
begin
  Result := nextpas.core.math.easing.EaseOutCubic(AT);
end;

function EaseInOutCubic(const AT: Double): Double;
begin
  Result := nextpas.core.math.easing.EaseInOutCubic(AT);
end;

function EaseInQuart(const AT: Double): Double;
begin
  Result := nextpas.core.math.easing.EaseInQuart(AT);
end;

function EaseOutQuart(const AT: Double): Double;
begin
  Result := nextpas.core.math.easing.EaseOutQuart(AT);
end;

function EaseInOutQuart(const AT: Double): Double;
begin
  Result := nextpas.core.math.easing.EaseInOutQuart(AT);
end;

function EaseInExpo(const AT: Double): Double;
begin
  Result := nextpas.core.math.easing.EaseInExpo(AT);
end;

function EaseOutExpo(const AT: Double): Double;
begin
  Result := nextpas.core.math.easing.EaseOutExpo(AT);
end;

function EaseInOutExpo(const AT: Double): Double;
begin
  Result := nextpas.core.math.easing.EaseInOutExpo(AT);
end;

function EaseInElastic(const AT: Double): Double;
begin
  Result := nextpas.core.math.easing.EaseInElastic(AT);
end;

function EaseOutElastic(const AT: Double): Double;
begin
  Result := nextpas.core.math.easing.EaseOutElastic(AT);
end;

function EaseInOutElastic(const AT: Double): Double;
begin
  Result := nextpas.core.math.easing.EaseInOutElastic(AT);
end;

function EaseInBack(const AT: Double): Double;
begin
  Result := nextpas.core.math.easing.EaseInBack(AT);
end;

function EaseOutBack(const AT: Double): Double;
begin
  Result := nextpas.core.math.easing.EaseOutBack(AT);
end;

function EaseInOutBack(const AT: Double): Double;
begin
  Result := nextpas.core.math.easing.EaseInOutBack(AT);
end;

function EaseInBounce(const AT: Double): Double;
begin
  Result := nextpas.core.math.easing.EaseInBounce(AT);
end;

function EaseOutBounce(const AT: Double): Double;
begin
  Result := nextpas.core.math.easing.EaseOutBounce(AT);
end;

function EaseInOutBounce(const AT: Double): Double;
begin
  Result := nextpas.core.math.easing.EaseInOutBounce(AT);
end;

end.
