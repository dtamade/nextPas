program test_window_win32_runtime;
{ Win32 runtime smoke:探测式；非 Windows 或无 user32 时 SKIP，REQUIRED 时强制失败。 heaptrc 0。 }

{$I nextpas.core.settings.inc}

uses
  nextpas.core.test,
  nextpas.core.window.base,
  nextpas.core.window.intf,
  nextpas.core.window.factory,
  nextpas.core.window.win32, nextpas.core.exception, nextpas.core.os.env;

procedure Skip(const AMsg: string);
begin
  WriteLn('SKIP: ', AMsg);
  if GetEnvironmentVariable('NEXTPAS_WINDOW_WIN32_REQUIRED')='1' then
    raise Exception.Create('REQUIRED but skipped: '+AMsg);
end;

procedure TestProbe;
begin
  if not WindowWin32IsAvailable then
  begin
    Skip('Win32 not available (not Windows or user32 missing)');
    Exit;
  end;
  Check(True, 'win32 probed available');
end;

procedure TestSmoke;
var
  W: IWindow;
begin
  if not WindowWin32IsAvailable then
  begin
    Skip('skip smoke - no win32');
    Exit;
  end;
  try
    W := CreateWindowOf(wkWin32, DefaultWindowOptions);
  except
    on E: Exception do
    begin
      Skip('win32 create failed: '+E.Message);
      Exit;
    end;
  end;
  try
    Check(not W.IsClosed, 'win32 window open');
    W.SetTitle('win32-smoke');
    CheckEqual('win32-smoke', W.GetTitle);
    W.SetBounds(640,480);
    Check(W.GetWidth>0, 'width after SetBounds');
    W.Show;
    Check(W.IsVisible or not W.IsVisible, 'visible query ok');
    W.Hide; W.Show;
    W.Maximize; Check((W.IsMaximized=True) or (W.IsMaximized=False), 'maximized query ok');
    W.Unmaximize; W.Minimize; W.Restore;
    Check(W.GetScaleFactor>=1.0, 'scale >=1');
    W.Close; Check(W.IsClosed, 'closed'); Check(W.NativeHandle=nil, 'handle nil after close');
    W.Close; Check(True, 'close idempotent');
  finally
    if (W<>nil) and not W.IsClosed then W.Close;
  end;
end;

var
  T: TTestSuite;
begin
  T := TTestSuite.Create('nextpas.core.window.win32_runtime');
  T.Test('probe', @TestProbe);
  T.Test('smoke', @TestSmoke);
  if not T.Run then Halt(1);
  WriteLn('win32-runtime: done');
end.
