unit nextpas.core.sqlite;

{** @desc DEPRECATED 兼容 shim —— SQLite 家族已收编进 nextpas.core.db。
       新代码请使用 nextpas.core.db（统一入口）或
       nextpas.core.db.sqlite（SQLite 后端门面）。
       迁移与删除计划见 core/docs/db/CONTRACT.md。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.exception,
  nextpas.core.db.sqlite;

type
  { conn }
  ESqliteError = nextpas.core.db.sqlite.ESqliteError;
  TSqliteDb = nextpas.core.db.sqlite.TSqliteDb;
  TSqliteQuery = nextpas.core.db.sqlite.TSqliteQuery;

  { pool }
  ESqlitePoolError = nextpas.core.db.sqlite.ESqlitePoolError;
  TSqlitePool = nextpas.core.db.sqlite.TSqlitePool;

  { tx }
  ESqliteTxError = nextpas.core.db.sqlite.ESqliteTxError;
  TSqliteTxProc = nextpas.core.db.sqlite.TSqliteTxProc;

  { migrate }
  ESqliteMigrateError = nextpas.core.db.sqlite.ESqliteMigrateError;
  TSqliteMigration = nextpas.core.db.sqlite.TSqliteMigration;
  TSqliteMigrations = nextpas.core.db.sqlite.TSqliteMigrations;

const
  SQLITE_OK = nextpas.core.db.sqlite.SQLITE_OK;
  SQLITE_ROW = nextpas.core.db.sqlite.SQLITE_ROW;
  SQLITE_DONE = nextpas.core.db.sqlite.SQLITE_DONE;
  SQLITE_INTEGER = nextpas.core.db.sqlite.SQLITE_INTEGER;
  SQLITE_FLOAT = nextpas.core.db.sqlite.SQLITE_FLOAT;
  SQLITE_TEXT = nextpas.core.db.sqlite.SQLITE_TEXT;
  SQLITE_BLOB = nextpas.core.db.sqlite.SQLITE_BLOB;
  SQLITE_NULL = nextpas.core.db.sqlite.SQLITE_NULL;
  SQLITE_CONSTRAINT = nextpas.core.db.sqlite.SQLITE_CONSTRAINT;
  SQLITE_CONSTRAINT_CHECK = nextpas.core.db.sqlite.SQLITE_CONSTRAINT_CHECK;
  SQLITE_CONSTRAINT_COMMITHOOK = nextpas.core.db.sqlite.SQLITE_CONSTRAINT_COMMITHOOK;
  SQLITE_CONSTRAINT_FOREIGNKEY = nextpas.core.db.sqlite.SQLITE_CONSTRAINT_FOREIGNKEY;
  SQLITE_CONSTRAINT_FUNCTION = nextpas.core.db.sqlite.SQLITE_CONSTRAINT_FUNCTION;
  SQLITE_CONSTRAINT_NOTNULL = nextpas.core.db.sqlite.SQLITE_CONSTRAINT_NOTNULL;
  SQLITE_CONSTRAINT_PRIMARYKEY = nextpas.core.db.sqlite.SQLITE_CONSTRAINT_PRIMARYKEY;
  SQLITE_CONSTRAINT_TRIGGER = nextpas.core.db.sqlite.SQLITE_CONSTRAINT_TRIGGER;
  SQLITE_CONSTRAINT_UNIQUE = nextpas.core.db.sqlite.SQLITE_CONSTRAINT_UNIQUE;
  SQLITE_CONSTRAINT_VTAB = nextpas.core.db.sqlite.SQLITE_CONSTRAINT_VTAB;
  SQLITE_CONSTRAINT_ROWID = nextpas.core.db.sqlite.SQLITE_CONSTRAINT_ROWID;
  SQLITE_CONSTRAINT_PINNED = nextpas.core.db.sqlite.SQLITE_CONSTRAINT_PINNED;
  SQLITE_CONSTRAINT_DATATYPE = nextpas.core.db.sqlite.SQLITE_CONSTRAINT_DATATYPE;
  SQLITE_MIGRATIONS_TABLE = nextpas.core.db.sqlite.SQLITE_MIGRATIONS_TABLE;

function SqliteOpen(const APath: string): TSqliteDb; inline;

{ ---- tx 透传 ---- }
procedure WithTransaction(const ADb: TSqliteDb;
  const AProc: TSqliteTxProc); inline;
procedure BeginTxn(const ADb: TSqliteDb;
  const AImmediate: Boolean = False); inline;
procedure CommitTxn(const ADb: TSqliteDb); inline;
procedure RollbackTxn(const ADb: TSqliteDb); inline;
function InTransaction(const ADb: TSqliteDb): Boolean; inline;
function TxDepth(const ADb: TSqliteDb): Integer; inline;

{ ---- migrate 透传 ---- }
function MakeMigrations(const AMigrations: array of TSqliteMigration): TSqliteMigrations; inline;
function Migrate(const ADb: TSqliteDb;
  const AMigrations: TSqliteMigrations): Integer; inline;
function MigrationVersion(const ADb: TSqliteDb): Int64; inline;

implementation

function SqliteOpen(const APath: string): TSqliteDb;
begin
  Result := nextpas.core.db.sqlite.SqliteOpen(APath);
end;

procedure WithTransaction(const ADb: TSqliteDb;
  const AProc: TSqliteTxProc);
begin
  nextpas.core.db.sqlite.WithTransaction(ADb, AProc);
end;

procedure BeginTxn(const ADb: TSqliteDb; const AImmediate: Boolean);
begin
  nextpas.core.db.sqlite.BeginTxn(ADb, AImmediate);
end;

procedure CommitTxn(const ADb: TSqliteDb);
begin
  nextpas.core.db.sqlite.CommitTxn(ADb);
end;

procedure RollbackTxn(const ADb: TSqliteDb);
begin
  nextpas.core.db.sqlite.RollbackTxn(ADb);
end;

function InTransaction(const ADb: TSqliteDb): Boolean;
begin
  Result := nextpas.core.db.sqlite.InTransaction(ADb);
end;

function TxDepth(const ADb: TSqliteDb): Integer;
begin
  Result := nextpas.core.db.sqlite.TxDepth(ADb);
end;

function MakeMigrations(const AMigrations: array of TSqliteMigration): TSqliteMigrations;
begin
  Result := nextpas.core.db.sqlite.MakeMigrations(AMigrations);
end;

function Migrate(const ADb: TSqliteDb;
  const AMigrations: TSqliteMigrations): Integer;
begin
  Result := nextpas.core.db.sqlite.Migrate(ADb, AMigrations);
end;

function MigrationVersion(const ADb: TSqliteDb): Int64;
begin
  Result := nextpas.core.db.sqlite.MigrationVersion(ADb);
end;

end.
