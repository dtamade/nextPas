unit nextpas.core.math.trig;

{$I nextpas.core.settings.inc}

interface

const
  PI_VALUE: Double = 3.14159265358979323846;
  TWO_PI: Double = 6.28318530717958647692;
  HALF_PI: Double = 1.57079632679489661923;

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

implementation

uses
  nextpas.core.math.impl.scalar;

function DoubleHasSignBit(const AValue: Double): Boolean; inline;
var
  LBits: UInt64;
begin
  Move(AValue, LBits, SizeOf(LBits));
  Result := (LBits and UInt64($8000000000000000)) <> 0;
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

function Sin(const AX: Single): Single;
begin
  Result := Single(Sin(Double(AX)));
end;

function Sin(const AX: Double): Double;
begin
  if DoubleIsNaN(AX) or DoubleIsInfinite(AX) then
    Exit(DoubleQuietNaN);
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
  Result := Single(Tan(Double(AX)));
end;

function Tan(const AX: Double): Double;
begin
  if DoubleIsNaN(AX) or DoubleIsInfinite(AX) then
    Exit(DoubleQuietNaN);
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
    Result := ArcTan(AY / AX)
  else if AX < 0.0 then
  begin
    if AY > 0.0 then
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
  Result := Single(Exp(Double(AX)));
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

function Power(const ABase, AExponent: Double): Double;
var
  LAbsBase: Double;
  LResult: Double;
begin
  if DoubleIsNaN(AExponent) then
    Exit(DoubleQuietNaN);
  if AExponent = 0.0 then
    Exit(1.0);
  if DoubleIsNaN(ABase) then
    Exit(DoubleQuietNaN);
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
    LResult := System.Exp(AExponent * System.Ln(LAbsBase));
    if IsOddIntegerValue(AExponent) then
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
