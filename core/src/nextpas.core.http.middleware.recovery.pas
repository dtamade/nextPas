unit nextpas.core.http.middleware.recovery;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.http.intf;

function RecoveryMiddleware: IHttpMiddleware;

implementation

uses
  nextpas.core.errors,
  nextpas.core.http.base,
  nextpas.core.http.middleware;

function RecoveryMiddleware: IHttpMiddleware;
begin
  Result := MiddlewareFunc(function(const ANext: IHttpHandler): IHttpHandler
  begin
    Result := HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    var
      LMsg: string;
    begin
      try
        ANext.ServeHTTP(AReq, AW);
      except
        on E: Exception do
        begin
          LMsg := 'Internal Server Error';
          AW.WriteHeader(HTTP_STATUS_INTERNAL_SERVER_ERROR);
          AW.Write(LMsg[1], Length(LMsg));
        end;
      end;
    end);
  end);
end;

end.
