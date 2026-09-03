unit nextpas.core.window.gtk4.ffi;

{** @desc window.gtk4 FFI 互操作层（纯 ABI 缝，非机械 re-export）。
       真实 owner 为 nextpas.core.gtk4.ffi（L2 独立家族，base←ffi←loader）；
       本单元仅承载 window 域对 GTK4 的窗口级互操作补集，非全量 ABI 复刻——
       按设计规范 §2 按需存在：无独立职责不建 ffi，有职责才保留。

       职责边界（CONTRACT §2/§7）：
       - TWindowNativeHandle ↔ GtkWindow*/GdkSurface* 零拷贝指针互转（window 语义，gtk 侧不知 window）：
         互转在调用点 inline 纯指针 cast（Result := TGtk4WindowHandle(AHandle)），零分配/零拷贝，16ns 早退同源。
       - 可选 X11 XID 抽取符号（gdk_x11_window_get_xid），仅 window 句柄诚实表需要，generic gtk4.ffi 未覆盖。
       - 标题 bytes 单源：owner 为 nextpas.core.bytes.ops.StringToBytes/BytesToString 与
         nextpas.core.text.ansi.StrToPAnsiView；本 ffi 不承载拷贝逻辑，不重复 Move/SetLength，
         保持 *.ffi 无逻辑无 external 纯 ABI（INV-5），L0-L3 守层（L2 不依赖 L1 bytes.ops）。
       性能：句柄互转在后端调用点 inline 零拷贝；标题零拷贝视图经 text.ansi 单源，gtk 同步拷贝。
       稳定性：句柄生命周期归宿主/GTK（gtk_widget_destroy），本单元仅只读持有、Close 时置 nil 不释放。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.window.base,
  nextpas.core.gtk4.ffi;

type
  {** GtkWindow* 不透明句柄别名，生命周期归 GTK，window 侧只读持有。 *}
  TGtk4WindowHandle = type Pointer;

const
  WINDOW_GTK4_FFI_HAS_X11_XID = True;

var
  {** 可选绑定：X11 会话下 XID 抽取（window.gtk4.loader BindOpt，缺失保持 nil）。
       Wayland 诚实 nil 路径不依赖此符号；gtk4 泛用层不声明，window 侧补集。 *}
  gdk_x11_window_get_xid: function(AWindow: Pointer): Cardinal; cdecl;

implementation

end.
