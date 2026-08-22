unit nextpas.core.db.pg;

{** @desc PostgreSQL L2 facade: re-exports the friendly surface.
       Usage:
         Conn := PgOpen('host=/var/run/postgresql dbname=myapp user=app');
         Conn.Exec('CREATE TABLE t (id BIGINT PRIMARY KEY, v TEXT)');
         Q := Conn.Query('SELECT v FROM t WHERE id = $1');
         Q.BindInt64(1, 42);
         while Q.Step do ... *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.pg.base,
  nextpas.core.pg.conn;

type
  EPgError = nextpas.core.pg.base.EPgError;
  TPgConn  = nextpas.core.pg.conn.TPgConn;
  TPgQuery = nextpas.core.pg.conn.TPgQuery;

const
  CONNECTION_OK        = nextpas.core.pg.base.CONNECTION_OK;
  CONNECTION_BAD       = nextpas.core.pg.base.CONNECTION_BAD;
  PGRES_EMPTY_QUERY    = nextpas.core.pg.base.PGRES_EMPTY_QUERY;
  PGRES_COMMAND_OK     = nextpas.core.pg.base.PGRES_COMMAND_OK;
  PGRES_TUPLES_OK      = nextpas.core.pg.base.PGRES_TUPLES_OK;
  PGRES_FATAL_ERROR    = nextpas.core.pg.base.PGRES_FATAL_ERROR;

function PgOpen(const AConnInfo: string): TPgConn; inline;

implementation

function PgOpen(const AConnInfo: string): TPgConn;
begin
  Result := nextpas.core.pg.conn.PgOpen(AConnInfo);
end;

end.