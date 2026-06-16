program test_trig;
{$I nextpas.core.settings.inc}
uses
  SysUtils,
  nextpas.core.math.base,
  nextpas.core.math.scalar,
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
var
  LDelta: Double;
begin
  LDelta := AExpected - AActual;
  if LDelta < 0 then
    LDelta := -LDelta;
  Check(AName, LDelta < AEps);
end;

function MakeNaN: Double;
var
  LBits: UInt64;
begin
  LBits := UInt64($7FF8000000000000);
  Move(LBits, Result, SizeOf(Result));
end;

function MakePositiveInfinity: Double;
var
  LBits: UInt64;
begin
  LBits := UInt64($7FF0000000000000);
  Move(LBits, Result, SizeOf(Result));
end;

function MakeNegativeInfinity: Double;
var
  LBits: UInt64;
begin
  LBits := UInt64($FFF0000000000000);
  Move(LBits, Result, SizeOf(Result));
end;

function IsNaNValue(const AValue: Double): Boolean;
var
  LBits: UInt64;
begin
  Move(AValue, LBits, SizeOf(LBits));
  Result := ((LBits and UInt64($7FF0000000000000)) = UInt64($7FF0000000000000)) and
    ((LBits and UInt64($000FFFFFFFFFFFFF)) <> 0);
end;

begin
  WriteLn('=== nextpas.core.math.trig tests ===');
  WriteLn;

  WriteLn('--- Trig ---');
  CheckFloat('Sin(0)=0', 0, Sin(0), 0.0001);
  CheckFloat('Sin(PI/2)=1', 1, Sin(HALF_PI), 0.0001);
  CheckFloat('Sin(Single PI/2)=1', 1, Sin(Single(HALF_PI)), 0.0001);
  CheckFloat('Cos(0)=1', 1, Cos(0), 0.0001);
  CheckFloat('Cos(PI)=-1', -1, Cos(PI_VALUE), 0.0001);
  CheckFloat('Cos(Single 0)=1', 1, Cos(Single(0)), 0.0001);
  CheckFloat('Tan(PI/4)=1', 1, Tan(PI_VALUE / 4), 0.0001);
  CheckFloat('Tan(Single PI/4)=1', 1, Tan(Single(PI_VALUE / 4)), 0.0001);
  CheckFloat('ArcSin(1)=PI/2', HALF_PI, ArcSin(1), 0.0001);
  CheckFloat('ArcSin(Single 1)=PI/2', HALF_PI, ArcSin(Single(1)), 0.0001);
  CheckFloat('ArcCos(0)=PI/2', HALF_PI, ArcCos(0), 0.0001);
  CheckFloat('ArcTan(1)=PI/4', PI_VALUE/4, ArcTan(1), 0.0001);
  CheckFloat('ArcTan2(1,1)=PI/4', PI_VALUE/4, ArcTan2(1, 1), 0.0001);
  CheckFloat('ArcTan2(Single 1,1)=PI/4', PI_VALUE/4, ArcTan2(Single(1), Single(1)), 0.0001);
  Check('ArcSin(out of domain)=NaN', IsNaNValue(ArcSin(1.0001)));
  Check('ArcCos(out of domain)=NaN', IsNaNValue(ArcCos(-1.0001)));
  Check('ArcTan2(NaN,1)=NaN', IsNaNValue(ArcTan2(MakeNaN, 1.0)));
  Check('ArcTan2(1,NaN)=NaN', IsNaNValue(ArcTan2(1.0, MakeNaN)));
  CheckFloat('ArcTan2(+Inf,+Inf)=PI/4', PI_VALUE / 4.0,
    ArcTan2(MakePositiveInfinity, MakePositiveInfinity), 0.0001);
  CheckFloat('ArcTan2(+Inf,-Inf)=3PI/4', 3.0 * PI_VALUE / 4.0,
    ArcTan2(MakePositiveInfinity, MakeNegativeInfinity), 0.0001);
  CheckFloat('ArcTan2(-Inf,+Inf)=-PI/4', -PI_VALUE / 4.0,
    ArcTan2(MakeNegativeInfinity, MakePositiveInfinity), 0.0001);
  CheckFloat('ArcTan2(-Inf,-Inf)=-3PI/4', -3.0 * PI_VALUE / 4.0,
    ArcTan2(MakeNegativeInfinity, MakeNegativeInfinity), 0.0001);

  WriteLn('--- Exp/Log ---');
  CheckFloat('Exp(0)=1', 1, Exp(0), 0.0001);
  CheckFloat('Exp(1)=e', 2.71828, Exp(1), 0.001);
  CheckFloat('Exp(Single 1)=e', 2.71828, Exp(Single(1)), 0.001);
  CheckFloat('Ln(1)=0', 0, Ln(1), 0.0001);
  CheckFloat('Ln(Single 1)=0', 0, Ln(Single(1)), 0.0001);
  CheckFloat('Ln(e)=1', 1, Ln(2.71828), 0.001);
  CheckFloat('Sqrt(4)=2', 2, Sqrt(4), 0.0001);
  CheckFloat('Sqrt(Single 4)=2', 2, Sqrt(Single(4)), 0.0001);
  CheckFloat('Sqrt(2)=1.414', 1.41421, Sqrt(2), 0.001);
  Check('Sqrt(-1)=NaN', IsNaNValue(Sqrt(-1.0)));
  CheckFloat('Power(2,10)=1024', 1024, Power(2, 10), 0.001);
  CheckFloat('Power(Single 2,10)=1024', 1024, Power(Single(2), Single(10)), 0.001);

  WriteLn('--- DegToRad/RadToDeg ---');
  CheckFloat('DegToRad(180)=PI', PI_VALUE, DegToRad(180), 0.0001);
  CheckFloat('DegToRad(Single 180)=PI', PI_VALUE, DegToRad(Single(180)), 0.0001);
  CheckFloat('RadToDeg(PI)=180', 180, RadToDeg(PI_VALUE), 0.0001);
  CheckFloat('RadToDeg(Single PI)=180', 180, RadToDeg(Single(PI_VALUE)), 0.0001);

  WriteLn;
  WriteLn('=== Results: ', GPass, ' passed, ', GFail, ' failed ===');
  if GFail > 0 then Halt(1);
end.
