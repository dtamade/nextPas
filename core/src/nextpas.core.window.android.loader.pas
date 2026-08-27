unit nextpas.core.window.android.loader;

{** @desc Android 动态装载（家族内唯一触 platform.dl 的单元）。
       原语一律来自 nextpas.core.platform.dl，禁用 FPC DynLibs。

       宿主非 Android 时诚实失败（Loaded=False）。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.platform.dl,
  nextpas.core.window.android.ffi;

type
  TWindowAndroidLoadInfo = record
    Loaded: Boolean;
  end;

function TryLoadWindowAndroid(out AInfo: TWindowAndroidLoadInfo): Boolean;
procedure UnloadWindowAndroid;
function WindowAndroidLoadInfo: TWindowAndroidLoadInfo;
function WindowAndroidIsLoaded: Boolean;

implementation

var
  GLoaded: Boolean = False;
  GLoading: Boolean = False;
  GInfo: TWindowAndroidLoadInfo;
  GAndroidLib: TPlatformLibrary;

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
  if GAndroidLib.Sym(PAnsiChar(AName), LAddr) = 0 then
  begin
    PPointer(AVarAddr)^ := LAddr;
    Exit(True);
  end;
  Result := False;
end;

procedure ReleaseAll;
begin
  platform_dl_release(GAndroidLib);
end;

function TryLoadWindowAndroid(out AInfo: TWindowAndroidLoadInfo): Boolean;

  function BindAll: Boolean;
  begin
    Result :=
      BindReq(@ANativeWindow_getWidth, 'ANativeWindow_getWidth') and
      BindReq(@ANativeWindow_getHeight, 'ANativeWindow_getHeight') and
      BindReq(@ANativeWindow_setBuffersGeometry, 'ANativeWindow_setBuffersGeometry');
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
    if not TryDlOpen(GAndroidLib, ['libandroid.so', 'libnativewindow.so']) then
    begin
      Exit(False);
    end;
    if not BindAll then
    begin
      ReleaseAll;
      Exit(False);
    end;
    GLoaded := True;
    GInfo.Loaded := True;
    AInfo := GInfo;
    Result := True;
  finally
    GLoading := False;
  end;
end;

procedure UnloadWindowAndroid;
begin
  if not GLoaded then Exit;
  ReleaseAll;
  GLoaded := False;
  GInfo := Default(TWindowAndroidLoadInfo);
end;

function WindowAndroidLoadInfo: TWindowAndroidLoadInfo;
begin
  Result := GInfo;
end;

function WindowAndroidIsLoaded: Boolean;
begin
  Result := GLoaded;
end;

end.
