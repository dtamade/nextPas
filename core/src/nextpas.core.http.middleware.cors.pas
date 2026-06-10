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

{ Split AllowOrigins by comma and check if AOrigin is in the list.
  '*' matches everything.  Comparison is case-insensitive. }
function IsOriginAllowed(const AAllowOrigins, AOrigin: string): Boolean;
var
  LStart, LEnd, LLen: Integer;
  LToken: string;
begin
  if AAllowOrigins = '*' then
    Exit(True);
  LLen := Length(AAllowOrigins);
  LStart := 1;
  while LStart <= LLen do
  begin
    { skip leading whitespace / commas }
    while (LStart <= LLen) and (AAllowOrigins[LStart] in [' ', ',']) do
      Inc(LStart);
    if LStart > LLen then
      Break;
    LEnd := LStart;
    while (LEnd <= LLen) and not (AAllowOrigins[LEnd] in [',']) do
      Inc(LEnd);
    LToken := Trim(Copy(AAllowOrigins, LStart, LEnd - LStart));
    if LToken <> '' then
    begin
      if LowerCase(LToken) = LowerCase(AOrigin) then
        Exit(True);
    end;
    LStart := LEnd + 1;
  end;
  Result := False;
end;

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
      LOrigin, LAllowOrigin: string;
      LIsWildcard: Boolean;
    begin
      LOrigin := AReq.Headers.Get('Origin');
      if LOrigin = '' then
      begin
        ANext.ServeHTTP(AReq, AW);
        Exit;
      end;

      LIsWildcard := AOptions.AllowOrigins = '*';

      { Determine the Access-Control-Allow-Origin value to emit.
        W3C rule: must NOT be '*' when AllowCredentials is true;
        the browser will reject that combination. }
      if AOptions.AllowCredentials then
      begin
        { Credentials mode: always echo the concrete Origin. }
        if LIsWildcard or IsOriginAllowed(AOptions.AllowOrigins, LOrigin) then
          LAllowOrigin := LOrigin
        else
          LAllowOrigin := '';
      end
      else
      begin
        { Non-credentials mode. }
        if LIsWildcard then
          LAllowOrigin := '*'
        else if IsOriginAllowed(AOptions.AllowOrigins, LOrigin) then
          LAllowOrigin := LOrigin
        else
          LAllowOrigin := '';
      end;

      { Origin not allowed: no CORS headers, pass through normally }
      if LAllowOrigin = '' then
      begin
        ANext.ServeHTTP(AReq, AW);
        Exit;
      end;

      { Set CORS response headers }
      AW.Headers.SetHeader('Access-Control-Allow-Origin', LAllowOrigin);

      { When echoing a specific Origin (not '*'), add Vary: Origin
        so caches distinguish responses per Origin. }
      if LAllowOrigin <> '*' then
        AW.Headers.SetHeader('Vary', 'Origin');

      AW.Headers.SetHeader('Access-Control-Allow-Methods', AOptions.AllowMethods);
      AW.Headers.SetHeader('Access-Control-Allow-Headers', AOptions.AllowHeaders);
      if AOptions.MaxAge > 0 then
        AW.Headers.SetHeader('Access-Control-Max-Age', IntToStr(Int64(AOptions.MaxAge)));
      if AOptions.AllowCredentials then
        AW.Headers.SetHeader('Access-Control-Allow-Credentials', 'true');

      { Preflight: OPTIONS with Origin -> 204, don't call next }
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
