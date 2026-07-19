program test_tui_frame_budget;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.tui.frame_budget,
  nextpas.core.test;

var
  T: TTestSuite;

procedure TestFrameStatsEmpty;
var
  LStats: TFrameStats;
begin
  LStats := TFrameStats.Empty;
  Check(LStats.FrameCount = 0, 'Empty FrameCount should be 0');
  Check(LStats.TotalMs = 0, 'Empty TotalMs should be 0');
  Check(LStats.LastMs = 0, 'Empty LastMs should be 0');
  Check(LStats.OverBudgetCount = 0, 'Empty OverBudgetCount should be 0');
end;

procedure TestFrameStatsAvgMsEmpty;
var
  LStats: TFrameStats;
begin
  LStats := TFrameStats.Empty;
  Check(LStats.AvgMs = 0, 'AvgMs with 0 frames should be 0');
end;

procedure TestFrameStatsOverBudgetPctEmpty;
var
  LStats: TFrameStats;
begin
  LStats := TFrameStats.Empty;
  Check(LStats.OverBudgetPct = 0, 'OverBudgetPct with 0 frames should be 0');
end;

procedure TestFrameStatsAvgMsCalc;
var
  LStats: TFrameStats;
begin
  LStats := TFrameStats.Empty;
  LStats.FrameCount := 4;
  LStats.TotalMs := 100;
  Check(LStats.AvgMs = 25, 'AvgMs should be TotalMs / FrameCount');
end;

procedure TestFrameStatsOverBudgetPctCalc;
var
  LStats: TFrameStats;
begin
  LStats := TFrameStats.Empty;
  LStats.FrameCount := 10;
  LStats.OverBudgetCount := 3;
  Check(LStats.OverBudgetPct = 30, 'OverBudgetPct should be 30%');
end;

procedure TestFrameBudgetCreate;
var
  LBudget: TFrameBudget;
begin
  LBudget := TFrameBudget.Create(20.0);
  Check(LBudget.BudgetMs = 20.0, 'BudgetMs should be set');
  Check(LBudget.DegradeAfterMs = 16.0, 'DegradeAfterMs should be 80% of budget');
  Check(LBudget.ShouldDegrade = False, 'ShouldDegrade should be False initially');
end;

procedure TestFrameBudgetWithDegradeThreshold;
var
  LBudget: TFrameBudget;
begin
  LBudget := TFrameBudget.Create(20.0);
  LBudget := LBudget.WithDegradeThreshold(10);
  Check(LBudget.DegradeAfterMs = 10, 'DegradeAfterMs should be overridden');
end;

procedure TestFrameBudgetReset;
var
  LBudget: TFrameBudget;
begin
  LBudget := TFrameBudget.Create(20.0);
  LBudget.Reset;
  Check(LBudget.Stats.FrameCount = 0, 'Reset FrameCount should be 0');
  Check(LBudget.Stats.TotalMs = 0, 'Reset TotalMs should be 0');
  Check(LBudget.ShouldDegrade = False, 'Reset ShouldDegrade should be False');
end;

procedure TestFrameBudgetBeginEndFrame;
var
  LBudget: TFrameBudget;
begin
  LBudget := TFrameBudget.Create(16.0);
  LBudget.BeginFrame;
  Check(LBudget.FrameStart > 0, 'BeginFrame should set FrameStart');
  LBudget.EndFrame;
  Check(LBudget.Stats.FrameCount = 1, 'EndFrame should increment FrameCount');
  Check(LBudget.Stats.LastMs >= 0, 'EndFrame should set LastMs');
end;

procedure TestFrameBudgetMultipleFrames;
var
  LBudget: TFrameBudget;
begin
  LBudget := TFrameBudget.Create(1000);
  LBudget.BeginFrame;
  LBudget.EndFrame;
  LBudget.BeginFrame;
  LBudget.EndFrame;
  LBudget.BeginFrame;
  LBudget.EndFrame;
  Check(LBudget.Stats.FrameCount = 3, 'Should track 3 frames');
end;

begin
  T := TTestSuite.Create('tui_frame_budget');
  T.Test('TFrameStats.Empty creates zero state', @TestFrameStatsEmpty);
  T.Test('TFrameStats.AvgMs with 0 frames', @TestFrameStatsAvgMsEmpty);
  T.Test('TFrameStats.OverBudgetPct with 0 frames', @TestFrameStatsOverBudgetPctEmpty);
  T.Test('TFrameStats.AvgMs calculation', @TestFrameStatsAvgMsCalc);
  T.Test('TFrameStats.OverBudgetPct calculation', @TestFrameStatsOverBudgetPctCalc);
  T.Test('TFrameBudget.Create sets budget', @TestFrameBudgetCreate);
  T.Test('TFrameBudget.WithDegradeThreshold', @TestFrameBudgetWithDegradeThreshold);
  T.Test('TFrameBudget.Reset', @TestFrameBudgetReset);
  T.Test('TFrameBudget.BeginFrame/EndFrame', @TestFrameBudgetBeginEndFrame);
  T.Test('TFrameBudget multiple frames', @TestFrameBudgetMultipleFrames);
  if not T.Run then Halt(1);
end.
