unit nextpas.core.qt.ffi;

{** @desc 自包装 C shim（vendors/libnextpas-qt）ABI 声明层（qt 家族）。
       只含不透明句柄类型、回调类型与函数指针变量——无逻辑、无 external；
       绑定真相归 qt.loader（经 nextpas.core.platform.dl 动态装载）。

       本单元为 deferred 桩：全部符号以 BindOpt 绑定，桩阶段缺席不报错；
       shim 立项后提供稳定 C ABI（见 core/docs/qt/README.md）。
       本单元禁止 uses 家族其他单元（INV-5）。 *}

{$I nextpas.core.settings.inc}

interface

type
  QtAppHandle = Pointer;
  QtWindowHandle = Pointer;
  QtNativeHandle = Pointer;

  TQtDispatcherProc = procedure(AData: Pointer); cdecl;
  TQtDispatcherNotify = procedure(AData: Pointer); cdecl;

var
  { ---- App 生命周期 ---- }
  qt_app_create: function(AArgc: PInt32; AArgv: PPAnsiChar): QtAppHandle; cdecl;
  qt_app_destroy: procedure(AApp: QtAppHandle); cdecl;
  qt_app_run: procedure(AApp: QtAppHandle); cdecl;
  qt_app_quit: procedure(AApp: QtAppHandle); cdecl;

  { ---- Window 窗口壳（对齐 IWindow 最小集） ---- }
  qt_window_create: function(AApp: QtAppHandle; AWidth, AHeight: Integer; ATitle: PAnsiChar): QtWindowHandle; cdecl;
  qt_window_destroy: procedure(AWin: QtWindowHandle); cdecl;
  qt_window_set_title: procedure(AWin: QtWindowHandle; ATitle: PAnsiChar); cdecl;
  qt_window_get_title: function(AWin: QtWindowHandle): PAnsiChar; cdecl;
  qt_window_set_bounds: procedure(AWin: QtWindowHandle; AWidth, AHeight: Integer); cdecl;
  qt_window_get_bounds: procedure(AWin: QtWindowHandle; AWidth, AHeight: PInteger); cdecl;
  qt_window_show: procedure(AWin: QtWindowHandle); cdecl;
  qt_window_hide: procedure(AWin: QtWindowHandle); cdecl;
  qt_window_close: procedure(AWin: QtWindowHandle); cdecl;
  qt_window_is_visible: function(AWin: QtWindowHandle): Integer; cdecl;
  qt_window_get_scale: function(AWin: QtWindowHandle): Double; cdecl;
  qt_window_get_native_handle: function(AWin: QtWindowHandle): QtNativeHandle; cdecl;

  { ---- Dispatcher 投递（对齐 IWindowDispatcher.Post） ---- }
  qt_dispatcher_post: procedure(AWin: QtWindowHandle; AProc: TQtDispatcherProc; AData: Pointer; ANotify: TQtDispatcherNotify); cdecl;

implementation

end.
