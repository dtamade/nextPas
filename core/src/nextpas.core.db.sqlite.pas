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
  nextpas.core.db.sqlite.base,
  nextpas.core.db.sqlite.conn,
  nextpas.core.db.sqlite.tx;

type
  { conn }
  ESqliteError = nextpas.core.db.sqlite.conn.ESqliteError;
  TSqliteDb = nextpas.core.db.sqlite.conn.TSqliteDb;
  TSqliteQuery = nextpas.core.db.sqlite.conn.TSqliteQuery;

  { tx }
  ESqliteTxError = nextpas.core.db.sqlite.tx.ESqliteTxError;
  TSqliteTxProc = nextpas.core.db.sqlite.tx.TSqliteTxProc;

const
  SQLITE_OK = nextpas.core.db.sqlite.base.SQLITE_OK;
  SQLITE_ROW = nextpas.core.db.sqlite.base.SQLITE_ROW;
  SQLITE_DONE = nextpas.core.db.sqlite.base.SQLITE_DONE;
  SQLITE_INTEGER = nextpas.core.db.sqlite.base.SQLITE_INTEGER;
  SQLITE_FLOAT = nextpas.core.db.sqlite.base.SQLITE_FLOAT;
  SQLITE_TEXT = nextpas.core.db.sqlite.base.SQLITE_TEXT;
  SQLITE_BLOB = nextpas.core.db.sqlite.base.SQLITE_BLOB;
  SQLITE_NULL = nextpas.core.db.sqlite.base.SQLITE_NULL;
  SQLITE_CONSTRAINT = nextpas.core.db.sqlite.base.SQLITE_CONSTRAINT;
  SQLITE_CONSTRAINT_CHECK = nextpas.core.db.sqlite.base.SQLITE_CONSTRAINT_CHECK;
  SQLITE_CONSTRAINT_COMMITHOOK = nextpas.core.db.sqlite.base.SQLITE_CONSTRAINT_COMMITHOOK;
  SQLITE_CONSTRAINT_FOREIGNKEY = nextpas.core.db.sqlite.base.SQLITE_CONSTRAINT_FOREIGNKEY;
  SQLITE_CONSTRAINT_FUNCTION = nextpas.core.db.sqlite.base.SQLITE_CONSTRAINT_FUNCTION;
  SQLITE_CONSTRAINT_NOTNULL = nextpas.core.db.sqlite.base.SQLITE_CONSTRAINT_NOTNULL;
  SQLITE_CONSTRAINT_PRIMARYKEY = nextpas.core.db.sqlite.base.SQLITE_CONSTRAINT_PRIMARYKEY;
  SQLITE_CONSTRAINT_TRIGGER = nextpas.core.db.sqlite.base.SQLITE_CONSTRAINT_TRIGGER;
  SQLITE_CONSTRAINT_UNIQUE = nextpas.core.db.sqlite.base.SQLITE_CONSTRAINT_UNIQUE;
  SQLITE_CONSTRAINT_VTAB = nextpas.core.db.sqlite.base.SQLITE_CONSTRAINT_VTAB;
  SQLITE_CONSTRAINT_ROWID = nextpas.core.db.sqlite.base.SQLITE_CONSTRAINT_ROWID;
  SQLITE_CONSTRAINT_PINNED = nextpas.core.db.sqlite.base.SQLITE_CONSTRAINT_PINNED;
  SQLITE_CONSTRAINT_DATATYPE = nextpas.core.db.sqlite.base.SQLITE_CONSTRAINT_DATATYPE;

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

implementation

function SqliteOpen(const APath: string): TSqliteDb;
begin
  Result := nextpas.core.db.sqlite.conn.SqliteOpen(APath);
end;

procedure WithTransaction(const ADb: TSqliteDb;
  const AProc: TSqliteTxProc);
begin
  nextpas.core.db.sqlite.tx.WithTransaction(ADb, AProc);
end;

procedure BeginTxn(const ADb: TSqliteDb; const AImmediate: Boolean);
begin
  nextpas.core.db.sqlite.tx.BeginTxn(ADb, AImmediate);
end;

procedure CommitTxn(const ADb: TSqliteDb);
begin
  nextpas.core.db.sqlite.tx.CommitTxn(ADb);
end;

procedure RollbackTxn(const ADb: TSqliteDb);
begin
  nextpas.core.db.sqlite.tx.RollbackTxn(ADb);
end;

function InTransaction(const ADb: TSqliteDb): Boolean;
begin
  Result := nextpas.core.db.sqlite.tx.InTransaction(ADb);
end;

function TxDepth(const ADb: TSqliteDb): Integer;
begin
  Result := nextpas.core.db.sqlite.tx.TxDepth(ADb);
end;

end.
