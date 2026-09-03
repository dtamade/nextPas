unit nextpas.core.gtk4.loader;

{** @desc GTK4 窗口子集动态装载（家族内唯一触 platform.dl 的单元）。
       原语一律来自 nextpas.core.platform.dl，禁用 FPC DynLibs。

       探测仅装载 GTK4 栈（libgtk-4 / libgobject-2.0 / libglib-2.0），
       不触 WebKit/JSC。能力以符号存在性判定，装载结果进程级幂等。
       GTK4 特有符号（gtk_window_set_child 等、gdk_surface_get_state）
       以 BindOpt 可选绑定，缺失不导致整体失败。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.platform.dl,
  nextpas.core.gtk4.ffi;

type
  TGtk4LoadInfo = record
    Loaded: Boolean;
  end;

function TryLoadGtk4(out AInfo: TGtk4LoadInfo): Boolean;
procedure UnloadGtk4;
function Gtk4LoadInfo: TGtk4LoadInfo;
function Gtk4IsLoaded: Boolean;
const
  GTK4_SONAMES = 'libgtk-4.so.1|libgtk-4.so|libgtk-4.so.0';
  GTK4_GOBJECT_SONAME = 'libgobject-2.0.so.0';
  GTK4_GLIB_SONAME = 'libglib-2.0.so.0';
function Gtk4Sonames: string; inline;

implementation

var
  GLoaded: Boolean = False;
  GLoading: Boolean = False;
  GInfo: TGtk4LoadInfo;
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

function BindOpt(AVarAddr: Pointer; const AName: string): Boolean;
begin
  if Sym(PAnsiChar(AName), PPointer(AVarAddr)^) then
    Exit(True);
  PPointer(AVarAddr)^ := nil;
  Result := True;
end;

procedure ReleaseAll;
begin
  platform_dl_release(GGtkLib);
  platform_dl_release(GGobjectLib);
  platform_dl_release(GGlibLib);
end;

function TryLoadGtk4(out AInfo: TGtk4LoadInfo): Boolean;

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
      BindOpt(@gdk_window_get_state, 'gdk_window_get_state') and
      BindReq(@gtk_main, 'gtk_main') and
      BindReq(@gtk_main_quit, 'gtk_main_quit') and
      BindReq(@gtk_main_iteration_do, 'gtk_main_iteration_do') and
      BindReq(@gtk_events_pending, 'gtk_events_pending') and
      BindOpt(@gtk_window_set_child, 'gtk_window_set_child') and
      BindOpt(@gtk_window_get_child, 'gtk_window_get_child') and
      BindOpt(@gtk_widget_set_visible, 'gtk_widget_set_visible') and
      BindOpt(@gtk_widget_show, 'gtk_widget_show') and
      BindOpt(@gtk_window_present, 'gtk_window_present') and
      BindOpt(@gdk_surface_get_state, 'gdk_surface_get_state');
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
    if not (TryDlOpen(GGtkLib, ['libgtk-4.so.1','libgtk-4.so','libgtk-4.so.0']) and
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

procedure UnloadGtk4;
begin
  if not GLoaded then Exit;
  ReleaseAll;
  GLoaded := False;
  GInfo := Default(TGtk4LoadInfo);
end;

function Gtk4LoadInfo: TGtk4LoadInfo;
begin
  Result := GInfo;
end;

function Gtk4IsLoaded: Boolean;
begin
  Result := GLoaded;
end;

function Gtk4Sonames: string; inline;
begin
  // 单源：与 TryDlOpen 同源，inline 零拷贝
  Result := GTK4_SONAMES + '|' + GTK4_GOBJECT_SONAME + '|' + GTK4_GLIB_SONAME;
end;

end.
