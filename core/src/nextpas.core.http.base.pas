unit nextpas.core.http.base;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.errors,
  nextpas.core.net.server.base;

type
  THttpVersion = (hvHttp10, hvHttp11, hvHttp2, hvHttp3);

  THttpMethod = (
    hmGet, hmHead, hmPost, hmPut, hmDelete,
    hmPatch, hmOptions, hmConnect, hmTrace
  );

  THttpStatus = UInt16;
  TTcpServerBackend = nextpas.core.net.server.base.TTcpServerBackend;

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
    class function ParseRequestTarget(const ARaw: string): TUrl; static;
    function ToString: string;
    function HostPort: string;
  end;

  THttpClientOptions = record
    Timeout: Int64;
    MaxRedirects: Int32;
    FollowRedirects: Boolean;
    class function Default: THttpClientOptions; static;
  end;

  THttpServerOptions = record
    Backend: TTcpServerBackend;
    ReadTimeout: Int64;
    WriteTimeout: Int64;
    IdleTimeout: Int64;
    MaxHeaderSize: Int32;
    MaxBodySize: Int64;
    class function Default: THttpServerOptions; static;
  end;

const
  { 1xx Informational }
  HTTP_STATUS_CONTINUE              = THttpStatus(100);
  HTTP_STATUS_SWITCHING_PROTOCOLS   = THttpStatus(101);
  HTTP_STATUS_EARLY_HINTS           = THttpStatus(103);

  { 2xx Success }
  HTTP_STATUS_OK                    = THttpStatus(200);
  HTTP_STATUS_CREATED               = THttpStatus(201);
  HTTP_STATUS_ACCEPTED              = THttpStatus(202);
  HTTP_STATUS_NO_CONTENT            = THttpStatus(204);
  HTTP_STATUS_RESET_CONTENT         = THttpStatus(205);
  HTTP_STATUS_PARTIAL_CONTENT       = THttpStatus(206);

  { 3xx Redirection }
  HTTP_STATUS_MOVED_PERMANENTLY     = THttpStatus(301);
  HTTP_STATUS_FOUND                 = THttpStatus(302);
  HTTP_STATUS_SEE_OTHER             = THttpStatus(303);
  HTTP_STATUS_NOT_MODIFIED          = THttpStatus(304);
  HTTP_STATUS_TEMPORARY_REDIRECT    = THttpStatus(307);
  HTTP_STATUS_PERMANENT_REDIRECT    = THttpStatus(308);

  { 4xx Client Error }
  HTTP_STATUS_BAD_REQUEST           = THttpStatus(400);
  HTTP_STATUS_UNAUTHORIZED          = THttpStatus(401);
  HTTP_STATUS_FORBIDDEN             = THttpStatus(403);
  HTTP_STATUS_NOT_FOUND             = THttpStatus(404);
  HTTP_STATUS_METHOD_NOT_ALLOWED    = THttpStatus(405);
  HTTP_STATUS_NOT_ACCEPTABLE        = THttpStatus(406);
  HTTP_STATUS_REQUEST_TIMEOUT       = THttpStatus(408);
  HTTP_STATUS_CONFLICT              = THttpStatus(409);
  HTTP_STATUS_GONE                  = THttpStatus(410);
  HTTP_STATUS_PAYLOAD_TOO_LARGE     = THttpStatus(413);
  HTTP_STATUS_EXPECTATION_FAILED    = THttpStatus(417);
  HTTP_STATUS_UNPROCESSABLE_ENTITY  = THttpStatus(422);
  HTTP_STATUS_TOO_MANY_REQUESTS     = THttpStatus(429);
  HTTP_STATUS_HEADER_TOO_LARGE      = THttpStatus(431);

  { 5xx Server Error }
  HTTP_STATUS_INTERNAL_SERVER_ERROR = THttpStatus(500);
  HTTP_STATUS_NOT_IMPLEMENTED       = THttpStatus(501);
  HTTP_STATUS_BAD_GATEWAY           = THttpStatus(502);
  HTTP_STATUS_SERVICE_UNAVAILABLE   = THttpStatus(503);

  { TCP server backend aliases }
  TCP_SERVER_BACKEND_THREADED = nextpas.core.net.server.base.tsbThreaded;
  TCP_SERVER_BACKEND_EPOLL = nextpas.core.net.server.base.tsbEpoll;
  TCP_SERVER_BACKEND_KQUEUE = nextpas.core.net.server.base.tsbKqueue;
  TCP_SERVER_BACKEND_IOCP = nextpas.core.net.server.base.tsbIocp;

function HttpMethodToStr(const AMethod: THttpMethod): string;
function HttpStrToMethod(const AStr: string): THttpMethod;
function HttpStatusText(const ACode: THttpStatus): string;
function HttpStatusIsInformational(const ACode: THttpStatus): Boolean;
function HttpStatusIsSuccess(const ACode: THttpStatus): Boolean;
function HttpStatusIsRedirect(const ACode: THttpStatus): Boolean;
function HttpStatusIsClientError(const ACode: THttpStatus): Boolean;
function HttpStatusIsServerError(const ACode: THttpStatus): Boolean;
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
var
  LUpper: string;
begin
  LUpper := UpperCase(AStr);
  if LUpper = 'GET' then Result := hmGet
  else if LUpper = 'HEAD' then Result := hmHead
  else if LUpper = 'POST' then Result := hmPost
  else if LUpper = 'PUT' then Result := hmPut
  else if LUpper = 'DELETE' then Result := hmDelete
  else if LUpper = 'PATCH' then Result := hmPatch
  else if LUpper = 'OPTIONS' then Result := hmOptions
  else if LUpper = 'CONNECT' then Result := hmConnect
  else if LUpper = 'TRACE' then Result := hmTrace
  else
    raise EHttpError.Create('Unknown HTTP method: ' + AStr);
end;

function HttpStatusText(const ACode: THttpStatus): string;
begin
  case ACode of
    { 1xx }
    100: Result := 'Continue';
    101: Result := 'Switching Protocols';
    103: Result := 'Early Hints';
    { 2xx }
    200: Result := 'OK';
    201: Result := 'Created';
    202: Result := 'Accepted';
    204: Result := 'No Content';
    205: Result := 'Reset Content';
    206: Result := 'Partial Content';
    { 3xx }
    301: Result := 'Moved Permanently';
    302: Result := 'Found';
    303: Result := 'See Other';
    304: Result := 'Not Modified';
    307: Result := 'Temporary Redirect';
    308: Result := 'Permanent Redirect';
    { 4xx }
    400: Result := 'Bad Request';
    401: Result := 'Unauthorized';
    403: Result := 'Forbidden';
    404: Result := 'Not Found';
    405: Result := 'Method Not Allowed';
    406: Result := 'Not Acceptable';
    408: Result := 'Request Timeout';
    409: Result := 'Conflict';
    410: Result := 'Gone';
    413: Result := 'Payload Too Large';
    417: Result := 'Expectation Failed';
    422: Result := 'Unprocessable Entity';
    429: Result := 'Too Many Requests';
    431: Result := 'Request Header Fields Too Large';
    { 5xx }
    500: Result := 'Internal Server Error';
    501: Result := 'Not Implemented';
    502: Result := 'Bad Gateway';
    503: Result := 'Service Unavailable';
  else
    Result := 'Unknown';
  end;
end;

function HttpStatusInRange(const ACode, AMin, AMax: THttpStatus): Boolean;
begin
  Result := (ACode >= AMin) and (ACode <= AMax);
end;

function HttpStatusIsInformational(const ACode: THttpStatus): Boolean;
begin
  Result := HttpStatusInRange(ACode, 100, 199);
end;

function HttpStatusIsSuccess(const ACode: THttpStatus): Boolean;
begin
  Result := HttpStatusInRange(ACode, 200, 299);
end;

function HttpStatusIsRedirect(const ACode: THttpStatus): Boolean;
begin
  Result := HttpStatusInRange(ACode, 300, 399);
end;

function HttpStatusIsClientError(const ACode: THttpStatus): Boolean;
begin
  Result := HttpStatusInRange(ACode, 400, 499);
end;

function HttpStatusIsServerError(const ACode: THttpStatus): Boolean;
begin
  Result := HttpStatusInRange(ACode, 500, 599);
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

function ParseUrlPort(const APort: string): UInt16;
var
  LPortVal: Int64;
begin
  if (APort = '') or (not TryStrToInt(APort, LPortVal)) then
    raise EHttpError.Create('Invalid port: ' + APort);
  if (LPortVal < 0) or (LPortVal > 65535) then
    raise EHttpError.Create('Port out of range: ' + APort);
  Result := UInt16(LPortVal);
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
  LI: SizeInt;
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

    // Extract authority (up to first /, ?, or # -- or end)
    LPos := 0;
    for LI := 1 to Length(LRest) do
      if (LRest[LI] = '/') or (LRest[LI] = '?') or (LRest[LI] = '#') then
      begin
        LPos := LI;
        Break;
      end;
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
          Result.Port := ParseUrlPort(LPortStr);
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
        Result.Port := ParseUrlPort(LPortStr);
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

class function TUrl.ParseRequestTarget(const ARaw: string): TUrl;
var
  LRest: string;
  LPos: SizeInt;
begin
  if ARaw = '' then
    raise EHttpError.Create('Cannot parse empty request-target');

  if (ARaw[1] <> '/') and (ARaw[1] <> '*') and (Pos('://', ARaw) > 0) then
    Exit(TUrl.Parse(ARaw));

  Result := Default(TUrl);
  LRest := ARaw;

  LPos := Pos('#', LRest);
  if LPos > 0 then
  begin
    Result.Fragment := Copy(LRest, LPos + 1, Length(LRest) - LPos);
    LRest := Copy(LRest, 1, LPos - 1);
  end;

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
    if Pos(':', Host) > 0 then
      LResult := LResult + '[' + Host + ']'
    else
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
var
  LHost: string;
begin
  if Pos(':', Host) > 0 then
    LHost := '[' + Host + ']'
  else
    LHost := Host;

  if Port <> 0 then
    Result := LHost + ':' + IntToStr(Int64(Port))
  else
    Result := LHost;
end;

{ THttpClientOptions }

class function THttpClientOptions.Default: THttpClientOptions;
begin
  Result.Timeout := 30000;
  Result.MaxRedirects := 10;
  Result.FollowRedirects := True;
end;

{ THttpServerOptions }

class function THttpServerOptions.Default: THttpServerOptions;
begin
  Result.Backend := tsbThreaded;
  Result.ReadTimeout := 0;
  Result.WriteTimeout := 0;
  Result.IdleTimeout := 30000;
  Result.MaxHeaderSize := 8192;
  Result.MaxBodySize := 4194304;
end;

end.
