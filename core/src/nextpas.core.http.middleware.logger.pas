unit nextpas.core.http.middleware.logger;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.http.intf;

function LoggerMiddleware: IHttpMiddleware;

implementation

uses
  nextpas.core.http.base,
  nextpas.core.http.middleware,
  nextpas.core.time.base,
  nextpas.core.text.conv;

function LoggerMiddleware: IHttpMiddleware;
begin
  Result := MiddlewareFunc(function(const ANext: IHttpHandler): IHttpHandler
  begin
    Result := HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    var
      LStart: TInstant;
      LDuration: TDuration;
    begin
      LStart := TInstant.Now;
      ANext.ServeHTTP(AReq, AW);
      LDuration := LStart.Elapsed;
      WriteLn(HttpMethodToStr(AReq.Method), ' ', AReq.Url.Path,
              ' ', AW.GetStatus, ' ', LDuration.ToString);
    end);
  end);
end;

end.
