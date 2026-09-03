unit nextpas.core.window.gtk3;

{** @desc GTK3 后端（薄适配层，消费独立 L2 gtk3 家族 + 共享实现单元）。
       原 786 行 `{$I}` 共享实现已显式化为
       `nextpas.core.window.gtk.impl` 单元（显式 uses 图，INV-3/INV-5 可静态扫描），
       本单元仅保留族别名、IGtkOps trait 接口 + TGtkOpsAdapter 适配器注入与 Raw 低阶壳，零重复逻辑，适配器 inline 透传。 *}

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

{ 低阶 Raw 壳（供 L3 webview 单源复用，零开销 inline 转发） }
function WindowGtkRawInit: Boolean;
function WindowGtkRawCreate(const ATitle: string; AWidth, AHeight: Integer;
  AResizable, AStartMaximized: Boolean): Pointer;
procedure WindowGtkRawSetTitle(AWin: Pointer; const ATitle: string); inline;
procedure WindowGtkRawResize(AWin: Pointer; AW, AH: Integer); inline;
procedure WindowGtkRawShow(AWin: Pointer); inline;
procedure WindowGtkRawHide(AWin: Pointer); inline;
function WindowGtkRawIsMaximized(AWin: Pointer): Boolean; inline;
procedure WindowGtkRawMaximize(AWin: Pointer); inline;
procedure WindowGtkRawUnmaximize(AWin: Pointer); inline;
function WindowGtkRawScaleFactor(AWidget: Pointer): Integer; inline;
procedure WindowGtkRawFocus(AWidget: Pointer); inline;
function WindowGtkRawNativeHandle(AWidget: Pointer): Pointer; inline;
procedure WindowGtkRawRunMainLoop; inline;
procedure WindowGtkRawQuitMainLoop; inline;

{ 族显式别名（与旧 shim 兼容） }
function WindowGtk3IsAvailable: Boolean;
function CreateWindowGtk3(const AOptions: TWindowOptions): IWindow;
function Gtk3LiveWindowCount: Integer;
procedure WindowGtk3RunMainLoop;
procedure WindowGtk3QuitMainLoop;

implementation

uses
  nextpas.core.math,
  nextpas.core.errors,
  nextpas.core.text.ansi,
  nextpas.core.platform.thread,
  nextpas.core.sync.intf,
  nextpas.core.sync.mutex,
  nextpas.core.gtk3.base,
  nextpas.core.gtk3.ffi,
  nextpas.core.gtk3.loader,
  nextpas.core.window.impl,
  nextpas.core.window.live,
  nextpas.core.window.queue,
  nextpas.core.window.registry,
  nextpas.core.window.gtk.impl;

type
  TGtkLoadInfo = TGtk3LoadInfo;

function GtkTryLoad(out ALoaded: Boolean): Boolean;
var
  L: TGtk3LoadInfo;
begin
  Result := TryLoadGtk3(L);
  ALoaded := L.Loaded;
end;

function BuildGtk3Ops: TGtkOps; inline;
begin
  // 性能：trait 适配器 inline 透传单次字段间接 nil 守卫，inline 构造零额外堆分配，复用 loader 全局直调，记录存储零手写重复 via fields.inc
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
  // trait 接口：单次构造填充 loader 全局指针经 Adapter 桥接，inline 透传零额外拷贝，记录存储复用 fields.inc 单源
  GContext := TGtkContext.Create(BuildGtk3Ops);
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
  // 预加载以保证后端可用（record 直调实时读 ffi 绑定，零 stale 拷贝）
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

{ ---- Raw 壳实现（薄转发，复用同族 gtk_* 已绑定符号） }

function WindowGtkRawInit: Boolean;
var
  LLoaded: Boolean;
begin
  if not GtkTryLoad(LLoaded) or not LLoaded then Exit(False);
  Result := nextpas.core.window.gtk.impl.GtkEnsureInit(GetContext);
end;

function WindowGtkRawCreate(const ATitle: string; AWidth, AHeight: Integer;
  AResizable, AStartMaximized: Boolean): Pointer;
const
  GTK_WINDOW_TOPLEVEL = 0;
begin
  Result := gtk_window_new(GTK_WINDOW_TOPLEVEL);
  if Result = nil then Exit(nil);
  gtk_window_set_default_size(Result, AWidth, AHeight);
  gtk_window_set_resizable(Result, Ord(AResizable));
  if ATitle <> '' then
    // perf: inline zero-copy StrToPAnsiView 无临时分配
    gtk_window_set_title(Result, StrToPAnsiView(ATitle));
  if AStartMaximized then
    gtk_window_maximize(Result);
end;

procedure WindowGtkRawSetTitle(AWin: Pointer; const ATitle: string); inline;
begin
  // perf: inline zero-copy StrToPAnsiView 高频标题零拷贝
  gtk_window_set_title(AWin, StrToPAnsiView(ATitle));
end;

procedure WindowGtkRawResize(AWin: Pointer; AW, AH: Integer); inline;
begin
  gtk_window_resize(AWin, AW, AH);
end;

procedure WindowGtkRawShow(AWin: Pointer); inline;
begin
  gtk_widget_show_all(AWin);
end;

procedure WindowGtkRawHide(AWin: Pointer); inline;
begin
  gtk_widget_hide(AWin);
end;

function WindowGtkRawIsMaximized(AWin: Pointer): Boolean; inline;
begin
  Result := gtk_window_is_maximized(AWin) <> 0;
end;

procedure WindowGtkRawMaximize(AWin: Pointer); inline;
begin
  gtk_window_maximize(AWin);
end;

procedure WindowGtkRawUnmaximize(AWin: Pointer); inline;
begin
  gtk_window_unmaximize(AWin);
end;

function WindowGtkRawScaleFactor(AWidget: Pointer): Integer; inline;
begin
  Result := gtk_widget_get_scale_factor(AWidget);
end;

procedure WindowGtkRawFocus(AWidget: Pointer); inline;
begin
  gtk_widget_grab_focus(AWidget);
end;

function WindowGtkRawNativeHandle(AWidget: Pointer): Pointer; inline;
begin
  Result := gtk_widget_get_window(AWidget);
end;

procedure WindowGtkRawRunMainLoop; inline;
begin
  WindowGtkRunMainLoop;
end;

procedure WindowGtkRawQuitMainLoop; inline;
begin
  WindowGtkQuitMainLoop;
end;

function WindowGtk3IsAvailable: Boolean;
begin
  Result := WindowGtkIsAvailable;
end;

function CreateWindowGtk3(const AOptions: TWindowOptions): IWindow;
begin
  Result := CreateWindowGtk(AOptions);
end;

function Gtk3LiveWindowCount: Integer;
begin
  Result := GtkLiveWindowCount;
end;

procedure WindowGtk3RunMainLoop;
begin
  WindowGtkRunMainLoop;
end;

procedure WindowGtk3QuitMainLoop;
begin
  WindowGtkQuitMainLoop;
end;

procedure RegisterGtk3Backend;
var LDesc: TBackendDesc;
begin
  LDesc.Kind := wkGtk3;
  LDesc.Probe := @WindowGtk3IsAvailable;
  LDesc.Create := @CreateWindowGtk3;
  LDesc.Live := @Gtk3LiveWindowCount;
  LDesc.Run := @WindowGtk3RunMainLoop;
  LDesc.Quit := @WindowGtk3QuitMainLoop;
  LDesc.Pump := @GtkPumpOnce;
  LDesc.Sonames := GTK3_SONAMES;
  RegistryRegister(LDesc);
  // 同步注册聚合 wkGtk（gtk 智能回退）：以 gtk3 为载体， Probe/Create 经 registry 智能委托
  LDesc.Kind := wkGtk;
  LDesc.Probe := @WindowGtkIsAvailable;
  LDesc.Create := @RegistryCreateGtkSmart;
  LDesc.Live := @RegistryLiveGtkSmart;
  LDesc.Run := @RegistryRunGtkSmart;
  LDesc.Quit := @RegistryQuitGtkSmart;
  LDesc.Pump := @GtkPumpOnce;
  LDesc.Sonames := GTK3_SONAMES;
  RegistryRegister(LDesc);
end;

initialization
  RegisterGtk3Backend;

finalization
  GContext.Free;

end.
