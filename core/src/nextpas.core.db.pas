unit nextpas.core.db;
{**
 * L3 db family facade — pure re-export.
 * See core/docs/db/CONTRACT.md §2.14.
 *}

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
  nextpas.core.db.pool;

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

const
  DB_MIGRATIONS_TABLE = nextpas.core.db.migrate.DB_MIGRATIONS_TABLE;

  { TDbDryRunStatus 成员透传（type 别名不引入枚举成员作用域） }
  drsApply = nextpas.core.db.migrate.drsApply;
  drsApplied = nextpas.core.db.migrate.drsApplied;
  drsChecksumMismatch = nextpas.core.db.migrate.drsChecksumMismatch;

{ Factory }
function ConnectSqlite(const APath: string;
  const AStmtCacheCapacity: Integer = 64):
  IDbConnection; inline;
function ConnectSqlite(const APath: string; const AOptions: TDbConnectOptions;
  const AStmtCacheCapacity: Integer = 64):
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
function ConnectOdbc(const ADsn: string): IDbConnection; inline;
function ConnectOdbc(const ADsn: string;
  const AOptions: TDbConnectOptions): IDbConnection; inline;
function ConnectOdbc(const ADsn: string;
  const AOptions: TDbConnectOptions;
  const AStmtCacheCapacity: Integer): IDbConnection; inline;
function ConnectRedis(const AAddr: string): IDbConnection; inline;
function ConnectDm(const ADsn: string): IDbConnection; inline; overload;
function ConnectDm(const ADsn: string;
  const AOptions: TDbConnectOptions): IDbConnection; inline; overload;
function ConnectDm(const ADsn: string;
  const AOptions: TDbConnectOptions;
  const AStmtCacheCapacity: Integer): IDbConnection; inline; overload;

{ Pool }
function OpenSqlitePool(const APath: string;
  AMaxReadConnections: Integer): TDbPool; inline; overload;
function OpenSqlitePool(const APath: string; const APolicy: TDbPoolPolicy;
  const AOptions: TDbConnectOptions): TDbPool; inline; overload;

{ Capabilities }
function DbCapabilities(const AConn: IDbConnection): IDbCapabilities; inline;

{ Batch }
function DbArrayBinding(const AQry: IDbQuery): IDbArrayBinding; inline;

{ Trace }
function DbTraceControl(const AConn: IDbConnection): IDbTraceControl; inline;

{ Tx — B13 零捕获 source-contract 硬门禁 }
procedure WithTransaction(const AConn: IDbConnection;
  const ABody: TDbConnProc); inline; overload;
function DbRetryableDefault(const AE: EDbError): Boolean; inline;
procedure WithTransactionRetry(const AConn: IDbConnection;
  const ABody: TDbConnProc); inline; overload;
procedure WithTransactionRetry(const AConn: IDbConnection;
  const ABody: TDbConnProc; const APolicy: TDbRetryPolicy); inline; overload;

{ Migrate }
function MakeMigrations(const AMigrations: array of TDbMigration): TDbMigrations; inline;
function Migrate(const AConn: IDbConnection;
  const AMigrations: TDbMigrations): Integer; inline;
function MigrateDryRun(const AConn: IDbConnection;
  const AMigrations: TDbMigrations): TDbDryRunPlan; inline;
function MigrationVersion(const AConn: IDbConnection): Int64; inline;

implementation

uses
  nextpas.core.bytes.ops,
  nextpas.core.db.factory.facade,
  nextpas.core.db.perf,
  nextpas.core.db.capprobe,
  nextpas.core.db.batch,
  nextpas.core.db.trace;

{ bytes.ops single source — owner bytes.ops, perf via db.perf uses-link. }


{ Facade pure re-export: inline thin forward via factory.facade Kind-driven table, zero adapter hard link. }
{ Perf inline/bytes.ops single-source, interface refcount auto; factory.facade (zero adapter hard link invariant, single source). }

function ConnectSqlite(const APath: string;
  const AStmtCacheCapacity: Integer): IDbConnection; inline;
begin
  Result := nextpas.core.db.factory.facade.ConnectSqlite(APath, AStmtCacheCapacity);
end;

function ConnectSqlite(const APath: string; const AOptions: TDbConnectOptions;
  const AStmtCacheCapacity: Integer): IDbConnection; inline;
begin
  Result := nextpas.core.db.factory.facade.ConnectSqlite(APath, AOptions, AStmtCacheCapacity);
end;

function ConnectPostgres(const AConnInfo: string): IDbConnection; inline;
begin
  Result := nextpas.core.db.factory.facade.ConnectPostgres(AConnInfo);
end;

function ConnectPostgres(const AConnInfo: string;
  const AOptions: TDbConnectOptions): IDbConnection; inline;
begin
  Result := nextpas.core.db.factory.facade.ConnectPostgres(AConnInfo, AOptions);
end;

function ConnectPostgres(const AConnInfo: string;
  const AOptions: TDbConnectOptions;
  const AStmtCacheCapacity: Integer): IDbConnection; inline;
begin
  Result := nextpas.core.db.factory.facade.ConnectPostgres(AConnInfo, AOptions, AStmtCacheCapacity);
end;

function ConnectMysql(const ADsn: string): IDbConnection; inline;
begin
  Result := nextpas.core.db.factory.facade.ConnectMysql(ADsn);
end;

function ConnectMysql(const ADsn: string;
  const AOptions: TDbConnectOptions): IDbConnection; inline;
begin
  Result := nextpas.core.db.factory.facade.ConnectMysql(ADsn, AOptions);
end;

function ConnectMysql(const ADsn: string;
  const AOptions: TDbConnectOptions;
  const AStmtCacheCapacity: Integer): IDbConnection; inline;
begin
  Result := nextpas.core.db.factory.facade.ConnectMysql(ADsn, AOptions, AStmtCacheCapacity);
end;

function ConnectOdbc(const ADsn: string): IDbConnection; inline;
begin
  Result := nextpas.core.db.factory.facade.ConnectOdbc(ADsn);
end;

function ConnectOdbc(const ADsn: string;
  const AOptions: TDbConnectOptions): IDbConnection; inline;
begin
  Result := nextpas.core.db.factory.facade.ConnectOdbc(ADsn, AOptions);
end;

function ConnectOdbc(const ADsn: string;
  const AOptions: TDbConnectOptions;
  const AStmtCacheCapacity: Integer): IDbConnection; inline;
begin
  Result := nextpas.core.db.factory.facade.ConnectOdbc(ADsn, AOptions, AStmtCacheCapacity);
end;

function ConnectRedis(const AAddr: string): IDbConnection; inline;
begin
  Result := nextpas.core.db.factory.facade.ConnectRedis(AAddr);
end;

function ConnectDm(const ADsn: string): IDbConnection; inline;
begin
  Result := nextpas.core.db.factory.facade.ConnectDm(ADsn);
end;

function ConnectDm(const ADsn: string;
  const AOptions: TDbConnectOptions): IDbConnection; inline;
begin
  Result := nextpas.core.db.factory.facade.ConnectDm(ADsn, AOptions);
end;

function ConnectDm(const ADsn: string;
  const AOptions: TDbConnectOptions;
  const AStmtCacheCapacity: Integer): IDbConnection; inline;
begin
  Result := nextpas.core.db.factory.facade.ConnectDm(ADsn, AOptions, AStmtCacheCapacity);
end;

function OpenSqlitePool(const APath: string;
  AMaxReadConnections: Integer): TDbPool; inline;
begin
  Result := nextpas.core.db.factory.facade.OpenSqlitePool(APath, AMaxReadConnections);
end;

function OpenSqlitePool(const APath: string; const APolicy: TDbPoolPolicy;
  const AOptions: TDbConnectOptions): TDbPool; inline;
begin
  Result := nextpas.core.db.factory.facade.OpenSqlitePool(APath, APolicy, AOptions);
end;

function DbCapabilities(const AConn: IDbConnection): IDbCapabilities; inline;
begin
  Result := nextpas.core.db.capprobe.DbProbeCapabilities(AConn);
end;

function DbArrayBinding(const AQry: IDbQuery): IDbArrayBinding; inline;
begin
  Result := nextpas.core.db.batch.DbBatchProbeArrayBinding(AQry);
end;

function DbTraceControl(const AConn: IDbConnection): IDbTraceControl; inline;
begin
  Result := nextpas.core.db.trace.DbProbeTraceControl(AConn);
end;

procedure WithTransaction(const AConn: IDbConnection;
  const ABody: TDbConnProc); inline;
begin
  nextpas.core.db.tx.WithTransaction(AConn, ABody);
end;

function DbRetryableDefault(const AE: EDbError): Boolean; inline;
begin
  Result := nextpas.core.db.tx.DbRetryableDefault(AE);
end;

procedure WithTransactionRetry(const AConn: IDbConnection;
  const ABody: TDbConnProc); inline;
begin
  nextpas.core.db.tx.WithTransactionRetry(AConn, ABody);
end;

procedure WithTransactionRetry(const AConn: IDbConnection;
  const ABody: TDbConnProc; const APolicy: TDbRetryPolicy); inline;
begin
  nextpas.core.db.tx.WithTransactionRetry(AConn, ABody, APolicy);
end;

function MakeMigrations(const AMigrations: array of TDbMigration): TDbMigrations; inline;
begin
  Result := nextpas.core.db.migrate.MakeMigrations(AMigrations);
end;

function Migrate(const AConn: IDbConnection;
  const AMigrations: TDbMigrations): Integer; inline;
begin
  Result := nextpas.core.db.migrate.Migrate(AConn, AMigrations);
end;

function MigrateDryRun(const AConn: IDbConnection;
  const AMigrations: TDbMigrations): TDbDryRunPlan; inline;
begin
  Result := nextpas.core.db.migrate.MigrateDryRun(AConn, AMigrations);
end;

function MigrationVersion(const AConn: IDbConnection): Int64; inline;
begin
  Result := nextpas.core.db.migrate.MigrationVersion(AConn);
end;

end.
