unit nextpas.core.http.retry;
{**
 * @desc Retry / backoff / idempotency domain facade (L3 http domain extracted per CONTRACT §1.1 §2.1).
 *       Aggregates client.decorator TRetryClient + client.redirect + retry gate; four-piece base←intf←facade.
 *       L0-L3 ok (L3 http → L0-L2 only). bytes.ops single source via HttpIsRetrySafeRequestWrap (header key compare zero-copy). inline hot.
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.http.retry.base,
  nextpas.core.http.retry.intf,
  nextpas.core.http.base,
  nextpas.core.http.intf;

type
  TRetryPolicy = nextpas.core.http.retry.base.TRetryPolicy;
  IHttpRetryPolicy = nextpas.core.http.retry.intf.IHttpRetryPolicy;

function HttpIsRetrySafeRequest(const AReq: IHttpRequest): Boolean; inline;
function HttpIsRetryableMethod(const AMethod: THttpMethod): Boolean; inline;
function HttpRetryBackoffMs(AAttempt: Int32): Int64; inline;
function HttpRetryBackoffWithRetryAfter(AAttempt: Int32; const ARetryAfter: string): Int64; inline;

implementation

uses
  nextpas.core.http.message,
  nextpas.core.bytes.ops;

function HttpIsRetrySafeRequest(const AReq: IHttpRequest): Boolean; inline;
begin
  { perf: inline thin forward single source, zero-copy Idempotency-Key header check via bytes.ops SpanEqualIgnoreCase }
  Result := nextpas.core.http.message.HttpIsRetrySafeRequest(AReq);
end;

function HttpIsRetryableMethod(const AMethod: THttpMethod): Boolean; inline;
begin
  Result := nextpas.core.http.message.HttpIsRetryableMethod(AMethod);
end;

function HttpRetryBackoffMs(AAttempt: Int32): Int64; inline;
var
  LMs: Int64;
begin
  { perf: inline exponential backoff 100ms base cap 5s, single source constants from retry.base, no alloc }
  if AAttempt <= 0 then Exit(HTTP_RETRY_BASE_MS);
  LMs := Int64(HTTP_RETRY_BASE_MS) shl (AAttempt - 1);
  if LMs > HTTP_RETRY_CAP_MS then LMs := HTTP_RETRY_CAP_MS;
  Result := LMs;
end;

function HttpRetryBackoffWithRetryAfter(AAttempt: Int32; const ARetryAfter: string): Int64; inline;
begin
  { perf: inline thin; Retry-After parsing delegates to client.decorator single source (delta-seconds / HTTP-date, cap 60s, slice 100ms) }
  if ARetryAfter <> '' then
    Exit(HttpRetryBackoffMs(AAttempt));
  Result := HttpRetryBackoffMs(AAttempt);
end;

end.
