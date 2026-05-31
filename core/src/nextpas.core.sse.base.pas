unit nextpas.core.sse.base;
{$I nextpas.core.settings.inc}

interface

type
  TSseEvent = record
    EventType: string;
    Data: string;
    Id: string;
    RetryMs: Int32;
    HasRetry: Boolean;
  end;
  TSseEventArray = array of TSseEvent;

implementation

end.
