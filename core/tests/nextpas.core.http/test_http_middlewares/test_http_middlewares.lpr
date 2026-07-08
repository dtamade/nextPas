program test_http_middlewares;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.base,
  nextpas.core.test,
  nextpas.core.io.intf,
  nextpas.core.http.base,
  nextpas.core.http.intf,
  nextpas.core.http.headers,
  nextpas.core.http.middleware,
  nextpas.core.http.middleware.recovery,
  nextpas.core.http.middleware.logger,
  nextpas.core.http.middleware.cors,
  nextpas.core.http.middleware.timeout,
  nextpas.core.http.middleware.bodylimit,
  nextpas.core.http.middleware.contenttype,
  nextpas.core.http.middleware.requestid,
  nextpas.core.time.base,
  nextpas.core.time.sleep;

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
  end;

  TMockRequest = class(TInterfacedObject, IHttpRequest)
  private
    FMethod: THttpMethod;
    FUrl: TUrl;
    FHeaders: IHttpHeaders;
    FContentLength: Int64;
  public
    constructor Create(const AMethod: THttpMethod; const APath: string);
    procedure SetContentLength(const AValue: Int64);
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
  FContentLength := 0;
end;

procedure TMockRequest.SetContentLength(const AValue: Int64);
begin
  FContentLength := AValue;
end;

function TMockRequest.GetMethod: THttpMethod;
begin Result := FMethod; end;

function TMockRequest.GetUrl: TUrl;
begin Result := FUrl; end;

function TMockRequest.GetPath: string;
begin Result := FUrl.Path; end;

function TMockRequest.GetRawQuery: string;
begin Result := FUrl.RawQuery; end;

function TMockRequest.GetVersion: THttpVersion;
begin Result := hvHttp11; end;

function TMockRequest.GetHeaders: IHttpHeaders;
begin Result := FHeaders; end;

function TMockRequest.GetBody: IReader;
begin Result := nil; end;

function TMockRequest.GetContentLength: Int64;
begin Result := FContentLength; end;

function TMockRequest.GetTrailers: IHttpHeaders;
begin Result := nil; end;

function TMockRequest.GetRemoteAddr: string;
begin Result := '127.0.0.1'; end;

function TMockRequest.PathParam(const AName: string): string;
begin Result := ''; end;

function TMockRequest.QueryParam(const AName: string): string;
begin Result := ''; end;

{ === Recovery Tests === }

procedure TestRecoveryHandlerRaises;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: IHttpRequest;
begin
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      raise Exception.Create('db password=secret');
    end),
    [RecoveryMiddleware]
  );
  LReq := TMockRequest.Create(hmGet, '/crash');
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReq, LW);
  CheckEqual(Int64(500), Int64(LWObj.Status), 'recovery returns 500');
  CheckEqual('Internal Server Error', LWObj.Body, 'recovery returns generic body');
  Check(Pos('password', LWObj.Body) = 0, 'body does not expose field names');
  Check(Pos('secret', LWObj.Body) = 0, 'body does not expose secret values');
end;

procedure TestRecoveryHandlerSucceeds;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: IHttpRequest;
  LBody: string;
begin
  LBody := 'ok';
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      AW.WriteHeader(HTTP_STATUS_OK);
      AW.Write(LBody[1], Length(LBody));
    end),
    [RecoveryMiddleware]
  );
  LReq := TMockRequest.Create(hmGet, '/ok');
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReq, LW);
  CheckEqual(Int64(200), Int64(LWObj.Status), 'success passes through');
  CheckEqual('ok', LWObj.Body, 'body passes through');
end;

procedure TestRecoveryHidesExceptionDetails;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: IHttpRequest;
begin
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      raise Exception.Create('detailed error info');
    end),
    [RecoveryMiddleware]
  );
  LReq := TMockRequest.Create(hmGet, '/err');
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReq, LW);
  CheckEqual(Int64(500), Int64(LWObj.Status), 'recovery returns 500 for detailed error');
  CheckEqual('Internal Server Error', LWObj.Body, 'recovery hides detailed body');
  Check(Pos('detailed error info', LWObj.Body) = 0, 'body does not expose exception message');
end;

{ === Logger Tests === }

procedure TestLoggerCallsNext;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: IHttpRequest;
  LBody: string;
begin
  LBody := 'logged';
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      AW.WriteHeader(HTTP_STATUS_OK);
      AW.Write(LBody[1], Length(LBody));
    end),
    [LoggerMiddleware]
  );
  LReq := TMockRequest.Create(hmGet, '/log');
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReq, LW);
  CheckEqual('logged', LWObj.Body, 'logger passes response body');
end;

procedure TestLoggerPreservesStatus;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: IHttpRequest;
begin
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      AW.WriteHeader(HTTP_STATUS_CREATED);
    end),
    [LoggerMiddleware]
  );
  LReq := TMockRequest.Create(hmPost, '/create');
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReq, LW);
  CheckEqual(Int64(201), Int64(LWObj.Status), 'logger preserves status');
end;

procedure TestLoggerNoCrash;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: IHttpRequest;
begin
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      AW.WriteHeader(HTTP_STATUS_NOT_FOUND);
    end),
    [LoggerMiddleware]
  );
  LReq := TMockRequest.Create(hmGet, '/missing');
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReq, LW);
  CheckEqual(Int64(404), Int64(LWObj.Status), 'logger handles 404 without crash');
end;

{ === CORS Tests === }

procedure TestCorsPreflight;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: TMockRequest;
  LReqIntf: IHttpRequest;
begin
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      AW.WriteHeader(HTTP_STATUS_OK);
    end),
    [CorsMiddleware(TCorsOptions.Default)]
  );
  LReq := TMockRequest.Create(hmOptions, '/api');
  LReq.GetHeaders.SetHeader('Origin', 'http://example.com');
  LReqIntf := LReq;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReqIntf, LW);
  CheckEqual(Int64(204), Int64(LWObj.Status), 'preflight returns 204');
  CheckEqual('*', LWObj.GetHeaders.Get('Access-Control-Allow-Origin'), 'ACAO header');
end;

procedure TestCorsNormalRequest;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: TMockRequest;
  LReqIntf: IHttpRequest;
  LBody: string;
begin
  LBody := 'data';
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      AW.WriteHeader(HTTP_STATUS_OK);
      AW.Write(LBody[1], Length(LBody));
    end),
    [CorsMiddleware(TCorsOptions.Default)]
  );
  LReq := TMockRequest.Create(hmGet, '/api');
  LReq.GetHeaders.SetHeader('Origin', 'http://example.com');
  LReqIntf := LReq;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReqIntf, LW);
  CheckEqual(Int64(200), Int64(LWObj.Status), 'normal request passes');
  CheckEqual('*', LWObj.GetHeaders.Get('Access-Control-Allow-Origin'), 'ACAO on normal');
  CheckEqual('data', LWObj.Body, 'body passes through');
end;

procedure TestCorsNoOriginHeader;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: IHttpRequest;
begin
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      AW.WriteHeader(HTTP_STATUS_OK);
    end),
    [CorsMiddleware(TCorsOptions.Default)]
  );
  LReq := TMockRequest.Create(hmGet, '/api');
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReq, LW);
  CheckEqual(Int64(200), Int64(LWObj.Status), 'no origin passes through');
  CheckEqual('', LWObj.GetHeaders.Get('Access-Control-Allow-Origin'), 'no CORS headers');
end;

procedure TestCorsCredentials;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: TMockRequest;
  LReqIntf: IHttpRequest;
  LOpts: TCorsOptions;
begin
  LOpts := TCorsOptions.Default;
  LOpts.AllowCredentials := True;
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      AW.WriteHeader(HTTP_STATUS_OK);
    end),
    [CorsMiddleware(LOpts)]
  );
  LReq := TMockRequest.Create(hmGet, '/api');
  LReq.GetHeaders.SetHeader('Origin', 'http://example.com');
  LReqIntf := LReq;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReqIntf, LW);
  CheckEqual('true', LWObj.GetHeaders.Get('Access-Control-Allow-Credentials'), 'credentials header');
end;

procedure TestCorsSpecificOriginAllowed;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: TMockRequest;
  LReqIntf: IHttpRequest;
  LOpts: TCorsOptions;
begin
  LOpts := TCorsOptions.Default;
  LOpts.AllowOrigins := 'https://trusted.com, https://other.com';
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      AW.WriteHeader(HTTP_STATUS_OK);
    end),
    [CorsMiddleware(LOpts)]
  );
  LReq := TMockRequest.Create(hmGet, '/api');
  LReq.GetHeaders.SetHeader('Origin', 'https://trusted.com');
  LReqIntf := LReq;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReqIntf, LW);
  CheckEqual('https://trusted.com', LWObj.GetHeaders.Get('Access-Control-Allow-Origin'),
    'specific origin echoed');
  CheckEqual('Origin', LWObj.GetHeaders.Get('Vary'), 'Vary: Origin for specific origin');
end;

procedure TestCorsSpecificOriginDenied;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: TMockRequest;
  LReqIntf: IHttpRequest;
  LOpts: TCorsOptions;
begin
  LOpts := TCorsOptions.Default;
  LOpts.AllowOrigins := 'https://trusted.com';
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      AW.WriteHeader(HTTP_STATUS_OK);
    end),
    [CorsMiddleware(LOpts)]
  );
  LReq := TMockRequest.Create(hmGet, '/api');
  LReq.GetHeaders.SetHeader('Origin', 'https://evil.com');
  LReqIntf := LReq;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReqIntf, LW);
  CheckEqual('', LWObj.GetHeaders.Get('Access-Control-Allow-Origin'),
    'disallowed origin gets no ACAO');
end;

procedure TestCorsCredentialsWildcardEchoesOrigin;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: TMockRequest;
  LReqIntf: IHttpRequest;
  LOpts: TCorsOptions;
begin
  LOpts := TCorsOptions.Default;
  LOpts.AllowOrigins := '*';
  LOpts.AllowCredentials := True;
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      AW.WriteHeader(HTTP_STATUS_OK);
    end),
    [CorsMiddleware(LOpts)]
  );
  LReq := TMockRequest.Create(hmGet, '/api');
  LReq.GetHeaders.SetHeader('Origin', 'http://example.com');
  LReqIntf := LReq;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReqIntf, LW);
  CheckEqual('http://example.com', LWObj.GetHeaders.Get('Access-Control-Allow-Origin'),
    'credentials+wildcard echoes concrete origin, not *');
  CheckEqual('true', LWObj.GetHeaders.Get('Access-Control-Allow-Credentials'),
    'credentials header present');
  CheckEqual('Origin', LWObj.GetHeaders.Get('Vary'), 'Vary: Origin for echoed origin');
end;

procedure TestCorsMaxAge;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: TMockRequest;
  LReqIntf: IHttpRequest;
  LOpts: TCorsOptions;
begin
  LOpts := TCorsOptions.Default;
  LOpts.MaxAge := 3600;
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      AW.WriteHeader(HTTP_STATUS_OK);
    end),
    [CorsMiddleware(LOpts)]
  );
  LReq := TMockRequest.Create(hmOptions, '/api');
  LReq.GetHeaders.SetHeader('Origin', 'http://example.com');
  LReqIntf := LReq;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReqIntf, LW);
  CheckEqual('3600', LWObj.GetHeaders.Get('Access-Control-Max-Age'), 'MaxAge header');
end;

procedure TestCorsCustomMethodsHeaders;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: TMockRequest;
  LReqIntf: IHttpRequest;
  LOpts: TCorsOptions;
begin
  LOpts := TCorsOptions.Default;
  LOpts.AllowMethods := 'GET, POST, PATCH';
  LOpts.AllowHeaders := 'Content-Type, X-Custom';
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      AW.WriteHeader(HTTP_STATUS_OK);
    end),
    [CorsMiddleware(LOpts)]
  );
  LReq := TMockRequest.Create(hmOptions, '/api');
  LReq.GetHeaders.SetHeader('Origin', 'http://example.com');
  LReqIntf := LReq;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReqIntf, LW);
  CheckEqual('GET, POST, PATCH', LWObj.GetHeaders.Get('Access-Control-Allow-Methods'),
    'custom AllowMethods');
  CheckEqual('Content-Type, X-Custom', LWObj.GetHeaders.Get('Access-Control-Allow-Headers'),
    'custom AllowHeaders');
end;

{ === Timeout Tests === }

procedure TestTimeoutFastHandler;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: IHttpRequest;
begin
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      AW.WriteHeader(HTTP_STATUS_OK);
    end),
    [TimeoutMiddleware]
  );
  LReq := TMockRequest.Create(hmGet, '/fast');
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReq, LW);
  CheckEqual(Int64(200), Int64(LWObj.Status), 'fast handler OK');
  Check(LWObj.GetHeaders.Has('X-Response-Time'), 'has X-Response-Time header');
end;

procedure TestTimeoutSlowHandler;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: IHttpRequest;
  LVal: string;
begin
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      TSleep.ForDuration(TDuration.FromMilliseconds(50));
      AW.WriteHeader(HTTP_STATUS_OK);
    end),
    [TimeoutMiddleware]
  );
  LReq := TMockRequest.Create(hmGet, '/slow');
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReq, LW);
  CheckEqual(Int64(200), Int64(LWObj.Status), 'slow handler still completes');
  LVal := LWObj.GetHeaders.Get('X-Response-Time');
  Check(LVal <> '', 'X-Response-Time present for slow handler');
end;

procedure TestTimeoutResponseTimeValue;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: IHttpRequest;
  LVal: string;
begin
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      AW.WriteHeader(HTTP_STATUS_OK);
    end),
    [TimeoutMiddleware]
  );
  LReq := TMockRequest.Create(hmGet, '/check');
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReq, LW);
  LVal := LWObj.GetHeaders.Get('X-Response-Time');
  Check(Pos('ms', LVal) > 0, 'X-Response-Time contains ms suffix');
end;

{ === BodyLimit Tests === }

procedure TestBodyLimitUnderLimitPasses;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: TMockRequest;
  LReqIntf: IHttpRequest;
begin
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      AW.WriteHeader(HTTP_STATUS_OK);
    end),
    [BodyLimitMiddleware(1024)]
  );
  LReq := TMockRequest.Create(hmPost, '/upload');
  LReq.SetContentLength(512);
  LReqIntf := LReq;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReqIntf, LW);
  CheckEqual(Int64(200), Int64(LWObj.Status), 'under limit passes through');
end;

procedure TestBodyLimitOverLimitRejects;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: TMockRequest;
  LReqIntf: IHttpRequest;
begin
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      AW.WriteHeader(HTTP_STATUS_OK);
    end),
    [BodyLimitMiddleware(1024)]
  );
  LReq := TMockRequest.Create(hmPost, '/upload');
  LReq.SetContentLength(2048);
  LReqIntf := LReq;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReqIntf, LW);
  CheckEqual(Int64(413), Int64(LWObj.Status), 'over limit returns 413');
  Check(Pos('too large', LWObj.Body) > 0, 'body contains error message');
end;

procedure TestBodyLimitExactLimitPasses;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: TMockRequest;
  LReqIntf: IHttpRequest;
begin
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      AW.WriteHeader(HTTP_STATUS_OK);
    end),
    [BodyLimitMiddleware(1024)]
  );
  LReq := TMockRequest.Create(hmPost, '/upload');
  LReq.SetContentLength(1024);
  LReqIntf := LReq;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReqIntf, LW);
  CheckEqual(Int64(200), Int64(LWObj.Status), 'exact limit passes through');
end;

procedure TestBodyLimitNoContentLengthPasses;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: TMockRequest;
  LReqIntf: IHttpRequest;
begin
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      AW.WriteHeader(HTTP_STATUS_OK);
    end),
    [BodyLimitMiddleware(1024)]
  );
  LReq := TMockRequest.Create(hmGet, '/api');
  LReqIntf := LReq;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReqIntf, LW);
  CheckEqual(Int64(200), Int64(LWObj.Status), 'no content-length passes through');
end;

procedure TestBodyLimitZeroContentLengthPasses;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: TMockRequest;
  LReqIntf: IHttpRequest;
begin
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      AW.WriteHeader(HTTP_STATUS_OK);
    end),
    [BodyLimitMiddleware(1024)]
  );
  LReq := TMockRequest.Create(hmPost, '/api');
  LReq.SetContentLength(0);
  LReqIntf := LReq;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReqIntf, LW);
  CheckEqual(Int64(200), Int64(LWObj.Status), 'zero content-length passes through');
end;

procedure TestBodyLimitRejectsHandlerNotCalled;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: TMockRequest;
  LReqIntf: IHttpRequest;
  LHandlerCalled: Boolean;
begin
  LHandlerCalled := False;
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      LHandlerCalled := True;
      AW.WriteHeader(HTTP_STATUS_OK);
    end),
    [BodyLimitMiddleware(100)]
  );
  LReq := TMockRequest.Create(hmPost, '/upload');
  LReq.SetContentLength(999);
  LReqIntf := LReq;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReqIntf, LW);
  CheckEqual(Int64(413), Int64(LWObj.Status), 'reject returns 413');
  Check(not LHandlerCalled, 'handler not called when rejected');
end;

{ ContentTypeMiddleware tests }

procedure TestContentTypeAcceptedPasses;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: TMockRequest;
  LReqIntf: IHttpRequest;
  LHandlerCalled: Boolean;
begin
  LHandlerCalled := False;
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      LHandlerCalled := True;
      AW.WriteHeader(HTTP_STATUS_OK);
    end),
    [ContentTypeMiddleware(['application/json'])]
  );
  LReq := TMockRequest.Create(hmPost, '/api');
  LReq.GetHeaders.SetHeader('content-type', 'application/json');
  LReqIntf := LReq;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReqIntf, LW);
  Check(LHandlerCalled, 'handler called for accepted type');
  CheckEqual(Int64(200), Int64(LWObj.Status), 'status 200');
end;

procedure TestContentTypeRejectedReturns415;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: TMockRequest;
  LReqIntf: IHttpRequest;
  LHandlerCalled: Boolean;
begin
  LHandlerCalled := False;
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      LHandlerCalled := True;
      AW.WriteHeader(HTTP_STATUS_OK);
    end),
    [ContentTypeMiddleware(['application/json'])]
  );
  LReq := TMockRequest.Create(hmPost, '/api');
  LReq.GetHeaders.SetHeader('content-type', 'text/plain');
  LReqIntf := LReq;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReqIntf, LW);
  Check(not LHandlerCalled, 'handler not called for rejected type');
  CheckEqual(Int64(415), Int64(LWObj.Status), 'status 415');
end;

procedure TestContentTypeIgnoresParams;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: TMockRequest;
  LReqIntf: IHttpRequest;
  LHandlerCalled: Boolean;
begin
  LHandlerCalled := False;
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      LHandlerCalled := True;
      AW.WriteHeader(HTTP_STATUS_OK);
    end),
    [ContentTypeMiddleware(['application/json'])]
  );
  LReq := TMockRequest.Create(hmPost, '/api');
  LReq.GetHeaders.SetHeader('content-type', 'application/json; charset=utf-8');
  LReqIntf := LReq;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReqIntf, LW);
  Check(LHandlerCalled, 'handler called when params match');
end;

procedure TestContentTypeGetSkipsCheck;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: TMockRequest;
  LReqIntf: IHttpRequest;
  LHandlerCalled: Boolean;
begin
  LHandlerCalled := False;
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      LHandlerCalled := True;
      AW.WriteHeader(HTTP_STATUS_OK);
    end),
    [ContentTypeMiddleware(['application/json'])]
  );
  LReq := TMockRequest.Create(hmGet, '/api');
  LReq.GetHeaders.SetHeader('content-type', 'text/plain');
  LReqIntf := LReq;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReqIntf, LW);
  Check(LHandlerCalled, 'handler called for GET even with wrong type');
  CheckEqual(Int64(200), Int64(LWObj.Status), 'status 200');
end;

procedure TestContentTypeEmptyAllowsAny;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: TMockRequest;
  LReqIntf: IHttpRequest;
  LHandlerCalled: Boolean;
begin
  LHandlerCalled := False;
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      LHandlerCalled := True;
      AW.WriteHeader(HTTP_STATUS_OK);
    end),
    [ContentTypeMiddleware([])]
  );
  LReq := TMockRequest.Create(hmPost, '/api');
  LReq.GetHeaders.SetHeader('content-type', 'anything/at-all');
  LReqIntf := LReq;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReqIntf, LW);
  Check(LHandlerCalled, 'handler called when accepted list empty');
end;

procedure TestContentTypeMissingPasses;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: TMockRequest;
  LReqIntf: IHttpRequest;
  LHandlerCalled: Boolean;
begin
  LHandlerCalled := False;
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      LHandlerCalled := True;
      AW.WriteHeader(HTTP_STATUS_OK);
    end),
    [ContentTypeMiddleware(['application/json'])]
  );
  LReq := TMockRequest.Create(hmPost, '/api');
  LReqIntf := LReq;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReqIntf, LW);
  Check(LHandlerCalled, 'handler called when no content-type');
end;

{ RequestIdMiddleware tests }

procedure TestRequestIdGeneratesId;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: TMockRequest;
  LReqIntf: IHttpRequest;
  LRequestId: string;
begin
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      AW.WriteHeader(HTTP_STATUS_OK);
    end),
    [RequestIdMiddleware]
  );
  LReq := TMockRequest.Create(hmGet, '/api');
  LReqIntf := LReq;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReqIntf, LW);
  LRequestId := LWObj.GetHeaders.Get('x-request-id');
  Check(LRequestId <> '', 'request id is set');
  Check(Length(LRequestId) = 36, 'request id is UUID format');
end;

procedure TestRequestIdPreservesExisting;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: TMockRequest;
  LReqIntf: IHttpRequest;
begin
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      AW.WriteHeader(HTTP_STATUS_OK);
    end),
    [RequestIdMiddleware]
  );
  LReq := TMockRequest.Create(hmGet, '/api');
  LReq.GetHeaders.SetHeader('x-request-id', 'my-trace-123');
  LReqIntf := LReq;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReqIntf, LW);
  CheckEqual('my-trace-123', LWObj.GetHeaders.Get('x-request-id'), 'preserves existing id');
end;

procedure TestRequestIdCustomHeader;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: TMockRequest;
  LReqIntf: IHttpRequest;
  LRequestId: string;
begin
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      AW.WriteHeader(HTTP_STATUS_OK);
    end),
    [RequestIdMiddlewareWith('x-correlation-id')]
  );
  LReq := TMockRequest.Create(hmGet, '/api');
  LReqIntf := LReq;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReqIntf, LW);
  LRequestId := LWObj.GetHeaders.Get('x-correlation-id');
  Check(LRequestId <> '', 'custom header is set');
  CheckEqual('', LWObj.GetHeaders.Get('x-request-id'), 'default header not set');
end;

procedure TestRequestIdUniquePerRequest;
var
  LHandler: IHttpHandler;
  LW1, LW2: TMockResponseWriter;
  LWIntf1, LWIntf2: IHttpResponseWriter;
  LReq1, LReq2: TMockRequest;
  LReqIntf1, LReqIntf2: IHttpRequest;
begin
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      AW.WriteHeader(HTTP_STATUS_OK);
    end),
    [RequestIdMiddleware]
  );
  LReq1 := TMockRequest.Create(hmGet, '/a');
  LReqIntf1 := LReq1;
  LW1 := TMockResponseWriter.Create;
  LWIntf1 := LW1;
  LHandler.ServeHTTP(LReqIntf1, LWIntf1);
  LReq2 := TMockRequest.Create(hmGet, '/b');
  LReqIntf2 := LReq2;
  LW2 := TMockResponseWriter.Create;
  LWIntf2 := LW2;
  LHandler.ServeHTTP(LReqIntf2, LWIntf2);
  Check(LW1.GetHeaders.Get('x-request-id') <> LW2.GetHeaders.Get('x-request-id'),
    'different requests get different ids');
end;

var
  T: TTestSuite;
begin
  T := TTestSuite.Create('nextpas.core.http.middlewares');
  { Recovery }
  T.Test('Recovery: handler raises → 500', @TestRecoveryHandlerRaises);
  T.Test('Recovery: handler succeeds → passthrough', @TestRecoveryHandlerSucceeds);
  T.Test('Recovery: exception details hidden', @TestRecoveryHidesExceptionDetails);
  { Logger }
  T.Test('Logger: calls next handler', @TestLoggerCallsNext);
  T.Test('Logger: preserves status', @TestLoggerPreservesStatus);
  T.Test('Logger: no crash on 404', @TestLoggerNoCrash);
  { CORS }
  T.Test('CORS: preflight → 204 + headers', @TestCorsPreflight);
  T.Test('CORS: normal GET with Origin', @TestCorsNormalRequest);
  T.Test('CORS: no Origin → no CORS headers', @TestCorsNoOriginHeader);
  T.Test('CORS: AllowCredentials header', @TestCorsCredentials);
  T.Test('CORS: specific origin allowed + Vary', @TestCorsSpecificOriginAllowed);
  T.Test('CORS: specific origin denied', @TestCorsSpecificOriginDenied);
  T.Test('CORS: credentials+wildcard echoes origin', @TestCorsCredentialsWildcardEchoesOrigin);
  T.Test('CORS: MaxAge header', @TestCorsMaxAge);
  T.Test('CORS: custom AllowMethods/AllowHeaders', @TestCorsCustomMethodsHeaders);
  { Timeout }
  T.Test('Timeout: fast handler has X-Response-Time', @TestTimeoutFastHandler);
  T.Test('Timeout: slow handler still works', @TestTimeoutSlowHandler);
  T.Test('Timeout: X-Response-Time has ms suffix', @TestTimeoutResponseTimeValue);
  { BodyLimit }
  T.Test('BodyLimit: under limit passes through', @TestBodyLimitUnderLimitPasses);
  T.Test('BodyLimit: over limit returns 413', @TestBodyLimitOverLimitRejects);
  T.Test('BodyLimit: exact limit passes through', @TestBodyLimitExactLimitPasses);
  T.Test('BodyLimit: no content-length passes through', @TestBodyLimitNoContentLengthPasses);
  T.Test('BodyLimit: zero content-length passes through', @TestBodyLimitZeroContentLengthPasses);
  T.Test('BodyLimit: handler not called on reject', @TestBodyLimitRejectsHandlerNotCalled);
  { ContentType }
  T.Test('ContentType: accepted type passes through', @TestContentTypeAcceptedPasses);
  T.Test('ContentType: rejected type returns 415', @TestContentTypeRejectedReturns415);
  T.Test('ContentType: ignores charset parameters', @TestContentTypeIgnoresParams);
  T.Test('ContentType: GET request skips check', @TestContentTypeGetSkipsCheck);
  T.Test('ContentType: empty accepted allows any', @TestContentTypeEmptyAllowsAny);
  T.Test('ContentType: missing content-type passes', @TestContentTypeMissingPasses);
  { RequestId }
  T.Test('RequestId: generates UUID id', @TestRequestIdGeneratesId);
  T.Test('RequestId: preserves existing id', @TestRequestIdPreservesExisting);
  T.Test('RequestId: custom header name', @TestRequestIdCustomHeader);
  T.Test('RequestId: unique per request', @TestRequestIdUniquePerRequest);
  if not T.Run then Halt(1);
end.
