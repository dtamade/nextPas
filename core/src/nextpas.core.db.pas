unit nextpas.core.db;

{** @desc nextpas.core.db L3 门面：统一数据库访问层。
       聚合统一接口（IDbConnection/IDbQuery）、双后端工厂（SQLite /
       PostgreSQL）、泛化事务与迁移助手。

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
  nextpas.core.db.intf,
  nextpas.core.db.tx,
  nextpas.core.db.migrate;

type
  { base }
  TDbKind = nextpas.core.db.base.TDbKind;
  TDbColumnType = nextpas.core.db.base.TDbColumnType;
  EDbError = nextpas.core.db.base.EDbError;
  EDbNotSupported = nextpas.core.db.base.EDbNotSupported;

  { intf }
  IDbConnection = nextpas.core.db.intf.IDbConnection;
  IDbQuery = nextpas.core.db.intf.IDbQuery;
  IDbTxControl = nextpas.core.db.intf.IDbTxControl;

  { tx }
  TDbTxProc = nextpas.core.db.tx.TDbTxProc;

  { migrate }
  EDbMigrateError = nextpas.core.db.migrate.EDbMigrateError;
  TDbMigration = nextpas.core.db.migrate.TDbMigration;
  TDbMigrations = nextpas.core.db.migrate.TDbMigrations;

const
  DB_MIGRATIONS_TABLE = nextpas.core.db.migrate.DB_MIGRATIONS_TABLE;

{ ---- 工厂 ---- }
function ConnectSqlite(const APath: string): IDbConnection; inline;
function ConnectPostgres(const AConnInfo: string): IDbConnection; inline;

{ ---- tx 透传 ---- }
procedure WithTransaction(const AConn: IDbConnection;
  const AProc: TDbTxProc); inline;

{ ---- migrate 透传 ---- }
function MakeMigrations(const AMigrations: array of TDbMigration): TDbMigrations; inline;
function Migrate(const AConn: IDbConnection;
  const AMigrations: TDbMigrations): Integer; inline;
function MigrationVersion(const AConn: IDbConnection): Int64; inline;

implementation

uses
  nextpas.core.db.sqlite.adapter,
  nextpas.core.db.pg.adapter;

function ConnectSqlite(const APath: string): IDbConnection;
begin
  Result := nextpas.core.db.sqlite.adapter.ConnectSqlite(APath);
end;

function ConnectPostgres(const AConnInfo: string): IDbConnection;
begin
  Result := nextpas.core.db.pg.adapter.ConnectPostgres(AConnInfo);
end;

procedure WithTransaction(const AConn: IDbConnection;
  const AProc: TDbTxProc);
begin
  nextpas.core.db.tx.WithTransaction(AConn, AProc);
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

function MigrationVersion(const AConn: IDbConnection): Int64;
begin
  Result := nextpas.core.db.migrate.MigrationVersion(AConn);
end;

end.
