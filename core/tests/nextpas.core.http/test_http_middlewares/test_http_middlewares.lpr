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
      raise Exception.Create('boom');
    end),
    [RecoveryMiddleware]
  );
  LReq := TMockRequest.Create(hmGet, '/crash');
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReq, LW);
  CheckEqual(Int64(500), Int64(LWObj.Status), 'recovery returns 500');
  Check(Pos('boom', LWObj.Body) > 0, 'body contains error message');
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

procedure TestRecoveryPreservesBody;
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
  Check(Pos('detailed error info', LWObj.Body) > 0, 'error body has details');
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
  LReq.GetHeaders.Set_('Origin', 'http://example.com');
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
  LReq.GetHeaders.Set_('Origin', 'http://example.com');
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
  LReq.GetHeaders.Set_('Origin', 'http://example.com');
  LReqIntf := LReq;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReqIntf, LW);
  CheckEqual('true', LWObj.GetHeaders.Get('Access-Control-Allow-Credentials'), 'credentials header');
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
    [TimeoutMiddleware(TDuration.FromSeconds(5))]
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
    [TimeoutMiddleware(TDuration.FromMilliseconds(10))]
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
    [TimeoutMiddleware(TDuration.FromSeconds(1))]
  );
  LReq := TMockRequest.Create(hmGet, '/check');
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReq, LW);
  LVal := LWObj.GetHeaders.Get('X-Response-Time');
  Check(Pos('ms', LVal) > 0, 'X-Response-Time contains ms suffix');
end;

var
  T: TTestRunner;
begin
  T := TTestRunner.Create('nextpas.core.http.middlewares');
  { Recovery }
  T.Run('Recovery: handler raises → 500', @TestRecoveryHandlerRaises);
  T.Run('Recovery: handler succeeds → passthrough', @TestRecoveryHandlerSucceeds);
  T.Run('Recovery: error body preserved', @TestRecoveryPreservesBody);
  { Logger }
  T.Run('Logger: calls next handler', @TestLoggerCallsNext);
  T.Run('Logger: preserves status', @TestLoggerPreservesStatus);
  T.Run('Logger: no crash on 404', @TestLoggerNoCrash);
  { CORS }
  T.Run('CORS: preflight → 204 + headers', @TestCorsPreflight);
  T.Run('CORS: normal GET with Origin', @TestCorsNormalRequest);
  T.Run('CORS: no Origin → no CORS headers', @TestCorsNoOriginHeader);
  T.Run('CORS: AllowCredentials header', @TestCorsCredentials);
  { Timeout }
  T.Run('Timeout: fast handler has X-Response-Time', @TestTimeoutFastHandler);
  T.Run('Timeout: slow handler still works', @TestTimeoutSlowHandler);
  T.Run('Timeout: X-Response-Time has ms suffix', @TestTimeoutResponseTimeValue);
  T.Summary;
end.
