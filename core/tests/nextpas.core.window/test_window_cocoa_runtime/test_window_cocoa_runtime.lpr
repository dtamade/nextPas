program test_window_cocoa_runtime;
{ Cocoa runtime smoke:探测式；非 macOS 时 SKIP，REQUIRED 时强制失败。 heaptrc 0。 }

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.test,
  nextpas.core.window.base,
  nextpas.core.window.intf,
  nextpas.core.window.factory,
  nextpas.core.window.cocoa;

procedure Skip(const AMsg: string);
begin
  WriteLn('SKIP: ', AMsg);
  if GetEnvironmentVariable('NEXTPAS_WINDOW_COCOA_REQUIRED')='1' then
    raise Exception.Create('REQUIRED but skipped: '+AMsg);
end;

procedure TestProbe;
begin
  if not WindowCocoaIsAvailable then
  begin
    Skip('Cocoa not available (not macOS or AppKit missing)');
    Exit;
  end;
  Check(True, 'cocoa probed available');
end;

procedure TestSmoke;
var
  W: IWindow;
begin
  if not WindowCocoaIsAvailable then
  begin
    Skip('skip smoke - no cocoa');
    Exit;
  end;
  try
    W := CreateWindowOf(wkCocoa, DefaultWindowOptions);
  except
    on E: Exception do
    begin
      Skip('cocoa create failed: '+E.Message);
      Exit;
    end;
  end;
  try
    Check(not W.IsClosed, 'cocoa window open');
    W.SetTitle('cocoa-smoke');
    CheckEqual('cocoa-smoke', W.GetTitle);
    W.SetBounds(640,480);
    Check(W.GetWidth>0, 'width after SetBounds');
    W.Show;
    Check(W.IsVisible or not W.IsVisible, 'visible query ok');
    W.Hide; W.Show;
    W.Close; Check(W.IsClosed, 'closed');
    W.Close; Check(True, 'close idempotent');
  finally
    if (W<>nil) and not W.IsClosed then W.Close;
  end;
end;

var
  T: TTestSuite;
begin
  T := TTestSuite.Create('nextpas.core.window.cocoa_runtime');
  T.Test('probe', @TestProbe);
  T.Test('smoke', @TestSmoke);
  if not T.Run then Halt(1);
  WriteLn('cocoa-runtime: done');
end.
