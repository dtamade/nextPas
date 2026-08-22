unit nextpas.core.pg.base;

{** @desc DEPRECATED 兼容 shim —— 已迁入 nextpas.core.db.pg.base。
       新代码请使用 nextpas.core.db.* 家族（见 core/docs/db/CONTRACT.md）。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.exception,
  nextpas.core.db.pg.base;

const
  CONNECTION_OK  = nextpas.core.db.pg.base.CONNECTION_OK;
  CONNECTION_BAD = nextpas.core.db.pg.base.CONNECTION_BAD;
  PGRES_EMPTY_QUERY    = nextpas.core.db.pg.base.PGRES_EMPTY_QUERY;
  PGRES_COMMAND_OK     = nextpas.core.db.pg.base.PGRES_COMMAND_OK;
  PGRES_TUPLES_OK      = nextpas.core.db.pg.base.PGRES_TUPLES_OK;
  PGRES_COPY_OUT       = nextpas.core.db.pg.base.PGRES_COPY_OUT;
  PGRES_COPY_IN        = nextpas.core.db.pg.base.PGRES_COPY_IN;
  PGRES_BAD_RESPONSE   = nextpas.core.db.pg.base.PGRES_BAD_RESPONSE;
  PGRES_NONFATAL_ERROR = nextpas.core.db.pg.base.PGRES_NONFATAL_ERROR;
  PGRES_FATAL_ERROR    = nextpas.core.db.pg.base.PGRES_FATAL_ERROR;
  PG_DIAG_SEVERITY        = nextpas.core.db.pg.base.PG_DIAG_SEVERITY;
  PG_DIAG_SQLSTATE        = nextpas.core.db.pg.base.PG_DIAG_SQLSTATE;
  PG_DIAG_MESSAGE_PRIMARY = nextpas.core.db.pg.base.PG_DIAG_MESSAGE_PRIMARY;
  PG_DIAG_DETAIL          = nextpas.core.db.pg.base.PG_DIAG_DETAIL;
  PG_DIAG_HINT            = nextpas.core.db.pg.base.PG_DIAG_HINT;
  PG_LIBRARY_NAME = nextpas.core.db.pg.base.PG_LIBRARY_NAME;

type
  PGconn   = nextpas.core.db.pg.base.PGconn;
  PGresult = nextpas.core.db.pg.base.PGresult;
  EPgError = nextpas.core.db.pg.base.EPgError;

implementation

end.
