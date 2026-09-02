unit nextpas.core.webview.gtk.win;

{** @desc GTK 窗口壳内部缝 — F4 阶段 2 单源化完成：本单元已退化为
       deprecated shim（文件保留至下一主版本），全部 WinShell* 12 项
       薄转发至 nextpas.core.window.gtk3 的 Raw 壳（WindowGtkRaw*）。
       保留原签名以保证 webview.gtk 零改动；新代码应直接使用
       window.gtk3 Raw API。下一主版本移除本文件。
       性能：全量 inline 零拷贝薄转发、零额外调用、零状态零分配；
       稳定性：薄转发层无资源持有，释放不丢（所有权归 window.gtk3）。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.window.gtk3;

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
function WinShellInit: Boolean; inline; deprecated 'use window.gtk3.WindowGtkRawInit';

{ 创建 top-level 壳窗口并应用启动几何；返回 GtkWindow* 句柄 }
function WinShellCreate(const AGeometry: TWinShellGeometry): Pointer; inline; deprecated 'use window.gtk3.WindowGtkRawCreate';

procedure WinShellSetTitle(AWin: Pointer; const ATitle: string); inline; deprecated 'use window.gtk3.WindowGtkRawSetTitle';
procedure WinShellResize(AWin: Pointer; AW, AH: Integer); inline; deprecated 'use window.gtk3.WindowGtkRawResize';
procedure WinShellShow(AWin: Pointer); inline; deprecated 'use window.gtk3.WindowGtkRawShow';
procedure WinShellHide(AWin: Pointer); inline; deprecated 'use window.gtk3.WindowGtkRawHide';

function WinShellIsMaximized(AWin: Pointer): Boolean; inline; deprecated 'use window.gtk3.WindowGtkRawIsMaximized';
procedure WinShellMaximize(AWin: Pointer); inline; deprecated 'use window.gtk3.WindowGtkRawMaximize';
procedure WinShellUnmaximize(AWin: Pointer); inline; deprecated 'use window.gtk3.WindowGtkRawUnmaximize';
function WinShellScaleFactor(AWidget: Pointer): Integer; inline; deprecated 'use window.gtk3.WindowGtkRawScaleFactor';

{ 键盘焦点与原生句柄 }
procedure WinShellFocus(AWidget: Pointer); inline; deprecated 'use window.gtk3.WindowGtkRawFocus';
function WinShellNativeHandle(AWidget: Pointer): Pointer; inline; deprecated 'use window.gtk3.WindowGtkRawNativeHandle';

{ 主循环所有权：RunLoop 语义（阻塞直到 Quit）；Quit 幂等安全 }
procedure WinShellRunMainLoop; inline; deprecated 'use window.factory.WindowRunLoop';
procedure WinShellQuitMainLoop; inline; deprecated 'use window.factory.WindowExitLoop';

implementation

function WinShellInit: Boolean; inline;
begin
  Result := WindowGtkRawInit;
end;

function WinShellCreate(const AGeometry: TWinShellGeometry): Pointer; inline;
begin
  Result := WindowGtkRawCreate(AGeometry.Title, AGeometry.Width, AGeometry.Height,
    AGeometry.Resizable, AGeometry.StartMaximized);
end;

procedure WinShellSetTitle(AWin: Pointer; const ATitle: string); inline;
begin
  WindowGtkRawSetTitle(AWin, ATitle);
end;

procedure WinShellResize(AWin: Pointer; AW, AH: Integer); inline;
begin
  WindowGtkRawResize(AWin, AW, AH);
end;

procedure WinShellShow(AWin: Pointer); inline;
begin
  WindowGtkRawShow(AWin);
end;

procedure WinShellHide(AWin: Pointer); inline;
begin
  WindowGtkRawHide(AWin);
end;

function WinShellIsMaximized(AWin: Pointer): Boolean; inline;
begin
  Result := WindowGtkRawIsMaximized(AWin);
end;

procedure WinShellMaximize(AWin: Pointer); inline;
begin
  WindowGtkRawMaximize(AWin);
end;

procedure WinShellUnmaximize(AWin: Pointer); inline;
begin
  WindowGtkRawUnmaximize(AWin);
end;

function WinShellScaleFactor(AWidget: Pointer): Integer; inline;
begin
  Result := WindowGtkRawScaleFactor(AWidget);
end;

procedure WinShellFocus(AWidget: Pointer); inline;
begin
  WindowGtkRawFocus(AWidget);
end;

function WinShellNativeHandle(AWidget: Pointer): Pointer; inline;
begin
  Result := WindowGtkRawNativeHandle(AWidget);
end;

procedure WinShellRunMainLoop; inline;
begin
  WindowGtkRawRunMainLoop;
end;

procedure WinShellQuitMainLoop; inline;
begin
  WindowGtkRawQuitMainLoop;
end;

end.
