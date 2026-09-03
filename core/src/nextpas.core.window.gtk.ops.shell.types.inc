{ nextpas.core.window.gtk.ops.shell.types.inc — codegen 单源：GTK 窗口壳 ABI 函数指针类型单表
  单源于 bytes.ops 思想：单一类型表驱动 ffi var / loader 绑定 / TGtkOps record 三处，零手写重复，守高级感。
  本表与 nextpas.core.gtk{2,3,4}.ffi var 签名同源，TGtkOps 字段经 nextpas.core.window.gtk.ops.fields.inc 复用同一类型，
  手维护 19+ 重复消除，inline 零额外调用，零拷贝视图透传。
  性能：cdecl 函数指针单次字段间接零 vtable，Assigned 检查 inline 可折叠，零虚派。
  稳定性：类型与符号一一对应，缺失编译期显式。
  生成：与 ffi 签名同表，禁止在外手写重复；扩展仅改此表即同步。 }
  TGIdleAddFullFunc = function(APriority: gint; AFunc: TGtkIdleFunc; AUserData: Pointer; ANotify: TGDestroyNotify): guint; cdecl;
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
