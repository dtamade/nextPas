unit nextpas.core.ssh.window;

{** nextpas.core.ssh.window - 通道窗口兼容门面。
 *
 *  历史薄别名已收敛：`SSH_WINDOW_LOW_WATER_DIVISOR` 直连 `flow.window.base`
 *  单源（`FLOW_WINDOW_LOW_WATER_DIVISOR=2` 半水位回补），避免
 *  `ssh.window -> flow.window -> base` 二跳间接；`TChannelWindow` 为
 *  `TFlowWindow` 零成本 `type` alias（编译期零拷贝，无额外堆分配），
 *  热路径 `inline` 与 `bytes.ops` 单源由 L1 `flow.window` 侧保证
 *  （`Move` 单源、record 值语义零堆、释放不丢）。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.flow.window,
  nextpas.core.flow.window.base;

type
  TChannelWindow = nextpas.core.flow.window.TFlowWindow deprecated 'Use TFlowWindow from nextpas.core.flow.window; ssh.window alias deprecated, will be removed — new code should uses flow.window directly';

const
  SSH_WINDOW_LOW_WATER_DIVISOR = nextpas.core.flow.window.base.FLOW_WINDOW_LOW_WATER_DIVISOR deprecated 'Use FLOW_WINDOW_LOW_WATER_DIVISOR from nextpas.core.flow.window.base or nextpas.core.flow.window';

implementation

end.
