unit nextpas.core.ssh.flow.window;

{**
 * 已回退（匠心修复 S27′ 奢华抽取）：本单元原将 TChannelWindow 别名为
 * TFlowWindow 并重复常量 FLOW_WINDOW_LOW_WATER_DIVISOR = SSH_WINDOW_LOW_WATER_DIVISOR，
 * 仅别名未提供跨协议独立不变量，通用流控晋升名不副实，且未达 ≥2 协议复用实证
 * （HTTP/2 实际使用 TH2FlowState，QUIC 使用 TQuicFlowBudget/RecvCtl）。
 * 为守四件套与 L0-L3 最小面，移除独立晋升与重复常量；通用流控退回候选。
 * 调用方请直接使用 nextpas.core.ssh.window.TChannelWindow（record 值语义、
 * inline 热路径、零堆分配、复用 bytes.ops 单源，性能与稳定性证据见 CONTRACT §5-6）。
 * 本单元仅作兼容过渡保留，后续版本将删除；新代码禁止 uses。
 * 业务以 CONTRACT 为准，缺能力先反哺 owner。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.ssh.window;

type
  TFlowWindow = TChannelWindow; deprecated 'Use TChannelWindow from nextpas.core.ssh.window directly';

implementation

end.
