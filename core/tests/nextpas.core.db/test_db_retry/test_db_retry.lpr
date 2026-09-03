program test_db_retry;

{ V3-B5 瞬时错误重试助手契约测试：
    1 首试即成：零重试零延迟
    2 瞬时段位重试后成功：死锁 ×2 后第三次提交；
      整事务重跑语义自证（每次尝试副作用重建，Committed 只记最终一笔）
    3 非 EDbError 业务异常直抛不重试
    4 缺省段位分类纯函数：死锁/序列化/SQLITE BUSY-LOCKED 可重试；
      pg 语句超时、连接断亡、约束违例不可重试
    5 自定义谓词覆盖缺省段位
    6 重试耗尽：总尝试 = 1 + MaxRetries，末次异常原样穿出
    7 退避延迟真实发生（耗时下界断言）
    8 与外层 WithTransaction 组合冒烟（真 sqlite，savepoint 路径）
  全部用例经门面 nextpas.core.db 词汇验证。 }

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.test,
  nextpas.core.base,
  nextpas.core.db,
  nextpas.core.db.base,
  nextpas.core.db.err,
  nextpas.core.db.intf;

var
  T: TTestSuite;

{ 脚本化假连接：前 N 次 CommitTxn 抛死锁（decTransaction），之后成功。
  数据模型验证整事务重跑：回调内累加 FPending；提交成功才落账，
  提交失败与回滚都清空未提交副作用。 }
type
  TFakeFlakyConn = class(TInterfacedObject, IDbConnection, IDbTxControl)
  private
    FDepth: Integer;
    FFailCommitsLeft: Integer;
    FBeginCalls: Integer;
    FPending: Integer;
    FCommitted: Integer;
  public
    function Kind: TDbKind;
    procedure Exec(const ASql: string); overload;
    procedure Exec(const ASql: string;
      const AOptions: TDbExecOptions); overload;
    function Query(const ASql: string): IDbQuery; overload;
    function Query(const ASql: string;
      const AOptions: TDbExecOptions): IDbQuery; overload;
    function Changes: Int64;
    function Raw: Pointer;
    procedure BeginTxn(const AImmediate: Boolean = False);
    procedure CommitTxn;
    procedure RollbackTxn;
    function InTransaction: Boolean;
    function TxDepth: Integer;
    property FailCommitsLeft: Integer read FFailCommitsLeft write FFailCommitsLeft;
    property BeginCalls: Integer read FBeginCalls;
    property Pending: Integer read FPending write FPending;
    property Committed: Integer read FCommitted;
  end;

function TFakeFlakyConn.Kind: TDbKind;
begin
  Result := dbkUnknown;
end;

procedure TFakeFlakyConn.Exec(const ASql: string);
begin
  raise EDbError.CreateSimple(dbkUnknown, 'flaky conn: no SQL surface');
end;

function TFakeFlakyConn.Query(const ASql: string): IDbQuery;
begin
  Result := nil;
  raise EDbError.CreateSimple(dbkUnknown, 'flaky conn: no SQL surface');
end;

procedure TFakeFlakyConn.Exec(const ASql: string;
  const AOptions: TDbExecOptions);
begin
  raise EDbError.CreateSimple(dbkUnknown, 'flaky conn: no SQL surface');
end;

function TFakeFlakyConn.Query(const ASql: string;
  const AOptions: TDbExecOptions): IDbQuery;
begin
  Result := nil;
  raise EDbError.CreateSimple(dbkUnknown, 'flaky conn: no SQL surface');
end;

function TFakeFlakyConn.Changes: Int64;
begin
  Result := 0;
end;

function TFakeFlakyConn.Raw: Pointer;
begin
  Result := nil;
end;

procedure TFakeFlakyConn.BeginTxn(const AImmediate: Boolean);
begin
  Inc(FDepth);
  Inc(FBeginCalls);
end;

procedure TFakeFlakyConn.CommitTxn;
begin
  if FDepth = 0 then
    raise EDbError.CreateSimple(dbkUnknown, 'flaky: commit without begin');
  Dec(FDepth);
  if FFailCommitsLeft > 0 then
  begin
    Dec(FFailCommitsLeft);
    FPending := 0;                       { 提交失败 = 未提交副作用全灭 }
    raise NewDbErrorPg('40P01', 'ERROR', '',
      'deadlock detected', decTransaction, dckNone);
  end;
  FCommitted := FCommitted + FPending;
  FPending := 0;
end;

procedure TFakeFlakyConn.RollbackTxn;
begin
  if FDepth = 0 then
    raise EDbError.CreateSimple(dbkUnknown, 'flaky: rollback without begin');
  FDepth := 0;
  FPending := 0;
end;

function TFakeFlakyConn.InTransaction: Boolean;
begin
  Result := FDepth > 0;
end;

function TFakeFlakyConn.TxDepth: Integer;
begin
  Result := FDepth;
end;

{ 1 }
procedure TestFirstTrySuccess;
var
  LObj: TFakeFlakyConn;
  Conn: IDbConnection;
begin
  LObj := TFakeFlakyConn.Create;
  Conn := LObj;
  try
    WithTransactionRetry(Conn, procedure(const C: IDbConnection)
    begin
      LObj.Pending := LObj.Pending + 1;
    end);
    Check(LObj.BeginCalls = 1, 'first: exactly one attempt');
    Check(LObj.Committed = 1, 'first: side effect committed');
  finally
    Conn := nil;
  end;
end;

{ 2 + 7 }
procedure TestTransientRetriesThenSucceeds;
var
  LObj: TFakeFlakyConn;
  Conn: IDbConnection;
  Policy: TDbRetryPolicy;
  T0, T1: QWord;
begin
  LObj := TFakeFlakyConn.Create;
  Conn := LObj;
  try
    LObj.FailCommitsLeft := 2;
    Policy := TDbRetryPolicy.Default;
    Policy.MaxRetries := 2;
    Policy.BaseDelayMs := 40;            { 退避 40 + 80 = 120ms 下界 }
    Policy.MaxDelayMs := 1000;

    T0 := GetTickCount64;
    WithTransactionRetry(Conn, procedure(const C: IDbConnection)
    begin
      LObj.Pending := LObj.Pending + 1;
    end, Policy);
    T1 := GetTickCount64;

    Check(LObj.BeginCalls = 3, 'retry: three attempts total');
    Check(LObj.Committed = 1,
      'retry: whole-txn rerun semantics (not partial accumulation)');
    Check(T1 - T0 >= 120, 'retry: backoff delays actually slept');
  finally
    Conn := nil;
  end;
end;

{ 3 }
procedure TestBusinessExceptionPassesThrough;
var
  LObj: TFakeFlakyConn;
  Conn: IDbConnection;
  Raised: Boolean;
begin
  LObj := TFakeFlakyConn.Create;
  Conn := LObj;
  try
    Raised := False;
    try
      WithTransactionRetry(Conn, procedure(const C: IDbConnection)
      begin
        LObj.Pending := LObj.Pending + 1;
        raise Exception.Create('business boom');
      end);
    except
      on E: Exception do
        Raised := E.Message = 'business boom';
    end;
    Check(Raised, 'biz: exception re-raised');
    Check(LObj.BeginCalls = 1, 'biz: non-EDbError never retried');
    Check(LObj.Committed = 0, 'biz: nothing committed');
  finally
    Conn := nil;
  end;
end;

{ 4 }
procedure TestDefaultPredicateClassification;
var
  E: EDbError;
begin
  E := NewDbErrorPg('40P01', 'ERROR', '', 'deadlock',
    decTransaction, dckNone);
  try
    Check(DbRetryableDefault(E), 'pred: deadlock retryable');
  finally
    E.Free;
  end;
  E := NewDbErrorPg('40001', 'ERROR', '', 'serialization failure',
    decTransaction, dckNone);
  try
    Check(DbRetryableDefault(E), 'pred: serialization retryable');
  finally
    E.Free;
  end;
  E := NewDbErrorSqlite(DB_SQLITE_BUSY, 0, decTimeout, dckNone,
    'database is locked');
  try
    Check(DbRetryableDefault(E), 'pred: sqlite busy retryable');
  finally
    E.Free;
  end;
  E := NewDbErrorPg('57014', 'ERROR', '', 'statement timeout',
    decTimeout, dckNone);
  try
    Check(not DbRetryableDefault(E),
      'pred: pg statement timeout is NOT retried (query genuinely slow)');
  finally
    E.Free;
  end;
  E := EDbError.CreateSimple(dbkPostgres, 'connection lost');
  try
    Check(not DbRetryableDefault(E),
      'pred: connection loss needs reconnect (pool domain)');
  finally
    E.Free;
  end;
  E := NewDbErrorSqlite(2067, 0, decConstraint, dckUnique,
    'unique violation');
  try
    Check(not DbRetryableDefault(E), 'pred: constraint is not transient');
  finally
    E.Free;
  end;
end;

{ 5 }
procedure TestCustomPredicateOverrides;
var
  LObj: TFakeFlakyConn;
  Conn: IDbConnection;
  Policy: TDbRetryPolicy;
  FailLeft: Integer;
begin
  { 自定义谓词把约束违例也算瞬态（示例场景：UPSERT 冲突竞态） }
  FailLeft := 1;
  LObj := TFakeFlakyConn.Create;
  Conn := LObj;
  try
    LObj.FailCommitsLeft := -1;          { 关闭死锁脚本 }
    Policy := TDbRetryPolicy.Default;
    Policy.MaxRetries := 1;
    Policy.ShouldRetry := function(const AE: EDbError): Boolean
    begin
      Result := AE.Category = decConstraint;
    end;

    { 谓词生效路径验证：回调内首次抛约束错误一次，重试后成功 }
    WithTransactionRetry(Conn, procedure(const C: IDbConnection)
    begin
      if FailLeft > 0 then
      begin
        Dec(FailLeft);
        raise NewDbErrorSqlite(2067, 0, decConstraint, dckUnique,
          'unique race');
      end;
      LObj.Pending := LObj.Pending + 1;
    end, Policy);
    Check(LObj.Committed = 1, 'custom: predicate-driven retry succeeded');
  finally
    Conn := nil;
  end;
end;

{ 6 }
procedure TestExhaustionRaisesLast;
var
  LObj: TFakeFlakyConn;
  Conn: IDbConnection;
  Policy: TDbRetryPolicy;
  Raised: Boolean;
begin
  LObj := TFakeFlakyConn.Create;
  Conn := LObj;
  try
    LObj.FailCommitsLeft := 99;
    Policy := TDbRetryPolicy.Default;
    Policy.MaxRetries := 2;
    Policy.BaseDelayMs := 1;             { 耗尽路径不必真睡 }

    Raised := False;
    try
      WithTransactionRetry(Conn, procedure(const C: IDbConnection)
      begin
        LObj.Pending := LObj.Pending + 1;
      end, Policy);
    except
      on E: EDbError do
        Raised := Pos('deadlock', E.Message) > 0;
    end;
    Check(Raised, 'exhaust: last error surfaces with message');
    Check(LObj.BeginCalls = 3, 'exhaust: total attempts = 1 + MaxRetries');
    Check(LObj.Committed = 0, 'exhaust: nothing committed');
  finally
    Conn := nil;
  end;
end;

{ 8 }
procedure TestNestedInsideOuterTransactionSmoke;
var
  Conn: IDbConnection;
begin
  Conn := ConnectSqlite(':memory:');
  try
    Conn.Exec('CREATE TABLE t_r (v INTEGER)');
    WithTransaction(Conn, procedure(const C: IDbConnection)
    begin
      { 外层内嵌套：助手走 savepoint 路径，重试包装透明 }
      WithTransactionRetry(Conn, procedure(const C: IDbConnection)
      begin
        Conn.Exec('INSERT INTO t_r VALUES (42)');
      end);
    end);
    Check(True, 'nested: composed without error');
  finally
    Conn := nil;
  end;
end;

begin
  T := TTestSuite.Create('nextpas.core.db.retry');
  T.Test('first try success', @TestFirstTrySuccess);
  T.Test('transient retries then succeeds', @TestTransientRetriesThenSucceeds);
  T.Test('business exception passes through', @TestBusinessExceptionPassesThrough);
  T.Test('default predicate classification', @TestDefaultPredicateClassification);
  T.Test('custom predicate overrides', @TestCustomPredicateOverrides);
  T.Test('exhaustion raises last error', @TestExhaustionRaisesLast);
  T.Test('nested inside outer transaction smoke', @TestNestedInsideOuterTransactionSmoke);
  if not T.Run then Halt(1);
end.
