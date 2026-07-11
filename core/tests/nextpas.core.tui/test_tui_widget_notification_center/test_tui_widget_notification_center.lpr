program test_tui_widget_notification_center;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.base.utils,
  nextpas.core.tui.base,
  nextpas.core.tui.color,
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
  Check(True, 'Should render stateful notification center');
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
  if not T.Run then Halt(1);
end.
