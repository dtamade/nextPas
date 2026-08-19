program test_auth;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.test,
  nextpas.core.io.intf,
  nextpas.core.http.base,
  nextpas.core.http.intf,
  nextpas.core.http.headers,
  nextpas.core.http.middleware,
  nextpas.core.http.middleware.auth,
  nextpas.core.http.middleware.context,
  nextpas.core.text.conv;

var
  GHandlerCalled: Boolean;
  GCapturedSubject: string;
  GValidatorSeen: string;

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

  { Full-featured request mock: carries an IHttpContext bag. }
  TMockRequest = class(TInterfacedObject, IHttpRequest, IHttpRequestWithContext)
  private
    FMethod: THttpMethod;
    FUrl: TUrl;
    FHeaders: IHttpHeaders;
    FContext: IHttpContext;
  public
    constructor Create(const AMethod: THttpMethod; const APath: string);
    procedure SetHeader(const AName, AValue: string);
    procedure SetContext(const ACtx: IHttpContext);
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
    function GetContext: IHttpContext;
  end;

  { Minimal request mock without context support (custom request types). }
  TBasicRequest = class(TInterfacedObject, IHttpRequest)
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
  FContext := nil;
end;

procedure TMockRequest.SetHeader(const AName, AValue: string);
begin
  FHeaders.SetHeader(AName, AValue);
end;

procedure TMockRequest.SetContext(const ACtx: IHttpContext);
begin
  FContext := ACtx;
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

function TMockRequest.GetContext: IHttpContext;
begin
  Result := FContext;
end;

{ TBasicRequest }

constructor TBasicRequest.Create(const AMethod: THttpMethod; const APath: string);
begin
  inherited Create;
  FMethod := AMethod;
  FUrl := Default(TUrl);
  FUrl.Path := APath;
  FHeaders := NewHttpHeaders;
end;

procedure TBasicRequest.SetHeader(const AName, AValue: string);
begin
  FHeaders.SetHeader(AName, AValue);
end;

function TBasicRequest.GetMethod: THttpMethod;
begin
  Result := FMethod;
end;

function TBasicRequest.GetUrl: TUrl;
begin
  Result := FUrl;
end;

function TBasicRequest.GetPath: string;
begin
  Result := FUrl.Path;
end;

function TBasicRequest.GetRawQuery: string;
begin
  Result := FUrl.RawQuery;
end;

function TBasicRequest.GetVersion: THttpVersion;
begin
  Result := hvHttp11;
end;

function TBasicRequest.GetHeaders: IHttpHeaders;
begin
  Result := FHeaders;
end;

function TBasicRequest.GetBody: IReader;
begin
  Result := nil;
end;

function TBasicRequest.GetContentLength: Int64;
begin
  Result := 0;
end;

function TBasicRequest.GetTrailers: IHttpHeaders;
begin
  Result := nil;
end;

function TBasicRequest.GetRemoteIp: string;
begin
  Result := GetRemoteAddr;
end;

function TBasicRequest.GetRemoteAddr: string;
begin
  Result := '127.0.0.1';
end;

function TBasicRequest.PathParam(const AName: string): string;
begin
  Result := '';
end;

function TBasicRequest.QueryParam(const AName: string): string;
begin
  Result := '';
end;

{ Handler that records invocation and captures the context subject. }
function NewCaptureHandler: IHttpHandler;
begin
  Result := HandlerFunc(procedure(const AReq: IHttpRequest;
    const AW: IHttpResponseWriter)
  begin
    GHandlerCalled := True;
    GCapturedSubject := HttpContextGetString(HttpContextOf(AReq),
      AUTH_SUBJECT_KEY);
    AW.WriteHeader(HTTP_STATUS_OK);
  end);
end;

procedure ResetCapture;
begin
  GHandlerCalled := False;
  GCapturedSubject := '';
  GValidatorSeen := '';
end;

{ Validator factory: records the credentials it saw, returns a fixed subject. }
function RecordingValidator(const ASubject: string): TAuthValidatorFunc;
var
  LSubject: string;
begin
  LSubject := ASubject;
  Result := function(const AReq: IHttpRequest;
    const AKind: TAuthCredentialKind; const ACredential: string): string
  begin
    GValidatorSeen := 'kind=' + IntToStr(Ord(AKind)) + ':' + ACredential;
    Result := LSubject;
  end;
end;

procedure TestMissingCredentials401;
var
  LReq: IHttpRequest;
  LReqObj: TMockRequest;
  LW: IHttpResponseWriter;
  LWObj: TMockResponseWriter;
  LResult: IHttpHandler;
begin
  ResetCapture;
  LReqObj := TMockRequest.Create(hmGet, '/admin');
  LReq := LReqObj;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LResult := Chain(NewCaptureHandler(),
    [IHttpMiddleware(AuthMiddlewareWithValidator(RecordingValidator('key-1')))]);
  LResult.ServeHTTP(LReq, LW);
  CheckEqual(Int64(HTTP_STATUS_UNAUTHORIZED), Int64(LWObj.Status),
    'missing credentials → 401');
  CheckFalse(GHandlerCalled, 'handler not called');
  CheckEqual('Bearer realm="restricted", ApiKey realm="restricted"',
    LWObj.Headers.Get('www-authenticate'),
    'WWW-Authenticate challenge lists Bearer+ApiKey with default realm');
end;

procedure TestMalformedAuthorization401;
var
  LReq: IHttpRequest;
  LReqObj: TMockRequest;
  LW: IHttpResponseWriter;
  LWObj: TMockResponseWriter;
  LResult: IHttpHandler;
begin
  { Unsupported scheme }
  ResetCapture;
  LReqObj := TMockRequest.Create(hmGet, '/admin');
  LReqObj.SetHeader('Authorization', 'Basic dXNlcjpwYXNz');
  LReq := LReqObj;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LResult := Chain(NewCaptureHandler(),
    [IHttpMiddleware(AuthMiddlewareWithValidator(RecordingValidator('key-1')))]);
  LResult.ServeHTTP(LReq, LW);
  CheckEqual(Int64(HTTP_STATUS_UNAUTHORIZED), Int64(LWObj.Status),
    'Basic scheme → 401 bad format');
  CheckFalse(GHandlerCalled, 'handler not called for Basic scheme');

  { Empty bearer token }
  ResetCapture;
  LReqObj := TMockRequest.Create(hmGet, '/admin');
  LReqObj.SetHeader('Authorization', 'Bearer');
  LReq := LReqObj;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LResult := Chain(NewCaptureHandler(),
    [IHttpMiddleware(AuthMiddlewareWithValidator(RecordingValidator('key-1')))]);
  LResult.ServeHTTP(LReq, LW);
  CheckEqual(Int64(HTTP_STATUS_UNAUTHORIZED), Int64(LWObj.Status),
    'empty bearer token → 401 bad format');
  CheckFalse(GHandlerCalled, 'handler not called for empty token');

  { No space between scheme and token }
  ResetCapture;
  LReqObj := TMockRequest.Create(hmGet, '/admin');
  LReqObj.SetHeader('Authorization', 'BearerTokenNoSpace');
  LReq := LReqObj;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LResult := Chain(NewCaptureHandler(),
    [IHttpMiddleware(AuthMiddlewareWithValidator(RecordingValidator('key-1')))]);
  LResult.ServeHTTP(LReq, LW);
  CheckEqual(Int64(HTTP_STATUS_UNAUTHORIZED), Int64(LWObj.Status),
    'missing scheme separator → 401 bad format');

  { Header present but blank value treated as missing }
  ResetCapture;
  LReqObj := TMockRequest.Create(hmGet, '/admin');
  LReqObj.SetHeader('Authorization', '   ');
  LReq := LReqObj;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LResult := Chain(NewCaptureHandler(),
    [IHttpMiddleware(AuthMiddlewareWithValidator(RecordingValidator('key-1')))]);
  LResult.ServeHTTP(LReq, LW);
  CheckEqual(Int64(HTTP_STATUS_UNAUTHORIZED), Int64(LWObj.Status),
    'blank authorization header → 401');
end;

procedure TestBearerAcceptedIntoContext;
var
  LReq: IHttpRequest;
  LReqObj: TMockRequest;
  LW: IHttpResponseWriter;
  LWObj: TMockResponseWriter;
  LResult: IHttpHandler;
begin
  ResetCapture;
  LReqObj := TMockRequest.Create(hmGet, '/admin');
  LReqObj.SetHeader('Authorization', 'Bearer tok-1');
  LReq := LReqObj;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LResult := Chain(NewCaptureHandler(),
    [IHttpMiddleware(AuthMiddlewareWithValidator(RecordingValidator('key-42')))]);
  LResult.ServeHTTP(LReq, LW);
  CheckEqual(Int64(HTTP_STATUS_OK), Int64(LWObj.Status), 'valid bearer → 200');
  CheckTrue(GHandlerCalled, 'handler called');
  CheckEqual('key-42', GCapturedSubject, 'subject propagated via context');
  CheckEqual('kind=' + IntToStr(Ord(ackBearer)) + ':tok-1', GValidatorSeen,
    'validator saw bearer channel with trimmed token');
end;

procedure TestValidatorRejection403;
var
  LReq: IHttpRequest;
  LReqObj: TMockRequest;
  LW: IHttpResponseWriter;
  LWObj: TMockResponseWriter;
  LResult: IHttpHandler;
begin
  ResetCapture;
  LReqObj := TMockRequest.Create(hmGet, '/admin');
  LReqObj.SetHeader('Authorization', 'Bearer bad-token');
  LReq := LReqObj;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LResult := Chain(NewCaptureHandler(),
    [IHttpMiddleware(AuthMiddlewareWithValidator(RecordingValidator('')))]);
  LResult.ServeHTTP(LReq, LW);
  CheckEqual(Int64(HTTP_STATUS_FORBIDDEN), Int64(LWObj.Status),
    'validator rejection → 403');
  CheckFalse(GHandlerCalled, 'handler not called');
  CheckFalse(LWObj.Headers.Has('www-authenticate'),
    '403 carries no WWW-Authenticate');
end;

procedure TestApiKeyChannel;
var
  LReq: IHttpRequest;
  LReqObj: TMockRequest;
  LW: IHttpResponseWriter;
  LWObj: TMockResponseWriter;
  LResult: IHttpHandler;
begin
  ResetCapture;
  LReqObj := TMockRequest.Create(hmGet, '/data');
  LReqObj.SetHeader('X-API-Key', 'k-7');
  LReq := LReqObj;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LResult := Chain(NewCaptureHandler(),
    [IHttpMiddleware(AuthMiddlewareWithValidator(RecordingValidator('tenant-7')))]);
  LResult.ServeHTTP(LReq, LW);
  CheckEqual(Int64(HTTP_STATUS_OK), Int64(LWObj.Status),
    'valid X-API-Key → 200');
  CheckTrue(GHandlerCalled, 'handler called');
  CheckEqual('tenant-7', GCapturedSubject, 'api-key subject propagated');
  CheckEqual('kind=' + IntToStr(Ord(ackApiKey)) + ':k-7', GValidatorSeen,
    'validator saw api-key channel');

  ResetCapture;
  LReqObj := TMockRequest.Create(hmGet, '/data');
  LReq := LReqObj;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LResult := Chain(NewCaptureHandler(),
    [IHttpMiddleware(AuthMiddlewareWithValidator(RecordingValidator('tenant-7')))]);
  LResult.ServeHTTP(LReq, LW);
  CheckEqual(Int64(HTTP_STATUS_UNAUTHORIZED), Int64(LWObj.Status),
    'missing X-API-Key → 401');
end;

{ 额外 API key 头（F-9）：配置 ExtraApiKeyHeaders 后，除默认 x-api-key 外再
  接受这些头提供 api-key 通道凭证；默认头优先；未配置时不被接受。 }
procedure TestExtraApiKeyHeaders;
var
  LOpts: TAuthOptions;
  LReq: IHttpRequest;
  LReqObj: TMockRequest;
  LW: IHttpResponseWriter;
  LWObj: TMockResponseWriter;
  LResult: IHttpHandler;
begin
  LOpts := Default(TAuthOptions);
  LOpts.Validator := RecordingValidator('admin-9');
  SetLength(LOpts.ExtraApiKeyHeaders, 1);
  LOpts.ExtraApiKeyHeaders[0] := 'x-admin-api-key';

  ResetCapture;
  LReqObj := TMockRequest.Create(hmGet, '/data');
  LReqObj.SetHeader('X-Admin-API-Key', 'k-admin');
  LReq := LReqObj;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LResult := Chain(NewCaptureHandler(),
    [IHttpMiddleware(AuthMiddleware(LOpts))]);
  LResult.ServeHTTP(LReq, LW);
  CheckEqual(Int64(HTTP_STATUS_OK), Int64(LWObj.Status),
    'X-Admin-API-Key via extra header → 200');
  CheckTrue(GHandlerCalled, 'handler called');
  CheckEqual('admin-9', GCapturedSubject,
    'extra-header subject propagated');
  CheckEqual('kind=' + IntToStr(Ord(ackApiKey)) + ':k-admin', GValidatorSeen,
    'extra header presented through api-key channel');

  { 默认 X-API-Key 优先：两者同时存在时取默认头。 }
  ResetCapture;
  LReqObj := TMockRequest.Create(hmGet, '/data');
  LReqObj.SetHeader('X-API-Key', 'k-default');
  LReqObj.SetHeader('X-Admin-API-Key', 'k-admin');
  LReq := LReqObj;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LResult := Chain(NewCaptureHandler(),
    [IHttpMiddleware(AuthMiddleware(LOpts))]);
  LResult.ServeHTTP(LReq, LW);
  CheckEqual(Int64(HTTP_STATUS_OK), Int64(LWObj.Status),
    'default header wins → 200');
  CheckEqual('kind=' + IntToStr(Ord(ackApiKey)) + ':k-default',
    GValidatorSeen, 'default x-api-key preferred over extra header');

  { 额外头缺失（无任何凭证）→ 401。 }
  ResetCapture;
  LReqObj := TMockRequest.Create(hmGet, '/data');
  LReq := LReqObj;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LResult := Chain(NewCaptureHandler(),
    [IHttpMiddleware(AuthMiddleware(LOpts))]);
  LResult.ServeHTTP(LReq, LW);
  CheckEqual(Int64(HTTP_STATUS_UNAUTHORIZED), Int64(LWObj.Status),
    'no credentials → 401');

  { 未配置额外头时 X-Admin-API-Key 不被接受（默认行为不变）。 }
  LOpts := Default(TAuthOptions);
  LOpts.Validator := RecordingValidator('plain-9');
  ResetCapture;
  LReqObj := TMockRequest.Create(hmGet, '/data');
  LReqObj.SetHeader('X-Admin-API-Key', 'k-admin');
  LReq := LReqObj;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LResult := Chain(NewCaptureHandler(),
    [IHttpMiddleware(AuthMiddleware(LOpts))]);
  LResult.ServeHTTP(LReq, LW);
  CheckEqual(Int64(HTTP_STATUS_UNAUTHORIZED), Int64(LWObj.Status),
    'unconfigured extra header not accepted → 401');
end;

procedure TestStaticBearerConstantTimeCompare;
var
  LOpts: TAuthOptions;
  LReq: IHttpRequest;
  LReqObj: TMockRequest;
  LW: IHttpResponseWriter;
  LWObj: TMockResponseWriter;
  LResult: IHttpHandler;
begin
  LOpts := Default(TAuthOptions);
  SetLength(LOpts.BearerTokens, 1);
  LOpts.BearerTokens[0] := 'secret-token-abc';

  { Exact match }
  ResetCapture;
  LReqObj := TMockRequest.Create(hmGet, '/admin');
  LReqObj.SetHeader('Authorization', 'Bearer secret-token-abc');
  LReq := LReqObj;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LResult := Chain(NewCaptureHandler(),
    [IHttpMiddleware(AuthMiddleware(LOpts))]);
  LResult.ServeHTTP(LReq, LW);
  CheckEqual(Int64(HTTP_STATUS_OK), Int64(LWObj.Status),
    'exact static bearer token → 200');
  CheckTrue(GHandlerCalled, 'handler called');
  CheckEqual('secret-token-abc', GCapturedSubject,
    'static match subject is the credential');

  { Same-length wrong token — constant-time compare path }
  ResetCapture;
  LReqObj := TMockRequest.Create(hmGet, '/admin');
  LReqObj.SetHeader('Authorization', 'Bearer secret-token-abd');
  LReq := LReqObj;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LResult := Chain(NewCaptureHandler(),
    [IHttpMiddleware(AuthMiddleware(LOpts))]);
  LResult.ServeHTTP(LReq, LW);
  CheckEqual(Int64(HTTP_STATUS_FORBIDDEN), Int64(LWObj.Status),
    'same-length wrong token → 403');
  CheckFalse(GHandlerCalled, 'handler not called for wrong token');

  { Different-length token }
  ResetCapture;
  LReqObj := TMockRequest.Create(hmGet, '/admin');
  LReqObj.SetHeader('Authorization', 'Bearer short');
  LReq := LReqObj;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LResult := Chain(NewCaptureHandler(),
    [IHttpMiddleware(AuthMiddleware(LOpts))]);
  LResult.ServeHTTP(LReq, LW);
  CheckEqual(Int64(HTTP_STATUS_FORBIDDEN), Int64(LWObj.Status),
    'different-length token → 403');
  CheckFalse(GHandlerCalled, 'handler not called for short token');
end;

procedure TestStaticApiKey;
var
  LOpts: TAuthOptions;
  LReq: IHttpRequest;
  LReqObj: TMockRequest;
  LW: IHttpResponseWriter;
  LWObj: TMockResponseWriter;
  LResult: IHttpHandler;
begin
  LOpts := Default(TAuthOptions);
  SetLength(LOpts.ApiKeys, 1);
  LOpts.ApiKeys[0] := 'k-1';

  ResetCapture;
  LReqObj := TMockRequest.Create(hmGet, '/data');
  LReqObj.SetHeader('X-API-Key', 'k-1');
  LReq := LReqObj;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LResult := Chain(NewCaptureHandler(),
    [IHttpMiddleware(AuthMiddleware(LOpts))]);
  LResult.ServeHTTP(LReq, LW);
  CheckEqual(Int64(HTTP_STATUS_OK), Int64(LWObj.Status),
    'static api key match → 200');

  ResetCapture;
  LReqObj := TMockRequest.Create(hmGet, '/data');
  LReqObj.SetHeader('X-API-Key', 'k-2');
  LReq := LReqObj;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LResult := Chain(NewCaptureHandler(),
    [IHttpMiddleware(AuthMiddleware(LOpts))]);
  LResult.ServeHTTP(LReq, LW);
  CheckEqual(Int64(HTTP_STATUS_FORBIDDEN), Int64(LWObj.Status),
    'static api key mismatch → 403');
end;

procedure TestUnconfiguredChannelRejected;
var
  LOpts: TAuthOptions;
  LReq: IHttpRequest;
  LReqObj: TMockRequest;
  LW: IHttpResponseWriter;
  LWObj: TMockResponseWriter;
  LResult: IHttpHandler;
begin
  { Only bearer configured: an api-key credential is presented but rejected. }
  LOpts := Default(TAuthOptions);
  SetLength(LOpts.BearerTokens, 1);
  LOpts.BearerTokens[0] := 'tok';
  ResetCapture;
  LReqObj := TMockRequest.Create(hmGet, '/admin');
  LReqObj.SetHeader('X-API-Key', 'anything');
  LReq := LReqObj;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LResult := Chain(NewCaptureHandler(),
    [IHttpMiddleware(AuthMiddleware(LOpts))]);
  LResult.ServeHTTP(LReq, LW);
  CheckEqual(Int64(HTTP_STATUS_FORBIDDEN), Int64(LWObj.Status),
    'unconfigured api-key channel → 403');
  CheckFalse(GHandlerCalled, 'handler not called');
end;

procedure TestAuthorizationWinsOverApiKey;
var
  LOpts: TAuthOptions;
  LReq: IHttpRequest;
  LReqObj: TMockRequest;
  LW: IHttpResponseWriter;
  LWObj: TMockResponseWriter;
  LResult: IHttpHandler;
begin
  LOpts := Default(TAuthOptions);
  SetLength(LOpts.BearerTokens, 1);
  LOpts.BearerTokens[0] := 'tok-good';
  SetLength(LOpts.ApiKeys, 1);
  LOpts.ApiKeys[0] := 'k-good';

  { Both headers present; the invalid bearer must win over the valid key. }
  ResetCapture;
  LReqObj := TMockRequest.Create(hmGet, '/admin');
  LReqObj.SetHeader('Authorization', 'Bearer tok-bad');
  LReqObj.SetHeader('X-API-Key', 'k-good');
  LReq := LReqObj;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LResult := Chain(NewCaptureHandler(),
    [IHttpMiddleware(AuthMiddleware(LOpts))]);
  LResult.ServeHTTP(LReq, LW);
  CheckEqual(Int64(HTTP_STATUS_FORBIDDEN), Int64(LWObj.Status),
    'invalid bearer wins over valid api key → 403');
  CheckFalse(GHandlerCalled, 'handler not called');
end;

procedure TestSkipPrefixes;
var
  LOpts: TAuthOptions;
  LReq: IHttpRequest;
  LReqObj: TMockRequest;
  LW: IHttpResponseWriter;
  LWObj: TMockResponseWriter;
  LResult: IHttpHandler;
begin
  LOpts := Default(TAuthOptions);
  SetLength(LOpts.BearerTokens, 1);
  LOpts.BearerTokens[0] := 'tok-ok';
  SetLength(LOpts.SkipPrefixes, 2);
  LOpts.SkipPrefixes[0] := '/health';
  LOpts.SkipPrefixes[1] := '/public';

  ResetCapture;
  LReqObj := TMockRequest.Create(hmGet, '/health');
  LReq := LReqObj;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LResult := Chain(NewCaptureHandler(),
    [IHttpMiddleware(AuthMiddleware(LOpts))]);
  LResult.ServeHTTP(LReq, LW);
  CheckEqual(Int64(HTTP_STATUS_OK), Int64(LWObj.Status),
    'exact skip prefix → 200 without credentials');
  CheckTrue(GHandlerCalled, 'handler called on skipped path');

  { Skipped paths bypass validation entirely: even bad credentials pass. }
  ResetCapture;
  LReqObj := TMockRequest.Create(hmGet, '/health/x');
  LReqObj.SetHeader('Authorization', 'Bearer wrong-token');
  LReq := LReqObj;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LResult := Chain(NewCaptureHandler(),
    [IHttpMiddleware(AuthMiddleware(LOpts))]);
  LResult.ServeHTTP(LReq, LW);
  CheckEqual(Int64(HTTP_STATUS_OK), Int64(LWObj.Status),
    'skip prefix ignores credentials → 200');

  ResetCapture;
  LReqObj := TMockRequest.Create(hmGet, '/health/db');
  LReq := LReqObj;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LResult := Chain(NewCaptureHandler(),
    [IHttpMiddleware(AuthMiddleware(LOpts))]);
  LResult.ServeHTTP(LReq, LW);
  CheckEqual(Int64(HTTP_STATUS_OK), Int64(LWObj.Status),
    'sub-path of skip prefix → 200 without credentials');

  ResetCapture;
  LReqObj := TMockRequest.Create(hmGet, '/public/x');
  LReq := LReqObj;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LResult := Chain(NewCaptureHandler(),
    [IHttpMiddleware(AuthMiddleware(LOpts))]);
  LResult.ServeHTTP(LReq, LW);
  CheckEqual(Int64(HTTP_STATUS_OK), Int64(LWObj.Status),
    'segmented skip prefix → 200 without credentials');

  { Segment boundary: /healthz must NOT be exempt. }
  ResetCapture;
  LReqObj := TMockRequest.Create(hmGet, '/healthz');
  LReq := LReqObj;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LResult := Chain(NewCaptureHandler(),
    [IHttpMiddleware(AuthMiddleware(LOpts))]);
  LResult.ServeHTTP(LReq, LW);
  CheckEqual(Int64(HTTP_STATUS_UNAUTHORIZED), Int64(LWObj.Status),
    '/healthz not matched by /health → 401');
  CheckFalse(GHandlerCalled, 'handler not called on /healthz');

  ResetCapture;
  LReqObj := TMockRequest.Create(hmGet, '/private');
  LReq := LReqObj;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LResult := Chain(NewCaptureHandler(),
    [IHttpMiddleware(AuthMiddleware(LOpts))]);
  LResult.ServeHTTP(LReq, LW);
  CheckEqual(Int64(HTTP_STATUS_UNAUTHORIZED), Int64(LWObj.Status),
    'non-exempt path → 401');
end;

procedure TestRealmOption;
var
  LOpts: TAuthOptions;
  LReq: IHttpRequest;
  LReqObj: TMockRequest;
  LW: IHttpResponseWriter;
  LWObj: TMockResponseWriter;
  LResult: IHttpHandler;
begin
  { Custom realm }
  LOpts := Default(TAuthOptions);
  SetLength(LOpts.BearerTokens, 1);
  LOpts.BearerTokens[0] := 'tok';
  LOpts.Realm := 'gateway-api';
  ResetCapture;
  LReqObj := TMockRequest.Create(hmGet, '/admin');
  LReq := LReqObj;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LResult := Chain(NewCaptureHandler(),
    [IHttpMiddleware(AuthMiddleware(LOpts))]);
  LResult.ServeHTTP(LReq, LW);
  CheckEqual('Bearer realm="gateway-api"',
    LWObj.Headers.Get('www-authenticate'),
    'custom realm in WWW-Authenticate');

  { Missing credentials when only bearer static configured: no ApiKey challenge }
  LOpts := Default(TAuthOptions);
  SetLength(LOpts.BearerTokens, 1);
  LOpts.BearerTokens[0] := 'tok';
  ResetCapture;
  LReqObj := TMockRequest.Create(hmGet, '/admin');
  LReq := LReqObj;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LResult := Chain(NewCaptureHandler(),
    [IHttpMiddleware(AuthMiddleware(LOpts))]);
  LResult.ServeHTTP(LReq, LW);
  CheckEqual('Bearer realm="restricted"',
    LWObj.Headers.Get('www-authenticate'),
    'default realm, no ApiKey challenge when channel unconfigured');
end;

procedure TestContextBagLifecycle;
var
  LReq: IHttpRequest;
  LReqObj: TMockRequest;
  LW: IHttpResponseWriter;
  LWObj: TMockResponseWriter;
  LResult: IHttpHandler;
  LExisting: IHttpContext;
begin
  { Auth attaches a fresh bag and detaches it after the handler. }
  ResetCapture;
  LReqObj := TMockRequest.Create(hmGet, '/admin');
  LReqObj.SetHeader('Authorization', 'Bearer tok-1');
  LReq := LReqObj;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LResult := Chain(NewCaptureHandler(),
    [IHttpMiddleware(AuthMiddlewareWithValidator(RecordingValidator('key-42')))]);
  LResult.ServeHTTP(LReq, LW);
  CheckEqual(Int64(HTTP_STATUS_OK), Int64(LWObj.Status),
    'authorized with fresh bag → 200');
  CheckEqual('key-42', GCapturedSubject, 'subject read inside handler');
  Check(LReqObj.GetContext = nil, 'auth-created bag detached after handler');

  { An existing bag (ContextMiddleware-style) is reused, not replaced. }
  ResetCapture;
  LExisting := NewHttpContext;
  LReqObj := TMockRequest.Create(hmGet, '/admin');
  LReqObj.SetHeader('Authorization', 'Bearer tok-1');
  LReqObj.SetContext(LExisting);
  LReq := LReqObj;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LResult := Chain(NewCaptureHandler(),
    [IHttpMiddleware(AuthMiddlewareWithValidator(RecordingValidator('key-9')))]);
  LResult.ServeHTTP(LReq, LW);
  CheckEqual(Int64(HTTP_STATUS_OK), Int64(LWObj.Status),
    'authorized with existing bag → 200');
  CheckEqual('key-9', GCapturedSubject, 'subject read inside handler');
  CheckEqual('key-9', HttpContextGetString(LExisting, AUTH_SUBJECT_KEY),
    'subject stored in the existing bag');
  CheckNotNil(LReqObj.GetContext, 'existing bag left attached');
end;

procedure TestNoContextRequestStillAuthorizes;
var
  LReq: IHttpRequest;
  LReqObj: TBasicRequest;
  LW: IHttpResponseWriter;
  LWObj: TMockResponseWriter;
  LResult: IHttpHandler;
begin
  { Request types without context support still get authorized (subject dropped). }
  ResetCapture;
  LReqObj := TBasicRequest.Create(hmGet, '/admin');
  LReqObj.SetHeader('Authorization', 'Bearer tok-1');
  LReq := LReqObj;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LResult := Chain(NewCaptureHandler(),
    [IHttpMiddleware(AuthMiddlewareWithValidator(RecordingValidator('key-1')))]);
  LResult.ServeHTTP(LReq, LW);
  CheckEqual(Int64(HTTP_STATUS_OK), Int64(LWObj.Status),
    'context-less request still authorized → 200');
  CheckTrue(GHandlerCalled, 'handler called for context-less request');
end;

procedure TestConstructionValidation;
var
  LOpts: TAuthOptions;
  LRaised: Boolean;
begin
  LOpts := Default(TAuthOptions);
  LRaised := False;
  try
    AuthMiddleware(LOpts);
  except
    on E: Exception do
      LRaised := True;
  end;
  Check(LRaised, 'options without validator/static credentials raise');

  LRaised := False;
  try
    AuthMiddlewareWithValidator(nil);
  except
    on E: Exception do
      LRaised := True;
  end;
  Check(LRaised, 'nil validator raises');
end;

var
  T: TTestSuite;
begin
  T := TTestSuite.Create('nextpas.core.http.middleware.auth');
  T.Test('Missing credentials → 401 + WWW-Authenticate', @TestMissingCredentials401);
  T.Test('Malformed Authorization → 401', @TestMalformedAuthorization401);
  T.Test('Bearer accepted, subject into context', @TestBearerAcceptedIntoContext);
  T.Test('Validator rejection → 403', @TestValidatorRejection403);
  T.Test('X-API-Key channel', @TestApiKeyChannel);
  T.Test('Extra API key headers (F-9)', @TestExtraApiKeyHeaders);
  T.Test('Static bearer constant-time compare', @TestStaticBearerConstantTimeCompare);
  T.Test('Static API key', @TestStaticApiKey);
  T.Test('Unconfigured channel rejected', @TestUnconfiguredChannelRejected);
  T.Test('Authorization wins over X-API-Key', @TestAuthorizationWinsOverApiKey);
  T.Test('Skip prefixes bypass auth', @TestSkipPrefixes);
  T.Test('Realm option in WWW-Authenticate', @TestRealmOption);
  T.Test('Context bag lifecycle', @TestContextBagLifecycle);
  T.Test('Context-less request still authorized', @TestNoContextRequestStillAuthorizes);
  T.Test('Construction validation', @TestConstructionValidation);
  if not T.Run then
    Halt(1);
end.