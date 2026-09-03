unit nextpas.core.gtk3.ffi;

{** @desc GTK3 子集 ABI 声明层（gtk3 家族）。
       只含窗口壳必需的 GLib/GTK 类型与函数指针变量——无逻辑、无 external；
       绑定真相归 gtk3.loader（经 nextpas.core.platform.dl）。

       来源：GTK3 / GLib / GObject 官方头（gtk/gtk.h, gdk/gdk.h, glib.h）。
       本单元禁止 uses 家族其他单元（仅允许 base，INV-5）。 *}

{$I nextpas.core.settings.inc}
{$IF 0}
{$mode objfpc}{$H+}
{$ENDIF}

interface

uses
  nextpas.core.gtk3.base;

type
  {** 回调签名（glib/gtk 官方头同名类型） *}
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

var
  { GLib }
  g_idle_add_full: function(APriority: gint; AFunc: TGIdleFunc;
    AUserData: Pointer; ANotify: TGDestroyNotify): guint; cdecl;
  g_source_remove: function(ATag: guint): gboolean; cdecl;
  g_signal_connect_data: function(AInstance: Pointer; ADetailedSignal: PAnsiChar;
    AHandler: Pointer; AData: Pointer; ADestroyData: TGDestroyNotify;
    AConnectFlags: guint): gulong; cdecl;
  g_signal_handler_disconnect: procedure(AInstance: Pointer; AHandlerId: gulong); cdecl;
  g_timeout_add: function(AInterval: guint; AFunc: TGIdleFunc;
    AData: Pointer): guint; cdecl;

  { GObject }
  g_object_unref: procedure(AObject: Pointer); cdecl;

  { GTK3 窗口壳 }
  gtk_init_check: function(AArgc: PInt32; AArgv: PPAnsiChar): gboolean; cdecl;
  gtk_window_new: function(AType: gint): Pointer; cdecl;
  gtk_window_set_title: procedure(AWindow: Pointer; ATitle: PAnsiChar); cdecl;
  gtk_window_get_title: function(AWindow: Pointer): PAnsiChar; cdecl;
  gtk_window_set_default_size: procedure(AWindow: Pointer; AWidth, AHeight: gint); cdecl;
  gtk_window_set_resizable: procedure(AWindow: Pointer; AResizable: gboolean); cdecl;
  gtk_window_resize: procedure(AWindow: Pointer; AWidth, AHeight: gint); cdecl;
  gtk_window_maximize: procedure(AWindow: Pointer); cdecl;
  gtk_window_unmaximize: procedure(AWindow: Pointer); cdecl;
  gtk_window_iconify: procedure(AWindow: Pointer); cdecl;
  gtk_window_deiconify: procedure(AWindow: Pointer); cdecl;
  gtk_window_is_maximized: function(AWindow: Pointer): gboolean; cdecl;
  gtk_widget_show_all: procedure(AWidget: Pointer); cdecl;
  gtk_widget_hide: procedure(AWidget: Pointer); cdecl;
  gtk_widget_get_visible: function(AWidget: Pointer): gboolean; cdecl;
  gtk_widget_get_scale_factor: function(AWidget: Pointer): gint; cdecl;
  gtk_widget_grab_focus: procedure(AWidget: Pointer); cdecl;
  gtk_widget_get_window: function(AWidget: Pointer): Pointer; cdecl;
  gtk_widget_destroy: procedure(AWidget: Pointer); cdecl;
  gtk_widget_get_allocated_width: function(AWidget: Pointer): gint; cdecl;
  gtk_widget_get_allocated_height: function(AWidget: Pointer): gint; cdecl;
  gdk_window_get_state: function(AWindow: Pointer): guint; cdecl;
  gtk_container_add: procedure(AContainer: Pointer; AWidget: Pointer); cdecl;
  gtk_container_remove: procedure(AContainer: Pointer; AWidget: Pointer); cdecl;
  gtk_widget_show: procedure(AWidget: Pointer); cdecl;
  gtk_main: procedure; cdecl;
  gtk_main_quit: procedure; cdecl;
  gtk_main_iteration_do: function(ABlocking: gboolean): gboolean; cdecl;
  gtk_events_pending: function: gboolean; cdecl;

implementation

end.
