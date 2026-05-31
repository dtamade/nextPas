unit nextpas.core.http.base;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.errors;

type
  THttpVersion = (hvHttp10, hvHttp11, hvHttp2, hvHttp3);

  THttpMethod = (
    hmGet, hmHead, hmPost, hmPut, hmDelete,
    hmPatch, hmOptions, hmConnect, hmTrace
  );

  THttpStatus = UInt16;

  EHttpError = class(ENextPasError)
  public
    constructor Create(const AMessage: string); overload;
  end;

  TUrl = record
    Scheme: string;
    UserInfo: string;
    Host: string;
    Port: UInt16;
    Path: string;
    RawQuery: string;
    Fragment: string;
    class function Parse(const ARaw: string): TUrl; static;
    function ToString: string;
    function HostPort: string;
  end;

const
  HTTP_STATUS_OK                    = THttpStatus(200);
  HTTP_STATUS_CREATED               = THttpStatus(201);
  HTTP_STATUS_NO_CONTENT            = THttpStatus(204);
  HTTP_STATUS_MOVED_PERMANENTLY     = THttpStatus(301);
  HTTP_STATUS_FOUND                 = THttpStatus(302);
  HTTP_STATUS_NOT_MODIFIED          = THttpStatus(304);
  HTTP_STATUS_BAD_REQUEST           = THttpStatus(400);
  HTTP_STATUS_UNAUTHORIZED          = THttpStatus(401);
  HTTP_STATUS_FORBIDDEN             = THttpStatus(403);
  HTTP_STATUS_NOT_FOUND             = THttpStatus(404);
  HTTP_STATUS_METHOD_NOT_ALLOWED    = THttpStatus(405);
  HTTP_STATUS_INTERNAL_SERVER_ERROR = THttpStatus(500);
  HTTP_STATUS_BAD_GATEWAY           = THttpStatus(502);
  HTTP_STATUS_SERVICE_UNAVAILABLE   = THttpStatus(503);

function HttpMethodToStr(const AMethod: THttpMethod): string;
function HttpStrToMethod(const AStr: string): THttpMethod;
function HttpStatusText(const ACode: THttpStatus): string;
function HttpVersionToStr(const AVersion: THttpVersion): string;

implementation

uses
  nextpas.core.text.conv;

{ EHttpError }

constructor EHttpError.Create(const AMessage: string);
begin
  inherited Create(AMessage, ecNetwork);
end;

{ Free functions }

function HttpMethodToStr(const AMethod: THttpMethod): string;
begin
  case AMethod of
    hmGet:     Result := 'GET';
    hmHead:    Result := 'HEAD';
    hmPost:    Result := 'POST';
    hmPut:     Result := 'PUT';
    hmDelete:  Result := 'DELETE';
    hmPatch:   Result := 'PATCH';
    hmOptions: Result := 'OPTIONS';
    hmConnect: Result := 'CONNECT';
    hmTrace:   Result := 'TRACE';
  end;
end;

function HttpStrToMethod(const AStr: string): THttpMethod;
begin
  if AStr = 'GET' then Result := hmGet
  else if AStr = 'HEAD' then Result := hmHead
  else if AStr = 'POST' then Result := hmPost
  else if AStr = 'PUT' then Result := hmPut
  else if AStr = 'DELETE' then Result := hmDelete
  else if AStr = 'PATCH' then Result := hmPatch
  else if AStr = 'OPTIONS' then Result := hmOptions
  else if AStr = 'CONNECT' then Result := hmConnect
  else if AStr = 'TRACE' then Result := hmTrace
  else
    raise EHttpError.Create('Unknown HTTP method: ' + AStr);
end;

function HttpStatusText(const ACode: THttpStatus): string;
begin
  case ACode of
    200: Result := 'OK';
    201: Result := 'Created';
    204: Result := 'No Content';
    301: Result := 'Moved Permanently';
    302: Result := 'Found';
    304: Result := 'Not Modified';
    400: Result := 'Bad Request';
    401: Result := 'Unauthorized';
    403: Result := 'Forbidden';
    404: Result := 'Not Found';
    405: Result := 'Method Not Allowed';
    500: Result := 'Internal Server Error';
    502: Result := 'Bad Gateway';
    503: Result := 'Service Unavailable';
  else
    Result := 'Unknown';
  end;
end;

function HttpVersionToStr(const AVersion: THttpVersion): string;
begin
  case AVersion of
    hvHttp10: Result := 'HTTP/1.0';
    hvHttp11: Result := 'HTTP/1.1';
    hvHttp2:  Result := 'HTTP/2';
    hvHttp3:  Result := 'HTTP/3';
  end;
end;

{ TUrl }

class function TUrl.Parse(const ARaw: string): TUrl;
var
  LRest: string;
  LPos: SizeInt;
  LSchemeEnd: SizeInt;
  LAuthority: string;
  LAtPos: SizeInt;
  LColonPos: SizeInt;
  LPortStr: string;
  LPortVal: Int64;
begin
  Result := Default(TUrl);
  if ARaw = '' then
    raise EHttpError.Create('Cannot parse empty URL');

  LRest := ARaw;

  // Check for scheme (contains "://")
  LSchemeEnd := Pos('://', LRest);
  if LSchemeEnd > 0 then
  begin
    Result.Scheme := Copy(LRest, 1, LSchemeEnd - 1);
    Delete(LRest, 1, LSchemeEnd + 2);

    // Extract authority (up to first / or end)
    LPos := Pos('/', LRest);
    if LPos > 0 then
    begin
      LAuthority := Copy(LRest, 1, LPos - 1);
      Delete(LRest, 1, LPos - 1);
    end
    else
    begin
      LAuthority := LRest;
      LRest := '';
    end;

    // Check for userinfo (@)
    LAtPos := Pos('@', LAuthority);
    if LAtPos > 0 then
    begin
      Result.UserInfo := Copy(LAuthority, 1, LAtPos - 1);
      Delete(LAuthority, 1, LAtPos);
    end;

    // Parse host:port (handle IPv6 brackets)
    if (Length(LAuthority) > 0) and (LAuthority[1] = '[') then
    begin
      LColonPos := Pos(']', LAuthority);
      if LColonPos > 0 then
      begin
        Result.Host := Copy(LAuthority, 2, LColonPos - 2);
        if (LColonPos < Length(LAuthority)) and (LAuthority[LColonPos + 1] = ':') then
        begin
          LPortStr := Copy(LAuthority, LColonPos + 2, Length(LAuthority) - LColonPos - 1);
          if TryStrToInt(LPortStr, LPortVal) then
            Result.Port := UInt16(LPortVal);
        end;
      end
      else
        Result.Host := LAuthority;
    end
    else
    begin
      LColonPos := Pos(':', LAuthority);
      if LColonPos > 0 then
      begin
        Result.Host := Copy(LAuthority, 1, LColonPos - 1);
        LPortStr := Copy(LAuthority, LColonPos + 1, Length(LAuthority) - LColonPos);
        if TryStrToInt(LPortStr, LPortVal) then
          Result.Port := UInt16(LPortVal)
        else
          Result.Port := 0;
      end
      else
      begin
        Result.Host := LAuthority;
        Result.Port := 0;
      end;
    end;
  end;

  // Fragment
  LPos := Pos('#', LRest);
  if LPos > 0 then
  begin
    Result.Fragment := Copy(LRest, LPos + 1, Length(LRest) - LPos);
    LRest := Copy(LRest, 1, LPos - 1);
  end;

  // Query
  LPos := Pos('?', LRest);
  if LPos > 0 then
  begin
    Result.RawQuery := Copy(LRest, LPos + 1, Length(LRest) - LPos);
    LRest := Copy(LRest, 1, LPos - 1);
  end;

  Result.Path := LRest;
end;

function TUrl.ToString: string;
var
  LResult: string;
begin
  LResult := '';
  if Scheme <> '' then
  begin
    LResult := Scheme + '://';
    if UserInfo <> '' then
      LResult := LResult + UserInfo + '@';
    LResult := LResult + Host;
    if Port <> 0 then
      LResult := LResult + ':' + IntToStr(Int64(Port));
  end;
  LResult := LResult + Path;
  if RawQuery <> '' then
    LResult := LResult + '?' + RawQuery;
  if Fragment <> '' then
    LResult := LResult + '#' + Fragment;
  Result := LResult;
end;

function TUrl.HostPort: string;
begin
  if Port <> 0 then
    Result := Host + ':' + IntToStr(Int64(Port))
  else
    Result := Host;
end;

end.
