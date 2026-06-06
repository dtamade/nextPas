unit nextpas.core.math.easing;

{$I nextpas.core.settings.inc}

interface

type
  TEasingFunction = function(const AT: Double): Double;

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
function EaseInExpo(const AT: Double): Double;
function EaseOutExpo(const AT: Double): Double;
function EaseInOutExpo(const AT: Double): Double;
function EaseInElastic(const AT: Double): Double;
function EaseOutElastic(const AT: Double): Double;
function EaseInOutElastic(const AT: Double): Double;
function EaseInBack(const AT: Double): Double; inline;
function EaseOutBack(const AT: Double): Double; inline;
function EaseInOutBack(const AT: Double): Double;
function EaseInBounce(const AT: Double): Double;
function EaseOutBounce(const AT: Double): Double;
function EaseInOutBounce(const AT: Double): Double;

implementation

uses
  nextpas.core.math.scalar,
  nextpas.core.math.trig;

function EaseLinear(const AT: Double): Double;
begin
  Result := AT;
end;

function EaseInQuad(const AT: Double): Double;
begin
  Result := AT * AT;
end;

function EaseOutQuad(const AT: Double): Double;
begin
  Result := AT * (2.0 - AT);
end;

function EaseInOutQuad(const AT: Double): Double;
begin
  if AT < 0.5 then
    Result := 2.0 * AT * AT
  else
    Result := -1.0 + (4.0 - 2.0 * AT) * AT;
end;

function EaseInCubic(const AT: Double): Double;
begin
  Result := AT * AT * AT;
end;

function EaseOutCubic(const AT: Double): Double;
var
  T: Double;
begin
  T := AT - 1.0;
  Result := T * T * T + 1.0;
end;

function EaseInOutCubic(const AT: Double): Double;
var
  T: Double;
begin
  if AT < 0.5 then
    Result := 4.0 * AT * AT * AT
  else
  begin
    T := 2.0 * AT - 2.0;
    Result := (T * T * T + 2.0) * 0.5;
  end;
end;

function EaseInQuart(const AT: Double): Double;
begin
  Result := AT * AT * AT * AT;
end;

function EaseOutQuart(const AT: Double): Double;
var
  T: Double;
begin
  T := AT - 1.0;
  Result := 1.0 - T * T * T * T;
end;

function EaseInOutQuart(const AT: Double): Double;
var
  T: Double;
begin
  if AT < 0.5 then
    Result := 8.0 * AT * AT * AT * AT
  else
  begin
    T := AT - 1.0;
    Result := 1.0 - 8.0 * T * T * T * T;
  end;
end;

function EaseInExpo(const AT: Double): Double;
begin
  if AT = 0.0 then
    Result := 0.0
  else
    Result := nextpas.core.math.trig.Power(2.0, 10.0 * (AT - 1.0));
end;

function EaseOutExpo(const AT: Double): Double;
begin
  if AT = 1.0 then
    Result := 1.0
  else
    Result := 1.0 - nextpas.core.math.trig.Power(2.0, -10.0 * AT);
end;

function EaseInOutExpo(const AT: Double): Double;
begin
  if AT = 0.0 then
    Result := 0.0
  else if AT = 1.0 then
    Result := 1.0
  else if AT < 0.5 then
    Result := nextpas.core.math.trig.Power(2.0, 20.0 * AT - 10.0) * 0.5
  else
    Result := (2.0 - nextpas.core.math.trig.Power(2.0, -20.0 * AT + 10.0)) * 0.5;
end;

function EaseInElastic(const AT: Double): Double;
var
  C4: Double;
begin
  if AT = 0.0 then
    Result := 0.0
  else if AT = 1.0 then
    Result := 1.0
  else
  begin
    C4 := (2.0 * nextpas.core.math.scalar.PI_VALUE) / 3.0;
    Result := -nextpas.core.math.trig.Power(2.0, 10.0 * AT - 10.0) *
      nextpas.core.math.trig.Sin((AT * 10.0 - 10.75) * C4);
  end;
end;

function EaseOutElastic(const AT: Double): Double;
var
  C4: Double;
begin
  if AT = 0.0 then
    Result := 0.0
  else if AT = 1.0 then
    Result := 1.0
  else
  begin
    C4 := (2.0 * nextpas.core.math.scalar.PI_VALUE) / 3.0;
    Result := nextpas.core.math.trig.Power(2.0, -10.0 * AT) *
      nextpas.core.math.trig.Sin((AT * 10.0 - 0.75) * C4) + 1.0;
  end;
end;

function EaseInOutElastic(const AT: Double): Double;
var
  C5: Double;
begin
  if AT = 0.0 then
    Result := 0.0
  else if AT = 1.0 then
    Result := 1.0
  else
  begin
    C5 := (2.0 * nextpas.core.math.scalar.PI_VALUE) / 4.5;
    if AT < 0.5 then
      Result := -(nextpas.core.math.trig.Power(2.0, 20.0 * AT - 10.0) *
        nextpas.core.math.trig.Sin((20.0 * AT - 11.125) * C5)) * 0.5
    else
      Result := (nextpas.core.math.trig.Power(2.0, -20.0 * AT + 10.0) *
        nextpas.core.math.trig.Sin((20.0 * AT - 11.125) * C5)) * 0.5 + 1.0;
  end;
end;

function EaseInBack(const AT: Double): Double;
const
  C1 = 1.70158;
  C3 = C1 + 1.0;
begin
  Result := C3 * AT * AT * AT - C1 * AT * AT;
end;

function EaseOutBack(const AT: Double): Double;
const
  C1 = 1.70158;
  C3 = C1 + 1.0;
var
  T: Double;
begin
  T := AT - 1.0;
  Result := 1.0 + C3 * T * T * T + C1 * T * T;
end;

function EaseInOutBack(const AT: Double): Double;
const
  C1 = 1.70158;
  C2 = C1 * 1.525;
var
  T: Double;
begin
  if AT < 0.5 then
  begin
    T := 2.0 * AT;
    Result := (T * T * ((C2 + 1.0) * T - C2)) * 0.5;
  end
  else
  begin
    T := 2.0 * AT - 2.0;
    Result := (T * T * ((C2 + 1.0) * T + C2) + 2.0) * 0.5;
  end;
end;

function EaseOutBounce(const AT: Double): Double;
const
  N1 = 7.5625;
  D1 = 2.75;
var
  T: Double;
begin
  T := AT;
  if T = 0.0 then
    Result := 0.0
  else if T = 1.0 then
    Result := 1.0
  else if T < 1.0 / D1 then
    Result := N1 * T * T
  else if T < 2.0 / D1 then
  begin
    T := T - 1.5 / D1;
    Result := N1 * T * T + 0.75;
  end
  else if T < 2.5 / D1 then
  begin
    T := T - 2.25 / D1;
    Result := N1 * T * T + 0.9375;
  end
  else
  begin
    T := T - 2.625 / D1;
    Result := N1 * T * T + 0.984375;
  end;
end;

function EaseInBounce(const AT: Double): Double;
begin
  Result := 1.0 - EaseOutBounce(1.0 - AT);
end;

function EaseInOutBounce(const AT: Double): Double;
begin
  if AT < 0.5 then
    Result := (1.0 - EaseOutBounce(1.0 - 2.0 * AT)) * 0.5
  else
    Result := (1.0 + EaseOutBounce(2.0 * AT - 1.0)) * 0.5;
end;

end.
