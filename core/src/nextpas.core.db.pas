unit nextpas.core.db;

{** @desc nextpas.core.db L3 门面：统一数据库访问层。
       聚合统一接口（IDbConnection/IDbQuery）、6 后端工厂（SQLite /
       PostgreSQL / MySQL / ODBC / Redis / DM）、泛化事务与迁移助手。

       用法：
         Conn := ConnectSqlite(':memory:');
         Conn.Exec('CREATE TABLE t (id INTEGER PRIMARY KEY, v TEXT)');
         Q := Conn.Query('SELECT v FROM t WHERE id = ?');
         Q.BindInt64(1, 42);
         while Q.Step do ...        { 接口引用计数自动释放 }

       后端专属特性（pool、原生句柄等）分别经 nextpas.core.db.sqlite /
       nextpas.core.db.pg 门面使用。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.exception,
  nextpas.core.db.base,
  nextpas.core.db.bulk,
  nextpas.core.db.intf,
  nextpas.core.db.tx,
  nextpas.core.db.migrate,
  nextpas.core.db.pool,
  nextpas.core.db.sqlite.base,
  nextpas.core.db.redis.base;

type
  { base }
  TDbKind = nextpas.core.db.base.TDbKind;
  TDbColumnType = nextpas.core.db.base.TDbColumnType;
  TDbErrorCategory = nextpas.core.db.base.TDbErrorCategory;
  TDbConstraintKind = nextpas.core.db.base.TDbConstraintKind;
  EDbError = nextpas.core.db.base.EDbError;
  EDbNotSupported = nextpas.core.db.base.EDbNotSupported;
  TDbExecOptions = nextpas.core.db.base.TDbExecOptions;

  { intf }
  IDbConnection = nextpas.core.db.intf.IDbConnection;
  IDbQuery = nextpas.core.db.intf.IDbQuery;
  IDbTxControl = nextpas.core.db.intf.IDbTxControl;
  IDbSavepointControl = nextpas.core.db.intf.IDbSavepointControl;
  IDbBatchExecutor = nextpas.core.db.intf.IDbBatchExecutor;
  TDbSqlSteps = nextpas.core.db.base.TDbSqlSteps;
  IDbStmtCacheControl = nextpas.core.db.intf.IDbStmtCacheControl;
  IDbBlobStream = nextpas.core.db.intf.IDbBlobStream;
  IDbLargeObjectControl = nextpas.core.db.intf.IDbLargeObjectControl;
  IDbRowBlobControl = nextpas.core.db.intf.IDbRowBlobControl;
  IDbArrayBinding = nextpas.core.db.intf.IDbArrayBinding;
  TDbInt64Array = nextpas.core.db.base.TDbInt64Array;
  TDbDoubleArray = nextpas.core.db.base.TDbDoubleArray;
  TDbStringArray = nextpas.core.db.base.TDbStringArray;
  TDbBoolArray = nextpas.core.db.base.TDbBoolArray;
  IDbCapabilities = nextpas.core.db.intf.IDbCapabilities;
  IDbTraceListener = nextpas.core.db.intf.IDbTraceListener;
  IDbTraceControl = nextpas.core.db.intf.IDbTraceControl;
  TDbSeekOrigin = nextpas.core.db.base.TDbSeekOrigin;

  { pool }
  TDbPool = nextpas.core.db.pool.TDbPool;
  TDbPoolPolicy = nextpas.core.db.pool.TDbPoolPolicy;
  TDbConnectFunc = nextpas.core.db.pool.TDbConnectFunc;
  IDbPooledHandle = nextpas.core.db.pool.IDbPooledHandle;

  { tx }
  TDbTxProc = nextpas.core.db.tx.TDbTxProc;
  TDbConnProc = nextpas.core.db.tx.TDbConnProc;
  TDbRetryShouldRetry = nextpas.core.db.tx.TDbRetryShouldRetry;
  TDbRetryPolicy = nextpas.core.db.tx.TDbRetryPolicy;

  { migrate }
  EDbMigrateError = nextpas.core.db.migrate.EDbMigrateError;
  TDbMigration = nextpas.core.db.migrate.TDbMigration;
  TDbMigrations = nextpas.core.db.migrate.TDbMigrations;
  TDbDryRunStatus = nextpas.core.db.migrate.TDbDryRunStatus;
  TDbDryRunEntry = nextpas.core.db.migrate.TDbDryRunEntry;
  TDbDryRunPlan = nextpas.core.db.migrate.TDbDryRunPlan;

  { redis }
  TDbRedisConnectOptions = nextpas.core.db.redis.base.TDbRedisConnectOptions;

const
  DB_MIGRATIONS_TABLE = nextpas.core.db.migrate.DB_MIGRATIONS_TABLE;

  { TDbDryRunStatus 成员透传（type 别名不引入枚举成员作用域） }
  drsApply = nextpas.core.db.migrate.drsApply;
  drsApplied = nextpas.core.db.migrate.drsApplied;
  drsChecksumMismatch = nextpas.core.db.migrate.drsChecksumMismatch;

{ ---- 工厂 ---- }
function ConnectSqlite(const APath: string;
  const AStmtCacheCapacity: Integer = DEFAULT_SQLITE_STMT_CACHE_CAPACITY):
  IDbConnection; inline;
function ConnectSqlite(const APath: string; const AOptions: TDbConnectOptions;
  const AStmtCacheCapacity: Integer = DEFAULT_SQLITE_STMT_CACHE_CAPACITY):
  IDbConnection; inline;
{ C5 调优预设：TDbSqlitePragmas 连接级 PRAGMA 受控面（类型来自
  db.sqlite.base，本单元随用随透出）。语义与 fail-closed 回读校验
  见 adapter 同名重载注记。 }
function ConnectSqlite(const APath: string; const AOptions: TDbConnectOptions;
  const APragmas: TDbSqlitePragmas;
  const AStmtCacheCapacity: Integer = DEFAULT_SQLITE_STMT_CACHE_CAPACITY):
  IDbConnection; inline;
function ConnectPostgres(const AConnInfo: string): IDbConnection; inline;
function ConnectPostgres(const AConnInfo: string;
  const AOptions: TDbConnectOptions): IDbConnection; inline;
function ConnectPostgres(const AConnInfo: string;
  const AOptions: TDbConnectOptions;
  const AStmtCacheCapacity: Integer): IDbConnection; inline;
function ConnectMysql(const ADsn: string): IDbConnection; inline;
function ConnectMysql(const ADsn: string;
  const AOptions: TDbConnectOptions): IDbConnection; inline;
function ConnectMysql(const ADsn: string;
  const AOptions: TDbConnectOptions;
  const AStmtCacheCapacity: Integer): IDbConnection; inline;
{ V3-A4：ODBC 网关（DSN/DSN-less connstr 原文透传 DriverConnect）。
  能力降级矩阵与诚实契约见 odbc.adapter 单元头注。 }
function ConnectOdbc(const ADsn: string): IDbConnection; inline;
function ConnectOdbc(const ADsn: string;
  const AOptions: TDbConnectOptions): IDbConnection; inline;
function ConnectOdbc(const ADsn: string;
  const AOptions: TDbConnectOptions;
  const AStmtCacheCapacity: Integer): IDbConnection; inline;
function ConnectRedis(const AAddr: string): IDbConnection; inline; overload;
function ConnectRedis(const AAddr: string; const APassword: string;
  const ADbIndex: Integer; const AOptions: TDbConnectOptions): IDbConnection; inline; overload;
function ConnectRedis(const AAddr: string;
  const AOptions: TDbRedisConnectOptions): IDbConnection; inline; overload;
function ConnectDm(const ADsn: string): IDbConnection; inline; overload;
function ConnectDm(const ADsn: string;
  const AOptions: TDbConnectOptions): IDbConnection; inline; overload;
function ConnectDm(const ADsn: string;
  const AOptions: TDbConnectOptions;
  const AStmtCacheCapacity: Integer): IDbConnection; inline; overload;

{ ---- 池工厂（开箱组合：池策略 × 后端连接选项）---- }
{ 便利形态：缺省策略仅覆盖读上限，busy_timeout 烘入生产级缺省
  （DefaultSqliteBusyTimeoutMs，F-10）。 }
function OpenSqlitePool(const APath: string;
  AMaxReadConnections: Integer): TDbPool; inline; overload;
{ 全控形态：池策略与连接选项逐字采用。 }
function OpenSqlitePool(const APath: string; const APolicy: TDbPoolPolicy;
  const AOptions: TDbConnectOptions): TDbPool; inline; overload;

{ ---- 能力矩阵（V3-B1）---- }
{ 统一能力自述探测：连接实现 IDbCapabilities 则返回之，否则 nil
  （无值用 nil 表达——仓库错误处理策略）。布尔项与可选接口存在性
  互证契约见 db.intf 注记与 CONTRACT §2.10。 }
function DbCapabilities(const AConn: IDbConnection): IDbCapabilities; inline;

{ ---- 参数级批量绑定（V3-C2）---- }
{ 统一探测：查询对象实现 IDbArrayBinding 则返回之，否则 nil（无值用
  nil 表达——后端未支持即降级通用路径）。语义与 fail-fast 契约见
  db.intf 注记与 CONTRACT §2.16。 }
function DbArrayBinding(const AQry: IDbQuery): IDbArrayBinding; inline;

{ ---- 观测钩子控制面（V3-B3）---- }
{ 统一探测：连接实现 IDbTraceControl 则返回之，否则 nil（无值用
  nil 表达）。SetListener 非 nil 即同步补发 OnAcquire，语义与配对
  契约见 CONTRACT §2.12。 }
function DbTraceControl(const AConn: IDbConnection): IDbTraceControl; inline;

{ ---- tx 透传 ---- }
{ 捕获形态：回调若引用池化连接，租约滞留至闭包销毁（B13）——
  池化连接一律改用参数化形态。 }
procedure WithTransaction(const AConn: IDbConnection;
  const AProc: TDbTxProc); inline; overload;
{ 参数化形态（B13 零捕获）：连接由框架作实参传入，
  本调用语句结束即归还租约。事务语义与捕获形态一致。 }
procedure WithTransaction(const AConn: IDbConnection;
  const ABody: TDbConnProc); inline; overload;
function DbRetryableDefault(const AE: EDbError): Boolean; inline;
procedure WithTransactionRetry(const AConn: IDbConnection;
  const AProc: TDbTxProc); inline; overload;
procedure WithTransactionRetry(const AConn: IDbConnection;
  const AProc: TDbTxProc; const APolicy: TDbRetryPolicy); inline; overload;
procedure WithTransactionRetry(const AConn: IDbConnection;
  const ABody: TDbConnProc); inline; overload;
procedure WithTransactionRetry(const AConn: IDbConnection;
  const ABody: TDbConnProc; const APolicy: TDbRetryPolicy); inline; overload;

{ ---- migrate 透传 ---- }
function MakeMigrations(const AMigrations: array of TDbMigration): TDbMigrations; inline;
function Migrate(const AConn: IDbConnection;
  const AMigrations: TDbMigrations): Integer; inline;
function MigrateDryRun(const AConn: IDbConnection;
  const AMigrations: TDbMigrations): TDbDryRunPlan; inline;
function MigrationVersion(const AConn: IDbConnection): Int64; inline;

implementation

uses
  nextpas.core.base.utils,
  nextpas.core.db.sqlite.adapter,
  nextpas.core.db.sqlite.pool,
  nextpas.core.db.pg.adapter,
  nextpas.core.db.mysql.adapter,
  nextpas.core.db.odbc.adapter,
  nextpas.core.db.redis.adapter,
  nextpas.core.db.dm.adapter;

function ConnectSqlite(const APath: string;
  const AStmtCacheCapacity: Integer): IDbConnection;
begin
  Result := nextpas.core.db.sqlite.adapter.ConnectSqlite(APath,
    AStmtCacheCapacity);
end;

function ConnectSqlite(const APath: string; const AOptions: TDbConnectOptions;
  const AStmtCacheCapacity: Integer): IDbConnection;
begin
  Result := nextpas.core.db.sqlite.adapter.ConnectSqlite(APath, AOptions,
    AStmtCacheCapacity);
end;

function ConnectSqlite(const APath: string; const AOptions: TDbConnectOptions;
  const APragmas: TDbSqlitePragmas;
  const AStmtCacheCapacity: Integer): IDbConnection;
begin
  Result := nextpas.core.db.sqlite.adapter.ConnectSqlite(APath, AOptions,
    AStmtCacheCapacity);
end;

function ConnectPostgres(const AConnInfo: string): IDbConnection;
begin
  Result := nextpas.core.db.pg.adapter.ConnectPostgres(AConnInfo);
end;

function ConnectPostgres(const AConnInfo: string;
  const AOptions: TDbConnectOptions): IDbConnection;
begin
  Result := nextpas.core.db.pg.adapter.ConnectPostgres(AConnInfo, AOptions);
end;

function ConnectPostgres(const AConnInfo: string;
  const AOptions: TDbConnectOptions;
  const AStmtCacheCapacity: Integer): IDbConnection;
begin
  Result := nextpas.core.db.pg.adapter.ConnectPostgres(AConnInfo, AOptions,
    AStmtCacheCapacity);
end;

function ConnectMysql(const ADsn: string): IDbConnection;
begin
  Result := nextpas.core.db.mysql.adapter.ConnectMysql(ADsn);
end;

function ConnectMysql(const ADsn: string;
  const AOptions: TDbConnectOptions): IDbConnection;
begin
  Result := nextpas.core.db.mysql.adapter.ConnectMysql(ADsn, AOptions);
end;

function ConnectMysql(const ADsn: string;
  const AOptions: TDbConnectOptions;
  const AStmtCacheCapacity: Integer): IDbConnection;
begin
  Result := nextpas.core.db.mysql.adapter.ConnectMysql(ADsn, AOptions);
end;

function ConnectOdbc(const ADsn: string): IDbConnection;
begin
  Result := nextpas.core.db.odbc.adapter.ConnectOdbc(ADsn);
end;

function ConnectOdbc(const ADsn: string;
  const AOptions: TDbConnectOptions): IDbConnection;
begin
  Result := nextpas.core.db.odbc.adapter.ConnectOdbc(ADsn, AOptions);
end;

function ConnectOdbc(const ADsn: string;
  const AOptions: TDbConnectOptions;
  const AStmtCacheCapacity: Integer): IDbConnection;
begin
  Result := nextpas.core.db.odbc.adapter.ConnectOdbc(ADsn, AOptions);
end;

function ConnectRedis(const AAddr: string): IDbConnection;
begin
  Result := nextpas.core.db.redis.adapter.ConnectRedis(AAddr);
end;

function ConnectRedis(const AAddr: string; const APassword: string;
  const ADbIndex: Integer; const AOptions: TDbConnectOptions): IDbConnection;
begin
  Result := nextpas.core.db.redis.adapter.ConnectRedis(AAddr, APassword, ADbIndex, AOptions);
end;

function ConnectRedis(const AAddr: string;
  const AOptions: TDbRedisConnectOptions): IDbConnection;
begin
  Result := nextpas.core.db.redis.adapter.ConnectRedis(AAddr, AOptions);
end;

function ConnectDm(const ADsn: string): IDbConnection;
begin
  Result := nextpas.core.db.dm.adapter.ConnectDm(ADsn);
end;

function ConnectDm(const ADsn: string;
  const AOptions: TDbConnectOptions): IDbConnection;
begin
  Result := nextpas.core.db.dm.adapter.ConnectDm(ADsn, AOptions);
end;

function ConnectDm(const ADsn: string;
  const AOptions: TDbConnectOptions;
  const AStmtCacheCapacity: Integer): IDbConnection;
begin
  Result := nextpas.core.db.dm.adapter.ConnectDm(ADsn, AOptions, AStmtCacheCapacity);
end;

function OpenSqlitePool(const APath: string;
  AMaxReadConnections: Integer): TDbPool;
begin
  Result := nextpas.core.db.sqlite.pool.OpenSqlitePool(APath,
    AMaxReadConnections);
end;

function OpenSqlitePool(const APath: string; const APolicy: TDbPoolPolicy;
  const AOptions: TDbConnectOptions): TDbPool;
begin
  Result := nextpas.core.db.sqlite.pool.OpenSqlitePool(APath, APolicy,
    AOptions);
end;

function DbCapabilities(const AConn: IDbConnection): IDbCapabilities;
begin
  Result := nil;
  if AConn = nil then
    Exit;
  Supports(AConn, IDbCapabilities, Result);
end;

function DbArrayBinding(const AQry: IDbQuery): IDbArrayBinding;
begin
  Result := nil;
  if AQry = nil then
    Exit;
  Supports(AQry, IDbArrayBinding, Result);
end;

function DbTraceControl(const AConn: IDbConnection): IDbTraceControl;
begin
  Result := nil;
  if AConn = nil then
    Exit;
  Supports(AConn, IDbTraceControl, Result);
end;

procedure WithTransaction(const AConn: IDbConnection;
  const AProc: TDbTxProc);
begin
  nextpas.core.db.tx.WithTransaction(AConn, AProc);
end;

procedure WithTransaction(const AConn: IDbConnection;
  const ABody: TDbConnProc);
begin
  nextpas.core.db.tx.WithTransaction(AConn, ABody);
end;

function DbRetryableDefault(const AE: EDbError): Boolean;
begin
  Result := nextpas.core.db.tx.DbRetryableDefault(AE);
end;

procedure WithTransactionRetry(const AConn: IDbConnection;
  const ABody: TDbConnProc);
begin
  nextpas.core.db.tx.WithTransactionRetry(AConn, ABody);
end;

procedure WithTransactionRetry(const AConn: IDbConnection;
  const ABody: TDbConnProc; const APolicy: TDbRetryPolicy);
begin
  nextpas.core.db.tx.WithTransactionRetry(AConn, ABody, APolicy);
end;

procedure WithTransactionRetry(const AConn: IDbConnection;
  const AProc: TDbTxProc);
begin
  nextpas.core.db.tx.WithTransactionRetry(AConn, AProc);
end;

procedure WithTransactionRetry(const AConn: IDbConnection;
  const AProc: TDbTxProc; const APolicy: TDbRetryPolicy);
begin
  nextpas.core.db.tx.WithTransactionRetry(AConn, AProc, APolicy);
end;

function MakeMigrations(const AMigrations: array of TDbMigration): TDbMigrations;
begin
  Result := nextpas.core.db.migrate.MakeMigrations(AMigrations);
end;

function Migrate(const AConn: IDbConnection;
  const AMigrations: TDbMigrations): Integer;
begin
  Result := nextpas.core.db.migrate.Migrate(AConn, AMigrations);
end;

function MigrateDryRun(const AConn: IDbConnection;
  const AMigrations: TDbMigrations): TDbDryRunPlan;
begin
  Result := nextpas.core.db.migrate.MigrateDryRun(AConn, AMigrations);
end;

function MigrationVersion(const AConn: IDbConnection): Int64;
begin
  Result := nextpas.core.db.migrate.MigrationVersion(AConn);
end;

end.
