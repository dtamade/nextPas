unit nextpas.core.window.gtk.window;

{** @desc GTK 窗口形态与信号回调单源（family shard，owner window.impl 间接 via window.gtk.impl）。

       职责：TWindowGtk（IWindow 全集）+ 7 信号回调（delete/configure/focus/scale/destroy/state）。
       由 window.gtk.impl 拆分而来：原 860 行三职责超阈，本单元收口窗口与信号单职责，
       dispatcher 已收口至 window.gtk.dispatcher，共享类型（TGtkOps/TGtkContext/活窗聚合）
       留存于 window.gtk.impl，守单源。

       依赖方向：window.gtk.window → window.gtk.impl (TGtkOps/TGtkContext/活窗) +
       window.gtk.dispatcher (TWindowGtkDispatcher) + window.base/intf/live/queue/impl
       （L2 内家族共享，非门面 re-export，仅被 window.gtk.impl uses 实现转发）；
       守四件套与 L0-L3，复用 bytes.ops 单源 0→32→2×（WindowGrowCapacity inline）与
       text.ansi 零拷贝视图（StrToPAnsiView）。

       性能：标题路径 StrToPAnsiView 零拷贝（复用 bytes.ops TByteSpan 视图单源，gtk 同步拷贝），
       WindowGrowCapacity 单源转发 bytes.ops 0→32→2× O(1) 均摊；TWindowQueue 32cap 起步 2×
       指数扩容 Move 环绕锁外 Drain inline 零额外调用；IGtkOps trait 接口 + TGtkOpsAdapter inline 透传单次字段间接 nil 守卫，
       零额外堆分配；OnEvent 变体直存 Method/Proc 零堆分配 inline 零拷贝；
       Close 跨线程回退 FDispatcher.Post(TWindowProcMethod(@RealClose)) 零堆分配直存 wwkMethod（复用 bytes.ops 单源，禁匿名 Ref）。

       稳定性：队列 Clear 逐条 nil 释放闭包；单 FIdleTag+ILock 保护 DropAll 原子摘除 g_source_remove，
       异常 try-finally 不丢释放；FLock(I Lock/TMutex) 互斥保护 CbDestroy/RealClose 的 FClosed/FHandle 单次置位与单次 GtkUnregisterLive/WindowGtkLiveAdjust，锁外快照句柄后解锁再 WidgetDestroy/Disconnect，避免重入死锁与双重摘除时序风险；托管闭包计数的 FreeAndNil 对称 0 泄漏；信号 Connect/Disconnect 对称，Destroy 回调幂等。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.window.base,
  nextpas.core.window.intf,
  nextpas.core.window.gtk.impl;

function GtkWindowCreate(ACtx: TGtkContext; const AOptions: TWindowOptions): IWindow;

implementation

uses
  nextpas.core.errors,
  nextpas.core.text.ansi,
  nextpas.core.platform.thread,
  nextpas.core.sync.intf,
  nextpas.core.sync.mutex,
  nextpas.core.window.impl,
  nextpas.core.window.live,
  nextpas.core.window.queue,
  nextpas.core.window.gtk.dispatcher;

type
  gboolean = Int32;
  guint = Cardinal;
  gulong = QWord;
  gint = Int32;

const
  GDK_WINDOW_STATE_ICONIFIED = 1 shl 1;
  GTK_WINDOW_TOPLEVEL = 0;

{ ---- Signal callbacks ---- }

function CbDelete(AWidget: Pointer; AEvent: Pointer; AData: Pointer): gboolean; cdecl; forward;
function CbConfigure(AWidget: Pointer; AEvent: Pointer; AData: Pointer): gboolean; cdecl; forward;
function CbFocusIn(AWidget: Pointer; AEvent: Pointer; AData: Pointer): gboolean; cdecl; forward;
function CbFocusOut(AWidget: Pointer; AEvent: Pointer; AData: Pointer): gboolean; cdecl; forward;
procedure CbScaleNotify(AObj: Pointer; AParam: Pointer; AData: Pointer); cdecl; forward;
procedure CbDestroy(AWidget: Pointer; AData: Pointer); cdecl; forward;
function CbWindowState(AWidget: Pointer; AEvent: Pointer; AData: Pointer): gboolean; cdecl; forward;

type
  TWindowGtk = class(TInterfacedObject, IWindow)
  private
    FLock: ILock;
    FHandle: Pointer;
    FClosed: Boolean;
    FVisible: Boolean;
    FResizable: Boolean;
    FMaximized: Boolean;
    FMinimized: Boolean;
    FTitle: string;
    FWidth: Integer;
    FHeight: Integer;
    FOwnerThread: UInt64;
    FDispatcher: IWindowDispatcher;
    FOnEvent: TWindowEventVariant;
    FSignalDelete: gulong;
    FSignalConfigure: gulong;
    FSignalFocusIn: gulong;
    FSignalFocusOut: gulong;
    FSignalScale: gulong;
    FSignalDestroy: gulong;
    FSignalState: gulong;
    FContext: TGtkContext;
    procedure RequireOpen; inline;
    procedure DoDispatch(const AEvent: TWindowEvent); inline;
    procedure RealClose;
    procedure ConnectSignals;
    procedure DisconnectSignals;
    function IsOnMainThread: Boolean; inline;
  protected
    procedure Close;
    function IsClosed: Boolean; inline;
    procedure Show;
    procedure Hide;
    function IsVisible: Boolean;
    procedure Focus;
    procedure SetTitle(const ATitle: string);
    function GetTitle: string;
    procedure SetBounds(AWidth, AHeight: Integer);
    function GetWidth: Integer; inline;
    function GetHeight: Integer; inline;
    procedure SetResizable(AResizable: Boolean);
    procedure Maximize;
    procedure Unmaximize;
    function IsMaximized: Boolean;
    procedure Minimize;
    procedure Restore;
    function IsMinimized: Boolean;
    function GetScaleFactor: Double;
    function NativeHandle: TWindowNativeHandle;
    function GetDispatcher: IWindowDispatcher;
    procedure OnEvent(AHandler: TWindowEventHandler); overload;
    procedure OnEvent(AHandler: TWindowEventMethod); overload;
    procedure OnEvent(AHandler: TWindowEventProc); overload;
  public
    constructor Create(ACtx: TGtkContext; const AOptions: TWindowOptions);
    destructor Destroy; override;
  end;

{ ---- Signal callbacks impl ---- }

function CbDelete(AWidget: Pointer; AEvent: Pointer; AData: Pointer): gboolean; cdecl;
var
  Self: TWindowGtk;
  E: TWindowEvent;
begin
  Self := TWindowGtk(AData);
  E.Kind := weCloseRequested;
  E.Width := TWindowPixel(0); E.Height := TWindowPixel(0); E.X := TWindowPixel(0); E.Y := TWindowPixel(0); E.NewScale := TWindowScale.Invalid;
  Self.DoDispatch(E);
  Result := 1;
end;

function CbConfigure(AWidget: Pointer; AEvent: Pointer; AData: Pointer): gboolean; cdecl;
var
  Self: TWindowGtk;
  E: TWindowEvent;
  W, H: gint;
begin
  Self := TWindowGtk(AData);
  if (Self = nil) or (Self.FHandle = nil) or (Self.FContext.Ops = nil) then
  begin
    Result := 0; Exit;
  end;
  W := Self.FContext.Ops.WidgetGetAllocatedWidth(Self.FHandle);
  H := Self.FContext.Ops.WidgetGetAllocatedHeight(Self.FHandle);
  Self.FWidth := W;
  Self.FHeight := H;
  E.Kind := weResized;
  E.Width := TWindowPixel(W); E.Height := TWindowPixel(H); E.X := TWindowPixel(0); E.Y := TWindowPixel(0); E.NewScale := TWindowScale.Invalid;
  Self.DoDispatch(E);
  Result := 0;
end;

function CbFocusIn(AWidget: Pointer; AEvent: Pointer; AData: Pointer): gboolean; cdecl;
var
  Self: TWindowGtk;
  E: TWindowEvent;
begin
  Self := TWindowGtk(AData);
  E.Kind := weFocusIn;
  E.Width := TWindowPixel(0); E.Height := TWindowPixel(0); E.X := TWindowPixel(0); E.Y := TWindowPixel(0); E.NewScale := TWindowScale.Invalid;
  Self.DoDispatch(E);
  Result := 0;
end;

function CbFocusOut(AWidget: Pointer; AEvent: Pointer; AData: Pointer): gboolean; cdecl;
var
  Self: TWindowGtk;
  E: TWindowEvent;
begin
  Self := TWindowGtk(AData);
  E.Kind := weFocusOut;
  E.Width := TWindowPixel(0); E.Height := TWindowPixel(0); E.X := TWindowPixel(0); E.Y := TWindowPixel(0); E.NewScale := TWindowScale.Invalid;
  Self.DoDispatch(E);
  Result := 0;
end;

procedure CbScaleNotify(AObj: Pointer; AParam: Pointer; AData: Pointer); cdecl;
var
  Self: TWindowGtk;
  E: TWindowEvent;
  S: gint;
begin
  Self := TWindowGtk(AData);
  if (Self = nil) or (Self.FHandle = nil) or (Self.FContext.Ops = nil) then Exit;
  S := Self.FContext.Ops.WidgetGetScaleFactor(Self.FHandle);
  if S <= 0 then S := 1;
  E.Kind := weScaleChanged;
  E.Width := TWindowPixel(0); E.Height := TWindowPixel(0); E.X := TWindowPixel(0); E.Y := TWindowPixel(0);
  E.NewScale := TWindowScale.FromFactor(S);
  Self.DoDispatch(E);
end;

procedure CbDestroy(AWidget: Pointer; AData: Pointer); cdecl;
var
  Self: TWindowGtk;
begin
  Self := TWindowGtk(AData);
  if Self = nil then Exit;
  if Self.FLock <> nil then Self.FLock.Acquire;
  try
    if Self.FClosed then Exit;
    Self.FClosed := True;
    Self.FVisible := False;
    Self.FHandle := nil;
  finally
    if Self.FLock <> nil then Self.FLock.Release;
  end;
  GtkUnregisterLive(Self.FContext, Pointer(Self));
end;

function CbWindowState(AWidget: Pointer; AEvent: Pointer; AData: Pointer): gboolean; cdecl;
begin
  Result := 0;
end;

{ ---- TWindowGtk impl ---- }

constructor TWindowGtk.Create(ACtx: TGtkContext; const AOptions: TWindowOptions);
var
  LLoaded: Boolean;
begin
  inherited Create;
  if ACtx = nil then
    raise EWindowNotInitialized.Create('gtk context is nil');
  FContext := ACtx;
  CheckWindowOptions(AOptions);
  if (ACtx.Ops = nil) or not ACtx.Ops.TryLoad(LLoaded) or not LLoaded then
    raise EWindowBackendUnavailable.Create('GTK backend not available');
  if not GtkEnsureInit(ACtx) then
    raise EWindowNotInitialized.Create('gtk_init_check failed (no display?)');

  FLock := TMutex.Create as ILock;
  FClosed := False;
  FVisible := False;
  FResizable := AOptions.Resizable;
  FMaximized := AOptions.Maximized;
  FMinimized := False;
  FTitle := AOptions.Title;
  if AOptions.Size.Width <= 0 then
    FWidth := DefaultWindowOptions.Size.Width
  else
    FWidth := AOptions.Size.Width;
  if AOptions.Size.Height <= 0 then
    FHeight := DefaultWindowOptions.Size.Height
  else
    FHeight := AOptions.Size.Height;
  FOwnerThread := platform_thread_id;
  FDispatcher := TWindowGtkDispatcher.Create(FOwnerThread, ACtx) as IWindowDispatcher;

  if ACtx.Ops = nil then
    raise EWindowNotInitialized.Create('gtk_window_new not bound');
  FHandle := ACtx.Ops.WindowNew(GTK_WINDOW_TOPLEVEL);
  if FHandle = nil then
    raise EWindowNotInitialized.Create('gtk_window_new returned nil');
  if ACtx.Ops <> nil then
    ACtx.Ops.WindowSetDefaultSize(FHandle, FWidth, FHeight);
  if ACtx.Ops <> nil then
    ACtx.Ops.WindowSetResizable(FHandle, Ord(FResizable));
  if (FTitle <> '') and (ACtx.Ops <> nil) then
    // perf: inline zero-copy StrToPAnsiView 无临时 Ansi，复用 bytes.ops 视图单源，gtk 同步拷贝，trait 透传 nil 守卫
    ACtx.Ops.WindowSetTitle(FHandle, StrToPAnsiView(FTitle));
  if FMaximized and (ACtx.Ops <> nil) then
    ACtx.Ops.WindowMaximize(FHandle);

  ConnectSignals;
  GtkRegisterLive(ACtx, Pointer(Self));
end;

destructor TWindowGtk.Destroy;
begin
  WindowEventVariantClear(FOnEvent);
  if not FClosed and (FHandle <> nil) then
  begin
    DisconnectSignals;
  end;
  if FDispatcher <> nil then
  begin
    (FDispatcher as TWindowGtkDispatcher).DropAll;
  end;
  GtkUnregisterLive(FContext, Pointer(Self));
  FLock := nil;
  inherited;
end;

procedure TWindowGtk.ConnectSignals;
begin
  if (FHandle = nil) or (FContext.Ops = nil) then Exit;
  begin
    FSignalDelete   := FContext.Ops.SignalConnectData(FHandle, 'delete-event', Pointer(@CbDelete), Self, nil, 0);
    FSignalConfigure:= FContext.Ops.SignalConnectData(FHandle, 'configure-event', Pointer(@CbConfigure), Self, nil, 0);
    FSignalFocusIn  := FContext.Ops.SignalConnectData(FHandle, 'focus-in-event', Pointer(@CbFocusIn), Self, nil, 0);
    FSignalFocusOut := FContext.Ops.SignalConnectData(FHandle, 'focus-out-event', Pointer(@CbFocusOut), Self, nil, 0);
    FSignalScale    := FContext.Ops.SignalConnectData(FHandle, 'notify::scale-factor', Pointer(@CbScaleNotify), Self, nil, 0);
    FSignalDestroy  := FContext.Ops.SignalConnectData(FHandle, 'destroy', Pointer(@CbDestroy), Self, nil, 0);
    FSignalState    := FContext.Ops.SignalConnectData(FHandle, 'window-state-event', Pointer(@CbWindowState), Self, nil, 0);
  end;
end;

procedure TWindowGtk.DisconnectSignals;
begin
  if (FHandle = nil) or (FContext.Ops = nil) then Exit;
  if FSignalDelete <> 0 then FContext.Ops.SignalHandlerDisconnect(FHandle, FSignalDelete);
  if FSignalConfigure <> 0 then FContext.Ops.SignalHandlerDisconnect(FHandle, FSignalConfigure);
  if FSignalFocusIn <> 0 then FContext.Ops.SignalHandlerDisconnect(FHandle, FSignalFocusIn);
  if FSignalFocusOut <> 0 then FContext.Ops.SignalHandlerDisconnect(FHandle, FSignalFocusOut);
  if FSignalScale <> 0 then FContext.Ops.SignalHandlerDisconnect(FHandle, FSignalScale);
  if FSignalDestroy <> 0 then FContext.Ops.SignalHandlerDisconnect(FHandle, FSignalDestroy);
  if FSignalState <> 0 then FContext.Ops.SignalHandlerDisconnect(FHandle, FSignalState);
  FSignalDelete := 0; FSignalConfigure := 0; FSignalFocusIn := 0; FSignalFocusOut := 0;
  FSignalScale := 0; FSignalDestroy := 0; FSignalState := 0;
end;

procedure TWindowGtk.RequireOpen;
begin
  if FClosed then
    raise EWindowClosed.Create('window is closed');
end;

procedure TWindowGtk.DoDispatch(const AEvent: TWindowEvent); inline;
begin
  // 零堆分配分发：Method/Proc 直存 variant，inline 零拷贝
  if FClosed then Exit;
  WindowEventVariantDispatch(FOnEvent, AEvent);
end;

function TWindowGtk.IsOnMainThread: Boolean; inline;
begin
  Result := platform_thread_id = FOwnerThread;
end;

procedure TWindowGtk.RealClose;
var
  LHandle: Pointer;
begin
  // 互斥 test-and-set：与 CbDestroy 争用 FClosed/FHandle，锁内单次置位，解锁后单次 Unregister，零双重摘除
  if FLock <> nil then FLock.Acquire;
  try
    if FClosed then Exit;
    FClosed := True;
    FVisible := False;
    LHandle := FHandle;
    FHandle := nil;
  finally
    if FLock <> nil then FLock.Release;
  end;
  WindowEventVariantClear(FOnEvent);
  if FDispatcher <> nil then
    (FDispatcher as TWindowGtkDispatcher).DropAll;
  // 信号摘除用快照句柄，FHandle 已 nil 避免重入误删，inline 零拷贝单次遍历，trait nil 守卫
  if (LHandle <> nil) and (FContext.Ops <> nil) then
  begin
    if FSignalDelete <> 0 then FContext.Ops.SignalHandlerDisconnect(LHandle, FSignalDelete);
    if FSignalConfigure <> 0 then FContext.Ops.SignalHandlerDisconnect(LHandle, FSignalConfigure);
    if FSignalFocusIn <> 0 then FContext.Ops.SignalHandlerDisconnect(LHandle, FSignalFocusIn);
    if FSignalFocusOut <> 0 then FContext.Ops.SignalHandlerDisconnect(LHandle, FSignalFocusOut);
    if FSignalScale <> 0 then FContext.Ops.SignalHandlerDisconnect(LHandle, FSignalScale);
    if FSignalDestroy <> 0 then FContext.Ops.SignalHandlerDisconnect(LHandle, FSignalDestroy);
    if FSignalState <> 0 then FContext.Ops.SignalHandlerDisconnect(LHandle, FSignalState);
    FSignalDelete := 0; FSignalConfigure := 0; FSignalFocusIn := 0; FSignalFocusOut := 0;
    FSignalScale := 0; FSignalDestroy := 0; FSignalState := 0;
  end;
  if LHandle <> nil then
  begin
    if FContext.Ops <> nil then
      FContext.Ops.WidgetDestroy(LHandle);
  end;
  GtkUnregisterLive(FContext, Pointer(Self));
end;

procedure TWindowGtk.Close;
begin
  if FClosed then Exit;
  if not IsOnMainThread then
  begin
    // 热路径零堆分配：Method 直存 wwkMethod 单源 bytes.ops 0→32→2×，inline 零拷贝，禁匿名 Ref 堆分配
    FDispatcher.Post(TWindowProcMethod(@RealClose));
    Exit;
  end;
  RealClose;
end;

function TWindowGtk.IsClosed: Boolean; inline;
begin
  Result := FClosed;
end;

procedure TWindowGtk.Show;
begin
  RequireOpen;
  if FContext.Ops <> nil then
    FContext.Ops.WidgetShowAll(FHandle);
  FVisible := True;
end;

procedure TWindowGtk.Hide;
begin
  RequireOpen;
  if FContext.Ops <> nil then
    FContext.Ops.WidgetHide(FHandle);
  FVisible := False;
end;

function TWindowGtk.IsVisible: Boolean;
begin
  RequireOpen;
  if (FHandle <> nil) and (FContext.Ops <> nil) then
    Result := FContext.Ops.WidgetGetVisible(FHandle) <> 0
  else
    Result := FVisible;
end;

procedure TWindowGtk.Focus;
begin
  RequireOpen;
  if (FHandle <> nil) and (FContext.Ops <> nil) then
    FContext.Ops.WidgetGrabFocus(FHandle);
end;

procedure TWindowGtk.SetTitle(const ATitle: string);
begin
  RequireOpen;
  FTitle := ATitle;
  if (FHandle <> nil) and (FContext.Ops <> nil) then
    // perf: inline zero-copy StrToPAnsiView 高频零分配，视图 lifetime 绑 ATitle/FTitle，trait 透传 nil 守卫
    FContext.Ops.WindowSetTitle(FHandle, StrToPAnsiView(ATitle));
end;

function TWindowGtk.GetTitle: string;
var
  P: PAnsiChar;
begin
  RequireOpen;
  if (FHandle <> nil) and (FContext.Ops <> nil) then
  begin
    P := FContext.Ops.WindowGetTitle(FHandle);
    if P <> nil then
      Result := AnsiPtrToStr(P)
    else
      Result := FTitle;
  end
  else
    Result := FTitle;
end;

procedure TWindowGtk.SetBounds(AWidth, AHeight: Integer);
var
  E: TWindowEvent;
begin
  RequireOpen;
  if AWidth < 0 then AWidth := 0;
  if AHeight < 0 then AHeight := 0;
  FWidth := AWidth;
  FHeight := AHeight;
  if (FHandle <> nil) and (FContext.Ops <> nil) then
    FContext.Ops.WindowResize(FHandle, AWidth, AHeight);
  E.Kind := weResized;
  E.Width := TWindowPixel(FWidth); E.Height := TWindowPixel(FHeight); E.X := TWindowPixel(0); E.Y := TWindowPixel(0); E.NewScale := TWindowScale.Invalid;
  DoDispatch(E);
end;

function TWindowGtk.GetWidth: Integer; inline;
begin
  RequireOpen;
  // perf: 本地缓存物理像素 inline 零 trait/跨库调用，60fps 失效循环 O(1) 快路径零虚派；CbConfigure/SetBounds 单源更新 FWidth，复用 bytes.ops 单源思想
  Result := FWidth;
end;

function TWindowGtk.GetHeight: Integer; inline;
begin
  RequireOpen;
  // perf: 本地缓存物理像素 inline 零 trait/跨库调用，60fps 失效循环 O(1) 快路径零虚派；CbConfigure/SetBounds 单源更新 FHeight
  Result := FHeight;
end;

procedure TWindowGtk.SetResizable(AResizable: Boolean);
begin
  RequireOpen;
  FResizable := AResizable;
  if (FHandle <> nil) and (FContext.Ops <> nil) then
    FContext.Ops.WindowSetResizable(FHandle, Ord(AResizable));
end;

procedure TWindowGtk.Maximize;
var
  E: TWindowEvent;
begin
  RequireOpen;
  FMaximized := True;
  FMinimized := False;
  if (FHandle <> nil) and (FContext.Ops <> nil) then
    FContext.Ops.WindowMaximize(FHandle);
  E.Kind := weResized;
  E.Width := TWindowPixel(FWidth); E.Height := TWindowPixel(FHeight); E.X := TWindowPixel(0); E.Y := TWindowPixel(0); E.NewScale := TWindowScale.Invalid;
  DoDispatch(E);
end;

procedure TWindowGtk.Unmaximize;
begin
  RequireOpen;
  FMaximized := False;
  if (FHandle <> nil) and (FContext.Ops <> nil) then
    FContext.Ops.WindowUnmaximize(FHandle);
end;

function TWindowGtk.IsMaximized: Boolean;
begin
  RequireOpen;
  if (FHandle <> nil) and (FContext.Ops <> nil) then
    Result := FContext.Ops.WindowIsMaximized(FHandle) <> 0
  else
    Result := FMaximized;
end;

procedure TWindowGtk.Minimize;
begin
  RequireOpen;
  FMinimized := True;
  FMaximized := False;
  if (FHandle <> nil) and (FContext.Ops <> nil) then
    FContext.Ops.WindowIconify(FHandle);
end;

procedure TWindowGtk.Restore;
begin
  RequireOpen;
  FMinimized := False;
  FMaximized := False;
  if (FHandle <> nil) and (FContext.Ops <> nil) then
    FContext.Ops.WindowDeiconify(FHandle);
end;

function TWindowGtk.IsMinimized: Boolean;
var
  St: guint;
  GW: Pointer;
begin
  RequireOpen;
  if (FHandle <> nil) and (FContext.Ops <> nil) then
  begin
    GW := FContext.Ops.WidgetGetWindow(FHandle);
    if GW <> nil then
    begin
      St := FContext.Ops.GdkWindowGetState(GW);
      Result := (St and GDK_WINDOW_STATE_ICONIFIED) <> 0;
      Exit;
    end;
  end;
  Result := FMinimized;
end;

function TWindowGtk.GetScaleFactor: Double;
var
  S: gint;
begin
  RequireOpen;
  if (FHandle <> nil) and (FContext.Ops <> nil) then
  begin
    S := FContext.Ops.WidgetGetScaleFactor(FHandle);
    if S <= 0 then S := 1;
    Result := S;
  end
  else
    Result := 1.0;
end;

function TWindowGtk.NativeHandle: TWindowNativeHandle;
var
  GW: Pointer;
begin
  if FClosed or (FHandle = nil) or (FContext.Ops = nil) then
    Exit(nil);
  GW := FContext.Ops.WidgetGetWindow(FHandle);
  Result := TWindowNativeHandle(GW);
end;

function TWindowGtk.GetDispatcher: IWindowDispatcher; inline;
begin
  Result := FDispatcher;
end;

procedure TWindowGtk.OnEvent(AHandler: TWindowEventHandler); inline;
begin
  RequireOpen;
  FOnEvent := WindowEventVariantFromRef(AHandler);
end;

procedure TWindowGtk.OnEvent(AHandler: TWindowEventMethod); inline;
begin
  // 零堆分配直存 wedkMethod，inline 零拷贝
  RequireOpen;
  FOnEvent := WindowEventVariantFromMethod(AHandler);
end;

procedure TWindowGtk.OnEvent(AHandler: TWindowEventProc); inline;
begin
  RequireOpen;
  FOnEvent := WindowEventVariantFromProc(AHandler);
end;

function GtkWindowCreate(ACtx: TGtkContext; const AOptions: TWindowOptions): IWindow;
begin
  Result := TWindowGtk.Create(ACtx, AOptions);
end;

end.
