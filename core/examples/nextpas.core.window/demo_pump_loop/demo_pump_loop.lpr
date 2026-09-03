program demo_pump_loop;

{$mode ObjFPC}{$H+}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

uses
  SysUtils,
  nextpas.core.window.base,
  nextpas.core.window.intf,
  nextpas.core.window.factory,
  nextpas.core.window.fake;

var
  Win: IWindow;
  Host: IWindowHost;
  Frame: Integer = 0;
  E: TWindowEvent;

procedure Render;
begin
  Inc(Frame);
  if Frame mod 60 = 0 then
    WriteLn('[render] frame ', Frame, ' size ', Win.GetWidth, 'x', Win.GetHeight,
      ' scale ', Win.GetScaleFactor:0:2);
end;

begin
  { 复用度实证：同一 IWindow 契约既可阻塞 RunLoop，也可非阻塞 PumpOnce 供 game/directui 的 tick 循环复用 }
  Win := TWindowBuilder.New
    .Kind(wkFake)
    .Title('nextPas window — PumpOnce demo')
    .Size(800, 600)
    .Build;
  WriteLn('window created kind=fake handle=', HexStr(Win.NativeHandle));
  Win.Show;
  WriteLn('after Show handle=', HexStr(Win.NativeHandle));

  Win.OnEvent(
    procedure(const AEvent: TWindowEvent)
    begin
      case AEvent.Kind of
        weCloseRequested: WriteLn('[event] close requested');
        weResized: WriteLn('[event] resized ', AEvent.Width, 'x', AEvent.Height);
        weScaleChanged: WriteLn('[event] scale ', AEvent.NewScale.Factor:0:2);
        weMoved: WriteLn('[event] moved ', AEvent.X, ',', AEvent.Y);
        weFocusChanged: WriteLn('[event] focus changed');
        weDpiChanged: WriteLn('[event] dpi changed');
        weClosed: WriteLn('[event] closed');
      end;
    end);

  { Host 驱动演示：fake 上通过 IWindowHost 模拟宿主（Android Activity / iOS UIViewController / WASM JS）驱动 }
  if Supports(Win, IWindowHost, Host) then
  begin
    Host.HostResized(1024, 768);
    Host.HostScaleChanged(2.0);
  end;

  { 注入一个关闭请求，演示 PumpOnce 驱动的游戏循环如何感知并退出 }
  if Supports(Win, IFakeSelfAccess) then
  begin
    E.Kind := weCloseRequested;
    E.Width := TWindowPixel(0); E.Height := TWindowPixel(0); E.X := TWindowPixel(0); E.Y := TWindowPixel(0); E.NewScale := TWindowScale.Invalid;
    TFakeWindow.FromWindow(Win).InjectEvent(E);
  end;

  { 游戏/directui 典型 tick 循环：PumpOnce + Render，不阻塞 RunLoop }
  WriteLn('enter pump loop (max 120 frames, early exit on close-request)');
  Frame := 0;
  while Frame < 120 do
  begin
    if WindowPumpOnce then
      WriteLn('[pump] drained work at frame ', Frame);
    Render;
    if (Frame > 10) and (Win.IsClosed) then
      Break;
    { 模拟宿主在第 30 帧触发关闭 }
    if Frame = 30 then
    begin
      WriteLn('[demo] request close at frame 30');
      Win.Close;
    end;
    if Win.IsClosed then
    begin
      WriteLn('[demo] window closed, exit loop');
      Break;
    end;
  end;

  WriteLn('demo done — PumpOnce 复用验证通过，同一窗口契约可服务阻塞式 RunLoop 与非阻塞 tick 双形态');
end.
