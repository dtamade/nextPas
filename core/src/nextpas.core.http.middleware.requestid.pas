unit nextpas.core.http.middleware.requestid;
{**
 * @desc Request ID middleware. Ensures every request/response has a unique
 *       X-Request-Id header for distributed tracing and debugging.
 *       Preserves existing X-Request-Id from proxies/clients.
 *       Generates a new UUID v4 if not present.
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.http.intf;

{** @desc Create middleware that ensures X-Request-Id header on every response.
   Preserves existing request header, generates UUID v4 if missing. }
function RequestIdMiddleware: IHttpMiddleware;

{** @desc Create middleware with custom header name (default: 'x-request-id'). }
function RequestIdMiddlewareWith(const AHeaderName: string): IHttpMiddleware;

implementation

uses
  SysUtils,
  nextpas.core.http.middleware;

function GenerateRequestId: string;
var
  LGuid: TGuid;
begin
  CreateGUID(LGuid);
  Result := GUIDToString(LGuid);
  Result := Copy(Result, 2, Length(Result) - 2);
end;

function RequestIdMiddleware: IHttpMiddleware;
begin
  Result := RequestIdMiddlewareWith('x-request-id');
end;

function RequestIdMiddlewareWith(const AHeaderName: string): IHttpMiddleware;
var
  LHeader: string;
begin
  LHeader := AHeaderName;
  if LHeader = '' then
    LHeader := 'x-request-id';

  Result := MiddlewareFunc(function(const ANext: IHttpHandler): IHttpHandler
  begin
    Result := HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    var
      LRequestId: string;
    begin
      LRequestId := AReq.GetHeaders.Get(LHeader);
      if LRequestId = '' then
        LRequestId := GenerateRequestId;
      AW.GetHeaders.SetHeader(LHeader, LRequestId);
      ANext.ServeHTTP(AReq, AW);
    end);
  end);
end;

end.
