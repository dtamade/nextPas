program test_trig;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.testing,
  nextpas.core.math.trig;

var
  T: TTestRunner;

type
  TSingleBitCast = packed record
    case Integer of
      0: (Value: Single);
      1: (Bits: LongWord);
  end;

  TDoubleBitCast = packed record
    case Integer of
      0: (Value: Double);
      1: (Bits: QWord);
  end;

procedure CheckNear(const AExpected, AActual, AEpsilon: Double; const AMessage: string);
var
  LDelta: Double;
begin
  LDelta := AExpected - AActual;
  if LDelta < 0.0 then
    LDelta := -LDelta;
  Check(LDelta <= AEpsilon, AMessage);
end;

function SingleNaN: Single;
var
  LValue: TSingleBitCast;
begin
  LValue.Bits := $7FC00000;
  Result := LValue.Value;
end;

function SingleInfinity: Single;
var
  LValue: TSingleBitCast;
begin
  LValue.Bits := $7F800000;
  Result := LValue.Value;
end;

function DoubleNaN: Double;
var
  LValue: TDoubleBitCast;
begin
  LValue.Bits := $7FF8000000000000;
  Result := LValue.Value;
end;

function DoubleInfinity: Double;
var
  LValue: TDoubleBitCast;
begin
  LValue.Bits := $7FF0000000000000;
  Result := LValue.Value;
end;

function SingleNegativeZero: Single;
var
  LValue: TSingleBitCast;
begin
  LValue.Bits := LongWord($80000000);
  Result := LValue.Value;
end;

function DoubleNegativeZero: Double;
var
  LValue: TDoubleBitCast;
begin
  LValue.Bits := QWord($80000000) shl 32;
  Result := LValue.Value;
end;

function IsSingleNaN(const AValue: Single): Boolean;
var
  LValue: TSingleBitCast;
begin
  LValue.Value := AValue;
  Result := ((LValue.Bits and $7F800000) = $7F800000) and
    ((LValue.Bits and $007FFFFF) <> 0);
end;

function IsDoubleNaN(const AValue: Double): Boolean;
var
  LValue: TDoubleBitCast;
begin
  LValue.Value := AValue;
  Result := ((LValue.Bits and $7FF0000000000000) = $7FF0000000000000) and
    ((LValue.Bits and $000FFFFFFFFFFFFF) <> 0);
end;

function IsSinglePositiveInfinity(const AValue: Single): Boolean;
var
  LValue: TSingleBitCast;
begin
  LValue.Value := AValue;
  Result := LValue.Bits = $7F800000;
end;

function IsDoublePositiveInfinity(const AValue: Double): Boolean;
var
  LValue: TDoubleBitCast;
begin
  LValue.Value := AValue;
  Result := LValue.Bits = $7FF0000000000000;
end;

function IsSingleNegativeInfinity(const AValue: Single): Boolean;
var
  LValue: TSingleBitCast;
begin
  LValue.Value := AValue;
  Result := LValue.Bits = LongWord($FF800000);
end;

function IsDoubleNegativeInfinity(const AValue: Double): Boolean;
var
  LValue: TDoubleBitCast;
begin
  LValue.Value := AValue;
  Result := LValue.Bits = QWord($FFF0000000000000);
end;

function IsSinglePositiveZero(const AValue: Single): Boolean;
var
  LValue: TSingleBitCast;
begin
  LValue.Value := AValue;
  Result := LValue.Bits = 0;
end;

function IsDoublePositiveZero(const AValue: Double): Boolean;
var
  LValue: TDoubleBitCast;
begin
  LValue.Value := AValue;
  Result := LValue.Bits = 0;
end;

function IsSingleNegativeZero(const AValue: Single): Boolean;
var
  LValue: TSingleBitCast;
begin
  LValue.Value := AValue;
  Result := LValue.Bits = LongWord($80000000);
end;

function IsDoubleNegativeZero(const AValue: Double): Boolean;
var
  LValue: TDoubleBitCast;
begin
  LValue.Value := AValue;
  Result := LValue.Bits = (QWord($80000000) shl 32);
end;

procedure TestBasicTrigValues;
begin
  CheckNear(0.0, Sin(0.0), 0.0001, 'Sin(0)=0');
  CheckNear(1.0, Sin(HALF_PI), 0.0001, 'Sin(PI/2)=1');
  CheckNear(1.0, Sin(Single(HALF_PI)), 0.0001, 'Sin(Single PI/2)=1');
  CheckNear(1.0, Cos(0.0), 0.0001, 'Cos(0)=1');
  CheckNear(-1.0, Cos(PI_VALUE), 0.0001, 'Cos(PI)=-1');
  CheckNear(1.0, Cos(Single(0.0)), 0.0001, 'Cos(Single 0)=1');
  CheckNear(1.0, Tan(PI_VALUE / 4.0), 0.0001, 'Tan(PI/4)=1');
  CheckNear(1.0, Tan(Single(PI_VALUE / 4.0)), 0.0001, 'Tan(Single PI/4)=1');
  CheckNear(HALF_PI, ArcSin(1.0), 0.0001, 'ArcSin(1)=PI/2');
  CheckNear(-HALF_PI, ArcSin(-1.0), 0.0001, 'ArcSin(-1)=-PI/2');
  CheckNear(HALF_PI, ArcSin(Single(1.0)), 0.0001, 'ArcSin(Single 1)=PI/2');
  CheckNear(HALF_PI, ArcCos(0.0), 0.0001, 'ArcCos(0)=PI/2');
  CheckNear(PI_VALUE, ArcCos(-1.0), 0.0001, 'ArcCos(-1)=PI');
  CheckNear(HALF_PI, ArcCos(Single(0.0)), 0.0001, 'ArcCos(Single 0)=PI/2');
  CheckNear(PI_VALUE / 4.0, ArcTan(1.0), 0.0001, 'ArcTan(1)=PI/4');
  CheckNear(PI_VALUE / 4.0, ArcTan(Single(1.0)), 0.0001, 'ArcTan(Single 1)=PI/4');
  CheckNear(PI_VALUE / 4.0, ArcTan2(1.0, 1.0), 0.0001, 'ArcTan2(1,1)=PI/4');
  CheckNear(PI_VALUE / 4.0, ArcTan2(Single(1.0), Single(1.0)), 0.0001,
    'ArcTan2(Single 1,1)=PI/4');
end;

procedure TestInverseTrigDomainContracts;
begin
  Check(IsDoubleNaN(ArcSin(1.0001)), 'ArcSin(out of domain)=NaN');
  Check(IsSingleNaN(ArcSin(Single(1.0001))), 'ArcSin(Single out of domain)=NaN');
  Check(IsDoubleNaN(ArcCos(-1.0001)), 'ArcCos(out of domain)=NaN');
  Check(IsSingleNaN(ArcCos(Single(-1.0001))), 'ArcCos(Single out of domain)=NaN');
end;

procedure TestArcTan2SpecialCases;
begin
  Check(IsDoubleNaN(ArcTan2(DoubleNaN, 1.0)), 'ArcTan2(NaN,1)=NaN');
  Check(IsDoubleNaN(ArcTan2(1.0, DoubleNaN)), 'ArcTan2(1,NaN)=NaN');
  Check(IsSingleNaN(ArcTan2(SingleNaN, Single(1.0))), 'ArcTan2(Single NaN,1)=NaN');
  CheckNear(PI_VALUE / 4.0, ArcTan2(DoubleInfinity, DoubleInfinity), 0.0001,
    'ArcTan2(+Inf,+Inf)=PI/4');
  CheckNear(3.0 * PI_VALUE / 4.0, ArcTan2(DoubleInfinity, -DoubleInfinity), 0.0001,
    'ArcTan2(+Inf,-Inf)=3PI/4');
  CheckNear(-PI_VALUE / 4.0, ArcTan2(-DoubleInfinity, DoubleInfinity), 0.0001,
    'ArcTan2(-Inf,+Inf)=-PI/4');
  CheckNear(-3.0 * PI_VALUE / 4.0, ArcTan2(-DoubleInfinity, -DoubleInfinity), 0.0001,
    'ArcTan2(-Inf,-Inf)=-3PI/4');
  CheckNear(PI_VALUE / 4.0, ArcTan2(SingleInfinity, SingleInfinity), 0.0001,
    'ArcTan2(Single +Inf,+Inf)=PI/4');
end;

procedure TestArcTan2SignedZeroContracts;
begin
  CheckNear(0.0, ArcTan2(0.0, 0.0), 0.0, 'ArcTan2(+0,+0)=+0');
  Check(IsDoubleNegativeZero(ArcTan2(DoubleNegativeZero, 0.0)),
    'ArcTan2(-0,+0)=-0');
  CheckNear(PI_VALUE, ArcTan2(0.0, DoubleNegativeZero), 0.000001,
    'ArcTan2(+0,-0)=+PI');
  CheckNear(-PI_VALUE, ArcTan2(DoubleNegativeZero, DoubleNegativeZero), 0.000001,
    'ArcTan2(-0,-0)=-PI');
  CheckNear(PI_VALUE, ArcTan2(0.0, -1.0), 0.000001,
    'ArcTan2(+0,negative)=+PI');
  CheckNear(-PI_VALUE, ArcTan2(DoubleNegativeZero, -1.0), 0.000001,
    'ArcTan2(-0,negative)=-PI');

  CheckNear(0.0, ArcTan2(Single(0.0), Single(0.0)), 0.0,
    'ArcTan2(Single +0,+0)=+0');
  Check(IsSingleNegativeZero(ArcTan2(SingleNegativeZero, Single(0.0))),
    'ArcTan2(Single -0,+0)=-0');
  CheckNear(PI_VALUE, ArcTan2(Single(0.0), SingleNegativeZero), 0.000001,
    'ArcTan2(Single +0,-0)=+PI');
  CheckNear(-PI_VALUE, ArcTan2(SingleNegativeZero, SingleNegativeZero), 0.000001,
    'ArcTan2(Single -0,-0)=-PI');
  CheckNear(PI_VALUE, ArcTan2(Single(0.0), Single(-1.0)), 0.000001,
    'ArcTan2(Single +0,negative)=+PI');
  CheckNear(-PI_VALUE, ArcTan2(SingleNegativeZero, Single(-1.0)), 0.000001,
    'ArcTan2(Single -0,negative)=-PI');
end;

procedure TestExpLogAndSqrtContracts;
begin
  CheckNear(1.0, Exp(0.0), 0.0001, 'Exp(0)=1');
  CheckNear(2.71828, Exp(1.0), 0.001, 'Exp(1)=e');
  CheckNear(2.71828, Exp(Single(1.0)), 0.001, 'Exp(Single 1)=e');
  CheckNear(0.0, Ln(1.0), 0.0001, 'Ln(1)=0');
  CheckNear(0.0, Ln(Single(1.0)), 0.0001, 'Ln(Single 1)=0');
  CheckNear(1.0, Ln(2.71828), 0.001, 'Ln(e)=1');
  CheckNear(3.0, Log2(8.0), 0.0001, 'Log2(8)=3');
  CheckNear(3.0, Log2(Single(8.0)), 0.0001, 'Log2(Single 8)=3');
  CheckNear(3.0, Log10(1000.0), 0.0001, 'Log10(1000)=3');
  CheckNear(3.0, Log10(Single(1000.0)), 0.0001, 'Log10(Single 1000)=3');
  Check(IsDoubleNaN(Log2(-1.0)), 'Log2(negative)=NaN');
  Check(IsDoubleNaN(Log10(-1.0)), 'Log10(negative)=NaN');
  CheckNear(2.0, Sqrt(4.0), 0.0001, 'Sqrt(4)=2');
  CheckNear(2.0, Sqrt(Single(4.0)), 0.0001, 'Sqrt(Single 4)=2');
  CheckNear(1.41421, Sqrt(2.0), 0.001, 'Sqrt(2)=1.414');
  Check(IsDoubleNaN(Sqrt(-1.0)), 'Sqrt(-1)=NaN');
  Check(IsSingleNaN(Sqrt(Single(-1.0))), 'Sqrt(Single -1)=NaN');
end;

procedure TestPowerEdgeContracts;
begin
  CheckNear(1024.0, Power(2.0, 10.0), 0.001, 'Power(2,10)=1024');
  CheckNear(1024.0, Power(Single(2.0), Single(10.0)), 0.001, 'Power(Single 2,10)=1024');
  CheckNear(-8.0, Power(-2.0, 3.0), 0.0001, 'Power negative base odd integer exponent');
  CheckNear(4.0, Power(-2.0, 2.0), 0.0001, 'Power negative base even integer exponent');
  CheckNear(-0.125, Power(-2.0, -3.0), 0.0001, 'Power negative base negative odd exponent');
  CheckNear(-8.0, Power(Single(-2.0), Single(3.0)), 0.0001,
    'Power Single negative base odd integer exponent');
  Check(IsDoubleNaN(Power(-2.0, 0.5)), 'Power negative base fractional exponent returns NaN');
  Check(IsSingleNaN(Power(Single(-2.0), Single(0.5))),
    'Power Single negative base fractional exponent returns NaN');
  Check(IsDoublePositiveInfinity(Power(0.0, -1.0)),
    'Power zero negative exponent returns +Inf');
  Check(IsSinglePositiveInfinity(Power(Single(0.0), Single(-1.0))),
    'Power Single zero negative exponent returns +Inf');
  Check(IsDoubleNaN(Power(0.0, DoubleNaN)),
    'Power zero NaN exponent returns NaN');
  Check(IsSingleNaN(Power(Single(0.0), SingleNaN)),
    'Power Single zero NaN exponent returns NaN');
  Check(IsDoubleNaN(Power(DoubleNegativeZero, DoubleNaN)),
    'Power negative zero NaN exponent returns NaN');
  Check(IsSingleNaN(Power(SingleNegativeZero, SingleNaN)),
    'Power Single negative zero NaN exponent returns NaN');
  Check(IsDoubleNegativeZero(Power(DoubleNegativeZero, 3.0)),
    'Power negative zero odd positive exponent returns -0');
  Check(IsSingleNegativeZero(Power(SingleNegativeZero, Single(3.0))),
    'Power Single negative zero odd positive exponent returns -0');
  Check(IsDoublePositiveZero(Power(DoubleNegativeZero, 2.0)),
    'Power negative zero even positive exponent returns +0');
  Check(IsSinglePositiveZero(Power(SingleNegativeZero, Single(2.0))),
    'Power Single negative zero even positive exponent returns +0');
  Check(IsDoubleNegativeInfinity(Power(DoubleNegativeZero, -3.0)),
    'Power negative zero odd negative exponent returns -Inf');
  Check(IsSingleNegativeInfinity(Power(SingleNegativeZero, Single(-3.0))),
    'Power Single negative zero odd negative exponent returns -Inf');
  Check(IsDoublePositiveInfinity(Power(DoubleNegativeZero, -2.0)),
    'Power negative zero even negative exponent returns +Inf');
  Check(IsSinglePositiveInfinity(Power(SingleNegativeZero, Single(-2.0))),
    'Power Single negative zero even negative exponent returns +Inf');
end;

procedure TestAngleConversions;
begin
  CheckNear(PI_VALUE, DegToRad(180.0), 0.0001, 'DegToRad(180)=PI');
  CheckNear(PI_VALUE, DegToRad(Single(180.0)), 0.0001, 'DegToRad(Single 180)=PI');
  CheckNear(180.0, RadToDeg(PI_VALUE), 0.0001, 'RadToDeg(PI)=180');
  CheckNear(180.0, RadToDeg(Single(PI_VALUE)), 0.0001, 'RadToDeg(Single PI)=180');
end;

begin
  T := TTestRunner.Create('nextpas.core.math.trig');
  T.Run('basic trig values', @TestBasicTrigValues);
  T.Run('inverse trig domain contracts', @TestInverseTrigDomainContracts);
  T.Run('ArcTan2 special cases', @TestArcTan2SpecialCases);
  T.Run('ArcTan2 signed zero contracts', @TestArcTan2SignedZeroContracts);
  T.Run('exp/log/sqrt contracts', @TestExpLogAndSqrtContracts);
  T.Run('power edge contracts', @TestPowerEdgeContracts);
  T.Run('angle conversions', @TestAngleConversions);
  T.Summary;
end.
