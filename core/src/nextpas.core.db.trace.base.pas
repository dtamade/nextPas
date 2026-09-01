unit nextpas.core.db.trace.base;

{$I nextpas.core.settings.inc}

interface

const
  DB_TRACE_SQL_SUMMARY_MAX = 512;

type
  TDbTraceEventKind = (tekAcquire, tekQuery, tekError, tekRelease);

implementation

end.
