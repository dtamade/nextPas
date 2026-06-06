program test_easing;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.errors,
  nextpas.core.testing,
  nextpas.core.math.easing;

type
  TDoubleBitCast = packed record
    case Integer of
      0: (Value: Double);
      1: (Bits: QWord);
  end;

  TEasingCase = record
    Name: string;
    Func: TEasingFunction;
  end;

  TOutOfRangeCase = record
    Name: string;
    Func: TEasingFunction;
    BelowZeroExpected: Double;
    AboveOneExpected: Double;
  end;

var
  T: TTestRunner;

procedure CheckNearEpsilon(const AExpected, AActual, AEpsilon: Double; const AMessage: string);
var
  Delta: Double;
begin
  Delta := AExpected - AActual;
  if Delta < 0.0 then
    Delta := -Delta;
  Check(Delta <= AEpsilon, AMessage);
end;

procedure CheckNear(const AExpected, AActual: Double; const AMessage: string);
begin
  CheckNearEpsilon(AExpected, AActual, 0.0000001, AMessage);
end;

procedure CheckEase(const AName: string; const AFunc: TEasingFunction; const AMidpoint: Double);
begin
  CheckNear(0.0, AFunc(0.0), AName + ' starts at zero');
  CheckNear(1.0, AFunc(1.0), AName + ' ends at one');
  CheckNear(AMidpoint, AFunc(0.5), AName + ' midpoint');
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

procedure TestPolynomialAndExpoEasing;
var
  Func: TEasingFunction;
begin
  Func := @EaseInQuad;
  CheckNear(0.25, Func(0.5), 'TEasingFunction accepts easing functions');

  CheckEase('EaseLinear', @EaseLinear, 0.5);
  CheckEase('EaseInQuad', @EaseInQuad, 0.25);
  CheckEase('EaseOutQuad', @EaseOutQuad, 0.75);
  CheckEase('EaseInOutQuad', @EaseInOutQuad, 0.5);
  CheckNear(0.125, EaseInOutQuad(0.25), 'EaseInOutQuad first half');
  CheckNear(0.875, EaseInOutQuad(0.75), 'EaseInOutQuad second half');

  CheckEase('EaseInCubic', @EaseInCubic, 0.125);
  CheckEase('EaseOutCubic', @EaseOutCubic, 0.875);
  CheckEase('EaseInOutCubic', @EaseInOutCubic, 0.5);
  CheckNear(0.0625, EaseInOutCubic(0.25), 'EaseInOutCubic first half');
  CheckNear(0.9375, EaseInOutCubic(0.75), 'EaseInOutCubic second half');

  CheckEase('EaseInQuart', @EaseInQuart, 0.0625);
  CheckEase('EaseOutQuart', @EaseOutQuart, 0.9375);
  CheckEase('EaseInOutQuart', @EaseInOutQuart, 0.5);
  CheckNear(0.03125, EaseInOutQuart(0.25), 'EaseInOutQuart first half');
  CheckNear(0.96875, EaseInOutQuart(0.75), 'EaseInOutQuart second half');

  CheckEase('EaseInExpo', @EaseInExpo, 0.03125);
  CheckEase('EaseOutExpo', @EaseOutExpo, 0.96875);
  CheckEase('EaseInOutExpo', @EaseInOutExpo, 0.5);
  CheckNear(0.015625, EaseInOutExpo(0.25), 'EaseInOutExpo first half');
  CheckNear(0.984375, EaseInOutExpo(0.75), 'EaseInOutExpo second half');
end;

procedure TestElasticBackAndBounceEasing;
begin
  CheckEase('EaseInElastic', @EaseInElastic, -0.015625);
  CheckEase('EaseOutElastic', @EaseOutElastic, 1.015625);
  CheckEase('EaseInOutElastic', @EaseInOutElastic, 0.5);
  CheckNear(0.011969444423734, EaseInOutElastic(0.25), 'EaseInOutElastic first half');
  CheckNear(0.988030555576266, EaseInOutElastic(0.75), 'EaseInOutElastic second half');

  CheckEase('EaseInBack', @EaseInBack, -0.0876975);
  CheckEase('EaseOutBack', @EaseOutBack, 1.0876975);
  CheckEase('EaseInOutBack', @EaseInOutBack, 0.5);
  CheckNear(-0.09968184375, EaseInOutBack(0.25), 'EaseInOutBack first half');
  CheckNear(1.09968184375, EaseInOutBack(0.75), 'EaseInOutBack second half');

  CheckEase('EaseInBounce', @EaseInBounce, 0.234375);
  CheckEase('EaseOutBounce', @EaseOutBounce, 0.765625);
  CheckEase('EaseInOutBounce', @EaseInOutBounce, 0.5);
  CheckNear(0.1171875, EaseInOutBounce(0.25), 'EaseInOutBounce first half');
  CheckNear(0.8828125, EaseInOutBounce(0.75), 'EaseInOutBounce second half');
end;

procedure TestFiniteOutOfRangeInputsExtrapolate;
const
  Cases: array[0..21] of TOutOfRangeCase = (
    (Name: 'EaseLinear'; Func: @EaseLinear;
      BelowZeroExpected: -0.5; AboveOneExpected: 1.5),
    (Name: 'EaseInQuad'; Func: @EaseInQuad;
      BelowZeroExpected: 0.25; AboveOneExpected: 2.25),
    (Name: 'EaseOutQuad'; Func: @EaseOutQuad;
      BelowZeroExpected: -1.25; AboveOneExpected: 0.75),
    (Name: 'EaseInOutQuad'; Func: @EaseInOutQuad;
      BelowZeroExpected: 0.5; AboveOneExpected: 0.5),
    (Name: 'EaseInCubic'; Func: @EaseInCubic;
      BelowZeroExpected: -0.125; AboveOneExpected: 3.375),
    (Name: 'EaseOutCubic'; Func: @EaseOutCubic;
      BelowZeroExpected: -2.375; AboveOneExpected: 1.125),
    (Name: 'EaseInOutCubic'; Func: @EaseInOutCubic;
      BelowZeroExpected: -0.5; AboveOneExpected: 1.5),
    (Name: 'EaseInQuart'; Func: @EaseInQuart;
      BelowZeroExpected: 0.0625; AboveOneExpected: 5.0625),
    (Name: 'EaseOutQuart'; Func: @EaseOutQuart;
      BelowZeroExpected: -4.0625; AboveOneExpected: 0.9375),
    (Name: 'EaseInOutQuart'; Func: @EaseInOutQuart;
      BelowZeroExpected: 0.5; AboveOneExpected: 0.5),
    (Name: 'EaseInExpo'; Func: @EaseInExpo;
      BelowZeroExpected: 0.000030517578125; AboveOneExpected: 32.0),
    (Name: 'EaseOutExpo'; Func: @EaseOutExpo;
      BelowZeroExpected: -31.0; AboveOneExpected: 0.999969482421875),
    (Name: 'EaseInOutExpo'; Func: @EaseInOutExpo;
      BelowZeroExpected: 0.000000476837158203125; AboveOneExpected: 0.9999995231628418),
    (Name: 'EaseInElastic'; Func: @EaseInElastic;
      BelowZeroExpected: 0.000030517578125; AboveOneExpected: -16.0),
    (Name: 'EaseOutElastic'; Func: @EaseOutElastic;
      BelowZeroExpected: 17.0; AboveOneExpected: 0.999969482421875),
    (Name: 'EaseInOutElastic'; Func: @EaseInOutElastic;
      BelowZeroExpected: -0.00000044808035867656106; AboveOneExpected: 1.0000004480803587),
    (Name: 'EaseInBack'; Func: @EaseInBack;
      BelowZeroExpected: -0.7630925; AboveOneExpected: 5.2892775),
    (Name: 'EaseOutBack'; Func: @EaseOutBack;
      BelowZeroExpected: -4.2892775; AboveOneExpected: 1.7630925),
    (Name: 'EaseInOutBack'; Func: @EaseInOutBack;
      BelowZeroExpected: -3.0949095; AboveOneExpected: 4.0949095),
    (Name: 'EaseInBounce'; Func: @EaseInBounce;
      BelowZeroExpected: -2.234375; AboveOneExpected: -0.890625),
    (Name: 'EaseOutBounce'; Func: @EaseOutBounce;
      BelowZeroExpected: 1.890625; AboveOneExpected: 3.234375),
    (Name: 'EaseInOutBounce'; Func: @EaseInOutBounce;
      BelowZeroExpected: -4.125; AboveOneExpected: 5.125)
  );
var
  I: Integer;
begin
  for I := Low(Cases) to High(Cases) do
  begin
    CheckNearEpsilon(Cases[I].BelowZeroExpected, Cases[I].Func(-0.5), 0.000001,
      Cases[I].Name + ' extrapolates finite input below zero');
    CheckNearEpsilon(Cases[I].AboveOneExpected, Cases[I].Func(1.5), 0.000001,
      Cases[I].Name + ' extrapolates finite input above one');
  end;
end;

procedure TestNonFiniteInputsFailFast;
const
  Cases: array[0..20] of TEasingCase = (
    (Name: 'EaseLinear'; Func: @EaseLinear),
    (Name: 'EaseInQuad'; Func: @EaseInQuad),
    (Name: 'EaseOutQuad'; Func: @EaseOutQuad),
    (Name: 'EaseInOutQuad'; Func: @EaseInOutQuad),
    (Name: 'EaseInCubic'; Func: @EaseInCubic),
    (Name: 'EaseOutCubic'; Func: @EaseOutCubic),
    (Name: 'EaseInOutCubic'; Func: @EaseInOutCubic),
    (Name: 'EaseInQuart'; Func: @EaseInQuart),
    (Name: 'EaseOutQuart'; Func: @EaseOutQuart),
    (Name: 'EaseInOutQuart'; Func: @EaseInOutQuart),
    (Name: 'EaseInExpo'; Func: @EaseInExpo),
    (Name: 'EaseOutExpo'; Func: @EaseOutExpo),
    (Name: 'EaseInOutExpo'; Func: @EaseInOutExpo),
    (Name: 'EaseInElastic'; Func: @EaseInElastic),
    (Name: 'EaseOutElastic'; Func: @EaseOutElastic),
    (Name: 'EaseInOutElastic'; Func: @EaseInOutElastic),
    (Name: 'EaseInBack'; Func: @EaseInBack),
    (Name: 'EaseOutBack'; Func: @EaseOutBack),
    (Name: 'EaseInOutBack'; Func: @EaseInOutBack),
    (Name: 'EaseInBounce'; Func: @EaseInBounce),
    (Name: 'EaseOutBounce'; Func: @EaseOutBounce)
  );
var
  I: Integer;
  Caught: Boolean;
begin
  for I := Low(Cases) to High(Cases) do
  begin
    Caught := False;
    try
      Cases[I].Func(DoubleNaN);
    except
      on E: EArgumentError do
        Caught := True;
    end;
    Check(Caught, Cases[I].Name + ' rejects NaN input');

    Caught := False;
    try
      Cases[I].Func(DoubleInfinity);
    except
      on E: EArgumentError do
        Caught := True;
    end;
    Check(Caught, Cases[I].Name + ' rejects infinite input');
  end;

  Caught := False;
  try
    EaseInOutBounce(DoubleNaN);
  except
    on E: EArgumentError do
      Caught := True;
  end;
  Check(Caught, 'EaseInOutBounce rejects NaN input');

  Caught := False;
  try
    EaseInOutBounce(DoubleInfinity);
  except
    on E: EArgumentError do
      Caught := True;
  end;
  Check(Caught, 'EaseInOutBounce rejects infinite input');
end;

begin
  T := TTestRunner.Create('nextpas.core.math.easing');
  T.Run('polynomial and expo easing', @TestPolynomialAndExpoEasing);
  T.Run('elastic back and bounce easing', @TestElasticBackAndBounceEasing);
  T.Run('finite out-of-range inputs extrapolate', @TestFiniteOutOfRangeInputsExtrapolate);
  T.Run('non-finite inputs fail fast', @TestNonFiniteInputsFailFast);
  T.Summary;
end.
