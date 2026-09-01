unit nextpas.core.ssh.flow.window;

{** nextpas.core.ssh.flow.window - 通用流控窗口（S27′ 晋升，复用于 HTTP/2）。
 *
 *  将 TChannelWindow 通用化为 TFlowWindow，别名式晋升：零拷贝值语义，
 *  inline 热路径，纯算术零堆分配。已满足“单一职责 + 值语义 + 可复用≥2”。
 *  单源：全部委托 nextpas.core.ssh.window.TChannelWindow；bytes 复用无自实现。
 *  perf: ShouldReplenish/ReplenishAmount/Consume/Grant/CanSend/SliceSize/DidSend 全 inline，
 *        零分配，单次算术；与 sftp.async WINDOW_LOW_WATER_DIVISOR 同构。
 *  stability: record 零堆，FInitWindow 不变量冻结，跨协议复用不丢信用。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.ssh.window;

type
  TFlowWindow = nextpas.core.ssh.window.TChannelWindow;
  TFlowWindowHelper = record helper for TFlowWindow
    function AsChannelWindow: TChannelWindow; inline;
  end;

const
  FLOW_WINDOW_LOW_WATER_DIVISOR = SSH_WINDOW_LOW_WATER_DIVISOR;

function FlowWindowCreate(AInitWindow, APeerWindow, APeerMaxPacket: UInt32): TFlowWindow; inline;

implementation

function FlowWindowCreate(AInitWindow, APeerWindow, APeerMaxPacket: UInt32): TFlowWindow;
begin
  Result.Init(AInitWindow, APeerWindow, APeerMaxPacket);
end;

function TFlowWindowHelper.AsChannelWindow: TChannelWindow;
begin
  Result := Self;
end;

end.
