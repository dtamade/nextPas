unit nextpas.core.http.middleware.healthcheck;
{**
 * @desc Health check middleware. Intercepts requests to a configurable health
 *       check endpoint and returns 200 OK without invoking the handler.
 *       Commonly used for load balancer and container orchestrator probes.
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.http.base,
  nextpas.core.http.intf;

{** @desc Create middleware that responds to GET /healthz with 200 OK.
   Returns an application/json body reporting ok status. }
function HealthCheckMiddleware: IHttpMiddleware;

{** @desc Create middleware that responds to GET APath with 200 OK.
   APath defaults to '/healthz' if empty. }
function HealthCheckMiddlewareAt(const APath: string): IHttpMiddleware;

implementation

uses
  nextpas.core.http.middleware;

function HealthCheckMiddleware: IHttpMiddleware;
begin
  Result := HealthCheckMiddlewareAt('/healthz');
end;

function HealthCheckMiddlewareAt(const APath: string): IHttpMiddleware;
var
  LPath: string;
begin
  LPath := APath;
  if LPath = '' then
    LPath := '/healthz';

  Result := MiddlewareFunc(function(const ANext: IHttpHandler): IHttpHandler
  begin
    Result := HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      if (AReq.GetMethod = hmGet) and (AReq.GetPath = LPath) then
      begin
        AW.GetHeaders.SetHeader('content-type', 'application/json');
        AW.WriteHeader(HTTP_STATUS_OK);
        AW.Write('{"status":"ok"}'[1], 15);
      end
      else
        ANext.ServeHTTP(AReq, AW);
    end);
  end);
end;

end.
