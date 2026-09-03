unit nextpas.core.webview.wk.ffi;

{** @desc WKWebView ABI 声明层（Wave 3 桩→S106 探针闭环）。

       仅含不透明句柄与占位类型——无逻辑、无 external；
       绑定真相归 wk.loader（经 platform.dl 真探 WebKit.framework/libobjc）。
       S106探针闭环：Linux诚实False（dlopen失败），Darwin按框架存在性诚实；
       Darwin真实现复用 nextpas.core.window.cocoa 的 ObjC运行时（纯C objc_msgSend），
       本单元不自建ObjC链，落地路径已闭环。 *}

{$I nextpas.core.settings.inc}

interface

type
  WKLoadInfo = record
    Loaded: Boolean;
    DllName: string;
  end;

implementation

end.
