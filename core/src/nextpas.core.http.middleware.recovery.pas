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
var
  LBody: string;
begin
  LBody := 'Internal Server Error';
  Result := MiddlewareFunc(function(const ANext: IHttpHandler): IHttpHandler
  begin
    Result := HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      try
        ANext.ServeHTTP(AReq, AW);
      except
        on E: Exception do
        begin
          AW.WriteHeader(HTTP_STATUS_INTERNAL_SERVER_ERROR);
          if Length(LBody) > 0 then
            AW.Write(LBody[1], Length(LBody));
        end;
      end;
    end);
  end);
end;

end.
