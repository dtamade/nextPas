program test_quic_congestion;

{ QUIC NewReno 拥塞控制单元测试（RFC 9002 §7，Q5）：
  - 手算向量：初始窗口公式（10×MSS 与 14720 上限取小）/ 慢启动指数增
    / 恢复期减半下限 kMinimumWindow / 恢复期一 RTT 至多降窗一次 /
    「恢复起点后发包获确认」退出条件 / 避免期每 cwnd 增量恰为一 MSS
    （分子累积整数精确）/ 持久拥塞降 kMinimumWindow 后重回慢启动；
  - 确定性丢包仿真：tracker+RTT+Reno 三件套合成时钟闭环，周期注丢，
    断言 cwnd 永不低于最小窗、无丢段收敛增长、双跑逐位一致。
  仅依赖 nextPas/core（无 system 垫片）。 }

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.fs.path,
  nextpas.core.fs.util,
  nextpas.core.net.quic.frame,
  nextpas.core.net.quic.reliable,
  nextpas.core.net.quic.congestion,
  nextpas.core.test;

{$I ../../fpc_rtl_uses_scan.inc}

const
  cSimMss = 1200;
  cSimRttUs = 100000;
  cSimRounds = 40;
  cSimPerRoundCap = 6;

type
  TSimResult = record
    Ok: Boolean;
    FinalCwnd: UInt64;
    MinCwndSeen: UInt64;
    LostEvents: Integer;
    FinalInFlight: Integer;
  end;

{ 确定性丢包仿真：rounds 内第 (mod 7 = 3) 轮（3..27）首个包判死
  （发出、永不 ACK），其余全确认；尾部留干净收敛段；时钟步长恒 RTT。
  阈值经探针实测校准：4 次丢包事件、FinalCwnd=17723、Min=6803。 }
function RunLossySim(out ARes: TSimResult): Boolean;
var
  LReno: TQuicNewReno;
  LTracker: TQuicSentTracker;
  LEst: TQuicRttEstimator;
  LDropped: array[0..1023] of Boolean;
  LRanges: TQuicAckRangeArray;
  LLost: TQuicPnArray;
  LLostBytes: Integer;
  LStats: TQuicAckStats;
  LRIdx, LSent, LPn, LI, LAckHi: Integer;
  LNow: UInt64;
  LRunLo: Integer;
  LInRun: Boolean;

  procedure BuildRunsDesc(AHi: Integer);
  var
    LP: Integer;
  begin
    { 升序收集 [0..AHi] 未丢连续段再倒序 → frame 层要求的降序 ranges }
    LRanges := nil;
    LRunLo := -1;
    LInRun := False;
    for LP := 0 to AHi do
    begin
      if not LDropped[LP] then
      begin
        if not LInRun then
        begin
          LInRun := True;
          LRunLo := LP;
        end;
      end
      else if LInRun then
      begin
        LInRun := False;
        SetLength(LRanges, Length(LRanges) + 1);
        LRanges[High(LRanges)].Lo := LRunLo;
        LRanges[High(LRanges)].Hi := LP - 1;
      end;
    end;
    if LInRun then
    begin
      SetLength(LRanges, Length(LRanges) + 1);
      LRanges[High(LRanges)].Lo := LRunLo;
      LRanges[High(LRanges)].Hi := AHi;
    end;
    for LP := 0 to Length(LRanges) div 2 - 1 do
    begin
      LRunLo := LRanges[LP].Lo;
      LRanges[LP].Lo := LRanges[High(LRanges) - LP].Lo;
      LRanges[High(LRanges) - LP].Lo := LRunLo;
      LRunLo := LRanges[LP].Hi;
      LRanges[LP].Hi := LRanges[High(LRanges) - LP].Hi;
      LRanges[High(LRanges) - LP].Hi := LRunLo;
    end;
  end;

begin
  Result := False;
  ARes := Default(TSimResult);
  for LI := 0 to High(LDropped) do
    LDropped[LI] := False;
  QuicRttInit(LEst);
  LTracker := TQuicSentTracker.Create(256);
  LReno := TQuicNewReno.Create(cSimMss);
  try
    ARes.MinCwndSeen := LReno.Cwnd;
    LAckHi := 0;
    for LRIdx := 0 to cSimRounds + 9 do   { 尾部 10 轮纯排水 }
    begin
      LNow := UInt64(LRIdx) * UInt64(cSimRttUs);

      { 1. ACK 结算（仅覆盖上一拍及以前发出的包） }
      if LAckHi > 0 then
      begin
        BuildRunsDesc(LAckHi);
        if Length(LRanges) > 0 then
        begin
          if not LTracker.OnAckFrame(UInt64(LRanges[0].Hi), LRanges,
            LStats) then
            Exit;
          if LStats.HasSampleCandidate then
            QuicRttOnSample(LEst, LNow - LStats.SampleTimeSentUs, 0,
              True, 25000);
          if LStats.AckedBytes > 0 then
            LReno.OnAcked(LStats.SamplePn,
              UInt64(LTracker.HighestTracked), UInt64(LStats.AckedBytes));
        end;
      end;

      { 2. 丢失检测 → 拥塞事件 }
      LTracker.DetectLost(LEst, LNow, LLost, LLostBytes);
      if Length(LLost) > 0 then
      begin
        Inc(ARes.LostEvents);
        LReno.OnLost(UInt64(LTracker.HighestTracked));
      end;

      { 3. 发送相位（尾部排水轮不发） }
      if LRIdx < cSimRounds then
      begin
        LSent := 0;
        while LReno.CanSend(UInt64(LTracker.InFlightBytes)) and
              (LSent < cSimPerRoundCap) and (LAckHi < High(LDropped)) do
        begin
          Inc(LAckHi);
          LPn := LAckHi;
          { 第 mod7=3 轮（3..27）的首包判死，尾部留干净收敛段 }
          if ((LRIdx mod 7) = 3) and (LRIdx >= 3) and (LRIdx < 28) and
             (LSent = 0) then
            LDropped[LPn] := True;
          if not LTracker.Track(UInt64(LPn), LNow, cSimMss, True) then
            Exit;
          Inc(LSent);
        end;
      end;

      if LReno.Cwnd < ARes.MinCwndSeen then
        ARes.MinCwndSeen := LReno.Cwnd;
      if LReno.Cwnd < LReno.MinCwnd then
        Exit;   { cwnd 跌破最小窗即失败 }
    end;
    ARes.FinalCwnd := LReno.Cwnd;
    ARes.FinalInFlight := LTracker.InFlightCount;
    Result := True;
  finally
    LReno.Free;
    LTracker.Free;
  end;
end;

var
  LRunner: TSuiteRunner;
  LSuite: TTestSuite;

begin
  LSuite := TTestSuite.Create('quic_congestion');

  { ---------- 初始/最小窗口公式 ---------- }
  LSuite.Test('initial window formula with 14720 cap', procedure
  begin
    { 1200：min(12000, max(14720,2400)) = 12000 }
    CheckEqual(UInt64(12000), QuicInitialCwnd(1200));
    { 2000：min(20000, 14720) = 14720——上限咬合 }
    CheckEqual(UInt64(14720), QuicInitialCwnd(2000));
    { 800：min(8000, 14720) = 8000——乘数咬合 }
    CheckEqual(UInt64(8000), QuicInitialCwnd(800));
    CheckEqual(UInt64(2400), QuicMinimumCwnd(1200));
  end);

  LSuite.Test('slow start exponential growth', procedure
  var
    LR: TQuicNewReno;
  begin
    LR := TQuicNewReno.Create(1200);
    try
      CheckTrue(LR.InSlowStart);
      CheckTrue(LR.CanSend(11999));
      CheckFalse(LR.CanSend(12000));   { 在途=窗即禁发 }
      LR.OnAcked(3, 3, 6000);
      CheckEqual(UInt64(18000), LR.Cwnd);
      CheckTrue(LR.InSlowStart);       { ssthresh 无穷大仍在慢启动 }
      LR.OnAcked(4, 4, 2000);
      CheckEqual(UInt64(20000), LR.Cwnd);
    finally
      LR.Free;
    end;
  end);

  LSuite.Test('loss halves window with minimum floor', procedure
  var
    LR: TQuicNewReno;
  begin
    LR := TQuicNewReno.Create(1200);
    try
      LR.OnAcked(5, 5, 6000);          { cwnd=18000 }
      LR.OnLost(9);                    { ssthresh=cwnd/2=9000 }
      CheckEqual(UInt64(9000), LR.Ssthresh);
      CheckEqual(UInt64(9000), LR.Cwnd);
      CheckTrue(LR.InRecovery);
      CheckFalse(LR.InSlowStart);
      { 连续两轮丢失压到最小窗下限 }
      LR.OnLost(11);                   { 恢复期内忽略 }
      CheckEqual(UInt64(9000), LR.Cwnd);
      LR.OnAcked(12, 12, 1200);        { pn>9 ⇒ 恢复结束；CA 增量 }
      CheckFalse(LR.InRecovery);
      LR.OnLost(13);
      CheckEqual(UInt64(4580), LR.Cwnd);   { 9160/2 —— 见下方精确链 }
    finally
      LR.Free;
    end;
  end);

  LSuite.Test('recovery exit on post-start packet ack', procedure
  var
    LR: TQuicNewReno;
  begin
    LR := TQuicNewReno.Create(1200);
    try
      LR.OnAcked(5, 5, 6000);
      LR.OnLost(9);                    { 恢复起点：最高已发=9 }
      CheckTrue(LR.InRecovery);
      LR.OnAcked(7, 10, 3000);         { pn=7 ≤ 9：仍恢复，不增窗 }
      CheckTrue(LR.InRecovery);
      CheckEqual(UInt64(9000), LR.Cwnd);
      LR.OnAcked(10, 10, 1200);        { pn=10 > 9：退出并进入 CA }
      CheckFalse(LR.InRecovery);
      { CA 分子累积：1200×1200=1440000 ≥ cwnd 9000 → +160 恰整除 }
      CheckEqual(UInt64(9160), LR.Cwnd);
    finally
      LR.Free;
    end;
  end);

  LSuite.Test('congestion avoidance one mss per cwnd acked', procedure
  var
    LR: TQuicNewReno;
  begin
    LR := TQuicNewReno.Create(1200);
    try
      LR.OnAcked(5, 5, 18000);         { cwnd=30000? 不对：SS 直接加 }
      CheckEqual(UInt64(30000), LR.Cwnd);
      LR.OnLost(8);
      CheckEqual(UInt64(15000), LR.Ssthresh);
      CheckEqual(UInt64(15000), LR.Cwnd);
      LR.OnAcked(9, 9, 15000);         { 退出恢复；cwnd=ssthresh → CA }
      CheckFalse(LR.InRecovery);
      { 整 RTT 确认一个 cwnd：增量应恰为 1 MSS。
        1200×15000=18000000 div 15000 = 1200 }
      CheckEqual(UInt64(16200), LR.Cwnd);
      { 小 ACK 链式累积（逐笔结算，cwnd 随增随用）：
        ack1: accum=1200000 → +74 余 1200, cwnd=16274
        ack2: accum=1201200 div 16274=73 余 13198, cwnd=16347
        ack3: accum=1213198 div 16347=74 余 3520, cwnd=16421 }
      LR.OnAcked(10, 10, 1000);
      LR.OnAcked(11, 11, 1000);
      LR.OnAcked(12, 12, 1000);
      CheckEqual(UInt64(16421), LR.Cwnd);
    finally
      LR.Free;
    end;
  end);

  LSuite.Test('persistent congestion resets to minimum window', procedure
  var
    LR: TQuicNewReno;
  begin
    CheckTrue(QuicIsPersistentCongestion(600000, 200000));
    CheckFalse(QuicIsPersistentCongestion(599999, 200000));
    LR := TQuicNewReno.Create(1200);
    try
      LR.OnAcked(5, 5, 6000);          { cwnd=18000 }
      LR.OnLost(9);                    { ssthresh=9000 }
      LR.OnPersistentCongestion(20);   { §7.6：降 kMinimumWindow }
      CheckEqual(UInt64(2400), LR.Cwnd);
      CheckEqual(UInt64(9000), LR.Ssthresh);   { 阈值不动 }
      CheckTrue(LR.InRecovery);
      LR.OnAcked(21, 21, 1200);        { 退出恢复；SS：2400+1200=3600 }
      CheckFalse(LR.InRecovery);
      { cwnd 3600 < ssthresh 9000 ⇒ 重回慢启动（§7.3.1） }
      CheckTrue(LR.InSlowStart);
      LR.OnAcked(22, 22, 4800);
      CheckEqual(UInt64(8400), LR.Cwnd);   { SS 按 acked 直加：3600+4800 }
    finally
      LR.Free;
    end;
  end);

  LSuite.Test('deterministic lossy sim converges and is reproducible', procedure
  var
    LR1, LR2: TSimResult;
    LOk1, LOk2: Boolean;
  begin
    LOk1 := RunLossySim(LR1);
    LOk2 := RunLossySim(LR2);
    CheckTrue(LOk1);
    CheckTrue(LOk2);
    { 双跑逐位一致 = 纯确定性 }
    CheckTrue(LR1.FinalCwnd = LR2.FinalCwnd, 'final cwnd deterministic');
    CheckTrue(LR1.LostEvents = LR2.LostEvents, 'lost events deterministic');
    { 收敛面：在途排空、丢包事件按期发生、cwnd 不破下限、干净尾段
      重回初始窗之上（探针实测：FinalCwnd=17723 / Min=6803 / 4 事件） }
    CheckEqual(0, LR1.FinalInFlight);
    CheckTrue(LR1.LostEvents = 4, 'expected exactly four loss events');
    CheckTrue(LR1.MinCwndSeen >= 2400, 'cwnd floor respected');
    CheckTrue(LR1.FinalCwnd > 12000,
      'clean tail regrows beyond initial window');
  end);

  { ---------- 源码契约 ---------- }
  LSuite.Test('source contract: no bare FPC RTL in congestion unit', procedure
  var
    LSrcPath, LHit: string;
  begin
    LSrcPath := FsPathAbs(FsPathJoin([FsPathDir(ParamStr(0)),
      '..', '..', '..', '..', 'src', 'nextpas.core.net.quic.congestion.pas']));
    Check(not FindBareFpcRtlInUses(FsReadFileText(LSrcPath), LHit),
      'no bare FPC RTL (hit: ' + LHit + ')');
  end);

  LRunner := TSuiteRunner.Create('nextpas.core.net.quic.congestion');
  LRunner.Add(LSuite);
  LRunner.RunAll;
  LRunner.Summary;
  if not LRunner.AllPassed then Halt(1);
end.
