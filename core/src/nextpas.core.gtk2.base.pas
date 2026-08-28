unit nextpas.core.gtk2.base;

{** @desc nextpas.core.gtk2 L2 家族：公共类型与常量根。
       仅承载 GTK2 窗口壳必需的常量，同 gtk3 常量子集，无逻辑与 ABI 绑定。

       依赖方向：base 不依赖家族任何其他单元。 *}

{$I nextpas.core.settings.inc}

interface

const
  {** GTK 窗口类型（GtkWindowType 序）。GTK2/GTK3 复用同一数值。 *}
  GTK_WINDOW_TOPLEVEL = 0;

  GDK_WINDOW_STATE_WITHDRAWN  = 1 shl 0;
  GDK_WINDOW_STATE_ICONIFIED  = 1 shl 1;
  GDK_WINDOW_STATE_MAXIMIZED  = 1 shl 2;

  GLIB_SOURCE_REMOVE   = 0;
  GLIB_SOURCE_CONTINUE = 1;
  G_PRIORITY_DEFAULT   = 0;

implementation

end.
