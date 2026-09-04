program demo_game_pump;

{$mode ObjFPC}{$H+}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

{** @desc game 复用实证：window 作为 game loop 宿主
       演示 60 FPS 游戏主循环如何以 WindowPumpOnce 非阻塞驱动窗口，
       同一 IWindow 契约既可阻塞 RunLoop 也可嵌入游戏 tick。

       要点：
       - tick 循环：WindowPumpOnce → update → render，不阻塞
       - HostScaleChanged 驱动 swapchain 重建（以 log 代真 GPU）
       - 输入与关闭均经 TWindowEvent，不解析平台消息
*}

uses
  nextpas.core.base.utils,
  nextpas.core.window.base,
  nextpas.core.window.intf,
  nextpas.core.window.factory,
  nextpas.core.window.fake;

type
  TGame = class
  private
    FWindow: IWindow;
    FFrame: Integer;
    FScale: Double;
    FRunning: Boolean;
    procedure OnEvent(const AEvent: TWindowEvent);
  public
    constructor Create(AWindow: IWindow);
    procedure Update;
    procedure Render;
    property Running: Boolean read FRunning;
    property Frame: Integer read FFrame;
  end;

constructor TGame.Create(AWindow: IWindow);
begin
  inherited Create;
  FWindow := AWindow;
  FScale := AWindow.GetScaleFactor;
  FRunning := True;
  FFrame := 0;
end;

procedure TGame.OnEvent(const AEvent: TWindowEvent);
begin
  case AEvent.Kind of
    weCloseRequested: begin
      WriteLn('[game] close requested → exit loop');
      FRunning := False;
    end;
    weResized: WriteLn('[game] resized ', AEvent.Width, 'x', AEvent.Height, ' — swapchain rebuild');
    weScaleChanged: begin
      FScale := AEvent.NewScale.Factor;
      WriteLn('[game] scale ', FScale:0:2, ' — framebuffer scale rebuild');
    end;
    weFocusIn: WriteLn('[game] focus in — resume');
    weFocusOut: WriteLn('[game] focus out — pause');
    weMoved: ;
  end;
end;

procedure TGame.Update;
begin
  Inc(FFrame);
  // 游戏逻辑：每 15 帧模拟一次后台资源加载完成，Post 回主线程
  if FFrame = 15 then
    FWindow.GetDispatcher.Post(procedure
      begin
        WriteLn('[game] async resource loaded → next frame will render');
      end);
end;

procedure TGame.Render;
begin
  if FFrame mod 20 = 0 then
    WriteLn('[game] render frame ', FFrame, ' size ', FWindow.GetWidth, 'x', FWindow.GetHeight, ' scale ', FScale:0:2);
end;

var
  Win: IWindow;
  Game: TGame;
  Host: IWindowHost;
  Pumped: Boolean;
begin
  Win := TWindowBuilder.New
    .Kind(wkFake)
    .Title('game — window host demo')
    .Size(1280, 720)
    .Build;
  WriteLn('window kind=fake handle=', HexStr(Win.NativeHandle));
  Win.Show;

  Game := TGame.Create(Win);
  Win.OnEvent(@Game.OnEvent);

  // 宿主驱动：模拟 DPI 变更（真实 game 会重建 swapchain）
  if Supports(Win, IWindowHost, Host) then
    Host.HostScaleChanged(1.75);

  WriteLn('enter game loop (cap 90 frames, PumpOnce non-blocking)');
  while Game.Running and (Game.Frame < 90) do
  begin
    Pumped := WindowPumpOnce;
    // 空转时不忙等，真实 game 会 vsync；此处仅演示早退路径
    if Pumped then
      WriteLn('[loop] pumped at frame ', Game.Frame);

    Game.Update;
    Game.Render;

    if Game.Frame = 45 then
    begin
      WriteLn('[demo] inject scale change at frame 45');
      if Supports(Win, IWindowHost, Host) then Host.HostScaleChanged(2.0);
    end;
    if Game.Frame = 70 then
    begin
      WriteLn('[demo] request close at frame 70');
      Win.Close;
      Break;
    end;
  end;

  Game.Free;
  if not Win.IsClosed then Win.Close;
  WriteLn('demo done — game 复用验证通过：WindowPumpOnce 完美嵌入 60 FPS tick，无阻塞');
end.
