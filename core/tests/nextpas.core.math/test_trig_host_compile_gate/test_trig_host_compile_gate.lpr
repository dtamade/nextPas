program test_trig_host_compile_gate;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.math,
  nextpas.core.math.trig;

type
  TUnarySingle = function(const AX: Single): Single;
  TUnaryDouble = function(const AX: Double): Double;
  TBinarySingle = function(const AX, AY: Single): Single;
  TBinaryDouble = function(const AX, AY: Double): Double;

procedure RequireUnarySingle(const AValue: TUnarySingle);
begin
  if not Assigned(AValue) then
    Halt(1);
end;

procedure RequireUnaryDouble(const AValue: TUnaryDouble);
begin
  if not Assigned(AValue) then
    Halt(1);
end;

procedure RequireBinarySingle(const AValue: TBinarySingle);
begin
  if not Assigned(AValue) then
    Halt(1);
end;

procedure RequireBinaryDouble(const AValue: TBinaryDouble);
begin
  if not Assigned(AValue) then
    Halt(1);
end;

begin
  RequireUnaryDouble(@nextpas.core.math.Sin);
  RequireUnarySingle(@nextpas.core.math.Sin);
  RequireUnaryDouble(@nextpas.core.math.Cos);
  RequireUnarySingle(@nextpas.core.math.Cos);
  RequireUnaryDouble(@nextpas.core.math.Tan);
  RequireUnarySingle(@nextpas.core.math.Tan);
  RequireUnaryDouble(@nextpas.core.math.ArcSin);
  RequireUnarySingle(@nextpas.core.math.ArcSin);
  RequireUnaryDouble(@nextpas.core.math.ArcCos);
  RequireUnarySingle(@nextpas.core.math.ArcCos);
  RequireUnaryDouble(@nextpas.core.math.ArcTan);
  RequireUnarySingle(@nextpas.core.math.ArcTan);
  RequireUnaryDouble(@nextpas.core.math.Exp);
  RequireUnarySingle(@nextpas.core.math.Exp);
  RequireUnaryDouble(@nextpas.core.math.Ln);
  RequireUnarySingle(@nextpas.core.math.Ln);
  RequireUnaryDouble(@nextpas.core.math.Log2);
  RequireUnarySingle(@nextpas.core.math.Log2);
  RequireUnaryDouble(@nextpas.core.math.Log10);
  RequireUnarySingle(@nextpas.core.math.Log10);
  RequireUnaryDouble(@nextpas.core.math.Sqrt);
  RequireUnarySingle(@nextpas.core.math.Sqrt);
  RequireBinaryDouble(@nextpas.core.math.ArcTan2);
  RequireBinarySingle(@nextpas.core.math.ArcTan2);
  RequireBinaryDouble(@nextpas.core.math.Power);
  RequireBinarySingle(@nextpas.core.math.Power);

  RequireUnaryDouble(@nextpas.core.math.trig.Sin);
  RequireUnarySingle(@nextpas.core.math.trig.Sin);
  RequireUnaryDouble(@nextpas.core.math.trig.Cos);
  RequireUnarySingle(@nextpas.core.math.trig.Cos);
  RequireUnaryDouble(@nextpas.core.math.trig.Tan);
  RequireUnarySingle(@nextpas.core.math.trig.Tan);
  RequireUnaryDouble(@nextpas.core.math.trig.ArcSin);
  RequireUnarySingle(@nextpas.core.math.trig.ArcSin);
  RequireUnaryDouble(@nextpas.core.math.trig.ArcCos);
  RequireUnarySingle(@nextpas.core.math.trig.ArcCos);
  RequireUnaryDouble(@nextpas.core.math.trig.ArcTan);
  RequireUnarySingle(@nextpas.core.math.trig.ArcTan);
  RequireUnaryDouble(@nextpas.core.math.trig.Exp);
  RequireUnarySingle(@nextpas.core.math.trig.Exp);
  RequireUnaryDouble(@nextpas.core.math.trig.Ln);
  RequireUnarySingle(@nextpas.core.math.trig.Ln);
  RequireUnaryDouble(@nextpas.core.math.trig.Log2);
  RequireUnarySingle(@nextpas.core.math.trig.Log2);
  RequireUnaryDouble(@nextpas.core.math.trig.Log10);
  RequireUnarySingle(@nextpas.core.math.trig.Log10);
  RequireUnaryDouble(@nextpas.core.math.trig.Sqrt);
  RequireUnarySingle(@nextpas.core.math.trig.Sqrt);
  RequireBinaryDouble(@nextpas.core.math.trig.ArcTan2);
  RequireBinarySingle(@nextpas.core.math.trig.ArcTan2);
  RequireBinaryDouble(@nextpas.core.math.trig.Power);
  RequireBinarySingle(@nextpas.core.math.trig.Power);
end.
