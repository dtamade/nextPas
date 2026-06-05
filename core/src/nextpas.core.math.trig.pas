unit nextpas.core.math.trig;

{$I nextpas.core.settings.inc}

interface

const
  PI_VALUE: Double = 3.14159265358979323846;
  TWO_PI: Double = 6.28318530717958647692;
  HALF_PI: Double = 1.57079632679489661923;
  DEG_TO_RAD: Double = 0.01745329251994329577;
  RAD_TO_DEG: Double = 57.2957795130823208768;

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

function DegToRad(const ADeg: Double): Double; overload; inline;
function DegToRad(const ADeg: Single): Single; overload; inline;
function RadToDeg(const ARad: Double): Double; overload; inline;
function RadToDeg(const ARad: Single): Single; overload; inline;

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
