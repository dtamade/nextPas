unit nextpas.core.db.pool.state;

{** @desc db.pool 状态容器单源（L2 基础设施，CONTRACT §2.7；base ← idle/leak ← state ← sched ← impl ← facade）。
       职责：Idle 与 Outstanding 向量统一持有与 Init/Done 单源，Pending/LeakNextDue/NextEvictDue 聚合于同一容器，impl 薄委托零直连跨叶（6→1 收敛经 state 单入口，sched 单核调度零跨叶变更），消弭 impl 内直接持有 TPoolIdleVec/TOutstandingVec 并自管 Init/Done 的分治剩余；
       性能 inline/零拷贝（TSmallVec 栈内联 16/8 + 堆 1.5x 单 Move，bytes.ops 单源 BYTES_OPS_SINGLE_SOURCE 单 Move 零拷贝，platform_monotonic_ns 单源），稳定性资源释放不丢（Init/Done 配对、Done 清 Pending），复用 bytes.ops 与 collections 小容器单源。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.bytes.ops,
  nextpas.core.collections.smallvec,
  nextpas.core.db.pool.base,
  nextpas.core.db.pool.idle,
  nextpas.core.db.pool.leak;

const
  POOL_STATE_BYTES_SINGLE_SOURCE = BYTES_OPS_SINGLE_SOURCE;

{$I nextpas.core.bytes.ops.single_source.inc}

type
  { 池状态容器：Idle 热队 + Outstanding 簿记 + Pending/阈值节流聚合单源（sched 单核唯一操作面，impl 仅持此容器） }
  TPoolState = record
    Idle: TPoolIdleVec;
    Outstanding: TPoolOutstandingVec;
    Pending: TDbPoolLeakReports;
    LeakNextDue: QWord;
    NextEvictDue: QWord;
  end;

  { 单核收敛类型载体再导出：impl 经 state 单入口零直连 idle/leak，逻辑经 sched 单核聚合（6→1 叶收敛，零直连跨叶调度） }
  TStateIdleEntry = TPoolIdleEntry;
  TStateOutstanding = TPoolOutstanding;
  TStateLeakSnaps = TPoolLeakSnaps;
  TStateIdleVec = TPoolIdleVec;
  TStateOutstandingVec = TPoolOutstandingVec;

procedure PoolStateInit(var AState: TPoolState); inline;
procedure PoolStateDone(var AState: TPoolState); inline;

implementation

procedure PoolStateInit(var AState: TPoolState); inline;
begin
  AState.Idle.Init;
  AState.Outstanding.Init;
  AState.Pending := nil;
  AState.LeakNextDue := High(QWord);
  AState.NextEvictDue := 0;
end;

procedure PoolStateDone(var AState: TPoolState); inline;
begin
  AState.Idle.Done;
  AState.Outstanding.Done;
  AState.Pending := nil;
  AState.LeakNextDue := High(QWord);
  AState.NextEvictDue := 0;
end;

end.
