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
  nextpas.core.base,
  nextpas.core.http.base,
  nextpas.core.http.middleware,
  nextpas.core.text.conv,
  nextpas.core.text.strings;

type
  TCorsState = record
    Wildcard: Boolean;
    Origins: array of string;
    AllowMethods: string;
    AllowHeaders: string;
    MaxAge: Int32;
    AllowCredentials: Boolean;
  end;

function ParseOrigins(const AAllowOrigins: string): TCorsState;
var
  LStart, LEnd, LLen: Integer;
  LToken: string;
  LCount: Integer;
begin
  Result.Wildcard := AAllowOrigins = '*';
  Result.Origins := nil;
  LCount := 0;

  if not Result.Wildcard then
  begin
    LLen := Length(AAllowOrigins);
    LStart := 1;
    while LStart <= LLen do
    begin
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
        if LCount >= Length(Result.Origins) then
          SetLength(Result.Origins, LCount + 4);
        Result.Origins[LCount] := LowerCase(LToken);
        Inc(LCount);
      end;
      LStart := LEnd + 1;
    end;
    SetLength(Result.Origins, LCount);
  end;
end;

function IsOriginAllowed(const AState: TCorsState; const AOrigin: string): Boolean;
var
  LI: Integer;
  LLower: string;
begin
  if AState.Wildcard then
    Exit(True);
  LLower := LowerCase(AOrigin);
  for LI := 0 to High(AState.Origins) do
    if AState.Origins[LI] = LLower then
      Exit(True);
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

{ Check if AMethod is in the comma-separated AllowMethods list. }
function MethodIsAllowed(const AMethod, AAllowMethods: string): Boolean;
var
  LMethods: TStringArray;
  LI: SizeInt;
begin
  LMethods := StringsSplit(AAllowMethods, ',');
  for LI := 0 to High(LMethods) do
    if LowerCase(Trim(LMethods[LI])) = LowerCase(AMethod) then
      Exit(True);
  Result := False;
end;

function CorsMiddleware(const AOptions: TCorsOptions): IHttpMiddleware;
var
  LState: TCorsState;
begin
  LState := ParseOrigins(AOptions.AllowOrigins);
  LState.AllowMethods := AOptions.AllowMethods;
  LState.AllowHeaders := AOptions.AllowHeaders;
  LState.MaxAge := AOptions.MaxAge;
  LState.AllowCredentials := AOptions.AllowCredentials;

  Result := MiddlewareFunc(function(const ANext: IHttpHandler): IHttpHandler
  begin
    Result := HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    var
      LOrigin, LAllowOrigin, LRequestHeaders, LRequestMethod, LVaryExisting: string;
    begin
      LOrigin := AReq.Headers.Get('Origin');
      if LOrigin = '' then
      begin
        ANext.ServeHTTP(AReq, AW);
        Exit;
      end;

      { Determine the Access-Control-Allow-Origin value to emit.
        W3C rule: must NOT be '*' when AllowCredentials is true;
        the browser will reject that combination. }
      if LState.AllowCredentials then
      begin
        { Credentials mode: always echo the concrete Origin. }
        if LState.Wildcard or IsOriginAllowed(LState, LOrigin) then
          LAllowOrigin := LOrigin
        else
          LAllowOrigin := '';
      end
      else
      begin
        { Non-credentials mode. }
        if LState.Wildcard then
          LAllowOrigin := '*'
        else if IsOriginAllowed(LState, LOrigin) then
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
        so caches distinguish responses per Origin. Also include
        Access-Control-Request-Method and Access-Control-Request-Headers
        since preflight responses vary by these too.
        Merge with existing Vary to avoid overwriting other cache dimensions. }
      if LAllowOrigin <> '*' then
      begin
        LVaryExisting := AW.Headers.Get('Vary');
        if LVaryExisting <> '' then
          AW.Headers.SetHeader('Vary', LVaryExisting +
            ', Origin, Access-Control-Request-Method, Access-Control-Request-Headers')
        else
          AW.Headers.SetHeader('Vary',
            'Origin, Access-Control-Request-Method, Access-Control-Request-Headers');
      end;

      AW.Headers.SetHeader('Access-Control-Allow-Methods', LState.AllowMethods);

      { When AllowHeaders is '*', echo back the request's Access-Control-Request-Headers.
        This lets the browser send any headers the client requested. }
      if (LState.AllowHeaders = '*') and (AReq.Method = hmOptions) then
      begin
        LRequestHeaders := AReq.Headers.Get('Access-Control-Request-Headers');
        if LRequestHeaders <> '' then
          AW.Headers.SetHeader('Access-Control-Allow-Headers', LRequestHeaders)
        else
          AW.Headers.SetHeader('Access-Control-Allow-Headers', '*');
      end
      else
        AW.Headers.SetHeader('Access-Control-Allow-Headers', LState.AllowHeaders);

      if LState.MaxAge > 0 then
        AW.Headers.SetHeader('Access-Control-Max-Age', IntToStr(Int64(LState.MaxAge)));
      if LState.AllowCredentials then
        AW.Headers.SetHeader('Access-Control-Allow-Credentials', 'true');

      { Preflight: OPTIONS with Origin + Access-Control-Request-Method -> 204 }
      if AReq.Method = hmOptions then
      begin
        LRequestMethod := AReq.Headers.Get('Access-Control-Request-Method');
        if LRequestMethod <> '' then
        begin
          { Validate the requested method is in the allowed list }
          if not MethodIsAllowed(LRequestMethod, LState.AllowMethods) then
          begin
            AW.WriteHeader(HTTP_STATUS_FORBIDDEN);
            Exit;
          end;
        end;
        AW.WriteHeader(HTTP_STATUS_NO_CONTENT);
        Exit;
      end;

      ANext.ServeHTTP(AReq, AW);
    end);
  end);
end;

end.
