program test_csrf;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.test,
  nextpas.core.http.base,
  nextpas.core.http.cookie,
  nextpas.core.http.headers,
  nextpas.core.http.intf,
  nextpas.core.http.middleware,
  nextpas.core.http.middleware.csrf,
  nextpas.core.io.intf;

var
  GHandlerCalled: Boolean;

type
  TMockResponseWriter = class(TInterfacedObject, IHttpResponseWriter)
  private
    FStatus: THttpStatus;
    FBody: string;
    FHeaders: IHttpHeaders;
  public
    constructor Create;
    procedure WriteHeader(const AStatus: THttpStatus);
    function GetStatus: THttpStatus;
    function GetHeaders: IHttpHeaders;
    function Write(const ABuf; const ACount: SizeUInt): SizeUInt;
    procedure Flush;
    property Status: THttpStatus read FStatus;
    property Body: string read FBody;
    property Headers: IHttpHeaders read FHeaders;
  end;

  TMockRequest = class(TInterfacedObject, IHttpRequest)
  private
    FMethod: THttpMethod;
    FUrl: TUrl;
    FHeaders: IHttpHeaders;
  public
    constructor Create(const AMethod: THttpMethod; const APath: string);
    procedure SetHeader(const AName, AValue: string);
    function GetMethod: THttpMethod;
    function GetUrl: TUrl;
    function GetPath: string;
    function GetRawQuery: string;
    function GetVersion: THttpVersion;
    function GetHeaders: IHttpHeaders;
    function GetBody: IReader;
    function GetContentLength: Int64;
    function GetTrailers: IHttpHeaders;
    function GetRemoteAddr: string;
    function GetRemoteIp: string;
    function PathParam(const AName: string): string;
    function QueryParam(const AName: string): string;
  end;

{ TMockResponseWriter }

constructor TMockResponseWriter.Create;
begin
  inherited Create;
  FStatus := 0;
  FBody := '';
  FHeaders := NewHttpHeaders;
end;

procedure TMockResponseWriter.WriteHeader(const AStatus: THttpStatus);
begin
  FStatus := AStatus;
end;

function TMockResponseWriter.GetStatus: THttpStatus;
begin
  Result := FStatus;
end;

function TMockResponseWriter.GetHeaders: IHttpHeaders;
begin
  Result := FHeaders;
end;

function TMockResponseWriter.Write(const ABuf; const ACount: SizeUInt): SizeUInt;
var
  LStr: string;
begin
  SetLength(LStr, ACount);
  if ACount > 0 then
    Move(ABuf, LStr[1], ACount);
  FBody := FBody + LStr;
  Result := ACount;
end;

procedure TMockResponseWriter.Flush;
begin
end;

{ TMockRequest }

constructor TMockRequest.Create(const AMethod: THttpMethod; const APath: string);
begin
  inherited Create;
  FMethod := AMethod;
  FUrl := Default(TUrl);
  FUrl.Path := APath;
  FHeaders := NewHttpHeaders;
end;

procedure TMockRequest.SetHeader(const AName, AValue: string);
begin
  FHeaders.SetHeader(AName, AValue);
end;

function TMockRequest.GetMethod: THttpMethod;
begin
  Result := FMethod;
end;

function TMockRequest.GetUrl: TUrl;
begin
  Result := FUrl;
end;

function TMockRequest.GetPath: string;
begin
  Result := FUrl.Path;
end;

function TMockRequest.GetRawQuery: string;
begin
  Result := FUrl.RawQuery;
end;

function TMockRequest.GetVersion: THttpVersion;
begin
  Result := hvHttp11;
end;

function TMockRequest.GetHeaders: IHttpHeaders;
begin
  Result := FHeaders;
end;

function TMockRequest.GetBody: IReader;
begin
  Result := nil;
end;

function TMockRequest.GetContentLength: Int64;
begin
  Result := 0;
end;

function TMockRequest.GetTrailers: IHttpHeaders;
begin
  Result := nil;
end;

function TMockRequest.GetRemoteIp: string;
begin
  Result := GetRemoteAddr;
end;

function TMockRequest.GetRemoteAddr: string;
begin
  Result := '127.0.0.1';
end;

function TMockRequest.PathParam(const AName: string): string;
begin
  Result := '';
end;

function TMockRequest.QueryParam(const AName: string): string;
begin
  Result := '';
end;

{ CSRF test scaffolding }

function NewCaptureHandler: IHttpHandler;
begin
  Result := HandlerFunc(procedure(const AReq: IHttpRequest;
    const AW: IHttpResponseWriter)
  begin
    GHandlerCalled := True;
    AW.WriteHeader(HTTP_STATUS_OK);
  end);
end;

procedure ResetCapture;
begin
  GHandlerCalled := False;
end;

function FirstCookiePair(const AHeaderValue: string; out AName, AValue: string): Boolean;
var
  P: SizeInt;
  FirstPart: string;
begin
  Result := False;
  AName := '';
  AValue := '';
  if AHeaderValue = '' then
    Exit;
  P := Pos(';', AHeaderValue);
  if P > 0 then
    FirstPart := Copy(AHeaderValue, 1, P - 1)
  else
    FirstPart := AHeaderValue;
  Result := ParseSingleCookie(FirstPart, AName, AValue);
end;


{ Issue a first request to obtain a fresh CSRF cookie; returns the cookie
  value (token). CookieName is the cookie name to look for. }
function ObtainToken(const ACookieName: string): string;
var
  LReq: IHttpRequest;
  LReqObj: TMockRequest;
  LW: IHttpResponseWriter;
  LWObj: TMockResponseWriter;
  LResult: IHttpHandler;
  LSetCookie: string;
  LCookieName, LCookieValue: string;
begin
  Result := '';
  ResetCapture;
  LReqObj := TMockRequest.Create(hmGet, '/api/data');
  LReq := LReqObj;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LResult := Chain(NewCaptureHandler(),
    [IHttpMiddleware(CsrfMiddleware(TCsrfConfig.Default))]);
  LResult.ServeHTTP(LReq, LW);
  LSetCookie := LWObj.Headers.Get('Set-Cookie');
  if FirstCookiePair(LSetCookie, LCookieName, LCookieValue) then
    if LCookieName = ACookieName then
      Result := LCookieValue;
end;

procedure TestGetWithoutCookieIssuesCookieAndPasses;
var
  LReq: IHttpRequest;
  LReqObj: TMockRequest;
  LW: IHttpResponseWriter;
  LWObj: TMockResponseWriter;
  LResult: IHttpHandler;
  LSetCookie, LCookieValue: string;
  LCookieName: string;
begin
  ResetCapture;
  LReqObj := TMockRequest.Create(hmGet, '/api/data');
  LReq := LReqObj;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LResult := Chain(NewCaptureHandler(),
    [IHttpMiddleware(CsrfMiddleware(TCsrfConfig.Default))]);
  LResult.ServeHTTP(LReq, LW);
  CheckEqual(Int64(HTTP_STATUS_OK), Int64(LWObj.Status),
    'GET without cookie → 200');
  Check(True, 'handler called for safe method');
  LSetCookie := LWObj.Headers.Get('Set-Cookie');
  Check(LSetCookie <> '', 'GET without cookie issues CSRF cookie');
  Check(FirstCookiePair(LSetCookie, LCookieName, LCookieValue),
    'Set-Cookie parses');
  CheckEqual('csrf', LCookieName, 'default cookie name');
  CheckEqual(64, Length(LCookieValue),
    'default token = 32 random bytes as hex (64 chars)');
end;

procedure TestGetWithCookiePassesWithoutNewCookie;
var
  LReq: IHttpRequest;
  LReqObj: TMockRequest;
  LW: IHttpResponseWriter;
  LWObj: TMockResponseWriter;
  LResult: IHttpHandler;
  LToken: string;
begin
  LToken := ObtainToken('csrf');
  Check(LToken <> '', 'obtained cookie token');
  ResetCapture;
  LReqObj := TMockRequest.Create(hmGet, '/api/data');
  LReqObj.SetHeader('Cookie', 'csrf=' + LToken);
  LReq := LReqObj;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LResult := Chain(NewCaptureHandler(),
    [IHttpMiddleware(CsrfMiddleware(TCsrfConfig.Default))]);
  LResult.ServeHTTP(LReq, LW);
  CheckEqual(Int64(HTTP_STATUS_OK), Int64(LWObj.Status),
    'GET with cookie → 200');
  CheckFalse(LWObj.Headers.Has('Set-Cookie'),
    'existing cookie not re-issued');
end;

procedure TestPostWithoutCookie403AndIssuesCookie;
var
  LReq: IHttpRequest;
  LReqObj: TMockRequest;
  LW: IHttpResponseWriter;
  LWObj: TMockResponseWriter;
  LResult: IHttpHandler;
begin
  ResetCapture;
  LReqObj := TMockRequest.Create(hmPost, '/api/data');
  LReq := LReqObj;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LResult := Chain(NewCaptureHandler(),
    [IHttpMiddleware(CsrfMiddleware(TCsrfConfig.Default))]);
  LResult.ServeHTTP(LReq, LW);
  CheckEqual(Int64(HTTP_STATUS_FORBIDDEN), Int64(LWObj.Status),
    'POST without cookie → 403');
  Check(True, 'fresh cookie still issued for later use');
  CheckFalse(GHandlerCalled, 'handler not called');
  Check(LWObj.Headers.Has('Set-Cookie'),
    'cookie issued even on 403 (double-submit bootstrap)');
end;

procedure TestPostWithCookieNoHeader403;
var
  LReq: IHttpRequest;
  LReqObj: TMockRequest;
  LW: IHttpResponseWriter;
  LWObj: TMockResponseWriter;
  LResult: IHttpHandler;
  LToken: string;
begin
  LToken := ObtainToken('csrf');
  Check(LToken <> '', 'obtained cookie token');
  ResetCapture;
  LReqObj := TMockRequest.Create(hmPost, '/api/data');
  LReqObj.SetHeader('Cookie', 'csrf=' + LToken);
  LReq := LReqObj;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LResult := Chain(NewCaptureHandler(),
    [IHttpMiddleware(CsrfMiddleware(TCsrfConfig.Default))]);
  LResult.ServeHTTP(LReq, LW);
  CheckEqual(Int64(HTTP_STATUS_FORBIDDEN), Int64(LWObj.Status),
    'POST with cookie but no header → 403');
  CheckFalse(GHandlerCalled, 'handler not called');
end;

procedure TestPostWithMatchingHeader200;
var
  LReq: IHttpRequest;
  LReqObj: TMockRequest;
  LW: IHttpResponseWriter;
  LWObj: TMockResponseWriter;
  LResult: IHttpHandler;
  LToken: string;
begin
  LToken := ObtainToken('csrf');
  Check(LToken <> '', 'obtained cookie token');
  ResetCapture;
  LReqObj := TMockRequest.Create(hmPost, '/api/data');
  LReqObj.SetHeader('Cookie', 'csrf=' + LToken);
  LReqObj.SetHeader('X-CSRF-Token', LToken);
  LReq := LReqObj;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LResult := Chain(NewCaptureHandler(),
    [IHttpMiddleware(CsrfMiddleware(TCsrfConfig.Default))]);
  LResult.ServeHTTP(LReq, LW);
  CheckEqual(Int64(HTTP_STATUS_OK), Int64(LWObj.Status),
    'POST with matching header → 200');
  Check(True, 'handler called');
end;

procedure TestPostMismatchedHeader403;
var
  LReq: IHttpRequest;
  LReqObj: TMockRequest;
  LW: IHttpResponseWriter;
  LWObj: TMockResponseWriter;
  LResult: IHttpHandler;
  LToken: string;
begin
  LToken := ObtainToken('csrf');
  Check(LToken <> '', 'obtained cookie token');
  ResetCapture;
  LReqObj := TMockRequest.Create(hmPost, '/api/data');
  LReqObj.SetHeader('Cookie', 'csrf=' + LToken);
  LReqObj.SetHeader('X-CSRF-Token', 'A' + Copy(LToken, 2, Length(LToken) - 1));
  LReq := LReqObj;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LResult := Chain(NewCaptureHandler(),
    [IHttpMiddleware(CsrfMiddleware(TCsrfConfig.Default))]);
  LResult.ServeHTTP(LReq, LW);
  CheckEqual(Int64(HTTP_STATUS_FORBIDDEN), Int64(LWObj.Status),
    'POST with same-length wrong token → 403 (constant-time compare)');
  CheckFalse(GHandlerCalled, 'handler not called');
end;

procedure TestHeaderCaseFallback;
var
  LReq: IHttpRequest;
  LReqObj: TMockRequest;
  LW: IHttpResponseWriter;
  LWObj: TMockResponseWriter;
  LResult: IHttpHandler;
  LToken: string;
begin
  LToken := ObtainToken('csrf');
  Check(LToken <> '', 'obtained cookie token');
  ResetCapture;
  LReqObj := TMockRequest.Create(hmPost, '/api/data');
  LReqObj.SetHeader('Cookie', 'csrf=' + LToken);
  { Different header spelling — resolved by case-insensitive lookup. }
  LReqObj.SetHeader('x-csrf-token', LToken);
  LReq := LReqObj;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LResult := Chain(NewCaptureHandler(),
    [IHttpMiddleware(CsrfMiddleware(TCsrfConfig.Default))]);
  LResult.ServeHTTP(LReq, LW);
  CheckEqual(Int64(HTTP_STATUS_OK), Int64(LWObj.Status),
    'lowercase header spelling accepted');
end;

procedure TestSecureModeHostCookie;
var
  LOpts: TCsrfConfig;
  LReq: IHttpRequest;
  LReqObj: TMockRequest;
  LW: IHttpResponseWriter;
  LWObj: TMockResponseWriter;
  LResult: IHttpHandler;
  LSetCookie, LCookieValue: string;
  LCookieName: string;
begin
  LOpts := TCsrfConfig.Default;
  LOpts.SecureMode := csmSecure;
  ResetCapture;
  LReqObj := TMockRequest.Create(hmGet, '/api/data');
  LReq := LReqObj;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LResult := Chain(NewCaptureHandler(),
    [IHttpMiddleware(CsrfMiddleware(LOpts))]);
  LResult.ServeHTTP(LReq, LW);
  LSetCookie := LWObj.Headers.Get('Set-Cookie');
  Check(FirstCookiePair(LSetCookie, LCookieName, LCookieValue),
    'secure-mode Set-Cookie parses');
  CheckEqual('__Host-csrf', LCookieName,
    '__Host- prefix in secure mode');
  Check(Pos('Secure', LSetCookie) > 0, 'Secure attribute emitted');
  Check(Pos('Path=/', LSetCookie) > 0, 'Path=/ emitted (__Host- requires it)');
  Check(Pos('SameSite=Strict', LSetCookie) > 0, 'default SameSite=Strict');

  { Secure-mode token must validate end to end. }
  ResetCapture;
  LReqObj := TMockRequest.Create(hmPost, '/api/data');
  LReqObj.SetHeader('Cookie', '__Host-csrf=' + LCookieValue);
  LReqObj.SetHeader('X-CSRF-Token', LCookieValue);
  LReq := LReqObj;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LResult := Chain(NewCaptureHandler(),
    [IHttpMiddleware(CsrfMiddleware(LOpts))]);
  LResult.ServeHTTP(LReq, LW);
  CheckEqual(Int64(HTTP_STATUS_OK), Int64(LWObj.Status),
    'secure-mode token validates');
end;

procedure TestTokenLengthBounds;
var
  LOpts: TCsrfConfig;
  LRaised: Boolean;
begin
  LOpts := TCsrfConfig.Default;
  LOpts.TokenLength := 8;
  LRaised := False;
  try
    CsrfMiddleware(LOpts);
  except
    on E: Exception do
      LRaised := True;
  end;
  Check(LRaised, 'TokenLength < 16 raises');

  LOpts.TokenLength := 128;
  LRaised := False;
  try
    CsrfMiddleware(LOpts);
  except
    on E: Exception do
      LRaised := True;
  end;
  Check(LRaised, 'TokenLength > 64 raises');

  LOpts.TokenLength := 16;
  LRaised := False;
  try
    CsrfMiddleware(LOpts);
  except
    on E: Exception do
      LRaised := True;
  end;
  Check(not LRaised, 'TokenLength = 16 accepted');

  LOpts.TokenLength := 64;
  LRaised := False;
  try
    CsrfMiddleware(LOpts);
  except
    on E: Exception do
      LRaised := True;
  end;
  Check(not LRaised, 'TokenLength = 64 accepted');
end;

procedure TestOptionsSafeMethod;
var
  LReq: IHttpRequest;
  LReqObj: TMockRequest;
  LW: IHttpResponseWriter;
  LWObj: TMockResponseWriter;
  LResult: IHttpHandler;
begin
  ResetCapture;
  LReqObj := TMockRequest.Create(hmOptions, '/api/data');
  LReq := LReqObj;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LResult := Chain(NewCaptureHandler(),
    [IHttpMiddleware(CsrfMiddleware(TCsrfConfig.Default))]);
  LResult.ServeHTTP(LReq, LW);
  CheckEqual(Int64(HTTP_STATUS_OK), Int64(LWObj.Status),
    'OPTIONS is a safe method → 200');
end;

var
  T: TTestSuite;
begin
  T := TTestSuite.Create('nextpas.core.http.middleware.csrf');
  T.Test('GET without cookie issues cookie + passes', @TestGetWithoutCookieIssuesCookieAndPasses);
  T.Test('GET with cookie passes without re-issue', @TestGetWithCookiePassesWithoutNewCookie);
  T.Test('POST without cookie → 403 + bootstrap cookie', @TestPostWithoutCookie403AndIssuesCookie);
  T.Test('POST with cookie but no header → 403', @TestPostWithCookieNoHeader403);
  T.Test('POST with matching header → 200', @TestPostWithMatchingHeader200);
  T.Test('POST with mismatched header → 403', @TestPostMismatchedHeader403);
  T.Test('header case fallback', @TestHeaderCaseFallback);
  T.Test('secure mode __Host- cookie', @TestSecureModeHostCookie);
  T.Test('token length bounds', @TestTokenLengthBounds);
  T.Test('OPTIONS safe method', @TestOptionsSafeMethod);
  if not T.Run then
    Halt(1);
end.
