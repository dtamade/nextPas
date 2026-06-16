{
  nextpas.core.math.easing.pas
  Easing functions for animation and interpolation
}
unit nextpas.core.math.easing;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.math.base,
  nextpas.core.math.scalar,
  nextpas.core.math.trig;

{ === Linear === }

{** Identity easing: returns AT unchanged (single-precision) }
function Linear(AT: Single): Single;
{** Identity easing: returns AT unchanged (double-precision) }
function Linear(AT: Double): Double;

{ === Quadratic === }

{** Quadratic ease-in (single-precision) }
function QuadIn(AT: Single): Single;
{** Quadratic ease-in (double-precision) }
function QuadIn(AT: Double): Double;
{** Quadratic ease-out (single-precision) }
function QuadOut(AT: Single): Single;
{** Quadratic ease-out (double-precision) }
function QuadOut(AT: Double): Double;
{** Quadratic ease-in-out (single-precision) }
function QuadInOut(AT: Single): Single;
{** Quadratic ease-in-out (double-precision) }
function QuadInOut(AT: Double): Double;

{ === Cubic === }

{** Cubic ease-in (single-precision) }
function CubicIn(AT: Single): Single;
{** Cubic ease-in (double-precision) }
function CubicIn(AT: Double): Double;
{** Cubic ease-out (single-precision) }
function CubicOut(AT: Single): Single;
{** Cubic ease-out (double-precision) }
function CubicOut(AT: Double): Double;
{** Cubic ease-in-out (single-precision) }
function CubicInOut(AT: Single): Single;
{** Cubic ease-in-out (double-precision) }
function CubicInOut(AT: Double): Double;

{ === Quartic === }

{** Quartic ease-in (single-precision) }
function QuartIn(AT: Single): Single;
{** Quartic ease-in (double-precision) }
function QuartIn(AT: Double): Double;
{** Quartic ease-out (single-precision) }
function QuartOut(AT: Single): Single;
{** Quartic ease-out (double-precision) }
function QuartOut(AT: Double): Double;
{** Quartic ease-in-out (single-precision) }
function QuartInOut(AT: Single): Single;
{** Quartic ease-in-out (double-precision) }
function QuartInOut(AT: Double): Double;

{ === Quintic === }

{** Quintic ease-in (single-precision) }
function QuintIn(AT: Single): Single;
{** Quintic ease-in (double-precision) }
function QuintIn(AT: Double): Double;
{** Quintic ease-out (single-precision) }
function QuintOut(AT: Single): Single;
{** Quintic ease-out (double-precision) }
function QuintOut(AT: Double): Double;
{** Quintic ease-in-out (single-precision) }
function QuintInOut(AT: Single): Single;
{** Quintic ease-in-out (double-precision) }
function QuintInOut(AT: Double): Double;

{ === Sine === }

{** Sinusoidal ease-in (single-precision) }
function SineIn(AT: Single): Single;
{** Sinusoidal ease-in (double-precision) }
function SineIn(AT: Double): Double;
{** Sinusoidal ease-out (single-precision) }
function SineOut(AT: Single): Single;
{** Sinusoidal ease-out (double-precision) }
function SineOut(AT: Double): Double;
{** Sinusoidal ease-in-out (single-precision) }
function SineInOut(AT: Single): Single;
{** Sinusoidal ease-in-out (double-precision) }
function SineInOut(AT: Double): Double;

{ === Exponential === }

{** Exponential ease-in (single-precision) }
function ExpoIn(AT: Single): Single;
{** Exponential ease-in (double-precision) }
function ExpoIn(AT: Double): Double;
{** Exponential ease-out (single-precision) }
function ExpoOut(AT: Single): Single;
{** Exponential ease-out (double-precision) }
function ExpoOut(AT: Double): Double;
{** Exponential ease-in-out (single-precision) }
function ExpoInOut(AT: Single): Single;
{** Exponential ease-in-out (double-precision) }
function ExpoInOut(AT: Double): Double;

{ === Circular === }

{** Circular ease-in (single-precision) }
function CircIn(AT: Single): Single;
{** Circular ease-in (double-precision) }
function CircIn(AT: Double): Double;
{** Circular ease-out (single-precision) }
function CircOut(AT: Single): Single;
{** Circular ease-out (double-precision) }
function CircOut(AT: Double): Double;
{** Circular ease-in-out (single-precision) }
function CircInOut(AT: Single): Single;
{** Circular ease-in-out (double-precision) }
function CircInOut(AT: Double): Double;

{ === Elastic === }

{** Elastic ease-in (single-precision) }
function ElasticIn(AT: Single): Single;
{** Elastic ease-in (double-precision) }
function ElasticIn(AT: Double): Double;
{** Elastic ease-out (single-precision) }
function ElasticOut(AT: Single): Single;
{** Elastic ease-out (double-precision) }
function ElasticOut(AT: Double): Double;
{** Elastic ease-in-out (single-precision) }
function ElasticInOut(AT: Single): Single;
{** Elastic ease-in-out (double-precision) }
function ElasticInOut(AT: Double): Double;

{ === Back === }

{** Back ease-in with overshoot (single-precision) }
function BackIn(AT: Single): Single;
{** Back ease-in with overshoot (double-precision) }
function BackIn(AT: Double): Double;
{** Back ease-out with overshoot (single-precision) }
function BackOut(AT: Single): Single;
{** Back ease-out with overshoot (double-precision) }
function BackOut(AT: Double): Double;
{** Back ease-in-out with overshoot (single-precision) }
function BackInOut(AT: Single): Single;
{** Back ease-in-out with overshoot (double-precision) }
function BackInOut(AT: Double): Double;

{ === Bounce === }

{** Bounce ease-in (single-precision) }
function BounceIn(AT: Single): Single;
{** Bounce ease-in (double-precision) }
function BounceIn(AT: Double): Double;
{** Bounce ease-out (single-precision) }
function BounceOut(AT: Single): Single;
{** Bounce ease-out (double-precision) }
function BounceOut(AT: Double): Double;
{** Bounce ease-in-out (single-precision) }
function BounceInOut(AT: Single): Single;
{** Bounce ease-in-out (double-precision) }
function BounceInOut(AT: Double): Double;

implementation

const
  BACK_CONST_SINGLE: Single = 1.70158;
  BACK_CONST_DOUBLE: Double = 1.70158;
  ELASTIC_PERIOD_SINGLE: Single = 0.3;
  ELASTIC_PERIOD_DOUBLE: Double = 0.3;

{ === Linear === }

function Linear(AT: Single): Single;
begin
  Result := AT;
end;

function Linear(AT: Double): Double;
begin
  Result := AT;
end;

{ === Quadratic === }

function QuadIn(AT: Single): Single;
begin
  Result := AT * AT;
end;

function QuadIn(AT: Double): Double;
begin
  Result := AT * AT;
end;

function QuadOut(AT: Single): Single;
begin
  Result := AT * (2.0 - AT);
end;

function QuadOut(AT: Double): Double;
begin
  Result := AT * (2.0 - AT);
end;

function QuadInOut(AT: Single): Single;
begin
  if AT < 0.5 then
    Result := 2.0 * AT * AT
  else
    Result := -1.0 + (4.0 - 2.0 * AT) * AT;
end;

function QuadInOut(AT: Double): Double;
begin
  if AT < 0.5 then
    Result := 2.0 * AT * AT
  else
    Result := -1.0 + (4.0 - 2.0 * AT) * AT;
end;

{ === Cubic === }

function CubicIn(AT: Single): Single;
begin
  Result := AT * AT * AT;
end;

function CubicIn(AT: Double): Double;
begin
  Result := AT * AT * AT;
end;

function CubicOut(AT: Single): Single;
var
  LT: Single;
begin
  LT := AT - 1.0;
  Result := LT * LT * LT + 1.0;
end;

function CubicOut(AT: Double): Double;
var
  LT: Double;
begin
  LT := AT - 1.0;
  Result := LT * LT * LT + 1.0;
end;

function CubicInOut(AT: Single): Single;
begin
  if AT < 0.5 then
    Result := 4.0 * AT * AT * AT
  else
  begin
    Result := (AT - 1.0) * (2.0 * AT - 2.0) * (2.0 * AT - 2.0) + 1.0;
  end;
end;

function CubicInOut(AT: Double): Double;
begin
  if AT < 0.5 then
    Result := 4.0 * AT * AT * AT
  else
  begin
    Result := (AT - 1.0) * (2.0 * AT - 2.0) * (2.0 * AT - 2.0) + 1.0;
  end;
end;

{ === Quartic === }

function QuartIn(AT: Single): Single;
begin
  Result := AT * AT * AT * AT;
end;

function QuartIn(AT: Double): Double;
begin
  Result := AT * AT * AT * AT;
end;

function QuartOut(AT: Single): Single;
var
  LT: Single;
begin
  LT := AT - 1.0;
  Result := 1.0 - LT * LT * LT * LT;
end;

function QuartOut(AT: Double): Double;
var
  LT: Double;
begin
  LT := AT - 1.0;
  Result := 1.0 - LT * LT * LT * LT;
end;

function QuartInOut(AT: Single): Single;
begin
  if AT < 0.5 then
    Result := 8.0 * AT * AT * AT * AT
  else
  begin
    Result := 1.0 - 8.0 * Power(AT - 1.0, 4);
  end;
end;

function QuartInOut(AT: Double): Double;
begin
  if AT < 0.5 then
    Result := 8.0 * AT * AT * AT * AT
  else
  begin
    Result := 1.0 - 8.0 * Power(AT - 1.0, 4);
  end;
end;

{ === Quintic === }

function QuintIn(AT: Single): Single;
begin
  Result := AT * AT * AT * AT * AT;
end;

function QuintIn(AT: Double): Double;
begin
  Result := AT * AT * AT * AT * AT;
end;

function QuintOut(AT: Single): Single;
var
  LT: Single;
begin
  LT := AT - 1.0;
  Result := LT * LT * LT * LT * LT + 1.0;
end;

function QuintOut(AT: Double): Double;
var
  LT: Double;
begin
  LT := AT - 1.0;
  Result := LT * LT * LT * LT * LT + 1.0;
end;

function QuintInOut(AT: Single): Single;
begin
  if AT < 0.5 then
    Result := 16.0 * AT * AT * AT * AT * AT
  else
  begin
    Result := Power(2.0 * AT - 2.0, 5) / 2.0 + 1.0;
  end;
end;

function QuintInOut(AT: Double): Double;
begin
  if AT < 0.5 then
    Result := 16.0 * AT * AT * AT * AT * AT
  else
  begin
    Result := Power(2.0 * AT - 2.0, 5) / 2.0 + 1.0;
  end;
end;

{ === Sine === }

function SineIn(AT: Single): Single;
begin
  Result := 1.0 - Cos(AT * HALF_PI);
end;

function SineIn(AT: Double): Double;
begin
  Result := 1.0 - Cos(AT * HALF_PI);
end;

function SineOut(AT: Single): Single;
begin
  Result := Sin(AT * HALF_PI);
end;

function SineOut(AT: Double): Double;
begin
  Result := Sin(AT * HALF_PI);
end;

function SineInOut(AT: Single): Single;
begin
  Result := -(Cos(PI_VALUE * AT) - 1.0) / 2.0;
end;

function SineInOut(AT: Double): Double;
begin
  Result := -(Cos(PI_VALUE * AT) - 1.0) / 2.0;
end;

{ === Exponential === }

function ExpoIn(AT: Single): Single;
begin
  if AT = 0.0 then
    Result := 0.0
  else
    Result := Power(2.0, 10.0 * (AT - 1.0));
end;

function ExpoIn(AT: Double): Double;
begin
  if AT = 0.0 then
    Result := 0.0
  else
    Result := Power(2.0, 10.0 * (AT - 1.0));
end;

function ExpoOut(AT: Single): Single;
begin
  if AT = 1.0 then
    Result := 1.0
  else
    Result := 1.0 - Power(2.0, -10.0 * AT);
end;

function ExpoOut(AT: Double): Double;
begin
  if AT = 1.0 then
    Result := 1.0
  else
    Result := 1.0 - Power(2.0, -10.0 * AT);
end;

function ExpoInOut(AT: Single): Single;
begin
  if AT = 0.0 then
    Result := 0.0
  else if AT = 1.0 then
    Result := 1.0
  else if AT < 0.5 then
    Result := Power(2.0, 20.0 * AT - 10.0) / 2.0
  else
    Result := (2.0 - Power(2.0, -20.0 * AT + 10.0)) / 2.0;
end;

function ExpoInOut(AT: Double): Double;
begin
  if AT = 0.0 then
    Result := 0.0
  else if AT = 1.0 then
    Result := 1.0
  else if AT < 0.5 then
    Result := Power(2.0, 20.0 * AT - 10.0) / 2.0
  else
    Result := (2.0 - Power(2.0, -20.0 * AT + 10.0)) / 2.0;
end;

{ === Circular === }

function CircIn(AT: Single): Single;
begin
  Result := 1.0 - Sqrt(1.0 - AT * AT);
end;

function CircIn(AT: Double): Double;
begin
  Result := 1.0 - Sqrt(1.0 - AT * AT);
end;

function CircOut(AT: Single): Single;
begin
  Result := Sqrt(1.0 - Power(AT - 1.0, 2));
end;

function CircOut(AT: Double): Double;
begin
  Result := Sqrt(1.0 - Power(AT - 1.0, 2));
end;

function CircInOut(AT: Single): Single;
begin
  if AT < 0.5 then
    Result := (1.0 - Sqrt(1.0 - 4.0 * AT * AT)) / 2.0
  else
    Result := (Sqrt(1.0 - Power(-2.0 * AT + 2.0, 2)) + 1.0) / 2.0;
end;

function CircInOut(AT: Double): Double;
begin
  if AT < 0.5 then
    Result := (1.0 - Sqrt(1.0 - 4.0 * AT * AT)) / 2.0
  else
    Result := (Sqrt(1.0 - Power(-2.0 * AT + 2.0, 2)) + 1.0) / 2.0;
end;

{ === Elastic === }

function ElasticIn(AT: Single): Single;
begin
  if AT = 0.0 then
    Result := 0.0
  else if AT = 1.0 then
    Result := 1.0
  else
    Result := -Power(2.0, 10.0 * AT - 10.0) * Sin((AT * 10.0 - 10.75) * (TWO_PI / ELASTIC_PERIOD_SINGLE));
end;

function ElasticIn(AT: Double): Double;
begin
  if AT = 0.0 then
    Result := 0.0
  else if AT = 1.0 then
    Result := 1.0
  else
    Result := -Power(2.0, 10.0 * AT - 10.0) * Sin((AT * 10.0 - 10.75) * (TWO_PI / ELASTIC_PERIOD_DOUBLE));
end;

function ElasticOut(AT: Single): Single;
begin
  if AT = 0.0 then
    Result := 0.0
  else if AT = 1.0 then
    Result := 1.0
  else
    Result := Power(2.0, -10.0 * AT) * Sin((AT * 10.0 - 0.75) * (TWO_PI / ELASTIC_PERIOD_SINGLE)) + 1.0;
end;

function ElasticOut(AT: Double): Double;
begin
  if AT = 0.0 then
    Result := 0.0
  else if AT = 1.0 then
    Result := 1.0
  else
    Result := Power(2.0, -10.0 * AT) * Sin((AT * 10.0 - 0.75) * (TWO_PI / ELASTIC_PERIOD_DOUBLE)) + 1.0;
end;

function ElasticInOut(AT: Single): Single;
begin
  if AT = 0.0 then
    Result := 0.0
  else if AT = 1.0 then
    Result := 1.0
  else if AT < 0.5 then
    Result := -Power(2.0, 20.0 * AT - 10.0) * Sin((20.0 * AT - 11.125) * (TWO_PI / ELASTIC_PERIOD_SINGLE)) / 2.0
  else
    Result := Power(2.0, -20.0 * AT + 10.0) * Sin((20.0 * AT - 11.125) * (TWO_PI / ELASTIC_PERIOD_SINGLE)) / 2.0 + 1.0;
end;

function ElasticInOut(AT: Double): Double;
begin
  if AT = 0.0 then
    Result := 0.0
  else if AT = 1.0 then
    Result := 1.0
  else if AT < 0.5 then
    Result := -Power(2.0, 20.0 * AT - 10.0) * Sin((20.0 * AT - 11.125) * (TWO_PI / ELASTIC_PERIOD_DOUBLE)) / 2.0
  else
    Result := Power(2.0, -20.0 * AT + 10.0) * Sin((20.0 * AT - 11.125) * (TWO_PI / ELASTIC_PERIOD_DOUBLE)) / 2.0 + 1.0;
end;

{ === Back === }

function BackIn(AT: Single): Single;
begin
  Result := (BACK_CONST_SINGLE + 1.0) * AT * AT * AT - BACK_CONST_SINGLE * AT * AT;
end;

function BackIn(AT: Double): Double;
begin
  Result := (BACK_CONST_DOUBLE + 1.0) * AT * AT * AT - BACK_CONST_DOUBLE * AT * AT;
end;

function BackOut(AT: Single): Single;
var
  LT: Single;
begin
  LT := AT - 1.0;
  Result := 1.0 + (BACK_CONST_SINGLE + 1.0) * LT * LT * LT + BACK_CONST_SINGLE * LT * LT;
end;

function BackOut(AT: Double): Double;
var
  LT: Double;
begin
  LT := AT - 1.0;
  Result := 1.0 + (BACK_CONST_DOUBLE + 1.0) * LT * LT * LT + BACK_CONST_DOUBLE * LT * LT;
end;

function BackInOut(AT: Single): Single;
var
  LC: Single;
begin
  LC := BACK_CONST_SINGLE * 1.525;
  if AT < 0.5 then
    Result := (Power(2.0 * AT, 2) * ((LC + 1.0) * 2.0 * AT - LC)) / 2.0
  else
    Result := (Power(2.0 * AT - 2.0, 2) * ((LC + 1.0) * (AT * 2.0 - 2.0) + LC) + 2.0) / 2.0;
end;

function BackInOut(AT: Double): Double;
var
  LC: Double;
begin
  LC := BACK_CONST_DOUBLE * 1.525;
  if AT < 0.5 then
    Result := (Power(2.0 * AT, 2) * ((LC + 1.0) * 2.0 * AT - LC)) / 2.0
  else
    Result := (Power(2.0 * AT - 2.0, 2) * ((LC + 1.0) * (AT * 2.0 - 2.0) + LC) + 2.0) / 2.0;
end;

{ === Bounce === }

function BounceOut(AT: Single): Single;
begin
  if AT < 1.0 / 2.75 then
    Result := 7.5625 * AT * AT
  else if AT < 2.0 / 2.75 then
  begin
    AT := AT - 1.5 / 2.75;
    Result := 7.5625 * AT * AT + 0.75;
  end
  else if AT < 2.5 / 2.75 then
  begin
    AT := AT - 2.25 / 2.75;
    Result := 7.5625 * AT * AT + 0.9375;
  end
  else
  begin
    AT := AT - 2.625 / 2.75;
    Result := 7.5625 * AT * AT + 0.984375;
  end;
end;

function BounceOut(AT: Double): Double;
begin
  if AT < 1.0 / 2.75 then
    Result := 7.5625 * AT * AT
  else if AT < 2.0 / 2.75 then
  begin
    AT := AT - 1.5 / 2.75;
    Result := 7.5625 * AT * AT + 0.75;
  end
  else if AT < 2.5 / 2.75 then
  begin
    AT := AT - 2.25 / 2.75;
    Result := 7.5625 * AT * AT + 0.9375;
  end
  else
  begin
    AT := AT - 2.625 / 2.75;
    Result := 7.5625 * AT * AT + 0.984375;
  end;
end;

function BounceIn(AT: Single): Single;
begin
  Result := 1.0 - BounceOut(1.0 - AT);
end;

function BounceIn(AT: Double): Double;
begin
  Result := 1.0 - BounceOut(1.0 - AT);
end;

function BounceInOut(AT: Single): Single;
begin
  if AT < 0.5 then
    Result := (1.0 - BounceOut(1.0 - 2.0 * AT)) / 2.0
  else
    Result := (1.0 + BounceOut(2.0 * AT - 1.0)) / 2.0;
end;

function BounceInOut(AT: Double): Double;
begin
  if AT < 0.5 then
    Result := (1.0 - BounceOut(1.0 - 2.0 * AT)) / 2.0
  else
    Result := (1.0 + BounceOut(2.0 * AT - 1.0)) / 2.0;
end;

end.
