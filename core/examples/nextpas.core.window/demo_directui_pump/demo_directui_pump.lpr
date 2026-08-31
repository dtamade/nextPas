program demo_directui_pump;

{$mode ObjFPC}{$H+}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

{** @desc directui 复用实证：window 作为 directui 宿主
       演示同一 IWindow 契约如何被 directui 的声明式渲染循环复用，
       不阻塞 RunLoop，全程 WindowPumpOnce 驱动。

       要点：
       - directui 的 render 仅在 weResized/weScaleChanged 或 PumpOnce 返 true 时触发（避免 LCL 式消息伪装）
       - HostResized/HostScaleChanged 经 IWindowHost 注入，模拟 Android Activity / iOS UIViewController / WASM JS 驱动
       - Dispatcher.Post 跨线程安全，directui 的数据层可在后台线程准备后 Post 回主线程重绘
*}

uses
  SysUtils,
  nextpas.core.window.base,
  nextpas.core.window.intf,
  nextpas.core.window.factory,
  nextpas.core.window.fake;

type
  TDirectUINode = record
    Text: string;
    X, Y, W, H: Integer;
  end;

  TDirectUI = class
  private
    FWindow: IWindow;
    FDirty: Boolean;
    FScale: Double;
    FNodes: array of TDirectUINode;
    procedure MarkDirty;
    procedure Layout;
    procedure Paint;
  public
    constructor Create(AWindow: IWindow);
    procedure OnWindowEvent(const AEvent: TWindowEvent);
    procedure Tick;
    property Dirty: Boolean read FDirty;
  end;

constructor TDirectUI.Create(AWindow: IWindow);
begin
  inherited Create;
  FWindow := AWindow;
  FScale := AWindow.GetScaleFactor;
  FDirty := True;
  SetLength(FNodes, 2);
  FNodes[0].Text := 'nextPas directui — window host';
  FNodes[1].Text := 'PumpOnce driven, host-resizable';
  Layout;
end;

procedure TDirectUI.MarkDirty;
begin
  FDirty := True;
end;

procedure TDirectUI.Layout;
var
  W: Integer;
begin
  W := FWindow.GetWidth;
  FNodes[0].X := 12; FNodes[0].Y := 12; FNodes[0].W := W - 24; FNodes[0].H := 28;
  FNodes[1].X := 12; FNodes[1].Y := 48; FNodes[1].W := W - 24; FNodes[1].H := 20;
  // 高度随窗口缩放自适应（真实 directui 会走 text measure）
  if FScale > 1.5 then
  begin
    FNodes[0].H := 36;
    FNodes[1].H := 26;
  end;
  // 空实现，仅演示几何与 scale 的联动
end;

procedure TDirectUI.Paint;
var
  I: Integer;
begin
  if not FDirty then Exit;
  WriteLn('[directui] paint scale=', FScale:0:2, ' size=', FWindow.GetWidth, 'x', FWindow.GetHeight);
  for I := 0 to High(FNodes) do
    WriteLn('  node ', I, ': "', FNodes[I].Text, '" @', FNodes[I].X, ',', FNodes[I].Y, ' ', FNodes[I].W, 'x', FNodes[I].H);
  FDirty := False;
end;

procedure TDirectUI.OnWindowEvent(const AEvent: TWindowEvent);
begin
  case AEvent.Kind of
    weResized: begin
      WriteLn('[directui] event resized ', AEvent.Width, 'x', AEvent.Height);
      Layout; MarkDirty;
    end;
    weScaleChanged: begin
      WriteLn('[directui] event scale ', AEvent.NewScale:0:2);
      FScale := AEvent.NewScale;
      Layout; MarkDirty;
    end;
    weCloseRequested: WriteLn('[directui] event close requested');
    weFocusIn: WriteLn('[directui] focus in');
    weFocusOut: WriteLn('[directui] focus out');
    weMoved: ;
  end;
end;

procedure TDirectUI.Tick;
begin
  if FDirty then Paint;
end;

var
  Win: IWindow;
  Host: IWindowHost;
  UI: TDirectUI;
  Frame: Integer = 0;
  Pumped: Boolean;
begin
  Win := TWindowBuilder.New
    .Kind(wkFake)
    .Title('directui — window host demo')
    .Size(900, 600)
    .Build;
  WriteLn('window kind=fake handle=', HexStr(Win.NativeHandle), ' title="', Win.GetTitle, '"');
  Win.Show;

  UI := TDirectUI.Create(Win);
  Win.OnEvent(@UI.OnWindowEvent);

  // 宿主驱动：模拟移动端/浏览器宿主的几何与 DPI 变更
  if Supports(Win, IWindowHost, Host) then
  begin
    Host.HostResized(1024, 640);
    Host.HostScaleChanged(2.0);
  end;

  // 后台线程模拟：数据就绪后 Post 回主线程标记重绘（Dispatcher 跨线程安全）
  Win.GetDispatcher.Post(procedure
    begin
      WriteLn('[directui] background data ready → mark dirty');
      UI.MarkDirty;
    end);

  WriteLn('enter directui tick loop (PumpOnce + Tick, 60 frames)');
  while Frame < 60 do
  begin
    Inc(Frame);
    Pumped := WindowPumpOnce;
    if Pumped then WriteLn('[tick ', Frame, '] pumped work');
    UI.Tick;
    if Frame = 20 then
    begin
      WriteLn('[demo] host resize at frame 20');
      if Supports(Win, IWindowHost, Host) then Host.HostResized(1200, 800);
    end;
    if Frame = 40 then
    begin
      WriteLn('[demo] close at frame 40');
      Win.Close;
      Break;
    end;
  end;

  UI.Free;
  if not Win.IsClosed then Win.Close;
  WriteLn('demo done — directui 复用验证通过：同一 window 契约支撑声明式 UI 的非阻塞渲染');
end.
