unit nextpas.core.window.win32.loader;

{** @desc Win32 窗口子集动态装载（家族内唯一触 platform.dl 的单元）。
       原语一律来自 nextpas.core.platform.dl，禁用 FPC DynLibs。

       Windows 上尝试装载 user32.dll + kernel32；其他宿主诚实失败
       （LoadInfo.Loaded=False，探测降级）。GetDpiForWindow 为可选
       （Win8.1+），缺席回退 96 DPI。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.platform.dl,
  nextpas.core.window.win32.ffi;

type
  TWindowWin32LoadInfo = record
    Loaded: Boolean;
    HasGetDpiForWindow: Boolean;
  end;

function TryLoadWindowWin32(out AInfo: TWindowWin32LoadInfo): Boolean;
procedure UnloadWindowWin32;
function WindowWin32LoadInfo: TWindowWin32LoadInfo;
function WindowWin32IsLoaded: Boolean;

implementation

var
  GLoaded: Boolean = False;
  GLoading: Boolean = False;
  GInfo: TWindowWin32LoadInfo;
  GUser32, GKernel32: TPlatformLibrary;

function TryDlOpen(var ALib: TPlatformLibrary; const ASonames: array of string): Boolean;
var
  I: Integer;
begin
  for I := 0 to High(ASonames) do
    if platform_dl_load(ASonames[I], [dlfLazy, dlfGlobal], ALib) then
      Exit(True);
  Result := False;
end;

function BindReq(AVarAddr: Pointer; const AName: string): Boolean;
var
  LAddr: Pointer;
begin
  if GUser32.Sym(PAnsiChar(AName), LAddr) = 0 then
  begin
    PPointer(AVarAddr)^ := LAddr;
    Exit(True);
  end;
  if GKernel32.Sym(PAnsiChar(AName), LAddr) = 0 then
  begin
    PPointer(AVarAddr)^ := LAddr;
    Exit(True);
  end;
  Result := False;
end;

function BindOpt(AVarAddr: Pointer; const AName: string): Boolean;
var
  LAddr: Pointer;
begin
  if GUser32.Sym(PAnsiChar(AName), LAddr) = 0 then
  begin
    PPointer(AVarAddr)^ := LAddr;
    Exit(True);
  end;
  if GKernel32.Sym(PAnsiChar(AName), LAddr) = 0 then
  begin
    PPointer(AVarAddr)^ := LAddr;
    Exit(True);
  end;
  PPointer(AVarAddr)^ := nil;
  Result := False;
end;

procedure ReleaseAll;
begin
  platform_dl_release(GUser32);
  platform_dl_release(GKernel32);
  GetDpiForWindow := nil;
  WaitMessage := nil;
end;

function TryLoadWindowWin32(out AInfo: TWindowWin32LoadInfo): Boolean;

  function BindAll: Boolean;
  begin
    Result :=
      BindReq(@RegisterClassExA, 'RegisterClassExA') and
      BindReq(@CreateWindowExA, 'CreateWindowExA') and
      BindReq(@DefWindowProcA, 'DefWindowProcA') and
      BindReq(@DestroyWindow, 'DestroyWindow') and
      BindReq(@ShowWindow, 'ShowWindow') and
      BindReq(@IsWindowVisible, 'IsWindowVisible') and
      BindReq(@IsIconic, 'IsIconic') and
      BindReq(@IsZoomed, 'IsZoomed') and
      BindReq(@SetWindowTextA, 'SetWindowTextA') and
      BindReq(@GetWindowTextA, 'GetWindowTextA') and
      BindReq(@GetClientRect, 'GetClientRect') and
      BindReq(@GetWindowRect, 'GetWindowRect') and
      BindReq(@MoveWindow, 'MoveWindow') and
      BindReq(@SetWindowPos, 'SetWindowPos') and
      BindReq(@GetModuleHandleA, 'GetModuleHandleA') and
      BindReq(@LoadCursorA, 'LoadCursorA') and
      BindReq(@PostMessageA, 'PostMessageA') and
      BindReq(@PostQuitMessage, 'PostQuitMessage') and
      BindReq(@GetMessageA, 'GetMessageA') and
      BindReq(@PeekMessageA, 'PeekMessageA') and
      BindReq(@TranslateMessage, 'TranslateMessage') and
      BindReq(@DispatchMessageA, 'DispatchMessageA') and
      BindReq(@SetWindowLongPtrA, 'SetWindowLongPtrA') and
      BindReq(@GetWindowLongPtrA, 'GetWindowLongPtrA');
    BindOpt(@GetDpiForWindow, 'GetDpiForWindow');
    BindOpt(@WaitMessage, 'WaitMessage');
  end;

begin
  if GLoaded then
  begin
    AInfo := GInfo;
    Exit(True);
  end;
  if GLoading then Exit(False);
  FillChar(AInfo, SizeOf(AInfo), 0);
  GLoading := True;
  try
    if not (TryDlOpen(GUser32, ['user32.dll']) and
            TryDlOpen(GKernel32, ['kernel32.dll'])) then
    begin
      // On Linux, these sonames won't exist → honest unavailable
      ReleaseAll;
      Exit(False);
    end;
    if not BindAll then
    begin
      ReleaseAll;
      Exit(False);
    end;
    GLoaded := True;
    GInfo.Loaded := True;
    GInfo.HasGetDpiForWindow := Assigned(GetDpiForWindow);
    AInfo := GInfo;
    Result := True;
  finally
    GLoading := False;
  end;
end;

procedure UnloadWindowWin32;
begin
  if not GLoaded then Exit;
  ReleaseAll;
  GLoaded := False;
  GInfo := Default(TWindowWin32LoadInfo);
end;

function WindowWin32LoadInfo: TWindowWin32LoadInfo;
begin
  Result := GInfo;
end;

function WindowWin32IsLoaded: Boolean;
begin
  Result := GLoaded;
end;

end.
