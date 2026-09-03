unit nextpas.core.window.gtk2;

{** @desc GTK2 后端（薄适配层，消费独立 L2 gtk2 家族 + 共享实现单元）。
       原 786 行 `{$I}` 共享实现已显式化为
       `nextpas.core.window.gtk.impl` 单元，本单元仅保留族别名与 IGtkOps trait 接口 + TGtkOpsAdapter 适配器注入。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.window.base,
  nextpas.core.window.intf;

function WindowGtkIsAvailable: Boolean;
function CreateWindowGtk(const AOptions: TWindowOptions): IWindow;
function GtkLiveWindowCount: Integer;
function GtkPumpOnce: Boolean;
procedure WindowGtkRunMainLoop;
procedure WindowGtkQuitMainLoop;

{ 族显式别名（gtk2） }
function WindowGtk2IsAvailable: Boolean;
function CreateWindowGtk2(const AOptions: TWindowOptions): IWindow;
function Gtk2LiveWindowCount: Integer;
procedure WindowGtk2RunMainLoop;
procedure WindowGtk2QuitMainLoop;

implementation

uses
  nextpas.core.math,
  nextpas.core.errors,
  nextpas.core.text.ansi,
  nextpas.core.platform.thread,
  nextpas.core.sync.intf,
  nextpas.core.sync.mutex,
  nextpas.core.gtk2.base,
  nextpas.core.gtk2.ffi,
  nextpas.core.gtk2.loader,
  nextpas.core.window.impl,
  nextpas.core.window.live,
  nextpas.core.window.queue,
  nextpas.core.window.registry,
  nextpas.core.window.gtk.impl;

type
  TGtkLoadInfo = TGtk2LoadInfo;

function GtkTryLoad(out ALoaded: Boolean): Boolean;
var
  L: TGtk2LoadInfo;
begin
  Result := TryLoadGtk2(L);
  ALoaded := L.Loaded;
end;

function BuildGtk2Ops: TGtkOps; inline;
begin
  Result.TryLoad := @GtkTryLoad;
  Result.IdleAddFull := g_idle_add_full;
  Result.SourceRemove := g_source_remove;
  Result.SignalConnectData := g_signal_connect_data;
  Result.SignalHandlerDisconnect := g_signal_handler_disconnect;
  Result.InitCheck := gtk_init_check;
  Result.WindowNew := gtk_window_new;
  Result.WindowSetTitle := gtk_window_set_title;
  Result.WindowGetTitle := gtk_window_get_title;
  Result.WindowSetDefaultSize := gtk_window_set_default_size;
  Result.WindowSetResizable := gtk_window_set_resizable;
  Result.WindowResize := gtk_window_resize;
  Result.WindowMaximize := gtk_window_maximize;
  Result.WindowUnmaximize := gtk_window_unmaximize;
  Result.WindowIconify := gtk_window_iconify;
  Result.WindowDeiconify := gtk_window_deiconify;
  Result.WindowIsMaximized := gtk_window_is_maximized;
  Result.WidgetShowAll := gtk_widget_show_all;
  Result.WidgetHide := gtk_widget_hide;
  Result.WidgetGetVisible := gtk_widget_get_visible;
  Result.WidgetGetScaleFactor := gtk_widget_get_scale_factor;
  Result.WidgetGrabFocus := gtk_widget_grab_focus;
  Result.WidgetGetWindow := gtk_widget_get_window;
  Result.WidgetDestroy := gtk_widget_destroy;
  Result.WidgetGetAllocatedWidth := gtk_widget_get_allocated_width;
  Result.WidgetGetAllocatedHeight := gtk_widget_get_allocated_height;
  Result.GdkWindowGetState := gdk_window_get_state;
  Result.Main := gtk_main;
  Result.MainQuit := gtk_main_quit;
  Result.MainIterationDo := gtk_main_iteration_do;
  Result.EventsPending := gtk_events_pending;
end;

var
  GContext: TGtkContext = nil;

function GetContext: TGtkContext;
begin
  if GContext <> nil then Exit(GContext);
  // trait 接口：单次构造经 Adapter 桥接 inline 透传零额外拷贝
  GContext := TGtkContext.Create(BuildGtk2Ops);
  Result := GContext;
end;

function WindowGtkIsAvailable: Boolean;
begin
  Result := nextpas.core.window.gtk.impl.GtkIsAvailable(GetContext);
end;

function CreateWindowGtk(const AOptions: TWindowOptions): IWindow;
var
  LLoaded: Boolean;
  Ctx: TGtkContext;
begin
  if not GtkTryLoad(LLoaded) or not LLoaded then
    raise EWindowBackendUnavailable.Create('GTK backend not available');
  Ctx := GetContext;
  Result := nextpas.core.window.gtk.impl.GtkCreateWindow(Ctx, AOptions);
end;

function GtkLiveWindowCount: Integer;
begin
  Result := nextpas.core.window.gtk.impl.GtkLiveCount(GetContext);
end;

function GtkPumpOnce: Boolean;
begin
  Result := nextpas.core.window.gtk.impl.GtkPumpOnce(GetContext);
end;

procedure WindowGtkRunMainLoop;
begin
  nextpas.core.window.gtk.impl.GtkRunMainLoop(GetContext);
end;

procedure WindowGtkQuitMainLoop;
begin
  nextpas.core.window.gtk.impl.GtkQuitMainLoop(GetContext);
end;

function WindowGtk2IsAvailable: Boolean;
begin
  Result := WindowGtkIsAvailable;
end;

function CreateWindowGtk2(const AOptions: TWindowOptions): IWindow;
begin
  Result := CreateWindowGtk(AOptions);
end;

function Gtk2LiveWindowCount: Integer;
begin
  Result := GtkLiveWindowCount;
end;

procedure WindowGtk2RunMainLoop;
begin
  WindowGtkRunMainLoop;
end;

procedure WindowGtk2QuitMainLoop;
begin
  WindowGtkQuitMainLoop;
end;

procedure RegisterGtk2Backend;
var LDesc: TBackendDesc;
begin
  LDesc.Kind := wkGtk2;
  LDesc.Probe := @WindowGtk2IsAvailable;
  LDesc.Create := @CreateWindowGtk2;
  LDesc.Live := @Gtk2LiveWindowCount;
  LDesc.Run := @WindowGtk2RunMainLoop;
  LDesc.Quit := @WindowGtk2QuitMainLoop;
  LDesc.Pump := @GtkPumpOnce;
  LDesc.Sonames := GTK2_SONAMES;
  RegistryRegister(LDesc);
end;

initialization
  RegisterGtk2Backend;

finalization
  GContext.Free;

end.
