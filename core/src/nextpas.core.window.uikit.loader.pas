unit nextpas.core.window.uikit.loader;

{** @desc UIKit 动态装载（家族内唯一触 platform.dl 的单元）。
       原语一律来自 nextpas.core.platform.dl，禁用 FPC DynLibs。

       非 iOS 宿主上诚实失败（Loaded=False）。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.platform.dl,
  nextpas.core.window.uikit.ffi;

type
  TWindowUIKitLoadInfo = record
    Loaded: Boolean;
  end;

function TryLoadWindowUIKit(out AInfo: TWindowUIKitLoadInfo): Boolean;
procedure UnloadWindowUIKit;
function WindowUIKitLoadInfo: TWindowUIKitLoadInfo;
function WindowUIKitIsLoaded: Boolean;
const
  WINDOW_UIKIT_SONAMES = 'libUIKit.so|UIKit.framework';
function WindowUIKitSonames: string; inline;

implementation

var
  GLoaded: Boolean = False;
  GLoading: Boolean = False;
  GInfo: TWindowUIKitLoadInfo;
  GUIKitLib: TPlatformLibrary;

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
  if GUIKitLib.Sym(PAnsiChar(AName), LAddr) = 0 then
  begin
    PPointer(AVarAddr)^ := LAddr;
    Exit(True);
  end;
  Result := False;
end;

procedure ReleaseAll;
begin
  platform_dl_release(GUIKitLib);
end;

function TryLoadWindowUIKit(out AInfo: TWindowUIKitLoadInfo): Boolean;

  function BindAll: Boolean;
  begin
    Result :=
      BindReq(@UIWindow_getBounds, 'UIWindow_getBounds');
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
    if not TryDlOpen(GUIKitLib, ['libUIKit.so', '/System/Library/Frameworks/UIKit.framework/UIKit']) then
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

procedure UnloadWindowUIKit;
begin
  if not GLoaded then Exit;
  ReleaseAll;
  GLoaded := False;
  GInfo := Default(TWindowUIKitLoadInfo);
end;

function WindowUIKitLoadInfo: TWindowUIKitLoadInfo;
begin
  Result := GInfo;
end;

function WindowUIKitIsLoaded: Boolean;
begin
  Result := GLoaded;
end;

function WindowUIKitSonames: string; inline;
begin
  Result := WINDOW_UIKIT_SONAMES;
end;

end.
