program test_trig;
{$I nextpas.core.settings.inc}
uses
  SysUtils,
  nextpas.core.math.ffi,
  nextpas.core.math.trig;
var
  GPass: Integer = 0;
  GFail: Integer = 0;

procedure Check(const AName: string; ACond: Boolean);
begin
  if ACond then begin Inc(GPass); WriteLn('  PASS: ', AName); end
  else begin Inc(GFail); WriteLn('  FAIL: ', AName); end;
end;

procedure CheckFloat(const AName: string; AExpected, AActual, AEps: Double);
begin
  Check(AName, nextpas.core.math.trig.Abs(AExpected - AActual) < AEps);
end;

begin
  WriteLn('=== nextpas.core.math.trig tests ===');
  WriteLn;

  WriteLn('--- Trig ---');
  CheckFloat('Sin(0)=0', 0, Sin(0), 0.0001);
  CheckFloat('Sin(PI/2)=1', 1, Sin(HALF_PI), 0.0001);
  CheckFloat('Cos(0)=1', 1, Cos(0), 0.0001);
  CheckFloat('Cos(PI)=-1', -1, Cos(PI_VALUE), 0.0001);
  CheckFloat('ArcTan2(1,1)=PI/4', PI_VALUE/4, ArcTan2(1, 1), 0.0001);

  WriteLn('--- Exp/Log ---');
  CheckFloat('Exp(0)=1', 1, Exp(0), 0.0001);
  CheckFloat('Exp(1)=e', 2.71828, Exp(1), 0.001);
  CheckFloat('Ln(1)=0', 0, Ln(1), 0.0001);
  CheckFloat('Ln(e)=1', 1, Ln(2.71828), 0.001);
  CheckFloat('Sqrt(4)=2', 2, Sqrt(4), 0.0001);
  CheckFloat('Sqrt(2)=1.414', 1.41421, Sqrt(2), 0.001);
  CheckFloat('Power(2,10)=1024', 1024, Power(2, 10), 0.001);

  WriteLn('--- Floor/Ceil/Round ---');
  Check('Floor(3.7)=3', Floor(3.7) = 3);
  Check('Floor(-1.2)=-2', Floor(-1.2) = -2);
  Check('Ceil(3.2)=4', Ceil(3.2) = 4);
  Check('Ceil(-1.8)=-1', Ceil(-1.8) = -1);
  Check('Round(3.5)=4', Round(3.5) = 4);
  Check('Round(2.4)=2', Round(2.4) = 2);
  Check('Trunc(3.9)=3', Trunc(3.9) = 3);

  WriteLn('--- Abs ---');
  Check('Abs(-5.0)=5.0', nextpas.core.math.trig.Abs(-5.0) = 5.0);
  Check('Abs(3.0)=3.0', nextpas.core.math.trig.Abs(3.0) = 3.0);
  Check('Abs(-7)=7', nextpas.core.math.trig.Abs(Int32(-7)) = 7);

  WriteLn('--- Clamp/Lerp ---');
  CheckFloat('Clamp(5,0,10)=5', 5, Clamp(5.0, 0.0, 10.0), 0.001);
  CheckFloat('Clamp(-1,0,10)=0', 0, Clamp(-1.0, 0.0, 10.0), 0.001);
  CheckFloat('Clamp(15,0,10)=10', 10, Clamp(15.0, 0.0, 10.0), 0.001);
  CheckFloat('Lerp(0,10,0.5)=5', 5, Lerp(0, 10, 0.5), 0.001);
  CheckFloat('Lerp(0,10,0)=0', 0, Lerp(0, 10, 0), 0.001);
  CheckFloat('Lerp(0,10,1)=10', 10, Lerp(0, 10, 1), 0.001);

  WriteLn('--- DegToRad/RadToDeg ---');
  CheckFloat('DegToRad(180)=PI', PI_VALUE, DegToRad(180), 0.0001);
  CheckFloat('RadToDeg(PI)=180', 180, RadToDeg(PI_VALUE), 0.0001);

  WriteLn;
  WriteLn('=== Results: ', GPass, ' passed, ', GFail, ' failed ===');
  if GFail > 0 then Halt(1);
end.
