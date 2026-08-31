unit nextpas.core.net.quic.reliable;

{**
 * nextpas.core.net.quic.reliable — 发送追踪 + ACK 结算 + 丢失检测骨架
 * （RFC 9002 §5/§6 子集，Q3）
 *
 * 范围：
 * - TQuicRttEstimator：§5.3 全公式（首个样本重置估计器；握手确认前不钳
 *   max_ack_delay、确认后取 min(delay, max_ack_delay)；adjusted 仅当
 *   latest >= min_rtt + delay 才减 delay）；EWMA 7/8+1/8 与 rttvar 3/4+1/4
 *   以整数微秒实现（除法向零取整，确定性可复现）；
 * - TQuicSentTracker：PN 取模环形窗口的有界在途登记（S2：内存 =
 *   常量容量 × 槽，与已发包总数解耦）；ACK 结算按 range 直接命中槽，
 *   O(新确认包数)；同 PN 重复登记/窗口回绕覆盖即拒（fail-closed）；
 * - 丢失检测（§6.1 判定式）：未确认 + 在途 + 先于 largest_acked，且
 *   满足包阈（kPacketThreshold=3）或时阈（kTimeThreshold=9/8 ×
 *   max(smoothed_rtt, latest_rtt)，下限 kGranularity=1ms）之一；
 * - PTO（§6.2）：smoothed_rtt + max(4*rttvar, kGranularity) +
 *   max_ack_delay（Initial/Handshake 空 max_ack_delay 传 0）。
 *
 * 时钟纪律：全部时间为 UInt64 微秒且由调用方注入（loop 时间可控），
 * 本单元零时钟读取——丢包仿真的确定性由构造保证。
 *
 * @note Thread safety: 单实例单线程使用（每包号空间一个实例）。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.net.quic.frame;

const
  { RFC 9002 常量（原文 RECOMMENDED 值） }
  cQuicInitialRttUs = 333000;     { kInitialRtt = 333 ms }
  cQuicGranularityUs = 1000;      { kGranularity = 1 ms }
  cQuicPacketThreshold = 3;       { kPacketThreshold }
  cQuicTimeThresholdNum = 9;      { kTimeThreshold = 9/8 }
  cQuicTimeThresholdDen = 8;
  cQuicSentWindowDefault = 1024;  { 默认在途窗口容量 }

type
  TQuicPnArray = array of UInt64;

  TQuicRttEstimator = record
    LatestRttUs: UInt64;
    MinRttUs: UInt64;
    SmoothedRttUs: UInt64;
    RttVarUs: UInt64;
    HasSample: Boolean;
  end;

{** @desc 初始化为无样本态（Smoothed/RttVar 预置 kInitialRtt 引导值，
 *       供 PTO 在首个样本前使用） *}
procedure QuicRttInit(out AEst: TQuicRttEstimator);

{** @desc §5.3 样本更新。AAckDelayUs 为对端报告的已缩放确认延迟 *}
procedure QuicRttOnSample(var AEst: TQuicRttEstimator;
  ALatestRttUs, AAckDelayUs: UInt64; AHandshakeConfirmed: Boolean;
  AMaxAckDelayUs: UInt64);

{** @desc §6.2 PTO 周期。Initial/Handshake 空间传 AMaxAckDelayUs=0 *}
function QuicComputePtoUs(const AEst: TQuicRttEstimator;
  AMaxAckDelayUs: UInt64): UInt64;

type
  TQuicSentSlotState = (qssFree, qssInFlight);

  TQuicSentSlot = record
    State: TQuicSentSlotState;
    Pn: UInt64;
    TimeSentUs: UInt64;
    Bytes: Integer;
    AckEliciting: Boolean;
  end;

  { 一次 ACK 结算的产出：RTT 采样取「最大新确认的 ack-eliciting 包」 }
  TQuicAckStats = record
    HasSampleCandidate: Boolean;    { 存在新确认的 ack-eliciting 包 }
    SamplePn: UInt64;
    SampleTimeSentUs: UInt64;
    AckedCount: Integer;
    AckedBytes: Integer;
  end;

  TQuicSentTracker = class
  private
    FSlots: array of TQuicSentSlot;
    FCapacity: Integer;
    FInFlightCount: Integer;
    FInFlightBytes: Integer;
    FLargestAcked: UInt64;
    FHasLargestAcked: Boolean;
    FHighestTracked: UInt64;
    FHasTracked: Boolean;
    function SlotIndex(APn: UInt64): Integer; inline;
  public
    constructor Create(ACapacity: Integer);

    {** 登记发出；槽被占用（含重复 PN）返回 False *}
    function Track(APn, ATimeSentUs: UInt64; ABytes: Integer;
      AAckEliciting: Boolean): Boolean;

    {**
     * @desc 按 ACK frame 的降序闭区间结算（ARanges 须来自
     *       TryQuicAckRangesParse，首 range 上沿=ALargestAcked）。
     *       遍历按「最近登记包号的容量带」裁剪（任何在途包必落带内），
     *       成本与 range 宽度解耦。已丢失/已确认包再次出现按不可撤销
     *       语义跳过。
     *}
    function OnAckFrame(ALargestAcked: UInt64;
      const ARanges: array of TQuicAckRange;
      out AStats: TQuicAckStats): Boolean;

    {**
     * @desc §6.1 丢失判定并移除被判包。输出丢失 PN 列表与字节数。
     *}
    procedure DetectLost(const AEst: TQuicRttEstimator; ATimeNowUs: UInt64;
      out ALostPns: TQuicPnArray; out ALostBytes: Integer);

    {** @desc 查包发送时刻；不在途返回 -1（持久拥塞跨度判定用） *}
    function TimeSentOf(APn: UInt64): Int64;

    property InFlightCount: Integer read FInFlightCount;
    property InFlightBytes: Integer read FInFlightBytes;
    property LargestAcked: UInt64 read FLargestAcked;
    property HasLargestAcked: Boolean read FHasLargestAcked;
    { 最高已登记包号（拥塞控制恢复期判定用；未登记过为 0） }
    property HighestTracked: UInt64 read FHighestTracked;
    property Capacity: Integer read FCapacity;
  end;

implementation

procedure QuicRttInit(out AEst: TQuicRttEstimator);
begin
  AEst := Default(TQuicRttEstimator);
  AEst.SmoothedRttUs := cQuicInitialRttUs;
  AEst.RttVarUs := cQuicInitialRttUs div 2;
end;

procedure QuicRttOnSample(var AEst: TQuicRttEstimator;
  ALatestRttUs, AAckDelayUs: UInt64; AHandshakeConfirmed: Boolean;
  AMaxAckDelayUs: UInt64);
var
  LAckDelay, LAdjusted, LVarSample, LNewSmoothed: UInt64;
begin
  AEst.LatestRttUs := ALatestRttUs;
  if not AEst.HasSample then
  begin
    { 首个样本：重置估计器，不留历史（§5.3） }
    AEst.HasSample := True;
    AEst.MinRttUs := ALatestRttUs;
    AEst.SmoothedRttUs := ALatestRttUs;
    AEst.RttVarUs := ALatestRttUs div 2;
    Exit;
  end;
  if ALatestRttUs < AEst.MinRttUs then
    AEst.MinRttUs := ALatestRttUs;

  LAckDelay := AAckDelayUs;
  if AHandshakeConfirmed and (LAckDelay > AMaxAckDelayUs) then
    LAckDelay := AMaxAckDelayUs;
  LAdjusted := ALatestRttUs;
  { MUST NOT 减到低于 min_rtt：仅当 latest >= min_rtt + delay 才扣减 }
  if ALatestRttUs >= AEst.MinRttUs + LAckDelay then
    LAdjusted := ALatestRttUs - LAckDelay;

  LNewSmoothed := (7 * AEst.SmoothedRttUs + LAdjusted) div 8;
  LVarSample := Abs(Int64(LNewSmoothed) - Int64(LAdjusted));
  AEst.RttVarUs := (3 * AEst.RttVarUs + LVarSample) div 4;
  AEst.SmoothedRttUs := LNewSmoothed;
end;

function QuicComputePtoUs(const AEst: TQuicRttEstimator;
  AMaxAckDelayUs: UInt64): UInt64;
var
  LVarTerm: UInt64;
begin
  LVarTerm := 4 * AEst.RttVarUs;
  if LVarTerm < cQuicGranularityUs then
    LVarTerm := cQuicGranularityUs;
  Result := AEst.SmoothedRttUs + LVarTerm + AMaxAckDelayUs;
end;

{ TQuicSentTracker }

constructor TQuicSentTracker.Create(ACapacity: Integer);
begin
  inherited Create;
  if ACapacity < 16 then
    ACapacity := 16;
  FCapacity := ACapacity;
  FSlots := nil;
  SetLength(FSlots, FCapacity);
  FInFlightCount := 0;
  FInFlightBytes := 0;
  FHasLargestAcked := False;
  FLargestAcked := 0;
  FHasTracked := False;
  FHighestTracked := 0;
end;

function TQuicSentTracker.SlotIndex(APn: UInt64): Integer;
begin
  Result := Integer(APn mod UInt64(FCapacity));
end;

function TQuicSentTracker.Track(APn, ATimeSentUs: UInt64; ABytes: Integer;
  AAckEliciting: Boolean): Boolean;
var
  LSlot: TQuicSentSlot;
begin
  LSlot := FSlots[SlotIndex(APn)];
  { 槽被占用（含同 PN 重复登记/窗口回绕覆盖）即拒——fail-closed }
  if LSlot.State = qssInFlight then
    Exit(False);
  LSlot.State := qssInFlight;
  LSlot.Pn := APn;
  LSlot.TimeSentUs := ATimeSentUs;
  LSlot.Bytes := ABytes;
  LSlot.AckEliciting := AAckEliciting;
  FSlots[SlotIndex(APn)] := LSlot;
  Inc(FInFlightCount);
  Inc(FInFlightBytes, ABytes);
  if (not FHasTracked) or (APn > FHighestTracked) then
  begin
    FHighestTracked := APn;
    FHasTracked := True;
  end;
  Result := True;
end;

function TQuicSentTracker.OnAckFrame(ALargestAcked: UInt64;
  const ARanges: array of TQuicAckRange;
  out AStats: TQuicAckStats): Boolean;
var
  LI, LSlotIdx: Integer;
  LPnLo, LPnHi, LBandLo: UInt64;
  LSlot: TQuicSentSlot;
begin
  AStats := Default(TQuicAckStats);
  Result := False;
  if Length(ARanges) < 1 then
    Exit;

  if FHasTracked then
  begin
    { 在途包必落「最高登记 PN 往回一个容量」的带内（同余覆盖恰好一遍） }
    if FHighestTracked >= UInt64(FCapacity) - 1 then
      LBandLo := FHighestTracked - UInt64(FCapacity) + 1
    else
      LBandLo := 0;

    for LI := 0 to High(ARanges) do
    begin
      LPnLo := ARanges[LI].Lo;
      LPnHi := ARanges[LI].Hi;
      if LPnHi > FHighestTracked then
        LPnHi := FHighestTracked;
      if LPnLo < LBandLo then
        LPnLo := LBandLo;
      while LPnLo <= LPnHi do
      begin
        LSlotIdx := SlotIndex(LPnLo);
        LSlot := FSlots[LSlotIdx];
        if (LSlot.State = qssInFlight) and (LSlot.Pn = LPnLo) then
        begin
          Inc(AStats.AckedCount);
          Inc(AStats.AckedBytes, LSlot.Bytes);
          Dec(FInFlightCount);
          Dec(FInFlightBytes, LSlot.Bytes);
          if LSlot.AckEliciting and
             ((not AStats.HasSampleCandidate) or (LPnLo > AStats.SamplePn)) then
          begin
            AStats.HasSampleCandidate := True;
            AStats.SamplePn := LPnLo;
            AStats.SampleTimeSentUs := LSlot.TimeSentUs;
          end;
          LSlot.State := qssFree;
          FSlots[LSlotIdx] := LSlot;
        end;
        Inc(LPnLo);
      end;
    end;
  end;

  if (not FHasLargestAcked) or (ALargestAcked > FLargestAcked) then
  begin
    FLargestAcked := ALargestAcked;
    FHasLargestAcked := True;
  end;
  Result := True;
end;

procedure TQuicSentTracker.DetectLost(const AEst: TQuicRttEstimator;
  ATimeNowUs: UInt64; out ALostPns: TQuicPnArray; out ALostBytes: Integer);
var
  LI: Integer;
  LBase, LMaxRtt, LTimeThresholdUs: UInt64;
  LSlot: TQuicSentSlot;
begin
  ALostPns := nil;
  ALostBytes := 0;
  if not FHasLargestAcked then
    Exit;   { 尚无任何确认：无从判丢 }

  { 时阈 = max(kTimeThreshold * max(smoothed_rtt, latest_rtt), kGranularity)
    （乘法向上取整，避免过早判丢） }
  LMaxRtt := AEst.SmoothedRttUs;
  if AEst.LatestRttUs > LMaxRtt then
    LMaxRtt := AEst.LatestRttUs;
  LTimeThresholdUs := (LMaxRtt * cQuicTimeThresholdNum +
    cQuicTimeThresholdDen - 1) div cQuicTimeThresholdDen;
  if LTimeThresholdUs < cQuicGranularityUs then
    LTimeThresholdUs := cQuicGranularityUs;

  for LI := 0 to FCapacity - 1 do
  begin
    LSlot := FSlots[LI];
    if LSlot.State <> qssInFlight then
      Continue;
    if LSlot.Pn >= FLargestAcked then
      Continue;   { 仅「先于 largest_acked」的包参与判定 }
    LBase := FLargestAcked - LSlot.Pn;
    if (LBase >= cQuicPacketThreshold) or
       (ATimeNowUs >= LSlot.TimeSentUs + LTimeThresholdUs) then
    begin
      SetLength(ALostPns, Length(ALostPns) + 1);
      ALostPns[Length(ALostPns) - 1] := LSlot.Pn;
      Inc(ALostBytes, LSlot.Bytes);
      Dec(FInFlightCount);
      Dec(FInFlightBytes, LSlot.Bytes);
      LSlot.State := qssFree;
      FSlots[LI] := LSlot;
    end;
  end;
end;

function TQuicSentTracker.TimeSentOf(APn: UInt64): Int64;
var
  LSlot: TQuicSentSlot;
begin
  Result := -1;
  LSlot := FSlots[SlotIndex(APn)];
  if (LSlot.State = qssInFlight) and (LSlot.Pn = APn) then
    Result := Int64(LSlot.TimeSentUs);
end;

end.
