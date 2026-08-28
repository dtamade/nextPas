unit nextpas.core.gtk3.base;

{** @desc nextpas.core.gtk3 L2 家族：公共类型与常量根。
       仅承载 GTK3 窗口壳必需的常量与轻量载体，不含逻辑与 ABI 绑定。

       依赖方向：base 不依赖家族任何其他单元（INV-4），只含常量与类型；
       来源：GTK3 / GLib / GObject 官方头（gtk/gtk.h, gdk/gdk.h, glib.h）。
       纹理：uses 仅允许 FPC RTL。 *}

{$I nextpas.core.settings.inc}
{$IF 0}
{$mode objfpc}{$H+}
{$ENDIF}

interface

type
  {** GLib 基础整型别名，对齐官方头 glib.h *}
  gboolean = Int32;
  guint = Cardinal;
  gulong = QWord;
  guint32 = Cardinal;
  gint = Int32;

const
  {** GdkWindowState 位掩码（gdk/gdkwindow.h） *}
  GDK_WINDOW_STATE_WITHDRAWN  = 1 shl 0;
  GDK_WINDOW_STATE_ICONIFIED  = 1 shl 1;
  GDK_WINDOW_STATE_MAXIMIZED  = 1 shl 2;

  {** GLib 主循环源返回值（glib.h） *}
  GLIB_SOURCE_REMOVE   = 0;
  GLIB_SOURCE_CONTINUE = 1;
  G_PRIORITY_DEFAULT   = 0;

  {** GtkWindowType 枚举（gtk/gtkwindow.h），仅需 TOPLEVEL *}
  GTK_WINDOW_TOPLEVEL = 0;

implementation

end.
