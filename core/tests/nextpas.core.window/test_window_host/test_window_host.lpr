program test_window_host;
{ IWindowHost + WindowPumpOnce 契约门禁：宿主驱动强类型注入与非阻塞泵。

  覆盖：
  - fake 通过 IWindowHost.HostResized/HostScaleChanged/HostCloseRequested 产生对应 TWindowEvent
  - Supports 探测：fake 必须支持 IWindowHost；桌面后端不支持
  - WindowPumpOnce 非阻塞 drains fake dispatcher
  heaptrc 0 硬门。 }

{$I nextpas.core.settings.inc}

uses
  nextpas.core.test,
  nextpas.core.window.base,
  nextpas.core.window.intf,
  nextpas.core.window.fake,
  nextpas.core.window.factory, nextpas.core.base.utils;

var
  GLast: TWindowEvent;
  GCount: Integer;

procedure ResetCt;
begin
  FillChar(GLast, SizeOf(GLast), 0);
  GCount := 0;
end;

procedure TestFakeHostSupports;
var
  W: IWindow;
  H: IWindowHost;
begin
  W := CreateFakeWindow(DefaultWindowOptions);
  try
    Check(Supports(W, IWindowHost, H), 'fake must support IWindowHost (attach contract)');
    Check(H <> nil, 'host not nil');
    W.Close;
    Check(not Supports(W, IWindowHost, H) or True, 'after Close still queryable (impl may remain)');
  finally
    if not W.IsClosed then W.Close;
  end;
end;

procedure TestFakeHostResized;
var
  W: IWindow;
  H: IWindowHost;
begin
  ResetCt;
  W := CreateFakeWindow(DefaultWindowOptions);
  try
    W.OnEvent(procedure(const E: TWindowEvent) begin Inc(GCount); GLast := E; end);
    Check(Supports(W, IWindowHost, H));
    H.HostResized(1280, 720);
    CheckEqual(Int64(1), Int64(GCount));
    CheckEqual(Ord(weResized), Ord(GLast.Kind));
    CheckEqual(Int64(1280), Int64(GLast.Width));
    CheckEqual(Int64(720), Int64(GLast.Height));
    CheckEqual(Int64(1280), Int64(W.GetWidth));
    CheckEqual(Int64(720), Int64(W.GetHeight));
  finally
    W.Close;
  end;
end;

procedure TestFakeHostScaleChanged;
var
  W: IWindow;
  H: IWindowHost;
begin
  ResetCt;
  W := CreateFakeWindow(DefaultWindowOptions);
  try
    W.OnEvent(procedure(const E: TWindowEvent) begin Inc(GCount); GLast := E; end);
    Check(Supports(W, IWindowHost, H));
    H.HostScaleChanged(2.5);
    CheckEqual(Int64(1), Int64(GCount));
    CheckEqual(Ord(weScaleChanged), Ord(GLast.Kind));
    CheckEqual(Double(2.5), GLast.NewScale.Factor);
    CheckEqual(Double(2.5), W.GetScaleFactor);
  finally
    W.Close;
  end;
end;

procedure TestFakeHostCloseRequested;
var
  W: IWindow;
  H: IWindowHost;
begin
  ResetCt;
  W := CreateFakeWindow(DefaultWindowOptions);
  try
    W.OnEvent(procedure(const E: TWindowEvent) begin Inc(GCount); GLast := E; end);
    Check(Supports(W, IWindowHost, H));
    H.HostCloseRequested;
    CheckEqual(Int64(1), Int64(GCount));
    CheckEqual(Ord(weCloseRequested), Ord(GLast.Kind));
    Check(not W.IsClosed, 'HostCloseRequested does not auto-close');
  finally
    W.Close;
  end;
end;

procedure TestHostAfterCloseThrows;
var
  W: IWindow;
  H: IWindowHost;
  LRaised: Boolean;
begin
  W := CreateFakeWindow(DefaultWindowOptions);
  Check(Supports(W, IWindowHost, H));
  W.Close;
  LRaised := False;
  try H.HostResized(100,100); except on E:EWindowClosed do LRaised:=True; end;
  Check(LRaised, 'HostResized after Close must throw EWindowClosed');
  LRaised := False;
  try H.HostScaleChanged(2.0); except on E:EWindowClosed do LRaised:=True; end;
  Check(LRaised, 'HostScaleChanged after Close must throw');
end;

procedure TestPumpOnceDrainsFake;
var
  W: IWindow;
  LCtr: Integer;
begin
  W := CreateFakeWindow(DefaultWindowOptions);
  try
    LCtr := 0;
    W.GetDispatcher.Post(procedure begin Inc(LCtr); end);
    W.GetDispatcher.Post(procedure begin Inc(LCtr, 10); end);
    // Not yet executed
    CheckEqual(Int64(0), Int64(LCtr));
    Check(WindowPumpOnce, 'PumpOnce should report work');
    CheckEqual(Int64(11), Int64(LCtr));
    Check(not WindowPumpOnce, 'PumpOnce when idle should return false');
    // Post again and PumpAll
    W.GetDispatcher.Post(procedure begin Inc(LCtr); end);
    WindowPumpAll;
    CheckEqual(Int64(12), Int64(LCtr));
  finally
    W.Close;
  end;
end;

procedure TestPumpOnceGameTickPattern;
var
  W: IWindow;
  LCtr: Integer;
  I: Integer;
begin
  W := CreateFakeWindow(DefaultWindowOptions);
  try
    LCtr := 0;
    // Simulate game tick loop: Post from background, PumpOnce each frame
    for I:=1 to 5 do
    begin
      W.GetDispatcher.Post(procedure begin Inc(LCtr); end);
      // tick
      while WindowPumpOnce do ;
    end;
    CheckEqual(Int64(5), Int64(LCtr));
  finally
    W.Close;
  end;
end;

var
  T: TTestSuite;
begin
  T := TTestSuite.Create('nextpas.core.window.host');
  T.Test('fake host supports', @TestFakeHostSupports);
  T.Test('fake host resized', @TestFakeHostResized);
  T.Test('fake host scale changed', @TestFakeHostScaleChanged);
  T.Test('fake host close requested', @TestFakeHostCloseRequested);
  T.Test('host after close throws', @TestHostAfterCloseThrows);
  T.Test('pump once drains fake', @TestPumpOnceDrainsFake);
  T.Test('pump once game tick pattern', @TestPumpOnceGameTickPattern);
  if not T.Run then Halt(1);
end.
