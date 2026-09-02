unit nextpas.core.metrics;

{** @desc 通用可观测 Owner（L2）：计数器/阈值单源。
       承接 bench/log/webview 的通用可观测能力：UI 线程亲和 plain UInt64
       单调背压计数、帧阈值 1 MiB Hard Limit 常量即契约。
       原 L3 webview.metrics 的阈值与计数已反哺至本 L2 单源，L3 仅 thin-forward
       alias 零双写漂移；与 bench（tooling harness 时序统计）/log（结构化日志）
       正交，bench 提供 TBenchResult/log 提供 ILogSink，本单元提供 plain 计数
       单源零重复。性能 inline 薄转发零额外调用（TStringView.Len 零拷贝视图判定，
       复用 bytes.ops 单源思想 inline）、稳定性 plain 全局零句柄 Default 释放不丢、
       线程 UI 线程亲和（无 atomic，跨线程需外层同步）。 }

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.text.view,
  nextpas.core.metrics.base;

const
  { L2 单源阈值 re-export：webview 1 MiB 阈值即本常量，L3 alias 零漂移 }
  METRICS_WEBVIEW_MAX_FRAME_BYTES = METRICS_MAX_FRAME_BYTES;

{ 背压可观测：超限帧计数（单调递增，UI 线程亲和，plain 全局零句柄） }
function MetricsOversizedCount: UInt64; inline;
procedure MetricsResetOversizedCount; inline;
procedure MetricsNoteOversized({%H-}ASize: SizeUInt); inline;
{ 帧超限判定单源（Owner: L2 metrics）：复用 bytes.ops 零拷贝视图思想，inline 零额外调用 }
function MetricsIsOversized(const AView: TStringView): Boolean; inline;
function MetricsIsOversizedStr(const AFrameJson: string): Boolean; inline;
{ 解析后规范化膨胀：计入 JSON 解析 arena/节点与 payload 规范化拷贝后的实际内存水位
  （raw + payload 视图 + 节点/arena 估算开销），与单一 Len 比对的偏差闭环；
  inline 零拷贝视图，复用 bytes.ops 单源思想，Default 不丢 }
function MetricsExpandedSize(const AView: TStringView; const APayloadLen: SizeUInt): SizeUInt; inline;
function MetricsIsOversizedExpanded(const AView: TStringView; const APayloadLen: SizeUInt): Boolean; inline;
function MetricsIsOversizedExpandedView(const AView, APayloadView: TStringView): Boolean; inline;

implementation

var
  GMetricsOversizedFrames: UInt64 = 0;

function MetricsOversizedCount: UInt64; inline;
begin
  Result := GMetricsOversizedFrames;
end;

procedure MetricsResetOversizedCount; inline;
begin
  GMetricsOversizedFrames := 0;
end;

procedure MetricsNoteOversized({%H-}ASize: SizeUInt); inline;
begin
  Inc(GMetricsOversizedFrames);
end;

function MetricsIsOversized(const AView: TStringView): Boolean; inline;
begin
  Result := AView.Len > SizeUInt(METRICS_MAX_FRAME_BYTES);
end;

function MetricsIsOversizedStr(const AFrameJson: string): Boolean; inline;
begin
  Result := SizeUInt(Length(AFrameJson)) > SizeUInt(METRICS_MAX_FRAME_BYTES);
end;

function MetricsExpandedSize(const AView: TStringView; const APayloadLen: SizeUInt): SizeUInt; inline;
begin
  { 实际内存水位估算：raw 帧 + payload 规范化拷贝 + TJsonDocument 节点/arena 开销。
    节点开销 ~ AView.Len div 4 * sizeof(TJsonNode) 近似 AView.Len div 2，arena ~ AView.Len div 4，
    合计 ~ AView.Len + APayloadLen + AView.Len div 2 + 1KiB 固定头；零拷贝视图 Len 判定，
    inline 薄转发零额外调用，复用 bytes.ops 单源思想。 }
  Result := AView.Len + APayloadLen + (AView.Len shr 1) + 1024;
end;

function MetricsIsOversizedExpanded(const AView: TStringView; const APayloadLen: SizeUInt): Boolean; inline;
begin
  Result := MetricsExpandedSize(AView, APayloadLen) > SizeUInt(METRICS_MAX_FRAME_BYTES);
end;

function MetricsIsOversizedExpandedView(const AView, APayloadView: TStringView): Boolean; inline;
begin
  Result := MetricsIsOversizedExpanded(AView, APayloadView.Len);
end;

end.
