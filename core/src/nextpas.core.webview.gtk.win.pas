unit nextpas.core.webview.gtk.win;

{** @desc GTK 窗口壳内部缝：create/title/geometry/state/focus/loop 的
       薄函数式封装。签名不含任何 webview 概念、只依赖 webview.gtk.ffi
       （CONTRACT §1.1）——本单元是未来 nextpas.core.window 独立模块的
       抽取预备缝：第二个 consumer 出现或 Wave 2 前整体上移，消费方无感。

       纪律：FPU 屏蔽经 nextpas.core.math.SetExceptionMask，标题
       Ansi 互转经 nextpas.core.text.ansi（StrToAnsi），与
       nextpas.core.window.gtk.impl.inc 同纪律；F4 阶段 1 已对齐
       webview 侧窗口壳的 RTL 洁癖，阶段 2 待 window 暴露 raw shell
       API 后再单源化到 window.gtk3（见 FINAL_ROADMAP F4）。

       立场：不做任何策略决策（布局/默认值归调用方），只做机械转发与
       句柄纪律（show_all 统一出口等）。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.math,
  nextpas.core.text.ansi,
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

procedure WinShellSetTitle(AWin: Pointer; const ATitle: string); inline;
procedure WinShellResize(AWin: Pointer; AW, AH: Integer); inline;
procedure WinShellShow(AWin: Pointer); inline;
procedure WinShellHide(AWin: Pointer); inline;

function WinShellIsMaximized(AWin: Pointer): Boolean; inline;
procedure WinShellMaximize(AWin: Pointer); inline;
procedure WinShellUnmaximize(AWin: Pointer); inline;
function WinShellScaleFactor(AWidget: Pointer): Integer; inline;

{ 键盘焦点与原生句柄 }
procedure WinShellFocus(AWidget: Pointer); inline;
function WinShellNativeHandle(AWidget: Pointer): Pointer; inline;

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
    { 恢复 IEEE 浮点异常屏蔽：FPC RTL 默认解除屏蔽，而内核 clone 的
      子线程继承创建者 FP 控制字——WebKit/GLib/JIT 工作线程里任何合法
      的除零值运算（预期 ±Inf/NaN）都会陷阱成随机位置的 EZeroDivide。
      C 宿主默认带屏蔽嵌入引擎，我们对齐同一语义（仅本进程内生效）。 }
    nextpas.core.math.SetExceptionMask([exInvalidOp, exDenormalized, exZeroDivide,
      exOverflow, exUnderflow, exPrecision]);
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
    GTK_window_set_title(Result, PAnsiChar(StrToAnsi(AGeometry.Title)));
  if AGeometry.StartMaximized then
    GTK_window_maximize(Result);
end;

procedure WinShellSetTitle(AWin: Pointer; const ATitle: string); inline;
begin
  GTK_window_set_title(AWin, PAnsiChar(StrToAnsi(ATitle)));
end;

procedure WinShellResize(AWin: Pointer; AW, AH: Integer); inline;
begin
  GTK_window_resize(AWin, AW, AH);
end;

procedure WinShellShow(AWin: Pointer); inline;
begin
  { show_all 统一出口：子部件可见性由壳一次性铺开 }
  GTK_widget_show_all(AWin);
end;

procedure WinShellHide(AWin: Pointer); inline;
begin
  GTK_widget_hide(AWin);
end;

function WinShellIsMaximized(AWin: Pointer): Boolean; inline;
begin
  Result := GTK_window_is_maximized(AWin) <> 0;
end;

procedure WinShellMaximize(AWin: Pointer); inline;
begin
  GTK_window_maximize(AWin);
end;

procedure WinShellUnmaximize(AWin: Pointer); inline;
begin
  GTK_window_unmaximize(AWin);
end;

function WinShellScaleFactor(AWidget: Pointer): Integer; inline;
begin
  Result := GTK_widget_get_scale_factor(AWidget);
end;

procedure WinShellFocus(AWidget: Pointer); inline;
begin
  GTK_widget_grab_focus(AWidget);
end;

function WinShellNativeHandle(AWidget: Pointer): Pointer; inline;
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
