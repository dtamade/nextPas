unit nextpas.core.db.async.base;

{$I nextpas.core.settings.inc}

interface

const
  DB_ASYNC_MAX_INFLIGHT = 1;
  DB_ASYNC_PUMP_TICK_DEFAULT_MS = 50;
  DB_ASYNC_QUEUE_DEFAULT_CAPACITY = 1024;
  DB_ASYNC_MAX_FRAME_BYTES = 16 * 1024 * 1024;

type
  TDbAsyncKind = (akQuery, akListen, akSubscribe);

implementation

end.
