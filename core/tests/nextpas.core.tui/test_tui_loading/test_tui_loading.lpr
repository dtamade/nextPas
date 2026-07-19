program test_tui_loading;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.tui.task,
  nextpas.core.tui.loading,
  nextpas.core.test;

var
  T: TTestSuite;

procedure TestLoadingGroupEmpty;
var
  LGroup: TLoadingGroup;
begin
  LGroup := TLoadingGroup.Empty;
  Check(LGroup.Count = 0, 'Empty group should have Count 0');
end;

procedure TestLoadingGroupStart;
var
  LGroup: TLoadingGroup;
begin
  LGroup := TLoadingGroup.Empty;
  LGroup.Start(0, 1, 1000);
  Check(LGroup.Count = 1, 'Count should be 1 after Start');
  Check(LGroup.Items[0].TaskId = 1, 'TaskId should be 1');
  Check(LGroup.Items[0].Phase = lpLoading, 'Phase should be lpLoading');
  Check(LGroup.Items[0].StartMs = 1000, 'StartMs should be 1000');
end;

procedure TestLoadingGroupStartZeroTaskId;
var
  LGroup: TLoadingGroup;
begin
  LGroup := TLoadingGroup.Empty;
  LGroup.Start(0, 0, 1000);
  Check(LGroup.Items[0].Phase = lpError, 'Phase should be lpError for task rejected');
  Check(LGroup.Items[0].Error = 'task rejected', 'Error should be task rejected');
end;

procedure TestLoadingGroupStartMultiple;
var
  LGroup: TLoadingGroup;
begin
  LGroup := TLoadingGroup.Empty;
  LGroup.Start(0, 1, 1000);
  LGroup.Start(1, 2, 2000);
  LGroup.Start(2, 3, 3000);
  Check(LGroup.Count = 3, 'Count should be 3');
  Check(LGroup.Items[0].TaskId = 1, 'First task id');
  Check(LGroup.Items[1].TaskId = 2, 'Second task id');
  Check(LGroup.Items[2].TaskId = 3, 'Third task id');
end;

procedure TestLoadingGroupAllDoneEmpty;
var
  LGroup: TLoadingGroup;
begin
  LGroup := TLoadingGroup.Empty;
  Check(LGroup.AllDone, 'Empty group should be AllDone');
end;

procedure TestLoadingGroupAllDoneWithLoading;
var
  LGroup: TLoadingGroup;
begin
  LGroup := TLoadingGroup.Empty;
  LGroup.Start(0, 1, 1000);
  Check(not LGroup.AllDone, 'Should not be AllDone while loading');
end;

procedure TestLoadingGroupAnyLoading;
var
  LGroup: TLoadingGroup;
begin
  LGroup := TLoadingGroup.Empty;
  Check(not LGroup.AnyLoading, 'Empty group should not be AnyLoading');
  LGroup.Start(0, 1, 1000);
  Check(LGroup.AnyLoading, 'Should be AnyLoading after Start');
end;

procedure TestLoadingGroupAnyError;
var
  LGroup: TLoadingGroup;
begin
  LGroup := TLoadingGroup.Empty;
  Check(not LGroup.AnyError, 'Empty group should not be AnyError');
  LGroup.Start(0, 0, 1000);
  Check(LGroup.AnyError, 'Should be AnyError after failed task');
end;

procedure TestLoadingGroupGetPhase;
var
  LGroup: TLoadingGroup;
begin
  LGroup := TLoadingGroup.Empty;
  Check(LGroup.GetPhase(0) = lpIdle, 'Phase should be lpIdle before start');
  LGroup.Start(0, 1, 1000);
  Check(LGroup.GetPhase(0) = lpLoading, 'Phase should be lpLoading after start');
end;

procedure TestLoadingGroupGetPhaseOutOfBounds;
var
  LGroup: TLoadingGroup;
  LPhase: TLoadingPhase;
begin
  LGroup := TLoadingGroup.Empty;
  LPhase := LGroup.GetPhase(5);
  Check(LPhase = lpIdle, 'Out of bounds should return lpIdle');
end;

procedure TestLoadingGroupStartInvalidIndex;
var
  LGroup: TLoadingGroup;
begin
  LGroup := TLoadingGroup.Empty;
  LGroup.Start(-1, 1, 1000);
  Check(LGroup.Count = 0, 'Negative index should not change Count');
  LGroup.Start(16, 1, 1000);
  Check(LGroup.Count = 0, 'Index > 15 should not change Count');
end;

begin
  T := TTestSuite.Create('tui_loading');
  T.Test('TLoadingGroup.Empty creates empty group', @TestLoadingGroupEmpty);
  T.Test('TLoadingGroup.Start sets loading state', @TestLoadingGroupStart);
  T.Test('TLoadingGroup.Start with zero TaskId', @TestLoadingGroupStartZeroTaskId);
  T.Test('TLoadingGroup.Start multiple items', @TestLoadingGroupStartMultiple);
  T.Test('TLoadingGroup.AllDone with empty group', @TestLoadingGroupAllDoneEmpty);
  T.Test('TLoadingGroup.AllDone with loading item', @TestLoadingGroupAllDoneWithLoading);
  T.Test('TLoadingGroup.AnyLoading', @TestLoadingGroupAnyLoading);
  T.Test('TLoadingGroup.AnyError', @TestLoadingGroupAnyError);
  T.Test('TLoadingGroup.GetPhase', @TestLoadingGroupGetPhase);
  T.Test('TLoadingGroup.GetPhase out of bounds', @TestLoadingGroupGetPhaseOutOfBounds);
  T.Test('TLoadingGroup.Start invalid index', @TestLoadingGroupStartInvalidIndex);
  if not T.Run then Halt(1);
end.
