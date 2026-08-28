unit nextpas.core.gtk4.base;

{** @desc nextpas.core.gtk4 L2 家族：公共类型与常量根。
       仅承载 GTK4 窗口壳必需的常量与轻量载体，不含逻辑与 ABI 绑定。

       依赖方向：base 不依赖家族任何其他单元（INV-4）。 *}

{$I nextpas.core.settings.inc}

interface

const
  {** GTK 窗口类型（GtkWindowType 序）。
     GTK4 中 GtkWindowType 已弃用（gtk_window_new 无参化，API 侧忽略该参数），
     但数值仍为 0 的 GTK_WINDOW_TOPLEVEL 在 ABI 兼容层保留 —— 旧代码
     传 0 仍等价于顶层窗口；新代码应以 gtk_window_new / gtk_window_set_child
     替代。 *}
  GTK_WINDOW_TOPLEVEL = 0;

  {** GdkSurfaceState 位（GTK4 替代 GdkWindowState）。
     gdk_surface_get_state 返回位掩码，语义与 GTK3 的 gdk_window_get_state
     等价；GTK4 中 GdkWindow 更名为 GdkSurface。 *}
  GDK_SURFACE_STATE_WITHDRAWN = 1 shl 0;
  GDK_SURFACE_STATE_ICONIFIED = 1 shl 1;
  GDK_SURFACE_STATE_MAXIMIZED = 1 shl 2;
  { 兼容别名：沿用 GTK3 命名供调用方渐进迁移 }
  GDK_WINDOW_STATE_WITHDRAWN = GDK_SURFACE_STATE_WITHDRAWN;
  GDK_WINDOW_STATE_ICONIFIED = GDK_SURFACE_STATE_ICONIFIED;
  GDK_WINDOW_STATE_MAXIMIZED = GDK_SURFACE_STATE_MAXIMIZED;

  {** GLib 主循环源返回值（同 GTK3） *}
  GLIB_SOURCE_REMOVE   = 0;
  GLIB_SOURCE_CONTINUE = 1;
  G_PRIORITY_DEFAULT   = 0;

implementation

end.
