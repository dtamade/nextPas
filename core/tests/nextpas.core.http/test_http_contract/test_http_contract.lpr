program test_http_contract;
{**
 * @desc Facade and public contract tests.
 *       Proves the public HTTP surface can be consumed through exported contracts.
 *}

{$I nextpas.core.settings.inc}

uses
  nextpas.core.thread.init,
  nextpas.core.text.conv,
  nextpas.core.base,
  nextpas.core.base.utils,
  nextpas.core.errors,
  nextpas.core.test,
  nextpas.core.io.intf,
  nextpas.core.fs,
  nextpas.core.net,
  nextpas.core.net.intf,
  nextpas.core.http,
  nextpas.core.http.base,
  nextpas.core.http.middleware,
  nextpas.core.http.server,
  nextpas.core.http.client,
  nextpas.core.time.base,
  nextpas.core.time.deadline,
  nextpas.core.platform.thread;

var
  T: TTestSuite;
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

function SendRawRequestAndReadAll(const APort: UInt16;
  const ARequest: string): string;
var
  LConn: ITcpStream;
  LBuf: array[0..8191] of Byte;
  LN: SizeUInt;
begin
  Result := '';
  LConn := TcpConnect('127.0.0.1', APort);
  try
    LConn.SetReadDeadline(TDeadline.After(TDuration.FromSeconds(5)));
    if Length(ARequest) > 0 then
      LConn.Write(ARequest[1], SizeUInt(Length(ARequest)));
    LConn.Shutdown;
    repeat
      try
        LN := LConn.Read(LBuf[0], SizeUInt(Length(LBuf)));
      except
        LN := 0;
      end;
      if LN > 0 then
      begin
        SetLength(Result, Length(Result) + Int32(LN));
        Move(LBuf[0], Result[Length(Result) - Int32(LN) + 1], LN);
      end;
    until LN = 0;
  finally
    LConn.Close;
  end;
end;

function ReadTextFile(const APath: string): string;
{ Prefer fs.ReadFileText so nextpas.core.fs does not shadow System.file/FileSize. }
begin
  Result := ReadFileText(APath);
end;

function SourceHas(const ASource, AText: string): Boolean;
begin
  Result := Pos(AText, ASource) > 0;
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
  LHeaders.SetHeader('x-transport', 'mock');
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
  LH.SetHeader('x-foo', 'bar');
  CheckEqual('bar', LH.Get('x-foo'), 'Get after Set');
  Check(LH.Has('x-foo'), 'Has returns true');
  Check(not LH.Has('x-missing'), 'Has returns false for missing');
  CheckEqual(Int64(1), Int64(LH.Count), 'Count = 1');
  LH.SetHeader('x-baz', 'qux');
  CheckEqual(Int64(2), Int64(LH.Count), 'Count = 2');
  LClone := LH.Clone;
  CheckEqual('bar', LClone.Get('x-foo'), 'Clone preserves values');
  LH.Remove('x-foo');
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
  LRouter.Connect('/iface-connect', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    LHit := 'connect';
  end);
  LRouter.Trace('/iface-trace', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    LHit := 'trace';
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

  LHit := '';
  LRouter.ServeHTTP(NewRequest(hmConnect, TUrl.Parse('/iface-connect')), nil);
  CheckEqual('connect', LHit, 'IHttpRouter.Connect registers CONNECT route');

  LHit := '';
  LRouter.ServeHTTP(NewRequest(hmTrace, TUrl.Parse('/iface-trace')), nil);
  CheckEqual('trace', LHit, 'IHttpRouter.Trace registers TRACE route');
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
  CheckEqual('/path', LReq.Path, 'Path direct accessor');
  CheckEqual('q=1', LReq.RawQuery, 'RawQuery direct accessor');
  Check(LReq.Version = hvHttp11, 'Version = HTTP/1.1');
end;

{ Test 4: NewResponse — StatusCode/Headers accessible }
procedure TestNewResponse;
var
  LResp: IHttpResponse;
  LH: IHttpHeaders;
begin
  LH := NewHeaders;
  LH.SetHeader('x-test', 'val');
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
  CheckEqual('Early Hints',
    nextpas.core.http.HttpStatusText(
      nextpas.core.http.HTTP_STATUS_EARLY_HINTS), '103 facade');
  CheckEqual('OK', HttpStatusText(HTTP_STATUS_OK), '200');
  CheckEqual('Created', HttpStatusText(HTTP_STATUS_CREATED), '201');
  CheckEqual('Payload Too Large',
    nextpas.core.http.HttpStatusText(
      nextpas.core.http.HTTP_STATUS_PAYLOAD_TOO_LARGE), '413 facade');
  CheckEqual('Expectation Failed',
    nextpas.core.http.HttpStatusText(
      nextpas.core.http.HTTP_STATUS_EXPECTATION_FAILED), '417 facade');
  CheckEqual('Not Found', HttpStatusText(HTTP_STATUS_NOT_FOUND), '404');
  CheckEqual('Internal Server Error', HttpStatusText(HTTP_STATUS_INTERNAL_SERVER_ERROR), '500');
  CheckEqual('Not Implemented',
    nextpas.core.http.HttpStatusText(
      nextpas.core.http.HTTP_STATUS_NOT_IMPLEMENTED), '501 facade');
  CheckEqual('Request Header Fields Too Large',
    nextpas.core.http.HttpStatusText(
      nextpas.core.http.HTTP_STATUS_HEADER_TOO_LARGE), '431 facade');
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
    on E: EHttpError do
      LRaised := E.Kind = hekArgument;
  end;
  Check(LRaised, 'THttpServer.Create rejects nil handler as hekArgument');

  LRaised := False;
  try
    LServer := NewHttpServer(LHandler);
    LServer := nil;
  except
    on E: EHttpError do
      LRaised := E.Kind = hekArgument;
  end;
  Check(LRaised, 'NewHttpServer rejects nil handler as hekArgument');
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

procedure TestHttpServerFacadeOwnerBoundarySourceContract;
var
  LSource: string;
begin
  LSource := ReadTextFile('../../../src/nextpas.core.http.server.pas');

  Check(SourceHas(LSource,
    'THttpConnHandler = class(TInterfacedObject, ITcpServerHandler,'#10 +
    '    ITcpServerSessionFactory, ITcpServerSessionFactoryWithContext)'),
    'HTTP connection handler stays a TCP server handler/session bridge');
  Check(SourceHas(LSource,
    'if Supports(Transport, IHttpServerSessionFactoryWithContext, LContextFactory) then'),
    'HTTP server prefers context-aware transport session factory');
  Check(SourceHas(LSource,
    'Result := THttpConnSession.Create(Transport, Handler, AConn);'),
    'HTTP server keeps legacy ServeConn fallback behind a session object');

  Check(SourceHas(LSource, 'LTcpOptions := TTcpServerOptions.Default;'),
    'HTTP server starts from TCP server default options');
  Check(SourceHas(LSource, 'LTcpOptions.Backend := AOptions.Backend;'),
    'HTTP server forwards backend selection to TCP server options');
  Check(SourceHas(LSource, 'FTcpServer := NewTcpServer(LTcpOptions);'),
    'HTTP server creates runtime through the TCP server facade');

  Check(SourceHas(LSource,
    'FTcpServer.ListenAndServe(AAddr, APort, FConnHandler);'),
    'HTTP ListenAndServe delegates listener ownership to TCP server');
  Check(SourceHas(LSource, 'FTcpServer.Shutdown;'),
    'HTTP Shutdown delegates lifecycle ownership to TCP server');
  Check(SourceHas(LSource, 'Result := FTcpServer.LocalAddr'),
    'HTTP LocalAddr delegates address truth to TCP server');
  Check(SourceHas(LSource,
    'Result := (FTcpServer <> nil) and FTcpServer.IsRunning;'),
    'HTTP IsRunning delegates runtime truth to TCP server');
end;

procedure TestHttpMinimalFacadeSourceContract;
{ Thin facade: core types + router/server/client; no product middleware family. }
var
  LMinimal: string;
begin
  LMinimal := ReadTextFile('../../../src/nextpas.core.http.minimal.pas');

  Check(SourceHas(LMinimal, 'unit nextpas.core.http.minimal;'),
    'minimal unit exists');
  Check(SourceHas(LMinimal, 'nextpas.core.http.base,'),
    'minimal uses base');
  Check(SourceHas(LMinimal, 'nextpas.core.http.intf,'),
    'minimal uses intf');
  Check(SourceHas(LMinimal, 'nextpas.core.http.headers,'),
    'minimal uses headers');
  Check(SourceHas(LMinimal, 'nextpas.core.http.url,'),
    'minimal uses url');
  Check(SourceHas(LMinimal, 'nextpas.core.http.router,'),
    'minimal uses router');
  Check(SourceHas(LMinimal, 'nextpas.core.http.middleware,'),
    'minimal uses chain primitives unit middleware');
  Check(SourceHas(LMinimal, 'nextpas.core.http.message,'),
    'minimal uses message');
  Check(SourceHas(LMinimal, 'nextpas.core.http.server,'),
    'minimal uses server');
  Check(SourceHas(LMinimal, 'nextpas.core.http.client;'),
    'minimal uses client');

  Check(not SourceHas(LMinimal, 'nextpas.core.http.middleware.cors'),
    'minimal does not pull middleware.cors');
  Check(not SourceHas(LMinimal, 'nextpas.core.http.middleware.recovery'),
    'minimal does not pull middleware.recovery');
  Check(not SourceHas(LMinimal, 'nextpas.core.http.middleware.logger'),
    'minimal does not pull middleware.logger');
  Check(not SourceHas(LMinimal, 'nextpas.core.http.middleware.compression'),
    'minimal does not pull middleware.compression');
  Check(not SourceHas(LMinimal, 'nextpas.core.http.websocket'),
    'minimal does not pull websocket product surface');
  Check(not SourceHas(LMinimal, 'nextpas.core.http.static'),
    'minimal does not pull static product surface');

  Check(SourceHas(LMinimal, 'function NewHttpServer(const AHandler: IHttpHandler): IHttpServer;'),
    'minimal exports NewHttpServer');
  Check(SourceHas(LMinimal, 'function NewHttpClient: IHttpClient;'),
    'minimal exports NewHttpClient');
  Check(SourceHas(LMinimal, 'function NewRouter: IHttpRouter;'),
    'minimal exports NewRouter');
  Check(SourceHas(LMinimal, 'function HandlerFunc(const AFunc: THttpHandlerFunc): IHttpHandler;'),
    'minimal exports HandlerFunc');
end;

procedure TestNewRequestFacadeDeprecationParitySourceContract;
{ Whitelist only: NewRequest(Method, TUrl|string) + NewGetRequest.
  Multi-arg NewRequest and NewStreamingRequest are physically deleted. }
var
  LFacade: string;
  LMessage: string;
begin
  LFacade := ReadTextFile('../../../src/nextpas.core.http.pas');
  LMessage := ReadTextFile('../../../src/nextpas.core.http.message.pas');

  Check(SourceHas(LMessage,
    'function NewRequest(const AMethod: THttpMethod; const AUrl: TUrl): IHttpRequest; overload;'),
    'message keeps NewRequest(Method, TUrl) as the non-deprecated primitive');
  Check(SourceHas(LMessage,
    'function NewRequest(const AMethod: THttpMethod; const AUrl: string): IHttpRequest; overload;'),
    'message keeps NewRequest(Method, string) URL-parse bridge');
  Check(SourceHas(LFacade,
    'function NewRequest(const AMethod: THttpMethod; const AUrl: TUrl): IHttpRequest; overload; inline;'),
    'facade keeps NewRequest(Method, TUrl) as the non-deprecated primitive');
  Check(SourceHas(LFacade,
    'function NewRequest(const AMethod: THttpMethod; const AUrl: string): IHttpRequest; overload; inline;'),
    'facade keeps NewRequest(Method, string) URL-parse bridge');
  Check(SourceHas(LFacade, 'function NewGetRequest(const APath: string): IHttpRequest; inline;'),
    'facade keeps NewGetRequest non-deprecated');

  { Multi-arg NewRequest overloads removed from both units. }
  Check(not SourceHas(LFacade, 'const ABody: IReader; const AContentLength: Int64): IHttpRequest'),
    'facade has no NewRequest body+CL overload');
  Check(not SourceHas(LFacade, 'const AHeaders: IHttpHeaders; const ABody: IReader;'),
    'facade has no NewRequest headers+body overload');
  Check(not SourceHas(LFacade, 'const ABodyText: string): IHttpRequest'),
    'facade has no NewRequest body-text overload');
  Check(not SourceHas(LFacade, 'const ABodyBytes: TBytes): IHttpRequest'),
    'facade has no NewRequest body-bytes overload');
  Check(not SourceHas(LMessage, 'deprecated ''Use THttpRequestBuilder instead'''),
    'message no longer carries deprecated multi-arg NewRequest markers');

  Check(SourceHas(LFacade, 'THttpRequestBuilder = nextpas.core.http.messages.THttpRequestBuilder;'),
    'facade re-exports THttpRequestBuilder as the recommended construction path');

  { NewStreamingRequest physically deleted — builder / SendStreaming only. }
  Check(not SourceHas(LMessage, 'function NewStreamingRequest'),
    'message no longer declares NewStreamingRequest');
  Check(not SourceHas(LFacade, 'function NewStreamingRequest'),
    'facade no longer declares NewStreamingRequest');

  { Wave K freeze: no deprecated markers on request factories. }
  Check(not SourceHas(LFacade, 'deprecated'),
    'facade has no deprecated markers');
  Check(not SourceHas(LMessage, 'deprecated'),
    'message has no deprecated markers');
end;

procedure TestHttpErrorTaxonomyNoBareArgumentErrorSourceContract;
{ Wave E1: public http surface must not raise bare EArgumentError. }
var
  LPaths: array[0..11] of string;
  LSource: string;
  I: Integer;
begin
  LPaths[0] := '../../../src/nextpas.core.http.pas';
  LPaths[1] := '../../../src/nextpas.core.http.base.pas';
  LPaths[2] := '../../../src/nextpas.core.http.client.pas';
  LPaths[3] := '../../../src/nextpas.core.http.message.pas';
  LPaths[4] := '../../../src/nextpas.core.http.server.pas';
  LPaths[5] := '../../../src/nextpas.core.http.websocket.pas';
  LPaths[6] := '../../../src/nextpas.core.http.static.pas';
  LPaths[7] := '../../../src/nextpas.core.http.sse.pas';
  LPaths[8] := '../../../src/nextpas.core.http.stream.pas';
  LPaths[9] := '../../../src/nextpas.core.http.middleware.decompress.pas';
  LPaths[10] := '../../../src/nextpas.core.http.middleware.compression.pas';
  LPaths[11] := '../../../src/nextpas.core.http.middleware.bodylimit.pas';

  for I := Low(LPaths) to High(LPaths) do
  begin
    LSource := ReadTextFile(LPaths[I]);
    Check(Pos('raise EArgumentError', LSource) = 0,
      LPaths[I] + ' must not raise bare EArgumentError');
    Check(Pos('EArgumentError.Create', LSource) = 0,
      LPaths[I] + ' must not construct bare EArgumentError');
  end;

  LSource := ReadTextFile('../../../src/nextpas.core.http.middlewares.pas');
  Check(SourceHas(LSource,
    'raise EHttpError.Create(hekArgument, ''HttpUseRequestArena: router must not be nil'')'),
    'HttpUseRequestArena nil router uses hekArgument');

  LSource := ReadTextFile(
    '../../../src/nextpas.core.http.middleware.decompress.pas');
  Check(SourceHas(LSource,
    'raise EHttpError.Create(hekArgument, E.Message)'),
    'decompress wraps foreign EArgumentError as hekArgument');
  Check(not SourceHas(LSource, 'on E: EArgumentError do'#10 +
    '          raise;'),
    'decompress must not bare-re-raise EArgumentError');
end;

procedure TestHttpWithStarChainSemanticsSourceContract;
{ Wave E2: decorator vs rebuild classification stays as CONTRACT table. }
var
  LClient: string;
  LDeco: string;
begin
  LClient := ReadTextFile('../../../src/nextpas.core.http.client.pas');
  LDeco := ReadTextFile('../../../src/nextpas.core.http.client.decorator.pas');

  Check(SourceHas(LClient,
    'Result := TOptionsOverrideClient.Create(Self,'#10 +
    '    Default(THttpRequestOptions).WithTimeout(ATimeoutMs));'),
    'WithTimeout is request-options decorator, not options rebuild');
  Check(SourceHas(LClient,
    'Result := NewHttpClient(FOptions.WithConnectTimeout(ATimeoutMs));'),
    'WithConnectTimeout rebuilds base client options/transport');
  Check(SourceHas(LClient,
    'Result := NewHttpClient(FOptions.WithProxyUrl(AProxyUrl));'),
    'WithProxyUrl rebuilds base client');
  Check(SourceHas(LClient,
    'Result := NewHttpClient(FOptions.WithTLSContext(ATLSContext));'),
    'WithTLSContext rebuilds base client');
  Check(SourceHas(LDeco,
    'Result := RebindInner(FInner.WithConnectTimeout(ATimeoutMs));'),
    'decorator rebinds around ConnectTimeout rebuild');
  Check(SourceHas(LDeco,
    'Result := RebindInner(FInner.WithProxyUrl(AProxyUrl));'),
    'decorator rebinds around ProxyUrl rebuild');
  Check(SourceHas(LDeco,
    'Result := RebindInner(FInner.WithTLSContext(ATLSContext));'),
    'decorator rebinds around TLSContext rebuild');
  Check(SourceHas(LClient, 'Result := TRetryClient.Create(Self, AMaxRetries);'),
    'WithRetry remains a decorator');
end;

function SourceMentionsForbiddenFpcRtlUnit(const ASource: string): string;
{ Return first forbidden FPC RTL unit name if it appears as a uses-clause token. }
const
  Forbidden: array[0..10] of string = (
    'SysUtils', 'Classes', 'BaseUnix', 'Unix', 'Linux', 'Windows',
    'Sockets', 'ctypes', 'DynLibs', 'SyncObjs', 'Contnrs');
var
  LI: Integer;
  U: string;
begin
  Result := '';
  for LI := Low(Forbidden) to High(Forbidden) do
  begin
    U := Forbidden[LI];
    if SourceHas(ASource, 'uses ' + U + ',') or
       SourceHas(ASource, 'uses ' + U + ';') or
       SourceHas(ASource, #10'  ' + U + ',') or
       SourceHas(ASource, #13#10'  ' + U + ',') or
       SourceHas(ASource, #10'  ' + U + ';') or
       SourceHas(ASource, #13#10'  ' + U + ';') or
       SourceHas(ASource, ', ' + U + ',') or
       SourceHas(ASource, ',' + U + ',') or
       SourceHas(ASource, ', ' + U + ';') or
       SourceHas(ASource, ',' + U + ';') then
      Exit(U);
  end;
end;

procedure AssertNoForbiddenFpcRtlInFile(const APath: string);
var
  LSource: string;
  LHit: string;
begin
  LSource := ReadTextFile(APath);
  LHit := SourceMentionsForbiddenFpcRtlUnit(LSource);
  Check(LHit = '',
    'HTTP dual-compiler isolation forbids FPC RTL unit ' + LHit + ' in ' + APath);
end;

procedure AssertNoForbiddenFpcRtlInDirFiles(const ADir, ASuffix: string);
var
  LEntries: TDirEntryArray;
  LI: Integer;
  LName: string;
  LPath: string;
begin
  LEntries := ReadDir(ADir);
  for LI := 0 to High(LEntries) do
  begin
    LName := LEntries[LI].Name;
    if (LName = '.') or (LName = '..') then
      Continue;
    LPath := ADir + '/' + LName;
    if LEntries[LI].IsDir then
      AssertNoForbiddenFpcRtlInDirFiles(LPath, ASuffix)
    else if (Length(LName) >= Length(ASuffix)) and
            (Copy(LName, Length(LName) - Length(ASuffix) + 1, Length(ASuffix)) = ASuffix) then
      AssertNoForbiddenFpcRtlInFile(LPath);
  end;
end;

function IsHttpProductionUnitName(const AName: string): Boolean;
{ Match nextpas.core.http.pas and nextpas.core.http.*.pas (prefix length=17). }
const
  Prefix = 'nextpas.core.http';
begin
  if Length(AName) < Length(Prefix) + 4 then
    Exit(False);
  if Copy(AName, 1, Length(Prefix)) <> Prefix then
    Exit(False);
  if Copy(AName, Length(AName) - 3, 4) <> '.pas' then
    Exit(False);
  { nextpas.core.http.pas or nextpas.core.http.<rest>.pas — not nextpas.core.httpX }
  Result := (Length(AName) = Length(Prefix) + 4) or
            (AName[Length(Prefix) + 1] = '.');
end;

procedure TestHttpFpcRtlIsolationSourceContract;
{ Era0 / F-2026-02: only nextpas.core.system may uses FPC RTL; HTTP production
  units and HTTP tests must go through nextpas.core.* abstractions. }
var
  LEntries: TDirEntryArray;
  LI: Integer;
  LName: string;
  LPath: string;
  LCount: Integer;
begin
  LCount := 0;
  LEntries := ReadDir('../../../src');
  for LI := 0 to High(LEntries) do
  begin
    LName := LEntries[LI].Name;
    if LEntries[LI].IsDir then
      Continue;
    if not IsHttpProductionUnitName(LName) then
      Continue;
    LPath := '../../../src/' + LName;
    AssertNoForbiddenFpcRtlInFile(LPath);
    Inc(LCount);
  end;
  Check(LCount >= 60,
    'expected >=60 nextpas.core.http*.pas production units, got ' + IntToStr(LCount));

  AssertNoForbiddenFpcRtlInDirFiles('../../nextpas.core.http', '.lpr');
end;

procedure TestHttpErrorStableOpSetSourceContract;
{ Wave E1 aligns Wave J Op names; lock the stable Op string set. }
var
  LClient: string;
  LHelpers: string;
  LBase: string;
  LH1: string;
  LWs: string;
begin
  LClient := ReadTextFile('../../../src/nextpas.core.http.client.pas');
  LHelpers := ReadTextFile('../../../src/nextpas.core.http.client.helpers.pas');
  LBase := ReadTextFile('../../../src/nextpas.core.http.base.pas');
  { Op=connect owner: H1 client transport (STRUCT residual extract). }
  LH1 := ReadTextFile('../../../src/nextpas.core.http.impl.h1.client.pas');
  LWs := ReadTextFile('../../../src/nextpas.core.http.websocket.pas');

  Check(SourceHas(LClient, '''redirect'''),
    'client uses Op=redirect');
  Check(SourceHas(LClient, '''round_trip'''),
    'client uses Op=round_trip');
  Check(SourceHas(LHelpers, '''ensure'''),
    'client helpers use Op=ensure');
  Check(SourceHas(LHelpers, '''download'''),
    'client helpers use Op=download');
  Check(SourceHas(LHelpers, '''json'''),
    'client helpers use Op=json');
  Check(SourceHas(LHelpers, '''content_encoding'''),
    'client helpers use Op=content_encoding');
  Check(SourceHas(LBase, '''cancel'''),
    'base uses Op=cancel');
  Check(SourceHas(LBase, '''transport'''),
    'base uses Op=transport');
  Check(SourceHas(LH1, '''connect'''),
    'H1 client uses Op=connect');
  Check(SourceHas(LWs, '''websocket'''),
    'websocket uses Op=websocket');

  Check(SourceHas(LBase,
    'hekUnknown,'#10 +
    '    hekArgument,'#10 +
    '    hekTimeout,'#10 +
    '    hekConnect,'#10 +
    '    hekProtocol,'#10 +
    '    hekParse,'#10 +
    '    hekRedirect,'#10 +
    '    hekBody,'#10 +
    '    hekUpgrade,'#10 +
    '    hekRegistry,'#10 +
    '    hekStatus,'#10 +
    '    hekCanceled'),
    'THttpErrorKind order stays the Wave E1 taxonomy set');
end;

procedure TestChunkedRequestTrailerContract;
var
  LRouter: IHttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
  LGotBody: string;
  LGotTrailerDecl: string;
  LGotTrailerValue: string;
const
  REQ =
    'POST /upload HTTP/1.1'#13#10 +
    'Host: localhost'#13#10 +
    'Connection: close'#13#10 +
    'Transfer-Encoding: chunked'#13#10 +
    'Trailer: X-Test'#13#10#13#10 +
    '5'#13#10'hello'#13#10 +
    '0'#13#10 +
    'X-Test: value'#13#10#13#10;
begin
  LGotBody := '';
  LGotTrailerDecl := '';
  LGotTrailerValue := '';
  LRouter := NewRouter;
  LRouter.Post('/upload', procedure(const AReq: IHttpRequest;
    const AW: IHttpResponseWriter)
  var
    LBuf: array[0..15] of Byte;
    LN: SizeUInt;
    LBody: string;
    LRespBody: string;
  begin
    LBody := '';
    if AReq.Body <> nil then
      repeat
        LN := AReq.Body.Read(LBuf[0], SizeUInt(Length(LBuf)));
        if LN > 0 then
        begin
          SetLength(LBody, Length(LBody) + Int32(LN));
          Move(LBuf[0], LBody[Length(LBody) - Int32(LN) + 1], LN);
        end;
      until LN = 0;
    LGotBody := LBody;
    LGotTrailerDecl := AReq.Headers.Get('Trailer');
    LGotTrailerValue := AReq.Headers.Get('X-Test');

    LRespBody := 'ok';
    AW.GetHeaders.SetHeader('content-length', IntToStr(Int64(Length(LRespBody))));
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(LRespBody[1], SizeUInt(Length(LRespBody)));
  end);

  LHandle := StartServerWithTransport(LRouter as IHttpHandler, nil, LServer, LPort);
  try
    LResp := SendRawRequestAndReadAll(LPort, REQ);
    Check(Pos('200 OK', LResp) > 0,
      'Chunked trailer contract returns 200');
    Check(Pos('ok', LResp) > 0,
      'Chunked trailer contract preserves response body');
    CheckEqual('hello', LGotBody,
      'Chunked trailer contract decodes chunked body');
    CheckEqual('X-Test', LGotTrailerDecl,
      'Chunked trailer contract preserves declaration header');
    CheckEqual('', LGotTrailerValue,
      'Chunked trailer contract hides trailer field from ordinary headers');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestChunkedRequestMultipleTrailerDeclarationContract;
var
  LRouter: IHttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
  LGotBody: string;
  LGotTrailerDecl: string;
  LGotTrailerDeclValues: TStringArray;
  LGotTraceValue: string;
  LGotAuthValue: string;
  LGotTraceValues: TStringArray;
  LGotAuthValues: TStringArray;
  LHasTrace: Boolean;
  LHasAuth: Boolean;
const
  REQ =
    'POST /upload HTTP/1.1'#13#10 +
    'Host: localhost'#13#10 +
    'Connection: close'#13#10 +
    'Transfer-Encoding: chunked'#13#10 +
    'Trailer: X-Trace, X-Auth-Context'#13#10#13#10 +
    '5'#13#10'hello'#13#10 +
    '0'#13#10 +
    'X-Trace: abc123'#13#10 +
    'X-Auth-Context: role=admin'#13#10#13#10;
begin
  LGotBody := '';
  LGotTrailerDecl := '';
  SetLength(LGotTrailerDeclValues, 0);
  LGotTraceValue := '';
  LGotAuthValue := '';
  SetLength(LGotTraceValues, 0);
  SetLength(LGotAuthValues, 0);
  LHasTrace := False;
  LHasAuth := False;
  LRouter := NewRouter;
  LRouter.Post('/upload', procedure(const AReq: IHttpRequest;
    const AW: IHttpResponseWriter)
  var
    LBuf: array[0..15] of Byte;
    LN: SizeUInt;
    LBody: string;
    LRespBody: string;
  begin
    LBody := '';
    if AReq.Body <> nil then
      repeat
        LN := AReq.Body.Read(LBuf[0], SizeUInt(Length(LBuf)));
        if LN > 0 then
        begin
          SetLength(LBody, Length(LBody) + Int32(LN));
          Move(LBuf[0], LBody[Length(LBody) - Int32(LN) + 1], LN);
        end;
      until LN = 0;

    LGotBody := LBody;
    LGotTrailerDecl := AReq.Headers.Get('Trailer');
    LGotTrailerDeclValues := AReq.Headers.GetAll('Trailer');
    LGotTraceValue := AReq.Headers.Get('X-Trace');
    LGotAuthValue := AReq.Headers.Get('X-Auth-Context');
    LGotTraceValues := AReq.Headers.GetAll('X-Trace');
    LGotAuthValues := AReq.Headers.GetAll('X-Auth-Context');
    LHasTrace := AReq.Headers.Has('X-Trace');
    LHasAuth := AReq.Headers.Has('X-Auth-Context');

    LRespBody := 'ok';
    AW.GetHeaders.SetHeader('content-length', IntToStr(Int64(Length(LRespBody))));
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(LRespBody[1], SizeUInt(Length(LRespBody)));
  end);

  LHandle := StartServerWithTransport(LRouter as IHttpHandler, nil, LServer, LPort);
  try
    LResp := SendRawRequestAndReadAll(LPort, REQ);
    Check(Pos('200 OK', LResp) > 0,
      'Chunked multiple trailer declaration contract returns 200');
    CheckEqual('hello', LGotBody,
      'Chunked multiple trailer declaration contract decodes chunked body');
    CheckEqual('X-Trace, X-Auth-Context', LGotTrailerDecl,
      'Chunked multiple trailer declaration contract preserves declaration header');
    CheckEqual(Int64(1), Int64(Length(LGotTrailerDeclValues)),
      'Chunked multiple trailer declaration contract keeps one declaration entry');
    CheckEqual('X-Trace, X-Auth-Context', LGotTrailerDeclValues[0],
      'Chunked multiple trailer declaration contract preserves declaration entry text');
    CheckEqual('', LGotTraceValue,
      'Chunked multiple trailer declaration contract hides trace trailer field');
    CheckEqual('', LGotAuthValue,
      'Chunked multiple trailer declaration contract hides auth trailer field');
    CheckEqual(Int64(0), Int64(Length(LGotTraceValues)),
      'Chunked multiple trailer declaration contract exposes no trace trailer values');
    CheckEqual(Int64(0), Int64(Length(LGotAuthValues)),
      'Chunked multiple trailer declaration contract exposes no auth trailer values');
    Check(not LHasTrace,
      'Chunked multiple trailer declaration contract does not report hidden trace trailer field');
    Check(not LHasAuth,
      'Chunked multiple trailer declaration contract does not report hidden auth trailer field');
  finally
    StopServer(LServer, LHandle);
  end;
end;

begin
  T := TTestSuite.Create('nextpas.core.http.contract');
  T.Test('NewHeaders: Set/Get/Has/Del/Count/Clone', @TestNewHeaders);
  T.Test('NewRouter: Get route + FindRoute', @TestNewRouter);
  T.Test('IHttpRouter convenience methods are callable through interface', @TestRouterConvenienceMethodsOnInterface);
  T.Test('NewRequest: Method/Url/Version', @TestNewRequest);
  T.Test('NewResponse: StatusCode/Headers', @TestNewResponse);
  T.Test('HandlerFunc wraps correctly', @TestHandlerFuncWrap);
  T.Test('HandlerFunc wraps plain procedures through facade', @TestHandlerProcWrap);
  T.Test('HandlerFunc wraps object methods through facade', @TestHandlerMethodWrap);
  T.Test('Chain applies middleware', @TestChainMiddleware);
  T.Test('NewHttpServer overloads are available through facade', @TestHttpServerFacadeOverloads);
  T.Test('NewHttpClient overloads are available through facade', @TestHttpClientFacadeOverloads);
  T.Test('Injected client transport is used through facade client', @TestHttpClientTransportInjection);
  T.Test('Injected server transport is used through facade server', @TestHttpServerTransportInjection);
  T.Test('Injected server transport session factory is preferred',
    @TestHttpServerTransportInjectionPrefersSessionFactory);
  T.Test('Injected server transport context session factory is preferred',
    @TestHttpServerTransportInjectionPrefersContextSessionFactory);
  T.Test('UrlEncode/UrlDecode round-trip', @TestUrlEncodeDecodeRoundTrip);
  T.Test('ParseQueryString basic', @TestParseQueryString);
  T.Test('EncodeQueryString round-trip', @TestEncodeQueryStringRoundTrip);
  T.Test('HttpMethodToStr all methods', @TestHttpMethodToStr);
  T.Test('HttpStrToMethod all methods', @TestHttpStrToMethod);
  T.Test('HttpStatusText known codes', @TestHttpStatusText);
  T.Test('IHttpTransport RoundTrip contract shape', @TestHttpTransportRoundTripContract);
  T.Test('IHttpServerTransport ServeConn contract shape', @TestHttpServerTransportServeConnContract);
  T.Test('IHttpHijacker facade alias', @TestHttpHijackerFacadeAlias);
  T.Test('HttpServer rejects nil handler', @TestHttpServerRejectsNilHandler);
  T.Test('IHttpServer lifecycle contract shape', @TestHttpServerLifecycleContractOnInterface);
  T.Test('HttpServer honors explicit backend selection',
    @TestHttpServerHonorsExplicitBackendSelection);
  T.Test('HttpServer facade owner-boundary source contract',
    @TestHttpServerFacadeOwnerBoundarySourceContract);
  T.Test('Http minimal facade source contract',
    @TestHttpMinimalFacadeSourceContract);
  T.Test('NewRequest facade deprecation parity source contract',
    @TestNewRequestFacadeDeprecationParitySourceContract);
  T.Test('Error taxonomy: no bare EArgumentError source contract',
    @TestHttpErrorTaxonomyNoBareArgumentErrorSourceContract);
  T.Test('Error taxonomy: stable Op set source contract',
    @TestHttpErrorStableOpSetSourceContract);
  T.Test('With* chain semantics source contract',
    @TestHttpWithStarChainSemanticsSourceContract);
  T.Test('FPC RTL isolation source contract (src+tests)',
    @TestHttpFpcRtlIsolationSourceContract);
  T.Test('Chunked request trailer contract',
    @TestChunkedRequestTrailerContract);
  T.Test('Chunked request multiple trailer declaration contract',
    @TestChunkedRequestMultipleTrailerDeclarationContract);
  if not T.Run then Halt(1);
end.
