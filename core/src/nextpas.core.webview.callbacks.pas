unit nextpas.core.webview.callbacks;

{** @desc webview 家族公共回调适配器（method/proc → reference 单源）。

       目的：消除 fake/wk/gtk/webview2 四后端对三形态归一包装的重复拷贝。
       单源收敛到 bytes.ops/thread 单源思想：inline、零拷贝闭包、薄转发
       无额外堆分配（reference 闭包由编译器在调用点按需分配）。

       约束与可抽候选登记（CONTRACT §1.2）：
       - 只依赖 base/intf + L0 base.callbacks 单源，不依赖任何后端/bridge/factory（L3 内单向，L0→L1→L2→L3 守恒）
       - 所有函数 inline 薄转发至 L0 base.callbacks 单源，零额外调用，保持 hot path I-Cache 友好
       - 与 window.intf 的 WindowMethodToRef / EventMethodToRef 同构，已收敛至 L0 base.callbacks 单源可审计（见 test_webview_callbacks）；跨家族重复已评估，当前家族内薄转发保留，反哺 Owner L0 base.callbacks 已落地，抽取经设计评审不自行外溢
       - 性能：inline + 零拷贝闭包（Move 零拷贝，捕获仅方法/过程指针），单源治理重复实现漂移；稳定性：纯转发无所有权接管，Finalize 不丢 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.webview.intf,
  nextpas.core.base.callbacks;

type
  { 单源锚点：显式关联 L0 base.callbacks 单源，避免悬空重复，inline 零成本 }
  _WebviewCallbacksBaseAnchor = nextpas.core.base.callbacks.TCallbackScaleHandler;

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
  { inline thin forward to L0 single source, zero extra call, zero-copy closure (Move only) }
  Result := TWebviewNotifyHandler(CallbackNotifyMethodToRef(AHandler));
end;

function WebviewNotifyProcToRef(AHandler: TWebviewNotifyProc): TWebviewNotifyHandler; inline;
begin
  Result := TWebviewNotifyHandler(CallbackNotifyProcToRef(AHandler));
end;

function WebviewNavMethodToRef(AHandler: TWebviewNavEventMethod): TWebviewNavEventHandler; inline;
begin
  Result := TWebviewNavEventHandler(specialize CallbackEventMethodToRef<TWebviewNavigationEvent>(AHandler));
end;

function WebviewNavProcToRef(AHandler: TWebviewNavEventProc): TWebviewNavEventHandler; inline;
begin
  Result := TWebviewNavEventHandler(specialize CallbackEventProcToRef<TWebviewNavigationEvent>(AHandler));
end;

function WebviewNavFailedMethodToRef(AHandler: TWebviewNavFailedMethod): TWebviewNavFailedHandler; inline;
begin
  Result := TWebviewNavFailedHandler(specialize CallbackEventMethodToRef<TWebviewNavigationEvent>(AHandler));
end;

function WebviewNavFailedProcToRef(AHandler: TWebviewNavFailedProc): TWebviewNavFailedHandler; inline;
begin
  Result := TWebviewNavFailedHandler(specialize CallbackEventProcToRef<TWebviewNavigationEvent>(AHandler));
end;

function WebviewScaleMethodToRef(AHandler: TWebviewScaleMethod): TWebviewScaleHandler; inline;
begin
  Result := TWebviewScaleHandler(CallbackScaleMethodToRef(TCallbackScaleMethod(AHandler)));
end;

function WebviewScaleProcToRef(AHandler: TWebviewScaleProc): TWebviewScaleHandler; inline;
begin
  Result := TWebviewScaleHandler(CallbackScaleProcToRef(TCallbackScaleProc(AHandler)));
end;

function WebviewProcMethodToRef(AHandler: TWebviewProcMethod): TWebviewProcRef; inline;
begin
  Result := TWebviewProcRef(CallbackNotifyMethodToRef(AHandler));
end;

function WebviewProcToRef(AHandler: TWebviewProc): TWebviewProcRef; inline;
begin
  Result := TWebviewProcRef(CallbackNotifyProcToRef(AHandler));
end;

end.
