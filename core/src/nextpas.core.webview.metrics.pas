unit nextpas.core.webview.metrics;

{** @desc webview 家族可观测性 thin-forward（L3→L2）：阈值与背压计数已反哺
       L2 通用可观测 Owner（nextpas.core.metrics / nextpas.core.metrics.base），
       本单元仅为兼容 alias 与 inline 薄转发零重复定义。
       阈值 1 MiB Hard Limit（BRIDGE_PROTOCOL §6）常量即契约单源收口于 L2
       METRICS_MAX_FRAME_BYTES，bridge 仅复用本常量 NPW_MAX_FRAME_BYTES 薄转发；
       计数单调递增 UI 线程亲和 plain UInt64，L2 单源承载，bench/log 正交
       （bench 为 tooling harness 时序统计、log 为结构化日志，均不提供 UI 亲和计数）。
       解析后规范化膨胀已计入：IsOversizedExpanded* 以 raw + payload + 节点/arena
       估算实际内存水位（零拷贝 TStringView.Len 视图判定，复用 bytes.ops 单源思想
       inline 零额外调用），修正单一 Len 比对与水位偏差。
       性能 inline 薄转发零额外调用、稳定性 plain 全局零句柄 Default 释放不丢、
       线程 UI 线程亲和（无 atomic，跨线程需外层同步）。 }

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.text.view,
  nextpas.core.metrics.base,
  nextpas.core.metrics;

const
  { 帧长上限：BRIDGE_PROTOCOL §6 1 MiB Hard Limit，L2 单源 thin-forward。
    单源契约：复用 bytes.ops 单源思想（常量即契约，消除魔法数字漂移）；
    Owner 收敛：L2 nextpas.core.metrics.base.METRICS_MAX_FRAME_BYTES 单源，
    本单元与 bridge.NPW_MAX_FRAME_BYTES 均为 thin-forward alias 零双处漂移；
    已反哺 L2 通用 metrics（CONTRACT §1.2），业务以 CONTRACT 为准、缺能力先反哺 Owner。 }
  WEBVIEW_MAX_FRAME_BYTES = METRICS_MAX_FRAME_BYTES;

{ 背压可观测：超限帧计数（单调递增，UI 线程亲和，plain 全局零句柄；
    L2 metrics 单源承载，本单元 inline 薄转发零额外调用，Default 释放不丢） }
function WebviewMetricsOversizedCount: UInt64; inline;
procedure WebviewMetricsResetOversizedCount; inline;
procedure WebviewMetricsNoteOversized({%H-}ASize: SizeUInt); inline;
{ 帧超限判定单源（Owner: L2 metrics，L3 thin-forward）：复用 bytes.ops 零拷贝视图思想
    inline 薄转发零额外调用，Default 不丢；单一 Len 快径用于解析前早筛，解析后
    规范化膨胀由 IsOversizedExpanded* 覆盖实际内存水位 }
function WebviewMetricsIsOversized(const AView: TStringView): Boolean; inline;
function WebviewMetricsIsOversizedStr(const AFrameJson: string): Boolean; inline;
{ 解析后规范化膨胀判定（计入 payload 规范化拷贝 + 节点/arena 水位）：
  raw + payloadLen + overhead 与阈值比对，inline 零拷贝视图，复用 bytes.ops 单源 }
function WebviewMetricsIsOversizedExpanded(const AView: TStringView; const APayloadLen: SizeUInt): Boolean; inline;
function WebviewMetricsIsOversizedExpandedView(const AView, APayloadView: TStringView): Boolean; inline;
function WebviewMetricsExpandedSize(const AView: TStringView; const APayloadLen: SizeUInt): SizeUInt; inline;

implementation

function WebviewMetricsOversizedCount: UInt64; inline;
begin
  Result := MetricsOversizedCount;
end;

procedure WebviewMetricsResetOversizedCount; inline;
begin
  MetricsResetOversizedCount;
end;

procedure WebviewMetricsNoteOversized({%H-}ASize: SizeUInt); inline;
begin
  MetricsNoteOversized(ASize);
end;

function WebviewMetricsIsOversized(const AView: TStringView): Boolean; inline;
begin
  Result := MetricsIsOversized(AView);
end;

function WebviewMetricsIsOversizedStr(const AFrameJson: string): Boolean; inline;
begin
  Result := MetricsIsOversizedStr(AFrameJson);
end;

function WebviewMetricsIsOversizedExpanded(const AView: TStringView; const APayloadLen: SizeUInt): Boolean; inline;
begin
  Result := MetricsIsOversizedExpanded(AView, APayloadLen);
end;

function WebviewMetricsIsOversizedExpandedView(const AView, APayloadView: TStringView): Boolean; inline;
begin
  Result := MetricsIsOversizedExpandedView(AView, APayloadView);
end;

function WebviewMetricsExpandedSize(const AView: TStringView; const APayloadLen: SizeUInt): SizeUInt; inline;
begin
  Result := MetricsExpandedSize(AView, APayloadLen);
end;

end.
