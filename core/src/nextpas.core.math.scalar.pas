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
function Lerp(const AA, AB, AT: Double): Double; overload; inline;
function Lerp(const AA, AB, AT: Single): Single; overload; inline;
function InverseLerp(const AA, AB, AValue: Double): Double; overload; inline;
function InverseLerp(const AA, AB, AValue: Single): Single; overload; inline;
function Wrap(const AValue, AMin, AMax: Double): Double; overload;
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

implementation

uses
  nextpas.core.errors,
  nextpas.core.math.impl.scalar;

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
  Result := AA + (AB - AA) * AT;
end;

function Lerp(const AA, AB, AT: Double): Double;
begin
  Result := AA + (AB - AA) * AT;
end;

function InverseLerp(const AA, AB, AValue: Single): Single;
begin
  if AA = AB then
    Exit(0.0);
  Result := (AValue - AA) / (AB - AA);
end;

function InverseLerp(const AA, AB, AValue: Double): Double;
begin
  if AA = AB then
    Exit(0.0);
  Result := (AValue - AA) / (AB - AA);
end;

function Wrap(const AValue, AMin, AMax: Single): Single;
begin
  Result := Single(Wrap(Double(AValue), Double(AMin), Double(AMax)));
end;

function Wrap(const AValue, AMin, AMax: Double): Double;
var
  LRange: Double;
begin
  RequireWrapInputs(AValue, AMin, AMax);
  LRange := AMax - AMin;
  if LRange = 0.0 then
    Exit(AMin);
  Result := AValue - LRange * System.Int((AValue - AMin) / LRange);
  if Result < AMin then
    Result := Result + LRange;
end;

function SmoothStep(const AEdge0, AEdge1, AValue: Single): Single;
var
  LT: Single;
begin
  if AEdge0 = AEdge1 then
  begin
    if AValue < AEdge0 then
      Exit(0.0);
    Exit(1.0);
  end;
  LT := Clamp((AValue - AEdge0) / (AEdge1 - AEdge0), Single(0.0), Single(1.0));
  Result := LT * LT * (Single(3.0) - Single(2.0) * LT);
end;

function SmoothStep(const AEdge0, AEdge1, AValue: Double): Double;
var
  LT: Double;
begin
  if AEdge0 = AEdge1 then
  begin
    if AValue < AEdge0 then
      Exit(0.0);
    Exit(1.0);
  end;
  LT := Clamp((AValue - AEdge0) / (AEdge1 - AEdge0), 0.0, 1.0);
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
  if AValue > 0.0 then
    Result := 1.0
  else if AValue < 0.0 then
    Result := -1.0
  else
    Result := 0.0;
end;

function Sign(const AValue: Double): Double;
begin
  if AValue > 0.0 then
    Result := 1.0
  else if AValue < 0.0 then
    Result := -1.0
  else
    Result := 0.0;
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
  Result := ARadians * Single(RAD_TO_DEG);
end;

function RadToDeg(const ARadians: Double): Double;
begin
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
  Result := LMax * Single(System.Sqrt(1.0 + LRatio * LRatio));
end;

function Hypot(const AX, AY: Double): Double;
var
  LX, LY, LMax, LMin, LRatio: Double;
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
  Result := LMax * System.Sqrt(1.0 + LRatio * LRatio);
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

end.
