program test_tui_animator;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.tui.animator,
  nextpas.core.test;

var
  T: TTestSuite;

procedure TestAnimatorStart;
var
  LAnim: TAnimator;
  LTarget: Double;
  LId: Integer;
begin
  FillChar(LAnim, SizeOf(LAnim), 0);
  LTarget := 0;
  LId := LAnim.Start(@LTarget, 0, 100, 1000, @EaseLinear);
  Check(LId >= 0, 'Start should return valid id');
  Check(LAnim.AnyRunning, 'Should have running animation');
  Check(LAnim.RunningCount = 1, 'RunningCount should be 1');
end;

procedure TestAnimatorTick;
var
  LAnim: TAnimator;
  LTarget: Double;
begin
  FillChar(LAnim, SizeOf(LAnim), 0);
  LTarget := 0;
  LAnim.Start(@LTarget, 0, 100, 1000, @EaseLinear);
  LAnim.Tick(100);
  Check(LTarget = 0, 'Value at start should be 0');
  LAnim.Tick(600);
  Check(LTarget = 50, 'Value at 50% should be 50');
  LAnim.Tick(1100);
  Check(LTarget = 100, 'Value at end should be 100');
  Check(not LAnim.AnyRunning, 'Animation should be done');
end;

procedure TestAnimatorTickEasing;
var
  LAnim: TAnimator;
  LTarget: Double;
begin
  FillChar(LAnim, SizeOf(LAnim), 0);
  LTarget := 0;
  LAnim.Start(@LTarget, 0, 100, 1000, @EaseInQuad);
  LAnim.Tick(100);
  LAnim.Tick(600);
  Check(LTarget = 25, 'EaseInQuad at 50% should give 25');
end;

procedure TestAnimatorCancel;
var
  LAnim: TAnimator;
  LTarget: Double;
  LId: Integer;
begin
  FillChar(LAnim, SizeOf(LAnim), 0);
  LTarget := 0;
  LId := LAnim.Start(@LTarget, 0, 100, 1000, @EaseLinear);
  LAnim.Cancel(LId);
  Check(not LAnim.AnyRunning, 'Should not be running after cancel');
  Check(LAnim.RunningCount = 0, 'RunningCount should be 0');
end;

procedure TestAnimatorCancelTarget;
var
  LAnim: TAnimator;
  LTarget: Double;
begin
  FillChar(LAnim, SizeOf(LAnim), 0);
  LTarget := 0;
  LAnim.Start(@LTarget, 0, 100, 1000, @EaseLinear);
  LAnim.CancelTarget(@LTarget);
  Check(not LAnim.AnyRunning, 'Should not be running after CancelTarget');
end;

procedure TestAnimatorMultipleTargets;
var
  LAnim: TAnimator;
  LTarget1, LTarget2: Double;
begin
  FillChar(LAnim, SizeOf(LAnim), 0);
  LTarget1 := 0;
  LTarget2 := 0;
  LAnim.Start(@LTarget1, 0, 100, 1000, @EaseLinear);
  LAnim.Start(@LTarget2, 0, 200, 1000, @EaseLinear);
  Check(LAnim.RunningCount = 2, 'Should have 2 running animations');
  LAnim.Tick(100);
  LAnim.Tick(600);
  Check(LTarget1 = 50, 'Target1 at 50% should be 50');
  Check(LTarget2 = 100, 'Target2 at 50% should be 100');
end;

procedure TestAnimatorRestartTarget;
var
  LAnim: TAnimator;
  LTarget: Double;
begin
  FillChar(LAnim, SizeOf(LAnim), 0);
  LTarget := 0;
  LAnim.Start(@LTarget, 0, 100, 1000, @EaseLinear);
  LAnim.Tick(100);
  LAnim.Tick(1100);
  Check(LTarget = 100, 'First animation should complete');
  LAnim.Start(@LTarget, 100, 0, 1000, @EaseLinear);
  Check(LAnim.RunningCount = 1, 'Should have 1 running after restart');
  LAnim.Tick(1200);
  LAnim.Tick(2200);
  Check(LTarget = 0, 'Second animation should complete');
end;

procedure TestAnimatorCancelInvalidId;
var
  LAnim: TAnimator;
  LTarget: Double;
begin
  FillChar(LAnim, SizeOf(LAnim), 0);
  LTarget := 0;
  LAnim.Start(@LTarget, 0, 100, 1000, @EaseLinear);
  LAnim.Cancel(-1);
  LAnim.Cancel(100);
  Check(LAnim.AnyRunning, 'Should still be running after invalid cancel');
end;

procedure TestAnimatorTickClamp;
var
  LAnim: TAnimator;
  LTarget: Double;
begin
  FillChar(LAnim, SizeOf(LAnim), 0);
  LTarget := 0;
  LAnim.Start(@LTarget, 0, 100, 1000, @EaseLinear);
  LAnim.Tick(100);
  LAnim.Tick(3000);
  Check(LTarget = 100, 'Value should clamp to EndVal');
end;

procedure TestEasingFunctions;
begin
  CheckEqual(0.0, EaseLinear(0), 1e-10);
  CheckEqual(1.0, EaseLinear(1), 1e-10);
  CheckEqual(0.25, EaseInQuad(0.5), 1e-10);
  CheckEqual(0.75, EaseOutQuad(0.5), 1e-10);
  CheckEqual(0.0, EaseInOutQuad(0), 1e-10);
  CheckEqual(1.0, EaseInOutQuad(1), 1e-10);
  CheckEqual(0.0, EaseOutCubic(0), 1e-10);
  CheckEqual(1.0, EaseOutCubic(1), 1e-10);
  CheckEqual(0.0, EaseInOutCubic(0), 1e-10);
  CheckEqual(1.0, EaseInOutCubic(1), 1e-10);
  CheckEqual(0.0, EaseOutBack(0), 1e-6);
  CheckEqual(1.0, EaseOutBack(1), 1e-6);
  CheckEqual(0.0, EaseOutBounce(0), 1e-6);
  CheckEqual(1.0, EaseOutBounce(1), 1e-6);
  CheckEqual(0.0, EaseSpring(0), 1e-6);
end;

begin
  T := TTestSuite.Create('tui_animator');
  T.Test('TAnimator.Start', @TestAnimatorStart);
  T.Test('TAnimator.Tick', @TestAnimatorTick);
  T.Test('TAnimator.Tick with easing', @TestAnimatorTickEasing);
  T.Test('TAnimator.Cancel', @TestAnimatorCancel);
  T.Test('TAnimator.CancelTarget', @TestAnimatorCancelTarget);
  T.Test('TAnimator multiple targets', @TestAnimatorMultipleTargets);
  T.Test('TAnimator restart target', @TestAnimatorRestartTarget);
  T.Test('TAnimator.Cancel invalid id', @TestAnimatorCancelInvalidId);
  T.Test('TAnimator.Tick clamps', @TestAnimatorTickClamp);
  T.Test('Easing functions', @TestEasingFunctions);
  if not T.Run then Halt(1);
end.
