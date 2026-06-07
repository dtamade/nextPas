unit nextpas.core.http.middleware.cors;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.http.intf;

type
  TCorsOptions = record
    AllowOrigins: string;
    AllowMethods: string;
    AllowHeaders: string;
    MaxAge: Int32;
    AllowCredentials: Boolean;
    class function Default: TCorsOptions; static;
  end;

function CorsMiddleware(const AOptions: TCorsOptions): IHttpMiddleware;

implementation

uses
  nextpas.core.http.base,
  nextpas.core.http.middleware,
  nextpas.core.text.conv;

class function TCorsOptions.Default: TCorsOptions;
begin
  Result.AllowOrigins := '*';
  Result.AllowMethods := 'GET, POST, PUT, DELETE, OPTIONS';
  Result.AllowHeaders := 'Content-Type, Authorization';
  Result.MaxAge := 86400;
  Result.AllowCredentials := False;
end;

function CorsMiddleware(const AOptions: TCorsOptions): IHttpMiddleware;
begin
  Result := MiddlewareFunc(function(const ANext: IHttpHandler): IHttpHandler
  begin
    Result := HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    var
      LOrigin: string;
    begin
      LOrigin := AReq.Headers.Get('Origin');
      if LOrigin = '' then
      begin
        ANext.ServeHTTP(AReq, AW);
        Exit;
      end;

      { Set CORS response headers }
      AW.Headers.SetHeader('Access-Control-Allow-Origin', AOptions.AllowOrigins);
      AW.Headers.SetHeader('Access-Control-Allow-Methods', AOptions.AllowMethods);
      AW.Headers.SetHeader('Access-Control-Allow-Headers', AOptions.AllowHeaders);
      if AOptions.MaxAge > 0 then
        AW.Headers.SetHeader('Access-Control-Max-Age', IntToStr(Int64(AOptions.MaxAge)));
      if AOptions.AllowCredentials then
        AW.Headers.SetHeader('Access-Control-Allow-Credentials', 'true');

      { Preflight: OPTIONS with Origin → 204, don't call next }
      if AReq.Method = hmOptions then
      begin
        AW.WriteHeader(HTTP_STATUS_NO_CONTENT);
        Exit;
      end;

      ANext.ServeHTTP(AReq, AW);
    end);
  end);
end;

end.
