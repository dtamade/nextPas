unit nextpas.core.http.middleware.logger;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.http.intf,
  nextpas.core.log;

{ Default logger middleware — uses structured TLogger with method, path, status, duration }
function LoggerMiddleware: IHttpMiddleware;

{ Logger middleware with structured logging via TLogger }
function LoggerMiddlewareWith(const ALogger: TLogger): IHttpMiddleware;

implementation

uses
  nextpas.core.http.base,
  nextpas.core.http.middleware,
  nextpas.core.time.base,
  nextpas.core.text.conv;

function LoggerMiddleware: IHttpMiddleware;
begin
  Result := LoggerMiddlewareWith(DefaultLogger);
end;

function LoggerMiddlewareWith(const ALogger: TLogger): IHttpMiddleware;
begin
  Result := MiddlewareFunc(function(const ANext: IHttpHandler): IHttpHandler
  begin
    Result := HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    var
      LStart: TInstant;
      LDuration: TDuration;
      LEvent: PLogEvent;
    begin
      LStart := TInstant.Now;
      ANext.ServeHTTP(AReq, AW);
      LDuration := LStart.Elapsed;
      LEvent := ALogger.Info;
      LEvent^.Str('method', HttpMethodToStr(AReq.Method));
      LEvent^.Str('path', AReq.Path);
      LEvent^.Int('status', Int64(AW.GetStatus));
      LEvent^.Str('duration', LDuration.ToString);
      LEvent^.Msg('http_request');
    end);
  end);
end;

end.
