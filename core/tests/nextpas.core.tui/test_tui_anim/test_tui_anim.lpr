program test_tui_anim;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.tui.anim,
  nextpas.core.test;

var
  T: TTestSuite;

procedure TestEaseLinear;
begin
  Check(EaseLinear(0) = 0, 'EaseLinear(0) should be 0');
  Check(EaseLinear(0.5) = 0.5, 'EaseLinear(0.5) should be 0.5');
  Check(EaseLinear(1) = 1, 'EaseLinear(1) should be 1');
end;

procedure TestEaseInQuad;
begin
  Check(EaseInQuad(0) = 0, 'EaseInQuad(0) should be 0');
  Check(EaseInQuad(0.5) = 0.25, 'EaseInQuad(0.5) should be 0.25');
  Check(EaseInQuad(1) = 1, 'EaseInQuad(1) should be 1');
end;

procedure TestEaseOutQuad;
begin
  Check(EaseOutQuad(0) = 0, 'EaseOutQuad(0) should be 0');
  Check(EaseOutQuad(1) = 1, 'EaseOutQuad(1) should be 1');
end;

procedure TestEaseInOutQuad;
begin
  Check(EaseInOutQuad(0) = 0, 'EaseInOutQuad(0) should be 0');
  Check(EaseInOutQuad(0.5) = 0.5, 'EaseInOutQuad(0.5) should be 0.5');
  Check(EaseInOutQuad(1) = 1, 'EaseInOutQuad(1) should be 1');
end;

procedure TestEaseInCubic;
begin
  Check(EaseInCubic(0) = 0, 'EaseInCubic(0) should be 0');
  Check(EaseInCubic(1) = 1, 'EaseInCubic(1) should be 1');
end;

procedure TestEaseOutCubic;
begin
  Check(EaseOutCubic(0) = 0, 'EaseOutCubic(0) should be 0');
  Check(EaseOutCubic(1) = 1, 'EaseOutCubic(1) should be 1');
end;

procedure TestEaseInOutCubic;
begin
  Check(EaseInOutCubic(0) = 0, 'EaseInOutCubic(0) should be 0');
  Check(EaseInOutCubic(0.5) = 0.5, 'EaseInOutCubic(0.5) should be 0.5');
  Check(EaseInOutCubic(1) = 1, 'EaseInOutCubic(1) should be 1');
end;

procedure TestEaseBounce;
begin
  Check(EaseBounce(0) = 0, 'EaseBounce(0) should be 0');
  CheckEqual(1.0, EaseBounce(1), 1e-6);
end;

procedure TestLerp;
begin
  Check(Lerp(0, 100, 0) = 0, 'Lerp(0, 100, 0) should be 0');
  Check(Lerp(0, 100, 1) = 100, 'Lerp(0, 100, 1) should be 100');
  Check(Lerp(0, 100, 0.5) = 50, 'Lerp(0, 100, 0.5) should be 50');
end;

procedure TestLerpF;
begin
  Check(LerpF(0, 100, 0) = 0, 'LerpF(0, 100, 0) should be 0');
  Check(LerpF(0, 100, 1) = 100, 'LerpF(0, 100, 1) should be 100');
  Check(LerpF(0, 100, 0.5) = 50, 'LerpF(0, 100, 0.5) should be 50');
end;

procedure TestSpinnerCreateDots;
var
  LSpinner: TSpinner;
begin
  LSpinner := TSpinner.Create(skDots);
  Check(Length(LSpinner.Frames) = 10, 'Dots spinner should have 10 frames');
  Check(LSpinner.IntervalMs = 80, 'Dots interval should be 80');
end;

procedure TestSpinnerCreateLine;
var
  LSpinner: TSpinner;
begin
  LSpinner := TSpinner.Create(skLine);
  Check(Length(LSpinner.Frames) = 4, 'Line spinner should have 4 frames');
  Check(LSpinner.IntervalMs = 130, 'Line interval should be 130');
end;

procedure TestSpinnerCreateBraille;
var
  LSpinner: TSpinner;
begin
  LSpinner := TSpinner.Create(skBraille);
  Check(Length(LSpinner.Frames) = 8, 'Braille spinner should have 8 frames');
end;

procedure TestSpinnerCreateMoon;
var
  LSpinner: TSpinner;
begin
  LSpinner := TSpinner.Create(skMoon);
  Check(Length(LSpinner.Frames) = 8, 'Moon spinner should have 8 frames');
  Check(LSpinner.IntervalMs = 150, 'Moon interval should be 150');
end;

procedure TestSpinnerCreateArrow;
var
  LSpinner: TSpinner;
begin
  LSpinner := TSpinner.Create(skArrow);
  Check(Length(LSpinner.Frames) = 8, 'Arrow spinner should have 8 frames');
end;

procedure TestSpinnerCustom;
var
  LSpinner: TSpinner;
begin
  LSpinner := TSpinner.Custom(['-', '\\', '|', '/'], 100);
  Check(Length(LSpinner.Frames) = 4, 'Custom spinner should have 4 frames');
  Check(LSpinner.IntervalMs = 100, 'Custom interval should be 100');
end;

procedure TestSpinnerFrame;
var
  LSpinner: TSpinner;
begin
  LSpinner := TSpinner.Create(skLine);
  Check(LSpinner.Frame(0) = '|', 'Frame 0 should be |');
  Check(LSpinner.Frame(1) = '/', 'Frame 1 should be /');
  Check(LSpinner.Frame(2) = '-', 'Frame 2 should be -');
  Check(LSpinner.Frame(3) = '\', 'Frame 3 should be \');
  Check(LSpinner.Frame(4) = '|', 'Frame 4 should wrap to |');
end;

procedure TestSpinnerFrameNegative;
var
  LSpinner: TSpinner;
begin
  LSpinner := TSpinner.Create(skLine);
  Check(LSpinner.Frame(-1) = '\', 'Frame -1 should wrap to \');
end;

procedure TestSpinnerIsAnimating;
var
  LSpinner: TSpinner;
begin
  LSpinner := TSpinner.Create(skDots);
  Check(LSpinner.IsAnimating, 'Multi-frame spinner should be animating');
end;

procedure TestTransitionCreate;
var
  LTrans: TTransition;
begin
  LTrans := TTransition.Create(0, 100, 1000);
  Check(LTrans.StartVal = 0, 'StartVal should be 0');
  Check(LTrans.EndVal = 100, 'EndVal should be 100');
  Check(LTrans.DurationMs = 1000, 'DurationMs should be 1000');
  Check(LTrans.ElapsedMs = 0, 'ElapsedMs should be 0');
end;

procedure TestTransitionValue;
var
  LTrans: TTransition;
begin
  LTrans := TTransition.Create(0, 100, 1000);
  Check(LTrans.Value = 0, 'Initial value should be 0');
  LTrans.Advance(500);
  Check(LTrans.Value = 50, 'Value at 50% should be 50');
  LTrans.Advance(500);
  Check(LTrans.Value = 100, 'Value at 100% should be 100');
end;

procedure TestTransitionDone;
var
  LTrans: TTransition;
begin
  LTrans := TTransition.Create(0, 100, 1000);
  Check(not LTrans.Done, 'Should not be done initially');
  LTrans.Advance(1000);
  Check(LTrans.Done, 'Should be done after full duration');
end;

procedure TestTransitionAdvanceClamp;
var
  LTrans: TTransition;
begin
  LTrans := TTransition.Create(0, 100, 1000);
  LTrans.Advance(1500);
  Check(LTrans.ElapsedMs = 1000, 'ElapsedMs should clamp to DurationMs');
  Check(LTrans.Value = 100, 'Value should clamp to EndVal');
end;

procedure TestTransitionReset;
var
  LTrans: TTransition;
begin
  LTrans := TTransition.Create(0, 100, 1000);
  LTrans.Advance(500);
  LTrans.Reset;
  Check(LTrans.ElapsedMs = 0, 'Reset should clear ElapsedMs');
  Check(LTrans.Value = 0, 'Reset should reset value');
  Check(not LTrans.Done, 'Reset should clear Done');
end;

procedure TestTransitionWithEasing;
var
  LTrans: TTransition;
begin
  LTrans := TTransition.Create(0, 100, 1000).WithEasing(@EaseInQuad);
  LTrans.Advance(500);
  Check(LTrans.Value = 25, 'EaseInQuad at 50% should give 25');
end;

procedure TestTransitionZeroDuration;
var
  LTrans: TTransition;
begin
  LTrans := TTransition.Create(0, 100, 0);
  Check(LTrans.Value = 100, 'Zero duration should return EndVal');
  Check(LTrans.Done, 'Zero duration should be done');
end;

begin
  T := TTestSuite.Create('tui_anim');
  T.Test('EaseLinear', @TestEaseLinear);
  T.Test('EaseInQuad', @TestEaseInQuad);
  T.Test('EaseOutQuad', @TestEaseOutQuad);
  T.Test('EaseInOutQuad', @TestEaseInOutQuad);
  T.Test('EaseInCubic', @TestEaseInCubic);
  T.Test('EaseOutCubic', @TestEaseOutCubic);
  T.Test('EaseInOutCubic', @TestEaseInOutCubic);
  T.Test('EaseBounce', @TestEaseBounce);
  T.Test('Lerp', @TestLerp);
  T.Test('LerpF', @TestLerpF);
  T.Test('TSpinner.Create dots', @TestSpinnerCreateDots);
  T.Test('TSpinner.Create line', @TestSpinnerCreateLine);
  T.Test('TSpinner.Create braille', @TestSpinnerCreateBraille);
  T.Test('TSpinner.Create moon', @TestSpinnerCreateMoon);
  T.Test('TSpinner.Create arrow', @TestSpinnerCreateArrow);
  T.Test('TSpinner.Custom', @TestSpinnerCustom);
  T.Test('TSpinner.Frame', @TestSpinnerFrame);
  T.Test('TSpinner.Frame negative', @TestSpinnerFrameNegative);
  T.Test('TSpinner.IsAnimating', @TestSpinnerIsAnimating);
  T.Test('TTransition.Create', @TestTransitionCreate);
  T.Test('TTransition.Value', @TestTransitionValue);
  T.Test('TTransition.Done', @TestTransitionDone);
  T.Test('TTransition.Advance clamps', @TestTransitionAdvanceClamp);
  T.Test('TTransition.Reset', @TestTransitionReset);
  T.Test('TTransition.WithEasing', @TestTransitionWithEasing);
  T.Test('TTransition zero duration', @TestTransitionZeroDuration);
  if not T.Run then Halt(1);
end.
