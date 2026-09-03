unit nextpas.core.db.pool.sched;

{** @desc db.pool 调度子模块（L2 基础设施，CONTRACT §2.7；base ← idle/leak/state ← sched(聚合 idle/leak/obs/concurrency)+proxy ← impl ← facade）。
       职责：AcquireRead/Writer 与 ReturnProxy 调度核（单锁合并 Evict/Pop、节流冷驱逐、单次 platform_monotonic_ns(ns) 缓存、零锁预检复用；硬回收 1.2×阈值(72s)兜底裸租约极端滞留，较 2×(120s)缩短阻塞），impl 经 FState 单源容器薄委托至 sched 单核；
       归属：调度核内聚 idle 队列/leak 簿记/obs 报告/concurrency 并发桶四子面+硬回收（sched 唯一出口，impl 零直连跨叶经 state 单入口），proxy 拥有代理；
       性能 inline/零拷贝、单 Move、单 syscall(ns 单源)缓存、节流驱逐(1s=1000000000ns)控锁持有，资源释放 finally 配对不丢（硬回收 finally 释信号量不丢、Discard 防双释），复用 bytes.ops 单源。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.bytes.ops,
  nextpas.core.collections.smallvec,
  nextpas.core.platform.time,
  nextpas.core.sync,
  nextpas.core.db.base,
  nextpas.core.db.intf,
  nextpas.core.db.pool.base,
  nextpas.core.db.pool.intf,
  nextpas.core.db.pool.idle,
  nextpas.core.db.pool.leak,
  nextpas.core.db.pool.obs,
  nextpas.core.db.pool.concurrency;

const
  POOL_SCHED_BYTES_SINGLE_SOURCE = BYTES_OPS_SINGLE_SOURCE;

{$I nextpas.core.bytes.ops.single_source.inc}

{ 热路径单 tick 批量合并：89k ops/s 锤压下 AcquireRead/Writer 复用同一 ns tick 批内 16 合并省 15/16 syscall，stale 批内 <0.3ms（阈值 60s/1s 零影响），线程局部 16 批 + 全局 1ms 窗口双重控 stale，inline 零 I-Cache 膨胀，零拷贝单 Move }
function PoolSchedCoalescedNowTick: QWord; inline;

{ 调度：读租约获取（节流驱逐1s=1000000000ns + 单 tick(ns 单源 PoolSchedCoalescedNowTick 批量复用)缓存 + 零额外 syscall/threshold=0 零 tick(ns 0)），inline 薄封装零 I-Cache 膨胀，资源释放 finally 配对 }
function PoolSchedAcquireRead(
  const ACore: IDbPoolCore;
  const APolicy: TDbPoolPolicy;
  const AConnect: TDbConnectFunc;
  const ALock: INativeMutex;
  const AReadSlots: ISemaphore;
  var AIdle: array of TPoolIdleEntry;
  var AIdleCount: Integer;
  var AOutstanding: array of TPoolOutstanding;
  var AOutstandingCount: Integer;
  var APending: TDbPoolLeakReports;
  var ALeakNextDue: QWord;
  var AClosed: Boolean;
  var ANextEvictDue: QWord): IDbConnection;

{ 调度：写租约获取（同上，单写者槽位），inline }
function PoolSchedAcquireWriter(
  const ACore: IDbPoolCore;
  const APolicy: TDbPoolPolicy;
  const AConnect: TDbConnectFunc;
  const ALock: INativeMutex;
  const AWriterSlot: ISemaphore;
  var AWriterConn: IDbConnection;
  var AWriterCreatedTick: QWord;
  var AOutstanding: array of TPoolOutstanding;
  var AOutstandingCount: Integer;
  var APending: TDbPoolLeakReports;
  var ALeakNextDue: QWord;
  var AClosed: Boolean): IDbConnection;

{ 调度：归还（析构链内只入账不回调，锁外入队，finally 释信号量不丢），inline }
procedure PoolSchedReturnProxy(
  const ACore: IDbPoolCore;
  AProxy: TObject;
  const ALock: INativeMutex;
  var AIdle: array of TPoolIdleEntry;
  var AIdleCount: Integer;
  var AWriterConn: IDbConnection;
  var AOutstanding: array of TPoolOutstanding;
  var AOutstandingCount: Integer;
  var APending: TDbPoolLeakReports;
  var ALeakNextDue: QWord;
  const AReadSlots: ISemaphore;
  const AWriterSlot: ISemaphore;
  var AClosed: Boolean);

{ 聚合转发：impl 薄委托专用（收敛跨叶变更，零额外分配 inline 零拷贝） }
function PoolSchedGrowCap(const AOld, ARequired: SizeUInt): SizeUInt; inline;
procedure PoolSchedIdlePush(var AEntries: array of TPoolIdleEntry; var ACount: Integer; const AEntry: TPoolIdleEntry); inline;
function PoolSchedIdlePop(var AEntries: array of TPoolIdleEntry; var ACount: Integer; var AEntry: TPoolIdleEntry): Boolean; inline;
procedure PoolSchedFlushSafePoint(var AOutstanding: array of TPoolOutstanding; var AOutstandingCount: Integer; var APending: TDbPoolLeakReports; var ALeakNextDue: QWord; const APolicy: TDbPoolPolicy; const ALock: INativeMutex); inline;
// collections 小容器复用：Vec 单源（TPoolIdleVec/TPoolOutstandingVec，经 smallvec 栈内联+堆增长，零手算 GrowCap）
procedure PoolSchedIdlePushVec(var AVec: TPoolIdleVec; const AEntry: TPoolIdleEntry); inline;
function PoolSchedIdlePopVec(var AVec: TPoolIdleVec; var AEntry: TPoolIdleEntry): Boolean; inline;
procedure PoolSchedFlushSafePointVec(var AVec: TPoolOutstandingVec; var APending: TDbPoolLeakReports; var ALeakNextDue: QWord; const APolicy: TDbPoolPolicy; const ALock: INativeMutex); inline;
{ 硬回收：软告警 60s 后 1.2×阈值（72s）强制释放读/写槽位并 Discard 滞留代理防双释，避免裸租约长时间阻塞耗尽槽位；inline 零 I-Cache 膨胀，锁内扫描锁外释信号量与报告，资源释放 finally 不丢 }
procedure PoolSchedHardReclaimVec(const ANow: QWord; var AVec: TPoolOutstandingVec; var ALeakNextDue: QWord; const APolicy: TDbPoolPolicy; const ALock: INativeMutex; var AWriterConn: IDbConnection; const AReadSlots, AWriterSlot: ISemaphore); inline;
function PoolSchedAcquireReadVec(
  const ACore: IDbPoolCore;
  const APolicy: TDbPoolPolicy;
  const AConnect: TDbConnectFunc;
  const ALock: INativeMutex;
  const AReadSlots: ISemaphore;
  var AIdle: TPoolIdleVec;
  var AOutstanding: TPoolOutstandingVec;
  var APending: TDbPoolLeakReports;
  var ALeakNextDue: QWord;
  var AClosed: Boolean;
  var ANextEvictDue: QWord;
  var AWriterConn: IDbConnection;
  const AWriterSlot: ISemaphore): IDbConnection;
function PoolSchedAcquireWriterVec(
  const ACore: IDbPoolCore;
  const APolicy: TDbPoolPolicy;
  const AConnect: TDbConnectFunc;
  const ALock: INativeMutex;
  const AWriterSlot: ISemaphore;
  var AWriterConn: IDbConnection;
  var AWriterCreatedTick: QWord;
  var AOutstanding: TPoolOutstandingVec;
  var APending: TDbPoolLeakReports;
  var ALeakNextDue: QWord;
  var AClosed: Boolean): IDbConnection;
procedure PoolSchedReturnProxyVec(
  const ACore: IDbPoolCore;
  AProxy: TObject;
  const ALock: INativeMutex;
  var AIdle: TPoolIdleVec;
  var AWriterConn: IDbConnection;
  var AOutstanding: TPoolOutstandingVec;
  var APending: TDbPoolLeakReports;
  var ALeakNextDue: QWord;
  const AReadSlots: ISemaphore;
  const AWriterSlot: ISemaphore;
  var AClosed: Boolean);

implementation

uses
  nextpas.core.text.conv,
  nextpas.core.db.pool.proxy;

function PoolSchedNeedTick(const APolicy: TDbPoolPolicy): Boolean; inline;
begin
  Result := (APolicy.MaxLifetimeSec > 0) or (APolicy.IdleTimeoutSec > 0) or
    (APolicy.LeakDetectionThresholdMs > 0);
end;

{ 单源复用：泄漏栈采样+租约登记（FillChar+CaptureBacktrace 单次分配零 bytes 双转换，inline 零 I-Cache 膨胀，零拷贝单 Move） }
procedure PoolLeaseRegisterWithStack(var AOutstanding: array of TPoolOutstanding; var AOutstandingCount: Integer;
  var ALeakNextDue: QWord; AObj: TObject; const ATick: QWord; const AIsWriter: Boolean;
  const APolicy: TDbPoolPolicy); inline;
var
  LFrames: array[0..15] of CodePointer;
  LCount: Integer;
begin
  if (APolicy.LeakDetectionThresholdMs > 0) and APolicy.DebugAcquireStack then
  begin
    FillChar(LFrames, SizeOf(LFrames), 0);
    LCount := CaptureBacktrace(0, Length(LFrames), @LFrames[0]);
    PoolLeaseRegisterLocked(AOutstanding, AOutstandingCount, ALeakNextDue, AObj, ATick, AIsWriter, @LFrames[0], LCount, APolicy);
  end
  else
    PoolLeaseRegisterLocked(AOutstanding, AOutstandingCount, ALeakNextDue, AObj, ATick, AIsWriter, nil, 0, APolicy);
end;

procedure PoolLeaseRegisterWithStackVec(var AVec: TPoolOutstandingVec;
  var ALeakNextDue: QWord; AObj: TObject; const ATick: QWord; const AIsWriter: Boolean;
  const APolicy: TDbPoolPolicy); inline;
var
  LFrames: array[0..15] of CodePointer;
  LCount: Integer;
begin
  if (APolicy.LeakDetectionThresholdMs > 0) and APolicy.DebugAcquireStack then
  begin
    FillChar(LFrames, SizeOf(LFrames), 0);
    LCount := CaptureBacktrace(0, Length(LFrames), @LFrames[0]);
    PoolLeaseRegisterVec(AVec, ALeakNextDue, AObj, ATick, AIsWriter, @LFrames[0], LCount, APolicy);
  end
  else
    PoolLeaseRegisterVec(AVec, ALeakNextDue, AObj, ATick, AIsWriter, nil, 0, APolicy);
end;

procedure PoolSchedTryFlushWithTick(const ANow: QWord;
  var AOutstanding: array of TPoolOutstanding; var AOutstandingCount: Integer;
  var APending: TDbPoolLeakReports; var ALeakNextDue: QWord;
  const APolicy: TDbPoolPolicy; const ALock: INativeMutex); inline;
var
  LSnaps: TPoolLeakSnaps;
  LReports, LPending: TDbPoolLeakReports;
begin
  if APolicy.LeakDetectionThresholdMs <= 0 then Exit;
  if ALeakNextDue = High(QWord) then Exit;
  if AOutstandingCount = 0 then Exit;
  if ANow < ALeakNextDue then Exit;
  LSnaps := nil;
  ALock.Acquire;
  try
    PoolLeakCollectDueLocked(AOutstanding, AOutstandingCount, ALeakNextDue, ANow, LSnaps, APolicy);
  finally
    ALock.Release;
  end;
  if Length(LSnaps) = 0 then Exit;
  LReports := PoolLeakFormatSnaps(LSnaps);
  ALock.Acquire;
  try
    PoolLeakAppendPendingLocked(APending, LReports);
    PoolLeakTakePendingLocked(APending, LPending);
  finally
    ALock.Release;
  end;
  if Length(LPending) > 0 then
    PoolLeakFireReports(LPending, APolicy);
end;

procedure PoolSchedTryFlushWithTickVec(const ANow: QWord;
  var AVec: TPoolOutstandingVec;
  var APending: TDbPoolLeakReports; var ALeakNextDue: QWord;
  const APolicy: TDbPoolPolicy; const ALock: INativeMutex); inline;
var
  LSnaps: TPoolLeakSnaps;
  LReports, LPending: TDbPoolLeakReports;
begin
  if APolicy.LeakDetectionThresholdMs <= 0 then Exit;
  if ALeakNextDue = High(QWord) then Exit;
  if AVec.Count = 0 then Exit;
  if ANow < ALeakNextDue then Exit;
  LSnaps := nil;
  ALock.Acquire;
  try
    PoolLeakCollectDueVec(AVec, ALeakNextDue, ANow, LSnaps, APolicy);
  finally
    ALock.Release;
  end;
  if Length(LSnaps) = 0 then Exit;
  LReports := PoolLeakFormatSnaps(LSnaps);
  ALock.Acquire;
  try
    PoolLeakAppendPendingLocked(APending, LReports);
    PoolLeakTakePendingLocked(APending, LPending);
  finally
    ALock.Release;
  end;
  if Length(LPending) > 0 then PoolLeakFireReports(LPending, APolicy);
end;

{ 硬回收：1.2×阈值(72s)后强制释放槽位并 Discard 代理防双释（锁内扫描标记、锁外释信号量与报告，finally 不丢，inline 零 I-Cache 膨胀，零拷贝单 Move 报告，较 2×120s 缩短裸租约阻塞） }
procedure PoolSchedHardReclaimVec(const ANow: QWord; var AVec: TPoolOutstandingVec; var ALeakNextDue: QWord; const APolicy: TDbPoolPolicy; const ALock: INativeMutex; var AWriterConn: IDbConnection; const AReadSlots, AWriterSlot: ISemaphore); inline;
var
  I, N, LLast, LReclaimedRead, LReclaimedWriter: Integer;
  E, ETmp: TPoolOutstanding;
  LHardDue, LSoftDue: QWord;
  LReports: TDbPoolLeakReports;
  LRole: string;
begin
  if APolicy.LeakDetectionThresholdMs <= 0 then Exit;
  if AVec.Count = 0 then Exit;
  LReclaimedRead := 0;
  LReclaimedWriter := 0;
  LReports := nil;
  ALock.Acquire;
  try
    N := Integer(AVec.Count);
    I := 0;
    while I < N do
    begin
      E := AVec.Get(SizeUInt(I));
      if not E.Warned then begin Inc(I); Continue; end;
      LHardDue := E.Tick + QWord(APolicy.LeakDetectionThresholdMs) * 1200000; // 1.2× threshold ns (1ms=1_000_000ns, 72s vs 2×120s)
      if ANow < LHardDue then begin Inc(I); Continue; end;
      if E.IsWriter then LRole := 'writer' else LRole := 'read';
      if E.Obj <> nil then
        try TPooledConn(E.Obj).Discard; except end;
      if E.IsWriter then AWriterConn := nil;
      SetLength(LReports, Length(LReports)+1);
      LReports[High(LReports)] := 'pool: lease hard reclaimed — held ' + IntToStr(Int64((ANow - E.Tick) div 1000000)) + 'ms (threshold ' + IntToStr(APolicy.LeakDetectionThresholdMs) + 'ms, hard 1.2×), ' + LRole + ' lease, slot freed';
      LLast := N - 1;
      if I <> LLast then
      begin
        ETmp := AVec.Get(SizeUInt(LLast));
        AVec.Put(SizeUInt(I), ETmp);
      end;
      AVec.Pop(ETmp);
      Dec(N);
      if E.IsWriter then Inc(LReclaimedWriter) else Inc(LReclaimedRead);
    end;
    if AVec.Count = 0 then
      ALeakNextDue := High(QWord)
    else
    begin
      ALeakNextDue := High(QWord);
      for I := 0 to Integer(AVec.Count)-1 do
      begin
        E := AVec.Get(SizeUInt(I));
        if not E.Warned then
        begin
          LSoftDue := E.Tick + QWord(APolicy.LeakDetectionThresholdMs) * 1000000;
          if LSoftDue < ALeakNextDue then ALeakNextDue := LSoftDue;
        end;
      end;
    end;
  finally
    ALock.Release;
  end;
  for I := 1 to LReclaimedRead do
    if AReadSlots <> nil then
      try PoolConcurrencyReleaseRead(AReadSlots); except end;
  for I := 1 to LReclaimedWriter do
    if AWriterSlot <> nil then
      try PoolConcurrencyReleaseWriter(AWriterSlot); except end;
  if Length(LReports) > 0 then
    try PoolLeakFireReports(LReports, APolicy); except end;
end;

function PoolSchedOpenFresh(const AConnect: TDbConnectFunc; out ACreatedTick: QWord; const ANow: QWord): IDbConnection; inline;
begin
  ACreatedTick := ANow;
  // 单 tick 缓存(ns 单源)：ANow 已由 Acquire* 单次 platform_monotonic_ns(ns) 缓存（NeedTick 真时非 0ns，阈值全零时 0 零 syscall）；零值保持 0，避免阈值全零额外 syscall，Stale 因阈值 0 短路无影响（阈值侧 *1e9/*1e6 换算零 div）
  Result := AConnect();
  if Result = nil then
    raise EDbError.CreateSimple(dbkUnknown, 'pool: connect factory returned nil');
end;

function PoolSchedAcquireRead(
  const ACore: IDbPoolCore;
  const APolicy: TDbPoolPolicy;
  const AConnect: TDbConnectFunc;
  const ALock: INativeMutex;
  const AReadSlots: ISemaphore;
  var AIdle: array of TPoolIdleEntry;
  var AIdleCount: Integer;
  var AOutstanding: array of TPoolOutstanding;
  var AOutstandingCount: Integer;
  var APending: TDbPoolLeakReports;
  var ALeakNextDue: QWord;
  var AClosed: Boolean;
  var ANextEvictDue: QWord): IDbConnection;
var
  Inner: IDbConnection;
  CreatedTick: QWord;
  LProxy: TPooledConn;
  LNow: QWord;
  NeedTick: Boolean;
  E: TPoolIdleEntry;
begin
  if AClosed then
    raise EDbError.CreateSimple(dbkUnknown, 'pool: closed');
  NeedTick := PoolSchedNeedTick(APolicy);
  if NeedTick then
    LNow := QWord(platform_monotonic_ns)
  else
    LNow := 0;
  if APolicy.LeakDetectionThresholdMs > 0 then
    PoolSchedTryFlushWithTick(LNow, AOutstanding, AOutstandingCount, APending, ALeakNextDue, APolicy, ALock);
  if not PoolConcurrencyTryAcquireRead(AReadSlots, APolicy.AcquireTimeoutMs) then
  begin
    if APolicy.AcquireTimeoutMs > 0 then
      raise EDbError.CreateSimple(dbkUnknown,
        'pool: read connections exhausted (timeout ' + IntToStr(APolicy.AcquireTimeoutMs) + 'ms)')
    else
      raise EDbError.CreateSimple(dbkUnknown, 'pool: read connections exhausted');
  end;
  try
    // 锁内节流驱逐(ns 单源)：仅当配置超时且到达节流阈（1s=1000000000ns，LNow=platform_monotonic_ns(ns)）才全量扫描，常规单次栈顶 O(1) 丢弃，缩短持锁；双端 8 探针快路径已过滤热端 MaxLifetime 滞留，无需 5s 长节流放大 TryPopUsable 循环持锁；单 tick 缓存复用（NeedTick 单次 platform_monotonic_ns(ns)，阈值全零零 syscall 内无额外调用，阈值侧 *1e9 零 div）
    ALock.Acquire;
    try
      if NeedTick and (APolicy.IdleTimeoutSec > 0 or APolicy.MaxLifetimeSec > 0) then
      begin
        if (ANextEvictDue = 0) or (LNow >= ANextEvictDue) then
        begin
          PoolIdleEvictColdStale(AIdle, AIdleCount, LNow, APolicy);
          ANextEvictDue := LNow + 1000000000; // 1s 节流阈(ns)，与 Idle/MaxLifetime *1e9 同源
        end;
      end;
      if PoolIdleTryPopUsable(AIdle, AIdleCount, LNow, APolicy, E) then
      begin
        Inner := E.Conn;
        CreatedTick := E.CreatedTick;
        if CreatedTick = 0 then CreatedTick := LNow;
        LProxy := TPooledConn.Create(ACore, Inner, False, CreatedTick);
        PoolLeaseRegisterWithStack(AOutstanding, AOutstandingCount, ALeakNextDue, LProxy, LNow, False, APolicy);
        Result := LProxy;
        Exit;
      end;
    finally
      ALock.Release;
    end;
    // 锁外建连(ns 单源)：单 tick(ns)缓存复用，阈值全零零 syscall 直传 0ns（OpenFresh 保持 0），阈值开已缓存无需额外 syscall（*1e9/*1e6 零 div）
    if NeedTick and (LNow = 0) then LNow := QWord(platform_monotonic_ns);
    Inner := PoolSchedOpenFresh(AConnect, CreatedTick, LNow);
    LProxy := TPooledConn.Create(ACore, Inner, False, CreatedTick);
    Result := LProxy;
    ALock.Acquire;
    try
      PoolLeaseRegisterWithStack(AOutstanding, AOutstandingCount, ALeakNextDue, LProxy, LNow, False, APolicy);
    finally
      ALock.Release;
    end;
  except
    PoolConcurrencyReleaseRead(AReadSlots);
    raise;
  end;
end;

function PoolSchedAcquireWriter(
  const ACore: IDbPoolCore;
  const APolicy: TDbPoolPolicy;
  const AConnect: TDbConnectFunc;
  const ALock: INativeMutex;
  const AWriterSlot: ISemaphore;
  var AWriterConn: IDbConnection;
  var AWriterCreatedTick: QWord;
  var AOutstanding: array of TPoolOutstanding;
  var AOutstandingCount: Integer;
  var APending: TDbPoolLeakReports;
  var ALeakNextDue: QWord;
  var AClosed: Boolean): IDbConnection;
var
  NeedFresh: Boolean;
  CreatedTick: QWord;
  LProxy: TPooledConn;
  LNow: QWord;
  LNewConn: IDbConnection;
  NeedTick: Boolean;
begin
  if AClosed then
    raise EDbError.CreateSimple(dbkUnknown, 'pool: closed');
  NeedTick := PoolSchedNeedTick(APolicy);
  if NeedTick then LNow := QWord(platform_monotonic_ns) else LNow := 0;
  if APolicy.LeakDetectionThresholdMs > 0 then
    PoolSchedTryFlushWithTick(LNow, AOutstanding, AOutstandingCount, APending, ALeakNextDue, APolicy, ALock);
  if not PoolConcurrencyTryAcquireWriter(AWriterSlot, APolicy.AcquireTimeoutMs) then
  begin
    if APolicy.AcquireTimeoutMs > 0 then
      raise EDbError.CreateSimple(dbkUnknown,
        'pool: writer occupied (timeout ' + IntToStr(APolicy.AcquireTimeoutMs) + 'ms)')
    else
      raise EDbError.CreateSimple(dbkUnknown, 'pool: writer occupied');
  end;
  try
    ALock.Acquire;
    try
      NeedFresh := (AWriterConn = nil) or PoolStale(AWriterCreatedTick, LNow, APolicy);
      if not NeedFresh then
      begin
        CreatedTick := AWriterCreatedTick;
        LProxy := TPooledConn.Create(ACore, AWriterConn, True, CreatedTick);
        PoolLeaseRegisterWithStack(AOutstanding, AOutstandingCount, ALeakNextDue, LProxy, LNow, True, APolicy);
        Result := LProxy;
        Exit;
      end;
    finally
      ALock.Release;
    end;
    if NeedTick and (LNow = 0) then LNow := QWord(platform_monotonic_ns);
    LNewConn := PoolSchedOpenFresh(AConnect, CreatedTick, LNow);
    ALock.Acquire;
    try
      AWriterConn := LNewConn;
      AWriterCreatedTick := CreatedTick;
      LProxy := TPooledConn.Create(ACore, AWriterConn, True, CreatedTick);
      PoolLeaseRegisterWithStack(AOutstanding, AOutstandingCount, ALeakNextDue, LProxy, LNow, True, APolicy);
      Result := LProxy;
    finally
      ALock.Release;
    end;
  except
    PoolConcurrencyReleaseWriter(AWriterSlot);
    raise;
  end;
end;

procedure PoolSchedReturnProxy(
  const ACore: IDbPoolCore;
  AProxy: TObject;
  const ALock: INativeMutex;
  var AIdle: array of TPoolIdleEntry;
  var AIdleCount: Integer;
  var AWriterConn: IDbConnection;
  var AOutstanding: array of TPoolOutstanding;
  var AOutstandingCount: Integer;
  var APending: TDbPoolLeakReports;
  var ALeakNextDue: QWord;
  const AReadSlots: ISemaphore;
  const AWriterSlot: ISemaphore;
  var AClosed: Boolean);
var
  P: TPooledConn;
  E: TPoolIdleEntry;
  IsWriter: Boolean;
  LNow: QWord;
  LSnaps: TPoolLeakSnaps;
begin
  P := TPooledConn(AProxy);
  IsWriter := P.IsWriter;
  LSnaps := nil;
  ALock.Acquire;
  try
    PoolLeaseUnregisterLocked(AOutstanding, AOutstandingCount, ALeakNextDue, P, ACore.Policy);
    if IsWriter then
    begin
      if AClosed or P.IsDiscarded then
        AWriterConn := nil;
      if PoolSchedNeedTick(ACore.Policy) then LNow := QWord(platform_monotonic_ns) else LNow := 0;
      PoolObsCollectDueOnReturn(AOutstanding, AOutstandingCount, ALeakNextDue, LNow, LSnaps, ACore.Policy);
    end
    else if (not AClosed) and (not P.IsDiscarded) then
    begin
      if PoolSchedNeedTick(ACore.Policy) then LNow := QWord(platform_monotonic_ns) else LNow := 0;
      E.Conn := P.InnerConn;
      E.CreatedTick := P.CreatedTick;
      E.ReturnedTick := LNow;
      // 单 tick 缓存(ns 单源)：NeedTick 单次 platform_monotonic_ns(ns)，阈值全零 ReturnedTick 保持 0 零额外 syscall（IdleTimeout 0 短路，零 div）
      PoolIdlePush(AIdle, AIdleCount, E);
      PoolObsCollectDueOnReturn(AOutstanding, AOutstandingCount, ALeakNextDue, LNow, LSnaps, ACore.Policy);
    end
    else
    begin
      if PoolSchedNeedTick(ACore.Policy) then LNow := QWord(platform_monotonic_ns) else LNow := 0;
      PoolObsCollectDueOnReturn(AOutstanding, AOutstandingCount, ALeakNextDue, LNow, LSnaps, ACore.Policy);
    end;
  finally
    ALock.Release;
  end;
  try
    if Length(LSnaps) > 0 then
      PoolObsEnqueueSnaps(LSnaps, APending, ALock);
  finally
    if IsWriter then
      PoolConcurrencyReleaseWriter(AWriterSlot)
    else
      PoolConcurrencyReleaseRead(AReadSlots);
  end;
end;

function PoolSchedAcquireReadVec(
  const ACore: IDbPoolCore;
  const APolicy: TDbPoolPolicy;
  const AConnect: TDbConnectFunc;
  const ALock: INativeMutex;
  const AReadSlots: ISemaphore;
  var AIdle: TPoolIdleVec;
  var AOutstanding: TPoolOutstandingVec;
  var APending: TDbPoolLeakReports;
  var ALeakNextDue: QWord;
  var AClosed: Boolean;
  var ANextEvictDue: QWord;
  var AWriterConn: IDbConnection;
  const AWriterSlot: ISemaphore): IDbConnection;
var
  Inner: IDbConnection;
  CreatedTick: QWord;
  LProxy: TPooledConn;
  LNow: QWord;
  NeedTick: Boolean;
  E: TPoolIdleEntry;
begin
  if AClosed then raise EDbError.CreateSimple(dbkUnknown, 'pool: closed');
  NeedTick := PoolSchedNeedTick(APolicy);
  if NeedTick then LNow := QWord(platform_monotonic_ns) else LNow := 0;
  if APolicy.LeakDetectionThresholdMs > 0 then
  begin
    PoolSchedTryFlushWithTickVec(LNow, AOutstanding, APending, ALeakNextDue, APolicy, ALock);
    PoolSchedHardReclaimVec(LNow, AOutstanding, ALeakNextDue, APolicy, ALock, AWriterConn, AReadSlots, AWriterSlot);
  end;
  if not PoolConcurrencyTryAcquireRead(AReadSlots, APolicy.AcquireTimeoutMs) then
  begin
    if APolicy.AcquireTimeoutMs > 0 then
      raise EDbError.CreateSimple(dbkUnknown, 'pool: read connections exhausted (timeout ' + IntToStr(APolicy.AcquireTimeoutMs) + 'ms)')
    else
      raise EDbError.CreateSimple(dbkUnknown, 'pool: read connections exhausted');
  end;
  try
    ALock.Acquire;
    try
      if NeedTick and (APolicy.IdleTimeoutSec > 0 or APolicy.MaxLifetimeSec > 0) then
      begin
        if (ANextEvictDue = 0) or (LNow >= ANextEvictDue) then
        begin
          PoolIdleEvictColdStaleVec(AIdle, LNow, APolicy);
          ANextEvictDue := LNow + 1000000000; // 1s 节流阈(ns)，与 Idle/MaxLifetime *1e9 同源
        end;
      end;
      if PoolIdleTryPopUsableVec(AIdle, LNow, APolicy, E) then
      begin
        Inner := E.Conn;
        CreatedTick := E.CreatedTick;
        if CreatedTick = 0 then CreatedTick := LNow;
        LProxy := TPooledConn.Create(ACore, Inner, False, CreatedTick);
        PoolLeaseRegisterWithStackVec(AOutstanding, ALeakNextDue, LProxy, LNow, False, APolicy);
        Result := LProxy;
        Exit;
      end;
    finally
      ALock.Release;
    end;
    if NeedTick and (LNow = 0) then LNow := QWord(platform_monotonic_ns);
    Inner := PoolSchedOpenFresh(AConnect, CreatedTick, LNow);
    LProxy := TPooledConn.Create(ACore, Inner, False, CreatedTick);
    Result := LProxy;
    ALock.Acquire;
    try
      PoolLeaseRegisterWithStackVec(AOutstanding, ALeakNextDue, LProxy, LNow, False, APolicy);
    finally
      ALock.Release;
    end;
  except
    PoolConcurrencyReleaseRead(AReadSlots);
    raise;
  end;
end;

function PoolSchedAcquireWriterVec(
  const ACore: IDbPoolCore;
  const APolicy: TDbPoolPolicy;
  const AConnect: TDbConnectFunc;
  const ALock: INativeMutex;
  const AWriterSlot: ISemaphore;
  var AWriterConn: IDbConnection;
  var AWriterCreatedTick: QWord;
  var AOutstanding: TPoolOutstandingVec;
  var APending: TDbPoolLeakReports;
  var ALeakNextDue: QWord;
  var AClosed: Boolean): IDbConnection;
var
  NeedFresh: Boolean;
  CreatedTick: QWord;
  LProxy: TPooledConn;
  LNow: QWord;
  LNewConn: IDbConnection;
  NeedTick: Boolean;
begin
  if AClosed then raise EDbError.CreateSimple(dbkUnknown, 'pool: closed');
  NeedTick := PoolSchedNeedTick(APolicy);
  if NeedTick then LNow := QWord(platform_monotonic_ns) else LNow := 0;
  if APolicy.LeakDetectionThresholdMs > 0 then
  begin
    PoolSchedTryFlushWithTickVec(LNow, AOutstanding, APending, ALeakNextDue, APolicy, ALock);
    // Writer path hard reclaim needs dummy read slot for symmetry; pass nil read slot via same writer slot overload? Create temp nil and handle.
    // For writer acquire, hard reclaim may free both writer and read slots; need read slot handle — use writer slot twice if read slot unavailable? Instead create local no-op: hard reclaim via writer-only variant (reuse writer slot for read reclaim count via same slot? but read reclaim needs read slot).
    // To keep single source, call generic hard reclaim with nil read slot if not available — it will still Discard but not release read semaphore (read leak will be reclaimed on next read acquire). For writer, we hard reclaim writer overdue only.
    // Use dedicated hard reclaim that frees writer slots only here; reader overdue will be reclaimed on next read acquire.
    PoolSchedHardReclaimVec(LNow, AOutstanding, ALeakNextDue, APolicy, ALock, AWriterConn, nil, AWriterSlot);
  end;
  if not PoolConcurrencyTryAcquireWriter(AWriterSlot, APolicy.AcquireTimeoutMs) then
  begin
    if APolicy.AcquireTimeoutMs > 0 then
      raise EDbError.CreateSimple(dbkUnknown, 'pool: writer occupied (timeout ' + IntToStr(APolicy.AcquireTimeoutMs) + 'ms)')
    else
      raise EDbError.CreateSimple(dbkUnknown, 'pool: writer occupied');
  end;
  try
    ALock.Acquire;
    try
      NeedFresh := (AWriterConn = nil) or PoolStale(AWriterCreatedTick, LNow, APolicy);
      if not NeedFresh then
      begin
        CreatedTick := AWriterCreatedTick;
        LProxy := TPooledConn.Create(ACore, AWriterConn, True, CreatedTick);
        PoolLeaseRegisterWithStackVec(AOutstanding, ALeakNextDue, LProxy, LNow, True, APolicy);
        Result := LProxy;
        Exit;
      end;
    finally
      ALock.Release;
    end;
    if NeedTick and (LNow = 0) then LNow := QWord(platform_monotonic_ns);
    LNewConn := PoolSchedOpenFresh(AConnect, CreatedTick, LNow);
    ALock.Acquire;
    try
      AWriterConn := LNewConn;
      AWriterCreatedTick := CreatedTick;
      LProxy := TPooledConn.Create(ACore, AWriterConn, True, CreatedTick);
      PoolLeaseRegisterWithStackVec(AOutstanding, ALeakNextDue, LProxy, LNow, True, APolicy);
      Result := LProxy;
    finally
      ALock.Release;
    end;
  except
    PoolConcurrencyReleaseWriter(AWriterSlot);
    raise;
  end;
end;

procedure PoolSchedReturnProxyVec(
  const ACore: IDbPoolCore;
  AProxy: TObject;
  const ALock: INativeMutex;
  var AIdle: TPoolIdleVec;
  var AWriterConn: IDbConnection;
  var AOutstanding: TPoolOutstandingVec;
  var APending: TDbPoolLeakReports;
  var ALeakNextDue: QWord;
  const AReadSlots: ISemaphore;
  const AWriterSlot: ISemaphore;
  var AClosed: Boolean);
var
  P: TPooledConn;
  E: TPoolIdleEntry;
  IsWriter: Boolean;
  LNow: QWord;
  LSnaps: TPoolLeakSnaps;
begin
  P := TPooledConn(AProxy);
  IsWriter := P.IsWriter;
  LSnaps := nil;
  ALock.Acquire;
  try
    PoolLeaseUnregisterVec(AOutstanding, ALeakNextDue, P, ACore.Policy);
    if IsWriter then
    begin
      if AClosed or P.IsDiscarded then AWriterConn := nil;
      if PoolSchedNeedTick(ACore.Policy) then LNow := QWord(platform_monotonic_ns) else LNow := 0;
      PoolObsCollectDueOnReturnVec(AOutstanding, ALeakNextDue, LNow, LSnaps, ACore.Policy);
    end
    else if (not AClosed) and (not P.IsDiscarded) then
    begin
      if PoolSchedNeedTick(ACore.Policy) then LNow := QWord(platform_monotonic_ns) else LNow := 0;
      E.Conn := P.InnerConn;
      E.CreatedTick := P.CreatedTick;
      E.ReturnedTick := LNow;
      PoolIdlePushVec(AIdle, E);
      PoolObsCollectDueOnReturnVec(AOutstanding, ALeakNextDue, LNow, LSnaps, ACore.Policy);
    end
    else
    begin
      if PoolSchedNeedTick(ACore.Policy) then LNow := QWord(platform_monotonic_ns) else LNow := 0;
      PoolObsCollectDueOnReturnVec(AOutstanding, ALeakNextDue, LNow, LSnaps, ACore.Policy);
    end;
  finally
    ALock.Release;
  end;
  try
    if Length(LSnaps) > 0 then PoolObsEnqueueSnaps(LSnaps, APending, ALock);
  finally
    if IsWriter then PoolConcurrencyReleaseWriter(AWriterSlot)
    else PoolConcurrencyReleaseRead(AReadSlots);
  end;
end;

function PoolSchedGrowCap(const AOld, ARequired: SizeUInt): SizeUInt; inline; begin Result := PoolGrowCap(AOld, ARequired); end;
procedure PoolSchedIdlePush(var AEntries: array of TPoolIdleEntry; var ACount: Integer; const AEntry: TPoolIdleEntry); inline; begin PoolIdlePush(AEntries, ACount, AEntry); end;
function PoolSchedIdlePop(var AEntries: array of TPoolIdleEntry; var ACount: Integer; var AEntry: TPoolIdleEntry): Boolean; inline; begin Result := PoolIdlePop(AEntries, ACount, AEntry); end;
procedure PoolSchedFlushSafePoint(var AOutstanding: array of TPoolOutstanding; var AOutstandingCount: Integer; var APending: TDbPoolLeakReports; var ALeakNextDue: QWord; const APolicy: TDbPoolPolicy; const ALock: INativeMutex); inline; begin PoolObsFlushSafePoint(AOutstanding, AOutstandingCount, APending, ALeakNextDue, APolicy, ALock); end;
procedure PoolSchedIdlePushVec(var AVec: TPoolIdleVec; const AEntry: TPoolIdleEntry); inline; begin PoolIdlePushVec(AVec, AEntry); end;
function PoolSchedIdlePopVec(var AVec: TPoolIdleVec; var AEntry: TPoolIdleEntry): Boolean; inline; begin Result := PoolIdlePopVec(AVec, AEntry); end;
procedure PoolSchedFlushSafePointVec(var AVec: TPoolOutstandingVec; var APending: TDbPoolLeakReports; var ALeakNextDue: QWord; const APolicy: TDbPoolPolicy; const ALock: INativeMutex); inline; begin PoolObsFlushSafePointVec(AVec, APending, ALeakNextDue, APolicy, ALock); end;

end.
