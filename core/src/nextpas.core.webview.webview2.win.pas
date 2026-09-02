unit nextpas.core.webview.webview2.win;

{** @desc REMOVED per ROADMAP S105 — M6 has-a 收口完成，双 compat debt 集中下线。
       本单元已退化为空单元占位（文件保留至下一主版本物理删除），原 Win32Shell* 15 项
       deprecated inline 薄转发桩已清理（窗口壳唯一事实源为 nextpas.core.window.win32
       的 IWindow/WindowRunLoop，调度经 IWindow.Dispatcher.Post，L2 单源已收口）。
       零状态零分配、释放不丢（所有权归 window.win32）；性能：零拷贝零额外调用（无转发层）。
       新代码直接 uses window.win32 / window.intf IWindow；
       业务以 CONTRACT 为准，缺能力先反哺 owner（window.win32）。 *}

{$I nextpas.core.settings.inc}

interface

implementation

end.
