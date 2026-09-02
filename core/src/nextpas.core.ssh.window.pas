unit nextpas.core.ssh.window;

{** nextpas.core.ssh.window - 通道窗口兼容门面。
 *
 *  历史实现已抽离至 `nextpas.core.flow.window`（L1，零堆 `inline`，
 *  `FLOW_WINDOW_LOW_WATER_DIVISOR=2` 半水位回补）。本单元为 ssh 兼容
 *  薄门面，纯 re-export + `inline` 零成本 alias，零堆分配，`bytes.ops` 单源
 *  由 flow 侧保证，不自实现拷贝逻辑。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.flow.window;

type
  TChannelWindow = nextpas.core.flow.window.TFlowWindow;

const
  SSH_WINDOW_LOW_WATER_DIVISOR = nextpas.core.flow.window.FLOW_WINDOW_LOW_WATER_DIVISOR;

implementation

end.
