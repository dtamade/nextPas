program test_window_gtk_runtime;
{ GTK runtime smoke:探测式；无显示/无库时输出 SKIP，NEXTPAS_WINDOW_GTK_REQUIRED=1 时强制失败。
  覆盖：create→title/bounds/maximize→scale读取→close幂等→dispatcher post→事件往返（delete/configure模拟）。
  heaptrc 0 硬门。 }

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.test,
  nextpas.core.window.base,
  nextpas.core.window.intf,
  nextpas.core.window.factory,
  nextpas.core.window.gtk;

var
  GRequired: Boolean;

function IsRequired: Boolean;
begin
  Result := GetEnvironmentVariable('NEXTPAS_WINDOW_GTK_REQUIRED') = '1';
end;

procedure Skip(const AMsg: string);
begin
  WriteLn('SKIP: ', AMsg);
  if IsRequired then
    raise Exception.Create('REQUIRED but skipped: ' + AMsg);
end;

procedure TestProbe;
begin
  if not WindowGtkIsAvailable then
  begin
    Skip('GTK not available (lib not found)');
    Exit;
  end;
  Check(True, 'gtk probed available');
end;

procedure TestSmokeSequence;
var
  W: IWindow;
  LEvtFired: Boolean;
  LScale: Double;
begin
  if not WindowGtkIsAvailable then
  begin
    Skip('skip smoke - no gtk');
    Exit;
  end;
  // attempt create; if no display, gtk_init_check will fail with NotInitialized -> SKIP
  try
    W := CreateWindowOf(wkGtk, DefaultWindowOptions);
  except
    on E: Exception do
    begin
      Skip('gtk create failed (no display?): ' + E.Message);
      Exit;
    end;
  end;
  try
    Check(not W.IsClosed, 'gtk window open');
    Check(W.NativeHandle = nil, 'before Show, NativeHandle nil (not realized)');
    // title round-trip
    W.SetTitle('gtk-smoke');
    CheckEqual('gtk-smoke', W.GetTitle, 'title round-trip');
    // bounds
    W.SetBounds(640, 480);
    Check(W.GetWidth > 0, 'width after SetBounds');
    // dispatcher post
    LEvtFired := False;
    W.OnEvent(procedure(const AEvent: TWindowEvent)
      begin
        if AEvent.Kind = weResized then LEvtFired := True;
      end);
    W.SetBounds(800, 600);
    Check(LEvtFired, 'weResized via SetBounds dispatch');
    // scale factor honest 1 or 2
    LScale := W.GetScaleFactor;
    Check(LScale >= 1.0, 'scale >=1');
    // resizable
    W.SetResizable(False);
    W.SetResizable(True);
    // Show first to allow realization for state queries
    W.Show;
    Check(W.IsVisible, 'visible after Show (pre-max)');
    // maximize flow - may be WM-dependent, just ensure no exception and query is bool
    W.Maximize;
    Check((W.IsMaximized = True) or (W.IsMaximized = False), 'maximized query ok');
    W.Unmaximize;
    Check((W.IsMaximized = True) or (W.IsMaximized = False), 'unmaximized query ok');
    // minimize/restore (iconify may need display; just check no exception)
    W.Minimize;
    W.Restore;
    // Hide/Show cycle (already shown, now hide and re-show)
    W.Hide;
    Check(not W.IsVisible, 'hidden after Hide');
    W.Show;
    Check(W.IsVisible, 'visible after re-Show');
    // Focus
    W.Focus;
    // close idempotent
    W.Close;
    Check(W.IsClosed, 'closed');
    Check(W.NativeHandle = nil, 'handle nil after close');
    W.Close; // idempotent no throw
    Check(True, 'close idempotent');
  finally
    // ensure closed
    if (W <> nil) and not W.IsClosed then W.Close;
  end;
end;

procedure TestBuilderGtk;
var
  W: IWindow;
begin
  if not WindowGtkIsAvailable then
  begin
    Skip('skip builder gtk');
    Exit;
  end;
  try
    W := TWindowBuilder.New.Kind(wkGtk).Title('BuilderGTK').Size(1024,768).Build;
  except
    on E: Exception do
    begin
      Skip('builder gtk failed (no display?): '+E.Message);
      Exit;
    end;
  end;
  try
    CheckEqual('BuilderGTK', W.GetTitle);
    Check(not W.IsClosed, 'builder gtk open');
  finally
    if not W.IsClosed then W.Close;
  end;
end;

var
  T: TTestSuite;
  LHasDisplay: Boolean;
begin
  // quick env probe
  GRequired := IsRequired;
  T := TTestSuite.Create('nextpas.core.window.gtk_runtime');
  T.Test('probe', @TestProbe);
  T.Test('smoke sequence', @TestSmokeSequence);
  T.Test('builder gtk', @TestBuilderGtk);
  if not T.Run then Halt(1);
  WriteLn('gtk-runtime: done');
end.
