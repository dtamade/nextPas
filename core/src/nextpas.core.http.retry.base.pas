unit nextpas.core.http.retry.base;

{$I nextpas.core.settings.inc}

interface

const
  HTTP_RETRY_BASE_MS = 100;
  HTTP_RETRY_CAP_MS = 5000;
  HTTP_RETRY_AFTER_CAP_S = 60;
  HTTP_RETRY_SLICE_MS = 100;

type
  TRetryPolicy = record
    MaxAttempts: Int32;
    BaseMs: Int32;
    CapMs: Int32;
    SliceMs: Int32;
    class function Default: TRetryPolicy; static; inline;
  end;

implementation

class function TRetryPolicy.Default: TRetryPolicy; static; inline;
begin
  Result.MaxAttempts := 3;
  Result.BaseMs := HTTP_RETRY_BASE_MS;
  Result.CapMs := HTTP_RETRY_CAP_MS;
  Result.SliceMs := HTTP_RETRY_SLICE_MS;
end;

end.
