program test_http_registry;

{$I nextpas.core.settings.inc}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  nextpas.core.base,
  nextpas.core.testing,
  nextpas.core.net,
  nextpas.core.net.base,
  nextpas.core.net.intf,
  nextpas.core.http.base,
  nextpas.core.http.intf,
  nextpas.core.http.headers,
  nextpas.core.http.message,
  nextpas.core.http.middleware,
  nextpas.core.http.client,
  nextpas.core.http.server,
  nextpas.core.http.impl.registry,
  nextpas.core.platform.thread;

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

var
  T: TTestRunner;
  GClientFactoryTransport: IHttpTransport;
  GServerFactoryTransport: IHttpServerTransport;
  GSeenClientTimeout: Int64;
  GSeenServerHeaderLimit: Int32;

function CreateMockClientTransport(const AOptions: THttpClientOptions): IHttpTransport;
begin
  GSeenClientTimeout := AOptions.Timeout;
  Result := GClientFactoryTransport;
end;

function CreateMockServerTransport(const AOptions: THttpServerOptions): IHttpServerTransport;
begin
  GSeenServerHeaderLimit := AOptions.MaxHeaderSize;
  Result := GServerFactoryTransport;
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

function StartServer(const AHandler: IHttpHandler; out AServer: THttpServer;
  out APort: UInt16): TPlatformThreadHandle;
var
  LCtx: PServerCtx;
  LHandle: TPlatformThreadHandle;
  LWait: Int32;
begin
  AServer := THttpServer.Create(AHandler, THttpServerOptions.Default);
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

function TMockHttpTransport.RoundTrip(const AReq: IHttpRequest): IHttpResponse;
var
  LHeaders: IHttpHeaders;
begin
  FRoundTripCalled := True;
  FSeenMethod := AReq.Method;
  FSeenPath := AReq.Url.Path;
  LHeaders := NewHttpHeaders;
  Result := THttpResponse.Create(HTTP_STATUS_OK, LHeaders, nil);
end;

function TMockServerTransport.ServeConn(const AConn: ITcpStream;
  const AHandler: IHttpHandler): TTcpServerConnOwnership;
var
  LReq: IHttpRequest;
begin
  FServeConnCalled := True;
  if AHandler <> nil then
  begin
    LReq := THttpRequest.Create(hmGet, TUrl.Parse('/registry'),
      hvHttp11, NewHttpHeaders, nil, 0);
    AHandler.ServeHTTP(LReq, nil);
  end;
  Result := TCP_SERVER_CONN_OWNERSHIP_SERVER;
end;

procedure RestoreClientFactory(const AFactory: THttpClientTransportFactory;
  const AVersion: THttpVersion);
begin
  if Assigned(AFactory) then
    RegisterClientTransport(AVersion, AFactory)
  else
    UnregisterClientTransport(AVersion);
end;

procedure RestoreServerFactory(const AFactory: THttpServerTransportFactory;
  const AVersion: THttpVersion);
begin
  if Assigned(AFactory) then
    RegisterServerTransport(AVersion, AFactory)
  else
    UnregisterServerTransport(AVersion);
end;

procedure TestResolveClientTransportRaisesWhenMissing;
var
  LOldFactory: THttpClientTransportFactory;
  LHadFactory: Boolean;
  LRaised: Boolean;
begin
  LHadFactory := TryGetClientTransportFactory(hvHttp2, LOldFactory);
  UnregisterClientTransport(hvHttp2);
  LRaised := False;
  try
    ResolveClientTransport(hvHttp2, THttpClientOptions.Default);
  except
    on E: EHttpError do
      LRaised := True;
  end;
  if LHadFactory then
    RestoreClientFactory(LOldFactory, hvHttp2);
  Check(LRaised, 'missing client transport raises EHttpError');
end;

procedure TestResolveServerTransportRaisesWhenMissing;
var
  LOldFactory: THttpServerTransportFactory;
  LHadFactory: Boolean;
  LRaised: Boolean;
begin
  LHadFactory := TryGetServerTransportFactory(hvHttp2, LOldFactory);
  UnregisterServerTransport(hvHttp2);
  LRaised := False;
  try
    ResolveServerTransport(hvHttp2, THttpServerOptions.Default);
  except
    on E: EHttpError do
      LRaised := True;
  end;
  if LHadFactory then
    RestoreServerFactory(LOldFactory, hvHttp2);
  Check(LRaised, 'missing server transport raises EHttpError');
end;

procedure TestClientConstructorUsesRegistryDefault;
var
  LOldFactory: THttpClientTransportFactory;
  LOldVersion: THttpVersion;
  LClient: IHttpClient;
  LOptions: THttpClientOptions;
  LMock: TMockHttpTransport;
  LResp: IHttpResponse;
begin
  Check(TryGetClientTransportFactory(hvHttp11, LOldFactory),
    'built-in HTTP/1.1 client factory exists');
  LOldVersion := GetDefaultClientVersion;
  LMock := TMockHttpTransport.Create;
  GClientFactoryTransport := LMock as IHttpTransport;
  GSeenClientTimeout := 0;
  RegisterClientTransport(hvHttp11, @CreateMockClientTransport);
  SetDefaultClientVersion(hvHttp11);
  try
    LOptions := THttpClientOptions.Default;
    LOptions.Timeout := 1234;
    LClient := THttpClient.Create(LOptions);
    LResp := LClient.Get('http://example.com/registry');
    Check(LResp <> nil, 'registry client returns response');
    CheckEqual(Int64(200), Int64(LResp.StatusCode), 'registry client response status');
    Check(LMock.RoundTripCalled, 'default client constructor uses registry transport');
    Check(LMock.SeenMethod = hmGet, 'registry client sees GET');
    CheckEqual('/registry', LMock.SeenPath, 'registry client sees request path');
    CheckEqual(Int64(1234), GSeenClientTimeout, 'registry client factory sees options');
  finally
    LResp := nil;
    LClient := nil;
    RestoreClientFactory(LOldFactory, hvHttp11);
    SetDefaultClientVersion(LOldVersion);
    GClientFactoryTransport := nil;
  end;
end;

procedure TestServerConstructorUsesRegistryDefault;
var
  LOldFactory: THttpServerTransportFactory;
  LOldVersion: THttpVersion;
  LMock: TMockServerTransport;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LConn: ITcpStream;
  LHandlerCalled: Boolean;
  LWait: Int32;
begin
  Check(TryGetServerTransportFactory(hvHttp11, LOldFactory),
    'built-in HTTP/1.1 server factory exists');
  LOldVersion := GetDefaultServerVersion;
  LMock := TMockServerTransport.Create;
  GServerFactoryTransport := LMock as IHttpServerTransport;
  GSeenServerHeaderLimit := 0;
  RegisterServerTransport(hvHttp11, @CreateMockServerTransport);
  SetDefaultServerVersion(hvHttp11);
  LHandlerCalled := False;
  try
    LHandle := StartServer(nextpas.core.http.middleware.HandlerFunc(procedure(const AReq: IHttpRequest;
      const AW: IHttpResponseWriter)
    begin
      LHandlerCalled := True;
      CheckEqual('/registry', AReq.Url.Path, 'registry server passes handler request');
    end), LServer, LPort);
    try
      LConn := TcpConnect('127.0.0.1', LPort);
      LConn.Close;
      LWait := 0;
      while (not LMock.ServeConnCalled) and (LWait < 200) do
      begin
        platform_thread_sleep_ns(5000000);
        Inc(LWait);
      end;
      Check(LMock.ServeConnCalled, 'default server constructor uses registry transport');
      Check(LHandlerCalled, 'registry server transport can dispatch handler');
      CheckEqual(Int64(8192), Int64(GSeenServerHeaderLimit),
        'registry server factory sees default options');
    finally
      StopServer(LServer, LHandle);
    end;
  finally
    RestoreServerFactory(LOldFactory, hvHttp11);
    SetDefaultServerVersion(LOldVersion);
    GServerFactoryTransport := nil;
  end;
end;

begin
  T := TTestRunner.Create('nextpas.core.http.impl.registry');
  T.Run('ResolveClientTransport raises when version is missing',
    @TestResolveClientTransportRaisesWhenMissing);
  T.Run('ResolveServerTransport raises when version is missing',
    @TestResolveServerTransportRaisesWhenMissing);
  T.Run('THttpClient default constructor uses registry default',
    @TestClientConstructorUsesRegistryDefault);
  T.Run('THttpServer default constructor uses registry default',
    @TestServerConstructorUsesRegistryDefault);
  T.Summary;
end.
