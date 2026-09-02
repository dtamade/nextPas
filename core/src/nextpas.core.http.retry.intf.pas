unit nextpas.core.http.retry.intf;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.http.base,
  nextpas.core.http.intf,
  nextpas.core.http.retry.base;

type
  IHttpRetryPolicy = interface
    ['{A7B8C9D0-E1F2-4A3B-8C4D-2345678901BC}']
    function ShouldRetry(const AReq: IHttpRequest; const AResp: IHttpResponse; const E: Exception; AAttempt: Int32): Boolean;
    function BackoffMs(AAttempt: Int32; const ARetryAfter: string): Int64;
  end;

function HttpIsRetrySafeRequestWrap(const AReq: IHttpRequest): Boolean; inline;
function HttpIsRetryableMethodWrap(const AMethod: THttpMethod): Boolean; inline;

implementation

uses
  nextpas.core.http.message;

function HttpIsRetrySafeRequestWrap(const AReq: IHttpRequest): Boolean; inline;
begin
  { perf: inline thin forward, single source: http.message.HttpIsRetrySafeRequest (bytes.ops for Idempotency-Key lookup zero-copy) }
  Result := nextpas.core.http.message.HttpIsRetrySafeRequest(AReq);
end;

function HttpIsRetryableMethodWrap(const AMethod: THttpMethod): Boolean; inline;
begin
  Result := nextpas.core.http.message.HttpIsRetryableMethod(AMethod);
end;

end.
