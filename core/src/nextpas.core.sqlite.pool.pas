unit nextpas.core.sqlite.pool;

{** @desc DEPRECATED 兼容 shim —— 已迁入 nextpas.core.db.sqlite.pool。
       新代码请使用 nextpas.core.db.* 家族（见 core/docs/db/CONTRACT.md）。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.exception,
  nextpas.core.db.sqlite.base,
  nextpas.core.db.sqlite.conn,
  nextpas.core.db.sqlite.pool;

type
  ESqlitePoolError = nextpas.core.db.sqlite.pool.ESqlitePoolError;
  TSqlitePool      = nextpas.core.db.sqlite.pool.TSqlitePool;

implementation

end.
