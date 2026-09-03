unit nextpas.core.gtk3.loader;

{** @desc GTK3 动态装载（家族内唯一触 platform.dl 的单元）。
       原语一律来自 nextpas.core.platform.dl，禁用 FPC DynLibs。

       探测仅装载 GTK3 栈（libgtk-3 / libgobject-2.0 / libglib-2.0），
       不触 WebKit/JSC。能力以符号存在性判定，装载结果进程级幂等。

       依赖方向：ffi → loader；sonames 见实现。 *}

{$I nextpas.core.settings.inc}
{$IF 0}
{$mode objfpc}{$H+}
{$ENDIF}

interface

uses
  nextpas.core.platform.dl,
  nextpas.core.gtk3.ffi;

type
  {** 装载结果（与 window.gtk 兼容布局） *}
  TGtk3LoadInfo = record
    Loaded: Boolean;
  end;
  {** 兼容别名：window 侧历史名称 *}
  TWindowGtkLoadInfo = TGtk3LoadInfo;

{** @desc 尝试装载 GTK3 栈，幂等
    @return True 已装载（或本次成功装载） *}
function TryLoadGtk3(out AInfo: TGtk3LoadInfo): Boolean;
{** @desc 卸载已装载的 GTK3 栈 *}
procedure UnloadGtk3;
{** @desc 返回当前装载信息（未装载时 Loaded=False） *}
function Gtk3LoadInfo: TGtk3LoadInfo;
{** @desc 是否已装载 *}
function Gtk3IsLoaded: Boolean;
const
  GTK3_SONAMES = 'libgtk-3.so.0|libgtk-3.so';
  GTK3_GOBJECT_SONAME = 'libgobject-2.0.so.0';
  GTK3_GLIB_SONAME = 'libglib-2.0.so.0';
function Gtk3Sonames: string; inline;

{** 兼容包装：window.gtk 历史 API（inline 转发） *}
function TryLoadWindowGtk(out AInfo: TWindowGtkLoadInfo): Boolean; inline;
procedure UnloadWindowGtk; inline;
function WindowGtkLoadInfo: TWindowGtkLoadInfo; inline;
function WindowGtkIsLoaded: Boolean; inline;

implementation

var
  GLoaded: Boolean = False;
  GLoading: Boolean = False;
  GInfo: TGtk3LoadInfo;
  GGtkLib, GGobjectLib, GGlibLib: TPlatformLibrary;

function TryDlOpen(var ALib: TPlatformLibrary; const ASonames: array of string): Boolean;
var
  I: Integer;
begin
  for I := 0 to High(ASonames) do
    if platform_dl_load(ASonames[I], [dlfLazy, dlfGlobal], ALib) then
      Exit(True);
  Result := False;
end;

function Sym(const AName: PAnsiChar; out AAddr: Pointer): Boolean;
var
  LLibs: array[0..2] of ^TPlatformLibrary;
  I: Integer;
begin
  LLibs[0] := @GGtkLib;
  LLibs[1] := @GGobjectLib;
  LLibs[2] := @GGlibLib;
  for I := 0 to High(LLibs) do
    if LLibs[I]^.IsValid then
      if LLibs[I]^.Sym(AName, AAddr) = 0 then
        Exit(True);
  Result := False;
end;

function BindReq(AVarAddr: Pointer; const AName: string): Boolean;
begin
  Result := Sym(PAnsiChar(AName), PPointer(AVarAddr)^);
end;

procedure ReleaseAll;
begin
  platform_dl_release(GGtkLib);
  platform_dl_release(GGobjectLib);
  platform_dl_release(GGlibLib);
end;

function TryLoadGtk3(out AInfo: TGtk3LoadInfo): Boolean;

  function BindAll: Boolean;
  begin
    Result :=
      BindReq(@g_idle_add_full, 'g_idle_add_full') and
      BindReq(@g_source_remove, 'g_source_remove') and
      BindReq(@g_signal_connect_data, 'g_signal_connect_data') and
      BindReq(@g_signal_handler_disconnect, 'g_signal_handler_disconnect') and
      BindReq(@g_timeout_add, 'g_timeout_add') and
      BindReq(@g_object_unref, 'g_object_unref') and
      BindReq(@gtk_init_check, 'gtk_init_check') and
      BindReq(@gtk_window_new, 'gtk_window_new') and
      BindReq(@gtk_window_set_title, 'gtk_window_set_title') and
      BindReq(@gtk_window_get_title, 'gtk_window_get_title') and
      BindReq(@gtk_window_set_default_size, 'gtk_window_set_default_size') and
      BindReq(@gtk_window_set_resizable, 'gtk_window_set_resizable') and
      BindReq(@gtk_window_resize, 'gtk_window_resize') and
      BindReq(@gtk_window_maximize, 'gtk_window_maximize') and
      BindReq(@gtk_window_unmaximize, 'gtk_window_unmaximize') and
      BindReq(@gtk_window_iconify, 'gtk_window_iconify') and
      BindReq(@gtk_window_deiconify, 'gtk_window_deiconify') and
      BindReq(@gtk_window_is_maximized, 'gtk_window_is_maximized') and
      BindReq(@gtk_widget_show_all, 'gtk_widget_show_all') and
      BindReq(@gtk_widget_hide, 'gtk_widget_hide') and
      BindReq(@gtk_widget_get_visible, 'gtk_widget_get_visible') and
      BindReq(@gtk_widget_get_scale_factor, 'gtk_widget_get_scale_factor') and
      BindReq(@gtk_widget_grab_focus, 'gtk_widget_grab_focus') and
      BindReq(@gtk_widget_get_window, 'gtk_widget_get_window') and
      BindReq(@gtk_widget_destroy, 'gtk_widget_destroy') and
      BindReq(@gtk_widget_get_allocated_width, 'gtk_widget_get_allocated_width') and
      BindReq(@gtk_widget_get_allocated_height, 'gtk_widget_get_allocated_height') and
      BindReq(@gdk_window_get_state, 'gdk_window_get_state') and
      BindReq(@gtk_main, 'gtk_main') and
      BindReq(@gtk_main_quit, 'gtk_main_quit') and
      BindReq(@gtk_main_iteration_do, 'gtk_main_iteration_do') and
      BindReq(@gtk_events_pending, 'gtk_events_pending');
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
    if not (TryDlOpen(GGtkLib, ['libgtk-3.so.0', 'libgtk-3.so']) and
            TryDlOpen(GGobjectLib, ['libgobject-2.0.so.0']) and
            TryDlOpen(GGlibLib, ['libglib-2.0.so.0'])) then
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
    AInfo := GInfo;
    Result := True;
  finally
    GLoading := False;
  end;
end;

procedure UnloadGtk3;
begin
  if not GLoaded then Exit;
  ReleaseAll;
  GLoaded := False;
  GInfo := Default(TGtk3LoadInfo);
end;

function Gtk3LoadInfo: TGtk3LoadInfo;
begin
  Result := GInfo;
end;

function Gtk3IsLoaded: Boolean;
begin
  Result := GLoaded;
end;

function TryLoadWindowGtk(out AInfo: TWindowGtkLoadInfo): Boolean;
begin
  Result := TryLoadGtk3(AInfo);
end;

procedure UnloadWindowGtk;
begin
  UnloadGtk3;
end;

function WindowGtkLoadInfo: TWindowGtkLoadInfo;
begin
  Result := Gtk3LoadInfo;
end;

function WindowGtkIsLoaded: Boolean;
begin
  Result := Gtk3IsLoaded;
end;

function Gtk3Sonames: string; inline;
begin
  // 单源：与 TryDlOpen 同源，registry 诊断零重复，inline 零额外调用
  Result := GTK3_SONAMES + '|' + GTK3_GOBJECT_SONAME + '|' + GTK3_GLIB_SONAME;
end;

end.
