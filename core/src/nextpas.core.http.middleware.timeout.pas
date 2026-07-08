unit nextpas.core.http.middleware.timeout;
{**
 * @desc Response-time middleware. Records handler elapsed time in the
 *       X-Response-Time header.
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.http.intf;

function ResponseTimeMiddleware: IHttpMiddleware;

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

end.
