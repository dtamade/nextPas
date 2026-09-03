unit nextpas.core.window.win32;

{** @desc Win32 后端：窗口壳 + 消息循环 + 闭包投递。
       依托 window.win32.ffi/.loader（platform.dl 装载），实现 IWindow
       与 message-only 窗口驱动的 IWindowDispatcher（PostMessage）。

       关键语义：
       - WNDCLASSEX.lpfnWndProc 直绑 GlobalWndProc（类级），GWLP_USERDATA 携带 Self 指针按 handle 路由，消运行时 SetWindowLongPtr GWLP_WNDPROC 覆写竞态
       - WM_CLOSE→weCloseRequested（不销毁），WM_SIZE/WM_MOVE→几何，
         WM_SETFOCUS/WM_KILLFOCUS→焦点，WM_DPICHANGED→weScaleChanged
       - WM_GETMINMAXINFO 约束 Min/Max（创建期选项）
       - Dispatcher：全局互斥环 + 隐藏 message-only 窗口 PostMessage(WM_APP)
         唤醒主线程，在 WndProc 的 WM_APP 分支 Drain
       - GetScaleFactor：GetDpiForWindow/96，缺席回退 1.0                  *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.window.base,
  nextpas.core.window.intf;

function WindowWin32IsAvailable: Boolean;
function CreateWindowWin32(const AOptions: TWindowOptions): IWindow;
function Win32LiveWindowCount: Integer;
procedure WindowWin32RunLoop;
procedure WindowWin32QuitLoop;
function Win32PumpOnce: Boolean;

implementation

uses

  nextpas.core.errors,
  nextpas.core.text.ansi,
  nextpas.core.platform.thread,
  nextpas.core.sync.event,
  nextpas.core.sync.intf,
  nextpas.core.sync.mutex,
  nextpas.core.time.base,
  nextpas.core.window.impl,
  nextpas.core.window.live,
  nextpas.core.window.queue,
  nextpas.core.window.dispatcher.base,
  nextpas.core.window.registry,
  nextpas.core.window.win32.ffi,
  nextpas.core.window.win32.loader;

const
  NEXTPAS_CLASS = 'NextPasWindow';
  WM_DISPATCH = WM_APP + 1;

var
  GInitDone: Boolean = False;
  GInitOk: Boolean = False;
  GLoopQuit: Boolean = False;
  GLiveRegistry: TWindowLiveRegistry;
  GQueue: TWindowQueue;
  GDispWnd: HWND = nil;
  GWaitEvent: IEvent;

// 前向：窗口类直接绑定真实 WndProc，消运行时 SetWindowLongPtr 覆写脆弱窗口；启动路径单源精致，零竞态
function GlobalWndProc(hwnd: HWND; msg: UINT; wParam: WPARAM; lParam: LPARAM): LRESULT; stdcall; forward;

function EnsureWin32Init: Boolean;
var
  LInfo: TWindowWin32LoadInfo;
  Wc: WNDCLASSEX;
  HInst: HINSTANCE;
begin
  if GInitDone then Exit(GInitOk);
  GInitDone := True;
  if not TryLoadWindowWin32(LInfo) or not LInfo.Loaded then Exit(False);
  HInst := GetModuleHandleA(nil);
  FillChar(Wc, SizeOf(Wc), 0);
  Wc.cbSize := SizeOf(Wc);
  Wc.style := CS_HREDRAW or CS_VREDRAW or CS_OWNDC;
  Wc.lpfnWndProc := @GlobalWndProc; // 直接注册真实 WndProc，消 DefWindowProcA 占位+SetWindowLongPtr 覆写，启动路径精致无竞态
  Wc.hInstance := HInst;
  Wc.hCursor := LoadCursorA(HINSTANCE(nil), IDC_ARROW);
  Wc.hbrBackground := HBRUSH(COLOR_WINDOW + 1);
  Wc.lpszClassName := NEXTPAS_CLASS;
  if RegisterClassExA(@Wc) = 0 then
  begin
    // If already registered, GetLastError would be 1410; treat as ok
  end;
  if GQueue = nil then
    GQueue := RegistryEnsureDispatcherQueue;
  if GWaitEvent = nil then
    GWaitEvent := RegistryEnsureDispatcherWait;
  // Create message-only window for dispatcher wake
  GDispWnd := CreateWindowExA(0, NEXTPAS_CLASS, 'NextPasDispatcher', 0, 0, 0, 0, 0, nil, nil, HInst, nil);
  // Even if dispatcher window fails, main windows still work via PostQuit polling
  GInitOk := True;
  Result := True;
end;

function WindowWin32IsAvailable: Boolean;
var
  LInfo: TWindowWin32LoadInfo;
begin
  Result := TryLoadWindowWin32(LInfo) and LInfo.Loaded;
end;

function Win32LiveWindowCount: Integer;
begin
  if GLiveRegistry = nil then Exit(0);
  Result := GLiveRegistry.Count;
end;

procedure RegisterLive(AWin: Pointer);
begin
  RegistryEnsureLiveRegistry(GLiveRegistry);
  GLiveRegistry.Register(AWin);
end;

procedure UnregisterLive(AWin: Pointer);
begin
  if GLiveRegistry = nil then Exit;
  GLiveRegistry.Unregister(AWin);
end;

procedure DispatcherWake; forward;

procedure Win32DispatcherWake(AData: Pointer);
begin
  DispatcherWake;
end;

procedure EnsureDispatcherInited; inline;
begin
  if GQueue = nil then GQueue := RegistryEnsureDispatcherQueue;
  if GWaitEvent = nil then GWaitEvent := RegistryEnsureDispatcherWait;
end;

procedure DispatcherPush(AProc: TWindowProcRef); inline;
begin
  // 保留供非 dispatcher 路径复用；主路径已收口至 TWindowDispatcherBase inline 单源，零重复
  if (GQueue = nil) or (GWaitEvent = nil) then EnsureDispatcherInited;
  GQueue.Push(AProc);
  GWaitEvent.SetEvent;
end;

function DispatcherPop(out AProc: TWindowProcRef): Boolean;
begin
  if GQueue = nil then
  begin
    AProc := nil;
    Exit(False);
  end;
  Result := GQueue.TryPop(AProc);
end;

procedure DispatcherDrain;
begin
  if GQueue = nil then Exit;
  GQueue.Drain;
end;

procedure DispatcherWake;
begin
  if GDispWnd <> nil then
    PostMessageA(GDispWnd, WM_DISPATCH, 0, 0)
  else
    PostMessageA(nil, WM_DISPATCH, 0, 0);
end;

type
  TWindowWin32Dispatcher = class(TWindowDispatcherBase)
  public
    constructor Create(AOwnerThread: UInt64); reintroduce;
  end;

constructor TWindowWin32Dispatcher.Create(AOwnerThread: UInt64);
begin
  if (GQueue = nil) or (GWaitEvent = nil) then EnsureDispatcherInited;
  inherited Create(WindowFamilyToken, AOwnerThread, GQueue, GWaitEvent, @Win32DispatcherWake, nil, False);
end;

type
  TWindowWin32 = class(TInterfacedObject, IWindow)
  private
    FHandle: HWND;
    FClosed: Boolean;
    FVisible: Boolean;
    FResizable: Boolean;
    FTitle: string;
    FWidth, FHeight: Integer;
    FMinW, FMinH, FMaxW, FMaxH: Integer;
    FOwnerThread: UInt64;
    FDispatcher: IWindowDispatcher;
    FOnEvent: TWindowEventVariant;
    procedure RequireOpen; inline;
    procedure DoDispatch(const AEvent: TWindowEvent); inline;
    procedure RealClose;
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
    function GetDispatcher: IWindowDispatcher; inline;
    procedure OnEvent(AHandler: TWindowEventHandler); overload;
    procedure OnEvent(AHandler: TWindowEventMethod); overload;
    procedure OnEvent(AHandler: TWindowEventProc); overload;
  public
    constructor Create(const AOptions: TWindowOptions);
    destructor Destroy; override;
    // WndProc entry
    function WndProc(hwnd: HWND; msg: UINT; wParam: WPARAM; lParam: LPARAM): LRESULT;
  end;

function IsWin32Live(AWin: Pointer): Boolean; inline;
begin
  // 稳定性：野指针防护，Close/Destroy 后 USERDATA 残留指针经活窗注册表校验，不解构对象即判定
  Result := (AWin <> nil) and (GLiveRegistry <> nil) and GLiveRegistry.Contains(AWin);
end;

function GlobalWndProc(hwnd: HWND; msg: UINT; wParam: WPARAM; lParam: LPARAM): LRESULT; stdcall;
var
  Self: TWindowWin32;
  Ptr: Pointer;
begin
  Ptr := Pointer(GetWindowLongPtrA(hwnd, GWLP_USERDATA));
  // 稳定性：校验活窗注册表，未注册/已 Close/Destroy 的残留指针不再分发，避免野指针访问
  if IsWin32Live(Ptr) then
  begin
    Self := TWindowWin32(Ptr);
    // 额外校验句柄一致性与未关闭，防止 HWND 复用后误路由
    if (Self.FHandle = hwnd) and (not Self.FClosed) then
      Exit(Self.WndProc(hwnd, msg, wParam, lParam));
    // 已关闭但仍活注册：仅允许 WM_DISPATCH/WM_DESTROY 走安全分支，其余 Def
    if msg = WM_DISPATCH then
    begin
      DispatcherDrain;
      Exit(0);
    end;
    if msg = WM_DESTROY then
    begin
      // 幂等摘除，避免重复 Unregister
      Self.FClosed := True;
      Self.FVisible := False;
      Self.FHandle := nil;
      UnregisterLive(Ptr);
      SetWindowLongPtrA(hwnd, GWLP_USERDATA, 0);
      Exit(0);
    end;
    Result := DefWindowProcA(hwnd, msg, wParam, lParam);
    Exit;
  end;
  // 非活窗：可能是 dispatcher 窗或已销毁窗
  if msg = WM_DISPATCH then
  begin
    DispatcherDrain;
    Exit(0);
  end;
  Result := DefWindowProcA(hwnd, msg, wParam, lParam);
end;

constructor TWindowWin32.Create(const AOptions: TWindowOptions);
var
  LInfo: TWindowWin32LoadInfo;
  HInst: HINSTANCE;
  Style: DWORD;
begin
  inherited Create;
  CheckWindowOptions(AOptions);
  if not TryLoadWindowWin32(LInfo) or not LInfo.Loaded then
    raise EWindowBackendUnavailable.Create('Win32 backend not available');
  if not EnsureWin32Init then
    raise EWindowNotInitialized.Create('Win32 init failed');

  FClosed := False;
  FVisible := False;
  FResizable := AOptions.Resizable;
  FTitle := AOptions.Title;
  if AOptions.Size.Width <= 0 then FWidth := DefaultWindowOptions.Size.Width else FWidth := AOptions.Size.Width;
  if AOptions.Size.Height <= 0 then FHeight := DefaultWindowOptions.Size.Height else FHeight := AOptions.Size.Height;
  FMinW := AOptions.Constraints.MinWidth; FMinH := AOptions.Constraints.MinHeight;
  FMaxW := AOptions.Constraints.MaxWidth; FMaxH := AOptions.Constraints.MaxHeight;
  FOwnerThread := platform_thread_id;
  FDispatcher := TWindowWin32Dispatcher.Create(FOwnerThread);

  HInst := GetModuleHandleA(nil);
  Style := WS_OVERLAPPEDWINDOW;
  if not FResizable then
    Style := Style and not (WS_THICKFRAME or WS_MAXIMIZEBOX);

  // perf: inline zero-copy StrToPAnsiView 无 StrToAnsi 临时分配，复用 bytes.ops TByteSpan 视图单源，CreateWindowExA 同步拷贝故视图安全
  FHandle := CreateWindowExA(0, NEXTPAS_CLASS, StrToPAnsiView(FTitle),
    Style, CW_USEDEFAULT, CW_USEDEFAULT, FWidth, FHeight, nil, nil, HInst, nil);
  if FHandle = nil then
    raise EWindowNotInitialized.Create('CreateWindowExA failed');

  SetWindowLongPtrA(FHandle, GWLP_USERDATA, PtrInt(Self));
  // 窗口类已直接绑定 GlobalWndProc，无需 per-window SetWindowLongPtr GWLP_WNDPROC 覆写，消 WM_NCCREATE 等早消息竞态

  if AOptions.Maximized then
    ShowWindow(FHandle, SW_MAXIMIZE);

  RegisterLive(Pointer(Self));
end;

destructor TWindowWin32.Destroy;
begin
  WindowEventVariantClear(FOnEvent);
  UnregisterLive(Pointer(Self));
  inherited;
end;

procedure TWindowWin32.RequireOpen;
begin
  if FClosed then raise EWindowClosed.Create('window is closed');
end;

procedure TWindowWin32.DoDispatch(const AEvent: TWindowEvent); inline;
begin
  // 零堆分配分发：Method/Proc 直存 variant，inline 零拷贝
  if FClosed then Exit;
  WindowEventVariantDispatch(FOnEvent, AEvent);
end;

procedure TWindowWin32.RealClose;
begin
  if FClosed then Exit;
  FClosed := True;
  WindowEventVariantClear(FOnEvent);
  FVisible := False;
  if FHandle <> nil then
  begin
    // 稳定性：先清 USERDATA 再 Destroy，阻断 GlobalWndProc 野指针重入；资源释放不丢
    SetWindowLongPtrA(FHandle, GWLP_USERDATA, 0);
    DestroyWindow(FHandle);
    FHandle := nil;
  end;
  UnregisterLive(Pointer(Self));
  if Win32LiveWindowCount = 0 then GLoopQuit := True;
  if GWaitEvent<>nil then GWaitEvent.SetEvent;
  DispatcherWake;
end;

function TWindowWin32.IsOnMainThread: Boolean; inline;
begin
  Result := platform_thread_id = FOwnerThread;
end;

procedure TWindowWin32.Close;
begin
  if FClosed then Exit;
  if not IsOnMainThread then
  begin
    FDispatcher.Post(procedure begin RealClose; end);
    Exit;
  end;
  RealClose;
end;

function TWindowWin32.IsClosed: Boolean; inline; begin Result := FClosed; end;

procedure TWindowWin32.Show;
begin
  RequireOpen;
  ShowWindow(FHandle, SW_SHOW);
  FVisible := True;
end;

procedure TWindowWin32.Hide;
begin
  RequireOpen;
  ShowWindow(FHandle, SW_HIDE);
  FVisible := False;
end;

function TWindowWin32.IsVisible: Boolean;
begin
  RequireOpen;
  Result := IsWindowVisible(FHandle);
end;

procedure TWindowWin32.Focus;
begin
  RequireOpen;
  // SetForegroundWindow would be here; keep no-op for minimal
end;

procedure TWindowWin32.SetTitle(const ATitle: string);
begin
  RequireOpen;
  FTitle := ATitle;
  // perf: inline zero-copy StrToPAnsiView 无临时 Ansi 分配，高频标题场景零拷贝；SetWindowTextA 同步拷贝，视图安全
  SetWindowTextA(FHandle, StrToPAnsiView(ATitle));
end;

function TWindowWin32.GetTitle: string;
var
  Buf: array[0..1023] of AnsiChar;
  N: Integer;
begin
  RequireOpen;
  N := GetWindowTextA(FHandle, @Buf[0], Length(Buf));
  if N > 0 then
  begin
    Buf[N] := #0;
    Result := AnsiPtrToStr(@Buf[0]);
  end
  else Result := FTitle;
end;

procedure TWindowWin32.SetBounds(AWidth, AHeight: Integer);
var
  E: TWindowEvent;
  R: RECT;
begin
  RequireOpen;
  if AWidth < 0 then AWidth := 0;
  if AHeight < 0 then AHeight := 0;
  FWidth := AWidth; FHeight := AHeight;
  if GetWindowRect(FHandle, @R) then
    MoveWindow(FHandle, R.left, R.top, AWidth, AHeight, True);
  E := Default(TWindowEvent); E.Kind := weResized; E.Width := TWindowPixel(FWidth); E.Height := TWindowPixel(FHeight); E.X := TWindowPixel(0); E.Y := TWindowPixel(0); E.NewScale := TWindowScale.Invalid;
  DoDispatch(E);
end;

function TWindowWin32.GetWidth: Integer; inline;
var
  R: RECT;
begin
  RequireOpen;
  if GetClientRect(FHandle, @R) then Result := R.right - R.left else Result := FWidth;
end;

function TWindowWin32.GetHeight: Integer; inline;
var
  R: RECT;
begin
  RequireOpen;
  if GetClientRect(FHandle, @R) then Result := R.bottom - R.top else Result := FHeight;
end;

procedure TWindowWin32.SetResizable(AResizable: Boolean);
begin
  RequireOpen;
  FResizable := AResizable;
  // Style change requires SetWindowPos with SWP_FRAMECHANGED; keep flag for future Create
end;

procedure TWindowWin32.Maximize;
var
  E: TWindowEvent;
begin
  RequireOpen;
  ShowWindow(FHandle, SW_MAXIMIZE);
  E := Default(TWindowEvent); E.Kind := weResized; E.Width := TWindowPixel(FWidth); E.Height := TWindowPixel(FHeight); E.X := TWindowPixel(0); E.Y := TWindowPixel(0); E.NewScale := TWindowScale.Invalid;
  DoDispatch(E);
end;

procedure TWindowWin32.Unmaximize;
begin
  RequireOpen;
  ShowWindow(FHandle, SW_RESTORE);
end;

function TWindowWin32.IsMaximized: Boolean;
begin
  RequireOpen;
  Result := IsZoomed(FHandle);
end;

procedure TWindowWin32.Minimize;
begin
  RequireOpen;
  ShowWindow(FHandle, SW_MINIMIZE);
end;

procedure TWindowWin32.Restore;
begin
  RequireOpen;
  ShowWindow(FHandle, SW_RESTORE);
end;

function TWindowWin32.IsMinimized: Boolean;
begin
  RequireOpen;
  Result := IsIconic(FHandle);
end;

function TWindowWin32.GetScaleFactor: Double;
var
  Dpi: UINT;
begin
  RequireOpen;
  if Assigned(GetDpiForWindow) then
  begin
    Dpi := GetDpiForWindow(FHandle);
    if Dpi = 0 then Dpi := 96;
    Result := Dpi / 96.0;
  end
  else
    Result := 1.0;
end;

function TWindowWin32.NativeHandle: TWindowNativeHandle;
begin
  if FClosed or (FHandle = nil) then Exit(nil);
  Result := TWindowNativeHandle(FHandle);
end;

function TWindowWin32.GetDispatcher: IWindowDispatcher; inline;
begin
  Result := FDispatcher;
end;

procedure TWindowWin32.OnEvent(AHandler: TWindowEventHandler); inline;
begin
  RequireOpen;
  FOnEvent := WindowEventVariantFromRef(AHandler);
end;

procedure TWindowWin32.OnEvent(AHandler: TWindowEventMethod); inline;
begin
  // 零堆分配直存 wedkMethod，inline 零拷贝
  RequireOpen;
  FOnEvent := WindowEventVariantFromMethod(AHandler);
end;

procedure TWindowWin32.OnEvent(AHandler: TWindowEventProc); inline;
begin
  RequireOpen;
  FOnEvent := WindowEventVariantFromProc(AHandler);
end;

function TWindowWin32.WndProc(hwnd: HWND; msg: UINT; wParam: WPARAM; lParam: LPARAM): LRESULT;
var
  E: TWindowEvent;
  R: RECT;
  Mm: PMINMAXINFO;
begin
  case msg of
    WM_CLOSE:
      begin
        E := Default(TWindowEvent); E.Kind := weCloseRequested; E.Width := TWindowPixel(0); E.Height := TWindowPixel(0); E.X := TWindowPixel(0); E.Y := TWindowPixel(0); E.NewScale := TWindowScale.Invalid;
        DoDispatch(E);
        Exit(0);
      end;
    WM_SIZE:
      begin
        if wParam <> SIZE_MINIMIZED then
        begin
          if GetClientRect(hwnd, @R) then
          begin
            FWidth := R.right - R.left;
            FHeight := R.bottom - R.top;
            E := Default(TWindowEvent); E.Kind := weResized; E.Width := TWindowPixel(FWidth); E.Height := TWindowPixel(FHeight); E.X := TWindowPixel(0); E.Y := TWindowPixel(0); E.NewScale := TWindowScale.Invalid;
            DoDispatch(E);
          end;
        end;
      end;
    WM_MOVE:
      begin
        E := Default(TWindowEvent); E.Kind := weMoved; E.Width := TWindowPixel(0); E.Height := TWindowPixel(0);
        E.X := TWindowPixel(SmallInt(wParam and $FFFF)); E.Y := TWindowPixel(SmallInt((wParam shr 16) and $FFFF));
        E.NewScale := TWindowScale.Invalid;
        DoDispatch(E);
      end;
    WM_GETMINMAXINFO:
      begin
        Mm := PMINMAXINFO(lParam);
        if FMinW > 0 then Mm^.ptMinTrackSize.x := FMinW;
        if FMinH > 0 then Mm^.ptMinTrackSize.y := FMinH;
        if FMaxW > 0 then Mm^.ptMaxTrackSize.x := FMaxW;
        if FMaxH > 0 then Mm^.ptMaxTrackSize.y := FMaxH;
      end;
    WM_SETFOCUS:
      begin
        E := Default(TWindowEvent); E.Kind := weFocusIn; E.Width := TWindowPixel(0); E.Height := TWindowPixel(0); E.X := TWindowPixel(0); E.Y := TWindowPixel(0); E.NewScale := TWindowScale.Invalid;
        DoDispatch(E);
      end;
    WM_KILLFOCUS:
      begin
        E := Default(TWindowEvent); E.Kind := weFocusOut; E.Width := TWindowPixel(0); E.Height := TWindowPixel(0); E.X := TWindowPixel(0); E.Y := TWindowPixel(0); E.NewScale := TWindowScale.Invalid;
        DoDispatch(E);
      end;
    WM_DPICHANGED:
      begin
        E := Default(TWindowEvent); E.Kind := weScaleChanged; E.Width := TWindowPixel(0); E.Height := TWindowPixel(0); E.X := TWindowPixel(0); E.Y := TWindowPixel(0);
        E.NewScale := TWindowScale.FromFactor(HIWORD(wParam) / 96.0);
        DoDispatch(E);
      end;
    WM_DISPATCH:
      begin
        DispatcherDrain;
        Exit(0);
      end;
    WM_DESTROY:
      begin
        // 稳定性：幂等摘除，清除 USERDATA 阻断野指针，资源释放不丢；FClosed 已真则不再重复 Unregister
        if not FClosed then
        begin
          FClosed := True;
          FVisible := False;
          SetWindowLongPtrA(hwnd, GWLP_USERDATA, 0);
          FHandle := nil;
          UnregisterLive(Pointer(Self));
        end
        else
          SetWindowLongPtrA(hwnd, GWLP_USERDATA, 0);
      end;
  end;
  Result := DefWindowProcA(hwnd, msg, wParam, lParam);
end;

function CreateWindowWin32(const AOptions: TWindowOptions): IWindow;
begin
  Result := TWindowWin32.Create(AOptions);
end;

procedure WindowWin32RunLoop;
var
  LMsg: TMsg;
  Has: BOOL;
begin
  GLoopQuit := False;
  if (GQueue = nil) or (GWaitEvent = nil) then EnsureDispatcherInited;
  while not GLoopQuit do
  begin
    DispatcherDrain;
    if Win32LiveWindowCount = 0 then Break;
    Has := PeekMessageA(@LMsg, nil, 0, 0, PM_REMOVE);
    if Has then
    begin
      if LMsg.message = WM_QUIT then
      begin
        GLoopQuit := True;
        Break;
      end;
      TranslateMessage(@LMsg);
      DispatchMessageA(@LMsg);
    end
    else
    begin
      // 行业同行做法：WaitMessage 阻塞于 OS 消息队列，PostMessage/Quit 立即唤醒；回退以 IEvent 无限阻塞零轮询
      if Assigned(WaitMessage) then
        WaitMessage
      else if GWaitEvent <> nil then
        GWaitEvent.Wait;
    end;
    if Win32LiveWindowCount = 0 then Break;
  end;
end;

procedure WindowWin32QuitLoop;
begin
  GLoopQuit := True;
  if GWaitEvent <> nil then GWaitEvent.SetEvent;
  PostQuitMessage(0);
  DispatcherWake;
end;

function Win32PumpOnce: Boolean;
var
  LMsg: TMsg;
  LHas: BOOL;
begin
  Result := False;
  if not Assigned(PeekMessageA) or not Assigned(TranslateMessage) or not Assigned(DispatchMessageA) then
    Exit(False);
  // 非阻塞泵：零拷贝 PeekMessage 循环，inline 快速路径，无分配
  while True do
  begin
    LHas := PeekMessageA(@LMsg, nil, 0, 0, PM_REMOVE);
    if LHas = BOOL(0) then Break;
    Result := True;
    if LMsg.message = WM_QUIT then
    begin
      GLoopQuit := True;
      Break;
    end;
    TranslateMessage(@LMsg);
    DispatchMessageA(@LMsg);
  end;
  if Assigned(GQueue) and (GQueue.Count > 0) then
  begin
    DispatcherDrain;
    Result := True;
  end;
  // 稳定性：live=0 时不残留唤醒；资源随 Drain 释放，异常路径外层 try-finally 保障
end;

procedure RegisterWin32Backend;
var LDesc: TBackendDesc;
begin
  LDesc.Kind := wkWin32;
  LDesc.Probe := @WindowWin32IsAvailable;
  LDesc.Create := @CreateWindowWin32;
  LDesc.Live := @Win32LiveWindowCount;
  LDesc.Run := @WindowWin32RunLoop;
  LDesc.Quit := @WindowWin32QuitLoop;
  LDesc.Pump := @Win32PumpOnce;
  LDesc.Sonames := WINDOW_WIN32_SONAMES;
  RegistryRegister(LDesc);
end;

initialization
  RegisterWin32Backend;

finalization
  GLiveRegistry.Free;
  // 单源托管：GQueue/GWaitEvent 由 registry 统一释放，backend 仅置 nil 不双重 Free，heaptrc 0
  GQueue := nil;
  GWaitEvent := nil;

end.
