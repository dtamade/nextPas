unit nextpas.core.http.middleware.serverheader;
{**
 * @desc Server header middleware. Adds a standard "Server" response header
 *       to every response, identifying the server software.
 *
 *       RFC 9110 §10.3: The Server header field contains information about
 *       the software used by the origin server to handle the request.
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.http.intf;

{** @desc Add "Server: nextpas" header to every response. }
function ServerHeaderMiddleware: IHttpMiddleware;

{** @desc Add "Server: <ACustomName>" header to every response. }
function ServerHeaderMiddlewareWith(const ACustomName: string): IHttpMiddleware;

implementation

uses
  nextpas.core.http.middleware;

function ServerHeaderMiddleware: IHttpMiddleware;
begin
  Result := ServerHeaderMiddlewareWith('nextpas');
end;

function ServerHeaderMiddlewareWith(const ACustomName: string): IHttpMiddleware;
var
  LName: string;
begin
  LName := ACustomName;
  Result := MiddlewareFunc(function(const ANext: IHttpHandler): IHttpHandler
  begin
    Result := HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      AW.GetHeaders.SetHeader('server', LName);
      ANext.ServeHTTP(AReq, AW);
    end);
  end);
end;

end.
