unit nextpas.core.math;

{$I nextpas.core.settings.inc}

{ Math facade unit - provides flat API for all math functions.
  This unit re-exports functions from sub-units for convenience.
  For better compile times or to avoid the 1200+ line facade,
  consider using specific sub-units directly:
  - nextpas.core.math.scalar (basic math functions)
  - nextpas.core.math.trig (trigonometric functions)
  - nextpas.core.math.vec (vector types and operations)
  - nextpas.core.math.mat (matrix types and operations)
  - nextpas.core.math.quat (quaternion types and operations)
  - nextpas.core.math.transform (transformation matrices)
  - nextpas.core.math.easing (easing functions)
  - nextpas.core.math.random (random number generation)
  - nextpas.core.math.batch (batch operations)
}

interface

uses
  nextpas.core.math.base,
  nextpas.core.math.scalar,
  nextpas.core.math.trig,
  nextpas.core.math.vec,
  nextpas.core.math.vec.batch,
  nextpas.core.math.mat,
  nextpas.core.math.quat,
  nextpas.core.math.transform,
  nextpas.core.math.easing,
  nextpas.core.math.random,
  nextpas.core.math.batch;

const
  PI_VALUE = nextpas.core.math.base.PI_VALUE;
  TWO_PI = nextpas.core.math.base.TWO_PI;
  HALF_PI = nextpas.core.math.base.HALF_PI;
  DEG_TO_RAD = nextpas.core.math.base.DEG_TO_RAD;
  RAD_TO_DEG = nextpas.core.math.base.RAD_TO_DEG;

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

function Vec3fExtend(const AVec: TVec3f; const AW: Single): TVec4f; inline;
function Vec4fTruncate(const AVec: TVec4f): TVec3f; inline;
function Vec3dExtend(const AVec: TVec3d; const AW: Double): TVec4d; inline;
function Vec4dTruncate(const AVec: TVec4d): TVec3d; inline;

{ Batch operations - SIMD-friendly vectorized operations }
function BatchDot(const ALeft, ARight: array of TVec2f;
                  var AResults: array of Single): SizeInt; overload;
function BatchDot(const ALeft, ARight: array of TVec3f;
                  var AResults: array of Single): SizeInt; overload;
function BatchDot(const ALeft, ARight: array of TVec4f;
                  var AResults: array of Single): SizeInt; overload;

function BatchNormalize(var AVectors: array of TVec2f): SizeInt; overload;
function BatchNormalize(var AVectors: array of TVec3f): SizeInt; overload;
function BatchNormalize(var AVectors: array of TVec4f): SizeInt; overload;
function BatchNormalize(const ASource: array of TVec3f;
                        var ADest: array of TVec3f): SizeInt; overload;

function BatchTransform(const AMatrix: TMat3f;
                        const ASource: array of TVec2f;
                        var ADest: array of TVec2f): SizeInt; overload;
function BatchTransform(const AMatrix: TMat4f;
                        const ASource: array of TVec3f;
                        var ADest: array of TVec3f): SizeInt; overload;

function BatchLerp(const AStart, AEnd: array of TVec3f;
                   const AT: Single;
                   var ADest: array of TVec3f): SizeInt; overload;

function BatchClamp(const AVectors: array of TVec3f;
                    const AMin, AMax: TVec3f;
                    var ADest: array of TVec3f): SizeInt; overload;

{ Vector batch Double (M-V1 minimal parity with F32 core set) }
function BatchDot(const ALeft, ARight: array of TVec2d;
                  var AResults: array of Double): SizeInt; overload;
function BatchDot(const ALeft, ARight: array of TVec3d;
                  var AResults: array of Double): SizeInt; overload;
function BatchDot(const ALeft, ARight: array of TVec4d;
                  var AResults: array of Double): SizeInt; overload;

function BatchNormalize(var AVectors: array of TVec2d): SizeInt; overload;
function BatchNormalize(var AVectors: array of TVec3d): SizeInt; overload;
function BatchNormalize(var AVectors: array of TVec4d): SizeInt; overload;
function BatchNormalize(const ASource: array of TVec3d;
                        var ADest: array of TVec3d): SizeInt; overload;

function BatchTransform(const AMatrix: TMat3d;
                        const ASource: array of TVec2d;
                        var ADest: array of TVec2d): SizeInt; overload;
function BatchTransform(const AMatrix: TMat4d;
                        const ASource: array of TVec3d;
                        var ADest: array of TVec3d): SizeInt; overload;

function BatchLerp(const AStart, AEnd: array of TVec3d;
                   const AT: Double;
                   var ADest: array of TVec3d): SizeInt; overload;

function BatchClamp(const AVectors: array of TVec3d;
                    const AMin, AMax: TVec3d;
                    var ADest: array of TVec3d): SizeInt; overload;

{ Batch scalar operations }
function BatchSinF32(const AInput: array of Single;
                     var AOutput: array of Single): SizeInt;
function BatchCosF32(const AInput: array of Single;
                     var AOutput: array of Single): SizeInt;
function BatchSinCosF32(const AInput: array of Single;
                        var ASinOutput, ACosOutput: array of Single): SizeInt;
function BatchTanF32(const AInput: array of Single;
                     var AOutput: array of Single): SizeInt;
function BatchExpF32(const AInput: array of Single;
                     var AOutput: array of Single): SizeInt;
function BatchLnF32(const AInput: array of Single;
                    var AOutput: array of Single): SizeInt;
function BatchLogF32(const AInput: array of Single;
                     var AOutput: array of Single): SizeInt;
function TryBatchLnF32(const AInput: array of Single;
                       var AOutput: array of Single;
                       out ACount: SizeInt): Boolean;
function BatchLog10F32(const AInput: array of Single;
                      var AOutput: array of Single): SizeInt;
function BatchLog2F32(const AInput: array of Single;
                     var AOutput: array of Single): SizeInt;
function BatchSqrtF32(const AInput: array of Single;
                     var AOutput: array of Single): SizeInt;
function BatchAbsF32(const AInput: array of Single;
                    var AOutput: array of Single): SizeInt;
function BatchNegF32(const AInput: array of Single;
                    var AOutput: array of Single): SizeInt;
function BatchCeilF32(const AInput: array of Single;
                     var AOutput: array of Single): SizeInt;
function BatchFloorF32(const AInput: array of Single;
                      var AOutput: array of Single): SizeInt;
function BatchRoundF32(const AInput: array of Single;
                      var AOutput: array of Single): SizeInt;
function BatchTruncF32(const AInput: array of Single;
                      var AOutput: array of Single): SizeInt;
function BatchLerpF32(const AStart, AEnd: array of Single;
                      const AT: Single;
                      var AOutput: array of Single): SizeInt;
function BatchClampF32(const AInput: array of Single;
                       const AMin, AMax: Single;
                       var AOutput: array of Single): SizeInt;
function BatchScaleOffsetF32(const AInput: array of Single;
                             const AScale, AOffset: Single;
                             var AOutput: array of Single): SizeInt;

function BatchSinF64(const AInput: array of Double;
                     var AOutput: array of Double): SizeInt;
function BatchCosF64(const AInput: array of Double;
                     var AOutput: array of Double): SizeInt;
function BatchSinCosF64(const AInput: array of Double;
                        var ASinOutput, ACosOutput: array of Double): SizeInt;
function BatchTanF64(const AInput: array of Double;
                     var AOutput: array of Double): SizeInt;
function BatchExpF64(const AInput: array of Double;
                     var AOutput: array of Double): SizeInt;
function BatchLnF64(const AInput: array of Double;
                    var AOutput: array of Double): SizeInt;
function BatchLogF64(const AInput: array of Double;
                     var AOutput: array of Double): SizeInt;
function TryBatchLnF64(const AInput: array of Double;
                       var AOutput: array of Double;
                       out ACount: SizeInt): Boolean;
function BatchLog10F64(const AInput: array of Double;
                       var AOutput: array of Double): SizeInt;
function BatchLog2F64(const AInput: array of Double;
                      var AOutput: array of Double): SizeInt;
function BatchSqrtF64(const AInput: array of Double;
                      var AOutput: array of Double): SizeInt;
function BatchAbsF64(const AInput: array of Double;
                     var AOutput: array of Double): SizeInt;
function BatchNegF64(const AInput: array of Double;
                     var AOutput: array of Double): SizeInt;
function BatchCeilF64(const AInput: array of Double;
                      var AOutput: array of Double): SizeInt;
function BatchFloorF64(const AInput: array of Double;
                       var AOutput: array of Double): SizeInt;
function BatchRoundF64(const AInput: array of Double;
                       var AOutput: array of Double): SizeInt;
function BatchTruncF64(const AInput: array of Double;
                       var AOutput: array of Double): SizeInt;
function BatchLerpF64(const AStart, AEnd: array of Double;
                      const AT: Double;
                      var AOutput: array of Double): SizeInt;
function BatchClampF64(const AInput: array of Double;
                       const AMin, AMax: Double;
                       var AOutput: array of Double): SizeInt;
function BatchScaleOffsetF64(const AInput: array of Double;
                             const AScale, AOffset: Double;
                             var AOutput: array of Double): SizeInt;

{ 32 位目标 SizeUInt≡UInt32（LongWord），SizeUInt 重载与 UInt32 版撞签名，
  仅 64 位声明；调用方传 SizeUInt 时自动落到 UInt32 重载 }
{$IF DEFINED(CPU64)}
function IsAddOverflow(AA, AB: SizeUInt): Boolean; overload; inline;
{$ENDIF}
function IsAddOverflow(AA, AB: UInt32): Boolean; overload; inline;
{$IF DEFINED(CPU64)}
function IsMulOverflow(AA, AB: SizeUInt): Boolean; overload; inline;
{$ENDIF}
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
function NaN: Double; inline;
function Infinity: Double; inline;
function NegInfinity: Double; inline;
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

function Sum(const AData: array of Double): Double; overload; inline;
function Sum(const AData: array of Single): Single; overload; inline;
function SumToDouble(const AData: array of Single): Double; inline;
function SumInt(const AData: array of Integer): Int64; inline;
function Mean(const AData: array of Double): Double; overload; inline;
function Mean(const AData: array of Single): Single; overload; inline;
function Variance(const AData: array of Double): Double; overload; inline;
function Variance(const AData: array of Single): Single; overload; inline;
function PopnVariance(const AData: array of Double): Double; overload; inline;
function PopnVariance(const AData: array of Single): Single; overload; inline;
function StdDev(const AData: array of Double): Double; overload; inline;
function StdDev(const AData: array of Single): Single; overload; inline;
function PopnStdDev(const AData: array of Double): Double; overload; inline;
function PopnStdDev(const AData: array of Single): Single; overload; inline;
function TotalVariance(const AData: array of Double): Double; overload; inline;
function TotalVariance(const AData: array of Single): Single; overload; inline;
function SumSquaredDeviations(const AData: array of Double): Double; overload; inline;
function SumSquaredDeviations(const AData: array of Single): Single; overload; inline;

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
function Sqrt(const AX: Single): Single; overload;

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
function Camera2D(const ACenterX, ACenterY, AZoom: Single;
  const AViewportWidth, AViewportHeight: Integer;
  const ANear, AFar: Single): TMat4f; overload; inline;
function Camera2D(const ACenterX, ACenterY, AZoom: Double;
  const AViewportWidth, AViewportHeight: Integer;
  const ANear, AFar: Double): TMat4d; overload; inline;

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

{ ── FPU Exception Control (x86_64 MXCSR + x87 CW) ────────────────────────── }
{ Replaces Math.GetExceptionMask/SetExceptionMask — no FPC Math dependency. }
{ Must cover both SSE (MXCSR) and x87 control word: SIMD batch tails use fsin/fyl2x. }

type
  TFPUException = (
    exInvalidOp, exDenormalized, exZeroDivide,
    exOverflow, exUnderflow, exPrecision
  );
  TFPUExceptionMask = set of TFPUException;

function GetExceptionMask: TFPUExceptionMask;
procedure SetExceptionMask(const AMask: TFPUExceptionMask);

implementation

function Vec3fExtend(const AVec: TVec3f; const AW: Single): TVec4f;
begin
  Result := nextpas.core.math.vec.Vec3fExtend(AVec, AW);
end;

function Vec4fTruncate(const AVec: TVec4f): TVec3f;
begin
  Result := nextpas.core.math.vec.Vec4fTruncate(AVec);
end;

function Vec3dExtend(const AVec: TVec3d; const AW: Double): TVec4d;
begin
  Result := nextpas.core.math.vec.Vec3dExtend(AVec, AW);
end;

function Vec4dTruncate(const AVec: TVec4d): TVec3d;
begin
  Result := nextpas.core.math.vec.Vec4dTruncate(AVec);
end;

{ Batch operations }

function BatchDot(const ALeft, ARight: array of TVec2f;
                  var AResults: array of Single): SizeInt;
begin
  Result := nextpas.core.math.vec.batch.BatchDot(ALeft, ARight, AResults);
end;

function BatchDot(const ALeft, ARight: array of TVec3f;
                  var AResults: array of Single): SizeInt;
begin
  Result := nextpas.core.math.vec.batch.BatchDot(ALeft, ARight, AResults);
end;

function BatchDot(const ALeft, ARight: array of TVec4f;
                  var AResults: array of Single): SizeInt;
begin
  Result := nextpas.core.math.vec.batch.BatchDot(ALeft, ARight, AResults);
end;

function BatchNormalize(var AVectors: array of TVec2f): SizeInt;
begin
  Result := nextpas.core.math.vec.batch.BatchNormalize(AVectors);
end;

function BatchNormalize(var AVectors: array of TVec3f): SizeInt;
begin
  Result := nextpas.core.math.vec.batch.BatchNormalize(AVectors);
end;

function BatchNormalize(var AVectors: array of TVec4f): SizeInt;
begin
  Result := nextpas.core.math.vec.batch.BatchNormalize(AVectors);
end;

function BatchNormalize(const ASource: array of TVec3f;
                        var ADest: array of TVec3f): SizeInt;
begin
  Result := nextpas.core.math.vec.batch.BatchNormalize(ASource, ADest);
end;

function BatchTransform(const AMatrix: TMat3f;
                        const ASource: array of TVec2f;
                        var ADest: array of TVec2f): SizeInt;
begin
  Result := nextpas.core.math.vec.batch.BatchTransform(AMatrix, ASource, ADest);
end;

function BatchTransform(const AMatrix: TMat4f;
                        const ASource: array of TVec3f;
                        var ADest: array of TVec3f): SizeInt;
begin
  Result := nextpas.core.math.vec.batch.BatchTransform(AMatrix, ASource, ADest);
end;

function BatchLerp(const AStart, AEnd: array of TVec3f;
                   const AT: Single;
                   var ADest: array of TVec3f): SizeInt;
begin
  Result := nextpas.core.math.vec.batch.BatchLerp(AStart, AEnd, AT, ADest);
end;

function BatchClamp(const AVectors: array of TVec3f;
                    const AMin, AMax: TVec3f;
                    var ADest: array of TVec3f): SizeInt;
begin
  Result := nextpas.core.math.vec.batch.BatchClamp(AVectors, AMin, AMax, ADest);
end;

function BatchDot(const ALeft, ARight: array of TVec2d;
                  var AResults: array of Double): SizeInt;
begin
  Result := nextpas.core.math.vec.batch.BatchDot(ALeft, ARight, AResults);
end;

function BatchDot(const ALeft, ARight: array of TVec3d;
                  var AResults: array of Double): SizeInt;
begin
  Result := nextpas.core.math.vec.batch.BatchDot(ALeft, ARight, AResults);
end;

function BatchDot(const ALeft, ARight: array of TVec4d;
                  var AResults: array of Double): SizeInt;
begin
  Result := nextpas.core.math.vec.batch.BatchDot(ALeft, ARight, AResults);
end;

function BatchNormalize(var AVectors: array of TVec2d): SizeInt;
begin
  Result := nextpas.core.math.vec.batch.BatchNormalize(AVectors);
end;

function BatchNormalize(var AVectors: array of TVec3d): SizeInt;
begin
  Result := nextpas.core.math.vec.batch.BatchNormalize(AVectors);
end;

function BatchNormalize(var AVectors: array of TVec4d): SizeInt;
begin
  Result := nextpas.core.math.vec.batch.BatchNormalize(AVectors);
end;

function BatchNormalize(const ASource: array of TVec3d;
                        var ADest: array of TVec3d): SizeInt;
begin
  Result := nextpas.core.math.vec.batch.BatchNormalize(ASource, ADest);
end;

function BatchTransform(const AMatrix: TMat3d;
                        const ASource: array of TVec2d;
                        var ADest: array of TVec2d): SizeInt;
begin
  Result := nextpas.core.math.vec.batch.BatchTransform(AMatrix, ASource, ADest);
end;

function BatchTransform(const AMatrix: TMat4d;
                        const ASource: array of TVec3d;
                        var ADest: array of TVec3d): SizeInt;
begin
  Result := nextpas.core.math.vec.batch.BatchTransform(AMatrix, ASource, ADest);
end;

function BatchLerp(const AStart, AEnd: array of TVec3d;
                   const AT: Double;
                   var ADest: array of TVec3d): SizeInt;
begin
  Result := nextpas.core.math.vec.batch.BatchLerp(AStart, AEnd, AT, ADest);
end;

function BatchClamp(const AVectors: array of TVec3d;
                    const AMin, AMax: TVec3d;
                    var ADest: array of TVec3d): SizeInt;
begin
  Result := nextpas.core.math.vec.batch.BatchClamp(AVectors, AMin, AMax, ADest);
end;

{ Batch scalar operations }

function BatchSinF32(const AInput: array of Single;
                     var AOutput: array of Single): SizeInt;
begin
  Result := nextpas.core.math.batch.BatchSinF32(AInput, AOutput);
end;

function BatchCosF32(const AInput: array of Single;
                     var AOutput: array of Single): SizeInt;
begin
  Result := nextpas.core.math.batch.BatchCosF32(AInput, AOutput);
end;

function BatchSinCosF32(const AInput: array of Single;
                        var ASinOutput, ACosOutput: array of Single): SizeInt;
begin
  Result := nextpas.core.math.batch.BatchSinCosF32(AInput, ASinOutput, ACosOutput);
end;

function BatchTanF32(const AInput: array of Single;
                     var AOutput: array of Single): SizeInt;
begin
  Result := nextpas.core.math.batch.BatchTanF32(AInput, AOutput);
end;

function BatchExpF32(const AInput: array of Single;
                     var AOutput: array of Single): SizeInt;
begin
  Result := nextpas.core.math.batch.BatchExpF32(AInput, AOutput);
end;

function BatchLnF32(const AInput: array of Single;
                    var AOutput: array of Single): SizeInt;
begin
  Result := nextpas.core.math.batch.BatchLnF32(AInput, AOutput);
end;

function BatchLogF32(const AInput: array of Single;
                     var AOutput: array of Single): SizeInt;
begin
  Result := nextpas.core.math.batch.BatchLogF32(AInput, AOutput);
end;

function TryBatchLnF32(const AInput: array of Single;
                       var AOutput: array of Single;
                       out ACount: SizeInt): Boolean;
begin
  Result := nextpas.core.math.batch.TryBatchLnF32(AInput, AOutput, ACount);
end;

function BatchLog10F32(const AInput: array of Single;
                      var AOutput: array of Single): SizeInt;
begin
  Result := nextpas.core.math.batch.BatchLog10F32(AInput, AOutput);
end;

function BatchLog2F32(const AInput: array of Single;
                     var AOutput: array of Single): SizeInt;
begin
  Result := nextpas.core.math.batch.BatchLog2F32(AInput, AOutput);
end;

function BatchSqrtF32(const AInput: array of Single;
                     var AOutput: array of Single): SizeInt;
begin
  Result := nextpas.core.math.batch.BatchSqrtF32(AInput, AOutput);
end;

function BatchAbsF32(const AInput: array of Single;
                    var AOutput: array of Single): SizeInt;
begin
  Result := nextpas.core.math.batch.BatchAbsF32(AInput, AOutput);
end;

function BatchNegF32(const AInput: array of Single;
                    var AOutput: array of Single): SizeInt;
begin
  Result := nextpas.core.math.batch.BatchNegF32(AInput, AOutput);
end;

function BatchCeilF32(const AInput: array of Single;
                     var AOutput: array of Single): SizeInt;
begin
  Result := nextpas.core.math.batch.BatchCeilF32(AInput, AOutput);
end;

function BatchFloorF32(const AInput: array of Single;
                      var AOutput: array of Single): SizeInt;
begin
  Result := nextpas.core.math.batch.BatchFloorF32(AInput, AOutput);
end;

function BatchRoundF32(const AInput: array of Single;
                      var AOutput: array of Single): SizeInt;
begin
  Result := nextpas.core.math.batch.BatchRoundF32(AInput, AOutput);
end;

function BatchTruncF32(const AInput: array of Single;
                      var AOutput: array of Single): SizeInt;
begin
  Result := nextpas.core.math.batch.BatchTruncF32(AInput, AOutput);
end;

function BatchLerpF32(const AStart, AEnd: array of Single;
                      const AT: Single;
                      var AOutput: array of Single): SizeInt;
begin
  Result := nextpas.core.math.batch.BatchLerpF32(AStart, AEnd, AT, AOutput);
end;

function BatchClampF32(const AInput: array of Single;
                       const AMin, AMax: Single;
                       var AOutput: array of Single): SizeInt;
begin
  Result := nextpas.core.math.batch.BatchClampF32(AInput, AMin, AMax, AOutput);
end;

function BatchScaleOffsetF32(const AInput: array of Single;
                             const AScale, AOffset: Single;
                             var AOutput: array of Single): SizeInt;
begin
  Result := nextpas.core.math.batch.BatchScaleOffsetF32(AInput, AScale, AOffset, AOutput);
end;

function BatchSinF64(const AInput: array of Double;
                     var AOutput: array of Double): SizeInt;
begin
  Result := nextpas.core.math.batch.BatchSinF64(AInput, AOutput);
end;

function BatchCosF64(const AInput: array of Double;
                     var AOutput: array of Double): SizeInt;
begin
  Result := nextpas.core.math.batch.BatchCosF64(AInput, AOutput);
end;

function BatchSinCosF64(const AInput: array of Double;
                        var ASinOutput, ACosOutput: array of Double): SizeInt;
begin
  Result := nextpas.core.math.batch.BatchSinCosF64(AInput, ASinOutput, ACosOutput);
end;

function BatchTanF64(const AInput: array of Double;
                     var AOutput: array of Double): SizeInt;
begin
  Result := nextpas.core.math.batch.BatchTanF64(AInput, AOutput);
end;

function BatchExpF64(const AInput: array of Double;
                     var AOutput: array of Double): SizeInt;
begin
  Result := nextpas.core.math.batch.BatchExpF64(AInput, AOutput);
end;

function BatchLnF64(const AInput: array of Double;
                    var AOutput: array of Double): SizeInt;
begin
  Result := nextpas.core.math.batch.BatchLnF64(AInput, AOutput);
end;

function BatchLogF64(const AInput: array of Double;
                     var AOutput: array of Double): SizeInt;
begin
  Result := nextpas.core.math.batch.BatchLogF64(AInput, AOutput);
end;

function TryBatchLnF64(const AInput: array of Double;
                       var AOutput: array of Double;
                       out ACount: SizeInt): Boolean;
begin
  Result := nextpas.core.math.batch.TryBatchLnF64(AInput, AOutput, ACount);
end;

function BatchLog10F64(const AInput: array of Double;
                       var AOutput: array of Double): SizeInt;
begin
  Result := nextpas.core.math.batch.BatchLog10F64(AInput, AOutput);
end;

function BatchLog2F64(const AInput: array of Double;
                      var AOutput: array of Double): SizeInt;
begin
  Result := nextpas.core.math.batch.BatchLog2F64(AInput, AOutput);
end;

function BatchSqrtF64(const AInput: array of Double;
                      var AOutput: array of Double): SizeInt;
begin
  Result := nextpas.core.math.batch.BatchSqrtF64(AInput, AOutput);
end;

function BatchAbsF64(const AInput: array of Double;
                     var AOutput: array of Double): SizeInt;
begin
  Result := nextpas.core.math.batch.BatchAbsF64(AInput, AOutput);
end;

function BatchNegF64(const AInput: array of Double;
                     var AOutput: array of Double): SizeInt;
begin
  Result := nextpas.core.math.batch.BatchNegF64(AInput, AOutput);
end;

function BatchCeilF64(const AInput: array of Double;
                      var AOutput: array of Double): SizeInt;
begin
  Result := nextpas.core.math.batch.BatchCeilF64(AInput, AOutput);
end;

function BatchFloorF64(const AInput: array of Double;
                       var AOutput: array of Double): SizeInt;
begin
  Result := nextpas.core.math.batch.BatchFloorF64(AInput, AOutput);
end;

function BatchRoundF64(const AInput: array of Double;
                       var AOutput: array of Double): SizeInt;
begin
  Result := nextpas.core.math.batch.BatchRoundF64(AInput, AOutput);
end;

function BatchTruncF64(const AInput: array of Double;
                       var AOutput: array of Double): SizeInt;
begin
  Result := nextpas.core.math.batch.BatchTruncF64(AInput, AOutput);
end;

function BatchLerpF64(const AStart, AEnd: array of Double;
                      const AT: Double;
                      var AOutput: array of Double): SizeInt;
begin
  Result := nextpas.core.math.batch.BatchLerpF64(AStart, AEnd, AT, AOutput);
end;

function BatchClampF64(const AInput: array of Double;
                       const AMin, AMax: Double;
                       var AOutput: array of Double): SizeInt;
begin
  Result := nextpas.core.math.batch.BatchClampF64(AInput, AMin, AMax, AOutput);
end;

function BatchScaleOffsetF64(const AInput: array of Double;
                             const AScale, AOffset: Double;
                             var AOutput: array of Double): SizeInt;
begin
  Result := nextpas.core.math.batch.BatchScaleOffsetF64(AInput, AScale, AOffset, AOutput);
end;

{$IF DEFINED(CPU64)}
function IsAddOverflow(AA, AB: SizeUInt): Boolean;
begin
  Result := nextpas.core.math.scalar.IsAddOverflow(AA, AB);
end;
{$ENDIF}

function IsAddOverflow(AA, AB: UInt32): Boolean;
begin
  Result := nextpas.core.math.scalar.IsAddOverflow(AA, AB);
end;

{$IF DEFINED(CPU64)}
function IsMulOverflow(AA, AB: SizeUInt): Boolean;
begin
  Result := nextpas.core.math.scalar.IsMulOverflow(AA, AB);
end;
{$ENDIF}

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

function NaN: Double;
begin
  Result := nextpas.core.math.scalar.NaN;
end;

function Infinity: Double;
begin
  Result := nextpas.core.math.scalar.Infinity;
end;

function NegInfinity: Double;
begin
  Result := nextpas.core.math.scalar.NegInfinity;
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

function Sum(const AData: array of Double): Double;
begin
  Result := nextpas.core.math.scalar.Sum(AData);
end;

function Sum(const AData: array of Single): Single;
begin
  Result := nextpas.core.math.scalar.Sum(AData);
end;

function SumToDouble(const AData: array of Single): Double;
begin
  Result := nextpas.core.math.scalar.SumToDouble(AData);
end;

function SumInt(const AData: array of Integer): Int64;
begin
  Result := nextpas.core.math.scalar.SumInt(AData);
end;

function Mean(const AData: array of Double): Double;
begin
  Result := nextpas.core.math.scalar.Mean(AData);
end;

function Mean(const AData: array of Single): Single;
begin
  Result := nextpas.core.math.scalar.Mean(AData);
end;

function Variance(const AData: array of Double): Double;
begin
  Result := nextpas.core.math.scalar.Variance(AData);
end;

function Variance(const AData: array of Single): Single;
begin
  Result := nextpas.core.math.scalar.Variance(AData);
end;

function PopnVariance(const AData: array of Double): Double;
begin
  Result := nextpas.core.math.scalar.PopnVariance(AData);
end;

function PopnVariance(const AData: array of Single): Single;
begin
  Result := nextpas.core.math.scalar.PopnVariance(AData);
end;

function StdDev(const AData: array of Double): Double;
begin
  Result := nextpas.core.math.scalar.StdDev(AData);
end;

function StdDev(const AData: array of Single): Single;
begin
  Result := nextpas.core.math.scalar.StdDev(AData);
end;

function PopnStdDev(const AData: array of Double): Double;
begin
  Result := nextpas.core.math.scalar.PopnStdDev(AData);
end;

function PopnStdDev(const AData: array of Single): Single;
begin
  Result := nextpas.core.math.scalar.PopnStdDev(AData);
end;

function TotalVariance(const AData: array of Double): Double;
begin
  Result := nextpas.core.math.scalar.TotalVariance(AData);
end;

function TotalVariance(const AData: array of Single): Single;
begin
  Result := nextpas.core.math.scalar.TotalVariance(AData);
end;

function SumSquaredDeviations(const AData: array of Double): Double;
begin
  Result := nextpas.core.math.scalar.SumSquaredDeviations(AData);
end;

function SumSquaredDeviations(const AData: array of Single): Single;
begin
  Result := nextpas.core.math.scalar.SumSquaredDeviations(AData);
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

function Camera2D(const ACenterX, ACenterY, AZoom: Single;
  const AViewportWidth, AViewportHeight: Integer;
  const ANear, AFar: Single): TMat4f;
begin
  Result := nextpas.core.math.transform.Camera2D(ACenterX, ACenterY, AZoom, AViewportWidth,
    AViewportHeight, ANear, AFar);
end;

function Camera2D(const ACenterX, ACenterY, AZoom: Double;
  const AViewportWidth, AViewportHeight: Integer;
  const ANear, AFar: Double): TMat4d;
begin
  Result := nextpas.core.math.transform.Camera2D(ACenterX, ACenterY, AZoom, AViewportWidth,
    AViewportHeight, ANear, AFar);
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

{ ── FPU Exception Control ─────────────────────────────────────────────────── }
{ x86_64: keep MXCSR (SSE) and x87 CW mask bits in lockstep. Bit layout of
  TFPUException (0..5) matches both MXCSR[12:7] and x87 CW[5:0].
  SetExceptionMask also clears sticky status flags (MXCSR[5:0] + fnclex) so
  restore-after-boundary tests do not re-raise deferred exceptions. }

function GetExceptionMask: TFPUExceptionMask;
var
  LMxcsr: UInt32;
  LCw: Word;
  LMask: Byte;
begin
  Result := [];
  {$IFDEF CPUX86_64}
  {$asmmode intel}
  asm
    stmxcsr [LMxcsr]
    fnstcw [LCw]
  end;
  {$asmmode att}
  { Report the intersection so a flag appears masked only if both units mask it. }
  LMask := Byte(((LMxcsr shr 7) and $3F) and (LCw and $3F));
  Move(LMask, Result, 1);
  {$ENDIF}
end;

procedure SetExceptionMask(const AMask: TFPUExceptionMask);
var
  LMxcsr: UInt32;
  LCw: Word;
  LMask: Byte;
  {$IFDEF FPC}
  LSoft: Byte;
  {$ENDIF}
begin
  {$IFDEF CPUX86_64}
  LMask := 0;
  Move(AMask, LMask, 1);
  {$asmmode intel}
  asm
    stmxcsr [LMxcsr]
    fnstcw [LCw]
  end;
  {$asmmode att}
  { Clear sticky status (bits 0..5) while updating exception masks (bits 7..12). }
  LMxcsr := (LMxcsr and not UInt32($3F or ($3F shl 7))) or (UInt32(LMask) shl 7);
  LCw := (LCw and not Word($003F)) or Word(LMask);
  {$asmmode intel}
  asm
    ldmxcsr [LMxcsr]
    fnclex
    fldcw [LCw]
  end;
  {$asmmode att}
  {$IFDEF FPC}
  { Keep FPC softfloat in sync for System.Sin/Ln paths that consult it. }
  LSoft := LMask;
  Move(LSoft, softfloat_exception_mask, 1);
  {$ENDIF}
  {$ENDIF}
end;

end.
