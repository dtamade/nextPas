{ nextpas.core.window.gtk.ops.fields.inc — codegen 单源：TGtkOps 字段表，与 shell.types.inc 同源生成
  复用 bytes.ops 单源思想：单表驱动零手写重复，守四件套与 L0-L3，重用 inline 零拷贝。
  性能：record 直调单次字段间接零 vtable，inline 可折叠 Assigned，零额外虚派。 }
    TryLoad: TGtkTryLoadFunc;
    IdleAddFull: TGIdleAddFullFunc;
    SourceRemove: TSourceRemoveFunc;
    SignalConnectData: TSignalConnectFunc;
    SignalHandlerDisconnect: TSignalDisconnectProc;
    InitCheck: TGtkInitCheckFunc;
    WindowNew: TGtkWindowNewFunc;
    WindowSetTitle: TGtkWindowSetTitleProc;
    WindowGetTitle: TGtkWindowGetTitleFunc;
    WindowSetDefaultSize: TGtkWindowSetDefaultSizeProc;
    WindowSetResizable: TGtkWindowSetResizableProc;
    WindowResize: TGtkWindowResizeProc;
    WindowMaximize: TGtkWindowMaximizeProc;
    WindowUnmaximize: TGtkWindowUnmaximizeProc;
    WindowIconify: TGtkWindowIconifyProc;
    WindowDeiconify: TGtkWindowDeiconifyProc;
    WindowIsMaximized: TGtkWindowIsMaximizedFunc;
    WidgetShowAll: TGtkWidgetShowAllProc;
    WidgetHide: TGtkWidgetHideProc;
    WidgetGetVisible: TGtkWidgetGetVisibleFunc;
    WidgetGetScaleFactor: TGtkWidgetGetScaleFactorFunc;
    WidgetGrabFocus: TGtkWidgetGrabFocusProc;
    WidgetGetWindow: TGtkWidgetGetWindowFunc;
    WidgetDestroy: TGtkWidgetDestroyProc;
    WidgetGetAllocatedWidth: TGtkWidgetGetAllocatedWidthFunc;
    WidgetGetAllocatedHeight: TGtkWidgetGetAllocatedHeightFunc;
    GdkWindowGetState: TGdkWindowGetStateFunc;
    Main: TGtkMainProc;
    MainQuit: TGtkMainQuitProc;
    MainIterationDo: TGtkMainIterationDoFunc;
    EventsPending: TGtkEventsPendingFunc;
