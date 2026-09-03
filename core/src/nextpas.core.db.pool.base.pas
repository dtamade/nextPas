unit nextpas.core.db.pool.base;

{$I nextpas.core.settings.inc}

interface

const
  DB_POOL_DEFAULT_MAX_READ = 4;
  DB_POOL_DEFAULT_ACQUIRE_TIMEOUT_MS = 5000;
  DB_POOL_DEFAULT_IDLE_TIMEOUT_SEC = 60;
  DB_POOL_DEFAULT_MAX_LIFETIME_SEC = 0;
  DB_POOL_DEFAULT_MIN_CONNECTIONS = 0;
  DB_POOL_LEAK_DETECTION_DISABLED = 0;
  DB_POOL_DEBUG_STACK_FRAMES = 16;

type
  TDbPoolLeaseKind = (plkRead, plkWriter);

implementation

end.
