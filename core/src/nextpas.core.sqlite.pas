unit nextpas.core.sqlite;

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
  nextpas.core.sqlite.conn;

type
  ESqliteError = nextpas.core.sqlite.conn.ESqliteError;
  TSqliteDb = nextpas.core.sqlite.conn.TSqliteDb;
  TSqliteQuery = nextpas.core.sqlite.conn.TSqliteQuery;

const
  SQLITE_OK = nextpas.core.sqlite.base.SQLITE_OK;
  SQLITE_ROW = nextpas.core.sqlite.base.SQLITE_ROW;
  SQLITE_DONE = nextpas.core.sqlite.base.SQLITE_DONE;
  SQLITE_INTEGER = nextpas.core.sqlite.base.SQLITE_INTEGER;
  SQLITE_FLOAT = nextpas.core.sqlite.base.SQLITE_FLOAT;
  SQLITE_TEXT = nextpas.core.sqlite.base.SQLITE_TEXT;
  SQLITE_BLOB = nextpas.core.sqlite.base.SQLITE_BLOB;
  SQLITE_NULL = nextpas.core.sqlite.base.SQLITE_NULL;

function SqliteOpen(const APath: string): TSqliteDb; inline;

implementation

function SqliteOpen(const APath: string): TSqliteDb;
begin
  Result := nextpas.core.sqlite.conn.SqliteOpen(APath);
end;

end.