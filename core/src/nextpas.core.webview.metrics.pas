unit nextpas.core.webview.metrics;

{** @desc webview 家族可观测性 Owner：帧超限背压计数单源（L3）。
       bridge 不再自持 UI 线程全局，委托本 Owner 统一承载；常量即契约单源零漂移。
       与 bench/log 通用可观测能力重叠已评估：bench 为 tooling harness 时序统计
       （TBenchResult/CustomMetrics）、log 为 L1 结构化日志（ILogSink），均不提供
       UI 线程亲和 plain UInt64 背压单调计数；帧阈值 1 MiB 为 BRIDGE_PROTOCOL §6
       业务 Hard Limit，非通用指标，故暂落 L3，可抽 L2 metrics 单源候选见
       CONTRACT §1.2（通用计数器/直方图/prometheus Owner 落地时统一反哺 thin-forward），
       未落地前本 Owner 为单一事实源零重复定义。
       性能 inline 薄转发零额外调用（IsOversized* TStringView.Len 零拷贝视图判定，
       复用 bytes.ops 单源思想 inline 零额外调用）、稳定性 plain 全局零句柄
       Default 释放不丢、线程 UI 线程亲和（无 atomic，跨线程需外层同步）。 }

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.text.view;

const
  { 帧长上限：BRIDGE_PROTOCOL §6 业务建议 1 MiB Hard Limit 统一命名常量。
    单源契约：复用 bytes.ops 单源思想（常量即契约，消除魔法数字漂移；阈值判定
    复用 TStringView.Len 零拷贝视图思想，inline 零额外调用与 bytes.ops
    TCompactLiveRegistry/VecGrow 单源同源）；与文档 §6 一致。
    Owner 收敛：由 metrics 单源承载（L3），bridge 仅复用本常量
    NPW_MAX_FRAME_BYTES 薄转发 alias 零双处定义漂移；可抽 L2 metrics 单源候选
    （见 CONTRACT §1.2，通用计数器/直方图 Owner 落地时统一反哺）未落地前不外溢，
    业务以 CONTRACT 为准、缺能力先反哺 Owner。 }
  WEBVIEW_MAX_FRAME_BYTES = 1 * 1024 * 1024;

{ 背压可观测：超限帧计数（单调递增，UI 线程亲和，plain 全局零句柄，跨线程需外层同步；
    L3 metrics Owner 单源承载，bench/log 通用可观测 Owner 候选可抽 L2 metrics 单源
    见 CONTRACT §1.2，未落地前本单元单一事实源；inline 薄转发零额外调用，
    Default 释放不丢） }
function WebviewMetricsOversizedCount: UInt64; inline;
procedure WebviewMetricsResetOversizedCount; inline;
procedure WebviewMetricsNoteOversized({%H-}ASize: SizeUInt); inline;
{ 帧超限判定单源（Owner: metrics）：复用 bytes.ops 零拷贝视图思想（TStringView.Len
    零拷贝视图判定，无 ToString/Copy 堆分配），inline 薄转发零额外调用，Default 不丢 }
function WebviewMetricsIsOversized(const AView: TStringView): Boolean; inline;
function WebviewMetricsIsOversizedStr(const AFrameJson: string): Boolean; inline;

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

procedure WebviewMetricsNoteOversized({%H-}ASize: SizeUInt); inline;
begin
  Inc(GWebviewOversizedFrames);
end;

function WebviewMetricsIsOversized(const AView: TStringView): Boolean; inline;
begin
  Result := AView.Len > SizeUInt(WEBVIEW_MAX_FRAME_BYTES);
end;

function WebviewMetricsIsOversizedStr(const AFrameJson: string): Boolean; inline;
begin
  Result := SizeUInt(Length(AFrameJson)) > SizeUInt(WEBVIEW_MAX_FRAME_BYTES);
end;

end.
