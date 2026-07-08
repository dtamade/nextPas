unit nextpas.core.http.middleware.recovery;

{$I nextpas.core.settings.inc}

interface

uses
  SysUtils,
  nextpas.core.http.intf;

type
  {** Callback invoked when RecoveryMiddleware catches an exception.
     Use this to log panics, send alerts, etc. The middleware always
     returns 500 to the client regardless of the callback. }
  TRecoveryCallback = reference to procedure(E: Exception);

{** Catch panics and return 500 (silent — no error logging). }
function RecoveryMiddleware: IHttpMiddleware;

{** Catch panics and return 500, calling AOnError for each caught exception.
   Pass nil for silent behavior (same as RecoveryMiddleware). }
function RecoveryMiddlewareWith(const AOnError: TRecoveryCallback): IHttpMiddleware;

implementation

uses
  nextpas.core.errors,
  nextpas.core.http.base,
  nextpas.core.http.middleware;

function RecoveryMiddleware: IHttpMiddleware;
begin
  Result := RecoveryMiddlewareWith(nil);
end;

function RecoveryMiddlewareWith(const AOnError: TRecoveryCallback): IHttpMiddleware;
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
          if Assigned(AOnError) then
            AOnError(E);
          LMsg := 'Internal Server Error';
          AW.WriteHeader(HTTP_STATUS_INTERNAL_SERVER_ERROR);
          AW.Write(LMsg[1], Length(LMsg));
        end;
      end;
    end);
  end);
end;

end.
