unit nextpas.core.window.sdl2.loader;

{** @desc SDL2 窗口子集动态装载（家族内唯一触 platform.dl 的单元）。
       绑定 SDL_CreateWindow 族与事件泵所需符号；缺席符号诚实降级。
       SDL_GetWindowDisplayScale 为可选（≥2.24），缺席时置 nil 并回退 1.0。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.platform.dl,
  nextpas.core.window.sdl2.ffi;

type
  TWindowSdl2LoadInfo = record
    Loaded: Boolean;
    HasDisplayScale: Boolean;
  end;

function TryLoadWindowSdl2(out AInfo: TWindowSdl2LoadInfo): Boolean;
procedure UnloadWindowSdl2;
function WindowSdl2LoadInfo: TWindowSdl2LoadInfo;
function WindowSdl2IsLoaded: Boolean;
const
  WINDOW_SDL2_SONAMES = 'libSDL2-2.0.so.0|libSDL2.so|libSDL2.so.0';
function WindowSdl2Sonames: string; inline;

implementation

var
  GLoaded: Boolean = False;
  GLoading: Boolean = False;
  GInfo: TWindowSdl2LoadInfo;
  GSdlLib: TPlatformLibrary;

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
  if GSdlLib.Sym(PAnsiChar(AName), LAddr) = 0 then
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
  if GSdlLib.Sym(PAnsiChar(AName), LAddr) = 0 then
  begin
    PPointer(AVarAddr)^ := LAddr;
    Exit(True);
  end;
  PPointer(AVarAddr)^ := nil;
  Result := False;
end;

procedure ReleaseAll;
begin
  platform_dl_release(GSdlLib);
  SDL_GetWindowDisplayScale := nil;
  SDL_WaitEvent := nil;
  SDL_WaitEventTimeout := nil;
end;

function TryLoadWindowSdl2(out AInfo: TWindowSdl2LoadInfo): Boolean;

  function BindAll: Boolean;
  begin
    Result :=
      BindReq(@SDL_Init, 'SDL_Init') and
      BindReq(@SDL_QuitProc, 'SDL_Quit') and
      BindReq(@SDL_GetError, 'SDL_GetError') and
      BindReq(@SDL_CreateWindow, 'SDL_CreateWindow') and
      BindReq(@SDL_DestroyWindow, 'SDL_DestroyWindow') and
      BindReq(@SDL_ShowWindow, 'SDL_ShowWindow') and
      BindReq(@SDL_HideWindow, 'SDL_HideWindow') and
      BindReq(@SDL_SetWindowTitle, 'SDL_SetWindowTitle') and
      BindReq(@SDL_GetWindowTitle, 'SDL_GetWindowTitle') and
      BindReq(@SDL_SetWindowSize, 'SDL_SetWindowSize') and
      BindReq(@SDL_GetWindowSize, 'SDL_GetWindowSize') and
      BindReq(@SDL_SetWindowMinimumSize, 'SDL_SetWindowMinimumSize') and
      BindReq(@SDL_SetWindowMaximumSize, 'SDL_SetWindowMaximumSize') and
      BindReq(@SDL_SetWindowResizable, 'SDL_SetWindowResizable') and
      BindReq(@SDL_MaximizeWindow, 'SDL_MaximizeWindow') and
      BindReq(@SDL_MinimizeWindow, 'SDL_MinimizeWindow') and
      BindReq(@SDL_RestoreWindow, 'SDL_RestoreWindow') and
      BindReq(@SDL_GetWindowFlags, 'SDL_GetWindowFlags') and
      BindReq(@SDL_GetWindowID, 'SDL_GetWindowID') and
      BindReq(@SDL_GetWindowFromID, 'SDL_GetWindowFromID') and
      BindReq(@SDL_GetWindowDisplayIndex, 'SDL_GetWindowDisplayIndex') and
      BindReq(@SDL_GetWindowWMInfo, 'SDL_GetWindowWMInfo') and
      BindReq(@SDL_PollEvent, 'SDL_PollEvent') and
      BindReq(@SDL_PushEvent, 'SDL_PushEvent') and
      BindReq(@SDL_RegisterEvents, 'SDL_RegisterEvents');
    // Optional (industry blocking wait)
    BindOpt(@SDL_WaitEvent, 'SDL_WaitEvent');
    BindOpt(@SDL_WaitEventTimeout, 'SDL_WaitEventTimeout');
    BindOpt(@SDL_GetWindowDisplayScale, 'SDL_GetWindowDisplayScale');
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
    if not TryDlOpen(GSdlLib, ['libSDL2-2.0.so.0', 'libSDL2.so', 'libSDL2.so.0']) then
    begin
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
    GInfo.HasDisplayScale := Assigned(SDL_GetWindowDisplayScale);
    AInfo := GInfo;
    Result := True;
  finally
    GLoading := False;
  end;
end;

procedure UnloadWindowSdl2;
begin
  if not GLoaded then Exit;
  ReleaseAll;
  GLoaded := False;
  GInfo := Default(TWindowSdl2LoadInfo);
end;

function WindowSdl2LoadInfo: TWindowSdl2LoadInfo;
begin
  Result := GInfo;
end;

function WindowSdl2IsLoaded: Boolean;
begin
  Result := GLoaded;
end;

function WindowSdl2Sonames: string; inline;
begin
  // 单源：与 TryDlOpen 数组同源，registry 诊断经此零拷贝 inline 转发，零重复字面量
  Result := WINDOW_SDL2_SONAMES;
end;

end.
