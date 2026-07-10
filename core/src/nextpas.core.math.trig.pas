unit nextpas.core.math.trig;

{$I nextpas.core.settings.inc}

interface

const
  PI_VALUE: Double = 3.14159265358979323846;
  TWO_PI: Double = 6.28318530717958647692;
  HALF_PI: Double = 1.57079632679489661923;

{** * Computes the sine of AX (radians).
 * @param AX Angle in radians
 * @return sin(AX)
 *}
function Sin(const AX: Double): Double; overload; inline;
function Sin(const AX: Single): Single; overload; inline;

{** * Computes the cosine of AX (radians).
 * @param AX Angle in radians
 * @return cos(AX)
 *}
function Cos(const AX: Double): Double; overload; inline;
function Cos(const AX: Single): Single; overload; inline;

{** * Computes the tangent of AX (radians).
 * @param AX Angle in radians
 * @return tan(AX)
 *}
function Tan(const AX: Double): Double; overload; inline;
function Tan(const AX: Single): Single; overload; inline;

{** * Computes the inverse sine (arcsine) of AX.
 * @param AX Value in [-1, 1]
 * @return arcsin(AX) in radians, or NaN if AX is out of range
 *}
function ArcSin(const AX: Double): Double; overload; inline;
function ArcSin(const AX: Single): Single; overload; inline;

{** * Computes the inverse cosine (arccosine) of AX.
 * @param AX Value in [-1, 1]
 * @return arccos(AX) in radians, or NaN if AX is out of range
 *}
function ArcCos(const AX: Double): Double; overload; inline;
function ArcCos(const AX: Single): Single; overload; inline;

{** * Computes the inverse tangent (arctangent) of AX.
 * @param AX The input value
 * @return arctan(AX) in radians
 *}
function ArcTan(const AX: Double): Double; overload; inline;
function ArcTan(const AX: Single): Single; overload; inline;

{** * Computes the two-argument arctangent of AY / AX, using the signs to determine quadrant.
 * @param AY The Y coordinate
 * @param AX The X coordinate
 * @return arctan2(AY, AX) in radians
 *}
function ArcTan2(const AY, AX: Double): Double; overload; inline;
function ArcTan2(const AY, AX: Single): Single; overload; inline;

{** * Computes the exponential function e^AX.
 * @param AX The exponent
 * @return e^AX
 *}
function Exp(const AX: Double): Double; overload; inline;
function Exp(const AX: Single): Single; overload; inline;

{** * Computes the natural logarithm of AX.
 * @param AX The input value (must be positive)
 * @return ln(AX)
 *}
function Ln(const AX: Double): Double; overload; inline;
function Ln(const AX: Single): Single; overload; inline;

{** * Computes the base-2 logarithm of AX.
 * @param AX The input value (must be positive)
 * @return log2(AX)
 *}
function Log2(const AX: Double): Double; overload; inline;
function Log2(const AX: Single): Single; overload; inline;

{** * Computes the base-10 logarithm of AX.
 * @param AX The input value (must be positive)
 * @return log10(AX)
 *}
function Log10(const AX: Double): Double; overload; inline;
function Log10(const AX: Single): Single; overload; inline;

{** * Computes ABase raised to the power AExponent.
 * @param ABase The base value
 * @param AExponent The exponent
 * @return ABase^AExponent
 *}
function Power(const ABase, AExponent: Double): Double; overload; inline;
function Power(const ABase, AExponent: Single): Single; overload; inline;

{** * Computes the square root of AX.
 * @param AX The input value (must be non-negative)
 * @return sqrt(AX), or NaN if AX is negative
 *}
function Sqrt(const AX: Double): Double; overload; inline;
function Sqrt(const AX: Single): Single; overload; inline;

implementation

uses
  nextpas.core.math.impl.scalar;

const
  DOUBLE_EXP_OVERFLOW_LIMIT: Double = 709.7827128933839731;
  DOUBLE_EXP_UNDERFLOW_ZERO_LIMIT: Double = -745.1332191019411084;
  SINGLE_EXP_OVERFLOW_LIMIT: Double = 88.722839052068353;
  SINGLE_EXP_UNDERFLOW_ZERO_LIMIT: Double = -103.9720840454101563;

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

function DoubleHasSignBit(const AValue: Double): Boolean; inline;
var
  LBits: UInt64;
begin
  Move(AValue, LBits, SizeOf(LBits));
  Result := (LBits and UInt64($8000000000000000)) <> 0;
end;

function DoubleIsPositiveOneBits(const AValue: Double): Boolean; inline;
var
  LBits: UInt64;
begin
  Move(AValue, LBits, SizeOf(LBits));
  Result := LBits = UInt64($3FF0000000000000);
end;

function DoubleSignedZero(const ANegative: Boolean): Double; inline;
begin
  Result := 0.0;
  if ANegative then
    Result := -Result;
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

function AbsDouble(const AValue: Double): Double; inline;
begin
  if AValue < 0.0 then
    Result := -AValue
  else
    Result := AValue;
end;

function ProductGreaterThan(const ALeft, ARight, ALimit: Double): Boolean; inline;
begin
  if ARight > 0.0 then
    Result := ALeft > ALimit / ARight
  else if ARight < 0.0 then
    Result := ALeft < ALimit / ARight
  else
    Result := 0.0 > ALimit;
end;

function ProductLessThan(const ALeft, ARight, ALimit: Double): Boolean; inline;
begin
  if ARight > 0.0 then
    Result := ALeft < ALimit / ARight
  else if ARight < 0.0 then
    Result := ALeft > ALimit / ARight
  else
    Result := 0.0 < ALimit;
end;

function Sin(const AX: Single): Single;
begin
  Result := Single(Sin(Double(AX)));
end;

function Sin(const AX: Double): Double;
begin
  if DoubleIsNaN(AX) or DoubleIsInfinite(AX) then
    Exit(DoubleQuietNaN);
  if AX = 0.0 then
    Exit(DoubleSignedZero(DoubleHasSignBit(AX)));
  Result := System.Sin(AX);
end;

function Cos(const AX: Single): Single;
begin
  Result := Single(Cos(Double(AX)));
end;

function Cos(const AX: Double): Double;
begin
  if DoubleIsNaN(AX) or DoubleIsInfinite(AX) then
    Exit(DoubleQuietNaN);
  Result := System.Cos(AX);
end;

function Tan(const AX: Single): Single;
begin
  if DoubleIsNaN(AX) or DoubleIsInfinite(AX) then
    Exit(Single(Tan(Double(AX))));
  if AX = Single(HALF_PI) then
    Exit(SingleSignedInfinity(False));
  if AX = Single(-HALF_PI) then
    Exit(SingleSignedInfinity(True));
  Result := Single(Tan(Double(AX)));
end;

function Tan(const AX: Double): Double;
begin
  if DoubleIsNaN(AX) or DoubleIsInfinite(AX) then
    Exit(DoubleQuietNaN);
  if AX = 0.0 then
    Exit(DoubleSignedZero(DoubleHasSignBit(AX)));
  if AX = HALF_PI then
    Exit(DoubleSignedInfinity(False));
  if AX = -HALF_PI then
    Exit(DoubleSignedInfinity(True));
  Result := Sin(AX) / Cos(AX);
end;

function ArcSin(const AX: Single): Single;
begin
  Result := Single(ArcSin(Double(AX)));
end;

function ArcSin(const AX: Double): Double;
begin
  if DoubleIsNaN(AX) or (AX < -1.0) or (AX > 1.0) then
    Exit(DoubleQuietNaN);
  if AX = 0.0 then
    Exit(DoubleSignedZero(DoubleHasSignBit(AX)));
  if AX = 1.0 then
    Exit(HALF_PI);
  if AX = -1.0 then
    Exit(-HALF_PI);
  Result := ArcTan2(AX, Sqrt(1.0 - AX * AX));
end;

function ArcCos(const AX: Single): Single;
begin
  Result := Single(ArcCos(Double(AX)));
end;

function ArcCos(const AX: Double): Double;
begin
  if DoubleIsNaN(AX) or (AX < -1.0) or (AX > 1.0) then
    Exit(DoubleQuietNaN);
  if AX = 1.0 then
    Exit(0.0);
  if AX = -1.0 then
    Exit(PI_VALUE);
  Result := ArcTan2(Sqrt(1.0 - AX * AX), AX);
end;

function ArcTan(const AX: Single): Single;
begin
  Result := Single(ArcTan(Double(AX)));
end;

function ArcTan(const AX: Double): Double;
begin
  if DoubleIsNaN(AX) then
    Exit(DoubleQuietNaN);
  if DoubleIsInfinite(AX) then
  begin
    if AX > 0.0 then
      Exit(HALF_PI);
    Exit(-HALF_PI);
  end;
  if AX = 0.0 then
    Exit(DoubleSignedZero(DoubleHasSignBit(AX)));
  if AX = 1.0 then
    Exit(PI_VALUE / 4.0);
  if AX = -1.0 then
    Exit(-PI_VALUE / 4.0);
  Result := System.ArcTan(AX);
end;

function ArcTan2(const AY, AX: Single): Single;
begin
  Result := Single(ArcTan2(Double(AY), Double(AX)));
end;

function ArcTan2(const AY, AX: Double): Double;
begin
  if DoubleIsNaN(AY) or DoubleIsNaN(AX) then
    Exit(DoubleQuietNaN);

  if DoubleIsInfinite(AY) and DoubleIsInfinite(AX) then
  begin
    if AX > 0.0 then
    begin
      if AY > 0.0 then
        Exit(PI_VALUE / 4.0);
      Exit(-PI_VALUE / 4.0);
    end;

    if AY > 0.0 then
      Exit(3.0 * PI_VALUE / 4.0);
    Exit(-3.0 * PI_VALUE / 4.0);
  end;

  if DoubleIsInfinite(AY) then
  begin
    if AY > 0.0 then
      Exit(HALF_PI);
    Exit(-HALF_PI);
  end;

  if AY = 0.0 then
  begin
    if (AX < 0.0) or ((AX = 0.0) and DoubleHasSignBit(AX)) then
    begin
      if DoubleHasSignBit(AY) then
        Exit(-PI_VALUE);
      Exit(PI_VALUE);
    end;
    Exit(DoubleSignedZero(DoubleHasSignBit(AY)));
  end;

  if DoubleIsInfinite(AX) then
  begin
    if AX > 0.0 then
      Exit(DoubleSignedZero(DoubleHasSignBit(AY)));
    if AY > 0.0 then
      Exit(PI_VALUE);
    Exit(-PI_VALUE);
  end;

  if AX > 0.0 then
  begin
    if AbsDouble(AY) > AX then
    begin
      if AY > 0.0 then
        Result := HALF_PI - ArcTan(AX / AY)
      else
        Result := -HALF_PI + ArcTan(AX / -AY);
    end
    else
      Result := ArcTan(AY / AX);
  end
  else if AX < 0.0 then
  begin
    if AbsDouble(AY) > -AX then
    begin
      if AY > 0.0 then
        Result := HALF_PI + ArcTan((-AX) / AY)
      else
        Result := -HALF_PI - ArcTan((-AX) / -AY);
    end
    else
    begin
      if AY > 0.0 then
        Result := ArcTan(AY / AX) + PI_VALUE
      else
        Result := ArcTan(AY / AX) - PI_VALUE;
    end;
  end
  else if AY > 0.0 then
    Result := HALF_PI
  else if AY < 0.0 then
    Result := -HALF_PI
  else
    Result := 0.0;
end;

function Exp(const AX: Single): Single;
begin
  if SingleIsNaN(AX) then
    Exit(SingleQuietNaN);
  if SingleIsInfinite(AX) then
  begin
    if AX > 0.0 then
      Exit(AX);
    Exit(SingleSignedZero(False));
  end;
  if Double(AX) > SINGLE_EXP_OVERFLOW_LIMIT then
    Exit(SingleSignedInfinity(False));
  if Double(AX) < SINGLE_EXP_UNDERFLOW_ZERO_LIMIT then
    Exit(SingleSignedZero(False));
  Result := Single(System.Exp(Double(AX)));
end;

function Exp(const AX: Double): Double;
begin
  if DoubleIsNaN(AX) then
    Exit(DoubleQuietNaN);
  if DoubleIsInfinite(AX) then
  begin
    if AX > 0.0 then
      Exit(AX);
    Exit(DoubleSignedZero(False));
  end;
  if AX > DOUBLE_EXP_OVERFLOW_LIMIT then
    Exit(DoubleSignedInfinity(False));
  if AX < DOUBLE_EXP_UNDERFLOW_ZERO_LIMIT then
    Exit(DoubleSignedZero(False));
  Result := System.Exp(AX);
end;

function Ln(const AX: Single): Single;
begin
  Result := Single(Ln(Double(AX)));
end;

function Ln(const AX: Double): Double;
begin
  if DoubleIsNaN(AX) then
    Exit(DoubleQuietNaN);
  if AX < 0.0 then
    Exit(DoubleQuietNaN);
  if AX = 0.0 then
    Exit(DoubleSignedInfinity(True));
  if DoubleIsInfinite(AX) then
    Exit(AX);
  Result := System.Ln(AX);
end;

function Log2(const AX: Single): Single;
begin
  Result := Single(Log2(Double(AX)));
end;

function Log2(const AX: Double): Double;
begin
  if DoubleIsNaN(AX) then
    Exit(DoubleQuietNaN);
  if AX < 0.0 then
    Exit(DoubleQuietNaN);
  if AX = 0.0 then
    Exit(DoubleSignedInfinity(True));
  if DoubleIsInfinite(AX) then
    Exit(AX);
  if AX = 1.0 then
    Exit(0.0);
  if AX = 2.0 then
    Exit(1.0);
  Result := Ln(AX) / 0.69314718055994530942;
end;

function Log10(const AX: Single): Single;
begin
  Result := Single(Log10(Double(AX)));
end;

function Log10(const AX: Double): Double;
begin
  if DoubleIsNaN(AX) then
    Exit(DoubleQuietNaN);
  if AX < 0.0 then
    Exit(DoubleQuietNaN);
  if AX = 0.0 then
    Exit(DoubleSignedInfinity(True));
  if DoubleIsInfinite(AX) then
    Exit(AX);
  if AX = 1.0 then
    Exit(0.0);
  if AX = 10.0 then
    Exit(1.0);
  Result := Ln(AX) / 2.30258509299404568402;
end;

function IsIntegerValue(const AValue: Double): Boolean;
begin
  Result := AValue = System.Int(AValue);
end;

function IsOddIntegerValue(const AValue: Double): Boolean;
var
  LExponent: Int64;
begin
  if (not IsIntegerValue(AValue)) or
    (AValue < -9223372036854775808.0) or
    (AValue >= 9223372036854775808.0) then
    Exit(False);
  LExponent := System.Trunc(AValue);
  Result := (LExponent and 1) <> 0;
end;

function PowerWithExpLimits(const ABase, AExponent, AOverflowLimit,
  AUnderflowZeroLimit: Double): Double;
var
  LAbsBase: Double;
  LLogAbsBase: Double;
  LResult: Double;
  LScaledExponent: Double;
  LNegativeResult: Boolean;
begin
  if DoubleIsPositiveOneBits(ABase) then
    Exit(1.0);
  if DoubleIsNaN(AExponent) then
    Exit(DoubleQuietNaN);
  if AExponent = 0.0 then
    Exit(1.0);
  if DoubleIsNaN(ABase) then
    Exit(DoubleQuietNaN);
  if AExponent = 1.0 then
    Exit(ABase);
  if ABase = 0.0 then
  begin
    if AExponent > 0.0 then
      Exit(DoubleSignedZero(DoubleHasSignBit(ABase) and IsOddIntegerValue(AExponent)));
    if DoubleHasSignBit(ABase) and IsOddIntegerValue(AExponent) then
      Exit(DoubleSignedInfinity(True));
    Exit(DoubleSignedInfinity(False));
  end;
  if ((ABase = 1.0) or (ABase = -1.0)) and DoubleIsInfinite(AExponent) then
    Exit(1.0);
  if DoubleIsInfinite(AExponent) then
  begin
    LAbsBase := ABase;
    if LAbsBase < 0.0 then
      LAbsBase := -LAbsBase;
    if LAbsBase > 1.0 then
    begin
      if AExponent > 0.0 then
        Exit(DoubleSignedInfinity(False));
      Exit(DoubleSignedZero(False));
    end;
    if LAbsBase < 1.0 then
    begin
      if AExponent > 0.0 then
        Exit(DoubleSignedZero(False));
      Exit(DoubleSignedInfinity(False));
    end;
  end;
  if DoubleIsInfinite(ABase) then
  begin
    if AExponent > 0.0 then
    begin
      if (ABase < 0.0) and IsOddIntegerValue(AExponent) then
        Exit(DoubleSignedInfinity(True));
      Exit(DoubleSignedInfinity(False));
    end;
    if (ABase < 0.0) and IsOddIntegerValue(AExponent) then
      Exit(DoubleSignedZero(True));
    Exit(DoubleSignedZero(False));
  end;

  if ABase < 0.0 then
  begin
    if not IsIntegerValue(AExponent) then
      Exit(DoubleQuietNaN);
    LAbsBase := -ABase;
  end;

  if ABase > 0.0 then
    LAbsBase := ABase;

  LLogAbsBase := System.Ln(LAbsBase);
  LNegativeResult := (ABase < 0.0) and IsOddIntegerValue(AExponent);
  if ProductGreaterThan(AExponent, LLogAbsBase, AOverflowLimit) then
    Exit(DoubleSignedInfinity(LNegativeResult));
  if ProductLessThan(AExponent, LLogAbsBase, AUnderflowZeroLimit) then
    Exit(DoubleSignedZero(LNegativeResult));

  LScaledExponent := AExponent * LLogAbsBase;
  LResult := System.Exp(LScaledExponent);
  if LNegativeResult then
    Result := -LResult
  else
    Result := LResult;
end;

function Power(const ABase, AExponent: Double): Double;
begin
  Result := PowerWithExpLimits(ABase, AExponent, DOUBLE_EXP_OVERFLOW_LIMIT,
    DOUBLE_EXP_UNDERFLOW_ZERO_LIMIT);
end;

function Power(const ABase, AExponent: Single): Single;
begin
  Result := Single(PowerWithExpLimits(Double(ABase), Double(AExponent),
    SINGLE_EXP_OVERFLOW_LIMIT, SINGLE_EXP_UNDERFLOW_ZERO_LIMIT));
end;

function Sqrt(const AX: Double): Double;
begin
  if DoubleIsNaN(AX) then
    Exit(DoubleQuietNaN);
  if AX = 0.0 then
    Exit(DoubleSignedZero(DoubleHasSignBit(AX)));
  if DoubleIsInfinite(AX) then
  begin
    if AX > 0.0 then
      Exit(AX);
    Exit(DoubleQuietNaN);
  end;
  if AX < 0.0 then
    Exit(DoubleQuietNaN);
  Result := System.Sqrt(AX);
end;

function Sqrt(const AX: Single): Single;
begin
  Result := Single(Sqrt(Double(AX)));
end;

end.
