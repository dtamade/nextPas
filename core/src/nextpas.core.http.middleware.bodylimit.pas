unit nextpas.core.http.middleware.bodylimit;
{**
 * @desc Request body size limit middleware. Rejects requests with
 *       Content-Length exceeding the configured maximum with 413 Payload Too Large.
 *       Requests without Content-Length or with Content-Length <= limit pass through.
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.http.intf;

{** @desc Create middleware that rejects requests with body larger than AMaxBytes.
   Returns 413 Payload Too Large if Content-Length exceeds the limit.
   Requests without Content-Length pass through (assumed no body or chunked). }
function BodyLimitMiddleware(const AMaxBytes: Int64): IHttpMiddleware;

implementation

uses
  nextpas.core.base,
  nextpas.core.errors,
  nextpas.core.http.base,
  nextpas.core.http.middleware,
  nextpas.core.http.message;

function BodyLimitMiddleware(const AMaxBytes: Int64): IHttpMiddleware;
begin
  if AMaxBytes < 0 then
    raise EArgumentError.Create('body limit must not be negative');

  Result := MiddlewareFunc(function(const ANext: IHttpHandler): IHttpHandler
  begin
    Result := HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    var
      LContentLength: Int64;
    begin
      LContentLength := AReq.ContentLength;
      if (LContentLength > 0) and (LContentLength > AMaxBytes) then
      begin
        HttpWriteErrorPayloadTooLarge(AW, 'Request body too large');
        Exit;
      end;
      ANext.ServeHTTP(AReq, AW);
    end);
  end);
end;

end.
