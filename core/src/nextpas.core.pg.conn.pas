unit nextpas.core.pg.conn;

{** @desc DEPRECATED 兼容 shim —— 已迁入 nextpas.core.db.pg.conn。
       新代码请使用 nextpas.core.db.* 家族（见 core/docs/db/CONTRACT.md）。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.text.conv,
  nextpas.core.db.pg.base,
  nextpas.core.db.pg.ffi,
  nextpas.core.db.pg.loader,
  nextpas.core.db.pg.conn;

type
  TPgQuery = nextpas.core.db.pg.conn.TPgQuery;
  TPgConn  = nextpas.core.db.pg.conn.TPgConn;

function PgOpen(const AConnInfo: string): TPgConn; inline;

implementation

function PgOpen(const AConnInfo: string): TPgConn;
begin
  Result := nextpas.core.db.pg.conn.PgOpen(AConnInfo);
end;

end.
