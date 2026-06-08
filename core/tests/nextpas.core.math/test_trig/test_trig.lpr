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

function DoublePowerOfTwo63: Double;
var
  LValue: TDoubleBitCast;
begin
  LValue.Bits := $43E0000000000000;
  Result := LValue.Value;
end;

function SingleMaxFinite: Single;
var
  LValue: TSingleBitCast;
begin
  LValue.Bits := $7F7FFFFF;
  Result := LValue.Value;
end;

function SingleMinPositiveNormal: Single;
var
  LValue: TSingleBitCast;
begin
  LValue.Bits := $00800000;
  Result := LValue.Value;
end;

function DoubleMaxFinite: Double;
var
  LValue: TDoubleBitCast;
begin
  LValue.Bits := $7FEFFFFFFFFFFFFF;
  Result := LValue.Value;
end;

function DoubleMinPositiveNormal: Double;
var
  LValue: TDoubleBitCast;
begin
  LValue.Bits := $0010000000000000;
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
  CheckNear(0.0, ArcCos(1.0), 0.0001, 'ArcCos(1)=0');
  CheckNear(PI_VALUE, ArcCos(-1.0), 0.0001, 'ArcCos(-1)=PI');
  CheckNear(0.0, ArcCos(Single(1.0)), 0.0001, 'ArcCos(Single 1)=0');
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
  Check(IsDoubleNaN(ArcSin(-1.0001)), 'ArcSin below lower domain returns NaN');
  Check(IsSingleNaN(ArcSin(Single(1.0001))), 'ArcSin(Single out of domain)=NaN');
  Check(IsSingleNaN(ArcSin(Single(-1.0001))), 'ArcSin Single below lower domain returns NaN');
  Check(IsDoubleNaN(ArcCos(-1.0001)), 'ArcCos(out of domain)=NaN');
  Check(IsDoubleNaN(ArcCos(1.0001)), 'ArcCos above upper domain returns NaN');
  Check(IsSingleNaN(ArcCos(Single(-1.0001))), 'ArcCos(Single out of domain)=NaN');
  Check(IsSingleNaN(ArcCos(Single(1.0001))), 'ArcCos Single above upper domain returns NaN');
end;

procedure TestInverseTrigNonFiniteContracts;
begin
  Check(IsDoubleNaN(ArcSin(DoubleNaN)), 'ArcSin(NaN)=NaN');
  Check(IsSingleNaN(ArcSin(SingleNaN)), 'ArcSin(Single NaN)=NaN');
  Check(IsDoubleNaN(ArcSin(DoubleInfinity)), 'ArcSin(+Inf)=NaN');
  Check(IsDoubleNaN(ArcSin(-DoubleInfinity)), 'ArcSin(-Inf)=NaN');
  Check(IsSingleNaN(ArcSin(SingleInfinity)), 'ArcSin(Single +Inf)=NaN');
  Check(IsSingleNaN(ArcSin(-SingleInfinity)), 'ArcSin(Single -Inf)=NaN');

  Check(IsDoubleNaN(ArcCos(DoubleNaN)), 'ArcCos(NaN)=NaN');
  Check(IsSingleNaN(ArcCos(SingleNaN)), 'ArcCos(Single NaN)=NaN');
  Check(IsDoubleNaN(ArcCos(DoubleInfinity)), 'ArcCos(+Inf)=NaN');
  Check(IsDoubleNaN(ArcCos(-DoubleInfinity)), 'ArcCos(-Inf)=NaN');
  Check(IsSingleNaN(ArcCos(SingleInfinity)), 'ArcCos(Single +Inf)=NaN');
  Check(IsSingleNaN(ArcCos(-SingleInfinity)), 'ArcCos(Single -Inf)=NaN');
end;

procedure TestCircularTrigNonFiniteContracts;
begin
  Check(IsDoubleNaN(Sin(DoubleNaN)), 'Sin(NaN)=NaN');
  Check(IsSingleNaN(Sin(SingleNaN)), 'Sin(Single NaN)=NaN');
  Check(IsDoubleNaN(Sin(DoubleInfinity)), 'Sin(+Inf)=NaN');
  Check(IsDoubleNaN(Sin(-DoubleInfinity)), 'Sin(-Inf)=NaN');
  Check(IsSingleNaN(Sin(SingleInfinity)), 'Sin(Single +Inf)=NaN');
  Check(IsSingleNaN(Sin(-SingleInfinity)), 'Sin(Single -Inf)=NaN');

  Check(IsDoubleNaN(Cos(DoubleNaN)), 'Cos(NaN)=NaN');
  Check(IsSingleNaN(Cos(SingleNaN)), 'Cos(Single NaN)=NaN');
  Check(IsDoubleNaN(Cos(DoubleInfinity)), 'Cos(+Inf)=NaN');
  Check(IsDoubleNaN(Cos(-DoubleInfinity)), 'Cos(-Inf)=NaN');
  Check(IsSingleNaN(Cos(SingleInfinity)), 'Cos(Single +Inf)=NaN');
  Check(IsSingleNaN(Cos(-SingleInfinity)), 'Cos(Single -Inf)=NaN');

  Check(IsDoubleNaN(Tan(DoubleNaN)), 'Tan(NaN)=NaN');
  Check(IsSingleNaN(Tan(SingleNaN)), 'Tan(Single NaN)=NaN');
  Check(IsDoubleNaN(Tan(DoubleInfinity)), 'Tan(+Inf)=NaN');
  Check(IsDoubleNaN(Tan(-DoubleInfinity)), 'Tan(-Inf)=NaN');
  Check(IsSingleNaN(Tan(SingleInfinity)), 'Tan(Single +Inf)=NaN');
  Check(IsSingleNaN(Tan(-SingleInfinity)), 'Tan(Single -Inf)=NaN');
end;

procedure TestArcTanSpecialContracts;
begin
  Check(IsDoubleNaN(ArcTan(DoubleNaN)), 'ArcTan(NaN)=NaN');
  Check(IsSingleNaN(ArcTan(SingleNaN)), 'ArcTan(Single NaN)=NaN');
  CheckNear(HALF_PI, ArcTan(DoubleInfinity), 0.000000000001,
    'ArcTan(+Inf)=PI/2');
  CheckNear(-HALF_PI, ArcTan(-DoubleInfinity), 0.000000000001,
    'ArcTan(-Inf)=-PI/2');
  CheckNear(HALF_PI, ArcTan(SingleInfinity), 0.000001,
    'ArcTan(Single +Inf)=PI/2');
  CheckNear(-HALF_PI, ArcTan(-SingleInfinity), 0.000001,
    'ArcTan(Single -Inf)=-PI/2');
  Check(IsDoublePositiveZero(ArcTan(0.0)), 'ArcTan(+0)=+0');
  Check(IsDoubleNegativeZero(ArcTan(DoubleNegativeZero)), 'ArcTan(-0)=-0');
  Check(IsSinglePositiveZero(ArcTan(Single(0.0))), 'ArcTan(Single +0)=+0');
  Check(IsSingleNegativeZero(ArcTan(SingleNegativeZero)), 'ArcTan(Single -0)=-0');
  CheckNear(-PI_VALUE / 4.0, ArcTan(Double(-1.0)), 0.000000000001,
    'ArcTan(-1)=-PI/4');
  CheckNear(-PI_VALUE / 4.0, ArcTan(Single(-1.0)), 0.000001,
    'ArcTan(Single -1)=-PI/4');
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
  CheckNear(3.0 * PI_VALUE / 4.0, ArcTan2(SingleInfinity, -SingleInfinity), 0.0001,
    'ArcTan2(Single +Inf,-Inf)=3PI/4');
  CheckNear(-PI_VALUE / 4.0, ArcTan2(-SingleInfinity, SingleInfinity), 0.0001,
    'ArcTan2(Single -Inf,+Inf)=-PI/4');
  CheckNear(-3.0 * PI_VALUE / 4.0, ArcTan2(-SingleInfinity, -SingleInfinity), 0.0001,
    'ArcTan2(Single -Inf,-Inf)=-3PI/4');
end;

procedure TestArcTan2OneInfiniteContracts;
begin
  CheckNear(HALF_PI, ArcTan2(DoubleInfinity, 1.0), 0.000000000001,
    'ArcTan2(+Inf,+finite)=PI/2');
  CheckNear(-HALF_PI, ArcTan2(-DoubleInfinity, 1.0), 0.000000000001,
    'ArcTan2(-Inf,+finite)=-PI/2');
  CheckNear(HALF_PI, ArcTan2(DoubleInfinity, -1.0), 0.000000000001,
    'ArcTan2(+Inf,-finite)=PI/2');
  CheckNear(-HALF_PI, ArcTan2(-DoubleInfinity, -1.0), 0.000000000001,
    'ArcTan2(-Inf,-finite)=-PI/2');

  Check(IsDoublePositiveZero(ArcTan2(1.0, DoubleInfinity)),
    'ArcTan2(+finite,+Inf)=+0');
  Check(IsDoubleNegativeZero(ArcTan2(-1.0, DoubleInfinity)),
    'ArcTan2(-finite,+Inf)=-0');
  CheckNear(PI_VALUE, ArcTan2(1.0, -DoubleInfinity), 0.000000000001,
    'ArcTan2(+finite,-Inf)=PI');
  CheckNear(-PI_VALUE, ArcTan2(-1.0, -DoubleInfinity), 0.000000000001,
    'ArcTan2(-finite,-Inf)=-PI');

  CheckNear(HALF_PI, ArcTan2(SingleInfinity, Single(1.0)), 0.000001,
    'ArcTan2(Single +Inf,+finite)=PI/2');
  CheckNear(-HALF_PI, ArcTan2(-SingleInfinity, Single(1.0)), 0.000001,
    'ArcTan2(Single -Inf,+finite)=-PI/2');
  CheckNear(HALF_PI, ArcTan2(SingleInfinity, Single(-1.0)), 0.000001,
    'ArcTan2(Single +Inf,-finite)=PI/2');
  CheckNear(-HALF_PI, ArcTan2(-SingleInfinity, Single(-1.0)), 0.000001,
    'ArcTan2(Single -Inf,-finite)=-PI/2');

  Check(IsSinglePositiveZero(ArcTan2(Single(1.0), SingleInfinity)),
    'ArcTan2(Single +finite,+Inf)=+0');
  Check(IsSingleNegativeZero(ArcTan2(Single(-1.0), SingleInfinity)),
    'ArcTan2(Single -finite,+Inf)=-0');
  CheckNear(PI_VALUE, ArcTan2(Single(1.0), -SingleInfinity), 0.000001,
    'ArcTan2(Single +finite,-Inf)=PI');
  CheckNear(-PI_VALUE, ArcTan2(Single(-1.0), -SingleInfinity), 0.000001,
    'ArcTan2(Single -finite,-Inf)=-PI');
end;

procedure TestArcTan2SignedZeroContracts;
begin
  Check(IsDoublePositiveZero(ArcTan2(0.0, 0.0)), 'ArcTan2(+0,+0)=+0');
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
  CheckNear(PI_VALUE, ArcTan2(0.0, -DoubleInfinity), 0.000001,
    'ArcTan2(+0,-Inf)=+PI');
  CheckNear(-PI_VALUE, ArcTan2(DoubleNegativeZero, -DoubleInfinity), 0.000001,
    'ArcTan2(-0,-Inf)=-PI');

  Check(IsSinglePositiveZero(ArcTan2(Single(0.0), Single(0.0))),
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
  CheckNear(PI_VALUE, ArcTan2(Single(0.0), -SingleInfinity), 0.000001,
    'ArcTan2(Single +0,-Inf)=+PI');
  CheckNear(-PI_VALUE, ArcTan2(SingleNegativeZero, -SingleInfinity), 0.000001,
    'ArcTan2(Single -0,-Inf)=-PI');
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

procedure TestExpSqrtIEEEContracts;
begin
  Check(IsDoubleNaN(Exp(DoubleNaN)), 'Exp(NaN)=NaN');
  Check(IsSingleNaN(Exp(SingleNaN)), 'Exp(Single NaN)=NaN');
  Check(IsDoublePositiveInfinity(Exp(DoubleInfinity)), 'Exp(+Inf)=+Inf');
  Check(IsSinglePositiveInfinity(Exp(SingleInfinity)), 'Exp(Single +Inf)=+Inf');
  Check(IsDoublePositiveZero(Exp(-DoubleInfinity)), 'Exp(-Inf)=+0');
  Check(IsSinglePositiveZero(Exp(-SingleInfinity)), 'Exp(Single -Inf)=+0');

  Check(IsDoubleNaN(Sqrt(DoubleNaN)), 'Sqrt(NaN)=NaN');
  Check(IsSingleNaN(Sqrt(SingleNaN)), 'Sqrt(Single NaN)=NaN');
  Check(IsDoublePositiveZero(Sqrt(0.0)), 'Sqrt(+0)=+0');
  Check(IsSinglePositiveZero(Sqrt(Single(0.0))), 'Sqrt(Single +0)=+0');
  Check(IsDoubleNegativeZero(Sqrt(DoubleNegativeZero)), 'Sqrt(-0)=-0');
  Check(IsSingleNegativeZero(Sqrt(SingleNegativeZero)), 'Sqrt(Single -0)=-0');
  Check(IsDoublePositiveInfinity(Sqrt(DoubleInfinity)), 'Sqrt(+Inf)=+Inf');
  Check(IsSinglePositiveInfinity(Sqrt(SingleInfinity)), 'Sqrt(Single +Inf)=+Inf');
  Check(IsDoubleNaN(Sqrt(-DoubleInfinity)), 'Sqrt(-Inf)=NaN');
  Check(IsSingleNaN(Sqrt(-SingleInfinity)), 'Sqrt(Single -Inf)=NaN');
end;

procedure TestExpFiniteOverflowUnderflowContracts;
begin
  Check(IsDoublePositiveInfinity(Exp(710.0)), 'Exp finite overflow returns +Inf');
  Check(IsDoublePositiveZero(Exp(-746.0)), 'Exp finite underflow returns +0');
  Check(IsSinglePositiveInfinity(Exp(Single(89.0))),
    'Exp Single finite overflow returns +Inf');
  Check(IsSinglePositiveZero(Exp(Single(-104.0))),
    'Exp Single finite underflow returns +0');
end;

procedure CheckLogDomainDouble(const AName: string; const ALogPositiveZero,
  ALogNegativeZero, ALogNegative, ALogNegativeInfinity, ALogNaN,
  ALogPositiveInfinity: Double);
begin
  Check(IsDoubleNegativeInfinity(ALogPositiveZero), AName + '(+0)=-Inf');
  Check(IsDoubleNegativeInfinity(ALogNegativeZero), AName + '(-0)=-Inf');
  Check(IsDoubleNaN(ALogNegative), AName + '(negative finite)=NaN');
  Check(IsDoubleNaN(ALogNegativeInfinity), AName + '(-Inf)=NaN');
  Check(IsDoubleNaN(ALogNaN), AName + '(NaN)=NaN');
  Check(IsDoublePositiveInfinity(ALogPositiveInfinity), AName + '(+Inf)=+Inf');
end;

procedure CheckLogDomainSingle(const AName: string; const ALogPositiveZero,
  ALogNegativeZero, ALogNegative, ALogNegativeInfinity, ALogNaN,
  ALogPositiveInfinity: Single);
begin
  Check(IsSingleNegativeInfinity(ALogPositiveZero), AName + '(+0)=-Inf');
  Check(IsSingleNegativeInfinity(ALogNegativeZero), AName + '(-0)=-Inf');
  Check(IsSingleNaN(ALogNegative), AName + '(negative finite)=NaN');
  Check(IsSingleNaN(ALogNegativeInfinity), AName + '(-Inf)=NaN');
  Check(IsSingleNaN(ALogNaN), AName + '(NaN)=NaN');
  Check(IsSinglePositiveInfinity(ALogPositiveInfinity), AName + '(+Inf)=+Inf');
end;

procedure TestLogDomainSignedZeroContracts;
begin
  Check(IsDoubleNegativeInfinity(Ln(0.0)), 'Ln(+0)=-Inf');
  Check(IsDoubleNegativeInfinity(Ln(DoubleNegativeZero)), 'Ln(-0)=-Inf');
  Check(IsDoubleNaN(Ln(-1.0)), 'Ln(negative finite)=NaN');
  Check(IsDoubleNaN(Ln(-DoubleInfinity)), 'Ln(-Inf)=NaN');
  Check(IsDoubleNaN(Ln(DoubleNaN)), 'Ln(NaN)=NaN');
  Check(IsDoublePositiveInfinity(Ln(DoubleInfinity)), 'Ln(+Inf)=+Inf');

  Check(IsSingleNegativeInfinity(Ln(Single(0.0))), 'Ln(Single +0)=-Inf');
  Check(IsSingleNegativeInfinity(Ln(SingleNegativeZero)), 'Ln(Single -0)=-Inf');
  Check(IsSingleNaN(Ln(Single(-1.0))), 'Ln(Single negative finite)=NaN');
  Check(IsSingleNaN(Ln(-SingleInfinity)), 'Ln(Single -Inf)=NaN');
  Check(IsSingleNaN(Ln(SingleNaN)), 'Ln(Single NaN)=NaN');
  Check(IsSinglePositiveInfinity(Ln(SingleInfinity)), 'Ln(Single +Inf)=+Inf');

  CheckLogDomainDouble('Log2', Log2(0.0), Log2(DoubleNegativeZero),
    Log2(-1.0), Log2(-DoubleInfinity), Log2(DoubleNaN), Log2(DoubleInfinity));
  CheckLogDomainSingle('Log2 Single', Log2(Single(0.0)), Log2(SingleNegativeZero),
    Log2(Single(-1.0)), Log2(-SingleInfinity), Log2(SingleNaN), Log2(SingleInfinity));

  CheckLogDomainDouble('Log10', Log10(0.0), Log10(DoubleNegativeZero),
    Log10(-1.0), Log10(-DoubleInfinity), Log10(DoubleNaN), Log10(DoubleInfinity));
  CheckLogDomainSingle('Log10 Single', Log10(Single(0.0)), Log10(SingleNegativeZero),
    Log10(Single(-1.0)), Log10(-SingleInfinity), Log10(SingleNaN), Log10(SingleInfinity));
end;

procedure TestPowerEdgeContracts;
begin
  CheckNear(1024.0, Power(2.0, 10.0), 0.001, 'Power(2,10)=1024');
  CheckNear(1024.0, Power(Single(2.0), Single(10.0)), 0.001, 'Power(Single 2,10)=1024');
  CheckNear(-8.0, Power(-2.0, 3.0), 0.0001, 'Power negative base odd integer exponent');
  CheckNear(4.0, Power(-2.0, 2.0), 0.0001, 'Power negative base even integer exponent');
  CheckNear(-0.125, Power(-2.0, -3.0), 0.0001, 'Power negative base negative odd exponent');
  CheckNear(0.25, Power(-2.0, -2.0), 0.000000000001,
    'Power negative base negative even exponent');
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

procedure TestPowerNegativeFiniteBaseNonIntegerContracts;
begin
  Check(IsDoubleNaN(Power(-1.0, 0.5)),
    'Power negative unit base fractional exponent returns NaN');
  Check(IsDoubleNaN(Power(-0.25, 0.5)),
    'Power negative abs(base)<1 fractional exponent returns NaN');
  Check(IsDoubleNaN(Power(-4.0, -0.5)),
    'Power negative base negative fractional exponent returns NaN');
  Check(IsDoubleNaN(Power(-8.0, 1.0 / 3.0)),
    'Power negative base non-integer rational exponent returns NaN');
  Check(IsSingleNaN(Power(Single(-0.25), Single(0.5))),
    'Power Single negative abs(base)<1 fractional exponent returns NaN');
  Check(IsSingleNaN(Power(Single(-4.0), Single(-0.5))),
    'Power Single negative base negative fractional exponent returns NaN');
  CheckNear(1.0, Power(-1.0, DoublePowerOfTwo63), 0.0,
    'Power negative unit base huge even integer exponent returns 1');
  Check(IsDoubleNaN(Power(-2.0, DoubleNaN)),
    'Power finite negative base NaN exponent returns NaN');
end;

procedure TestPowerNonFiniteContracts;
begin
  Check(IsDoubleNaN(Power(DoubleNaN, 2.0)), 'Power NaN base nonzero exponent returns NaN');
  CheckNear(1.0, Power(DoubleNaN, 0.0), 0.0, 'Power NaN base zero exponent returns 1');
  CheckNear(1.0, Power(1.0, DoubleNaN), 0.0,
    'Power +1 NaN exponent returns 1');
  Check(IsDoubleNaN(Power(-1.0, DoubleNaN)),
    'Power -1 NaN exponent returns NaN');

  CheckNear(1.0, Power(1.0, DoubleInfinity), 0.0,
    'Power +1 +Inf exponent returns 1');
  CheckNear(1.0, Power(1.0, -DoubleInfinity), 0.0,
    'Power +1 -Inf exponent returns 1');
  CheckNear(1.0, Power(-1.0, DoubleInfinity), 0.0,
    'Power -1 +Inf exponent returns 1');
  CheckNear(1.0, Power(-1.0, -DoubleInfinity), 0.0,
    'Power -1 -Inf exponent returns 1');
  CheckNear(1.0, Power(Single(1.0), SingleInfinity), 0.0,
    'Power Single +1 +Inf exponent returns 1');
  CheckNear(1.0, Power(Single(1.0), -SingleInfinity), 0.0,
    'Power Single +1 -Inf exponent returns 1');
  CheckNear(1.0, Power(Single(-1.0), SingleInfinity), 0.0,
    'Power Single -1 +Inf exponent returns 1');
  CheckNear(1.0, Power(Single(-1.0), -SingleInfinity), 0.0,
    'Power Single -1 -Inf exponent returns 1');

  Check(IsDoublePositiveZero(Power(0.0, DoubleInfinity)),
    'Power +0 +Inf exponent returns +0');
  Check(IsDoublePositiveInfinity(Power(0.0, -DoubleInfinity)),
    'Power +0 -Inf exponent returns +Inf');
  Check(IsDoublePositiveZero(Power(DoubleNegativeZero, DoubleInfinity)),
    'Power -0 +Inf exponent returns +0');
  Check(IsDoublePositiveInfinity(Power(DoubleNegativeZero, -DoubleInfinity)),
    'Power -0 -Inf exponent returns +Inf');

  Check(IsDoublePositiveInfinity(Power(2.0, DoubleInfinity)),
    'Power abs(base)>1 +Inf exponent returns +Inf');
  Check(IsDoublePositiveZero(Power(2.0, -DoubleInfinity)),
    'Power abs(base)>1 -Inf exponent returns +0');
  Check(IsDoublePositiveZero(Power(0.5, DoubleInfinity)),
    'Power abs(base)<1 +Inf exponent returns +0');
  Check(IsDoublePositiveInfinity(Power(0.5, -DoubleInfinity)),
    'Power abs(base)<1 -Inf exponent returns +Inf');
  Check(IsDoublePositiveInfinity(Power(-2.0, DoubleInfinity)),
    'Power negative abs(base)>1 +Inf exponent returns +Inf');
  Check(IsDoublePositiveZero(Power(-2.0, -DoubleInfinity)),
    'Power negative abs(base)>1 -Inf exponent returns +0');

  Check(IsDoublePositiveInfinity(Power(DoubleInfinity, 2.0)),
    'Power +Inf positive exponent returns +Inf');
  Check(IsDoublePositiveZero(Power(DoubleInfinity, -1.0)),
    'Power +Inf negative exponent returns +0');
  Check(IsDoubleNegativeInfinity(Power(-DoubleInfinity, 3.0)),
    'Power -Inf odd positive exponent returns -Inf');
  Check(IsDoubleNegativeZero(Power(-DoubleInfinity, -3.0)),
    'Power -Inf odd negative exponent returns -0');
  Check(IsDoublePositiveInfinity(Power(-DoubleInfinity, 2.0)),
    'Power -Inf even positive exponent returns +Inf');
  Check(IsDoublePositiveZero(Power(-DoubleInfinity, -2.0)),
    'Power -Inf even negative exponent returns +0');

  CheckNear(1.0, Power(SingleNaN, Single(0.0)), 0.0,
    'Power Single NaN base zero exponent returns 1');
  Check(IsSingleNaN(Power(SingleNaN, Single(2.0))),
    'Power Single NaN base nonzero exponent returns NaN');
  CheckNear(1.0, Power(Single(1.0), SingleNaN), 0.0,
    'Power Single +1 NaN exponent returns 1');
  Check(IsSingleNaN(Power(Single(-1.0), SingleNaN)),
    'Power Single -1 NaN exponent returns NaN');
  Check(IsSinglePositiveInfinity(Power(Single(-2.0), SingleInfinity)),
    'Power Single negative abs(base)>1 +Inf exponent returns +Inf');
  Check(IsSinglePositiveZero(Power(Single(-2.0), -SingleInfinity)),
    'Power Single negative abs(base)>1 -Inf exponent returns +0');
end;

procedure TestPowerFiniteOverflowUnderflowSignContracts;
begin
  Check(IsDoublePositiveInfinity(Power(2.0, 1024.0)),
    'Power finite overflow returns +Inf');
  Check(IsDoubleNegativeInfinity(Power(-2.0, 1025.0)),
    'Power negative finite odd overflow returns -Inf');
  Check(IsDoublePositiveZero(Power(2.0, -1075.0)),
    'Power finite underflow returns +0');
  Check(IsDoubleNegativeZero(Power(-2.0, -1075.0)),
    'Power negative finite odd underflow returns -0');

  Check(IsSinglePositiveInfinity(Power(Single(2.0), Single(128.0))),
    'Power Single finite overflow returns +Inf');
  Check(IsSingleNegativeInfinity(Power(Single(-2.0), Single(129.0))),
    'Power Single negative finite odd overflow returns -Inf');
  Check(IsSinglePositiveZero(Power(Single(2.0), Single(-151.0))),
    'Power Single finite underflow returns +0');
  Check(IsSingleNegativeZero(Power(Single(-2.0), Single(-151.0))),
    'Power Single negative finite odd underflow returns -0');
end;

procedure TestArcTan2FiniteExtremeRatioContracts;
begin
  CheckNear(HALF_PI, ArcTan2(DoubleMaxFinite, DoubleMinPositiveNormal),
    0.000000000001, 'ArcTan2 huge positive finite ratio stays +PI/2');
  CheckNear(-HALF_PI, ArcTan2(-DoubleMaxFinite, DoubleMinPositiveNormal),
    0.000000000001, 'ArcTan2 huge negative finite ratio stays -PI/2');
  Check(IsDoublePositiveZero(ArcTan2(DoubleMinPositiveNormal, DoubleMaxFinite)),
    'ArcTan2 tiny positive finite ratio returns +0');
  Check(IsDoubleNegativeZero(ArcTan2(-DoubleMinPositiveNormal, DoubleMaxFinite)),
    'ArcTan2 tiny negative finite ratio returns -0');
  CheckNear(PI_VALUE, ArcTan2(DoubleMinPositiveNormal, -DoubleMaxFinite),
    0.000000000001, 'ArcTan2 tiny positive ratio with negative x stays +PI');
  CheckNear(-PI_VALUE, ArcTan2(-DoubleMinPositiveNormal, -DoubleMaxFinite),
    0.000000000001, 'ArcTan2 tiny negative ratio with negative x stays -PI');

  CheckNear(HALF_PI, ArcTan2(SingleMaxFinite, SingleMinPositiveNormal),
    0.000001, 'ArcTan2 Single huge positive finite ratio stays +PI/2');
  CheckNear(-HALF_PI, ArcTan2(-SingleMaxFinite, SingleMinPositiveNormal),
    0.000001, 'ArcTan2 Single huge negative finite ratio stays -PI/2');
  Check(IsSinglePositiveZero(ArcTan2(SingleMinPositiveNormal, SingleMaxFinite)),
    'ArcTan2 Single tiny positive finite ratio returns +0');
  Check(IsSingleNegativeZero(ArcTan2(-SingleMinPositiveNormal, SingleMaxFinite)),
    'ArcTan2 Single tiny negative finite ratio returns -0');
  CheckNear(PI_VALUE, ArcTan2(SingleMinPositiveNormal, -SingleMaxFinite),
    0.000001, 'ArcTan2 Single tiny positive ratio with negative x stays +PI');
  CheckNear(-PI_VALUE, ArcTan2(-SingleMinPositiveNormal, -SingleMaxFinite),
    0.000001, 'ArcTan2 Single tiny negative ratio with negative x stays -PI');
end;

begin
  T := TTestRunner.Create('nextpas.core.math.trig');
  T.Run('basic trig values', @TestBasicTrigValues);
  T.Run('inverse trig domain contracts', @TestInverseTrigDomainContracts);
  T.Run('inverse trig non-finite contracts', @TestInverseTrigNonFiniteContracts);
  T.Run('circular trig non-finite contracts', @TestCircularTrigNonFiniteContracts);
  T.Run('ArcTan special contracts', @TestArcTanSpecialContracts);
  T.Run('ArcTan2 special cases', @TestArcTan2SpecialCases);
  T.Run('ArcTan2 one-infinite contracts', @TestArcTan2OneInfiniteContracts);
  T.Run('ArcTan2 signed zero contracts', @TestArcTan2SignedZeroContracts);
  T.Run('exp/log/sqrt contracts', @TestExpLogAndSqrtContracts);
  T.Run('exp sqrt IEEE contracts', @TestExpSqrtIEEEContracts);
  T.Run('Exp finite overflow underflow contracts', @TestExpFiniteOverflowUnderflowContracts);
  T.Run('log domain signed zero contracts', @TestLogDomainSignedZeroContracts);
  T.Run('power edge contracts', @TestPowerEdgeContracts);
  T.Run('power negative finite base non-integer contracts',
    @TestPowerNegativeFiniteBaseNonIntegerContracts);
  T.Run('power non-finite contracts', @TestPowerNonFiniteContracts);
  T.Run('Power finite overflow underflow sign contracts',
    @TestPowerFiniteOverflowUnderflowSignContracts);
  T.Run('ArcTan2 finite extreme ratio contracts', @TestArcTan2FiniteExtremeRatioContracts);
  T.Summary;
end.
