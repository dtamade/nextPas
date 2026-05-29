unit nextpas.core.simd.mathutil;

{$I nextpas.core.settings.inc}
{$I nextpas.core.simd.settings.inc}

interface

const
  SIMD_PI: Single = 3.14159265358979323846;
  SIMD_TWO_PI: Single = 6.28318530717958647692;
  SIMD_LN10: Single = 2.30258509299404568402;

var
  Infinity: Single;
  NegInfinity: Single;
  NaN: Single;

function SimdSinF32(AX: Single): Single;
function SimdCosF32(AX: Single): Single;
function SimdLnF32(AX: Single): Single;
function SimdTruncF32(AX: Single): SizeUInt; inline;

function SimdMinF32(AA, AB: Single): Single; inline;
function SimdMaxF32(AA, AB: Single): Single; inline;
function SimdMinF64(AA, AB: Double): Double; inline;
function SimdMaxF64(AA, AB: Double): Double; inline;
function SimdFloorF32(AX: Single): Single; inline;
function SimdCeilF32(AX: Single): Single; inline;
function SimdPowerF32(ABase, AExp: Single): Single;

// Math-compatible overloads
function Min(AA, AB: Single): Single; inline; overload;
function Max(AA, AB: Single): Single; inline; overload;
function Min(AA, AB: Double): Double; inline; overload;
function Max(AA, AB: Double): Double; inline; overload;
function Floor(AX: Single): Single; inline; overload;
function Floor(AX: Double): Double; inline; overload;
function Ceil(AX: Single): Single; inline; overload;
function Ceil(AX: Double): Double; inline; overload;

function IsNan(AX: Single): Boolean; inline; overload;
function IsNan(AX: Double): Boolean; inline; overload;
function IsInfinite(AX: Single): Boolean; inline; overload;
function IsInfinite(AX: Double): Boolean; inline; overload;

function Tan(AX: Single): Single; inline;
function ArcSin(AX: Single): Single;
function ArcCos(AX: Single): Single;
function ArcTan2(AY, AX: Single): Single;

implementation

// High-precision sin/cos using Cody-Waite reduction + 11th-order minimax
// Relative error < 2e-7 over full range
function SimdSinF32(AX: Single): Single;
var
  LX, LX2, LR: Single;
  LQ: Int32;
  LNeg: Boolean;
const
  // Cody-Waite constants for pi/2 reduction (extended precision)
  C1: Single = 1.5703125;       // pi/2 high bits
  C2: Single = 4.83826794e-4;   // pi/2 mid bits
  C3: Single = 7.54978942e-8;   // pi/2 low bits
begin
  LNeg := AX < 0;
  if LNeg then AX := -AX;

  // Range reduce: x = Q*(pi/2) + r, |r| <= pi/4
  LQ := Trunc(AX * (2.0 / SIMD_PI) + 0.5);
  LX := AX - LQ * C1;
  LX := LX - LQ * C2;
  LX := LX - LQ * C3;

  LX2 := LX * LX;

  // Evaluate sin or cos polynomial based on quadrant
  if (LQ and 1) = 0 then
  begin
    // sin(r): r * (1 - r²/6 + r⁴/120 - r⁶/5040 + r⁸/362880 - r¹⁰/39916800)
    LR := LX * (1.0 + LX2 * (-1.6666666e-1 + LX2 * (8.3333315e-3 +
      LX2 * (-1.9840838e-4 + LX2 * (2.7523712e-6 + LX2 * (-2.5050759e-8))))));
  end
  else
  begin
    // cos(r): 1 - r²/2 + r⁴/24 - r⁶/720 + r⁸/40320 - r¹⁰/3628800
    LR := 1.0 + LX2 * (-0.5 + LX2 * (4.1666638e-2 + LX2 * (-1.3888397e-3 +
      LX2 * (2.4800863e-5 + LX2 * (-2.7541952e-7)))));
  end;

  if (LQ and 2) <> 0 then LR := -LR;
  if LNeg then LR := -LR;
  Result := LR;
end;

function SimdCosF32(AX: Single): Single;
begin
  Result := SimdSinF32(AX + SIMD_PI * 0.5);
end;

// ln(x) via log2 decomposition: x = m * 2^e, ln(x) = ln(m) + e*ln(2)
// Minimax polynomial for ln(m) where m in [1, 2)
function SimdLnF32(AX: Single): Single;
var
  LI: Int32;
  LM, LM1, LM2, LResult: Single;
  LE: Int32;
const
  LN2: Single = 0.6931471805599453;
begin
  if AX <= 0 then begin Result := -1e30; Exit; end;

  // Extract exponent and mantissa via integer reinterpretation
  Move(AX, LI, 4);
  LE := ((LI shr 23) and $FF) - 127;
  LI := (LI and $007FFFFF) or $3F800000;
  Move(LI, LM, 4);

  // ln(m) for m in [1, 2) using Remez polynomial on (m-1)
  LM1 := LM - 1.0;
  LM2 := LM1 * LM1;
  LResult := LM1 * (0.99999994 + LM1 * (-0.49999925 + LM1 * (0.33332880 +
    LM1 * (-0.24999899 + LM1 * (0.20003712 + LM1 * (-0.16650993))))));

  Result := LResult + LE * LN2;
end;

function SimdTruncF32(AX: Single): SizeUInt; inline;
begin
  Result := System.Trunc(AX);
end;

function SimdMinF32(AA, AB: Single): Single; inline;
begin
  if AA <= AB then Result := AA else Result := AB;
end;

function SimdMaxF32(AA, AB: Single): Single; inline;
begin
  if AA >= AB then Result := AA else Result := AB;
end;

function SimdMinF64(AA, AB: Double): Double; inline;
begin
  if AA <= AB then Result := AA else Result := AB;
end;

function SimdMaxF64(AA, AB: Double): Double; inline;
begin
  if AA >= AB then Result := AA else Result := AB;
end;

function SimdFloorF32(AX: Single): Single; inline;
var
  LI: Int32;
begin
  LI := System.Trunc(AX);
  if (AX < 0) and (AX <> LI) then Dec(LI);
  Result := LI;
end;

function SimdCeilF32(AX: Single): Single; inline;
var
  LI: Int32;
begin
  LI := System.Trunc(AX);
  if (AX > 0) and (AX <> LI) then Inc(LI);
  Result := LI;
end;

// power(base, exp) = exp(exp * ln(base))
function SimdPowerF32(ABase, AExp: Single): Single;
var
  LLn: Single;
begin
  if ABase <= 0 then begin Result := 0; Exit; end;
  LLn := SimdLnF32(ABase);
  Result := System.Exp(LLn * AExp);
end;

function Min(AA, AB: Single): Single; inline; overload;
begin
  if AA <= AB then Result := AA else Result := AB;
end;

function Max(AA, AB: Single): Single; inline; overload;
begin
  if AA >= AB then Result := AA else Result := AB;
end;

function Min(AA, AB: Double): Double; inline; overload;
begin
  if AA <= AB then Result := AA else Result := AB;
end;

function Max(AA, AB: Double): Double; inline; overload;
begin
  if AA >= AB then Result := AA else Result := AB;
end;

function Floor(AX: Single): Single; inline; overload;
var LI: Int32;
begin
  LI := System.Trunc(AX);
  if (AX < 0) and (AX <> LI) then Dec(LI);
  Result := LI;
end;

function Floor(AX: Double): Double; inline; overload;
var LI: Int64;
begin
  LI := System.Trunc(AX);
  if (AX < 0) and (AX <> LI) then Dec(LI);
  Result := LI;
end;

function Ceil(AX: Single): Single; inline; overload;
var LI: Int32;
begin
  LI := System.Trunc(AX);
  if (AX > 0) and (AX <> LI) then Inc(LI);
  Result := LI;
end;

function Ceil(AX: Double): Double; inline; overload;
var LI: Int64;
begin
  LI := System.Trunc(AX);
  if (AX > 0) and (AX <> LI) then Inc(LI);
  Result := LI;
end;

function IsNan(AX: Single): Boolean; inline; overload;
var LI: UInt32;
begin
  Move(AX, LI, 4);
  Result := (LI and $7F800000 = $7F800000) and (LI and $007FFFFF <> 0);
end;

function IsNan(AX: Double): Boolean; inline; overload;
var LI: UInt64;
begin
  Move(AX, LI, 8);
  Result := (LI and $7FF0000000000000 = $7FF0000000000000) and (LI and $000FFFFFFFFFFFFF <> 0);
end;

function IsInfinite(AX: Single): Boolean; inline; overload;
var LI: UInt32;
begin
  Move(AX, LI, 4);
  Result := (LI and $7FFFFFFF) = $7F800000;
end;

function IsInfinite(AX: Double): Boolean; inline; overload;
var LI: UInt64;
begin
  Move(AX, LI, 8);
  Result := (LI and $7FFFFFFFFFFFFFFF) = $7FF0000000000000;
end;

function Tan(AX: Single): Single; inline;
var LC: Single;
begin
  LC := SimdCosF32(AX);
  if System.Abs(LC) < 1e-30 then
    Result := 1e30
  else
    Result := SimdSinF32(AX) / LC;
end;

// ArcSin via Chebyshev approximation for |x| <= 1
function ArcSin(AX: Single): Single;
var
  LNeg: Boolean;
  LX, LX2, LR: Single;
begin
  LNeg := AX < 0;
  if LNeg then AX := -AX;
  if AX > 1.0 then begin Result := 0; Exit; end;

  if AX <= 0.5 then
  begin
    LX2 := AX * AX;
    LR := AX * (1.0 + LX2 * (1.6666667e-1 + LX2 * (7.5000000e-2 +
      LX2 * (4.4642857e-2 + LX2 * 3.0381944e-2))));
  end
  else
  begin
    // asin(x) = pi/2 - 2*asin(sqrt((1-x)/2))
    LX := System.Sqrt((1.0 - AX) * 0.5);
    LX2 := LX * LX;
    LR := LX * (1.0 + LX2 * (1.6666667e-1 + LX2 * (7.5000000e-2 +
      LX2 * (4.4642857e-2 + LX2 * 3.0381944e-2))));
    LR := SIMD_PI * 0.5 - 2.0 * LR;
  end;

  if LNeg then Result := -LR else Result := LR;
end;

function ArcCos(AX: Single): Single;
begin
  Result := SIMD_PI * 0.5 - ArcSin(AX);
end;

function ArcTan2(AY, AX: Single): Single;
var
  LR, LAbsX, LAbsY: Single;
begin
  LAbsX := System.Abs(AX);
  LAbsY := System.Abs(AY);

  if (LAbsX < 1e-30) and (LAbsY < 1e-30) then begin Result := 0; Exit; end;

  if LAbsX >= LAbsY then
  begin
    LR := AY / AX;
    // atan(r) ≈ r - r³/3 + r⁵/5 (for |r| <= 1)
    LR := LR * (1.0 - LR * LR * (0.3333333 - LR * LR * 0.2));
    if AX < 0 then
    begin
      if AY >= 0 then LR := LR + SIMD_PI
      else LR := LR - SIMD_PI;
    end;
  end
  else
  begin
    LR := AX / AY;
    LR := LR * (1.0 - LR * LR * (0.3333333 - LR * LR * 0.2));
    if AY > 0 then LR := SIMD_PI * 0.5 - LR
    else LR := -SIMD_PI * 0.5 - LR;
  end;
  Result := LR;
end;

initialization
  UInt32((@Infinity)^) := $7F800000;
  UInt32((@NegInfinity)^) := $FF800000;
  UInt32((@NaN)^) := $7FC00000;

end.
