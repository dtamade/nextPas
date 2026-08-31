program test_quic_reliable;

{ QUIC 可靠性骨架单元测试（RFC 9002 §5/§6 子集）：
  - RTT 估计器手算向量（µs 整数、除法向零取整语义逐值断言）：
    首样本重置 / EWMA 7-8+1-8 / rttvar 3-4+1-4 / 握手确认前不钳
    max_ack_delay / 确认后钳制 / MUST-NOT 减到 min_rtt 以下；
  - PTO 公式（含 Initial/Handshake 空间 max_ack_delay=0 与引导态）；
  - 发送追踪环形窗口：结算正确性 / 不可撤销 / 槽占用拒 / 容量带裁剪；
  - 丢失检测：包阈（kPacketThreshold=3）与时阈（9/8×max(srtt,latest)，
    下限 kGranularity）边界逐点断言——时钟全注入，确定性仿真。
  仅依赖 nextPas/core（无 system 垫片）。 }

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.fs.path,
  nextpas.core.fs.util,
  nextpas.core.net.quic.frame,
  nextpas.core.net.quic.reliable,
  nextpas.core.test;

{$I ../../fpc_rtl_uses_scan.inc}

function MkRanges1(ALo, AHi: UInt64): TQuicAckRangeArray;
begin
  Result := nil;
  SetLength(Result, 1);
  Result[0].Lo := ALo;
  Result[0].Hi := AHi;
end;

var
  LRunner: TSuiteRunner;
  LSuite: TTestSuite;

begin
  LSuite := TTestSuite.Create('quic_reliable');

  { ---------- RTT 估计器手算向量 ---------- }
  LSuite.Test('rtt estimator hand computed sequence', procedure
  var
    LEst: TQuicRttEstimator;
  begin
    QuicRttInit(LEst);
    CheckFalse(LEst.HasSample);
    CheckEqual(UInt64(333000), LEst.SmoothedRttUs);
    CheckEqual(UInt64(166500), LEst.RttVarUs);

    { 首样本重置，不留历史 }
    QuicRttOnSample(LEst, 80000, 0, True, 15000);
    CheckTrue(LEst.HasSample);
    CheckEqual(UInt64(80000), LEst.MinRttUs);
    CheckEqual(UInt64(80000), LEst.SmoothedRttUs);
    CheckEqual(UInt64(40000), LEst.RttVarUs);

    { 确认后钳 delay=5ms(<15ms)：adjusted=90ms；
      srtt=(7*80+90)/8=81.25ms；var=(3*40+|81.25-90|)/4=32.1875→32187µs }
    QuicRttOnSample(LEst, 95000, 5000, True, 15000);
    CheckEqual(UInt64(81250), LEst.SmoothedRttUs);
    CheckEqual(UInt64(32187), LEst.RttVarUs);

    { latest=60ms 新 min；delay 钳 15ms 后 60000 >= 60000+15000 不成立，
      MUST NOT 减到 min_rtt 以下 → adjusted=latest }
    QuicRttOnSample(LEst, 60000, 30000, True, 15000);
    CheckEqual(UInt64(60000), LEst.MinRttUs);
    CheckEqual(UInt64((7 * 81250 + 60000) div 8), LEst.SmoothedRttUs);
    CheckEqual(UInt64(28788), LEst.RttVarUs);
  end);

  LSuite.Test('ack delay clamp only after handshake confirmed', procedure
  var
    LEst: TQuicRttEstimator;
  begin
    { 场景：min_rtt=10ms，样本 latest=100ms。
      未确认：delay=90ms 不钳 → adjusted=100000-(10000+90000 卫语句通过)
      =10000；srtt=(70000+10000)/8=10000 }
    QuicRttInit(LEst);
    QuicRttOnSample(LEst, 10000, 0, False, 10000);
    QuicRttOnSample(LEst, 100000, 90000, False, 10000);
    CheckEqual(UInt64(100000), LEst.LatestRttUs);
    CheckEqual(UInt64(10000), LEst.SmoothedRttUs);
    CheckEqual(UInt64(3750), LEst.RttVarUs);

    { 已确认：delay 钳到 10ms → adjusted=90000；
      srtt=(70000+90000)/8=20000；var=(15000+70000)/4=21250 }
    QuicRttInit(LEst);
    QuicRttOnSample(LEst, 10000, 0, True, 10000);
    QuicRttOnSample(LEst, 100000, 90000, True, 10000);
    CheckEqual(UInt64(20000), LEst.SmoothedRttUs);
    CheckEqual(UInt64(21250), LEst.RttVarUs);
  end);

  { ---------- PTO ---------- }
  LSuite.Test('pto formula and bootstrap', procedure
  var
    LEst: TQuicRttEstimator;
  begin
    QuicRttInit(LEst);
    QuicRttOnSample(LEst, 80000, 0, True, 15000);
    QuicRttOnSample(LEst, 95000, 5000, True, 15000);
    { app 空间：81250 + max(4*32187, 1000) + 15000 = 224998 }
    CheckEqual(UInt64(224998), QuicComputePtoUs(LEst, 15000));
    { Initial/Handshake 空间 max_ack_delay=0 }
    CheckEqual(UInt64(209998), QuicComputePtoUs(LEst, 0));
    { 引导态（无样本）：333000 + max(4*166500, 1000) = 999000 }
    QuicRttInit(LEst);
    CheckEqual(UInt64(999000), QuicComputePtoUs(LEst, 0));
  end);

  { ---------- 追踪与结算 ---------- }
  LSuite.Test('track and settle with ranges', procedure
  var
    LT: TQuicSentTracker;
    LRng: TQuicAckRangeArray;
    LStats: TQuicAckStats;
    LI: Integer;
  begin
    LT := TQuicSentTracker.Create(cQuicSentWindowDefault);
    try
      for LI := 0 to 9 do
        CheckTrue(LT.Track(LI, UInt64(1000 + LI * 1000), 120, True));
      CheckEqual(10, LT.InFlightCount);
      CheckEqual(1200, LT.InFlightBytes);

      SetLength(LRng, 2);
      LRng[0].Lo := 7; LRng[0].Hi := 9;
      LRng[1].Lo := 4; LRng[1].Hi := 5;
      CheckTrue(LT.OnAckFrame(9, LRng, LStats));
      CheckEqual(5, LStats.AckedCount);
      CheckEqual(600, LStats.AckedBytes);
      CheckTrue(LStats.HasSampleCandidate);
      CheckEqual(UInt64(9), LStats.SamplePn);
      CheckEqual(UInt64(10000), LStats.SampleTimeSentUs);
      CheckEqual(5, LT.InFlightCount);
      CheckTrue(LT.HasLargestAcked);
      CheckEqual(UInt64(9), LT.LargestAcked);

      { 不可撤销：同帧重放零新确认 }
      CheckTrue(LT.OnAckFrame(9, LRng, LStats));
      CheckEqual(0, LStats.AckedCount);
      CheckFalse(LStats.HasSampleCandidate);
    finally
      LT.Free;
    end;
  end);

  LSuite.Test('non ack eliciting yields no sample candidate', procedure
  var
    LT: TQuicSentTracker;
    LStats: TQuicAckStats;
  begin
    LT := TQuicSentTracker.Create(16);
    try
      CheckTrue(LT.Track(0, 100, 50, False));
      CheckTrue(LT.Track(1, 200, 50, True));
      CheckTrue(LT.OnAckFrame(1, MkRanges1(0, 1), LStats));
      CheckEqual(2, LStats.AckedCount);
      CheckTrue(LStats.HasSampleCandidate);
      CheckEqual(UInt64(1), LStats.SamplePn);

      LT.Free;
      LT := TQuicSentTracker.Create(16);
      CheckTrue(LT.Track(0, 100, 50, False));
      CheckTrue(LT.OnAckFrame(0, MkRanges1(0, 0), LStats));
      CheckEqual(1, LStats.AckedCount);
      CheckFalse(LStats.HasSampleCandidate);
    finally
      LT.Free;
    end;
  end);

  { ---------- fail-closed 面 ---------- }
  LSuite.Test('window slot occupancy rejected', procedure
  var
    LT: TQuicSentTracker;
    LStats: TQuicAckStats;
    LI: Integer;
  begin
    LT := TQuicSentTracker.Create(16);
    try
      for LI := 0 to 15 do
        CheckTrue(LT.Track(UInt64(LI), 0, 10, True));
      { 回绕槽位被占：pn16 与 pn0 同槽 }
      CheckFalse(LT.Track(16, 0, 10, True));
      { 同 PN 重复登记拒 }
      CheckFalse(LT.Track(5, 0, 10, True));
      { 释放 pn0 后 pn16 可入 }
      CheckTrue(LT.OnAckFrame(0, MkRanges1(0, 0), LStats));
      CheckEqual(1, LStats.AckedCount);
      CheckTrue(LT.Track(16, 0, 10, True));
      CheckEqual(16, LT.InFlightCount);
    finally
      LT.Free;
    end;
  end);

  LSuite.Test('band clipping settles across wide range', procedure
  var
    LT: TQuicSentTracker;
    LStats: TQuicAckStats;
  begin
    { range 宽度远超容量：仍按容量带命中唯一在途槽 }
    LT := TQuicSentTracker.Create(16);
    try
      CheckTrue(LT.Track(40, 500, 77, True));
      CheckTrue(LT.OnAckFrame(100, MkRanges1(0, 100), LStats));
      CheckEqual(1, LStats.AckedCount);
      CheckEqual(77, LStats.AckedBytes);
      CheckEqual(UInt64(40), LStats.SamplePn);
      CheckEqual(0, LT.InFlightCount);
    finally
      LT.Free;
    end;
  end);

  { ---------- 丢失检测 ---------- }
  LSuite.Test('packet threshold loss declares 3 behind', procedure
  var
    LT: TQuicSentTracker;
    LEst: TQuicRttEstimator;
    LLost: TQuicPnArray;
    LBytes: Integer;
    LStats: TQuicAckStats;
    LI: Integer;
  begin
    LT := TQuicSentTracker.Create(cQuicSentWindowDefault);
    try
      for LI := 0 to 9 do
        CheckTrue(LT.Track(UInt64(LI), UInt64(LI * 1000), 100, True));
      QuicRttInit(LEst);
      CheckTrue(LT.OnAckFrame(9, MkRanges1(9, 9), LStats));

      { 引导态估计器时阈=ceil(9/8*333000)=374625；tNow=10ms 时对 pn0..6
        （发送时刻≤6000）时阈未到，判丢纯由包阈驱动：pn≤6 全丢，7/8 幸存 }
      LT.DetectLost(LEst, 10000, LLost, LBytes);
      CheckEqual(7, Length(LLost));
      CheckEqual(700, LBytes);
      CheckEqual(2, LT.InFlightCount);
    finally
      LT.Free;
    end;
  end);

  LSuite.Test('time threshold boundary exact', procedure
  var
    LT: TQuicSentTracker;
    LEst: TQuicRttEstimator;
    LLost: TQuicPnArray;
    LBytes: Integer;
    LStats: TQuicAckStats;
  begin
    LT := TQuicSentTracker.Create(cQuicSentWindowDefault);
    try
      CheckTrue(LT.Track(0, 0, 100, True));
      CheckTrue(LT.Track(1, 1000, 100, True));
      CheckTrue(LT.Track(2, 2000, 100, True));
      { 单样本：latest=srtt=80000 → 时阈=ceil(9/8*80000)=90000 }
      QuicRttInit(LEst);
      QuicRttOnSample(LEst, 80000, 0, True, 15000);
      CheckTrue(LT.OnAckFrame(2, MkRanges1(2, 2), LStats));

      { tNow=89999（阈前一刻）：无包越阈；pn2 已确认故在途=2 }
      LT.DetectLost(LEst, 89999, LLost, LBytes);
      CheckEqual(0, Length(LLost));
      CheckEqual(2, LT.InFlightCount);

      { t=90000：pn0 越阈（90000>=0+90000）；pn1 需 1000+90000=91000 }
      LT.DetectLost(LEst, 90000, LLost, LBytes);
      CheckEqual(1, Length(LLost));   { 仅 pn0 }
      CheckEqual(UInt64(0), LLost[0]);
      LT.DetectLost(LEst, 91000, LLost, LBytes);
      CheckEqual(1, Length(LLost));   { pn1 }
      CheckEqual(UInt64(1), LLost[0]);
      CheckEqual(0, LT.InFlightCount);   { pn2 已确认 }
    finally
      LT.Free;
    end;
  end);

  LSuite.Test('no largest acked means no loss detection', procedure
  var
    LT: TQuicSentTracker;
    LEst: TQuicRttEstimator;
    LLost: TQuicPnArray;
    LBytes: Integer;
  begin
    LT := TQuicSentTracker.Create(16);
    try
      QuicRttInit(LEst);
      CheckTrue(LT.Track(0, 0, 100, True));
      LT.DetectLost(LEst, 1000000000, LLost, LBytes);
      CheckEqual(0, Length(LLost));
      CheckEqual(1, LT.InFlightCount);
    finally
      LT.Free;
    end;
  end);

  { ---------- 源码契约 ---------- }
  LSuite.Test('source contract: no bare FPC RTL in reliable unit', procedure
  var
    LSrcPath, LHit: string;
  begin
    LSrcPath := FsPathAbs(FsPathJoin([FsPathDir(ParamStr(0)),
      '..', '..', '..', '..', 'src', 'nextpas.core.net.quic.reliable.pas']));
    Check(not FindBareFpcRtlInUses(FsReadFileText(LSrcPath), LHit),
      'no bare FPC RTL (hit: ' + LHit + ')');
  end);

  LRunner := TSuiteRunner.Create('nextpas.core.net.quic.reliable');
  LRunner.Add(LSuite);
  LRunner.RunAll;
  LRunner.Summary;
  if not LRunner.AllPassed then Halt(1);
end.
