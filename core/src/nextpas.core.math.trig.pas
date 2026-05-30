unit nextpas.core.math.trig;

{$I nextpas.core.settings.inc}

interface

const
  PI_VALUE: Double = 3.14159265358979323846;
  TWO_PI: Double = 6.28318530717958647692;
  HALF_PI: Double = 1.57079632679489661923;
  DEG_TO_RAD: Double = 0.01745329251994329577;
  RAD_TO_DEG: Double = 57.2957795130823208768;

{** 三角函数 *}
function Sin(const AX: Double): Double; inline;
function Cos(const AX: Double): Double; inline;
function Tan(const AX: Double): Double; inline;
function ArcSin(const AX: Double): Double; inline;
function ArcCos(const AX: Double): Double; inline;
function ArcTan(const AX: Double): Double; inline;
function ArcTan2(const AY, AX: Double): Double; inline;

{** 指数/对数 *}
function Exp(const AX: Double): Double; inline;
function Ln(const AX: Double): Double; inline;
function Log2(const AX: Double): Double; inline;
function Log10(const AX: Double): Double; inline;
function Power(const ABase, AExponent: Double): Double; inline;
function Sqrt(const AX: Double): Double; inline;

{** 取整 *}
function Floor(const AX: Double): Int64; inline;
function Ceil(const AX: Double): Int64; inline;
function Round(const AX: Double): Int64; inline;
function Trunc(const AX: Double): Int64; inline;
function Frac(const AX: Double): Double; inline;

{** 绝对值 *}
function Abs(const AX: Double): Double; overload; inline;
function Abs(const AX: Int32): Int32; overload; inline;
function Abs(const AX: Int64): Int64; overload; inline;

{** 角度转换 *}
function DegToRad(const ADeg: Double): Double; inline;
function RadToDeg(const ARad: Double): Double; inline;

{** 钳位 *}
function Clamp(const AValue, AMin, AMax: Double): Double; inline;
function Clamp(const AValue, AMin, AMax: Int32): Int32; inline;

{** 符号函数 *}
function Sign(const AX: Double): Double; overload; inline;
function Sign(const AX: Int32): Int32; overload; inline;
function Sign(const AX: Int64): Int64; overload; inline;

{** 插值 *}
function Lerp(const AA, AB, AT: Double): Double; inline;

implementation

uses
  nextpas.core.math.ffi;

function Sin(const AX: Double): Double;
begin
  Result := platform_sin(AX);
end;

function Cos(const AX: Double): Double;
begin
  Result := platform_cos(AX);
end;

function Tan(const AX: Double): Double;
begin
  Result := platform_tan(AX);
end;

function ArcSin(const AX: Double): Double;
begin
  Result := platform_asin(AX);
end;

function ArcCos(const AX: Double): Double;
begin
  Result := platform_acos(AX);
end;

function ArcTan(const AX: Double): Double;
begin
  Result := platform_atan(AX);
end;

function ArcTan2(const AY, AX: Double): Double;
begin
  Result := platform_atan2(AY, AX);
end;

function Exp(const AX: Double): Double;
begin
  Result := platform_exp(AX);
end;

function Ln(const AX: Double): Double;
begin
  Result := platform_log(AX);
end;

function Log2(const AX: Double): Double;
begin
  Result := platform_log2(AX);
end;

function Log10(const AX: Double): Double;
begin
  Result := platform_log10(AX);
end;

function Power(const ABase, AExponent: Double): Double;
begin
  Result := platform_pow(ABase, AExponent);
end;

function Sqrt(const AX: Double): Double;
begin
  Result := platform_sqrt(AX);
end;

function Floor(const AX: Double): Int64;
begin
  Result := System.Trunc(platform_floor(AX));
end;

function Ceil(const AX: Double): Int64;
begin
  Result := System.Trunc(platform_ceil(AX));
end;

function Round(const AX: Double): Int64;
begin
  Result := System.Round(AX);
end;

function Trunc(const AX: Double): Int64;
begin
  Result := System.Trunc(AX);
end;

function Frac(const AX: Double): Double;
begin
  Result := AX - System.Trunc(AX);
end;

function Abs(const AX: Double): Double;
begin
  if AX < 0 then Result := -AX else Result := AX;
end;

function Abs(const AX: Int32): Int32;
begin
  if AX < 0 then Result := -AX else Result := AX;
end;

function Abs(const AX: Int64): Int64;
begin
  if AX < 0 then Result := -AX else Result := AX;
end;

function DegToRad(const ADeg: Double): Double;
begin
  Result := ADeg * DEG_TO_RAD;
end;

function RadToDeg(const ARad: Double): Double;
begin
  Result := ARad * RAD_TO_DEG;
end;

function Clamp(const AValue, AMin, AMax: Double): Double;
begin
  if AValue < AMin then Result := AMin
  else if AValue > AMax then Result := AMax
  else Result := AValue;
end;

function Clamp(const AValue, AMin, AMax: Int32): Int32;
begin
  if AValue < AMin then Result := AMin
  else if AValue > AMax then Result := AMax
  else Result := AValue;
end;

function Lerp(const AA, AB, AT: Double): Double;
begin
  Result := AA + (AB - AA) * AT;
end;


function Sign(const AX: Double): Double;
begin
  if AX > 0 then Result := 1.0
  else if AX < 0 then Result := -1.0
  else Result := 0.0;
end;

function Sign(const AX: Int32): Int32;
begin
  if AX > 0 then Result := 1
  else if AX < 0 then Result := -1
  else Result := 0;
end;

function Sign(const AX: Int64): Int64;
begin
  if AX > 0 then Result := 1
  else if AX < 0 then Result := -1
  else Result := 0;
end;
end.
