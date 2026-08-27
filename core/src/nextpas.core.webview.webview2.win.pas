unit nextpas.core.webview.webview2.win;

{** @desc Win32 窗口壳内部缝：create/title/geometry/state/focus/loop 的
       薄函数式封装。签名不含任何 webview 概念、只依赖 Windows API
       （或 Linux 桩），与 gtk.win 对称——为未来 nextpas.core.window
       独立模块的抽取预备缝第二极：Win32 缝 + GTK 缝同构，消费方无感。

       立场：不做策略决策（布局/默认值归调用方），只做机械转发与
       句柄纪律（ShowWindow 统一出口、WM_DESTROY 幂等 Quit 等）。 *}

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

function Win32ShellInit: Boolean;
function Win32ShellCreate(const AGeometry: TWin32ShellGeometry): Pointer;
procedure Win32ShellSetTitle(AWin: Pointer; const ATitle: string);
procedure Win32ShellResize(AWin: Pointer; AW, AH: Integer);
procedure Win32ShellShow(AWin: Pointer);
procedure Win32ShellHide(AWin: Pointer);
procedure Win32ShellDestroy(AWin: Pointer);
function Win32ShellIsVisible(AWin: Pointer): Boolean;
function Win32ShellIsMaximized(AWin: Pointer): Boolean;
procedure Win32ShellMaximize(AWin: Pointer);
procedure Win32ShellUnmaximize(AWin: Pointer);
function Win32ShellScaleFactor(AWin: Pointer): Integer;
procedure Win32ShellFocus(AWin: Pointer);
function Win32ShellNativeHandle(AWin: Pointer): Pointer;
procedure Win32ShellRunMainLoop;
procedure Win32ShellQuitMainLoop;
function Win32ShellIsMainLoopRunning: Boolean;

implementation

{$IFDEF MSWINDOWS}
uses
  Windows, Messages;

const
  CLASS_NAME = 'NextPasWebView2Win';
  WIN_STYLE_RESIZABLE = WS_OVERLAPPEDWINDOW;
  WIN_STYLE_FIXED     = WS_OVERLAPPED or WS_CAPTION or WS_SYSMENU or WS_MINIMIZEBOX;

var
  GRegistered: Boolean = False;
  GMainLoopRunning: Boolean = False;
  GWinCount: Integer = 0;

function WndProc(AWnd: HWND; AMsg: UINT; AWParam: WPARAM; ALParam: LPARAM): LRESULT; stdcall;
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

procedure Win32ShellSetTitle(AWin: Pointer; const ATitle: string);
begin
  if AWin = nil then Exit;
  SetWindowTextW(HWND(AWin), PWideChar(WideString(ATitle)));
end;

procedure Win32ShellResize(AWin: Pointer; AW, AH: Integer);
begin
  if AWin = nil then Exit;
  SetWindowPos(HWND(AWin), 0, 0, 0, AW, AH, SWP_NOMOVE or SWP_NOZORDER);
end;

procedure Win32ShellShow(AWin: Pointer);
begin
  if AWin = nil then Exit;
  ShowWindow(HWND(AWin), SW_SHOW);
  UpdateWindow(HWND(AWin));
end;

procedure Win32ShellHide(AWin: Pointer);
begin
  if AWin = nil then Exit;
  ShowWindow(HWND(AWin), SW_HIDE);
end;

procedure Win32ShellDestroy(AWin: Pointer);
begin
  if AWin = nil then Exit;
  DestroyWindow(HWND(AWin));
end;

function Win32ShellIsVisible(AWin: Pointer): Boolean;
begin
  Result := (AWin <> nil) and IsWindowVisible(HWND(AWin));
end;

function Win32ShellIsMaximized(AWin: Pointer): Boolean;
begin
  Result := (AWin <> nil) and (IsZoomed(HWND(AWin)));
end;

procedure Win32ShellMaximize(AWin: Pointer);
begin
  if AWin = nil then Exit;
  ShowWindow(HWND(AWin), SW_MAXIMIZE);
end;

procedure Win32ShellUnmaximize(AWin: Pointer);
begin
  if AWin = nil then Exit;
  ShowWindow(HWND(AWin), SW_RESTORE);
end;

function Win32ShellScaleFactor(AWin: Pointer): Integer;
var
  DC: HDC;
begin
  if AWin = nil then Exit(1);
  {$IFDEF HAS_GETDPIFORWINDOW}
  // Windows 10 1607+ : GetDpiForWindow
  {$ENDIF}
  DC := GetDC(HWND(AWin));
  try
    Result := GetDeviceCaps(DC, LOGPIXELSX) div 96;
    if Result < 1 then Result := 1;
  finally
    ReleaseDC(HWND(AWin), DC);
  end;
end;

procedure Win32ShellFocus(AWin: Pointer);
begin
  if AWin = nil then Exit;
  SetForegroundWindow(HWND(AWin));
  SetFocus(HWND(AWin));
end;

function Win32ShellNativeHandle(AWin: Pointer): Pointer;
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

function Win32ShellIsMainLoopRunning: Boolean;
begin
  Result := GMainLoopRunning;
end;

{$ELSE}
{ Linux / 非 Windows 桩：零代价、编译期可达，行为与不可用后端一致 }
var
  GRunning: Boolean = False;
function Win32ShellInit: Boolean; begin Result := False; end;
function Win32ShellCreate(const AGeometry: TWin32ShellGeometry): Pointer; begin Result := nil; end;
procedure Win32ShellSetTitle(AWin: Pointer; const ATitle: string); begin end;
procedure Win32ShellResize(AWin: Pointer; AW, AH: Integer); begin end;
procedure Win32ShellShow(AWin: Pointer); begin end;
procedure Win32ShellHide(AWin: Pointer); begin end;
procedure Win32ShellDestroy(AWin: Pointer); begin end;
function Win32ShellIsVisible(AWin: Pointer): Boolean; begin Result := False; end;
function Win32ShellIsMaximized(AWin: Pointer): Boolean; begin Result := False; end;
procedure Win32ShellMaximize(AWin: Pointer); begin end;
procedure Win32ShellUnmaximize(AWin: Pointer); begin end;
function Win32ShellScaleFactor(AWin: Pointer): Integer; begin Result := 1; end;
procedure Win32ShellFocus(AWin: Pointer); begin end;
function Win32ShellNativeHandle(AWin: Pointer): Pointer; begin Result := AWin; end;
procedure Win32ShellRunMainLoop; begin GRunning := True; GRunning := False; end;
procedure Win32ShellQuitMainLoop; begin end;
function Win32ShellIsMainLoopRunning: Boolean; begin Result := GRunning; end;
{$ENDIF}

end.
