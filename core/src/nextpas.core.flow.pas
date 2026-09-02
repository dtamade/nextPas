unit nextpas.core.flow;

{$I nextpas.core.settings.inc}

{** nextpas.core.flow - 流控门面（纯 re-export）。
 *
 *  L1 通用流控能力门面，当前仅暴露 `window` 子模块。
 *  四件套：`base <- window <- facade`，零堆 `inline`，`bytes.ops` 单源。
 *}

interface

uses
  nextpas.core.flow.window.base,
  nextpas.core.flow.window;

type
  TFlowWindow = nextpas.core.flow.window.TFlowWindow;

const
  FLOW_WINDOW_LOW_WATER_DIVISOR = nextpas.core.flow.window.base.FLOW_WINDOW_LOW_WATER_DIVISOR;

implementation

end.
