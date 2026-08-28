unit nextpas.core.qt5pas.loader;

{** @desc libQt5Pas.so 动态装载（家族内唯一触 platform.dl 的单元）。
       原语一律来自 nextpas.core.platform.dl，禁用 FPC DynLibs。

       探测 sonames 按 Lazarus 发行顺序：
         ['libQt5Pas.so.1','libQt5Pas.so','libQt5Pas.so.1.2.14']
       窗口必需符号以 BindReq 绑定，缺一即视为不可用；QWindow 可选路径
       若缺席不影响 Loaded 判定。装载结果进程级幂等。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.platform.dl,
  nextpas.core.qt5pas.ffi;

type
  TQt5PasLoadInfo = record
    Loaded: Boolean;
    Soname: string;
  end;

function TryLoadQt5Pas(out AInfo: TQt5PasLoadInfo): Boolean;
procedure UnloadQt5Pas;
function Qt5PasLoadInfo: TQt5PasLoadInfo;
function Qt5PasIsLoaded: Boolean;

implementation

var
  GLoaded: Boolean = False;
  GLoading: Boolean = False;
  GInfo: TQt5PasLoadInfo;
  GLib: TPlatformLibrary;
  GSonameHit: string = '';

function TryDlOpen(var ALib: TPlatformLibrary; const ASonames: array of string; out AHit: string): Boolean;
var
  I: Integer;
begin
  AHit := '';
  for I := 0 to High(ASonames) do
    if platform_dl_load(ASonames[I], [dlfLazy, dlfGlobal], ALib) then
    begin
      AHit := ASonames[I];
      Exit(True);
    end;
  Result := False;
end;

function Sym(const AName: PAnsiChar; out AAddr: Pointer): Boolean;
begin
  if not GLib.IsValid then
    Exit(False);
  Result := GLib.Sym(AName, AAddr) = 0;
end;

function BindReq(AVarAddr: Pointer; const AName: string): Boolean;
begin
  Result := Sym(PAnsiChar(AName), PPointer(AVarAddr)^);
end;

function BindOpt(AVarAddr: Pointer; const AName: string): Boolean;
var
  LAddr: Pointer;
begin
  if Sym(PAnsiChar(AName), LAddr) then
  begin
    PPointer(AVarAddr)^ := LAddr;
    Exit(True);
  end;
  PPointer(AVarAddr)^ := nil;
  Result := True;
end;

procedure ReleaseAll;
begin
  platform_dl_release(GLib);
  GSonameHit := '';
end;

function TryLoadQt5Pas(out AInfo: TQt5PasLoadInfo): Boolean;

  function BindAll: Boolean;
  begin
    Result :=
      BindReq(@QApplication_create, 'QApplication_create') and
      BindReq(@QApplication_destroy, 'QApplication_destroy') and
      BindReq(@QApplication_exec, 'QApplication_exec') and
      BindReq(@QApplication_quit, 'QApplication_quit') and
      BindReq(@QWidget_create, 'QWidget_create') and
      BindReq(@QWidget_setWindowTitle, 'QWidget_setWindowTitle') and
      BindReq(@QWidget_windowTitle, 'QWidget_windowTitle') and
      BindReq(@QWidget_resize, 'QWidget_resize') and
      BindReq(@QWidget_show, 'QWidget_show') and
      BindReq(@QWidget_hide, 'QWidget_hide') and
      BindReq(@QWidget_close, 'QWidget_close') and
      BindReq(@QWidget_destroy, 'QWidget_destroy') and
      BindReq(@QWidget_winId, 'QWidget_winId') and
      BindReq(@QWidget_isVisible, 'QWidget_isVisible');
    // QWindow 与 hook 为可选增强，不计入必需集
    BindOpt(@QWindow_create, 'QWindow_create');
    BindOpt(@QApplication_hook_create, 'QApplication_hook_create');
    BindOpt(@QWidget_hook_create, 'QWidget_hook_create');
    BindOpt(@Hook_destroy, 'Hook_destroy');
  end;

begin
  if GLoaded then
  begin
    AInfo := GInfo;
    Exit(True);
  end;
  if GLoading then
    Exit(False);
  FillChar(AInfo, SizeOf(AInfo), 0);
  GLoading := True;
  try
    if not TryDlOpen(GLib, ['libQt5Pas.so.1','libQt5Pas.so','libQt5Pas.so.1.2.14'], GSonameHit) then
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
    GInfo.Soname := GSonameHit;
    AInfo := GInfo;
    Result := True;
  finally
    GLoading := False;
  end;
end;

procedure UnloadQt5Pas;
begin
  if not GLoaded then Exit;
  ReleaseAll;
  GLoaded := False;
  GInfo := Default(TQt5PasLoadInfo);
end;

function Qt5PasLoadInfo: TQt5PasLoadInfo;
begin
  Result := GInfo;
end;

function Qt5PasIsLoaded: Boolean;
begin
  Result := GLoaded;
end;

end.
