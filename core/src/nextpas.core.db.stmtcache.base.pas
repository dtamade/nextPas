unit nextpas.core.db.stmtcache.base;

{$I nextpas.core.settings.inc}

interface

const
  DB_STMT_CACHE_DEFAULT_CAPACITY = 64;
  DB_STMT_CACHE_DISABLED = 0;
  DB_STMT_CACHE_PG_NAME_PREFIX = 'np_db_stmt_';

type
  TDbStmtCacheKind = (sckSqliteLRU, sckPgRegistry);

implementation

end.
