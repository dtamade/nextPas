unit nextpas.core.webview.wk.ffi;

{** @desc WKWebView ABI 声明层（Wave 3 预研桩）。

       仅含不透明句柄与占位类型——无逻辑、无 external；
       绑定真相归 wk.loader（经 platform.dl）。
       当前阶段为桩：Linux 宿主上不尝试装载，Darwin 上预留
       Objective-C 运行时探针位。 *}

{$I nextpas.core.settings.inc}

interface

type
  WKLoadInfo = record
    Loaded: Boolean;
    DllName: string;
  end;

implementation

end.
