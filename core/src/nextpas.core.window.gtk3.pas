unit nextpas.core.window.gtk3;

{** @desc GTK3 后端（薄适配层，消费独立 L2 gtk3 家族）。
       共享实现见 nextpas.core.window.gtk.impl.inc，本单元仅保留
       uses 与族别名转发，消除与 gtk4/gtk2 的 786 行重复。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.window.base,
  nextpas.core.window.intf;

function WindowGtkIsAvailable: Boolean;
function CreateWindowGtk(const AOptions: TWindowOptions): IWindow;
function GtkLiveWindowCount: Integer;
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
  nextpas.core.window.live;

type
  TGtkLoadInfo = TGtk3LoadInfo;

function TryLoadGtk(out AInfo: TGtkLoadInfo): Boolean;
begin
  Result := TryLoadGtk3(AInfo);
end;

{$I nextpas.core.window.gtk.impl.inc}

{ ---- Raw 壳实现（薄转发，复用同族 gtk_* 已绑定符号） }

function WindowGtkRawInit: Boolean;
var LInfo: TGtkLoadInfo;
begin
  if not TryLoadGtk(LInfo) or not LInfo.Loaded then Exit(False);
  Result := EnsureGtkInit;
end;

function WindowGtkRawCreate(const ATitle: string; AWidth, AHeight: Integer;
  AResizable, AStartMaximized: Boolean): Pointer;
const GTK_WINDOW_TOPLEVEL = 0;
begin
  Result := gtk_window_new(GTK_WINDOW_TOPLEVEL);
  if Result = nil then Exit(nil);
  gtk_window_set_default_size(Result, AWidth, AHeight);
  gtk_window_set_resizable(Result, Ord(AResizable));
  if ATitle <> '' then
    gtk_window_set_title(Result, PAnsiChar(StrToAnsi(ATitle)));
  if AStartMaximized then
    gtk_window_maximize(Result);
end;

procedure WindowGtkRawSetTitle(AWin: Pointer; const ATitle: string); inline;
begin
  gtk_window_set_title(AWin, PAnsiChar(StrToAnsi(ATitle)));
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

finalization
  GLiveRegistry.Free;

end.
