unit nextpas.core.window.gtk.loader;

{** @desc GTK 窗口子集动态装载（家族内唯一触 platform.dl 的单元）。
       原语一律来自 nextpas.core.platform.dl，禁用 FPC DynLibs。

       探测仅装载 GTK3 栈（libgtk-3 / libgobject-2.0 / libglib-2.0），
       不触 WebKit/JSC。能力以符号存在性判定，装载结果进程级幂等。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.platform.dl,
  nextpas.core.window.gtk.ffi;

type
  TWindowGtkLoadInfo = record
    Loaded: Boolean;
  end;

function TryLoadWindowGtk(out AInfo: TWindowGtkLoadInfo): Boolean;
procedure UnloadWindowGtk;
function WindowGtkLoadInfo: TWindowGtkLoadInfo;
function WindowGtkIsLoaded: Boolean;

implementation

var
  GLoaded: Boolean = False;
  GLoading: Boolean = False;
  GInfo: TWindowGtkLoadInfo;
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

function TryLoadWindowGtk(out AInfo: TWindowGtkLoadInfo): Boolean;

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

var
  LHit: string;
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
    if not (TryDlOpen(GGtkLib, ['libgtk-3.so.0']) and
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

procedure UnloadWindowGtk;
begin
  if not GLoaded then Exit;
  ReleaseAll;
  GLoaded := False;
  GInfo := Default(TWindowGtkLoadInfo);
end;

function WindowGtkLoadInfo: TWindowGtkLoadInfo;
begin
  Result := GInfo;
end;

function WindowGtkIsLoaded: Boolean;
begin
  Result := GLoaded;
end;

end.
