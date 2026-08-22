unit nextpas.core.sqlite.base;

{** @desc DEPRECATED 兼容 shim —— 本单元已迁入 nextpas.core.db 家族：
       新代码请使用 nextpas.core.db.sqlite.base。
       迁移与删除计划见 core/docs/db/CONTRACT.md 与
       core/docs/plans/2026-08-23-db-module-boundary.md。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.db.sqlite.base;

const
  SQLITE_OK          = nextpas.core.db.sqlite.base.SQLITE_OK;
  SQLITE_ROW         = nextpas.core.db.sqlite.base.SQLITE_ROW;
  SQLITE_DONE        = nextpas.core.db.sqlite.base.SQLITE_DONE;
  SQLITE_CONSTRAINT              = nextpas.core.db.sqlite.base.SQLITE_CONSTRAINT;
  SQLITE_CONSTRAINT_CHECK        = nextpas.core.db.sqlite.base.SQLITE_CONSTRAINT_CHECK;
  SQLITE_CONSTRAINT_COMMITHOOK   = nextpas.core.db.sqlite.base.SQLITE_CONSTRAINT_COMMITHOOK;
  SQLITE_CONSTRAINT_FOREIGNKEY   = nextpas.core.db.sqlite.base.SQLITE_CONSTRAINT_FOREIGNKEY;
  SQLITE_CONSTRAINT_FUNCTION     = nextpas.core.db.sqlite.base.SQLITE_CONSTRAINT_FUNCTION;
  SQLITE_CONSTRAINT_NOTNULL      = nextpas.core.db.sqlite.base.SQLITE_CONSTRAINT_NOTNULL;
  SQLITE_CONSTRAINT_PRIMARYKEY   = nextpas.core.db.sqlite.base.SQLITE_CONSTRAINT_PRIMARYKEY;
  SQLITE_CONSTRAINT_TRIGGER      = nextpas.core.db.sqlite.base.SQLITE_CONSTRAINT_TRIGGER;
  SQLITE_CONSTRAINT_UNIQUE       = nextpas.core.db.sqlite.base.SQLITE_CONSTRAINT_UNIQUE;
  SQLITE_CONSTRAINT_VTAB         = nextpas.core.db.sqlite.base.SQLITE_CONSTRAINT_VTAB;
  SQLITE_CONSTRAINT_ROWID        = nextpas.core.db.sqlite.base.SQLITE_CONSTRAINT_ROWID;
  SQLITE_CONSTRAINT_PINNED       = nextpas.core.db.sqlite.base.SQLITE_CONSTRAINT_PINNED;
  SQLITE_CONSTRAINT_DATATYPE     = nextpas.core.db.sqlite.base.SQLITE_CONSTRAINT_DATATYPE;
  SQLITE_OPEN_READONLY  = nextpas.core.db.sqlite.base.SQLITE_OPEN_READONLY;
  SQLITE_OPEN_READWRITE = nextpas.core.db.sqlite.base.SQLITE_OPEN_READWRITE;
  SQLITE_OPEN_CREATE    = nextpas.core.db.sqlite.base.SQLITE_OPEN_CREATE;
  SQLITE_OPEN_URI       = nextpas.core.db.sqlite.base.SQLITE_OPEN_URI;
  SQLITE_OPEN_MEMORY    = nextpas.core.db.sqlite.base.SQLITE_OPEN_MEMORY;
  SQLITE_OPEN_NOMUTEX   = nextpas.core.db.sqlite.base.SQLITE_OPEN_NOMUTEX;
  SQLITE_OPEN_FULLMUTEX = nextpas.core.db.sqlite.base.SQLITE_OPEN_FULLMUTEX;
  SQLITE_INTEGER = nextpas.core.db.sqlite.base.SQLITE_INTEGER;
  SQLITE_FLOAT   = nextpas.core.db.sqlite.base.SQLITE_FLOAT;
  SQLITE_TEXT    = nextpas.core.db.sqlite.base.SQLITE_TEXT;
  SQLITE_BLOB    = nextpas.core.db.sqlite.base.SQLITE_BLOB;
  SQLITE_NULL    = nextpas.core.db.sqlite.base.SQLITE_NULL;
  SQLITE_STATIC    = nextpas.core.db.sqlite.base.SQLITE_STATIC;
  SQLITE_TRANSIENT = nextpas.core.db.sqlite.base.SQLITE_TRANSIENT;

type
  TSqliteHandle = nextpas.core.db.sqlite.base.TSqliteHandle;
  TSqliteStmt   = nextpas.core.db.sqlite.base.TSqliteStmt;
  TSqliteValue  = nextpas.core.db.sqlite.base.TSqliteValue;

implementation

end.
