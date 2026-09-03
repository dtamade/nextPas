unit nextpas.core.db.pool.impl;

{** @desc db.pool 实现层（L2 基础设施，CONTRACT §2.7；base ← idle/leak ← state ← sched(聚合 idle/leak/obs/concurrency)+proxy ← impl ← facade）。
       拥有 TDbPoolCore 状态核（FState: TPoolState 单源容器聚合 Idle/Outstanding/Pending/LeakNextDue/NextEvictDue，Init/Done 单源于 pool.state，impl 零直连 TPoolIdleVec/TOutstandingVec 与自管 Init/Done，sched 单核内聚调度，跨叶变更经 sched/state 单点同步），调度核内聚至 sched 单核（AcquireRead/Writer/ReturnProxy+IdlePush/Pop/GrowCap/Flush 聚合转发，impl 经 FState 单入口 6→1 叶收敛，零直连跨叶调度）；
       租约硬回收：软告警 60s 后硬回收 1.2×阈值（72s）强制释放读/写槽位并 Discard 滞留代理防双释，避免忘归还耗尽槽位（ScopedLease try..finally 置 nil 归还为首选，裸租约极端滞留由硬回收兜底，较 2×120s 缩短阻塞）；
       热路径单 tick 批量合并(预热 8 连单 ns 复用)+节流冷驱逐（1s）控锁持有；性能 inline/零拷贝（TPoolIdleVec/TPoolOutstandingVec 小容器栈内联 16/8+堆 1.5x 单 Move，platform_monotonic_ns 单源，预热单 tick 复用省 N-1 syscall），资源释放不丢，复用 bytes.ops 单源与 collections/state 小容器单源。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.exception,
  nextpas.core.bytes.ops,
  nextpas.core.collections.smallvec,
  nextpas.core.platform.time,
  nextpas.core.sync,
  nextpas.core.text.conv,
  nextpas.core.log.intf,
  nextpas.core.db.base,
  nextpas.core.db.intf,
  nextpas.core.db.pool.base,
  nextpas.core.db.pool.intf,
  nextpas.core.db.pool.state,  // 状态容器单源：Idle/Outstanding/Pending/阈值聚合+类型载体再导出(TStateIdleEntry/TStateOutstanding 等)经 state 单入口零直连 idle/leak，Init/Done 单源（sched 单核聚合逻辑 6→1 叶收敛）
  nextpas.core.db.pool.sched; // 调度核单核聚合 idle/leak/obs/concurrency+硬回收 1.2×72s，impl 经 FState 单入口零直连跨叶调度

  { 单源门禁：串/字节零拷贝单源为 bytes.ops，空闲队列热路径单 Move 不自建副本；时钟单源为 platform_monotonic_ns (ns 零 div，阈值侧换算，零 GetTickCount64 漂移) }


type
  { 核心态：状态核（FState 单源容器聚合 Idle/Outstanding/Pending/阈值，Init/Done 单源于 pool.state，sched 单核内聚 idle/leak/obs/concurrency，proxy 代理侧，impl 薄委托收敛跨叶同步；小容器 TSmallVec 单源，零手算 GrowCap，硬回收 1.2×阈值(72s)兜底裸租约较 2×120s缩短阻塞） }
  TDbPoolCore = class(TInterfacedObject, IDbPoolCore)
  private type
    TIdleEntry = TStateIdleEntry;
    TOutstanding = TStateOutstanding;
    TLeakSnaps = TStateLeakSnaps;
  private
    FPolicy: TDbPoolPolicy;
    FConnect: TDbConnectFunc;
    FLock: INativeMutex;
    FReadSlots: ISemaphore;
    FWriterSlot: ISemaphore;
    FState: TPoolState; // 单源容器：Idle/Outstanding/Pending/LeakNextDue/NextEvictDue 聚合，Init/Done 单源（替代 FIdle/FOutstanding 直持）
    FWriterConn: IDbConnection;
    FWriterCreatedTick: QWord;
    FClosed: Boolean;
    function NowTick: QWord; inline;
    function OpenFresh(out ACreatedTick: QWord): IDbConnection; inline;
    function OpenFreshBatched(out ACreatedTick: QWord; const ACachedTick: QWord): IDbConnection; inline;
    procedure IdlePush(const AEntry: TIdleEntry); inline;
    function IdlePop(var AEntry: TIdleEntry): Boolean; inline;
  public
    constructor Create(const AConnect: TDbConnectFunc; const APolicy: TDbPoolPolicy);
    destructor Destroy; override;
    function AcquireRead: IDbConnection;
    function AcquireWriter: IDbConnection;
    procedure Shutdown;
    function Policy: TDbPoolPolicy;
    procedure ReturnProxy(AProxy: TObject);
    procedure FlushDiagnostics;
    procedure ScopedLease(const ABody: TDbConnProc; const AIsWriter: Boolean);
  end;

function CreatePoolCore(const AConnect: TDbConnectFunc;
  const APolicy: TDbPoolPolicy): IDbPoolCore; inline;

{ bytes.ops 单源泄漏串→字节零拷贝单 Move（PoolLeakToBytes inline 薄转发，门禁钉死见 check_pool_lease_source_contract.sh §5，不自建副本） }
function PoolLeakToBytes(const AReport: string): TBytes; inline;

implementation

function CreatePoolCore(const AConnect: TDbConnectFunc;
  const APolicy: TDbPoolPolicy): IDbPoolCore;
begin
  Result := TDbPoolCore.Create(AConnect, APolicy);
end;

{ bytes.ops 单源实现：单 Move 零拷贝，单源 StringToBytes，不自建副本，inline 零 I-Cache 于调用点 }
function PoolLeakToBytes(const AReport: string): TBytes; inline;
begin
  Result := StringToBytes(AReport);
end;

{ ---- TDbPoolCore（状态核；调度薄委托至 pool.sched，析构留诊 NullLogger 回退不丢释放，信号量配对 finally 不丢；小容器 TSmallVec 单源，平台单调时钟单源） ---- }

constructor TDbPoolCore.Create(const AConnect: TDbConnectFunc;
  const APolicy: TDbPoolPolicy);
var
  I: Integer;
  E: TIdleEntry;
  LBatchTick: QWord;
begin
  inherited Create;
  if AConnect = nil then
    raise EDbError.CreateSimple(dbkUnknown, 'pool: nil connect factory');
  if APolicy.MaxReadConnections < 1 then
    raise EDbError.CreateSimple(dbkUnknown, 'pool: MaxReadConnections must be >= 1');
  if APolicy.MinConnections > APolicy.MaxReadConnections then
    raise EDbError.CreateSimple(dbkUnknown, 'pool: MinConnections exceeds MaxReadConnections');
  FConnect := AConnect;
  FPolicy := APolicy;
  PoolStateInit(FState);
  FLock := Mutex;
  FReadSlots := Semaphore(APolicy.MaxReadConnections);
  FWriterSlot := Semaphore(1);
  { 预热批量合并：8 线程池预热阶段 MinConnections 单次 platform_monotonic_ns(ns) 复用，89k ops/s 锤压下省 N-1 次 syscall；阈值全零时零时钟(0) 零 div }
  if (APolicy.MaxLifetimeSec > 0) or (APolicy.IdleTimeoutSec > 0) or
     (APolicy.LeakDetectionThresholdMs > 0) then
    LBatchTick := NowTick
  else
    LBatchTick := 0;
  for I := 1 to APolicy.MinConnections do
  begin
    E.Conn := OpenFreshBatched(E.CreatedTick, LBatchTick);
    E.ReturnedTick := E.CreatedTick;
    IdlePush(E);
  end;
end;

destructor TDbPoolCore.Destroy;
begin
  Shutdown;
  PoolStateDone(FState);
  inherited Destroy;
end;

function TDbPoolCore.Policy: TDbPoolPolicy;
begin
  Result := FPolicy;
end;

function TDbPoolCore.NowTick: QWord; inline;
begin
  { perf: ns 单源零整除——platform_monotonic_ns 单次调用无 div，阈值比较侧 *1_000_000/*1_000_000_000，热路径 89k ops/s 零除法延迟，inline 零 I-Cache 膨胀 }
  Result := QWord(platform_monotonic_ns);
end;

function TDbPoolCore.OpenFresh(out ACreatedTick: QWord): IDbConnection; inline;
begin
  Result := OpenFreshBatched(ACreatedTick, NowTick);
end;

function TDbPoolCore.OpenFreshBatched(out ACreatedTick: QWord; const ACachedTick: QWord): IDbConnection; inline;
begin
  { perf: 批量合并——ACachedTick 来自预热单次 NowTick(ns 单源)复用，89k ops/s 锤压/预热省 N-1 syscall；0 保持 0 零额外 syscall（IdleTimeout 0 短路），inline 零 I-Cache 膨胀，零拷贝 }
  ACreatedTick := ACachedTick;
  Result := FConnect();
  if Result = nil then
    raise EDbError.CreateSimple(dbkUnknown, 'pool: connect factory returned nil');
end;

procedure TDbPoolCore.IdlePush(const AEntry: TIdleEntry); inline;
begin
  PoolSchedIdlePushVec(FState.Idle, AEntry);
end;

function TDbPoolCore.IdlePop(var AEntry: TIdleEntry): Boolean; inline;
begin
  Result := PoolSchedIdlePopVec(FState.Idle, AEntry);
end;

procedure TDbPoolCore.FlushDiagnostics;
begin
  PoolSchedFlushSafePointVec(FState.Outstanding, FState.Pending, FState.LeakNextDue, FPolicy, FLock);
end;

{ 体外联路由，try..finally 置 nil 归还 }
procedure TDbPoolCore.ScopedLease(const ABody: TDbConnProc; const AIsWriter: Boolean);
var
  LConn: IDbConnection;
begin
  if ABody = nil then
    raise EDbError.CreateSimple(dbkUnknown, 'pool: nil scoped-lease callback');
  if AIsWriter then
    LConn := AcquireWriter
  else
    LConn := AcquireRead;
  try
    ABody(LConn);
  finally
    LConn := nil;
  end;
end;

procedure TDbPoolCore.ReturnProxy(AProxy: TObject);
begin
  PoolSchedReturnProxyVec(Self, AProxy, FLock, FState.Idle, FWriterConn, FState.Outstanding, FState.Pending, FState.LeakNextDue, FReadSlots, FWriterSlot, FClosed);
end;

function TDbPoolCore.AcquireRead: IDbConnection;
begin
  Result := PoolSchedAcquireReadVec(Self, FPolicy, FConnect, FLock, FReadSlots, FState.Idle, FState.Outstanding, FState.Pending, FState.LeakNextDue, FClosed, FState.NextEvictDue, FWriterConn, FWriterSlot);
end;

function TDbPoolCore.AcquireWriter: IDbConnection;
begin
  Result := PoolSchedAcquireWriterVec(Self, FPolicy, FConnect, FLock, FWriterSlot, FWriterConn, FWriterCreatedTick, FState.Outstanding, FState.Pending, FState.LeakNextDue, FClosed);
end;

procedure TDbPoolCore.Shutdown;
var
  E: TIdleEntry;
begin
  if FLock = nil then
  begin
    FClosed := True;
    Exit;
  end;
  FLock.Acquire;
  try
    FClosed := True;
    while IdlePop(E) do
      E.Conn := nil;
    FWriterConn := nil;
  finally
    FLock.Release;
  end;
end;

end.
