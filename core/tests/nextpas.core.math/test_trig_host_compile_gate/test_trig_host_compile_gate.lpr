program test_trig_host_compile_gate;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.math,
  nextpas.core.math.trig;

begin
  if Sin(0.0) + Cos(0.0) + Tan(0.0) + ArcTan2(1.0, 1.0) +
    Exp(0.0) + Ln(1.0) + Power(2.0, 3.0) + Sqrt(4.0) = 0.0 then
    Halt(1);
end.
