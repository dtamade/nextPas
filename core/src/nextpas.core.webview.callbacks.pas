unit nextpas.core.webview.callbacks;

{** @desc webview 家族公共回调适配器（method/proc → reference 单源）。

       目的：消除 fake/wk/gtk/webview2 四后端对三形态归一包装的重复拷贝。
       单源收敛到 bytes.ops/thread 单源思想：inline、零拷贝闭包、薄转发
       无额外堆分配（reference 闭包由编译器在调用点按需分配）。

       约束：
       - 只依赖 base/intf 的命名类型，不依赖任何后端/bridge/factory（L3 内单向）
       - 所有函数 inline，零额外调用，保持 hot path I-Cache 友好
       - 与 window.intf 的 WindowMethodToRef / EventMethodToRef 同构，
         单源可审计（见 test_webview_callbacks） *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.webview.intf;

function WebviewNotifyMethodToRef(AHandler: TWebviewNotifyMethod): TWebviewNotifyHandler; inline;
function WebviewNotifyProcToRef(AHandler: TWebviewNotifyProc): TWebviewNotifyHandler; inline;
function WebviewNavMethodToRef(AHandler: TWebviewNavEventMethod): TWebviewNavEventHandler; inline;
function WebviewNavProcToRef(AHandler: TWebviewNavEventProc): TWebviewNavEventHandler; inline;
function WebviewNavFailedMethodToRef(AHandler: TWebviewNavFailedMethod): TWebviewNavFailedHandler; inline;
function WebviewNavFailedProcToRef(AHandler: TWebviewNavFailedProc): TWebviewNavFailedHandler; inline;
function WebviewScaleMethodToRef(AHandler: TWebviewScaleMethod): TWebviewScaleHandler; inline;
function WebviewScaleProcToRef(AHandler: TWebviewScaleProc): TWebviewScaleHandler; inline;
function WebviewProcMethodToRef(AHandler: TWebviewProcMethod): TWebviewProcRef; inline;
function WebviewProcToRef(AHandler: TWebviewProc): TWebviewProcRef; inline;

implementation

function WebviewNotifyMethodToRef(AHandler: TWebviewNotifyMethod): TWebviewNotifyHandler; inline;
begin
  Result := procedure begin AHandler; end;
end;

function WebviewNotifyProcToRef(AHandler: TWebviewNotifyProc): TWebviewNotifyHandler; inline;
begin
  Result := procedure begin AHandler; end;
end;

function WebviewNavMethodToRef(AHandler: TWebviewNavEventMethod): TWebviewNavEventHandler; inline;
begin
  Result := procedure(const AEvent: TWebviewNavigationEvent) begin AHandler(AEvent); end;
end;

function WebviewNavProcToRef(AHandler: TWebviewNavEventProc): TWebviewNavEventHandler; inline;
begin
  Result := procedure(const AEvent: TWebviewNavigationEvent) begin AHandler(AEvent); end;
end;

function WebviewNavFailedMethodToRef(AHandler: TWebviewNavFailedMethod): TWebviewNavFailedHandler; inline;
begin
  Result := procedure(const AEvent: TWebviewNavigationEvent) begin AHandler(AEvent); end;
end;

function WebviewNavFailedProcToRef(AHandler: TWebviewNavFailedProc): TWebviewNavFailedHandler; inline;
begin
  Result := procedure(const AEvent: TWebviewNavigationEvent) begin AHandler(AEvent); end;
end;

function WebviewScaleMethodToRef(AHandler: TWebviewScaleMethod): TWebviewScaleHandler; inline;
begin
  Result := procedure(ANewScale: Double) begin AHandler(ANewScale); end;
end;

function WebviewScaleProcToRef(AHandler: TWebviewScaleProc): TWebviewScaleHandler; inline;
begin
  Result := procedure(ANewScale: Double) begin AHandler(ANewScale); end;
end;

function WebviewProcMethodToRef(AHandler: TWebviewProcMethod): TWebviewProcRef; inline;
begin
  Result := procedure begin AHandler(); end;
end;

function WebviewProcToRef(AHandler: TWebviewProc): TWebviewProcRef; inline;
begin
  Result := procedure begin AHandler(); end;
end;

end.
