unit nextpas.core.qt5pas.ffi;

{** @desc libQt5Pas.so 窗口壳 ABI 声明层（qt5pas 家族）。
       只含不透明句柄类型、常量与函数指针变量——无逻辑、无 external；
       绑定真相归 qt5pas.loader（经 nextpas.core.platform.dl 动态装载）。

       签名对照源：Lazarus Qt5Pas C 绑定头
         - lcl/interfaces/qt5/cbindings/qt5pas.h
         - libQt5Pas.so 导出的 QApplication/QWidget/QWindow 族
       本单元仅截取 IWindow 窗口壳必需的 8-10 个核心符号，保持与
       window.gtk.ffi 同风格；QWindow 为可选替代路径，信号连接仅保留
       hook 创建的基础形态。本单元禁止 uses 家族其他单元（INV-5）。 *}

{$I nextpas.core.settings.inc}

interface

type
  QApplicationH = Pointer;
  QWidgetH = Pointer;
  QWindowH = Pointer;
  HookH = Pointer;
  WId = QWord;

const
  {** Qt::WindowType 占位（Qt_WindowType_TopLevel = 0x00000000） *}
  Qt_WindowType_TopLevel = 0;

type
  {** Hook 销毁通知（与 GTK 的 TGDestroyNotify 对齐） *}
  TQtHookDestroyNotify = procedure(AData: Pointer); cdecl;

var
  { ---- QApplication 生命周期（窗口壳入口） ---- }
  QApplication_create: function(AArgc: PInt32; AArgv: PPAnsiChar): QApplicationH; cdecl;
  QApplication_destroy: procedure(AApp: QApplicationH); cdecl;
  QApplication_exec: function: Integer; cdecl;
  QApplication_quit: procedure; cdecl;

  { ---- QWidget 窗口壳（IWindow 最小集） ---- }
  QWidget_create: function(AParent: QWidgetH; AFlags: Cardinal): QWidgetH; cdecl;
  QWidget_setWindowTitle: procedure(AWidget: QWidgetH; ATitle: PWideChar); cdecl;
  QWidget_windowTitle: function(AWidget: QWidgetH): PWideChar; cdecl;
  QWidget_resize: procedure(AWidget: QWidgetH; AWidth, AHeight: Integer); cdecl;
  QWidget_show: procedure(AWidget: QWidgetH); cdecl;
  QWidget_hide: procedure(AWidget: QWidgetH); cdecl;
  QWidget_close: function(AWidget: QWidgetH): LongBool; cdecl;
  QWidget_destroy: procedure(AWidget: QWidgetH); cdecl;
  QWidget_winId: function(AWidget: QWidgetH): WId; cdecl;
  QWidget_isVisible: function(AWidget: QWidgetH): LongBool; cdecl;

  { ---- QWindow 替代路径（可选，Wayland/高分屏场景的原生句柄补充） ---- }
  QWindow_create: function: QWindowH; cdecl;

  { ---- 信号连接基础（hook 形态，与 GTK g_signal_connect_data 对位） ---- }
  QApplication_hook_create: function(AApp: QApplicationH): HookH; cdecl;
  QWidget_hook_create: function(AWidget: QWidgetH): HookH; cdecl;
  Hook_destroy: procedure(AHook: HookH); cdecl;

implementation

end.
