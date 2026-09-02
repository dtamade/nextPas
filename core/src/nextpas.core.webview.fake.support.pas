unit nextpas.core.webview.fake.support;

{** @desc webview fake 支撑子模块：回调适配与选项辅助。

       拆分治理（S105+）：原单文件 1580 行已按 design-conventions 四件套与
       L0-L3 单向依赖拆为 dispatcher/support 等子模块；
       本单元承载 MapInvokeCode 回调适配与 WindowOptions 辅助，
       均 inline 薄转发至 L0/L1 单源（webview.callbacks + bridge + window.base），
       零拷贝、零额外调用，bytes.ops 单源复用。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.webview.base,
  nextpas.core.webview.intf,
  nextpas.core.webview.bridge,
  nextpas.core.webview.callbacks,
  nextpas.core.bytes.ops;

{ handler 异常 → 协议错误码映射：唯一实现移至 bridge（NormalizeInvokeCode），fake 与未来真实后端共用同一映射，避免双处定义漂移。 }
function MapInvokeCode(const ACode: string): string; inline;

{ ---- 回调归一化（method/proc → reference）----
  统一存储范式（design-conventions §8）：内部只存 reference 形态。
  单源：nextpas.core.webview.callbacks inline 薄转发，零拷贝闭包，消除四后端重复。 }

function NotifyMethodToRef(AHandler: TWebviewNotifyMethod): TWebviewNotifyHandler; inline;
function NotifyProcToRef(AHandler: TWebviewNotifyProc): TWebviewNotifyHandler; inline;
function NavMethodToRef(AHandler: TWebviewNavEventMethod): TWebviewNavEventHandler; inline;
function NavProcToRef(AHandler: TWebviewNavEventProc): TWebviewNavEventHandler; inline;
function NavFailedMethodToRef(AHandler: TWebviewNavFailedMethod): TWebviewNavFailedHandler; inline;
function NavFailedProcToRef(AHandler: TWebviewNavFailedProc): TWebviewNavFailedHandler; inline;
function ScaleMethodToRef(AHandler: TWebviewScaleMethod): TWebviewScaleHandler; inline;
function ScaleProcToRef(AHandler: TWebviewScaleProc): TWebviewScaleHandler; inline;

{ WindowOptions 辅助：与 window.base DefaultWindowOptions 对齐 }
function WindowOptionsOf(const AOptions: TWebviewOptions): nextpas.core.window.base.TWindowOptions; inline;

implementation

uses
  nextpas.core.window.base;

function MapInvokeCode(const ACode: string): string; inline;
begin
  Result := NormalizeInvokeCode(ACode);
end;

function NotifyMethodToRef(AHandler: TWebviewNotifyMethod): TWebviewNotifyHandler; inline;
begin
  Result := WebviewNotifyMethodToRef(AHandler);
end;

function NotifyProcToRef(AHandler: TWebviewNotifyProc): TWebviewNotifyHandler; inline;
begin
  Result := WebviewNotifyProcToRef(AHandler);
end;

function NavMethodToRef(AHandler: TWebviewNavEventMethod): TWebviewNavEventHandler; inline;
begin
  Result := WebviewNavMethodToRef(AHandler);
end;

function NavProcToRef(AHandler: TWebviewNavEventProc): TWebviewNavEventHandler; inline;
begin
  Result := WebviewNavProcToRef(AHandler);
end;

function NavFailedMethodToRef(AHandler: TWebviewNavFailedMethod): TWebviewNavFailedHandler; inline;
begin
  Result := WebviewNavFailedMethodToRef(AHandler);
end;

function NavFailedProcToRef(AHandler: TWebviewNavFailedProc): TWebviewNavFailedHandler; inline;
begin
  Result := WebviewNavFailedProcToRef(AHandler);
end;

function ScaleMethodToRef(AHandler: TWebviewScaleMethod): TWebviewScaleHandler; inline;
begin
  Result := WebviewScaleMethodToRef(AHandler);
end;

function ScaleProcToRef(AHandler: TWebviewScaleProc): TWebviewScaleHandler; inline;
begin
  Result := WebviewScaleProcToRef(AHandler);
end;

function WindowOptionsOf(const AOptions: TWebviewOptions): nextpas.core.window.base.TWindowOptions; inline;
begin
  // perf: thin forward to window.base single source WindowOptionsCreate inline zero-copy, eliminates 8-field duplication with gtk.shell
  Result := WindowOptionsCreate(AOptions.Title, AOptions.Width, AOptions.Height,
    AOptions.MinWidth, AOptions.MinHeight, AOptions.MaxWidth, AOptions.MaxHeight,
    AOptions.Resizable, AOptions.Maximized);
end;

end.
