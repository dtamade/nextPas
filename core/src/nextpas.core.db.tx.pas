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
         回滚整个事务。两个入口的分工在 CONTRACT.md 写清。
       - B13 池化租约纪律：捕获式 TDbTxProc 若引用连接，租约随闭包
         存活可迟至外层例程退出（单写者池上即 writer 槽位滞留，heaptrc 未覆盖闭包捕获非堆泄漏，
         source-contract 硬门禁见 core/tests/nextpas.core.db/test_db_factory/check_pool_lease_source_contract.sh）；
         参数化重载 WithTransaction(conn, TDbConnProc) 由框架传连接
         作实参，回调零捕获——池化连接一律优先该形态。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.db.base,
  nextpas.core.db.intf;

type
  TDbTxProc = reference to procedure;

  { 参数化连接回调 owner 已下沉至 db.intf（B13 租约纪律）：本单元 thin alias 单源于 db.intf，L2 pool 直连 intf 零 L2→L3 上向；语义见 db.intf 注记。 }
  TDbConnProc = nextpas.core.db.intf.TDbConnProc;

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
    （深度 >= 2 走 savepoint，见单元头注释）。

    ⚠ 捕获形态（B13 契约注记）：AProc 若捕获了连接本身（常见于
    直接引用外层局部连接变量），该租约引用将存活至闭包销毁——
    实测可迟至外层例程退出，期间单写者池的 writer 槽位被滞留
    （并发超时）；heaptrc 硬门禁未覆盖该误用（闭包捕获非堆泄漏，source-contract 硬门禁见 check_pool_lease_source_contract.sh），
    池化连接一律改用参数化重载（TDbConnProc）：连接由框架作实参
    传入，回调体零捕获、语句结束即归还。 }
  procedure WithTransaction(const AConn: IDbConnection; const AProc: TDbTxProc); overload; deprecated 'pooled: use TDbConnProc overload (B13 lease linger; heaptrc not covering)';

  { 参数化形态（B13）：ABody 经实参拿连接，零捕获。池化租约在
    本调用语句结束即归还，嵌套/顺序借 writer 不受滞留影响。
    事务语义与捕获形态完全一致（提交/回滚/savepoint 共用一实现）。 }
  procedure WithTransaction(const AConn: IDbConnection; const ABody: TDbConnProc); overload;

  { 缺省瞬时段位：死锁/序列化冲突（decTransaction）与 sqlite 锁竞争
    （decTimeout 且 BUSY/LOCKED 码位）可重试。连接断亡需要重连
    （池的领域）、pg 语句超时意味着查询真的慢——两者不静默重试。 }
  function DbRetryableDefault(const AE: EDbError): Boolean;

  { 原子执行 + 瞬时错误自动重试（V3-B5）：仅整事务重跑，绝不部分
    重试——幂等责任在回调（同一副作用可能被执行多次），文档纪律。
    非 EDbError 异常（业务异常）不重试直接穿出。
    捕获形态同 WithTransaction B13 租约滞留 heaptrc 未覆盖 source-contract 硬门禁，池化一律参数化。 }
  procedure WithTransactionRetry(const AConn: IDbConnection; const AProc: TDbTxProc); overload; deprecated 'pooled: use TDbConnProc overload (B13 lease linger; heaptrc not covering)';
  procedure WithTransactionRetry(const AConn: IDbConnection; const AProc: TDbTxProc;
    const APolicy: TDbRetryPolicy); overload; deprecated 'pooled: use TDbConnProc overload (B13 lease linger; heaptrc not covering)';

  { 参数化重试形态（B13）：零捕获纪律 × 瞬时错误整事务重跑，
    池化写租约在重试结束（成功或最终失败）后即归还。 }
  procedure WithTransactionRetry(const AConn: IDbConnection;
    const ABody: TDbConnProc); overload;
  procedure WithTransactionRetry(const AConn: IDbConnection;
    const ABody: TDbConnProc; const APolicy: TDbRetryPolicy); overload;

implementation

uses
  nextpas.core.text.conv,
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

{ 事务帧公共实现（B13）：提交/回滚/savepoint 层级判定只此一份，
  两个 WithTransaction 形态各以零捕获包装委托进来。AStep 在事务
  框架内恰好执行一次。 }
procedure RunTransaction(const AConn: IDbConnection; const AStep: TDbTxProc);
var
  Tx: IDbTxControl;
  Sp: IDbSavepointControl;
  LPrev: Integer;
begin
  if AConn = nil then
    raise EDbError.CreateSimple(dbkUnknown,
      'WithTransaction on a nil connection');
  if AStep = nil then
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
    AStep();
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

procedure WithTransaction(const AConn: IDbConnection; const AProc: TDbTxProc);
begin
  RunTransaction(AConn, AProc);
end;

procedure WithTransaction(const AConn: IDbConnection; const ABody: TDbConnProc);
begin
  { 包装闭包只捕获 ABody（调用方所给参数体），不捕获连接——租约
    随本语句结束归还（B13）。 }
  RunTransaction(AConn,
    procedure
    begin
      ABody(AConn);
    end);
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

procedure WithTransactionRetry(const AConn: IDbConnection;
  const ABody: TDbConnProc);
begin
  WithTransactionRetry(AConn, ABody, TDbRetryPolicy.Default);
end;

procedure WithTransactionRetry(const AConn: IDbConnection;
  const ABody: TDbConnProc; const APolicy: TDbRetryPolicy);
begin
  { 包装闭包生命周期 = 本例程 = 重试循环全程：租约最迟在重试结束
    归还，语义正确（B13）。零参字面量只匹配 TDbTxProc 重载。 }
  WithTransactionRetry(AConn,
    procedure
    begin
      ABody(AConn);
    end, APolicy);
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
