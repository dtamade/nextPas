unit nextpas.core.webview.metrics;

{** @desc webview 家族可观测性 Owner：帧超限背压计数单源。
       bridge 不再自持 UI 线程全局，委托本 Owner 统一承载；
       bench/log 通用可观测面复用候选独立指标模块（L3，可抽 L2 metrics 单源时序见 CONTRACT §1.2）。
       当前 plain UInt64 UI 线程亲和（无 atomic，caller 外层同步跨线程可见性）；
       性能 inline 薄转发零额外调用，稳定性 Default 释放不丢。 }

{$I nextpas.core.settings.inc}

interface

{ 背压可观测：超限帧计数（单调递增，UI 线程亲和，plain 全局，跨线程需外层同步；L3 metrics Owner 单源承载，复用 bench/log 可观测 Owner 候选） }
function WebviewMetricsOversizedCount: UInt64; inline;
procedure WebviewMetricsResetOversizedCount; inline;
procedure WebviewMetricsNoteOversized(ASize: SizeUInt); inline;

implementation

var
  GWebviewOversizedFrames: UInt64 = 0;

function WebviewMetricsOversizedCount: UInt64; inline;
begin
  Result := GWebviewOversizedFrames;
end;

procedure WebviewMetricsResetOversizedCount; inline;
begin
  GWebviewOversizedFrames := 0;
end;

procedure WebviewMetricsNoteOversized(ASize: SizeUInt); inline;
begin
  Inc(GWebviewOversizedFrames);
  if ASize = 0 then ;
end;

end.
