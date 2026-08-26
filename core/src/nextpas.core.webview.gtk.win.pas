unit nextpas.core.webview.gtk.win;

{** @desc GTK 窗口壳内部缝：create/title/geometry/state/focus/loop 的
       薄函数式封装。签名不含任何 webview 概念、只依赖 gtk.ffi/gtk.loader
       （CONTRACT §1.1）——本单元是未来 nextpas.core.window 独立模块的
       抽取预备缝：第二个 consumer 出现或 Wave 2 前整体上移，消费方无感。

       立场：不做任何策略决策（布局/默认值归调用方），只做机械转发与
       句柄纪律（show_all 统一出口等）。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.webview.gtk.ffi;

type
  { 窗口壳启动几何（纯数据，无 webview 类型） }
  TWinShellGeometry = record
    Title: string;
    Width: Integer;
    Height: Integer;
    Resizable: Boolean;
    StartMaximized: Boolean;
  end;

{ 进程级 GTK 初始化（gtk_init_check 幂等封装）；False = 无显示等 }
function WinShellInit: Boolean;

{ 创建 top-level 壳窗口并应用启动几何；返回 GtkWindow* 句柄 }
function WinShellCreate(const AGeometry: TWinShellGeometry): Pointer;

procedure WinShellSetTitle(AWin: Pointer; const ATitle: string);
procedure WinShellResize(AWin: Pointer; AW, AH: Integer);
procedure WinShellShow(AWin: Pointer);
procedure WinShellHide(AWin: Pointer);

function WinShellIsMaximized(AWin: Pointer): Boolean;
procedure WinShellMaximize(AWin: Pointer);
procedure WinShellUnmaximize(AWin: Pointer);
function WinShellScaleFactor(AWidget: Pointer): Integer;

{ 键盘焦点与原生句柄 }
procedure WinShellFocus(AWidget: Pointer);
function WinShellNativeHandle(AWidget: Pointer): Pointer;

{ 主循环所有权：RunLoop 语义（阻塞直到 Quit）；Quit 幂等安全 }
procedure WinShellRunMainLoop;
procedure WinShellQuitMainLoop;

implementation

var
  GInitDone: Boolean = False;
  GInitOk: Boolean = False;
  GMainLoopRunning: Boolean = False;

function WinShellInit: Boolean;
var
  LArgc: Int32 = 0;
begin
  if not GInitDone then
  begin
    GInitOk := GTK_init_check(@LArgc, nil) <> 0;
    GInitDone := True;
  end;
  Result := GInitOk;
end;

function WinShellCreate(const AGeometry: TWinShellGeometry): Pointer;
const
  GTK_WINDOW_TOPLEVEL = 0;
begin
  Result := GTK_window_new(GTK_WINDOW_TOPLEVEL);
  GTK_window_set_default_size(Result, AGeometry.Width, AGeometry.Height);
  GTK_window_set_resizable(Result, Ord(AGeometry.Resizable));
  if AGeometry.Title <> '' then
    GTK_window_set_title(Result, PAnsiChar(AGeometry.Title));
  if AGeometry.StartMaximized then
    GTK_window_maximize(Result);
end;

procedure WinShellSetTitle(AWin: Pointer; const ATitle: string);
begin
  GTK_window_set_title(AWin, PAnsiChar(ATitle));
end;

procedure WinShellResize(AWin: Pointer; AW, AH: Integer);
begin
  GTK_window_resize(AWin, AW, AH);
end;

procedure WinShellShow(AWin: Pointer);
begin
  { show_all 统一出口：子部件可见性由壳一次性铺开 }
  GTK_widget_show_all(AWin);
end;

procedure WinShellHide(AWin: Pointer);
begin
  GTK_widget_hide(AWin);
end;

function WinShellIsMaximized(AWin: Pointer): Boolean;
begin
  Result := GTK_window_is_maximized(AWin) <> 0;
end;

procedure WinShellMaximize(AWin: Pointer);
begin
  GTK_window_maximize(AWin);
end;

procedure WinShellUnmaximize(AWin: Pointer);
begin
  GTK_window_unmaximize(AWin);
end;

function WinShellScaleFactor(AWidget: Pointer): Integer;
begin
  Result := GTK_widget_get_scale_factor(AWidget);
end;

procedure WinShellFocus(AWidget: Pointer);
begin
  GTK_widget_grab_focus(AWidget);
end;

function WinShellNativeHandle(AWidget: Pointer): Pointer;
begin
  Result := GTK_widget_get_window(AWidget);
end;

procedure WinShellRunMainLoop;
begin
  GMainLoopRunning := True;
  try
    GTK_main();
  finally
    GMainLoopRunning := False;
  end;
end;

procedure WinShellQuitMainLoop;
begin
  { 无运行中主循环时调用 gtk_main_quit 会触发 Gtk-CRITICAL }
  if GMainLoopRunning then
    GTK_main_quit();
end;

end.
