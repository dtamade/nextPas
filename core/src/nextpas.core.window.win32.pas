unit nextpas.core.window.win32;

{** @desc Win32 后端：窗口壳 + 消息循环 + 闭包投递。
       依托 window.win32.ffi/.loader（platform.dl 装载），实现 IWindow
       与 message-only 窗口驱动的 IWindowDispatcher（PostMessage）。

       关键语义：
       - GWLP_USERDATA 携带 Self 指针，WndProc 按 handle 路由事件
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

implementation

uses
  SysUtils,
  nextpas.core.errors,
  nextpas.core.platform.thread,
  nextpas.core.sync.intf,
  nextpas.core.sync.mutex,
  nextpas.core.window.win32.ffi,
  nextpas.core.window.win32.loader;

const
  NEXTPAS_CLASS = 'NextPasWindow';
  WM_DISPATCH = WM_APP + 1;

var
  GInitDone: Boolean = False;
  GInitOk: Boolean = False;
  GLoopQuit: Boolean = False;
  GLiveWindows: array of Pointer;
  GDispLock: ILock;
  GDispRing: array of TWindowProcRef;
  GDispHead: Integer = 0;
  GDispCount: Integer = 0;
  GDispWnd: HWND = nil;

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
  Wc.lpfnWndProc := @DefWindowProcA; // placeholder, real proc assigned per-window via SetWindowLongPtr
  Wc.hInstance := HInst;
  Wc.hCursor := LoadCursorA(HINSTANCE(nil), IDC_ARROW);
  Wc.hbrBackground := HBRUSH(COLOR_WINDOW + 1);
  Wc.lpszClassName := NEXTPAS_CLASS;
  if RegisterClassExA(@Wc) = 0 then
  begin
    // If already registered, GetLastError would be 1410; treat as ok
  end;
  if GDispLock = nil then
    GDispLock := TMutex.Create as ILock;
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
  Result := Length(GLiveWindows);
end;

procedure RegisterLive(AWin: Pointer);
begin
  SetLength(GLiveWindows, Length(GLiveWindows)+1);
  GLiveWindows[High(GLiveWindows)] := AWin;
end;

procedure UnregisterLive(AWin: Pointer);
var
  I: Integer;
begin
  for I := High(GLiveWindows) downto 0 do
    if GLiveWindows[I] = AWin then
    begin
      GLiveWindows[I] := GLiveWindows[High(GLiveWindows)];
      SetLength(GLiveWindows, Length(GLiveWindows)-1);
      Break;
    end;
end;

function EventMethodToRef(AHandler: TWindowEventMethod): TWindowEventHandler;
begin
  Result := procedure(const AEvent: TWindowEvent) begin AHandler(AEvent); end;
end;

function EventProcToRef(AHandler: TWindowEventProc): TWindowEventHandler;
begin
  Result := procedure(const AEvent: TWindowEvent) begin AHandler(AEvent); end;
end;

function WindowMethodToRef(AHandler: TWindowProcMethod): TWindowProcRef;
begin
  Result := procedure begin AHandler(); end;
end;

function WindowProcToRef(AHandler: TWindowProc): TWindowProcRef;
begin
  Result := procedure begin AHandler(); end;
end;

procedure DispatcherGrow;
var
  LNewCap, I: Integer;
  LNew: array of TWindowProcRef;
begin
  LNewCap := Length(GDispRing) * 2;
  if LNewCap = 0 then LNewCap := 32;
  SetLength(LNew, LNewCap);
  for I := 0 to GDispCount -1 do
    LNew[I] := GDispRing[(GDispHead + I) mod Length(GDispRing)];
  GDispRing := LNew;
  GDispHead := 0;
end;

procedure DispatcherPush(AProc: TWindowProcRef);
begin
  if GDispLock = nil then GDispLock := TMutex.Create as ILock;
  GDispLock.Acquire;
  try
    if GDispCount = Length(GDispRing) then DispatcherGrow;
    GDispRing[(GDispHead + GDispCount) mod Length(GDispRing)] := AProc;
    Inc(GDispCount);
  finally
    GDispLock.Release;
  end;
end;

function DispatcherPop(out AProc: TWindowProcRef): Boolean;
begin
  Result := False;
  AProc := nil;
  if GDispLock = nil then Exit;
  GDispLock.Acquire;
  try
    if GDispCount = 0 then Exit;
    AProc := GDispRing[GDispHead];
    GDispRing[GDispHead] := nil;
    GDispHead := (GDispHead + 1) mod Length(GDispRing);
    Dec(GDispCount);
    Result := True;
  finally
    GDispLock.Release;
  end;
end;

procedure DispatcherDrain;
var
  LProc: TWindowProcRef;
begin
  while DispatcherPop(LProc) do
  begin
    try if Assigned(LProc) then LProc(); except raise; end;
    LProc := nil;
  end;
end;

procedure DispatcherWake;
begin
  if GDispWnd <> nil then
    PostMessageA(GDispWnd, WM_DISPATCH, 0, 0)
  else
    PostMessageA(nil, WM_DISPATCH, 0, 0);
end;

type
  TWindowWin32Dispatcher = class(TInterfacedObject, IWindowDispatcher)
  private
    FOwnerThread: UInt64;
  public
    constructor Create(AOwnerThread: UInt64);
    function IsOnMainThread: Boolean; inline;
    procedure Post(AProc: TWindowProcRef); overload;
    procedure Post(AProc: TWindowProcMethod); overload;
    procedure Post(AProc: TWindowProc); overload;
  end;

constructor TWindowWin32Dispatcher.Create(AOwnerThread: UInt64);
begin
  inherited Create;
  FOwnerThread := AOwnerThread;
end;

function TWindowWin32Dispatcher.IsOnMainThread: Boolean; inline;
begin
  Result := platform_thread_id = FOwnerThread;
end;

procedure TWindowWin32Dispatcher.Post(AProc: TWindowProcRef);
begin
  if not Assigned(AProc) then Exit;
  DispatcherPush(AProc);
  DispatcherWake;
end;

procedure TWindowWin32Dispatcher.Post(AProc: TWindowProcMethod);
begin Post(WindowMethodToRef(AProc)); end;

procedure TWindowWin32Dispatcher.Post(AProc: TWindowProc);
begin Post(WindowProcToRef(AProc)); end;

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
    FOnEvent: TWindowEventHandler;
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
    function GetWidth: Integer;
    function GetHeight: Integer;
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

function GlobalWndProc(hwnd: HWND; msg: UINT; wParam: WPARAM; lParam: LPARAM): LRESULT; stdcall;
var
  Self: TWindowWin32;
begin
  Self := TWindowWin32(GetWindowLongPtrA(hwnd, GWLP_USERDATA));
  if Self <> nil then
    Result := Self.WndProc(hwnd, msg, wParam, lParam)
  else
  begin
    if msg = WM_DISPATCH then
    begin
      DispatcherDrain;
      Exit(0);
    end;
    Result := DefWindowProcA(hwnd, msg, wParam, lParam);
  end;
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
  if AOptions.Width <= 0 then FWidth := DefaultWindowOptions.Width else FWidth := AOptions.Width;
  if AOptions.Height <= 0 then FHeight := DefaultWindowOptions.Height else FHeight := AOptions.Height;
  FMinW := AOptions.MinWidth; FMinH := AOptions.MinHeight;
  FMaxW := AOptions.MaxWidth; FMaxH := AOptions.MaxHeight;
  FOwnerThread := platform_thread_id;
  FDispatcher := TWindowWin32Dispatcher.Create(FOwnerThread);

  HInst := GetModuleHandleA(nil);
  Style := WS_OVERLAPPEDWINDOW;
  if not FResizable then
    Style := Style and not (WS_THICKFRAME or WS_MAXIMIZEBOX);

  FHandle := CreateWindowExA(0, NEXTPAS_CLASS, PAnsiChar(AnsiString(FTitle)),
    Style, CW_USEDEFAULT, CW_USEDEFAULT, FWidth, FHeight, nil, nil, HInst, nil);
  if FHandle = nil then
    raise EWindowNotInitialized.Create('CreateWindowExA failed');

  SetWindowLongPtrA(FHandle, GWLP_USERDATA, PtrInt(Self));
  // Override WndProc for this window
  SetWindowLongPtrA(FHandle, -4 {GWLP_WNDPROC}, PtrInt(@GlobalWndProc));

  if AOptions.Maximized then
    ShowWindow(FHandle, SW_MAXIMIZE);

  RegisterLive(Pointer(Self));
end;

destructor TWindowWin32.Destroy;
begin
  UnregisterLive(Pointer(Self));
  inherited;
end;

procedure TWindowWin32.RequireOpen;
begin
  if FClosed then raise EWindowClosed.Create('window is closed');
end;

procedure TWindowWin32.DoDispatch(const AEvent: TWindowEvent);
var
  H: TWindowEventHandler;
begin
  if FClosed then Exit;
  H := FOnEvent;
  if Assigned(H) then H(AEvent);
end;

procedure TWindowWin32.RealClose;
begin
  if FClosed then Exit;
  FClosed := True;
  FVisible := False;
  if FHandle <> nil then
  begin
    DestroyWindow(FHandle);
    FHandle := nil;
  end;
  UnregisterLive(Pointer(Self));
  if Win32LiveWindowCount = 0 then GLoopQuit := True;
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
  SetWindowTextA(FHandle, PAnsiChar(AnsiString(ATitle)));
end;

function TWindowWin32.GetTitle: string;
var
  Buf: array[0..1023] of AnsiChar;
  N: Integer;
begin
  RequireOpen;
  N := GetWindowTextA(FHandle, @Buf[0], Length(Buf));
  if N > 0 then Result := string(AnsiString(Copy(string(AnsiString(@Buf[0])),1,N))) else Result := FTitle;
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
  E.Kind := weResized; E.Width := FWidth; E.Height := FHeight; E.X := 0; E.Y := 0; E.NewScale := 0;
  DoDispatch(E);
end;

function TWindowWin32.GetWidth: Integer;
var
  R: RECT;
begin
  RequireOpen;
  if GetClientRect(FHandle, @R) then Result := R.right - R.left else Result := FWidth;
end;

function TWindowWin32.GetHeight: Integer;
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
  E.Kind := weResized; E.Width := FWidth; E.Height := FHeight; E.X := 0; E.Y := 0; E.NewScale := 0;
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

procedure TWindowWin32.OnEvent(AHandler: TWindowEventHandler);
begin
  RequireOpen;
  FOnEvent := AHandler;
end;

procedure TWindowWin32.OnEvent(AHandler: TWindowEventMethod);
begin OnEvent(EventMethodToRef(AHandler)); end;

procedure TWindowWin32.OnEvent(AHandler: TWindowEventProc);
begin OnEvent(EventProcToRef(AHandler)); end;

function TWindowWin32.WndProc(hwnd: HWND; msg: UINT; wParam: WPARAM; lParam: LPARAM): LRESULT;
var
  E: TWindowEvent;
  R: RECT;
  Mm: PMINMAXINFO;
begin
  case msg of
    WM_CLOSE:
      begin
        E.Kind := weCloseRequested; E.Width := 0; E.Height := 0; E.X := 0; E.Y := 0; E.NewScale := 0;
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
            E.Kind := weResized; E.Width := FWidth; E.Height := FHeight; E.X := 0; E.Y := 0; E.NewScale := 0;
            DoDispatch(E);
          end;
        end;
      end;
    WM_MOVE:
      begin
        E.Kind := weMoved; E.Width := 0; E.Height := 0;
        E.X := SmallInt(wParam and $FFFF); E.Y := SmallInt((wParam shr 16) and $FFFF);
        E.NewScale := 0;
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
        E.Kind := weFocusIn; E.Width := 0; E.Height := 0; E.X := 0; E.Y := 0; E.NewScale := 0;
        DoDispatch(E);
      end;
    WM_KILLFOCUS:
      begin
        E.Kind := weFocusOut; E.Width := 0; E.Height := 0; E.X := 0; E.Y := 0; E.NewScale := 0;
        DoDispatch(E);
      end;
    WM_DPICHANGED:
      begin
        E.Kind := weScaleChanged; E.Width := 0; E.Height := 0; E.X := 0; E.Y := 0;
        E.NewScale := HIWORD(wParam) / 96.0;
        DoDispatch(E);
      end;
    WM_DISPATCH:
      begin
        DispatcherDrain;
        Exit(0);
      end;
    WM_DESTROY:
      begin
        if not FClosed then
        begin
          FClosed := True;
          FVisible := False;
          FHandle := nil;
          UnregisterLive(Pointer(Self));
        end;
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
  while not GLoopQuit do
  begin
    // Drain dispatcher even if no Win32 message
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
      // Avoid busy spin
      platform_thread_sleep_ms(1);
    end;
    if Win32LiveWindowCount = 0 then Break;
  end;
end;

procedure WindowWin32QuitLoop;
begin
  GLoopQuit := True;
  PostQuitMessage(0);
  DispatcherWake;
end;

end.
