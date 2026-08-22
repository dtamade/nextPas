unit nextpas.core.sqlite.conn;

{** @desc DEPRECATED 兼容 shim —— 已迁入 nextpas.core.db.sqlite.conn。
       新代码请使用 nextpas.core.db.* 家族（见 core/docs/db/CONTRACT.md）。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.exception,
  nextpas.core.db.sqlite.base,
  nextpas.core.db.sqlite.conn;

type
  ESqliteError  = nextpas.core.db.sqlite.conn.ESqliteError;
  TSqliteQuery  = nextpas.core.db.sqlite.conn.TSqliteQuery;
  TSqliteDb     = nextpas.core.db.sqlite.conn.TSqliteDb;

function SqliteOpen(const APath: string): TSqliteDb; inline;

implementation

function SqliteOpen(const APath: string): TSqliteDb;
begin
  Result := nextpas.core.db.sqlite.conn.SqliteOpen(APath);
end;

end.
