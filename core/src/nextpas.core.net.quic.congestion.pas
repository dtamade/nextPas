unit nextpas.core.net.quic.congestion;

{**
 * nextpas.core.net.quic.congestion — NewReno 拥塞控制器（RFC 9002 §7，Q5）
 *
 * 状态机（§7.3 Figure 1）：慢启动 ⇄ 恢复期 / 拥塞避免。
 * - 初始窗口（§7.2 原文定案）：min(10 × max_datagram_size,
 *   max(14720, 2 × max_datagram_size))；
 * - 慢启动：cwnd < ssthresh（初值无穷大），增量 = 已确认字节；
 * - 恢复期（§7.3.2）：进入时 ssthresh = cwnd/2（kLossReductionFactor=0.5，
 *   下限 kMinimumWindow）、立即降窗；期间新丢失不重复降窗（一 RTT 至多
 *   一次）；「恢复起点之后发出的包」获确认即退出；
 * - 拥塞避免（§7.3.3）：每个被确认的 cwnd 至多增 1 个 MSS——分子累积器
 *   实现整数精确式 cwnd += mss×acked/cwnd（整 RTT 增量恰为一 MSS，
 *   无小数漂移）；
 * - 持久拥塞（§7.6 原文定案）：cwnd MUST 降至 kMinimumWindow
 *   （2 × max_datagram_size）；ssthresh 不动 ⇒ cwnd < ssthresh 自动
 *   重回慢启动。判定阈 = kPersistentCongestionThreshold(3) × PTO。
 *
 * 确定性：纯整数运算零时钟读取，全部输入显式注入。
 *
 * @note Thread safety: 单实例单线程使用（每连接一个实例）。
 *}

{$I nextpas.core.settings.inc}

interface

const
  { RFC 9002 §7.2：初始窗口 = 10×MSS，上限取 max(14720, 2×MSS) 的较小者 }
  cQuicIwMultiplier = 10;
  cQuicIwByteFloor = 14720;       { 原文常量 14,720 字节 }
  cQuicMinWindowMultiplier = 2;   { kMinimumWindow = 2×MSS（RECOMMENDED） }
  cQuicPersistentCongestionThresholdPto = 3;  { §7.6 RECOMMENDED }

{** @desc 初始拥塞窗口（§7.2 公式完整形态） *}
function QuicInitialCwnd(AMaxDatagramSize: UInt64): UInt64;

{** @desc 最小拥塞窗口 kMinimumWindow = 2×MSS *}
function QuicMinimumCwnd(AMaxDatagramSize: UInt64): UInt64;

{**
 * @desc 持久拥塞时长判定：从首个丢失包到判丢确认点的时间跨度是否达到
 *       kPersistentCongestionThreshold × PTO（边界取等成立）。
 *}
function QuicIsPersistentCongestion(ASpanUs, APtoDurationUs: UInt64): Boolean;

type
  TQuicNewReno = class
  private
    FMss: UInt64;
    FMinCwnd: UInt64;
    FCwnd: UInt64;
    FSsthresh: UInt64;
    FInRecovery: Boolean;
    FRecoveryEndSentPn: UInt64;   { 恢复结束条件：APn > 此值获确认 }
    FCaAccum: UInt64;             { 避免期分子累积器（防小 ACK 下整除丢失） }
    function GetInSlowStart: Boolean;
  public
    constructor Create(AMaxDatagramSize: UInt64);

    {**
     * @desc ACK 结算后调用。APn=本次结算中新确认的最大包号；
     *       AHighestSentPn=当前最高已发包号；AAckedBytes=本次新确认字节。
     *}
    procedure OnAcked(APn, AHighestSentPn, AAckedBytes: UInt64);

    {** @desc 新丢失事件（DetectLost 产出非空时调用） *}
    procedure OnLost(AHighestSentPn: UInt64);

    {** @desc 持久拥塞宣告（QuicIsPersistentCongestion 成立时调用） *}
    procedure OnPersistentCongestion(AHighestSentPn: UInt64);

    {** @desc §7.2：在途字节超窗禁发（PTO 探测包由调用方豁免，§7.5） *}
    function CanSend(AInFlightBytes: UInt64): Boolean;

    property Cwnd: UInt64 read FCwnd;
    property Ssthresh: UInt64 read FSsthresh;
    property MinCwnd: UInt64 read FMinCwnd;
    property InRecovery: Boolean read FInRecovery;
    property InSlowStart: Boolean read GetInSlowStart;
  end;

implementation

function QuicInitialCwnd(AMaxDatagramSize: UInt64): UInt64;
var
  LCap: UInt64;
begin
  LCap := 2 * AMaxDatagramSize;
  if LCap < cQuicIwByteFloor then
    LCap := cQuicIwByteFloor;
  Result := cQuicIwMultiplier * AMaxDatagramSize;
  if Result > LCap then
    Result := LCap;
end;

function QuicMinimumCwnd(AMaxDatagramSize: UInt64): UInt64;
begin
  Result := cQuicMinWindowMultiplier * AMaxDatagramSize;
end;

function QuicIsPersistentCongestion(ASpanUs,
  APtoDurationUs: UInt64): Boolean;
begin
  Result := ASpanUs >=
    cQuicPersistentCongestionThresholdPto * APtoDurationUs;
end;

{ TQuicNewReno }

constructor TQuicNewReno.Create(AMaxDatagramSize: UInt64);
begin
  inherited Create;
  FMss := AMaxDatagramSize;
  FMinCwnd := QuicMinimumCwnd(AMaxDatagramSize);
  FCwnd := QuicInitialCwnd(AMaxDatagramSize);
  { §7.3.1：阈值初始化为无穷大——连接自慢启动开始 }
  FSsthresh := High(UInt64);
  FInRecovery := False;
  FRecoveryEndSentPn := 0;
  FCaAccum := 0;
end;

function TQuicNewReno.GetInSlowStart: Boolean;
begin
  Result := FCwnd < FSsthresh;
end;

procedure TQuicNewReno.OnAcked(APn, AHighestSentPn, AAckedBytes: UInt64);
var
  LAdd: UInt64;
begin
  { 恢复起点后发出的包获确认 ⇒ 恢复期结束（§7.3.2） }
  if FInRecovery and (APn > FRecoveryEndSentPn) then
    FInRecovery := False;
  if FInRecovery then
    Exit;   { 恢复期内确认不增窗 }

  if FCwnd < FSsthresh then
    FCwnd := FCwnd + AAckedBytes   { 慢启动：指数增长 }
  else
  begin
    { 拥塞避免：cwnd += mss×acked/cwnd，分子累积保整数精度 }
    if FCwnd = 0 then
      Exit;
    FCaAccum := FCaAccum + FMss * AAckedBytes;
    if FCaAccum >= FCwnd then
    begin
      LAdd := FCaAccum div FCwnd;
      FCaAccum := FCaAccum mod FCwnd;
      FCwnd := FCwnd + LAdd;
    end;
  end;
end;

procedure TQuicNewReno.OnLost(AHighestSentPn: UInt64);
var
  LReduced: UInt64;
begin
  if FInRecovery then
    Exit;   { 一 RTT 至多降窗一次（§7.3.2） }
  LReduced := FCwnd div 2;   { kLossReductionFactor = 0.5 }
  if LReduced < FMinCwnd then
    LReduced := FMinCwnd;
  FSsthresh := LReduced;
  FCwnd := LReduced;         { MAY 立即降窗：取立即形态 }
  FInRecovery := True;
  FRecoveryEndSentPn := AHighestSentPn;
  FCaAccum := 0;
end;

procedure TQuicNewReno.OnPersistentCongestion(AHighestSentPn: UInt64);
begin
  FCwnd := FMinCwnd;         { §7.6 MUST 降至 kMinimumWindow }
  { ssthresh 不动：cwnd < ssthresh ⇒ 重回慢启动（§7.3.1） }
  FInRecovery := True;
  FRecoveryEndSentPn := AHighestSentPn;
  FCaAccum := 0;
end;

function TQuicNewReno.CanSend(AInFlightBytes: UInt64): Boolean;
begin
  Result := AInFlightBytes < FCwnd;
end;

end.
