unit nextpas.core.http.middleware.timeout;
{**
 * @desc Response-time middleware. Records handler elapsed time in the
 *       X-Response-Time header. TimeoutMiddleware is kept as a deprecated
 *       alias for backward compatibility.
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.http.intf;

function ResponseTimeMiddleware: IHttpMiddleware;
function TimeoutMiddleware: IHttpMiddleware; deprecated 'use ResponseTimeMiddleware';

implementation

uses
  nextpas.core.http.middleware,
  nextpas.core.time.base,
  nextpas.core.text.conv;

function ResponseTimeMiddleware: IHttpMiddleware;
begin
  Result := MiddlewareFunc(function(const ANext: IHttpHandler): IHttpHandler
  begin
    Result := HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    var
      LStart: TInstant;
      LElapsed: TDuration;
      LMs: Int64;
    begin
      LStart := TInstant.Now;
      ANext.ServeHTTP(AReq, AW);
      LElapsed := LStart.Elapsed;
      LMs := LElapsed.AsMilliseconds;
      AW.Headers.SetHeader('X-Response-Time', IntToStr(LMs) + 'ms');
    end);
  end);
end;

function TimeoutMiddleware: IHttpMiddleware;
begin
  Result := ResponseTimeMiddleware;
end;

end.
