unit nextpas.core.qt.loader;

{** @desc 自包装 C shim 动态装载（家族内唯一触 platform.dl 的单元）。
       原语一律来自 nextpas.core.platform.dl，禁用 FPC DynLibs。

       探测 sonames：
         ['libnextpas-qt.so','libnextpas-qt.so.1']
       桩阶段全部符号以 BindOpt 绑定（deferred，缺席不报错）；
       Loaded 仅当主库加载成功时为 True，符号缺席不影响 Loaded。
       装载结果进程级幂等。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.platform.dl,
  nextpas.core.qt.ffi;

type
  TQtLoadInfo = record
    Loaded: Boolean;
    Soname: string;
  end;

function TryLoadQt(out AInfo: TQtLoadInfo): Boolean;
procedure UnloadQt;
function QtLoadInfo: TQtLoadInfo;
function QtIsLoaded: Boolean;

implementation

var
  GLoaded: Boolean = False;
  GLoading: Boolean = False;
  GInfo: TQtLoadInfo;
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

function BindOpt(AVarAddr: Pointer; const AName: string): Boolean;
var
  LAddr: Pointer;
begin
  if Sym(PAnsiChar(AName), LAddr) then
    PPointer(AVarAddr)^ := LAddr
  else
    PPointer(AVarAddr)^ := nil;
  Result := True;
end;

procedure ReleaseAll;
begin
  platform_dl_release(GLib);
  GSonameHit := '';
end;

function TryLoadQt(out AInfo: TQtLoadInfo): Boolean;

  procedure BindAllOpt;
  begin
    BindOpt(@qt_app_create, 'qt_app_create');
    BindOpt(@qt_app_destroy, 'qt_app_destroy');
    BindOpt(@qt_app_run, 'qt_app_run');
    BindOpt(@qt_app_quit, 'qt_app_quit');
    BindOpt(@qt_window_create, 'qt_window_create');
    BindOpt(@qt_window_destroy, 'qt_window_destroy');
    BindOpt(@qt_window_set_title, 'qt_window_set_title');
    BindOpt(@qt_window_get_title, 'qt_window_get_title');
    BindOpt(@qt_window_set_bounds, 'qt_window_set_bounds');
    BindOpt(@qt_window_get_bounds, 'qt_window_get_bounds');
    BindOpt(@qt_window_show, 'qt_window_show');
    BindOpt(@qt_window_hide, 'qt_window_hide');
    BindOpt(@qt_window_close, 'qt_window_close');
    BindOpt(@qt_window_is_visible, 'qt_window_is_visible');
    BindOpt(@qt_window_get_scale, 'qt_window_get_scale');
    BindOpt(@qt_window_get_native_handle, 'qt_window_get_native_handle');
    BindOpt(@qt_dispatcher_post, 'qt_dispatcher_post');
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
    if not TryDlOpen(GLib, ['libnextpas-qt.so','libnextpas-qt.so.1'], GSonameHit) then
    begin
      ReleaseAll;
      Exit(False);
    end;
    BindAllOpt;
    GLoaded := True;
    GInfo.Loaded := True;
    GInfo.Soname := GSonameHit;
    AInfo := GInfo;
    Result := True;
  finally
    GLoading := False;
  end;
end;

procedure UnloadQt;
begin
  if not GLoaded then Exit;
  ReleaseAll;
  GLoaded := False;
  GInfo := Default(TQtLoadInfo);
end;

function QtLoadInfo: TQtLoadInfo;
begin
  Result := GInfo;
end;

function QtIsLoaded: Boolean;
begin
  Result := GLoaded;
end;

end.
