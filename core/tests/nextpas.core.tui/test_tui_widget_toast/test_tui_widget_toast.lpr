program test_tui_widget_toast;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
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
  if not T.Run then Halt(1);
end.
