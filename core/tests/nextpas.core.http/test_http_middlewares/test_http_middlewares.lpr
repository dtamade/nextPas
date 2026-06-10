program test_http_middlewares;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.base,
  nextpas.core.testing,
  nextpas.core.io.intf,
  nextpas.core.http.base,
  nextpas.core.http.intf,
  nextpas.core.http.headers,
  nextpas.core.http.middleware,
  nextpas.core.http.middleware.recovery,
  nextpas.core.http.middleware.logger,
  nextpas.core.http.middleware.cors,
  nextpas.core.http.middleware.timeout,
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
  public
    constructor Create(const AMethod: THttpMethod; const APath: string);
    function GetMethod: THttpMethod;
    function GetUrl: TUrl;
    function GetPath: string;
    function GetRawQuery: string;
    function GetVersion: THttpVersion;
    function GetHeaders: IHttpHeaders;
    function GetBody: IReader;
    function GetContentLength: Int64;
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
begin Result := 0; end;

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

procedure TestRecoveryEmptyMessage;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: IHttpRequest;
begin
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      raise Exception.Create('');
    end),
    [RecoveryMiddleware]
  );
  LReq := TMockRequest.Create(hmGet, '/empty');
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReq, LW);
  CheckEqual(Int64(500), Int64(LWObj.Status), 'recovery returns 500 for empty message');
  CheckEqual('Internal Server Error', LWObj.Body, 'recovery returns generic body for empty msg');
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
  { W3C: credentials + wildcard must echo Origin, never '*' }
  CheckEqual('http://example.com', LWObj.GetHeaders.Get('Access-Control-Allow-Origin'),
    'ACAO echoes request Origin when credentials + wildcard');
  CheckEqual('Origin', LWObj.GetHeaders.Get('Vary'), 'Vary: Origin when echoing Origin');
end;

procedure TestCorsCredentialsWithExplicitWhitelist;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: TMockRequest;
  LReqIntf: IHttpRequest;
  LOpts: TCorsOptions;
begin
  LOpts := TCorsOptions.Default;
  LOpts.AllowOrigins := 'http://foo.com, http://bar.com';
  LOpts.AllowCredentials := True;
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      AW.WriteHeader(HTTP_STATUS_OK);
    end),
    [CorsMiddleware(LOpts)]
  );
  { origin in whitelist -> allowed }
  LReq := TMockRequest.Create(hmGet, '/api');
  LReq.GetHeaders.SetHeader('Origin', 'http://foo.com');
  LReqIntf := LReq;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReqIntf, LW);
  CheckEqual('http://foo.com', LWObj.GetHeaders.Get('Access-Control-Allow-Origin'),
    'whitelisted origin echoed');
  CheckEqual('true', LWObj.GetHeaders.Get('Access-Control-Allow-Credentials'),
    'credentials header set');
  CheckEqual('Origin', LWObj.GetHeaders.Get('Vary'), 'Vary: Origin for explicit whitelist');
end;

procedure TestCorsOriginNotAllowed;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: TMockRequest;
  LReqIntf: IHttpRequest;
  LOpts: TCorsOptions;
begin
  LOpts := TCorsOptions.Default;
  LOpts.AllowOrigins := 'http://foo.com';
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      AW.WriteHeader(HTTP_STATUS_OK);
    end),
    [CorsMiddleware(LOpts)]
  );
  LReq := TMockRequest.Create(hmGet, '/api');
  LReq.GetHeaders.SetHeader('Origin', 'http://evil.com');
  LReqIntf := LReq;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReqIntf, LW);
  CheckEqual('', LWObj.GetHeaders.Get('Access-Control-Allow-Origin'),
    'disallowed origin gets no ACAO');
  Check(not LWObj.GetHeaders.Has('Access-Control-Allow-Credentials'),
    'no credentials header for disallowed origin');
end;

procedure TestCorsCredentialsDisallowOrigin;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: TMockRequest;
  LReqIntf: IHttpRequest;
  LOpts: TCorsOptions;
begin
  LOpts := TCorsOptions.Default;
  LOpts.AllowOrigins := 'http://foo.com';
  LOpts.AllowCredentials := True;
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      AW.WriteHeader(HTTP_STATUS_OK);
    end),
    [CorsMiddleware(LOpts)]
  );
  LReq := TMockRequest.Create(hmGet, '/api');
  LReq.GetHeaders.SetHeader('Origin', 'http://evil.com');
  LReqIntf := LReq;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReqIntf, LW);
  CheckEqual('', LWObj.GetHeaders.Get('Access-Control-Allow-Origin'),
    'disallowed origin + credentials: no CORS headers');
  Check(not LWObj.GetHeaders.Has('Access-Control-Allow-Credentials'),
    'no credentials header for disallowed origin');
end;

procedure TestCorsExplicitOriginNoWildcard;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: TMockRequest;
  LReqIntf: IHttpRequest;
  LOpts: TCorsOptions;
begin
  LOpts := TCorsOptions.Default;
  LOpts.AllowOrigins := 'http://example.com';
  LOpts.AllowCredentials := False;
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
    'non-wildcard echoes specific origin');
  CheckEqual('Origin', LWObj.GetHeaders.Get('Vary'), 'Vary: Origin for non-wildcard');
end;

{ === ResponseTime Tests === }

procedure TestResponseTimeFastHandler;
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
    [ResponseTimeMiddleware]
  );
  LReq := TMockRequest.Create(hmGet, '/fast');
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReq, LW);
  CheckEqual(Int64(200), Int64(LWObj.Status), 'fast handler OK');
  Check(LWObj.GetHeaders.Has('X-Response-Time'), 'has X-Response-Time header');
end;

procedure TestResponseTimeSlowHandler;
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
    [ResponseTimeMiddleware]
  );
  LReq := TMockRequest.Create(hmGet, '/slow');
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReq, LW);
  CheckEqual(Int64(200), Int64(LWObj.Status), 'slow handler still completes');
  LVal := LWObj.GetHeaders.Get('X-Response-Time');
  Check(LVal <> '', 'X-Response-Time present for slow handler');
end;

procedure TestResponseTimeValueFormat;
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
    [ResponseTimeMiddleware]
  );
  LReq := TMockRequest.Create(hmGet, '/check');
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReq, LW);
  LVal := LWObj.GetHeaders.Get('X-Response-Time');
  Check(Pos('ms', LVal) > 0, 'X-Response-Time contains ms suffix');
end;

procedure TestDeprecatedAlias;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: IHttpRequest;
begin
  {$PUSH}{$WARNINGS OFF}
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      AW.WriteHeader(HTTP_STATUS_OK);
    end),
    [TimeoutMiddleware]
  );
  {$POP}
  LReq := TMockRequest.Create(hmGet, '/alias');
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReq, LW);
  CheckEqual(Int64(200), Int64(LWObj.Status), 'deprecated alias still works');
  Check(LWObj.GetHeaders.Has('X-Response-Time'), 'deprecated alias sets X-Response-Time');
end;

var
  T: TTestRunner;
begin
  T := TTestRunner.Create('nextpas.core.http.middlewares');
  { Recovery }
  T.Run('Recovery: handler raises -> 500', @TestRecoveryHandlerRaises);
  T.Run('Recovery: handler succeeds -> passthrough', @TestRecoveryHandlerSucceeds);
  T.Run('Recovery: exception details hidden', @TestRecoveryHidesExceptionDetails);
  T.Run('Recovery: empty message no crash', @TestRecoveryEmptyMessage);
  { Logger }
  T.Run('Logger: calls next handler', @TestLoggerCallsNext);
  T.Run('Logger: preserves status', @TestLoggerPreservesStatus);
  T.Run('Logger: no crash on 404', @TestLoggerNoCrash);
  { CORS }
  T.Run('CORS: preflight -> 204 + headers', @TestCorsPreflight);
  T.Run('CORS: normal GET with Origin', @TestCorsNormalRequest);
  T.Run('CORS: no Origin -> no CORS headers', @TestCorsNoOriginHeader);
  T.Run('CORS: AllowCredentials echoes Origin', @TestCorsCredentials);
  T.Run('CORS: credentials + explicit whitelist', @TestCorsCredentialsWithExplicitWhitelist);
  T.Run('CORS: origin not in whitelist rejected', @TestCorsOriginNotAllowed);
  T.Run('CORS: credentials + disallowed origin', @TestCorsCredentialsDisallowOrigin);
  T.Run('CORS: non-wildcard echoes specific origin', @TestCorsExplicitOriginNoWildcard);
  { ResponseTime }
  T.Run('ResponseTime: fast handler has X-Response-Time', @TestResponseTimeFastHandler);
  T.Run('ResponseTime: slow handler still works', @TestResponseTimeSlowHandler);
  T.Run('ResponseTime: X-Response-Time has ms suffix', @TestResponseTimeValueFormat);
  T.Run('ResponseTime: deprecated TimeoutMiddleware alias', @TestDeprecatedAlias);
  T.Summary;
end.
