unit nextpas.core.db.pool.obs;

{** @desc db.pool 观测子面（L2 基础设施，CONTRACT §2.7）。
       职责：泄漏报告收集→格式化→积压→安全点冲刷与 Return 路径入账，归属观测子面与 idle/leak 真源正交；
       idle 拥有空闲队列、leak 拥有租约簿记，obs 拥有报告流水线；impl 仅薄委托，锁外回调零重入。
       复用 bytes.ops 单源（BYTES_OPS_SINGLE_SOURCE 单 Move 零拷贝，inline 薄转发零 I-Cache 膨胀）。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.bytes.ops,
  nextpas.core.collections.smallvec,
  nextpas.core.platform.time,
  nextpas.core.sync,
  nextpas.core.db.pool.base,
  nextpas.core.db.pool.leak;



{ 安全点冲刷：扫描到期租约→格式化→积压→锁外回调，锁内零用户代码，inline 薄转发 }
procedure PoolObsFlushSafePoint(var AOutstanding: array of TPoolOutstanding;
  var AOutstandingCount: Integer; var APending: TDbPoolLeakReports;
  var ALeakNextDue: QWord; const APolicy: TDbPoolPolicy;
  const ALock: INativeMutex); inline;

procedure PoolObsFlushSafePointVec(var AVec: TPoolOutstandingVec; var APending: TDbPoolLeakReports;
  var ALeakNextDue: QWord; const APolicy: TDbPoolPolicy;
  const ALock: INativeMutex); inline;

{ Return 路径到期入账：仅扫描入账不触发回调（析构链内绝不碰用户代码），inline 薄转发 }
procedure PoolObsCollectDueOnReturn(var AOutstanding: array of TPoolOutstanding;
  var AOutstandingCount: Integer; var ALeakNextDue: QWord;
  const ANow: QWord; out ASnaps: TPoolLeakSnaps;
  const APolicy: TDbPoolPolicy); inline;
procedure PoolObsCollectDueOnReturnVec(var AVec: TPoolOutstandingVec; var ALeakNextDue: QWord;
  const ANow: QWord; out ASnaps: TPoolLeakSnaps;
  const APolicy: TDbPoolPolicy); inline;

{ 入账后统一排队：格式化→积压，inline 薄转发零拷贝 }
procedure PoolObsEnqueueSnaps(const ASnaps: TPoolLeakSnaps;
  var APending: TDbPoolLeakReports; const ALock: INativeMutex); inline;

{ 积压取走并在锁外触发报告，inline 薄转发 }
procedure PoolObsFirePending(var APending: TDbPoolLeakReports;
  const APolicy: TDbPoolPolicy; const ALock: INativeMutex); inline;

implementation

procedure PoolObsFlushSafePoint(var AOutstanding: array of TPoolOutstanding;
  var AOutstandingCount: Integer; var APending: TDbPoolLeakReports;
  var ALeakNextDue: QWord; const APolicy: TDbPoolPolicy;
  const ALock: INativeMutex);
var
  LNow: QWord;
  LSnaps: TPoolLeakSnaps;
  LReports, LPending: TDbPoolLeakReports;
begin
  if APolicy.LeakDetectionThresholdMs <= 0 then
    Exit;
  if ALeakNextDue = High(QWord) then
    Exit;
  if AOutstandingCount = 0 then
    Exit;
  LNow := QWord(platform_monotonic_ns);
  if LNow < ALeakNextDue then
    Exit;
  LSnaps := nil;
  ALock.Acquire;
  try
    PoolLeakCollectDueLocked(AOutstanding, AOutstandingCount, ALeakNextDue, LNow, LSnaps, APolicy);
  finally
    ALock.Release;
  end;
  if Length(LSnaps) = 0 then
    Exit;
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

procedure PoolObsFlushSafePointVec(var AVec: TPoolOutstandingVec; var APending: TDbPoolLeakReports;
  var ALeakNextDue: QWord; const APolicy: TDbPoolPolicy;
  const ALock: INativeMutex); inline;
var
  LNow: QWord;
  LSnaps: TPoolLeakSnaps;
  LReports, LPending: TDbPoolLeakReports;
begin
  if APolicy.LeakDetectionThresholdMs <= 0 then Exit;
  if ALeakNextDue = High(QWord) then Exit;
  if AVec.Count = 0 then Exit;
  LNow := QWord(platform_monotonic_ns);
  if LNow < ALeakNextDue then Exit;
  LSnaps := nil;
  ALock.Acquire;
  try
    PoolLeakCollectDueVec(AVec, ALeakNextDue, LNow, LSnaps, APolicy);
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

procedure PoolObsCollectDueOnReturn(var AOutstanding: array of TPoolOutstanding;
  var AOutstandingCount: Integer; var ALeakNextDue: QWord;
  const ANow: QWord; out ASnaps: TPoolLeakSnaps;
  const APolicy: TDbPoolPolicy);
begin
  SetLength(ASnaps, 0);
  if APolicy.LeakDetectionThresholdMs <= 0 then
    Exit;
  if ALeakNextDue = High(QWord) then
    Exit;
  if AOutstandingCount = 0 then
    Exit;
  if ANow < ALeakNextDue then
    Exit;
  PoolLeakCollectDueLocked(AOutstanding, AOutstandingCount, ALeakNextDue, ANow, ASnaps, APolicy);
end;

procedure PoolObsCollectDueOnReturnVec(var AVec: TPoolOutstandingVec; var ALeakNextDue: QWord;
  const ANow: QWord; out ASnaps: TPoolLeakSnaps;
  const APolicy: TDbPoolPolicy); inline;
begin
  SetLength(ASnaps, 0);
  if APolicy.LeakDetectionThresholdMs <= 0 then Exit;
  if ALeakNextDue = High(QWord) then Exit;
  if AVec.Count = 0 then Exit;
  if ANow < ALeakNextDue then Exit;
  PoolLeakCollectDueVec(AVec, ALeakNextDue, ANow, ASnaps, APolicy);
end;

procedure PoolObsEnqueueSnaps(const ASnaps: TPoolLeakSnaps;
  var APending: TDbPoolLeakReports; const ALock: INativeMutex);
var
  LReports: TDbPoolLeakReports;
begin
  if Length(ASnaps) = 0 then
    Exit;
  LReports := PoolLeakFormatSnaps(ASnaps);
  ALock.Acquire;
  try
    PoolLeakAppendPendingLocked(APending, LReports);
  finally
    ALock.Release;
  end;
end;

procedure PoolObsFirePending(var APending: TDbPoolLeakReports;
  const APolicy: TDbPoolPolicy; const ALock: INativeMutex);
var
  LPending: TDbPoolLeakReports;
begin
  ALock.Acquire;
  try
    PoolLeakTakePendingLocked(APending, LPending);
  finally
    ALock.Release;
  end;
  if Length(LPending) > 0 then
    PoolLeakFireReports(LPending, APolicy);
end;

end.
