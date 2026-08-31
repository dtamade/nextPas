unit nextpas.core.webview.webview2.win;

{** @desc Deprecated shim: thin re-export of window.win32.
       M5 has-a 组合后 webview2 不再自建 Win32 壳，统一复用
       nextpas.core.window.win32 的 WM_SIZE/WM_DPICHANGED 转译与
       IWindow.OnEvent → put_Bounds 同步。本单元保留仅为兼容旧测试
       对 Win32Shell* 的直接调用，内部转发或桩实现，新代码请直接
       uses nextpas.core.window.win32 / window.factory。 *}

{$I nextpas.core.settings.inc}

interface

type
  TWin32ShellGeometry = record
    Title: string;
    Width: Integer;
    Height: Integer;
    Resizable: Boolean;
    StartMaximized: Boolean;
  end;

  TWin32ScaleChangedProc = procedure(AWin: Pointer; AScale: Double);
  TWin32ResizeProc = procedure(AWin: Pointer; AWidth, AHeight: Integer);
  TWin32PostProc = procedure(AData: Pointer); stdcall;

function Win32ShellInit: Boolean;
function Win32ShellCreate(const AGeometry: TWin32ShellGeometry): Pointer;
procedure Win32ShellSetTitle(AWin: Pointer; const ATitle: string); inline;
procedure Win32ShellResize(AWin: Pointer; AW, AH: Integer); inline;
procedure Win32ShellShow(AWin: Pointer); inline;
procedure Win32ShellHide(AWin: Pointer); inline;
procedure Win32ShellDestroy(AWin: Pointer); inline;
function Win32ShellIsVisible(AWin: Pointer): Boolean; inline;
function Win32ShellIsMaximized(AWin: Pointer): Boolean; inline;
procedure Win32ShellMaximize(AWin: Pointer); inline;
procedure Win32ShellUnmaximize(AWin: Pointer); inline;
procedure Win32ShellMinimize(AWin: Pointer); inline;
procedure Win32ShellRestore(AWin: Pointer); inline;
function Win32ShellIsMinimized(AWin: Pointer): Boolean; inline;
function Win32ShellScaleFactor(AWin: Pointer): Double; inline;
procedure Win32ShellOnScaleChanged(AHandler: TWin32ScaleChangedProc); inline;
procedure Win32ShellOnResize(AHandler: TWin32ResizeProc); inline;
function Win32ShellClientSize(AWin: Pointer; out AWidth, AHeight: Integer): Boolean; inline;
function Win32ShellPost(AProc: TWin32PostProc; AData: Pointer): Boolean; inline;
procedure Win32ShellFocus(AWin: Pointer); inline;
function Win32ShellNativeHandle(AWin: Pointer): Pointer; inline;
procedure Win32ShellRunMainLoop;
procedure Win32ShellQuitMainLoop;
function Win32ShellIsMainLoopRunning: Boolean; inline;

implementation

{$IFDEF MSWINDOWS}
uses
  Windows, Messages;

const
  CLASS_NAME = 'NextPasWebView2Win';
  DISPATCH_CLASS = 'NextPasWebViewDispatch';
  WIN_STYLE_RESIZABLE = WS_OVERLAPPEDWINDOW;
  WIN_STYLE_FIXED     = WS_OVERLAPPED or WS_CAPTION or WS_SYSMENU or WS_MINIMIZEBOX;
  WM_DPICHANGED = $02E0;
  WM_WV_DISPATCH = WM_USER + 101;

type
  TGetDpiForWindow = function(AWnd: HWND): UINT; stdcall;

var
  GRegistered: Boolean = False;
  GDispatchRegistered: Boolean = False;
  GDispatchWnd: HWND = 0;
  GMainLoopRunning: Boolean = False;
  GWinCount: Integer = 0;
  GGetDpiForWindow: TGetDpiForWindow = nil;
  GGetDpiTried: Boolean = False;
  GScaleHandler: TWin32ScaleChangedProc = nil;
  GResizeHandler: TWin32ResizeProc = nil;

function TryResolveGetDpiForWindow: TGetDpiForWindow;
var
  H: HMODULE;
begin
  if GGetDpiTried then Exit(GGetDpiForWindow);
  GGetDpiTried := True;
  H := GetModuleHandleW('user32.dll');
  if H <> 0 then
    GGetDpiForWindow := TGetDpiForWindow(GetProcAddress(H, 'GetDpiForWindow'));
  Result := GGetDpiForWindow;
end;

function CurrentScaleForWindow(AWnd: HWND): Double;
var
  LGetDpi: TGetDpiForWindow;
  Dpi: UINT;
  DC: HDC;
begin
  LGetDpi := TryResolveGetDpiForWindow;
  if Assigned(LGetDpi) then
  begin
    Dpi := LGetDpi(AWnd);
    if Dpi <> 0 then Exit(Dpi / 96.0);
  end;
  DC := GetDC(AWnd);
  try
    Result := GetDeviceCaps(DC, LOGPIXELSX) / 96.0;
    if Result < 0.5 then Result := 1.0;
  finally
    ReleaseDC(AWnd, DC);
  end;
end;

function WndProc(AWnd: HWND; AMsg: UINT; AWParam: WPARAM; ALParam: LPARAM): LRESULT; stdcall;
var
  LScale: Double;
begin
  case AMsg of
    WM_DESTROY:
      begin
        Dec(GWinCount);
        if GWinCount <= 0 then
          Win32ShellQuitMainLoop;
        Result := 0;
        Exit;
      end;
    WM_CLOSE:
      begin
        DestroyWindow(AWnd);
        Result := 0;
        Exit;
      end;
    WM_SIZE:
      begin
        if Assigned(GResizeHandler) and (AWParam <> SIZE_MINIMIZED) then
          GResizeHandler(Pointer(AWnd), LoWord(ALParam), HiWord(ALParam));
        Result := DefWindowProcW(AWnd, AMsg, AWParam, ALParam);
        Exit;
      end;
    WM_DPICHANGED:
      begin
        if Assigned(GScaleHandler) then
        begin
          LScale := CurrentScaleForWindow(AWnd);
          GScaleHandler(Pointer(AWnd), LScale);
        end;
        Result := DefWindowProcW(AWnd, AMsg, AWParam, ALParam);
        Exit;
      end;
  end;
  Result := DefWindowProcW(AWnd, AMsg, AWParam, ALParam);
end;

function Win32ShellInit: Boolean;
var
  WC: WNDCLASSEXW;
begin
  if GRegistered then Exit(True);
  FillChar(WC, SizeOf(WC), 0);
  WC.cbSize := SizeOf(WC);
  WC.style := CS_HREDRAW or CS_VREDRAW;
  WC.lpfnWndProc := @WndProc;
  WC.hInstance := HInstance;
  WC.hCursor := LoadCursor(0, IDC_ARROW);
  WC.hbrBackground := GetStockObject(WHITE_BRUSH);
  WC.lpszClassName := CLASS_NAME;
  Result := RegisterClassExW(WC) <> 0;
  if Result then GRegistered := True
  else Result := GetLastError = ERROR_CLASS_ALREADY_EXISTS;
end;

function Win32ShellCreate(const AGeometry: TWin32ShellGeometry): Pointer;
var
  Style: DWORD;
  W, H: Integer;
begin
  Win32ShellInit;
  Style := WIN_STYLE_RESIZABLE;
  if not AGeometry.Resizable then Style := WIN_STYLE_FIXED;
  W := AGeometry.Width; if W <= 0 then W := 1024;
  H := AGeometry.Height; if H <= 0 then H := 768;
  Result := Pointer(CreateWindowExW(
    0, CLASS_NAME, PWideChar(WideString(AGeometry.Title)),
    Style,
    CW_USEDEFAULT, CW_USEDEFAULT, W, H,
    0, 0, HInstance, nil));
  if Result <> nil then
  begin
    Inc(GWinCount);
    if AGeometry.StartMaximized then
      ShowWindow(HWND(Result), SW_MAXIMIZE);
  end;
end;

procedure Win32ShellSetTitle(AWin: Pointer; const ATitle: string); inline;
begin
  if AWin = nil then Exit;
  SetWindowTextW(HWND(AWin), PWideChar(WideString(ATitle)));
end;

procedure Win32ShellResize(AWin: Pointer; AW, AH: Integer); inline;
begin
  if AWin = nil then Exit;
  SetWindowPos(HWND(AWin), 0, 0, 0, AW, AH, SWP_NOMOVE or SWP_NOZORDER);
end;

procedure Win32ShellShow(AWin: Pointer); inline;
begin
  if AWin = nil then Exit;
  ShowWindow(HWND(AWin), SW_SHOW);
  UpdateWindow(HWND(AWin));
end;

procedure Win32ShellHide(AWin: Pointer); inline;
begin
  if AWin = nil then Exit;
  ShowWindow(HWND(AWin), SW_HIDE);
end;

procedure Win32ShellDestroy(AWin: Pointer); inline;
begin
  if AWin = nil then Exit;
  DestroyWindow(HWND(AWin));
end;

function Win32ShellIsVisible(AWin: Pointer): Boolean; inline;
begin
  Result := (AWin <> nil) and IsWindowVisible(HWND(AWin));
end;

function Win32ShellIsMaximized(AWin: Pointer): Boolean; inline;
begin
  Result := (AWin <> nil) and (IsZoomed(HWND(AWin)));
end;

procedure Win32ShellMaximize(AWin: Pointer); inline;
begin
  if AWin = nil then Exit;
  ShowWindow(HWND(AWin), SW_MAXIMIZE);
end;

procedure Win32ShellUnmaximize(AWin: Pointer); inline;
begin
  if AWin = nil then Exit;
  ShowWindow(HWND(AWin), SW_RESTORE);
end;

procedure Win32ShellMinimize(AWin: Pointer); inline;
begin
  if AWin = nil then Exit;
  ShowWindow(HWND(AWin), SW_MINIMIZE);
end;

procedure Win32ShellRestore(AWin: Pointer); inline;
begin
  if AWin = nil then Exit;
  if IsIconic(HWND(AWin)) or IsZoomed(HWND(AWin)) then
    ShowWindow(HWND(AWin), SW_RESTORE)
  else
    ShowWindow(HWND(AWin), SW_SHOW);
end;

function Win32ShellIsMinimized(AWin: Pointer): Boolean; inline;
begin
  Result := (AWin <> nil) and IsIconic(HWND(AWin));
end;

function Win32ShellScaleFactor(AWin: Pointer): Double; inline;
begin
  if AWin = nil then Exit(1.0);
  Result := CurrentScaleForWindow(HWND(AWin));
  if Result < 0.5 then Result := 1.0;
end;

procedure Win32ShellOnScaleChanged(AHandler: TWin32ScaleChangedProc); inline;
begin
  GScaleHandler := AHandler;
end;

procedure Win32ShellOnResize(AHandler: TWin32ResizeProc); inline;
begin
  GResizeHandler := AHandler;
end;

function Win32ShellClientSize(AWin: Pointer; out AWidth, AHeight: Integer): Boolean; inline;
var
  CR: TRect;
begin
  if AWin = nil then Exit(False);
  Result := GetClientRect(HWND(AWin), CR);
  if Result then
  begin
    AWidth := CR.Right - CR.Left;
    AHeight := CR.Bottom - CR.Top;
  end;
end;

function DispatchWndProc(AWnd: HWND; AMsg: UINT; AWParam: WPARAM; ALParam: LPARAM): LRESULT; stdcall;
var
  LProc: TWin32PostProc;
  LData: Pointer;
begin
  if AMsg = WM_WV_DISPATCH then
  begin
    LProc := TWin32PostProc(AWParam);
    LData := Pointer(ALParam);
    if Assigned(LProc) then
      try LProc(LData); except end;
    Result := 0;
    Exit;
  end;
  Result := DefWindowProcW(AWnd, AMsg, AWParam, ALParam);
end;

function EnsureDispatchWnd: Boolean;
var
  WC: WNDCLASSEXW;
begin
  if GDispatchWnd <> 0 then Exit(True);
  if not GDispatchRegistered then
  begin
    FillChar(WC, SizeOf(WC), 0);
    WC.cbSize := SizeOf(WC);
    WC.lpfnWndProc := @DispatchWndProc;
    WC.hInstance := HInstance;
    WC.lpszClassName := DISPATCH_CLASS;
    if RegisterClassExW(WC) = 0 then
      if GetLastError <> ERROR_CLASS_ALREADY_EXISTS then Exit(False);
    GDispatchRegistered := True;
  end;
  GDispatchWnd := CreateWindowExW(0, DISPATCH_CLASS, nil, 0, 0, 0, 0, 0, HWND(Pointer(-3)), 0, HInstance, nil);
  Result := GDispatchWnd <> 0;
end;

function Win32ShellPost(AProc: TWin32PostProc; AData: Pointer): Boolean; inline;
begin
  if not Assigned(AProc) then Exit(False);
  if EnsureDispatchWnd then
    if PostMessageW(GDispatchWnd, WM_WV_DISPATCH, WPARAM(AProc), LPARAM(AData)) then
      Exit(True);
  // fallback: direct sync execution (no message loop yet or PostMessage failed)
  try AProc(AData); except end;
  Result := True;
end;

procedure Win32ShellFocus(AWin: Pointer); inline;
begin
  if AWin = nil then Exit;
  SetForegroundWindow(HWND(AWin));
  SetFocus(HWND(AWin));
end;

function Win32ShellNativeHandle(AWin: Pointer): Pointer; inline;
begin
  Result := AWin;
end;

procedure Win32ShellRunMainLoop;
var
  Msg: TMsg;
begin
  GMainLoopRunning := True;
  try
    while GetMessageW(Msg, 0, 0, 0) do
    begin
      TranslateMessage(Msg);
      DispatchMessageW(Msg);
      if GWinCount <= 0 then Break;
    end;
  finally
    GMainLoopRunning := False;
  end;
end;

procedure Win32ShellQuitMainLoop;
begin
  if GMainLoopRunning then
    PostQuitMessage(0);
end;

function Win32ShellIsMainLoopRunning: Boolean; inline;
begin
  Result := GMainLoopRunning;
end;

{$ELSE}
{ Linux / 非 Windows 桩：零代价、编译期可达，行为与不可用后端一致 }
var
  GRunning: Boolean = False;
  GScaleStub: TWin32ScaleChangedProc = nil;
  GResizeStub: TWin32ResizeProc = nil;
function Win32ShellInit: Boolean; begin Result := False; end;
function Win32ShellCreate(const AGeometry: TWin32ShellGeometry): Pointer; begin Result := nil; end;
procedure Win32ShellSetTitle(AWin: Pointer; const ATitle: string); inline; begin end;
procedure Win32ShellResize(AWin: Pointer; AW, AH: Integer); inline; begin end;
procedure Win32ShellShow(AWin: Pointer); inline; begin end;
procedure Win32ShellHide(AWin: Pointer); inline; begin end;
procedure Win32ShellDestroy(AWin: Pointer); inline; begin end;
function Win32ShellIsVisible(AWin: Pointer): Boolean; inline; begin Result := False; end;
function Win32ShellIsMaximized(AWin: Pointer): Boolean; inline; begin Result := False; end;
procedure Win32ShellMaximize(AWin: Pointer); inline; begin end;
procedure Win32ShellUnmaximize(AWin: Pointer); inline; begin end;
procedure Win32ShellMinimize(AWin: Pointer); inline; begin end;
procedure Win32ShellRestore(AWin: Pointer); inline; begin end;
function Win32ShellIsMinimized(AWin: Pointer): Boolean; inline; begin Result := False; end;
function Win32ShellScaleFactor(AWin: Pointer): Double; inline; begin Result := 1.0; end;
procedure Win32ShellOnScaleChanged(AHandler: TWin32ScaleChangedProc); inline; begin GScaleStub := AHandler; end;
procedure Win32ShellOnResize(AHandler: TWin32ResizeProc); inline; begin GResizeStub := AHandler; end;
function Win32ShellClientSize(AWin: Pointer; out AWidth, AHeight: Integer): Boolean; inline; begin AWidth:=0; AHeight:=0; Result:=False; end;
function Win32ShellPost(AProc: TWin32PostProc; AData: Pointer): Boolean; inline; begin if Assigned(AProc) then try AProc(AData); except end; Result := Assigned(AProc); end;
procedure Win32ShellFocus(AWin: Pointer); inline; begin end;
function Win32ShellNativeHandle(AWin: Pointer): Pointer; inline; begin Result := AWin; end;
procedure Win32ShellRunMainLoop; begin GRunning := True; GRunning := False; end;
procedure Win32ShellQuitMainLoop; begin end;
function Win32ShellIsMainLoopRunning: Boolean; inline; begin Result := GRunning; end;
{$ENDIF}

end.