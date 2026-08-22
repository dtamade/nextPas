unit nextpas.core.pg;

{** @desc DEPRECATED 兼容 shim —— PostgreSQL 家族已收编进 nextpas.core.db。
       新代码请使用 nextpas.core.db（统一入口）或
       nextpas.core.db.pg（PostgreSQL 后端门面）。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.exception,
  nextpas.core.db.pg;

type
  EPgError = nextpas.core.db.pg.EPgError;
  TPgConn  = nextpas.core.db.pg.TPgConn;
  TPgQuery = nextpas.core.db.pg.TPgQuery;

const
  CONNECTION_OK        = nextpas.core.db.pg.CONNECTION_OK;
  CONNECTION_BAD       = nextpas.core.db.pg.CONNECTION_BAD;
  PGRES_EMPTY_QUERY    = nextpas.core.db.pg.PGRES_EMPTY_QUERY;
  PGRES_COMMAND_OK     = nextpas.core.db.pg.PGRES_COMMAND_OK;
  PGRES_TUPLES_OK      = nextpas.core.db.pg.PGRES_TUPLES_OK;
  PGRES_FATAL_ERROR    = nextpas.core.db.pg.PGRES_FATAL_ERROR;

function PgOpen(const AConnInfo: string): TPgConn; inline;

implementation

function PgOpen(const AConnInfo: string): TPgConn;
begin
  Result := nextpas.core.db.pg.PgOpen(AConnInfo);
end;

end.
