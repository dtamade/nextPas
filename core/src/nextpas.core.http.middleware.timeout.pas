unit nextpas.core.http.middleware.timeout;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.http.intf,
  nextpas.core.time.base;

function TimeoutMiddleware(const ATimeout: TDuration): IHttpMiddleware;

implementation

uses
  nextpas.core.http.base,
  nextpas.core.http.middleware,
  nextpas.core.text.conv;

function TimeoutMiddleware(const ATimeout: TDuration): IHttpMiddleware;
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
      AW.Headers.Set_('X-Response-Time', IntToStr(LMs) + 'ms');
      if LElapsed > ATimeout then
        WriteLn('[WARN] Handler exceeded timeout: ', LElapsed.ToString,
                ' > ', ATimeout.ToString, ' for ', AReq.Url.Path);
    end);
  end);
end;

end.
