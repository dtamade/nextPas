unit nextpas.core.db.tx;

{** @desc 泛化事务助手：对任意实现 IDbTxControl 的统一连接提供
       WithTransaction。savepoint 混合模型（基线 §5.1，V2-S2）：

       - 成功自动提交；异常自动回滚并重抛原异常。
       - 深度 1（最外层）：真 BEGIN / COMMIT / ROLLBACK 事务边界。
       - 深度 >= 2（内层）：SAVEPOINT np_db_sp_<N> 包裹；成功 RELEASE
         并入父事务；失败 ROLLBACK TO 真正只撤销内层写入后 RELEASE，
         外层可捕获异常继续（部分提交语义）。外层整体回滚时内层
         savepoint 随之消亡。
       - 嵌套要求连接实现 IDbSavepointControl（两内置后端都实现）；
         不支持时嵌套调用 fail-fast 抛错——绝不静默退化为计数并入
         （那会把内层写入悬在外层事务里，v1 痛点）。
       - 手动 BeginTxn/CommitTxn/RollbackTxn 保持 v1 计数语义不变：
         内层 Begin 加深、内层 Commit 只降计数、任意深度 Rollback
         回滚整个事务。两个入口的分工在 CONTRACT.md 写清。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.db.base,
  nextpas.core.db.intf;

type
  TDbTxProc = reference to procedure;

  { 瞬时错误判定（V3-B5）。nil = DbRetryableDefault 缺省段位。 }
  TDbRetryShouldRetry = reference to function(const AE: EDbError): Boolean;

  { 重试策略：词汇对齐 nextpas.core.async.retry 的 TAsyncRetryOptions
    （同步包装，不依赖事件循环）。第 n 次失败后的延迟 =
    min(BaseDelayMs * BackoffFactor^(n-1), MaxDelayMs)。
    MaxRetries = 额外重试次数（0 = 失败即抛，总尝试 1 次）。 }
  TDbRetryPolicy = record
    MaxRetries: Integer;
    BaseDelayMs: Integer;
    MaxDelayMs: Integer;
    BackoffFactor: Integer;
    ShouldRetry: TDbRetryShouldRetry;
    class function Default: TDbRetryPolicy; static;
  end;

  { 原子执行 AProc：成功自动提交；异常自动回滚并重抛。嵌套安全
    （深度 >= 2 走 savepoint，见单元头注释）。 }
  procedure WithTransaction(const AConn: IDbConnection; const AProc: TDbTxProc);

  { 缺省瞬时段位：死锁/序列化冲突（decTransaction）与 sqlite 锁竞争
    （decTimeout 且 BUSY/LOCKED 码位）可重试。连接断亡需要重连
    （池的领域）、pg 语句超时意味着查询真的慢——两者不静默重试。 }
  function DbRetryableDefault(const AE: EDbError): Boolean;

  { 原子执行 + 瞬时错误自动重试（V3-B5）：仅整事务重跑，绝不部分
    重试——幂等责任在回调（同一副作用可能被执行多次），文档纪律。
    非 EDbError 异常（业务异常）不重试直接穿出。 }
  procedure WithTransactionRetry(const AConn: IDbConnection; const AProc: TDbTxProc); overload;
  procedure WithTransactionRetry(const AConn: IDbConnection; const AProc: TDbTxProc;
    const APolicy: TDbRetryPolicy); overload;

implementation

uses
  SysUtils,
  nextpas.core.db.err,
  nextpas.core.time.base,
  nextpas.core.time.sleep;

{ 固定格式 savepoint 名：<depth> = 即将进入的 WithTransaction 层级。
  兄弟层级顺序执行不重叠，同名复用安全；SQL 标准允许 SAVEPOINT 重名
  叠放且 ROLLBACK TO/RELEASE 总是作用于最近一个。格式稳定便于日志与
  服务端 pg_stat_activity 排障识别。 }
function SavepointNameForDepth(const ADepth: Integer): string;
begin
  Result := 'np_db_sp_' + IntToStr(ADepth);
end;

procedure WithTransaction(const AConn: IDbConnection; const AProc: TDbTxProc);
var
  Tx: IDbTxControl;
  Sp: IDbSavepointControl;
  LPrev: Integer;
begin
  if AConn = nil then
    raise EDbError.CreateSimple(dbkUnknown,
      'WithTransaction on a nil connection');
  if AProc = nil then
    raise EDbError.CreateSimple(AConn.Kind, 'nil transaction callback');
  if AConn.QueryInterface(IDbTxControl, Tx) <> 0 then
    raise EDbError.CreateSimple(AConn.Kind,
      'backend does not support transaction control');

  LPrev := Tx.TxDepth;
  if LPrev = 0 then
    Tx.BeginTxn(False)
  else
  begin
    { 嵌套 = savepoint 或拒绝，绝不静默计数并入 }
    if AConn.QueryInterface(IDbSavepointControl, Sp) <> 0 then
      raise EDbError.CreateSimple(AConn.Kind,
        'nested transaction requires savepoint support');
    Sp.Savepoint(SavepointNameForDepth(LPrev + 1));
  end;
  try
    AProc();
    if LPrev = 0 then
      Tx.CommitTxn                       { 最外层：真 COMMIT }
    else
      Sp.ReleaseTo(SavepointNameForDepth(LPrev + 1));  { 内层成功：并入父事务 }
  except
    if LPrev = 0 then
    begin
      { 外层失败：整事务回滚。InTransaction 守卫避免连接已断时
        重复回滚替换原异常。 }
      if Tx.InTransaction then
        Tx.RollbackTxn;
    end
    else
    begin
      { 内层失败：只撤销内层写入（ROLLBACK TO 销毁其后建立的
        更深 savepoint），RELEASE 释放本层保存点。清理自身失败
        （连接级灾难）会替换原异常——此时原异常已无修复意义。 }
      Sp.RollbackTo(SavepointNameForDepth(LPrev + 1));
      Sp.ReleaseTo(SavepointNameForDepth(LPrev + 1));
    end;
    raise;
  end;
end;

{ ===== V3-B5 瞬时错误重试 ===== }

class function TDbRetryPolicy.Default: TDbRetryPolicy;
begin
  Result.MaxRetries := 3;
  Result.BaseDelayMs := 50;
  Result.MaxDelayMs := 2000;
  Result.BackoffFactor := 2;
  Result.ShouldRetry := nil;               { = DbRetryableDefault }
end;

function DbRetryableDefault(const AE: EDbError): Boolean;
begin
  if AE = nil then
    Exit(False);
  { 死锁（pg 40P01）与序列化失败（40001）天然瞬态：整事务重跑即可 }
  if AE.Category = decTransaction then
    Exit(True);
  { sqlite 锁竞争归一为 decTimeout，但语义是"等一会就好"，与 pg 语句
    超时（查询真的慢，重跑还会超时）同栏不同命——按后端码位细分。 }
  if (AE.Backend = dbkSqlite) and (AE.Category = decTimeout) and
     ((AE.BackendCode = DB_SQLITE_BUSY) or
      (AE.BackendCode = DB_SQLITE_LOCKED)) then
    Exit(True);
  Result := False;
end;

procedure WithTransactionRetry(const AConn: IDbConnection; const AProc: TDbTxProc);
begin
  WithTransactionRetry(AConn, AProc, TDbRetryPolicy.Default);
end;

procedure WithTransactionRetry(const AConn: IDbConnection; const AProc: TDbTxProc;
  const APolicy: TDbRetryPolicy);
var
  LFailures: Integer;
  LDelay: Int64;
  I: Integer;
begin
  LFailures := 0;
  while True do
  begin
    try
      WithTransaction(AConn, AProc);       { 每次尝试 = 完整事务重跑 }
      Exit;
    except
      on E: EDbError do
      begin
        Inc(LFailures);
        { 总允许尝试 = 1 + MaxRetries：第 MaxRetries+1 次失败即抛 }
        if LFailures > APolicy.MaxRetries then
          raise;
        if APolicy.ShouldRetry <> nil then
        begin
          if not APolicy.ShouldRetry(E) then
            raise;
        end
        else if not DbRetryableDefault(E) then
          raise;
        { 指数退避：Base * Factor^(第 n 次失败)，封顶 MaxDelay。
          因子 <=1 时退化为固定延迟。 }
        LDelay := APolicy.BaseDelayMs;
        for I := 2 to LFailures do
          LDelay := LDelay * APolicy.BackoffFactor;
        if (APolicy.MaxDelayMs > 0) and (LDelay > APolicy.MaxDelayMs) then
          LDelay := APolicy.MaxDelayMs;
        if LDelay > 0 then
          TSleep.ForDuration(TDuration.FromMilliseconds(LDelay));
      end;
    end;
  end;
end;

end.
