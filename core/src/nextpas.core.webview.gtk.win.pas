unit nextpas.core.webview.gtk.win;

{** @desc REMOVED per ROADMAP S105 — F4 shim 已清理，门面冗余移除。
       窗口壳唯一事实源为 nextpas.core.window.gtk3 的 WindowGtkRaw* 12 项
       inline 薄转发（L2 单源，L3 has-a 组合，已收口至 window.factory 单泵）。
       本文件保留为空单元占位至下一主版本物理删除，不含任何 WinShell* 逻辑，
       零状态零分配、释放不丢（所有权归 window.gtk3）。新代码直接 uses
       window.gtk3 / window.intf IWindow；性能：零拷贝零额外调用（无转发层）。
       业务以 CONTRACT 为准，缺能力先反哺 owner（window.gtk3）。 *}

{$I nextpas.core.settings.inc}

interface

implementation

end.
