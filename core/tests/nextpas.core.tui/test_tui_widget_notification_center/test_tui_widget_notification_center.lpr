program test_tui_widget_notification_center;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.base.utils,
  nextpas.core.tui.base,
  nextpas.core.tui.color,
  nextpas.core.tui.modifier,
  nextpas.core.tui.style,
  nextpas.core.tui.buffer,
  nextpas.core.tui.widget.notification_center,
  nextpas.core.test;

var
  T: TTestSuite;

procedure TestNotificationMake;
var
  LNotif: TNotification;
begin
  LNotif := TNotification.Make('New message', nlInfo);
  Check(LNotif.Title = 'New message', 'Should set title');
end;

procedure TestNotificationWithBody;
var
  LNotif: TNotification;
begin
  LNotif := TNotification.Make('Alert', nlWarning).WithBody('Check disk space');
  Check(LNotif.Body = 'Check disk space', 'Should set body');
end;

procedure TestNotificationWithTimestamp;
var
  LNotif: TNotification;
begin
  LNotif := TNotification.Make('Event', nlInfo).WithTimestamp('10:30');
  Check(LNotif.Timestamp = '10:30', 'Should set timestamp');
end;

procedure TestNotificationCenterNew;
var
  LCenter: INotificationCenter;
begin
  LCenter := TNotificationCenter.New;
  Check(LCenter <> nil, 'Should create notification center instance');
end;

procedure TestNotificationCenterPush;
var
  LCenter: INotificationCenter;
begin
  LCenter := TNotificationCenter.New;
  LCenter.Push(TNotification.Make('Msg 1', nlInfo));
  LCenter.Push(TNotification.Make('Msg 2', nlWarning));
  Check(True, 'Should push notifications');
end;

procedure TestNotificationCenterMarkRead;
var
  LCenter: INotificationCenter;
begin
  LCenter := TNotificationCenter.New;
  LCenter.Push(TNotification.Make('Msg', nlInfo));
  LCenter.MarkRead(0);
  Check(True, 'Should mark as read');
end;

procedure TestNotificationCenterMarkAllRead;
var
  LCenter: INotificationCenter;
begin
  LCenter := TNotificationCenter.New;
  LCenter.Push(TNotification.Make('Msg 1', nlInfo));
  LCenter.Push(TNotification.Make('Msg 2', nlInfo));
  LCenter.MarkAllRead;
  Check(True, 'Should mark all as read');
end;

procedure TestNotificationCenterClear;
var
  LCenter: INotificationCenter;
begin
  LCenter := TNotificationCenter.New;
  LCenter.Push(TNotification.Make('Msg', nlInfo));
  LCenter.Clear;
  Check(True, 'Should clear notifications');
end;

procedure TestNotificationCenterRender;
var
  LCenter: INotificationCenter;
  LBuf: TBuffer;
  LArea: TRect;
begin
  LCenter := TNotificationCenter.New;
  LCenter.Push(TNotification.Make('Test', nlInfo));
  LArea := TRect.Make(0, 0, 40, 10);
  LBuf := TBuffer.CreateEmpty(LArea);
  LCenter.Render(LArea, LBuf);
  LBuf.Free;   { PH33 P1：补 Free（原测试泄漏，HEAPTRC_GATE=1 下可见）}
  Check(True, 'Should render notification center');
end;

procedure TestNotificationCenterRenderStateful;
var
  LCenter: INotificationCenter;
  LState: TNotificationCenterState;
  LBuf: TBuffer;
  LArea: TRect;
begin
  LCenter := TNotificationCenter.New;
  LCenter.Push(TNotification.Make('Test', nlInfo));
  LState.Selected := 0;
  LState.ScrollY := 0;
  LState.Visible := True;
  LArea := TRect.Make(0, 0, 40, 10);
  LBuf := TBuffer.CreateEmpty(LArea);
  LCenter.RenderStateful(LArea, LBuf, LState);
  LBuf.Free;   { PH33 P1：补 Free（原测试泄漏，HEAPTRC_GATE=1 下可见）}
  Check(True, 'Should render stateful notification center');
end;

procedure TestNotificationCenterGetCount;
var
  LCenter: INotificationCenter;
begin
  LCenter := TNotificationCenter.New;
  Check(LCenter.GetCount = 0, 'Initial count should be 0');
  LCenter.Push(TNotification.Make('Msg 1', nlInfo));
  Check(LCenter.GetCount = 1, 'Count should be 1 after push');
  LCenter.Push(TNotification.Make('Msg 2', nlWarning));
  Check(LCenter.GetCount = 2, 'Count should be 2 after second push');
end;

procedure TestNotificationCenterUnreadCount;
var
  LCenter: INotificationCenter;
begin
  LCenter := TNotificationCenter.New;
  Check(LCenter.UnreadCount = 0, 'Initial unread should be 0');
  LCenter.Push(TNotification.Make('Msg 1', nlInfo));
  LCenter.Push(TNotification.Make('Msg 2', nlInfo));
  Check(LCenter.UnreadCount = 2, 'Both should be unread');
  LCenter.MarkRead(0);
  Check(LCenter.UnreadCount = 1, 'One unread after MarkRead(0)');
end;

procedure TestNotificationCenterMarkAllReadUnreadCount;
var
  LCenter: INotificationCenter;
begin
  LCenter := TNotificationCenter.New;
  LCenter.Push(TNotification.Make('Msg 1', nlInfo));
  LCenter.Push(TNotification.Make('Msg 2', nlInfo));
  LCenter.Push(TNotification.Make('Msg 3', nlInfo));
  LCenter.MarkAllRead;
  Check(LCenter.UnreadCount = 0, 'All read → unread = 0');
end;

procedure TestNotificationCenterGetItem;
var
  LCenter: INotificationCenter;
  LNotif: TNotification;
begin
  LCenter := TNotificationCenter.New;
  LCenter.Push(TNotification.Make('Title1', nlError).WithBody('Body1'));
  LNotif := LCenter.GetItem(0);
  Check(LNotif.Title = 'Title1', 'GetItem title should match');
  Check(LNotif.Body = 'Body1', 'GetItem body should match');
  Check(LNotif.Level = nlError, 'GetItem level should match');
  Check(not LNotif.Read, 'GetItem should be unread by default');
end;

procedure TestNotificationCenterClearResetsCount;
var
  LCenter: INotificationCenter;
begin
  LCenter := TNotificationCenter.New;
  LCenter.Push(TNotification.Make('Msg', nlInfo));
  LCenter.Push(TNotification.Make('Msg', nlInfo));
  LCenter.Clear;
  Check(LCenter.GetCount = 0, 'Clear should reset count to 0');
  Check(LCenter.UnreadCount = 0, 'Clear should reset unread to 0');
end;

procedure TestNotificationCenterMarkReadOutOfBounds;
var
  LCenter: INotificationCenter;
begin
  LCenter := TNotificationCenter.New;
  LCenter.Push(TNotification.Make('Msg', nlInfo));
  LCenter.MarkRead(-1);  // should not crash
  LCenter.MarkRead(5);   // should not crash
  Check(LCenter.UnreadCount = 1, 'Out of bounds MarkRead should not affect state');
end;

{ PH33 P1：极小区 sweep——PanelW<6 时 Inner.Width-4 曾 Word 下溢巨区写
  （PH29 dialog/command_palette 同款），修复后不崩溃不越界 }
procedure TestNotificationCenterTinyAreas;
var
  LCenter: INotificationCenter;
  LState: TNotificationCenterState;
  LBuf: TBuffer;
  LArea: TRect;
  LSizes: array[0..5, 0..1] of Integer = ((1,1),(2,3),(3,2),(4,4),(5,5),(6,3));
  LI: Integer;
begin
  LCenter := TNotificationCenter.New;
  LCenter.Push(TNotification.Make('A long notification title here', nlError));
  for LI := 0 to High(LSizes) do
  begin
    LArea := TRect.Make(0, 0, LSizes[LI,0], LSizes[LI,1]);
    LBuf := TBuffer.CreateEmpty(LArea);
    LState.Selected := 0; LState.ScrollY := 0; LState.Visible := True;
    LCenter.RenderStateful(LArea, LBuf, LState);
    LBuf.Free;
  end;
  Check(True, 'Tiny areas should render without crash or overflow');
end;

{ PH33 P2：WithWidth 生效——面板右缘贴 AArea 右缘，宽 12 时左缘在 X+48；
  标题行含边框角与标题文本 }
procedure TestNotificationCenterWithWidth;
var
  LCenter: INotificationCenter;
  LBuf: TBuffer;
  LArea: TRect;
  LRow: AnsiString;
begin
  LCenter := TNotificationCenter.New.WithWidth(12);
  LCenter.Push(TNotification.Make('N', nlInfo));
  LArea := TRect.Make(0, 0, 60, 8);
  LBuf := TBuffer.CreateEmpty(LArea);
  LCenter.Render(LArea, LBuf);
  LRow := LBuf.RowAsString(0);
  { 面板 [48..59]，边框角在 x=48（TBlock 默认 BorderSetPlain；RowAsString
    返回 UTF-8 字节流，'┌' 占 3 字节 → 字节位置 49）}
  Check(Pos('┌', LRow) = 49, 'Panel left edge at X+48 with WithWidth(12)');
  LBuf.Free;
end;

{ PH33 P2：样式配置链可用且渲染不崩 }
procedure TestNotificationCenterWithStyles;
var
  LCenter: INotificationCenter;
  LState: TNotificationCenterState;
  LBuf: TBuffer;
  LArea: TRect;
begin
  LCenter := TNotificationCenter.New
    .WithStyle(TStyle.Default)
    .WithSelectedStyle(TStyle.Default.WithModifier([mbReversed]))
    .WithUnreadStyle(TStyle.Default.WithModifier([mbBold]));
  LCenter.Push(TNotification.Make('Styled', nlSuccess));
  LArea := TRect.Make(0, 0, 40, 10);
  LBuf := TBuffer.CreateEmpty(LArea);
  LState.Selected := 0; LState.ScrollY := 0; LState.Visible := True;
  LCenter.RenderStateful(LArea, LBuf, LState);
  LBuf.Free;
  Check(True, 'Configured styles should render without crash');
end;

begin
  T := TTestSuite.Create('tui_widget_notification_center');
  T.Test('TNotification.Make', @TestNotificationMake);
  T.Test('TNotification.WithBody', @TestNotificationWithBody);
  T.Test('TNotification.WithTimestamp', @TestNotificationWithTimestamp);
  T.Test('TNotificationCenter.New creates instance', @TestNotificationCenterNew);
  T.Test('TNotificationCenter.Push', @TestNotificationCenterPush);
  T.Test('TNotificationCenter.MarkRead', @TestNotificationCenterMarkRead);
  T.Test('TNotificationCenter.MarkAllRead', @TestNotificationCenterMarkAllRead);
  T.Test('TNotificationCenter.Clear', @TestNotificationCenterClear);
  T.Test('TNotificationCenter.Render', @TestNotificationCenterRender);
  T.Test('TNotificationCenter.RenderStateful', @TestNotificationCenterRenderStateful);
  T.Test('TNotificationCenter.GetCount', @TestNotificationCenterGetCount);
  T.Test('TNotificationCenter.UnreadCount', @TestNotificationCenterUnreadCount);
  T.Test('TNotificationCenter.MarkAllRead resets unread', @TestNotificationCenterMarkAllReadUnreadCount);
  T.Test('TNotificationCenter.GetItem', @TestNotificationCenterGetItem);
  T.Test('TNotificationCenter.Clear resets count', @TestNotificationCenterClearResetsCount);
  T.Test('TNotificationCenter.MarkRead out of bounds', @TestNotificationCenterMarkReadOutOfBounds);
  T.Test('TNotificationCenter.TinyAreas (PH33 P1)', @TestNotificationCenterTinyAreas);
  T.Test('TNotificationCenter.WithWidth (PH33 P2)', @TestNotificationCenterWithWidth);
  T.Test('TNotificationCenter.WithStyles (PH33 P2)', @TestNotificationCenterWithStyles);
  if not T.Run then Halt(1);
end.
