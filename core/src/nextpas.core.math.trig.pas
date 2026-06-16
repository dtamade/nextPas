unit nextpas.core.math.trig;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.math.base,
  nextpas.core.math.scalar;

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

function DegToRad(const ADeg: Double): Double; overload; inline;
function DegToRad(const ADeg: Single): Single; overload; inline;
function RadToDeg(const ARad: Double): Double; overload; inline;
function RadToDeg(const ARad: Single): Single; overload; inline;

{ Hyperbolic functions }

{** * Computes the hyperbolic sine of AX.
 * @param AX The input value
 * @return sinh(AX)
 *}
function Sinh(const AX: Double): Double; overload; inline;
function Sinh(const AX: Single): Single; overload; inline;

{** * Computes the hyperbolic cosine of AX.
 * @param AX The input value
 * @return cosh(AX)
 *}
function Cosh(const AX: Double): Double; overload; inline;
function Cosh(const AX: Single): Single; overload; inline;

{** * Computes the hyperbolic tangent of AX.
 * @param AX The input value
 * @return tanh(AX) in [-1, 1]
 *}
function Tanh(const AX: Double): Double; overload; inline;
function Tanh(const AX: Single): Single; overload; inline;

{ Inverse hyperbolic functions }

{** * Computes the inverse hyperbolic sine of AX.
 * @param AX The input value
 * @return arsinh(AX)
 *}
function ArcSinh(const AX: Double): Double; overload; inline;
function ArcSinh(const AX: Single): Single; overload; inline;

{** * Computes the inverse hyperbolic cosine of AX.
 * @param AX The input value (must be >= 1)
 * @return arcosh(AX), or NaN if AX < 1
 *}
function ArcCosh(const AX: Double): Double; overload; inline;
function ArcCosh(const AX: Single): Single; overload; inline;

{** * Computes the inverse hyperbolic tangent of AX.
 * @param AX The input value (must be in (-1, 1))
 * @return artanh(AX), or NaN if |AX| >= 1
 *}
function ArcTanh(const AX: Double): Double; overload; inline;
function ArcTanh(const AX: Single): Single; overload; inline;

{ Secant / Cosecant }

{** * Computes the secant of AX (radians): 1 / cos(AX).
 * @param AX Angle in radians
 * @return sec(AX)
 *}
function Sec(const AX: Double): Double; overload; inline;
function Sec(const AX: Single): Single; overload; inline;

{** * Computes the cosecant of AX (radians): 1 / sin(AX).
 * @param AX Angle in radians
 * @return csc(AX)
 *}
function Csc(const AX: Double): Double; overload; inline;
function Csc(const AX: Single): Single; overload; inline;

{ LogN / IntPower / Ldexp }

{** * Computes the logarithm of AX with an arbitrary base.
 * @param ABase The logarithm base (must be positive and not 1)
 * @param AX The input value (must be positive)
 * @return log_BASE(AX)
 *}
function LogN(const ABase, AX: Double): Double; overload; inline;
function LogN(const ABase, AX: Single): Single; overload; inline;

{** * Computes ABase raised to an integer exponent using exponentiation by squaring.
 * @param ABase The base value
 * @param AExponent The integer exponent
 * @return ABase^AExponent
 *}
function IntPower(const ABase: Double; AExponent: Int64): Double; overload; inline;
function IntPower(const ABase: Single; AExponent: Int64): Single; overload; inline;

{** * Multiplies AX by 2^AExp.
 * @param AX The significand
 * @param AExp The power-of-2 exponent
 * @return AX * 2^AExp
 *}
function Ldexp(const AX: Double; AExp: Integer): Double; overload; inline;
function Ldexp(const AX: Single; AExp: Integer): Single; overload; inline;

implementation

uses
  nextpas.core.math.impl.scalar;

function Sin(const AX: Single): Single;
begin
  Result := Single(System.Sin(Double(AX)));
end;

function Sin(const AX: Double): Double;
begin
  Result := System.Sin(AX);
end;

function Cos(const AX: Single): Single;
begin
  Result := Single(System.Cos(Double(AX)));
end;

function Cos(const AX: Double): Double;
begin
  Result := System.Cos(AX);
end;

function Tan(const AX: Single): Single;
begin
  Result := Single(Tan(Double(AX)));
end;

function Tan(const AX: Double): Double;
begin
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
  Result := Single(System.ArcTan(Double(AX)));
end;

function ArcTan(const AX: Double): Double;
begin
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

  if AX > 0.0 then
    Result := ArcTan(AY / AX)
  else if AX < 0.0 then
  begin
    if AY >= 0.0 then
      Result := ArcTan(AY / AX) + PI_VALUE
    else
      Result := ArcTan(AY / AX) - PI_VALUE;
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
  Result := Single(System.Exp(Double(AX)));
end;

function Exp(const AX: Double): Double;
begin
  Result := System.Exp(AX);
end;

function Ln(const AX: Single): Single;
begin
  Result := Single(System.Ln(Double(AX)));
end;

function Ln(const AX: Double): Double;
begin
  Result := System.Ln(AX);
end;

function Log2(const AX: Single): Single;
begin
  Result := Single(Log2(Double(AX)));
end;

function Log2(const AX: Double): Double;
begin
  Result := Ln(AX) / 0.69314718055994530942;
end;

function Log10(const AX: Single): Single;
begin
  Result := Single(Log10(Double(AX)));
end;

function Log10(const AX: Double): Double;
begin
  Result := Ln(AX) / 2.30258509299404568402;
end;

function IsIntegerValue(const AValue: Double): Boolean;
begin
  Result := AValue = System.Int(AValue);
end;

function Power(const ABase, AExponent: Double): Double;
var
  LAbsBase: Double;
  LExponent: Int64;
  LResult: Double;
begin
  if AExponent = 0.0 then
    Exit(1.0);
  if ABase = 0.0 then
  begin
    if AExponent > 0.0 then
      Exit(0.0);
    Exit(1.0 / 0.0);
  end;

  if (ABase < 0.0) and IsIntegerValue(AExponent) and
    (AExponent >= -9223372036854775808.0) and
    (AExponent < 9223372036854775808.0) then
  begin
    LAbsBase := -ABase;
    LExponent := System.Trunc(AExponent);
    LResult := System.Exp(AExponent * System.Ln(LAbsBase));
    if (LExponent and 1) <> 0 then
      Result := -LResult
    else
      Result := LResult;
    Exit;
  end;

  Result := System.Exp(AExponent * System.Ln(ABase));
end;

function Power(const ABase, AExponent: Single): Single;
begin
  Result := Single(Power(Double(ABase), Double(AExponent)));
end;

function Sqrt(const AX: Double): Double;
begin
  if DoubleIsNaN(AX) then
    Exit(DoubleQuietNaN);
  if AX < 0.0 then
    Exit(DoubleQuietNaN);
  Result := System.Sqrt(AX);
end;

function Sqrt(const AX: Single): Single;
begin
  Result := Single(Sqrt(Double(AX)));
end;

{ Hyperbolic functions }

function Sinh(const AX: Double): Double;
begin
  if DoubleIsNaN(AX) then
    Exit(DoubleQuietNaN);
  if DoubleIsInfinite(AX) then
    Exit(AX);
  // Odd function: avoid cancellation for large negative values
  if AX < 0.0 then
    Exit(-Sinh(-AX));
  Result := (System.Exp(AX) - System.Exp(-AX)) / 2.0;
end;

function Sinh(const AX: Single): Single;
begin
  Result := Single(Sinh(Double(AX)));
end;

function Cosh(const AX: Double): Double;
begin
  if DoubleIsNaN(AX) then
    Exit(DoubleQuietNaN);
  if DoubleIsInfinite(AX) then
    Exit(Abs(AX));
  Result := (System.Exp(AX) + System.Exp(-AX)) / 2.0;
end;

function Cosh(const AX: Single): Single;
begin
  Result := Single(Cosh(Double(AX)));
end;

function Tanh(const AX: Double): Double;
var
  LExp2X: Double;
begin
  if DoubleIsNaN(AX) then
    Exit(DoubleQuietNaN);
  if DoubleIsInfinite(AX) then
  begin
    if AX > 0.0 then Exit(1.0)
    else Exit(-1.0);
  end;
  LExp2X := System.Exp(2.0 * AX);
  Result := (LExp2X - 1.0) / (LExp2X + 1.0);
end;

function Tanh(const AX: Single): Single;
begin
  Result := Single(Tanh(Double(AX)));
end;

{ Inverse hyperbolic functions }

function ArcSinh(const AX: Double): Double;
begin
  if DoubleIsNaN(AX) then
    Exit(DoubleQuietNaN);
  if DoubleIsInfinite(AX) then
    Exit(AX);
  // Odd function: avoid cancellation for large negative values
  if AX < 0.0 then
    Exit(-ArcSinh(-AX));
  Result := System.Ln(AX + System.Sqrt(AX * AX + 1.0));
end;

function ArcSinh(const AX: Single): Single;
begin
  Result := Single(ArcSinh(Double(AX)));
end;

function ArcCosh(const AX: Double): Double;
begin
  if DoubleIsNaN(AX) then
    Exit(DoubleQuietNaN);
  if AX < 1.0 then
    Exit(DoubleQuietNaN);
  if AX = 1.0 then
    Exit(0.0);
  Result := System.Ln(AX + System.Sqrt(AX * AX - 1.0));
end;

function ArcCosh(const AX: Single): Single;
begin
  Result := Single(ArcCosh(Double(AX)));
end;

function ArcTanh(const AX: Double): Double;
begin
  if DoubleIsNaN(AX) then
    Exit(DoubleQuietNaN);
  if (AX <= -1.0) or (AX >= 1.0) then
    Exit(DoubleQuietNaN);
  Result := System.Ln((1.0 + AX) / (1.0 - AX)) / 2.0;
end;

function ArcTanh(const AX: Single): Single;
begin
  Result := Single(ArcTanh(Double(AX)));
end;

{ Secant / Cosecant }

function Sec(const AX: Double): Double;
begin
  if DoubleIsNaN(AX) then
    Exit(DoubleQuietNaN);
  Result := 1.0 / Cos(AX);
end;

function Sec(const AX: Single): Single;
begin
  Result := Single(Sec(Double(AX)));
end;

function Csc(const AX: Double): Double;
begin
  if DoubleIsNaN(AX) then
    Exit(DoubleQuietNaN);
  Result := 1.0 / Sin(AX);
end;

function Csc(const AX: Single): Single;
begin
  Result := Single(Csc(Double(AX)));
end;

{ LogN / IntPower / Ldexp }

function LogN(const ABase, AX: Double): Double;
begin
  if DoubleIsNaN(ABase) or DoubleIsNaN(AX) then
    Exit(DoubleQuietNaN);
  if (ABase <= 0.0) or (ABase = 1.0) or (AX <= 0.0) then
    Exit(DoubleQuietNaN);
  Result := System.Ln(AX) / System.Ln(ABase);
end;

function LogN(const ABase, AX: Single): Single;
begin
  Result := Single(LogN(Double(ABase), Double(AX)));
end;

function IntPower(const ABase: Double; AExponent: Int64): Double;
var
  LBase: Double;
  LExp: Int64;
begin
  if AExponent = 0 then
    Exit(1.0);
  if ABase = 0.0 then
  begin
    if AExponent > 0 then
      Exit(0.0);
    Exit(1.0 / 0.0);
  end;
  LBase := ABase;
  LExp := AExponent;
  // Low(Int64) cannot be negated (overflow), handle via division path
  if LExp < 0 then
  begin
    if LExp = Low(Int64) then
      Exit(1.0 / (IntPower(LBase, -LExp - 1) * LBase));
    LBase := 1.0 / LBase;
    LExp := -LExp;
  end;
  Result := 1.0;
  while LExp > 0 do
  begin
    if (LExp and 1) <> 0 then
      Result := Result * LBase;
    LBase := LBase * LBase;
    LExp := LExp shr 1;
  end;
end;

function IntPower(const ABase: Single; AExponent: Int64): Single;
begin
  Result := Single(IntPower(Double(ABase), AExponent));
end;

function Ldexp(const AX: Double; AExp: Integer): Double;
var
  LPow: Double;
  LE: Integer;
begin
  if AExp = 0 then
    Exit(AX);
  LPow := 1.0;
  LE := AExp;
  if LE < 0 then
  begin
    while LE < 0 do
    begin
      LPow := LPow / 2.0;
      Inc(LE);
    end;
  end
  else
  begin
    while LE > 0 do
    begin
      LPow := LPow * 2.0;
      Dec(LE);
    end;
  end;
  Result := AX * LPow;
end;

function Ldexp(const AX: Single; AExp: Integer): Single;
begin
  Result := Single(Ldexp(Double(AX), AExp));
end;

function DegToRad(const ADeg: Single): Single;
begin
  Result := ADeg * Single(DEG_TO_RAD);
end;

function DegToRad(const ADeg: Double): Double;
begin
  Result := ADeg * DEG_TO_RAD;
end;

function RadToDeg(const ARad: Single): Single;
begin
  Result := ARad * Single(RAD_TO_DEG);
end;

function RadToDeg(const ARad: Double): Double;
begin
  Result := ARad * RAD_TO_DEG;
end;

end.
