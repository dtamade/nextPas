program test_http_contract;
{**
 * @desc Facade and public contract tests.
 *       Proves the public HTTP surface can be consumed through exported contracts.
 *}

{$I nextpas.core.settings.inc}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  nextpas.core.base,
  nextpas.core.errors,
  nextpas.core.testing,
  nextpas.core.io.intf,
  nextpas.core.net,
  nextpas.core.net.intf,
  nextpas.core.http,
  nextpas.core.http.base,
  nextpas.core.http.middleware,
  nextpas.core.http.server,
  nextpas.core.http.client,
  nextpas.core.platform.thread;

var
  T: TTestRunner;
  GProcHandlerCalled: Boolean;
  GProcHandlerPath: string;

type
  PServerCtx = ^TServerCtx;
  TServerCtx = record
    Server: THttpServer;
    Addr: string;
    Port: UInt16;
  end;

  TMockHttpTransport = class(TInterfacedObject, IHttpTransport)
  private
    FRoundTripCalled: Boolean;
    FSeenMethod: THttpMethod;
    FSeenPath: string;
  public
    function RoundTrip(const AReq: IHttpRequest): IHttpResponse;
    property RoundTripCalled: Boolean read FRoundTripCalled;
    property SeenMethod: THttpMethod read FSeenMethod;
    property SeenPath: string read FSeenPath;
  end;

  TMockServerTransport = class(TInterfacedObject, IHttpServerTransport)
  private
    FServeConnCalled: Boolean;
  public
    function ServeConn(const AConn: ITcpStream;
      const AHandler: IHttpHandler): TTcpServerConnOwnership;
    property ServeConnCalled: Boolean read FServeConnCalled;
  end;

  TMockServerSession = class(TInterfacedObject, ITcpServerSession)
  private
    FRunCalled: PBoolean;
    FHandlerCalled: PBoolean;
  public
    constructor Create(const ARunCalled, AHandlerCalled: PBoolean);
    function Run: TTcpServerConnOwnership;
  end;

  TMockSessionServerTransport = class(TInterfacedObject, IHttpServerTransport,
    IHttpServerSessionFactory)
  private
    FServeConnCalled: Boolean;
    FSessionFactoryCalled: Boolean;
    FSessionRunCalled: Boolean;
    FHandlerCalled: Boolean;
  public
    function ServeConn(const AConn: ITcpStream;
      const AHandler: IHttpHandler): TTcpServerConnOwnership;
    function NewSession(const AConn: ITcpStream;
      const AHandler: IHttpHandler): ITcpServerSession;
    property ServeConnCalled: Boolean read FServeConnCalled;
    property SessionFactoryCalled: Boolean read FSessionFactoryCalled;
    property SessionRunCalled: Boolean read FSessionRunCalled;
    property HandlerCalled: Boolean read FHandlerCalled;
  end;

  TMockContextSessionServerTransport = class(TInterfacedObject, IHttpServerTransport,
    IHttpServerSessionFactoryWithContext)
  private
    FServeConnCalled: Boolean;
    FContextSessionFactoryCalled: Boolean;
    FWorkerHandoffSeen: Boolean;
    FSessionRunCalled: Boolean;
    FHandlerCalled: Boolean;
  public
    function ServeConn(const AConn: ITcpStream;
      const AHandler: IHttpHandler): TTcpServerConnOwnership;
    function NewSession(const AConn: ITcpStream; const AHandler: IHttpHandler;
      const AContext: ITcpServerSessionContext): ITcpServerSession;
    property ServeConnCalled: Boolean read FServeConnCalled;
    property ContextSessionFactoryCalled: Boolean read FContextSessionFactoryCalled;
    property WorkerHandoffSeen: Boolean read FWorkerHandoffSeen;
    property SessionRunCalled: Boolean read FSessionRunCalled;
    property HandlerCalled: Boolean read FHandlerCalled;
  end;

  TMethodHandlerTarget = class
  private
    FCalled: Boolean;
    FSeenPath: string;
  public
    procedure Handle(const AReq: IHttpRequest; const AW: IHttpResponseWriter);
    property Called: Boolean read FCalled;
    property SeenPath: string read FSeenPath;
  end;

function ServerThreadFunc(AArg: Pointer): Pointer; cdecl;
var
  LCtx: PServerCtx;
begin
  Result := nil;
  LCtx := PServerCtx(AArg);
  try
    LCtx^.Server.ListenAndServe(LCtx^.Addr, LCtx^.Port);
  except
  end;
  Dispose(LCtx);
end;

function StartServerWithTransport(const AHandler: IHttpHandler;
  const ATransport: IHttpServerTransport; out AServer: THttpServer;
  out APort: UInt16): TPlatformThreadHandle;
var
  LCtx: PServerCtx;
  LHandle: TPlatformThreadHandle;
  LWait: Int32;
begin
  AServer := THttpServer.Create(AHandler, ATransport, THttpServerOptions.Default);
  New(LCtx);
  LCtx^.Server := AServer;
  LCtx^.Addr := '127.0.0.1';
  LCtx^.Port := 0;
  platform_thread_create(LHandle, @ServerThreadFunc, LCtx);
  LWait := 0;
  while (not AServer.IsRunning) and (LWait < 200) do
  begin
    platform_thread_sleep_ns(5000000);
    Inc(LWait);
  end;
  APort := AServer.LocalAddr.Port;
  Result := LHandle;
end;

procedure StopServer(var AServer: THttpServer; const AHandle: TPlatformThreadHandle);
var
  LRet: Pointer;
begin
  AServer.Shutdown;
  platform_thread_join(AHandle, LRet);
  AServer.Free;
  AServer := nil;
end;

procedure PlainHandlerProc(const AReq: IHttpRequest; const AW: IHttpResponseWriter);
begin
  GProcHandlerCalled := True;
  if AReq <> nil then
    GProcHandlerPath := AReq.Url.Path;
end;

{ TMockHttpTransport }

function TMockHttpTransport.RoundTrip(const AReq: IHttpRequest): IHttpResponse;
var
  LHeaders: IHttpHeaders;
begin
  FRoundTripCalled := True;
  FSeenMethod := AReq.Method;
  FSeenPath := AReq.Url.Path;
  LHeaders := NewHeaders;
  LHeaders.Set_('x-transport', 'mock');
  Result := NewResponse(HTTP_STATUS_CREATED, LHeaders, nil);
end;

{ TMockServerTransport }

function TMockServerTransport.ServeConn(const AConn: ITcpStream;
  const AHandler: IHttpHandler): TTcpServerConnOwnership;
begin
  FServeConnCalled := True;
  if AHandler <> nil then
    AHandler.ServeHTTP(NewRequest(hmGet, TUrl.Parse('/transport')), nil);
  Result := TCP_SERVER_CONN_OWNERSHIP_SERVER;
end;

constructor TMockServerSession.Create(const ARunCalled, AHandlerCalled: PBoolean);
begin
  inherited Create;
  FRunCalled := ARunCalled;
  FHandlerCalled := AHandlerCalled;
end;

function TMockServerSession.Run: TTcpServerConnOwnership;
begin
  FRunCalled^ := True;
  FHandlerCalled^ := True;
  Result := TCP_SERVER_CONN_OWNERSHIP_SERVER;
end;

function TMockSessionServerTransport.ServeConn(const AConn: ITcpStream;
  const AHandler: IHttpHandler): TTcpServerConnOwnership;
begin
  FServeConnCalled := True;
  Result := TCP_SERVER_CONN_OWNERSHIP_SERVER;
end;

function TMockSessionServerTransport.NewSession(const AConn: ITcpStream;
  const AHandler: IHttpHandler): ITcpServerSession;
begin
  FSessionFactoryCalled := True;
  Result := TMockServerSession.Create(@FSessionRunCalled, @FHandlerCalled);
end;

function TMockContextSessionServerTransport.ServeConn(const AConn: ITcpStream;
  const AHandler: IHttpHandler): TTcpServerConnOwnership;
begin
  FServeConnCalled := True;
  Result := TCP_SERVER_CONN_OWNERSHIP_SERVER;
end;

function TMockContextSessionServerTransport.NewSession(const AConn: ITcpStream;
  const AHandler: IHttpHandler;
  const AContext: ITcpServerSessionContext): ITcpServerSession;
begin
  FContextSessionFactoryCalled := True;
  FWorkerHandoffSeen := (AContext <> nil) and (AContext.WorkerHandoff <> nil);
  Result := TMockServerSession.Create(@FSessionRunCalled, @FHandlerCalled);
end;

{ TMethodHandlerTarget }

procedure TMethodHandlerTarget.Handle(const AReq: IHttpRequest; const AW: IHttpResponseWriter);
begin
  FCalled := True;
  if AReq <> nil then
    FSeenPath := AReq.Url.Path;
end;

{ Test 1: NewHeaders — Set/Get/Has/Del/Count/Clone }
procedure TestNewHeaders;
var
  LH, LClone: IHttpHeaders;
begin
  LH := NewHeaders;
  Check(LH <> nil, 'NewHeaders returns non-nil');
  LH.Set_('x-foo', 'bar');
  CheckEqual('bar', LH.Get('x-foo'), 'Get after Set');
  Check(LH.Has('x-foo'), 'Has returns true');
  Check(not LH.Has('x-missing'), 'Has returns false for missing');
  CheckEqual(Int64(1), Int64(LH.Count), 'Count = 1');
  LH.Set_('x-baz', 'qux');
  CheckEqual(Int64(2), Int64(LH.Count), 'Count = 2');
  LClone := LH.Clone;
  CheckEqual('bar', LClone.Get('x-foo'), 'Clone preserves values');
  LH.Del('x-foo');
  Check(not LH.Has('x-foo'), 'Del removes header');
  CheckEqual(Int64(1), Int64(LH.Count), 'Count after Del');
  { Clone is independent }
  CheckEqual('bar', LClone.Get('x-foo'), 'Clone independent after Del');
end;

{ Test 2: NewRouter — Get route + FindRoute }
procedure TestNewRouter;
var
  LRouter: IHttpRouter;
  LCalled: Boolean;
begin
  LCalled := False;
  LRouter := NewRouter;
  Check(LRouter <> nil, 'NewRouter returns non-nil');
  LRouter.Handle(hmGet, '/test', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    LCalled := True;
  end);
  { Verify via ServeHTTP with a mock request }
  LRouter.ServeHTTP(NewRequest(hmGet, TUrl.Parse('/test')), nil);
  Check(LCalled, 'Router dispatches handler');
end;

{ Test 3: IHttpRouter convenience methods are callable through interface }
procedure TestRouterConvenienceMethodsOnInterface;
var
  LRouter: IHttpRouter;
  LHit: string;
begin
  LRouter := NewRouter;
  Check(LRouter <> nil, 'NewRouter returns non-nil for interface convenience methods');

  LRouter.Get('/iface-get', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    LHit := 'get';
  end);
  LRouter.Post('/iface-post', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    LHit := 'post';
  end);
  LRouter.Put('/iface-put', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    LHit := 'put';
  end);
  LRouter.Delete('/iface-delete', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    LHit := 'delete';
  end);
  LRouter.Head('/iface-head', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    LHit := 'head';
  end);
  LRouter.Patch('/iface-patch', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    LHit := 'patch';
  end);
  LRouter.Options('/iface-options', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    LHit := 'options';
  end);

  LHit := '';
  LRouter.ServeHTTP(NewRequest(hmGet, TUrl.Parse('/iface-get')), nil);
  CheckEqual('get', LHit, 'IHttpRouter.Get registers GET route');

  LHit := '';
  LRouter.ServeHTTP(NewRequest(hmPost, TUrl.Parse('/iface-post')), nil);
  CheckEqual('post', LHit, 'IHttpRouter.Post registers POST route');

  LHit := '';
  LRouter.ServeHTTP(NewRequest(hmPut, TUrl.Parse('/iface-put')), nil);
  CheckEqual('put', LHit, 'IHttpRouter.Put registers PUT route');

  LHit := '';
  LRouter.ServeHTTP(NewRequest(hmDelete, TUrl.Parse('/iface-delete')), nil);
  CheckEqual('delete', LHit, 'IHttpRouter.Delete registers DELETE route');

  LHit := '';
  LRouter.ServeHTTP(NewRequest(hmHead, TUrl.Parse('/iface-head')), nil);
  CheckEqual('head', LHit, 'IHttpRouter.Head registers HEAD route');

  LHit := '';
  LRouter.ServeHTTP(NewRequest(hmPatch, TUrl.Parse('/iface-patch')), nil);
  CheckEqual('patch', LHit, 'IHttpRouter.Patch registers PATCH route');

  LHit := '';
  LRouter.ServeHTTP(NewRequest(hmOptions, TUrl.Parse('/iface-options')), nil);
  CheckEqual('options', LHit, 'IHttpRouter.Options registers OPTIONS route');
end;

{ Test 4: NewRequest — Method/Url/Version accessible }
procedure TestNewRequest;
var
  LReq: IHttpRequest;
  LUrl: TUrl;
begin
  LUrl := TUrl.Parse('http://example.com/path?q=1');
  LReq := NewRequest(hmPost, LUrl);
  Check(LReq <> nil, 'NewRequest returns non-nil');
  Check(LReq.Method = hmPost, 'Method = POST');
  CheckEqual('/path', LReq.Url.Path, 'Url.Path');
  CheckEqual('q=1', LReq.Url.RawQuery, 'Url.RawQuery');
  Check(LReq.Version = hvHttp11, 'Version = HTTP/1.1');
end;

{ Test 4: NewResponse — StatusCode/Headers accessible }
procedure TestNewResponse;
var
  LResp: IHttpResponse;
  LH: IHttpHeaders;
begin
  LH := NewHeaders;
  LH.Set_('x-test', 'val');
  LResp := NewResponse(HTTP_STATUS_CREATED, LH, nil);
  Check(LResp <> nil, 'NewResponse returns non-nil');
  CheckEqual(Int64(201), Int64(LResp.StatusCode), 'StatusCode = 201');
  CheckEqual('val', LResp.Headers.Get('x-test'), 'Headers accessible');
  Check(LResp.Body = nil, 'Body is nil');
end;

{ Test 5: HandlerFunc wraps correctly }
procedure TestHandlerFuncWrap;
var
  LHandler: IHttpHandler;
  LCalled: Boolean;
begin
  LCalled := False;
  LHandler := HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    LCalled := True;
  end);
  Check(LHandler <> nil, 'HandlerFunc returns non-nil');
  LHandler.ServeHTTP(nil, nil);
  Check(LCalled, 'HandlerFunc handler was called');
end;

{ Test 6: HandlerFunc wraps plain procedures through facade }
procedure TestHandlerProcWrap;
var
  LHandler: IHttpHandler;
begin
  GProcHandlerCalled := False;
  GProcHandlerPath := '';
  LHandler := nextpas.core.http.HandlerFunc(@PlainHandlerProc);
  Check(LHandler <> nil, 'Facade HandlerFunc(proc) returns non-nil');
  LHandler.ServeHTTP(NewRequest(hmGet, TUrl.Parse('/proc')), nil);
  Check(GProcHandlerCalled, 'Facade HandlerFunc(proc) dispatches');
  CheckEqual('/proc', GProcHandlerPath, 'Facade HandlerFunc(proc) keeps request');
end;

{ Test 7: HandlerFunc wraps object methods through facade }
procedure TestHandlerMethodWrap;
var
  LTarget: TMethodHandlerTarget;
  LHandler: IHttpHandler;
begin
  LTarget := TMethodHandlerTarget.Create;
  try
    LHandler := nextpas.core.http.HandlerFunc(@LTarget.Handle);
    Check(LHandler <> nil, 'Facade HandlerFunc(method) returns non-nil');
    LHandler.ServeHTTP(NewRequest(hmGet, TUrl.Parse('/method')), nil);
    Check(LTarget.Called, 'Facade HandlerFunc(method) dispatches');
    CheckEqual('/method', LTarget.SeenPath, 'Facade HandlerFunc(method) keeps request');
  finally
    LTarget.Free;
  end;
end;

{ Test 8: Chain applies middleware }
procedure TestChainMiddleware;
var
  LHandler: IHttpHandler;
  LOrder: string;
  LMw: IHttpMiddleware;
begin
  LOrder := '';
  LHandler := HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    LOrder := LOrder + 'H';
  end);
  LMw := nextpas.core.http.middleware.MiddlewareFunc(function(const ANext: IHttpHandler): IHttpHandler
  begin
    Result := HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      LOrder := LOrder + 'M';
      ANext.ServeHTTP(AReq, AW);
    end);
  end);
  LHandler := Chain(LHandler, [LMw]);
  LHandler.ServeHTTP(nil, nil);
  CheckEqual('MH', LOrder, 'Chain: middleware then handler');
end;

{ Test 9: Facade exposes server overloads }
procedure TestHttpServerFacadeOverloads;
var
  LHandler: IHttpHandler;
  LServer: IHttpServer;
  LOptions: THttpServerOptions;
  LTransportObj: TMockServerTransport;
  LTransport: IHttpServerTransport;
begin
  LHandler := nextpas.core.http.HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
  end);

  LServer := nextpas.core.http.NewHttpServer(LHandler);
  Check(LServer <> nil, 'Facade NewHttpServer(handler) returns non-nil');

  LOptions := THttpServerOptions.Default;
  LOptions.MaxHeaderSize := 4096;
  LServer := nextpas.core.http.NewHttpServer(LHandler, LOptions);
  Check(LServer <> nil, 'Facade NewHttpServer(handler, options) returns non-nil');

  LTransportObj := TMockServerTransport.Create;
  LTransport := LTransportObj;
  LServer := nextpas.core.http.NewHttpServer(LHandler, LTransport);
  Check(LServer <> nil, 'Facade NewHttpServer(handler, transport) returns non-nil');

  LServer := nextpas.core.http.NewHttpServer(LHandler, LTransport, LOptions);
  Check(LServer <> nil, 'Facade NewHttpServer(handler, transport, options) returns non-nil');
end;

{ Test 10: Facade exposes client overloads }
procedure TestHttpClientFacadeOverloads;
var
  LClient: IHttpClient;
  LOptions: THttpClientOptions;
  LTransportObj: TMockHttpTransport;
  LTransport: IHttpTransport;
begin
  LClient := nextpas.core.http.NewHttpClient;
  Check(LClient <> nil, 'Facade NewHttpClient returns non-nil');

  LOptions := THttpClientOptions.Default;
  LOptions.Timeout := 1234;
  LClient := nextpas.core.http.NewHttpClient(LOptions);
  Check(LClient <> nil, 'Facade NewHttpClient(options) returns non-nil');

  LTransportObj := TMockHttpTransport.Create;
  LTransport := LTransportObj;
  LClient := nextpas.core.http.NewHttpClient(LTransport);
  Check(LClient <> nil, 'Facade NewHttpClient(transport) returns non-nil');

  LClient := nextpas.core.http.NewHttpClient(LTransport, LOptions);
  Check(LClient <> nil, 'Facade NewHttpClient(transport, options) returns non-nil');
end;

{ Test 11: Facade client injection delegates round-trip to transport }
procedure TestHttpClientTransportInjection;
var
  LObj: TMockHttpTransport;
  LTransport: IHttpTransport;
  LClient: IHttpClient;
  LResp: IHttpResponse;
begin
  LObj := TMockHttpTransport.Create;
  LTransport := LObj;
  LClient := nextpas.core.http.NewHttpClient(LTransport);
  LResp := LClient.Get('http://example.com/injected?x=1');
  Check(LObj.RoundTripCalled, 'Injected client transport was called');
  Check(LObj.SeenMethod = hmGet, 'Injected client transport sees GET');
  CheckEqual('/injected', LObj.SeenPath, 'Injected client transport sees parsed path');
  CheckEqual(Int64(201), Int64(LResp.StatusCode), 'Injected client transport response returned');
end;

{ Test 12: Facade server injection delegates accepted connections to transport }
procedure TestHttpServerTransportInjection;
var
  LObj: TMockServerTransport;
  LTransport: IHttpServerTransport;
  LHandler: IHttpHandler;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LConn: ITcpStream;
  LHandlerCalled: Boolean;
  LWait: Int32;
begin
  LObj := TMockServerTransport.Create;
  LTransport := LObj;
  LHandlerCalled := False;
  LHandler := HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    LHandlerCalled := True;
    Check(AReq.Method = hmGet, 'Injected server transport sees handler');
    CheckEqual('/transport', AReq.Url.Path, 'Injected server transport passes handler request');
  end);

  LHandle := StartServerWithTransport(LHandler, LTransport, LServer, LPort);
  try
    LConn := TcpConnect('127.0.0.1', LPort);
    LConn.Close;

    LWait := 0;
    while (not LObj.ServeConnCalled) and (LWait < 200) do
    begin
      platform_thread_sleep_ns(5000000);
      Inc(LWait);
    end;

    Check(LObj.ServeConnCalled, 'Injected server transport was called');
    Check(LHandlerCalled, 'Injected server transport can dispatch handler');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestHttpServerTransportInjectionPrefersSessionFactory;
var
  LObj: TMockSessionServerTransport;
  LTransport: IHttpServerTransport;
  LHandler: IHttpHandler;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LConn: ITcpStream;
  LWait: Int32;
begin
  LObj := TMockSessionServerTransport.Create;
  LTransport := LObj;
  LHandler := HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
  end);

  LHandle := StartServerWithTransport(LHandler, LTransport, LServer, LPort);
  try
    LConn := TcpConnect('127.0.0.1', LPort);
    LConn.Close;

    LWait := 0;
    while (not LObj.SessionRunCalled) and (LWait < 200) do
    begin
      platform_thread_sleep_ns(5000000);
      Inc(LWait);
    end;

    Check(LObj.SessionFactoryCalled,
      'Injected server transport session factory was called');
    Check(LObj.SessionRunCalled,
      'Injected server transport session was run');
    Check(not LObj.ServeConnCalled,
      'legacy ServeConn is bypassed when session factory is available');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestHttpServerTransportInjectionPrefersContextSessionFactory;
var
  LObj: TMockContextSessionServerTransport;
  LTransport: IHttpServerTransport;
  LHandler: IHttpHandler;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LConn: ITcpStream;
  LWait: Int32;
begin
  LObj := TMockContextSessionServerTransport.Create;
  LTransport := LObj;
  LHandler := HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
  end);

  LHandle := StartServerWithTransport(LHandler, LTransport, LServer, LPort);
  try
    LConn := TcpConnect('127.0.0.1', LPort);
    LConn.Close;

    LWait := 0;
    while (not LObj.SessionRunCalled) and (LWait < 200) do
    begin
      platform_thread_sleep_ns(5000000);
      Inc(LWait);
    end;

    Check(LObj.ContextSessionFactoryCalled,
      'Injected server transport context session factory was called');
    Check(LObj.WorkerHandoffSeen,
      'Injected server transport context session factory sees worker handoff');
    Check(LObj.SessionRunCalled,
      'Injected server transport context session was run');
    Check(not LObj.ServeConnCalled,
      'legacy ServeConn is bypassed when context session factory is available');
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Test 13: UrlEncode/UrlDecode round-trip }
procedure TestUrlEncodeDecodeRoundTrip;
var
  LOriginal, LEncoded, LDecoded: string;
begin
  LOriginal := 'hello world&foo=bar/baz';
  LEncoded := UrlEncode(LOriginal);
  Check(Pos(' ', LEncoded) = 0, 'Encoded has no spaces');
  Check(Pos('&', LEncoded) = 0, 'Encoded has no &');
  LDecoded := UrlDecode(LEncoded);
  CheckEqual(LOriginal, LDecoded, 'Round-trip preserves value');
end;

{ Test 14: ParseQueryString basic }
procedure TestParseQueryString;
var
  LParams: TQueryParams;
begin
  LParams := ParseQueryString('a=1&b=hello&c=');
  Check(Length(LParams) = 3, 'ParseQueryString: 3 params');
  CheckEqual('a', LParams[0].Name, 'param 0 name');
  CheckEqual('1', LParams[0].Value, 'param 0 value');
  CheckEqual('b', LParams[1].Name, 'param 1 name');
  CheckEqual('hello', LParams[1].Value, 'param 1 value');
  CheckEqual('c', LParams[2].Name, 'param 2 name');
  CheckEqual('', LParams[2].Value, 'param 2 value empty');
end;

{ Test 15: EncodeQueryString round-trip }
procedure TestEncodeQueryStringRoundTrip;
var
  LParams, LParsed: TQueryParams;
  LEncoded: string;
begin
  SetLength(LParams, 2);
  LParams[0].Name := 'key';
  LParams[0].Value := 'val ue';
  LParams[1].Name := 'x';
  LParams[1].Value := 'y&z';
  LEncoded := EncodeQueryString(LParams);
  LParsed := ParseQueryString(LEncoded);
  Check(Length(LParsed) = 2, 'round-trip: 2 params');
  CheckEqual('key', LParsed[0].Name, 'round-trip: name 0');
  CheckEqual('val ue', LParsed[0].Value, 'round-trip: value 0');
  CheckEqual('x', LParsed[1].Name, 'round-trip: name 1');
  CheckEqual('y&z', LParsed[1].Value, 'round-trip: value 1');
end;

{ Test 16: HttpMethodToStr all methods }
procedure TestHttpMethodToStr;
begin
  CheckEqual('GET', HttpMethodToStr(hmGet), 'GET');
  CheckEqual('HEAD', HttpMethodToStr(hmHead), 'HEAD');
  CheckEqual('POST', HttpMethodToStr(hmPost), 'POST');
  CheckEqual('PUT', HttpMethodToStr(hmPut), 'PUT');
  CheckEqual('DELETE', HttpMethodToStr(hmDelete), 'DELETE');
  CheckEqual('PATCH', HttpMethodToStr(hmPatch), 'PATCH');
  CheckEqual('OPTIONS', HttpMethodToStr(hmOptions), 'OPTIONS');
  CheckEqual('CONNECT', HttpMethodToStr(hmConnect), 'CONNECT');
  CheckEqual('TRACE', HttpMethodToStr(hmTrace), 'TRACE');
end;

{ Test 17: HttpStrToMethod all methods }
procedure TestHttpStrToMethod;
begin
  Check(HttpStrToMethod('GET') = hmGet, 'GET');
  Check(HttpStrToMethod('HEAD') = hmHead, 'HEAD');
  Check(HttpStrToMethod('POST') = hmPost, 'POST');
  Check(HttpStrToMethod('PUT') = hmPut, 'PUT');
  Check(HttpStrToMethod('DELETE') = hmDelete, 'DELETE');
  Check(HttpStrToMethod('PATCH') = hmPatch, 'PATCH');
  Check(HttpStrToMethod('OPTIONS') = hmOptions, 'OPTIONS');
  Check(HttpStrToMethod('CONNECT') = hmConnect, 'CONNECT');
  Check(HttpStrToMethod('TRACE') = hmTrace, 'TRACE');
end;

{ Test 18: HttpStatusText known codes }
procedure TestHttpStatusText;
begin
  CheckEqual('Continue', HttpStatusText(HTTP_STATUS_CONTINUE), '100');
  CheckEqual('Switching Protocols',
    nextpas.core.http.HttpStatusText(
      nextpas.core.http.HTTP_STATUS_SWITCHING_PROTOCOLS), '101 facade');
  CheckEqual('OK', HttpStatusText(HTTP_STATUS_OK), '200');
  CheckEqual('Created', HttpStatusText(HTTP_STATUS_CREATED), '201');
  CheckEqual('Not Found', HttpStatusText(HTTP_STATUS_NOT_FOUND), '404');
  CheckEqual('Internal Server Error', HttpStatusText(HTTP_STATUS_INTERNAL_SERVER_ERROR), '500');
  CheckEqual('Not Implemented', HttpStatusText(HTTP_STATUS_NOT_IMPLEMENTED), '501');
  CheckEqual('Method Not Allowed', HttpStatusText(HTTP_STATUS_METHOD_NOT_ALLOWED), '405');
  CheckEqual('Bad Request', HttpStatusText(HTTP_STATUS_BAD_REQUEST), '400');
end;

{ Test 19: IHttpTransport public contract shape }
procedure TestHttpTransportRoundTripContract;
var
  LObj: TMockHttpTransport;
  LTransport: IHttpTransport;
  LReq: IHttpRequest;
  LResp: IHttpResponse;
begin
  LObj := TMockHttpTransport.Create;
  LTransport := LObj;
  LReq := NewRequest(hmPost, TUrl.Parse('/transport?x=1'));
  LResp := LTransport.RoundTrip(LReq);
  Check(LObj.RoundTripCalled, 'RoundTrip was called');
  Check(LObj.SeenMethod = hmPost, 'RoundTrip receives request method');
  CheckEqual('/transport', LObj.SeenPath, 'RoundTrip receives request path');
  CheckEqual(Int64(201), Int64(LResp.StatusCode), 'RoundTrip returns response');
  CheckEqual('mock', LResp.Headers.Get('x-transport'), 'RoundTrip response headers');
end;

{ Test 20: IHttpServerTransport public contract shape }
procedure TestHttpServerTransportServeConnContract;
var
  LObj: TMockServerTransport;
  LTransport: IHttpServerTransport;
  LHandler: IHttpHandler;
  LHandlerCalled: Boolean;
  LOwnership: TTcpServerConnOwnership;
begin
  LObj := TMockServerTransport.Create;
  LTransport := LObj;
  LHandlerCalled := False;
  LHandler := HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    LHandlerCalled := True;
    Check(AReq.Method = hmGet, 'ServeConn passes request method');
    CheckEqual('/transport', AReq.Url.Path, 'ServeConn passes request path');
  end);
  LOwnership := LTransport.ServeConn(nil, LHandler);
  Check(LObj.ServeConnCalled, 'ServeConn was called');
  Check(LHandlerCalled, 'ServeConn can dispatch handler');
  Check(LOwnership = TCP_SERVER_CONN_OWNERSHIP_SERVER,
    'ServeConn returns server ownership when handler does not detach');
end;

{ Test 21: IHttpHijacker is exported by facade }
procedure TestHttpHijackerFacadeAlias;
var
  LHijacker: IHttpHijacker;
begin
  LHijacker := nil;
  Check(LHijacker = nil, 'IHttpHijacker type is available through facade');
end;

procedure TestHttpServerRejectsNilHandler;
var
  LOptions: THttpServerOptions;
  LRaised: Boolean;
  LHandler: IHttpHandler;
  LServer: IHttpServer;
begin
  LOptions := THttpServerOptions.Default;
  LHandler := nil;

  LRaised := False;
  try
    THttpServer.Create(LHandler, LOptions).Free;
  except
    on E: EArgumentError do
      LRaised := True;
  end;
  Check(LRaised, 'THttpServer.Create rejects nil handler');

  LRaised := False;
  try
    LServer := NewHttpServer(LHandler);
    LServer := nil;
  except
    on E: EArgumentError do
      LRaised := True;
  end;
  Check(LRaised, 'NewHttpServer rejects nil handler');
end;

procedure TestHttpServerLifecycleContractOnInterface;
var
  LHandler: IHttpHandler;
  LServer: IHttpServer;
  LAddr: TNetAddress;
begin
  LHandler := HandlerFunc(procedure(const AReq: IHttpRequest;
    const AW: IHttpResponseWriter)
  begin
  end);

  LServer := NewHttpServer(LHandler);
  Check(LServer <> nil, 'NewHttpServer returns IHttpServer contract');
  Check(not LServer.IsRunning, 'IHttpServer reports not running before listen');

  LAddr := LServer.LocalAddr;
  CheckEqual('0.0.0.0', LAddr.IP,
    'IHttpServer.LocalAddr uses any-address placeholder before listen');
  CheckEqual(Int64(0), Int64(LAddr.Port),
    'IHttpServer.LocalAddr uses port 0 before listen');

  LServer.Shutdown;
  Check(not LServer.IsRunning,
    'IHttpServer.Shutdown remains safe before listen');
end;

procedure TestHttpServerHonorsExplicitBackendSelection;
var
  LOptions: THttpServerOptions;
  LRaised: Boolean;
  LHandler: IHttpHandler;
  LServer: IHttpServer;
begin
  LHandler := HandlerFunc(procedure(const AReq: IHttpRequest;
    const AW: IHttpResponseWriter)
  begin
  end);
  LOptions := THttpServerOptions.Default;
  {$IFDEF WINDOWS}
  LOptions.Backend := TCP_SERVER_BACKEND_KQUEUE;
  {$ELSE}
  LOptions.Backend := TCP_SERVER_BACKEND_IOCP;
  {$ENDIF}

  LRaised := False;
  try
    THttpServer.Create(LHandler, LOptions).Free;
  except
    on E: ENotSupportedError do
      LRaised := True;
  end;
  Check(LRaised, 'THttpServer.Create forwards explicit backend selection');

  LRaised := False;
  try
    LServer := NewHttpServer(LHandler, LOptions);
    LServer := nil;
  except
    on E: ENotSupportedError do
      LRaised := True;
  end;
  Check(LRaised, 'NewHttpServer(handler, options) forwards explicit backend selection');
end;

begin
  T := TTestRunner.Create('nextpas.core.http.contract');
  T.Run('NewHeaders: Set/Get/Has/Del/Count/Clone', @TestNewHeaders);
  T.Run('NewRouter: Get route + FindRoute', @TestNewRouter);
  T.Run('IHttpRouter convenience methods are callable through interface', @TestRouterConvenienceMethodsOnInterface);
  T.Run('NewRequest: Method/Url/Version', @TestNewRequest);
  T.Run('NewResponse: StatusCode/Headers', @TestNewResponse);
  T.Run('HandlerFunc wraps correctly', @TestHandlerFuncWrap);
  T.Run('HandlerFunc wraps plain procedures through facade', @TestHandlerProcWrap);
  T.Run('HandlerFunc wraps object methods through facade', @TestHandlerMethodWrap);
  T.Run('Chain applies middleware', @TestChainMiddleware);
  T.Run('NewHttpServer overloads are available through facade', @TestHttpServerFacadeOverloads);
  T.Run('NewHttpClient overloads are available through facade', @TestHttpClientFacadeOverloads);
  T.Run('Injected client transport is used through facade client', @TestHttpClientTransportInjection);
  T.Run('Injected server transport is used through facade server', @TestHttpServerTransportInjection);
  T.Run('Injected server transport session factory is preferred',
    @TestHttpServerTransportInjectionPrefersSessionFactory);
  T.Run('Injected server transport context session factory is preferred',
    @TestHttpServerTransportInjectionPrefersContextSessionFactory);
  T.Run('UrlEncode/UrlDecode round-trip', @TestUrlEncodeDecodeRoundTrip);
  T.Run('ParseQueryString basic', @TestParseQueryString);
  T.Run('EncodeQueryString round-trip', @TestEncodeQueryStringRoundTrip);
  T.Run('HttpMethodToStr all methods', @TestHttpMethodToStr);
  T.Run('HttpStrToMethod all methods', @TestHttpStrToMethod);
  T.Run('HttpStatusText known codes', @TestHttpStatusText);
  T.Run('IHttpTransport RoundTrip contract shape', @TestHttpTransportRoundTripContract);
  T.Run('IHttpServerTransport ServeConn contract shape', @TestHttpServerTransportServeConnContract);
  T.Run('IHttpHijacker facade alias', @TestHttpHijackerFacadeAlias);
  T.Run('HttpServer rejects nil handler', @TestHttpServerRejectsNilHandler);
  T.Run('IHttpServer lifecycle contract shape', @TestHttpServerLifecycleContractOnInterface);
  T.Run('HttpServer honors explicit backend selection',
    @TestHttpServerHonorsExplicitBackendSelection);
  T.Summary;
end.
