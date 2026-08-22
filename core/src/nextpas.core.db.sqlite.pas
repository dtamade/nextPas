unit nextpas.core.db.sqlite;

{** @desc SQLite L2 facade: re-exports the friendly surface.
       Usage:
         Db := SqliteOpen(APath);          // or TSqliteDb.Create(':memory:')
         Db.Exec('CREATE TABLE t (id INTEGER PRIMARY KEY, v TEXT)');
         Q := Db.Query('SELECT v FROM t WHERE id = ?');
         Q.BindInt64(1, 42);
         while Q.Step do ...                 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.sqlite.base,
  nextpas.core.sqlite.conn,
  nextpas.core.sqlite.pool,
  nextpas.core.sqlite.tx,
  nextpas.core.sqlite.migrate;

type
  { conn }
  ESqliteError = nextpas.core.sqlite.conn.ESqliteError;
  TSqliteDb = nextpas.core.sqlite.conn.TSqliteDb;
  TSqliteQuery = nextpas.core.sqlite.conn.TSqliteQuery;

  { pool }
  ESqlitePoolError = nextpas.core.sqlite.pool.ESqlitePoolError;
  TSqlitePool = nextpas.core.sqlite.pool.TSqlitePool;

  { tx }
  ESqliteTxError = nextpas.core.sqlite.tx.ESqliteTxError;
  TSqliteTxProc = nextpas.core.sqlite.tx.TSqliteTxProc;

  { migrate }
  ESqliteMigrateError = nextpas.core.sqlite.migrate.ESqliteMigrateError;
  TSqliteMigration = nextpas.core.sqlite.migrate.TSqliteMigration;
  TSqliteMigrations = nextpas.core.sqlite.migrate.TSqliteMigrations;

const
  SQLITE_OK = nextpas.core.sqlite.base.SQLITE_OK;
  SQLITE_ROW = nextpas.core.sqlite.base.SQLITE_ROW;
  SQLITE_DONE = nextpas.core.sqlite.base.SQLITE_DONE;
  SQLITE_INTEGER = nextpas.core.sqlite.base.SQLITE_INTEGER;
  SQLITE_FLOAT = nextpas.core.sqlite.base.SQLITE_FLOAT;
  SQLITE_TEXT = nextpas.core.sqlite.base.SQLITE_TEXT;
  SQLITE_BLOB = nextpas.core.sqlite.base.SQLITE_BLOB;
  SQLITE_NULL = nextpas.core.sqlite.base.SQLITE_NULL;
  SQLITE_CONSTRAINT = nextpas.core.sqlite.base.SQLITE_CONSTRAINT;
  SQLITE_CONSTRAINT_CHECK = nextpas.core.sqlite.base.SQLITE_CONSTRAINT_CHECK;
  SQLITE_CONSTRAINT_COMMITHOOK = nextpas.core.sqlite.base.SQLITE_CONSTRAINT_COMMITHOOK;
  SQLITE_CONSTRAINT_FOREIGNKEY = nextpas.core.sqlite.base.SQLITE_CONSTRAINT_FOREIGNKEY;
  SQLITE_CONSTRAINT_FUNCTION = nextpas.core.sqlite.base.SQLITE_CONSTRAINT_FUNCTION;
  SQLITE_CONSTRAINT_NOTNULL = nextpas.core.sqlite.base.SQLITE_CONSTRAINT_NOTNULL;
  SQLITE_CONSTRAINT_PRIMARYKEY = nextpas.core.sqlite.base.SQLITE_CONSTRAINT_PRIMARYKEY;
  SQLITE_CONSTRAINT_TRIGGER = nextpas.core.sqlite.base.SQLITE_CONSTRAINT_TRIGGER;
  SQLITE_CONSTRAINT_UNIQUE = nextpas.core.sqlite.base.SQLITE_CONSTRAINT_UNIQUE;
  SQLITE_CONSTRAINT_VTAB = nextpas.core.sqlite.base.SQLITE_CONSTRAINT_VTAB;
  SQLITE_CONSTRAINT_ROWID = nextpas.core.sqlite.base.SQLITE_CONSTRAINT_ROWID;
  SQLITE_CONSTRAINT_PINNED = nextpas.core.sqlite.base.SQLITE_CONSTRAINT_PINNED;
  SQLITE_CONSTRAINT_DATATYPE = nextpas.core.sqlite.base.SQLITE_CONSTRAINT_DATATYPE;
  SQLITE_MIGRATIONS_TABLE = nextpas.core.sqlite.migrate.SQLITE_MIGRATIONS_TABLE;

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
  Result := nextpas.core.sqlite.conn.SqliteOpen(APath);
end;

procedure WithTransaction(const ADb: TSqliteDb;
  const AProc: TSqliteTxProc);
begin
  nextpas.core.sqlite.tx.WithTransaction(ADb, AProc);
end;

procedure BeginTxn(const ADb: TSqliteDb; const AImmediate: Boolean);
begin
  nextpas.core.sqlite.tx.BeginTxn(ADb, AImmediate);
end;

procedure CommitTxn(const ADb: TSqliteDb);
begin
  nextpas.core.sqlite.tx.CommitTxn(ADb);
end;

procedure RollbackTxn(const ADb: TSqliteDb);
begin
  nextpas.core.sqlite.tx.RollbackTxn(ADb);
end;

function InTransaction(const ADb: TSqliteDb): Boolean;
begin
  Result := nextpas.core.sqlite.tx.InTransaction(ADb);
end;

function TxDepth(const ADb: TSqliteDb): Integer;
begin
  Result := nextpas.core.sqlite.tx.TxDepth(ADb);
end;

function MakeMigrations(const AMigrations: array of TSqliteMigration): TSqliteMigrations;
begin
  Result := nextpas.core.sqlite.migrate.MakeMigrations(AMigrations);
end;

function Migrate(const ADb: TSqliteDb;
  const AMigrations: TSqliteMigrations): Integer;
begin
  Result := nextpas.core.sqlite.migrate.Migrate(ADb, AMigrations);
end;

function MigrationVersion(const ADb: TSqliteDb): Int64;
begin
  Result := nextpas.core.sqlite.migrate.MigrationVersion(ADb);
end;

end.
