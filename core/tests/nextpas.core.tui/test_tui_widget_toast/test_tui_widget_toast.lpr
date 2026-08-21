program test_tui_widget_toast;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.tui.base,
  nextpas.core.tui.color,
  nextpas.core.tui.modifier,
  nextpas.core.tui.style,
  nextpas.core.tui.cell,
  nextpas.core.tui.buffer,
  nextpas.core.tui.widget.intf,
  nextpas.core.tui.widget.toast,
  nextpas.core.test;

var
  T: TTestSuite;

procedure TestToastPositionEnum;
begin
  Check(Ord(tpTopRight) = 0, 'tpTopRight should be 0');
  Check(Ord(tpBottomRight) = 1, 'tpBottomRight should be 1');
  Check(Ord(tpTopCenter) = 2, 'tpTopCenter should be 2');
  Check(Ord(tpBottomCenter) = 3, 'tpBottomCenter should be 3');
end;

procedure TestToastLevelEnum;
begin
  Check(Ord(tlInfo) = 0, 'tlInfo should be 0');
  Check(Ord(tlSuccess) = 1, 'tlSuccess should be 1');
  Check(Ord(tlWarning) = 2, 'tlWarning should be 2');
  Check(Ord(tlError) = 3, 'tlError should be 3');
end;

procedure TestToastItemRecord;
var
  LItem: TToastItem;
begin
  LItem.Message := 'Test message';
  LItem.Level := tlInfo;
  LItem.RemainingMs := 3000;
  Check(LItem.Message = 'Test message', 'Message should be Test message');
  Check(LItem.Level = tlInfo, 'Level should be tlInfo');
  Check(LItem.RemainingMs = 3000, 'RemainingMs should be 3000');
end;

procedure TestToastManagerNew;
var
  LManager: IToastManager;
begin
  LManager := TToastManager.New;
  Check(LManager <> nil, 'New toast manager should not be nil');
  Check(LManager.Count = 0, 'Initial count should be 0');
  Check(LManager.Visible = 0, 'Initial visible should be 0');
end;

procedure TestToastManagerPush;
var
  LManager: IToastManager;
begin
  LManager := TToastManager.New;
  LManager.Push('Test message', tlInfo);
  Check(LManager.Count = 1, 'Count should be 1 after push');
end;

procedure TestToastManagerPushMultiple;
var
  LManager: IToastManager;
begin
  LManager := TToastManager.New;
  LManager.Push('Message 1', tlInfo);
  LManager.Push('Message 2', tlSuccess);
  LManager.Push('Message 3', tlWarning);
  Check(LManager.Count = 3, 'Count should be 3 after 3 pushes');
end;

procedure TestToastManagerTick;
var
  LManager: IToastManager;
begin
  LManager := TToastManager.New;
  LManager.Push('Test', tlInfo);
  Check(LManager.Count = 1, 'Count should be 1 before tick');
  LManager.Tick(4000);
  Check(LManager.Count = 0, 'Count should be 0 after tick past duration');
end;

procedure TestToastManagerTickPartial;
var
  LManager: IToastManager;
begin
  LManager := TToastManager.New;
  LManager.Push('Test', tlInfo);
  LManager.Tick(1000);
  Check(LManager.Count = 1, 'Count should be 1 after partial tick');
end;

procedure TestToastManagerRender;
var
  LManager: IToastManager;
  LBuffer: TBuffer;
  LArea: TRect;
begin
  LManager := TToastManager.New;
  LManager.Push('Test message', tlInfo);
  LArea := TRect.Make(0, 0, 40, 10);
  LBuffer := TBuffer.CreateEmpty(LArea);
  try
    LManager.Render(LArea, LBuffer);
    Check(True, 'Render should not raise exception');
  finally
    LBuffer.Free;
  end;
end;

procedure TestToastManagerRenderEmpty;
var
  LManager: IToastManager;
  LBuffer: TBuffer;
  LArea: TRect;
begin
  LManager := TToastManager.New;
  LArea := TRect.Make(0, 0, 40, 10);
  LBuffer := TBuffer.CreateEmpty(LArea);
  try
    LManager.Render(LArea, LBuffer);
    Check(True, 'Render empty should not raise exception');
  finally
    LBuffer.Free;
  end;
end;

procedure TestToastManagerVisibleCount;
var
  LManager: IToastManager;
begin
  LManager := TToastManager.New;
  LManager.Push('Msg 1', tlInfo);
  LManager.Push('Msg 2', tlSuccess);
  Check(LManager.Visible = 2, 'Visible should be 2');
  Check(LManager.Count = 2, 'Count should be 2');
end;

procedure TestToastManagerAllLevels;
var
  LManager: IToastManager;
begin
  LManager := TToastManager.New;
  LManager.Push('Info', tlInfo);
  LManager.Push('Success', tlSuccess);
  LManager.Push('Warning', tlWarning);
  LManager.Push('Error', tlError);
  Check(LManager.Count = 4, 'All 4 levels pushed');
end;

procedure TestToastManagerTickExactBoundary;
var
  LManager: IToastManager;
begin
  LManager := TToastManager.New;
  LManager.Push('Test', tlInfo);
  // Default duration is 3000ms
  LManager.Tick(3000);
  Check(LManager.Count = 0, 'Exact duration tick should remove toast');
end;

procedure TestToastManagerTickMultiplePartial;
var
  LManager: IToastManager;
begin
  LManager := TToastManager.New;
  LManager.Push('Test', tlInfo);
  LManager.Tick(1000);
  Check(LManager.Count = 1, 'Still alive after 1000ms');
  LManager.Tick(1000);
  Check(LManager.Count = 1, 'Still alive after 2000ms');
  LManager.Tick(1001);
  Check(LManager.Count = 0, 'Dead after 3001ms total');
end;

procedure TestToastManagerVisibleMax;
var
  LManager: IToastManager;
  I: Integer;
begin
  LManager := TToastManager.New;
  for I := 1 to 7 do
    LManager.Push('Msg', tlInfo);
  Check(LManager.Count = 7, 'Count should be 7');
  Check(LManager.Visible = 5, 'Visible capped at 5 (FMaxVisible)');
end;

procedure TestToastManagerRenderMultiple;
var
  LManager: IToastManager;
  LBuffer: TBuffer;
  LArea: TRect;
  LLines: TBufferLines;
begin
  LManager := TToastManager.New;
  LManager.Push('First toast', tlInfo);
  LManager.Push('Second toast', tlSuccess);
  LArea := TRect.Make(0, 0, 40, 10);
  LBuffer := TBuffer.CreateEmpty(LArea);
  try
    LManager.Render(LArea, LBuffer);
    LLines := LBuffer.AsLines;
    Check(Pos('First toast', LLines[0]) > 0, 'First toast visible');
    Check(Pos('Second toast', LLines[1]) > 0, 'Second toast visible');
  finally
    LBuffer.Free;
  end;
end;

{ PH33 P2：WithMaxVisible 配置生效 }
procedure TestToastManagerWithMaxVisible;
var
  LManager: IToastManager;
  I: Integer;
begin
  LManager := TToastManager.New.WithMaxVisible(3);
  for I := 1 to 5 do
    LManager.Push('Msg', tlInfo);
  Check(LManager.Count = 5, 'Count = 5 pushes');
  Check(LManager.Visible = 3, 'Visible capped at configured 3');
end;

{ PH33 P2：WithDuration 配置生效——1000ms 生命周期 }
procedure TestToastManagerWithDuration;
var
  LManager: IToastManager;
begin
  LManager := TToastManager.New.WithDuration(1000);
  LManager.Push('Short', tlInfo);
  LManager.Tick(999);
  Check(LManager.Count = 1, 'still alive at 999ms of configured 1000');
  LManager.Tick(1);
  Check(LManager.Count = 0, 'expired at configured 1000ms');
end;

begin
  T := TTestSuite.Create('nextpas.core.tui.widget.toast');
  T.Test('TToastPosition enum', @TestToastPositionEnum);
  T.Test('TToastLevel enum', @TestToastLevelEnum);
  T.Test('TToastItem record', @TestToastItemRecord);
  T.Test('TToastManager.New', @TestToastManagerNew);
  T.Test('TToastManager.Push', @TestToastManagerPush);
  T.Test('TToastManager.Push multiple', @TestToastManagerPushMultiple);
  T.Test('TToastManager.Tick', @TestToastManagerTick);
  T.Test('TToastManager.Tick partial', @TestToastManagerTickPartial);
  T.Test('TToastManager.Render', @TestToastManagerRender);
  T.Test('TToastManager.Render empty', @TestToastManagerRenderEmpty);
  T.Test('TToastManager.Visible count', @TestToastManagerVisibleCount);
  T.Test('TToastManager all levels', @TestToastManagerAllLevels);
  T.Test('TToastManager.Tick exact boundary', @TestToastManagerTickExactBoundary);
  T.Test('TToastManager.Tick multiple partial', @TestToastManagerTickMultiplePartial);
  T.Test('TToastManager.Visible max cap', @TestToastManagerVisibleMax);
  T.Test('TToastManager.WithMaxVisible (PH33 P2)', @TestToastManagerWithMaxVisible);
  T.Test('TToastManager.WithDuration (PH33 P2)', @TestToastManagerWithDuration);
  T.Test('TToastManager.Render multiple', @TestToastManagerRenderMultiple);
  if not T.Run then Halt(1);
end.
