unit nextpas.core.net.quic.flow;

{**
 * nextpas.core.net.quic.flow — QUIC 流控账本（RFC 9000 §4 子集，Q5）
 *
 * 单通道账本形态：同一 record 同时服务连接级与流级预算——
 * - 发送侧 TQuicFlowBudget：Granted=对端授权累计上沿、Frontier=我方
 *   已发最大偏移（计费前沿）。授权值单调不回退（§4.1 原文定案：
 *   "MUST ignore" 收缩值）；重传同偏移数据不再计费（前沿只进不退）。
 * - 接收侧 TQuicFlowRecvCtl：按「连续可交付前沿」记账；自动升窗 =
 *   剩余未记账窗口过半即通告 Consumed+Window，通告值单调不减
 *   （§4.1 "MUST NOT decrease"）。
 *
 * 确定性：纯整数运算零时钟读取，全部状态显式注入/读出。
 *
 * @note Thread safety: 纯函数/记录操作，无共享态。
 *}

{$I nextpas.core.settings.inc}

interface

const
  { 缺省窗口：与 conn 传输参数通告值一致（65536） }
  cQuicDefaultFlowWindow = 65536;

type
  { 单通道发送预算（连接级或流级共用） }
  TQuicFlowBudget = record
    Granted: UInt64;    { 对端授权累计上沿 }
    Frontier: UInt64;   { 我方已用前沿 = 已发最大偏移 }
  end;

  { 单通道接收控制 }
  TQuicFlowRecvCtl = record
    Window: UInt64;
    Advertised: UInt64; { 已通告上沿（初始 = Window） }
    Consumed: UInt64;   { 连续可交付前沿 }
  end;

{** @desc 初始化发送预算：AInitialGrant 为对端 initial_max_data /
 *       initial_max_stream_data_* 授予值 *}
procedure QuicBudgetInit(out ABudget: TQuicFlowBudget;
  AInitialGrant: UInt64);

{** @desc 对端 MAX_DATA / MAX_STREAM_DATA 授权落地；收缩值忽略不采纳 *}
procedure QuicBudgetGrant(var ABudget: TQuicFlowBudget; AValue: UInt64);

{** @desc 可发字节数 = Granted > Frontier ? Granted-Frontier : 0 *}
function QuicBudgetAvailable(const ABudget: TQuicFlowBudget): UInt64;

{** @desc ACount 是否可全量发出（不部分放行） *}
function QuicBudgetCanSend(const ABudget: TQuicFlowBudget;
  ACount: UInt64): Boolean;

{** @desc 计费前沿推进到 ANewFrontier（只进不退；重传路径不得调用） *}
procedure QuicBillingAdvance(var ABudget: TQuicFlowBudget;
  ANewFrontier: UInt64);

{** @desc 初始化接收控制；Advertised 预置为 AWindow（与传输参数一致） *}
procedure QuicRecvInit(out ACtl: TQuicFlowRecvCtl; AWindow: UInt64);

{** @desc 消费推进 ACount 字节 *}
procedure QuicRecvConsume(var ACtl: TQuicFlowRecvCtl; ACount: UInt64);

{**
 * @desc 是否应升窗：剩余未记账窗口 ≤ 一半即通告。恒等式
 *       ShouldAdvertise ⇔ Advertised-Consumed ≤ Window div 2
 *       （含 Consumed ≥ Advertised 的越界消费形态，恒真）。
 *}
function QuicRecvShouldAdvertise(const ACtl: TQuicFlowRecvCtl): Boolean;

{** @desc 下一个通告上沿 = Consumed + Window（单调性由调用方保证） *}
function QuicRecvNextLimit(const ACtl: TQuicFlowRecvCtl): UInt64;

{** @desc 通告值单调化落地：收缩值拒绝，返回是否实际变更 *}
function QuicRecvAdvertise(var ACtl: TQuicFlowRecvCtl;
  ALimit: UInt64): Boolean;

implementation

procedure QuicBudgetInit(out ABudget: TQuicFlowBudget;
  AInitialGrant: UInt64);
begin
  ABudget.Granted := AInitialGrant;
  ABudget.Frontier := 0;
end;

procedure QuicBudgetGrant(var ABudget: TQuicFlowBudget; AValue: UInt64);
begin
  if AValue > ABudget.Granted then
    ABudget.Granted := AValue;   { §4.1 MUST ignore reductions }
end;

function QuicBudgetAvailable(const ABudget: TQuicFlowBudget): UInt64;
begin
  if ABudget.Granted > ABudget.Frontier then
    Result := ABudget.Granted - ABudget.Frontier
  else
    Result := 0;
end;

function QuicBudgetCanSend(const ABudget: TQuicFlowBudget;
  ACount: UInt64): Boolean;
begin
  Result := QuicBudgetAvailable(ABudget) >= ACount;
end;

procedure QuicBillingAdvance(var ABudget: TQuicFlowBudget;
  ANewFrontier: UInt64);
begin
  if ANewFrontier > ABudget.Frontier then
    ABudget.Frontier := ANewFrontier;
end;

procedure QuicRecvInit(out ACtl: TQuicFlowRecvCtl; AWindow: UInt64);
begin
  ACtl.Window := AWindow;
  ACtl.Advertised := AWindow;
  ACtl.Consumed := 0;
end;

procedure QuicRecvConsume(var ACtl: TQuicFlowRecvCtl; ACount: UInt64);
begin
  ACtl.Consumed := ACtl.Consumed + ACount;
end;

function QuicRecvShouldAdvertise(const ACtl: TQuicFlowRecvCtl): Boolean;
begin
  if ACtl.Consumed >= ACtl.Advertised then
    Exit(True);
  Result := (ACtl.Advertised - ACtl.Consumed) <= ACtl.Window div 2;
end;

function QuicRecvNextLimit(const ACtl: TQuicFlowRecvCtl): UInt64;
begin
  Result := ACtl.Consumed + ACtl.Window;
end;

function QuicRecvAdvertise(var ACtl: TQuicFlowRecvCtl;
  ALimit: UInt64): Boolean;
begin
  if ALimit <= ACtl.Advertised then
    Exit(False);   { §4.1 MUST NOT decrease }
  ACtl.Advertised := ALimit;
  Result := True;
end;

end.
