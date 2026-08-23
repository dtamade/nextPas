program test_quic_flow;

{ QUIC 流控账本单元测试（RFC 9000 §4 子集，Q5）：
  - 发送预算手算向量：授权单调不回退 / 计费前沿只进不退 /
    可发数与全量放行判定边界逐点断言；
  - 接收自动升窗：过半阈值（Advertised-Consumed ≤ Window div 2）
    边界、通告单调不减、连续多轮升窗循环收敛；
  - 纯整数零时钟，确定性由构造保证。
  仅依赖 nextPas/core（无 system 垫片）。 }

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.fs.path,
  nextpas.core.fs.util,
  nextpas.core.net.quic.flow,
  nextpas.core.test;

{$I ../../fpc_rtl_uses_scan.inc}

var
  LRunner: TSuiteRunner;
  LSuite: TTestSuite;

begin
  LSuite := TTestSuite.Create('quic_flow');

  { ---------- 发送预算手算向量 ---------- }
  LSuite.Test('budget init and available arithmetic', procedure
  var
    LB: TQuicFlowBudget;
  begin
    QuicBudgetInit(LB, 1000);
    CheckEqual(UInt64(1000), LB.Granted);
    CheckEqual(UInt64(0), LB.Frontier);
    CheckEqual(UInt64(1000), QuicBudgetAvailable(LB));
    CheckTrue(QuicBudgetCanSend(LB, 1000));
    CheckFalse(QuicBudgetCanSend(LB, 1001));
    CheckTrue(QuicBudgetCanSend(LB, 0));
  end);

  LSuite.Test('grant monotonic: reductions ignored', procedure
  var
    LB: TQuicFlowBudget;
  begin
    QuicBudgetInit(LB, 1000);
    QuicBudgetGrant(LB, 800);          { 收缩值必须忽略 }
    CheckEqual(UInt64(1000), LB.Granted);
    QuicBillingAdvance(LB, 600);
    CheckEqual(UInt64(400), QuicBudgetAvailable(LB));
    QuicBudgetGrant(LB, 2000);         { 扩张生效 }
    CheckEqual(UInt64(2000), LB.Granted);
    CheckEqual(UInt64(1400), QuicBudgetAvailable(LB));
    { 同值重复授予幂等 }
    QuicBudgetGrant(LB, 2000);
    CheckEqual(UInt64(2000), LB.Granted);
  end);

  LSuite.Test('billing frontier only advances', procedure
  var
    LB: TQuicFlowBudget;
  begin
    QuicBudgetInit(LB, 2000);
    QuicBillingAdvance(LB, 600);
    QuicBillingAdvance(LB, 500);       { 回退尝试被拒 }
    CheckEqual(UInt64(600), LB.Frontier);
    CheckEqual(UInt64(1400), QuicBudgetAvailable(LB));
    QuicBillingAdvance(LB, 2000);      { 前沿推满 }
    CheckEqual(UInt64(0), QuicBudgetAvailable(LB));
    CheckFalse(QuicBudgetCanSend(LB, 1));
    { 重传同偏移不计费：前沿不动，可用额度不变 }
    QuicBudgetGrant(LB, 3000);
    QuicBillingAdvance(LB, 2000);
    CheckEqual(UInt64(1000), QuicBudgetAvailable(LB));
  end);

  { ---------- 接收自动升窗 ---------- }
  LSuite.Test('recv auto-window half threshold boundary', procedure
  var
    LC: TQuicFlowRecvCtl;
  begin
    QuicRecvInit(LC, 64);
    CheckEqual(UInt64(64), LC.Advertised);
    CheckEqual(UInt64(0), LC.Consumed);
    { 剩余 64 > 一半 32：不升窗 }
    CheckFalse(QuicRecvShouldAdvertise(LC));
    QuicRecvConsume(LC, 31);           { 剩余 33：仍不升 }
    CheckFalse(QuicRecvShouldAdvertise(LC));
    QuicRecvConsume(LC, 1);            { 剩余 32 = 一半：升窗边界 }
    CheckTrue(QuicRecvShouldAdvertise(LC));
    CheckEqual(UInt64(96), QuicRecvNextLimit(LC));
  end);

  LSuite.Test('advertise monotonic never shrinks', procedure
  var
    LC: TQuicFlowRecvCtl;
  begin
    QuicRecvInit(LC, 64);
    QuicRecvConsume(LC, 32);
    CheckTrue(QuicRecvAdvertise(LC, 96));
    CheckEqual(UInt64(96), LC.Advertised);
    CheckFalse(QuicRecvAdvertise(LC, 90));   { 收缩拒绝 }
    CheckEqual(UInt64(96), LC.Advertised);
    CheckFalse(QuicRecvAdvertise(LC, 96));   { 同值非变更 }
  end);

  LSuite.Test('consume past advertised still advertises', procedure
  var
    LC: TQuicFlowRecvCtl;
  begin
    QuicRecvInit(LC, 64);
    QuicRecvConsume(LC, 100);          { 越界消费（乱序到货形态） }
    CheckTrue(QuicRecvShouldAdvertise(LC));
    CheckEqual(UInt64(164), QuicRecvNextLimit(LC));
  end);

  LSuite.Test('multi round window cycling converges', procedure
  var
    LC: TQuicFlowRecvCtl;
    LRounds, LAds: Integer;
  begin
    QuicRecvInit(LC, 64);
    LAds := 0;
    for LRounds := 1 to 10 do
    begin
      QuicRecvConsume(LC, 32);         { 每轮消费半窗 }
      if QuicRecvShouldAdvertise(LC) then
      begin
        CheckTrue(QuicRecvAdvertise(LC, QuicRecvNextLimit(LC)));
        Inc(LAds);
      end;
    end;
    { 每轮恰好触发一次升窗：共 10 次，且通告上沿单调递增 }
    CheckEqual(10, LAds);
    CheckEqual(UInt64(64 + 320), LC.Advertised);
    CheckEqual(UInt64(320), LC.Consumed);
  end);

  { ---------- 源码契约 ---------- }
  LSuite.Test('source contract: no bare FPC RTL in flow unit', procedure
  var
    LSrcPath, LHit: string;
  begin
    LSrcPath := FsPathAbs(FsPathJoin([FsPathDir(ParamStr(0)),
      '..', '..', '..', '..', 'src', 'nextpas.core.net.quic.flow.pas']));
    Check(not FindBareFpcRtlInUses(FsReadFileText(LSrcPath), LHit),
      'no bare FPC RTL (hit: ' + LHit + ')');
  end);

  LRunner := TSuiteRunner.Create('nextpas.core.net.quic.flow');
  LRunner.Add(LSuite);
  LRunner.RunAll;
  LRunner.Summary;
  if not LRunner.AllPassed then Halt(1);
end.
