unit nextpas.core.math.scalar;

{$I nextpas.core.settings.inc}

interface

const
  PI_VALUE: Double = 3.14159265358979323846;
  TWO_PI: Double = 6.28318530717958647692;
  HALF_PI: Double = 1.57079632679489661923;
  DEG_TO_RAD: Double = 0.01745329251994329577;
  RAD_TO_DEG: Double = 57.2957795130823208768;

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
function Lerp(const AA, AB, AT: Double): Double; overload;
function Lerp(const AA, AB, AT: Single): Single; overload;
function InverseLerp(const AA, AB, AValue: Double): Double; overload;
function InverseLerp(const AA, AB, AValue: Single): Single; overload;
function Wrap(const AValue, AMin, AMax: Double): Double; overload;
function Wrap(const AValue, AMin, AMax: Single): Single; overload; inline;
function SmoothStep(const AEdge0, AEdge1, AValue: Double): Double; overload;
function SmoothStep(const AEdge0, AEdge1, AValue: Single): Single; overload;

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

implementation

uses
  nextpas.core.errors,
  nextpas.core.math.impl.scalar;

{$IF (SizeOf(Extended) > SizeOf(Double)) AND (DEFINED(CPUX86_64) OR DEFINED(CPUX86) OR DEFINED(CPUI386))}
  {$DEFINE NEXTPAS_MATH_EXTENDED_X87_80}
{$ELSEIF SizeOf(Extended) = SizeOf(Double)}
  {$DEFINE NEXTPAS_MATH_EXTENDED_DOUBLE_COMPAT}
{$ELSE}
  {$FATAL Unsupported Extended floating-point layout}
{$ENDIF}

const
  MAX_DOUBLE_VALUE: Double = 1.79769313486231570815e308;
  MAX_SINGLE_VALUE: Single = 3.40282346638528859812e38;

function UInt64AbsInt64(const AValue: Int64): UInt64; inline;
begin
  if AValue < 0 then
    Result := UInt64(-(AValue + 1)) + UInt64(1)
  else
    Result := UInt64(AValue);
end;

function GCDUInt64(AA, AB: UInt64): UInt64;
var
  LTemp: UInt64;
begin
  while AB <> 0 do
  begin
    LTemp := AA mod AB;
    AA := AB;
    AB := LTemp;
  end;
  Result := AA;
end;

function CheckedNonNegativeInt64(const AFunctionName: string; const AValue: UInt64): Int64; inline;
begin
  if AValue > UInt64(High(Int64)) then
    raise EArgumentError.Create(AFunctionName + ': result is outside Int64 range');
  Result := Int64(AValue);
end;

function SingleHasSignBit(const AValue: Single): Boolean; inline;
var
  LBits: UInt32;
begin
  Move(AValue, LBits, SizeOf(LBits));
  Result := (LBits and UInt32($80000000)) <> 0;
end;

function DoubleHasSignBit(const AValue: Double): Boolean; inline;
var
  LBits: UInt64;
begin
  Move(AValue, LBits, SizeOf(LBits));
  Result := (LBits and UInt64($8000000000000000)) <> 0;
end;

function SingleSignedZero(const ANegative: Boolean): Single; inline;
var
  LBits: UInt32;
begin
  if ANegative then
    LBits := UInt32($80000000)
  else
    LBits := UInt32(0);
  Move(LBits, Result, SizeOf(Result));
end;

function DoubleSignedZero(const ANegative: Boolean): Double; inline;
var
  LBits: UInt64;
begin
  if ANegative then
    LBits := UInt64($8000000000000000)
  else
    LBits := UInt64(0);
  Move(LBits, Result, SizeOf(Result));
end;

function SingleSignedInfinity(const ANegative: Boolean): Single; inline;
var
  LBits: UInt32;
begin
  if ANegative then
    LBits := UInt32($FF800000)
  else
    LBits := UInt32($7F800000);
  Move(LBits, Result, SizeOf(Result));
end;

function DoubleSignedInfinity(const ANegative: Boolean): Double; inline;
var
  LBits: UInt64;
begin
  if ANegative then
    LBits := UInt64($FFF0000000000000)
  else
    LBits := UInt64($7FF0000000000000);
  Move(LBits, Result, SizeOf(Result));
end;

function ExtendedHasSignBit(const AValue: Extended): Boolean; inline;
{$IFDEF NEXTPAS_MATH_EXTENDED_X87_80}
type
  TExtendedBytes = packed array[0..SizeOf(Extended) - 1] of Byte;
{$ENDIF}
var
  {$IFDEF NEXTPAS_MATH_EXTENDED_X87_80}
  LBytes: TExtendedBytes;
  {$ELSE}
  LBits: UInt64;
  {$ENDIF}
begin
  {$IFDEF NEXTPAS_MATH_EXTENDED_X87_80}
  Move(AValue, LBytes, SizeOf(LBytes));
  Result := (LBytes[9] and Byte($80)) <> 0;
  {$ELSE}
  Move(AValue, LBits, SizeOf(LBits));
  Result := (LBits and UInt64($8000000000000000)) <> 0;
  {$ENDIF}
end;

function ExtendedSignedZero(const ANegative: Boolean): Extended; inline;
{$IFDEF NEXTPAS_MATH_EXTENDED_X87_80}
type
  TExtendedBytes = packed array[0..SizeOf(Extended) - 1] of Byte;
{$ENDIF}
var
  {$IFDEF NEXTPAS_MATH_EXTENDED_X87_80}
  LBytes: TExtendedBytes;
  {$ELSE}
  LBits: UInt64;
  {$ENDIF}
begin
  {$IFDEF NEXTPAS_MATH_EXTENDED_X87_80}
  FillChar(LBytes, SizeOf(LBytes), 0);
  if ANegative then
    LBytes[9] := Byte($80);
  Move(LBytes, Result, SizeOf(Result));
  {$ELSE}
  if ANegative then
    LBits := UInt64($8000000000000000)
  else
    LBits := UInt64(0);
  Move(LBits, Result, SizeOf(Result));
  {$ENDIF}
end;

function ExtendedAbsFinite(const AValue: Extended): Extended; inline;
begin
  if AValue < 0.0 then
    Result := -AValue
  else
    Result := AValue;
end;

function SingleAbsBits(const AValue: Single): Single; inline;
var
  LBits: UInt32;
begin
  Move(AValue, LBits, SizeOf(LBits));
  LBits := LBits and UInt32($7FFFFFFF);
  Move(LBits, Result, SizeOf(Result));
end;

function DoubleAbsBits(const AValue: Double): Double; inline;
var
  LBits: UInt64;
begin
  Move(AValue, LBits, SizeOf(LBits));
  LBits := LBits and UInt64($7FFFFFFFFFFFFFFF);
  Move(LBits, Result, SizeOf(Result));
end;

function FmodPositiveFinite(const ADividend, ADivisor: Double): Double;
var
  LDividend: Double;
  LDivisor: Double;
  LScaledDivisor: Double;
begin
  LDividend := ADividend;
  LDivisor := ADivisor;
  if LDividend < LDivisor then
    Exit(LDividend);
  if LDividend = LDivisor then
    Exit(0.0);

  LScaledDivisor := LDivisor;
  while LScaledDivisor <= LDividend - LScaledDivisor do
    LScaledDivisor := LScaledDivisor + LScaledDivisor;

  while LScaledDivisor >= LDivisor do
  begin
    if LDividend >= LScaledDivisor then
    begin
      LDividend := LDividend - LScaledDivisor;
      if LDividend = 0.0 then
        Exit(0.0);
    end;
    LScaledDivisor := LScaledDivisor * 0.5;
  end;

  if LDividend >= LDivisor then
    LDividend := LDividend - LDivisor;
  Result := LDividend;
end;

{$IF SizeOf(Extended) > SizeOf(Double)}
function FmodPositiveFinite(const ADividend, ADivisor: Extended): Extended;
var
  LDividend: Extended;
  LDivisor: Extended;
  LScaledDivisor: Extended;
begin
  LDividend := ADividend;
  LDivisor := ADivisor;
  if LDividend < LDivisor then
    Exit(LDividend);
  if LDividend = LDivisor then
    Exit(0.0);

  LScaledDivisor := LDivisor;
  while LScaledDivisor <= LDividend - LScaledDivisor do
    LScaledDivisor := LScaledDivisor + LScaledDivisor;

  while LScaledDivisor >= LDivisor do
  begin
    if LDividend >= LScaledDivisor then
    begin
      LDividend := LDividend - LScaledDivisor;
      if LDividend = 0.0 then
        Exit(0.0);
    end;
    LScaledDivisor := LScaledDivisor * 0.5;
  end;

  if LDividend >= LDivisor then
    LDividend := LDividend - LDivisor;
  Result := LDividend;
end;
{$ENDIF}

function EuclideanModuloFinite(const AValue, AModulus: Double): Double;
var
  LAbsRemainder: Double;
begin
  if AValue = 0.0 then
    Exit(0.0);
  if AValue > 0.0 then
    Exit(FmodPositiveFinite(AValue, AModulus));

  LAbsRemainder := FmodPositiveFinite(-AValue, AModulus);
  if LAbsRemainder = 0.0 then
    Exit(0.0);
  Result := AModulus - LAbsRemainder;
  if Result >= AModulus then
    Result := 0.0;
end;

function DifferenceWouldOverflow(const ALeft, ARight: Double): Boolean;
begin
  if (ALeft > 0.0) and (ARight < 0.0) then
    Exit((ALeft * 0.5) > ((MAX_DOUBLE_VALUE * 0.5) + (ARight * 0.5)));
  if (ALeft < 0.0) and (ARight > 0.0) then
    Exit((ALeft * 0.5) < ((-MAX_DOUBLE_VALUE * 0.5) + (ARight * 0.5)));
  Result := False;
end;

function SingleDifferenceWouldOverflow(const ALeft, ARight: Single): Boolean;
begin
  if (ALeft > 0.0) and (ARight < 0.0) then
    Exit((ALeft * Single(0.5)) > ((MAX_SINGLE_VALUE * Single(0.5)) + (ARight * Single(0.5))));
  if (ALeft < 0.0) and (ARight > 0.0) then
    Exit((ALeft * Single(0.5)) < ((-MAX_SINGLE_VALUE * Single(0.5)) + (ARight * Single(0.5))));
  Result := False;
end;

function WrapOffsetFiniteRange(const AValue, AMin, ARange: Double): Double;
var
  LDelta: Double;
  LValueRemainder: Double;
  LMinRemainder: Double;
begin
  if not DifferenceWouldOverflow(AValue, AMin) then
  begin
    LDelta := AValue - AMin;
    Exit(EuclideanModuloFinite(LDelta, ARange));
  end;

  LValueRemainder := EuclideanModuloFinite(AValue, ARange);
  LMinRemainder := EuclideanModuloFinite(AMin, ARange);
  Result := LValueRemainder - LMinRemainder;
  if Result < 0.0 then
    Result := Result + ARange;
  if Result >= ARange then
    Result := Result - ARange;
end;

function WrapFiniteOverflowedRange(const AValue, AMin, AMax: Double): Double;
begin
  if AValue >= AMax then
    Exit(AMin + (AValue - AMax));
  Result := AMax - (AMin - AValue);
  if Result >= AMax then
    Result := AMin;
end;

function WrapRangeWouldOverflow(const AMin, AMax: Double): Boolean;
begin
  Result := (AMin < 0.0) and (AMax > 0.0) and ((MAX_DOUBLE_VALUE - AMax) < -AMin);
end;

function StableLerpFinite(const AA, AB, AT: Double): Double;
var
  LA: Double;
  LB: Double;
  LLeft: Double;
  LRight: Double;
  LScale: Double;
begin
  LScale := DoubleAbsBits(AA);
  if DoubleAbsBits(AB) > LScale then
    LScale := DoubleAbsBits(AB);
  if LScale = 0.0 then
    Exit(0.0);
  LA := AA / LScale;
  LB := AB / LScale;
  LLeft := LA * (1.0 - AT);
  LRight := LB * AT;
  Result := (LLeft + LRight) * LScale;
end;

function StableInverseLerpFinite(const AA, AB, AValue: Double): Double;
var
  LScale: Double;
  LAbs: Double;
begin
  LScale := DoubleAbsBits(AA);
  LAbs := DoubleAbsBits(AB);
  if LAbs > LScale then
    LScale := LAbs;
  LAbs := DoubleAbsBits(AValue);
  if LAbs > LScale then
    LScale := LAbs;
  if LScale = 0.0 then
    Exit(0.0);
  Result := ((AValue / LScale) - (AA / LScale)) /
    ((AB / LScale) - (AA / LScale));
end;

function ShouldUseStableLerp(const AA, AB: Double): Boolean;
begin
  Result := (not DoubleIsNaN(AA)) and (not DoubleIsNaN(AB)) and
    (not DoubleIsInfinite(AA)) and (not DoubleIsInfinite(AB)) and
    DifferenceWouldOverflow(AB, AA);
end;

function ShouldUseStableLerp(const AA, AB: Single): Boolean;
begin
  Result := (not SingleIsNaN(AA)) and (not SingleIsNaN(AB)) and
    (not SingleIsInfinite(AA)) and (not SingleIsInfinite(AB)) and
    SingleDifferenceWouldOverflow(AB, AA);
end;

function ShouldUseStableInverseLerp(const AA, AB, AValue: Double): Boolean;
begin
  Result := (not DoubleIsNaN(AA)) and (not DoubleIsNaN(AB)) and
    (not DoubleIsNaN(AValue)) and (not DoubleIsInfinite(AA)) and
    (not DoubleIsInfinite(AB)) and (not DoubleIsInfinite(AValue)) and
    (DifferenceWouldOverflow(AB, AA) or DifferenceWouldOverflow(AValue, AA));
end;

function ShouldUseStableInverseLerp(const AA, AB, AValue: Single): Boolean;
begin
  Result := (not SingleIsNaN(AA)) and (not SingleIsNaN(AB)) and
    (not SingleIsNaN(AValue)) and (not SingleIsInfinite(AA)) and
    (not SingleIsInfinite(AB)) and (not SingleIsInfinite(AValue)) and
    (SingleDifferenceWouldOverflow(AB, AA) or SingleDifferenceWouldOverflow(AValue, AA));
end;

function ValidComparisonEpsilon(const AEpsilon: Single): Boolean; inline;
begin
  Result := (not SingleIsNaN(AEpsilon)) and (not SingleIsInfinite(AEpsilon)) and
    (AEpsilon >= 0.0);
end;

function ValidComparisonEpsilon(const AEpsilon: Double): Boolean; inline;
begin
  Result := (not DoubleIsNaN(AEpsilon)) and (not DoubleIsInfinite(AEpsilon)) and
    (AEpsilon >= 0.0);
end;

function IsAddOverflow(AA, AB: SizeUInt): Boolean;
begin
  Result := AA > High(SizeUInt) - AB;
end;

function IsAddOverflow(AA, AB: UInt32): Boolean;
begin
  Result := AA > High(UInt32) - AB;
end;

function IsMulOverflow(AA, AB: SizeUInt): Boolean;
begin
  if AA = 0 then
    Exit(False);
  Result := AB > High(SizeUInt) div AA;
end;

function IsMulOverflow(AA, AB: UInt32): Boolean;
begin
  if AA = 0 then
    Exit(False);
  Result := AB > High(UInt32) div AA;
end;

function Min(AA, AB: SizeUInt): SizeUInt;
begin
  if AA < AB then Result := AA else Result := AB;
end;

function Max(AA, AB: SizeUInt): SizeUInt;
begin
  if AA > AB then Result := AA else Result := AB;
end;

function Min(AA, AB: SizeInt): SizeInt;
begin
  if AA < AB then Result := AA else Result := AB;
end;

function Max(AA, AB: SizeInt): SizeInt;
begin
  if AA > AB then Result := AA else Result := AB;
end;

function Min(AA, AB: Single): Single;
begin
  if SingleIsNaN(AA) or SingleIsNaN(AB) then
    Exit(SingleQuietNaN);
  if (AA = 0.0) and (AB = 0.0) then
    Exit(SingleSignedZero(SingleHasSignBit(AA) or SingleHasSignBit(AB)));
  if AA < AB then Result := AA else Result := AB;
end;

function Max(AA, AB: Single): Single;
begin
  if SingleIsNaN(AA) or SingleIsNaN(AB) then
    Exit(SingleQuietNaN);
  if (AA = 0.0) and (AB = 0.0) then
    Exit(SingleSignedZero(SingleHasSignBit(AA) and SingleHasSignBit(AB)));
  if AA > AB then Result := AA else Result := AB;
end;

function Min(AA, AB: Double): Double;
begin
  if DoubleIsNaN(AA) or DoubleIsNaN(AB) then
    Exit(DoubleQuietNaN);
  if (AA = 0.0) and (AB = 0.0) then
    Exit(DoubleSignedZero(DoubleHasSignBit(AA) or DoubleHasSignBit(AB)));
  if AA < AB then Result := AA else Result := AB;
end;

function Max(AA, AB: Double): Double;
begin
  if DoubleIsNaN(AA) or DoubleIsNaN(AB) then
    Exit(DoubleQuietNaN);
  if (AA = 0.0) and (AB = 0.0) then
    Exit(DoubleSignedZero(DoubleHasSignBit(AA) and DoubleHasSignBit(AB)));
  if AA > AB then Result := AA else Result := AB;
end;

procedure RequireClampBounds(const AMin, AMax: Single); inline;
begin
  if SingleIsNaN(AMin) or SingleIsNaN(AMax) or
    SingleIsInfinite(AMin) or SingleIsInfinite(AMax) then
    raise EArgumentError.Create('Clamp: minimum and maximum must be finite');
  if AMin > AMax then
    raise EArgumentError.Create('Clamp: minimum must not exceed maximum');
end;

procedure RequireClampBounds(const AMin, AMax: Double); inline;
begin
  if DoubleIsNaN(AMin) or DoubleIsNaN(AMax) or
    DoubleIsInfinite(AMin) or DoubleIsInfinite(AMax) then
    raise EArgumentError.Create('Clamp: minimum and maximum must be finite');
  if AMin > AMax then
    raise EArgumentError.Create('Clamp: minimum must not exceed maximum');
end;

procedure RequireWrapInputs(const AValue, AMin, AMax: Double); inline;
begin
  if DoubleIsNaN(AValue) or DoubleIsNaN(AMin) or DoubleIsNaN(AMax) or
    DoubleIsInfinite(AValue) or DoubleIsInfinite(AMin) or DoubleIsInfinite(AMax) then
    raise EArgumentError.Create('Wrap: value, minimum, and maximum must be finite');
  if AMin > AMax then
    raise EArgumentError.Create('Wrap: minimum must not exceed maximum');
end;

procedure RequireSmoothStepEdges(const AEdge0, AEdge1: Single); inline;
begin
  if SingleIsNaN(AEdge0) or SingleIsNaN(AEdge1) or
    SingleIsInfinite(AEdge0) or SingleIsInfinite(AEdge1) then
    raise EArgumentError.Create('SmoothStep: edges must be finite');
  if AEdge0 > AEdge1 then
    raise EArgumentError.Create('SmoothStep: edge0 must not exceed edge1');
end;

procedure RequireSmoothStepEdges(const AEdge0, AEdge1: Double); inline;
begin
  if DoubleIsNaN(AEdge0) or DoubleIsNaN(AEdge1) or
    DoubleIsInfinite(AEdge0) or DoubleIsInfinite(AEdge1) then
    raise EArgumentError.Create('SmoothStep: edges must be finite');
  if AEdge0 > AEdge1 then
    raise EArgumentError.Create('SmoothStep: edge0 must not exceed edge1');
end;

procedure RequireClampBounds(const AMin, AMax: Int32); inline;
begin
  if AMin > AMax then
    raise EArgumentError.Create('Clamp: minimum must not exceed maximum');
end;

function Clamp(const AValue, AMin, AMax: Single): Single;
begin
  RequireClampBounds(AMin, AMax);
  if SingleIsNaN(AValue) then
    Exit(AValue);
  if AMin = AMax then
    Exit(AMin);
  if AValue < AMin then
    Result := AMin
  else if AValue > AMax then
    Result := AMax
  else
    Result := AValue;
end;

function Clamp(const AValue, AMin, AMax: Double): Double;
begin
  RequireClampBounds(AMin, AMax);
  if DoubleIsNaN(AValue) then
    Exit(AValue);
  if AMin = AMax then
    Exit(AMin);
  if AValue < AMin then
    Result := AMin
  else if AValue > AMax then
    Result := AMax
  else
    Result := AValue;
end;

function Clamp(const AValue, AMin, AMax: Int32): Int32;
begin
  RequireClampBounds(AMin, AMax);
  if AValue < AMin then
    Result := AMin
  else if AValue > AMax then
    Result := AMax
  else
    Result := AValue;
end;

function Lerp(const AA, AB, AT: Single): Single;
begin
  if SingleIsNaN(AT) then
    Exit(AT);
  if AT = Single(0.0) then
    Exit(AA);
  if AT = Single(1.0) then
    Exit(AB);
  if ShouldUseStableLerp(AA, AB) then
    Exit(Single(StableLerpFinite(Double(AA), Double(AB), Double(AT))));
  Result := AA + (AB - AA) * AT;
end;

function Lerp(const AA, AB, AT: Double): Double;
begin
  if DoubleIsNaN(AT) then
    Exit(AT);
  if AT = 0.0 then
    Exit(AA);
  if AT = 1.0 then
    Exit(AB);
  if ShouldUseStableLerp(AA, AB) then
    Exit(StableLerpFinite(AA, AB, AT));
  Result := AA + (AB - AA) * AT;
end;

function InverseLerp(const AA, AB, AValue: Single): Single;
begin
  if AA = AB then
    Exit(0.0);
  if ShouldUseStableInverseLerp(AA, AB, AValue) then
    Exit(Single(StableInverseLerpFinite(Double(AA), Double(AB), Double(AValue))));
  Result := (AValue - AA) / (AB - AA);
end;

function InverseLerp(const AA, AB, AValue: Double): Double;
begin
  if AA = AB then
    Exit(0.0);
  if ShouldUseStableInverseLerp(AA, AB, AValue) then
    Exit(StableInverseLerpFinite(AA, AB, AValue));
  Result := (AValue - AA) / (AB - AA);
end;

function Wrap(const AValue, AMin, AMax: Single): Single;
begin
  Result := Single(Wrap(Double(AValue), Double(AMin), Double(AMax)));
end;

function Wrap(const AValue, AMin, AMax: Double): Double;
var
  LOffset: Double;
  LRange: Double;
begin
  RequireWrapInputs(AValue, AMin, AMax);
  if (AValue >= AMin) and (AValue < AMax) then
    Exit(AValue);
  if WrapRangeWouldOverflow(AMin, AMax) then
    Exit(WrapFiniteOverflowedRange(AValue, AMin, AMax));
  LRange := AMax - AMin;
  if LRange = 0.0 then
    Exit(AMin);
  if DoubleIsInfinite(LRange) then
  begin
    if AValue >= AMax then
      Exit(AMin + (AValue - AMax));
    Exit(AMax - (AMin - AValue));
  end;

  LOffset := WrapOffsetFiniteRange(AValue, AMin, LRange);
  Result := AMin + LOffset;
  if Result >= AMax then
    Result := AMin
  else if Result < AMin then
  begin
    Result := Result + LRange;
    if Result >= AMax then
      Result := AMin;
  end;
end;

function SmoothStep(const AEdge0, AEdge1, AValue: Single): Single;
var
  LT: Single;
begin
  if SingleIsNaN(AValue) then
    Exit(AValue);
  RequireSmoothStepEdges(AEdge0, AEdge1);
  if AEdge0 = AEdge1 then
  begin
    if AValue < AEdge0 then
      Exit(0.0);
    Exit(1.0);
  end;
  LT := Clamp(InverseLerp(AEdge0, AEdge1, AValue), Single(0.0), Single(1.0));
  Result := LT * LT * (Single(3.0) - Single(2.0) * LT);
end;

function SmoothStep(const AEdge0, AEdge1, AValue: Double): Double;
var
  LT: Double;
begin
  if DoubleIsNaN(AValue) then
    Exit(AValue);
  RequireSmoothStepEdges(AEdge0, AEdge1);
  if AEdge0 = AEdge1 then
  begin
    if AValue < AEdge0 then
      Exit(0.0);
    Exit(1.0);
  end;
  LT := Clamp(InverseLerp(AEdge0, AEdge1, AValue), 0.0, 1.0);
  Result := LT * LT * (3.0 - 2.0 * LT);
end;

function Floor(const AValue: Single): Int64;
begin
  Result := Floor(Double(AValue));
end;

function Floor(const AValue: Double): Int64;
var
  LValue: Double;
begin
  RequireInt64Convertible('Floor', AValue);
  LValue := System.Int(AValue);
  if (AValue < 0.0) and (AValue <> LValue) then
    LValue := LValue - 1.0;
  RequireInt64Convertible('Floor', LValue);
  Result := System.Trunc(LValue);
end;

function Ceil(const AValue: Single): Int64;
begin
  Result := Ceil(Double(AValue));
end;

function Ceil(const AValue: Double): Int64;
var
  LValue: Double;
begin
  RequireInt64Convertible('Ceil', AValue);
  LValue := System.Int(AValue);
  if (AValue > 0.0) and (AValue <> LValue) then
    LValue := LValue + 1.0;
  RequireInt64Convertible('Ceil', LValue);
  Result := System.Trunc(LValue);
end;

function Round(const AValue: Single): Int64;
begin
  Result := Round(Double(AValue));
end;

function Round(const AValue: Double): Int64;
var
  LValue: Double;
begin
  RequireInt64Convertible('Round', AValue);
  if AValue >= 0.0 then
    LValue := System.Int(AValue + 0.5)
  else
    LValue := System.Int(AValue - 0.5);
  RequireInt64Convertible('Round', LValue);
  Result := System.Trunc(LValue);
end;

function Trunc(const AValue: Single): Int64;
begin
  Result := Trunc(Double(AValue));
end;

function Trunc(const AValue: Double): Int64;
begin
  RequireInt64Convertible('Trunc', AValue);
  Result := System.Trunc(AValue);
end;

function Frac(const AValue: Single): Single;
var
  LResult: Double;
begin
  LResult := Frac(Double(AValue));
  if LResult = 0.0 then
    Result := SingleSignedZero(SingleHasSignBit(AValue))
  else
    Result := Single(LResult);
end;

function Frac(const AValue: Double): Double;
begin
  RequireInt64Convertible('Frac', AValue);
  Result := AValue - System.Trunc(AValue);
  if Result = 0.0 then
    Result := DoubleSignedZero(DoubleHasSignBit(AValue));
end;

function Abs(const AValue: Single): Single;
begin
  Result := SingleAbsBits(AValue);
end;

function Abs(const AValue: Double): Double;
begin
  Result := DoubleAbsBits(AValue);
end;

function Abs(const AValue: Int32): Int32;
begin
  RequireAbsConvertible('Abs', AValue);
  if AValue < 0 then Result := -AValue else Result := AValue;
end;

function Abs(const AValue: Int64): Int64;
begin
  RequireAbsConvertible('Abs', AValue);
  if AValue < 0 then Result := -AValue else Result := AValue;
end;

function Sign(const AValue: Single): Single;
begin
  if SingleIsNaN(AValue) then
    Result := SingleQuietNaN
  else if AValue = 0.0 then
    Result := SingleSignedZero(SingleHasSignBit(AValue))
  else if AValue > 0.0 then
    Result := 1.0
  else
    Result := -1.0;
end;

function Sign(const AValue: Double): Double;
begin
  if DoubleIsNaN(AValue) then
    Result := DoubleQuietNaN
  else if AValue = 0.0 then
    Result := DoubleSignedZero(DoubleHasSignBit(AValue))
  else if AValue > 0.0 then
    Result := 1.0
  else
    Result := -1.0;
end;

function Sign(const AValue: Int32): Int32;
begin
  if AValue > 0 then
    Result := 1
  else if AValue < 0 then
    Result := -1
  else
    Result := 0;
end;

function Sign(const AValue: Int64): Int64;
begin
  if AValue > 0 then
    Result := 1
  else if AValue < 0 then
    Result := -1
  else
    Result := 0;
end;

function IsNaN(const AValue: Single): Boolean;
begin
  Result := SingleIsNaN(AValue);
end;

function IsNaN(const AValue: Double): Boolean;
begin
  Result := DoubleIsNaN(AValue);
end;

function IsInfinite(const AValue: Single): Boolean;
begin
  Result := SingleIsInfinite(AValue);
end;

function IsInfinite(const AValue: Double): Boolean;
begin
  Result := DoubleIsInfinite(AValue);
end;

function FloatEquals(const AA, AB: Single; const AEpsilon: Single): Boolean;
begin
  if not ValidComparisonEpsilon(AEpsilon) then
    Exit(False);
  if IsNaN(AA) or IsNaN(AB) then
    Exit(False);
  if IsInfinite(AA) or IsInfinite(AB) then
    Exit(AA = AB);
  Result := Abs(AA - AB) <= AEpsilon;
end;

function FloatEquals(const AA, AB: Double; const AEpsilon: Double): Boolean;
begin
  if not ValidComparisonEpsilon(AEpsilon) then
    Exit(False);
  if IsNaN(AA) or IsNaN(AB) then
    Exit(False);
  if IsInfinite(AA) or IsInfinite(AB) then
    Exit(AA = AB);
  Result := Abs(AA - AB) <= AEpsilon;
end;

function FloatIsZero(const AValue: Single; const AEpsilon: Single): Boolean;
begin
  if (not ValidComparisonEpsilon(AEpsilon)) or IsNaN(AValue) or IsInfinite(AValue) then
    Exit(False);
  Result := Abs(AValue) <= AEpsilon;
end;

function FloatIsZero(const AValue: Double; const AEpsilon: Double): Boolean;
begin
  if (not ValidComparisonEpsilon(AEpsilon)) or IsNaN(AValue) or IsInfinite(AValue) then
    Exit(False);
  Result := Abs(AValue) <= AEpsilon;
end;

function DegToRad(const ADegrees: Single): Single;
begin
  Result := ADegrees * Single(DEG_TO_RAD);
end;

function DegToRad(const ADegrees: Double): Double;
begin
  Result := ADegrees * DEG_TO_RAD;
end;

function RadToDeg(const ARadians: Single): Single;
begin
  if SingleIsNaN(ARadians) or SingleIsInfinite(ARadians) then
    Exit(ARadians);
  if SingleAbsBits(ARadians) > (MAX_SINGLE_VALUE / Single(RAD_TO_DEG)) then
    Exit(SingleSignedInfinity(SingleHasSignBit(ARadians)));
  Result := ARadians * Single(RAD_TO_DEG);
end;

function RadToDeg(const ARadians: Double): Double;
begin
  if DoubleIsNaN(ARadians) or DoubleIsInfinite(ARadians) then
    Exit(ARadians);
  if DoubleAbsBits(ARadians) > (MAX_DOUBLE_VALUE / RAD_TO_DEG) then
    Exit(DoubleSignedInfinity(DoubleHasSignBit(ARadians)));
  Result := ARadians * RAD_TO_DEG;
end;

function GCD(AA, AB: Int64): Int64;
begin
  Result := CheckedNonNegativeInt64('GCD', GCDUInt64(UInt64AbsInt64(AA), UInt64AbsInt64(AB)));
end;

function LCM(AA, AB: Int64): Int64;
var
  LA, LB, LGCD, LQuotient: UInt64;
begin
  LA := UInt64AbsInt64(AA);
  LB := UInt64AbsInt64(AB);
  if (LA = 0) or (LB = 0) then
    Exit(0);

  LGCD := GCDUInt64(LA, LB);
  LQuotient := LA div LGCD;
  if LQuotient > UInt64(High(Int64)) div LB then
    raise EArgumentError.Create('LCM: result is outside Int64 range');
  Result := CheckedNonNegativeInt64('LCM', LQuotient * LB);
end;

function Hypot(const AX, AY: Single): Single;
var
  LX, LY, LMax, LMin, LRatio: Single;
  LFactor: Single;
begin
  LX := Abs(AX);
  LY := Abs(AY);
  if IsInfinite(LX) then
    Exit(LX);
  if IsInfinite(LY) then
    Exit(LY);
  if IsNaN(AX) or IsNaN(AY) then
    Exit(SingleQuietNaN);
  LMax := Max(LX, LY);
  if LMax = 0.0 then
    Exit(0.0);
  LMin := Min(LX, LY);
  LRatio := LMin / LMax;
  LFactor := Single(System.Sqrt(1.0 + LRatio * LRatio));
  if LMax > MAX_SINGLE_VALUE / LFactor then
    Exit(SingleSignedInfinity(False));
  Result := LMax * LFactor;
end;

function Hypot(const AX, AY: Double): Double;
var
  LX, LY, LMax, LMin, LRatio: Double;
  LFactor: Double;
begin
  LX := Abs(AX);
  LY := Abs(AY);
  if IsInfinite(LX) then
    Exit(LX);
  if IsInfinite(LY) then
    Exit(LY);
  if IsNaN(AX) or IsNaN(AY) then
    Exit(DoubleQuietNaN);
  LMax := Max(LX, LY);
  if LMax = 0.0 then
    Exit(0.0);
  LMin := Min(LX, LY);
  LRatio := LMin / LMax;
  LFactor := System.Sqrt(1.0 + LRatio * LRatio);
  if LMax > MAX_DOUBLE_VALUE / LFactor then
    Exit(DoubleSignedInfinity(False));
  Result := LMax * LFactor;
end;

function Fmod(const AX, AY: Single): Single;
var
  LResult: Double;
begin
  if IsNaN(AX) or IsNaN(AY) or (AY = 0.0) or IsInfinite(AX) then
    Exit(SingleQuietNaN);
  if IsInfinite(AY) then
    Exit(AX);
  LResult := FmodPositiveFinite(Double(Abs(AX)), Double(Abs(AY)));
  if LResult = 0.0 then
    Result := SingleSignedZero(SingleHasSignBit(AX));
  if LResult = 0.0 then
    Exit;
  Result := Single(LResult);
  if Result = 0.0 then
    Result := SingleSignedZero(SingleHasSignBit(AX))
  else if SingleHasSignBit(AX) then
    Result := -Result;
end;

function Fmod(const AX, AY: Double): Double;
var
  LResult: Double;
begin
  if IsNaN(AX) or IsNaN(AY) or (AY = 0.0) or IsInfinite(AX) then
    Exit(DoubleQuietNaN);
  if IsInfinite(AY) then
    Exit(AX);
  LResult := FmodPositiveFinite(Abs(AX), Abs(AY));
  if LResult = 0.0 then
    Result := DoubleSignedZero(DoubleHasSignBit(AX));
  if LResult = 0.0 then
    Exit;
  if DoubleHasSignBit(AX) then
    Result := -LResult
  else
    Result := LResult;
end;

{$IF SizeOf(Extended) > SizeOf(Double)}
function Fmod(const AX, AY: Extended): Extended;
var
  LResult: Extended;
begin
  if ExtendedIsNaN(AX) or ExtendedIsNaN(AY) or (AY = 0.0) or ExtendedIsInfinite(AX) then
    Exit(ExtendedQuietNaN);
  if ExtendedIsInfinite(AY) then
    Exit(AX);
  LResult := FmodPositiveFinite(ExtendedAbsFinite(AX), ExtendedAbsFinite(AY));
  if LResult = 0.0 then
  begin
    Result := ExtendedSignedZero(ExtendedHasSignBit(AX));
    Exit;
  end;
  if ExtendedHasSignBit(AX) then
    Result := -LResult
  else
    Result := LResult;
end;
{$ENDIF}

end.
