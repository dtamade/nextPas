program test_easing;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.testing,
  nextpas.core.math.easing;

var
  T: TTestRunner;

procedure CheckNear(const AExpected, AActual: Double; const AMessage: string);
var
  Delta: Double;
begin
  Delta := AExpected - AActual;
  if Delta < 0.0 then
    Delta := -Delta;
  Check(Delta <= 0.0000001, AMessage);
end;

procedure CheckEase(const AName: string; const AFunc: TEasingFunction; const AMidpoint: Double);
begin
  CheckNear(0.0, AFunc(0.0), AName + ' starts at zero');
  CheckNear(1.0, AFunc(1.0), AName + ' ends at one');
  CheckNear(AMidpoint, AFunc(0.5), AName + ' midpoint');
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

begin
  T := TTestRunner.Create('nextpas.core.math.easing');
  T.Run('polynomial and expo easing', @TestPolynomialAndExpoEasing);
  T.Run('elastic back and bounce easing', @TestElasticBackAndBounceEasing);
  T.Summary;
end.
