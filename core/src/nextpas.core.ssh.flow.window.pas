unit nextpas.core.ssh.flow.window;

{** 已删除（匠心修复 S27″·奢华抽取残留清理）：
 *  TFlowWindow 仅为 TChannelWindow 别名并重复常量
 *  FLOW_WINDOW_LOW_WATER_DIVISOR = SSH_WINDOW_LOW_WATER_DIVISOR，
 *  未提供跨协议独立不变量（HTTP/2 实际使用 TH2FlowState，
 *  QUIC 使用 TQuicFlowBudget/RecvCtl，未达 ≥2 协议复用实证），
 *  奢华抽取名不副实。为守四件套与 L0-L3 最小面，已移除独立晋升与
 *  重复常量，通用流控退回候选；本单元已删除，不再提供任何符号。
 *  请直接 uses nextpas.core.ssh.window.TChannelWindow（record 值语义、
 *  inline 热路径、零堆分配、零拷贝分片、复用 bytes.ops 单源，
 *  性能与稳定性证据见 CONTRACT §5-6）。
 *  业务以 CONTRACT 为准，缺能力先反哺 owner。新代码禁止 uses 本单元。
 *}

{$I nextpas.core.settings.inc}

interface

implementation

end.
