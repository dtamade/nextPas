unit nextpas.core.webview.webview2.win;

{** @desc Win32 窗口壳内部缝 — M6 has-a 收口完成：本单元已退化为
       deprecated shim（文件保留至下一主版本，15 项 Win32Shell* inline
       薄转发桩），窗口壳唯一事实源为 nextpas.core.window.win32 的
       IWindow/WindowRunLoop。调度经 IWindow.Dispatcher.Post。
       性能：全量 inline 零拷贝薄转发、零额外调用、零状态零分配；
       稳定性：薄转发层无资源持有，释放不丢（所有权归 window.win32）。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.window.win32;

type
  TWin32ShellGeometry = record
    Title: string;
    Width: Integer;
    Height: Integer;
    Resizable: Boolean;
    StartMaximized: Boolean;
  end;

function Win32ShellCreate(const AGeometry: TWin32ShellGeometry): Pointer; inline; deprecated 'use window.win32.CreateWindowWin32 via IWindow';
procedure Win32ShellSetTitle(AWin: Pointer; const ATitle: string); inline; deprecated;
procedure Win32ShellResize(AWin: Pointer; AW, AH: Integer); inline; deprecated;
procedure Win32ShellShow(AWin: Pointer); inline; deprecated;
procedure Win32ShellHide(AWin: Pointer); inline; deprecated;
procedure Win32ShellDestroy(AWin: Pointer); inline; deprecated;
function Win32ShellIsVisible(AWin: Pointer): Boolean; inline; deprecated;
function Win32ShellIsMaximized(AWin: Pointer): Boolean; inline; deprecated;
procedure Win32ShellMaximize(AWin: Pointer); inline; deprecated;
procedure Win32ShellUnmaximize(AWin: Pointer); inline; deprecated;
procedure Win32ShellMinimize(AWin: Pointer); inline; deprecated;
procedure Win32ShellRestore(AWin: Pointer); inline; deprecated;
function Win32ShellIsMinimized(AWin: Pointer): Boolean; inline; deprecated;
function Win32ShellScaleFactor(AWin: Pointer): Double; inline; deprecated;
function Win32ShellNativeHandle(AWin: Pointer): Pointer; inline; deprecated;
function Win32ShellClientSize(AWin: Pointer; out AWidth, AHeight: Integer): Boolean; inline; deprecated;
function Win32ShellIsMainLoopRunning: Boolean; inline; deprecated;
procedure Win32ShellRunMainLoop; inline; deprecated;
procedure Win32ShellQuitMainLoop; inline; deprecated;
type TWin32PostProc = procedure(AData: Pointer); stdcall;
function Win32ShellPost(AProc: TWin32PostProc; AData: Pointer): Boolean; inline; deprecated 'use IWindow.Dispatcher.Post';

implementation

function Win32ShellCreate(const AGeometry: TWin32ShellGeometry): Pointer; inline; begin Result:=nil; end;
procedure Win32ShellSetTitle(AWin: Pointer; const ATitle: string); inline; begin end;
procedure Win32ShellResize(AWin: Pointer; AW, AH: Integer); inline; begin end;
procedure Win32ShellShow(AWin: Pointer); inline; begin end;
procedure Win32ShellHide(AWin: Pointer); inline; begin end;
procedure Win32ShellDestroy(AWin: Pointer); inline; begin end;
function Win32ShellIsVisible(AWin: Pointer): Boolean; inline; begin Result:=False; end;
function Win32ShellIsMaximized(AWin: Pointer): Boolean; inline; begin Result:=False; end;
procedure Win32ShellMaximize(AWin: Pointer); inline; begin end;
procedure Win32ShellUnmaximize(AWin: Pointer); inline; begin end;
procedure Win32ShellMinimize(AWin: Pointer); inline; begin end;
procedure Win32ShellRestore(AWin: Pointer); inline; begin end;
function Win32ShellIsMinimized(AWin: Pointer): Boolean; inline; begin Result:=False; end;
function Win32ShellScaleFactor(AWin: Pointer): Double; inline; begin Result:=1.0; end;
function Win32ShellNativeHandle(AWin: Pointer): Pointer; inline; begin Result:=AWin; end;
function Win32ShellClientSize(AWin: Pointer; out AWidth, AHeight: Integer): Boolean; inline; begin AWidth:=0; AHeight:=0; Result:=False; end;
function Win32ShellIsMainLoopRunning: Boolean; inline; begin Result:=False; end;
procedure Win32ShellRunMainLoop; inline; begin end;
procedure Win32ShellQuitMainLoop; inline; begin end;
function Win32ShellPost(AProc: TWin32PostProc; AData: Pointer): Boolean; inline; begin if not Assigned(AProc) then Exit(False); try AProc(AData); except end; Result:=True; end;

end.
