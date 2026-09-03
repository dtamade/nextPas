unit nextpas.core.gtk2.ffi;

{** @desc GTK2 窗口子集 ABI 声明层（gtk2 家族）。
       只含窗口壳必需的 GLib/GTK 类型与函数指针变量——无逻辑、无 external；
       绑定真相归 gtk2.loader（经 nextpas.core.platform.dl）。

       来源：GTK2 / GLib / GObject 官方头（gtk/gtk.h, gdk/gdk.h, glib.h）。
       GTK2 差异：无 gtk_widget_get_scale_factor（该符号自 GTK 3.10 引入），
       以 BindOpt 可选绑定，其余窗口函数同 gtk3 子集。
       本单元禁止 uses 家族其他单元（INV-5）。 *}

{$I nextpas.core.settings.inc}

interface

type
  gboolean = Int32;
  guint = Cardinal;
  gulong = QWord;
  guint32 = Cardinal;
  gint = Int32;

const
  GDK_WINDOW_STATE_WITHDRAWN  = 1 shl 0;
  GDK_WINDOW_STATE_ICONIFIED  = 1 shl 1;
  GDK_WINDOW_STATE_MAXIMIZED  = 1 shl 2;

  GLIB_SOURCE_REMOVE   = 0;
  GLIB_SOURCE_CONTINUE = 1;
  G_PRIORITY_DEFAULT   = 0;

  GTK_WINDOW_TOPLEVEL = 0;

type
  TGCallback = procedure(AFirst: Pointer); cdecl;
  TGDestroyNotify = procedure(AData: Pointer); cdecl;
  TGIdleFunc = function(AUserData: Pointer): gboolean; cdecl;
  TGtkDeleteEventFunc = function(AWidget: Pointer; AEvent: Pointer;
    AUserData: Pointer): gboolean; cdecl;
  TGtkConfigureEventFunc = function(AWidget: Pointer; AEvent: Pointer;
    AUserData: Pointer): gboolean; cdecl;
  TGtkFocusEventFunc = function(AWidget: Pointer; AEvent: Pointer;
    AUserData: Pointer): gboolean; cdecl;
  TGtkWindowStateEventFunc = function(AWidget: Pointer; AEvent: Pointer;
    AUserData: Pointer): gboolean; cdecl;
  TGtkNotifyScaleFunc = procedure(AObj: Pointer; AParam: Pointer;
    AUserData: Pointer); cdecl;
  TGtkDestroyFunc = procedure(AWidget: Pointer; AUserData: Pointer); cdecl;

  // 显式单源：GTK 窗口壳 ABI 函数指针类型单表，手写零 codegen 缝，显式可扫描
  TGIdleAddFullFunc = function(APriority: gint; AFunc: TGIdleFunc; AUserData: Pointer; ANotify: TGDestroyNotify): guint; cdecl;
  TSourceRemoveFunc = function(ATag: guint): gboolean; cdecl;
  TSignalConnectFunc = function(AInstance: Pointer; ADetailedSignal: PAnsiChar; AHandler: Pointer; AData: Pointer; ADestroyData: TGDestroyNotify; AConnectFlags: guint): gulong; cdecl;
  TSignalDisconnectProc = procedure(AInstance: Pointer; AHandlerId: gulong); cdecl;
  TGtkInitCheckFunc = function(AArgc: PInt32; AArgv: PPAnsiChar): gboolean; cdecl;
  TGtkWindowNewFunc = function(AType: gint): Pointer; cdecl;
  TGtkWindowSetTitleProc = procedure(AWindow: Pointer; ATitle: PAnsiChar); cdecl;
  TGtkWindowGetTitleFunc = function(AWindow: Pointer): PAnsiChar; cdecl;
  TGtkWindowSetDefaultSizeProc = procedure(AWindow: Pointer; AWidth, AHeight: gint); cdecl;
  TGtkWindowSetResizableProc = procedure(AWindow: Pointer; AResizable: gboolean); cdecl;
  TGtkWindowResizeProc = procedure(AWindow: Pointer; AWidth, AHeight: gint); cdecl;
  TGtkWindowMaximizeProc = procedure(AWindow: Pointer); cdecl;
  TGtkWindowUnmaximizeProc = procedure(AWindow: Pointer); cdecl;
  TGtkWindowIconifyProc = procedure(AWindow: Pointer); cdecl;
  TGtkWindowDeiconifyProc = procedure(AWindow: Pointer); cdecl;
  TGtkWindowIsMaximizedFunc = function(AWindow: Pointer): gboolean; cdecl;
  TGtkWidgetShowAllProc = procedure(AWidget: Pointer); cdecl;
  TGtkWidgetHideProc = procedure(AWidget: Pointer); cdecl;
  TGtkWidgetGetVisibleFunc = function(AWidget: Pointer): gboolean; cdecl;
  TGtkWidgetGetScaleFactorFunc = function(AWidget: Pointer): gint; cdecl;
  TGtkWidgetGrabFocusProc = procedure(AWidget: Pointer); cdecl;
  TGtkWidgetGetWindowFunc = function(AWidget: Pointer): Pointer; cdecl;
  TGtkWidgetDestroyProc = procedure(AWidget: Pointer); cdecl;
  TGtkWidgetGetAllocatedWidthFunc = function(AWidget: Pointer): gint; cdecl;
  TGtkWidgetGetAllocatedHeightFunc = function(AWidget: Pointer): gint; cdecl;
  TGdkWindowGetStateFunc = function(AWindow: Pointer): guint; cdecl;
  TGtkMainProc = procedure; cdecl;
  TGtkMainQuitProc = procedure; cdecl;
  TGtkMainIterationDoFunc = function(ABlocking: gboolean): gboolean; cdecl;
  TGtkEventsPendingFunc = function: gboolean; cdecl;

var
  { GLib — 显式类型零 codegen }
  g_idle_add_full: TGIdleAddFullFunc;
  g_source_remove: TSourceRemoveFunc;
  g_signal_connect_data: TSignalConnectFunc;
  g_signal_handler_disconnect: TSignalDisconnectProc;
  g_timeout_add: function(AInterval: guint; AFunc: TGIdleFunc;
    AData: Pointer): guint; cdecl;

  { GObject }
  g_object_unref: procedure(AObject: Pointer); cdecl;

  { GTK2 窗口壳 — 显式类型零 codegen，唯 scale_factor 可选 }
  gtk_init_check: TGtkInitCheckFunc;
  gtk_window_new: TGtkWindowNewFunc;
  gtk_window_set_title: TGtkWindowSetTitleProc;
  gtk_window_get_title: TGtkWindowGetTitleFunc;
  gtk_window_set_default_size: TGtkWindowSetDefaultSizeProc;
  gtk_window_set_resizable: TGtkWindowSetResizableProc;
  gtk_window_resize: TGtkWindowResizeProc;
  gtk_window_maximize: TGtkWindowMaximizeProc;
  gtk_window_unmaximize: TGtkWindowUnmaximizeProc;
  gtk_window_iconify: TGtkWindowIconifyProc;
  gtk_window_deiconify: TGtkWindowDeiconifyProc;
  gtk_window_is_maximized: TGtkWindowIsMaximizedFunc;
  gtk_widget_show_all: TGtkWidgetShowAllProc;
  gtk_widget_hide: TGtkWidgetHideProc;
  gtk_widget_get_visible: TGtkWidgetGetVisibleFunc;
  gtk_widget_get_scale_factor: TGtkWidgetGetScaleFactorFunc;
  gtk_widget_grab_focus: TGtkWidgetGrabFocusProc;
  gtk_widget_get_window: TGtkWidgetGetWindowFunc;
  gtk_widget_destroy: TGtkWidgetDestroyProc;
  gtk_widget_get_allocated_width: TGtkWidgetGetAllocatedWidthFunc;
  gtk_widget_get_allocated_height: TGtkWidgetGetAllocatedHeightFunc;
  gdk_window_get_state: TGdkWindowGetStateFunc;
  gtk_main: TGtkMainProc;
  gtk_main_quit: TGtkMainQuitProc;
  gtk_main_iteration_do: TGtkMainIterationDoFunc;
  gtk_events_pending: TGtkEventsPendingFunc;

implementation

end.
