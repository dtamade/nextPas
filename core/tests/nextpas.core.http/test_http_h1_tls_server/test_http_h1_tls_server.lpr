program test_http_h1_tls_server;
{**
 * @desc C-A product path: H1 HTTPS server via THttpServer + TLSContext.
 *       Server: NewHttpServer(default H1 + TLSContext) → NewH1TlsServerTransport.
 *       Client: NewHttpClient(TLSContext) → https:// + ALPN http/1.1.
 *}

{$I nextpas.core.settings.inc}

uses
  nextpas.core.thread.init,
  nextpas.core.base,
  nextpas.core.test,
  nextpas.core.text.conv,
  nextpas.core.http,
  nextpas.core.http.base,
  nextpas.core.http.intf,
  nextpas.core.tls.base,
  nextpas.core.tls.context.builder,
  nextpas.core.tls.cert.builder,
  nextpas.core.tls.openssl.backed,
  nextpas.core.tls.http2.alpn,
  nextpas.core.platform.thread;

type
  PServerCtx = ^TServerCtx;
  TServerCtx = record
    Server: IHttpServer;
    Addr: string;
    Port: UInt16;
  end;

var
  T: TTestSuite;

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

function NewServerTlsContext: ISSLContext;
var
  LKeyPair: IKeyPairWithCertificate;
  LCertPEM, LKeyPEM: string;
begin
  LKeyPair := TCertificateBuilder.Create
    .WithCommonName('127.0.0.1')
    .WithOrganization('nextpas-h1-tls')
    .SelfSigned;
  LKeyPair.SaveToPEM(LCertPEM, LKeyPEM);
  Result := TSSLContextBuilder.Create
    .WithTLS12And13
    .WithCertificatePEM(LCertPEM)
    .WithPrivateKeyPEM(LKeyPEM)
    .WithVerifyNone
    .BuildServer;
end;

function NewClientTlsContext: ISSLContext;
begin
  Result := TSSLContextBuilder.Create
    .WithTLS12And13
    .WithVerifyNone
    .BuildClient;
end;

function StartH1TlsServer(const AHandler: IHttpHandler;
  out AServer: IHttpServer; out APort: UInt16): TPlatformThreadHandle;
var
  LOpts: THttpServerOptions;
  LCtx: PServerCtx;
  LWait: Int32;
begin
  { Default version is H1; TLSContext selects NewH1TlsServerTransport. }
  LOpts := THttpServerOptions.Default.WithIdleTimeout(5000);
  LOpts.TLSContext := NewServerTlsContext;
  AServer := NewHttpServer(AHandler, LOpts);
  New(LCtx);
  LCtx^.Server := AServer;
  LCtx^.Addr := '127.0.0.1';
  LCtx^.Port := 0;
  platform_thread_create(Result, @ServerThreadFunc, LCtx);
  LWait := 0;
  while (not AServer.IsRunning) and (LWait < 400) do
  begin
    platform_thread_sleep_ns(5000000);
    Inc(LWait);
  end;
  Check(AServer.IsRunning, 'H1 TLS server listening');
  APort := AServer.LocalAddr.Port;
  Check(APort > 0, 'H1 TLS server port');
end;

procedure StopH1TlsServer(var AServer: IHttpServer;
  const AHandle: TPlatformThreadHandle);
var
  LRet: Pointer;
begin
  if AServer <> nil then
    AServer.Shutdown;
  platform_thread_join(AHandle, LRet);
  AServer := nil;
end;

function NewH1TlsClient: IHttpClient;
var
  LOpts: THttpClientOptions;
begin
  LOpts := THttpClientOptions.Default
    .WithTimeout(10000)
    .WithConnectTimeout(5000)
    .WithTLSContext(NewClientTlsContext);
  Result := NewHttpClient(LOpts);
end;

function HttpsUrl(const APort: UInt16; const APath: string): string;
begin
  Result := 'https://127.0.0.1:' + IntToStr(Int64(APort)) + APath;
end;

procedure TestH1TlsServerGet200;
var
  LRouter: IHttpRouter;
  LServer: IHttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LClient: IHttpClient;
  LResp: IHttpResponse;
  LBody: string;
begin
  LRouter := NewRouter;
  LRouter.Get('/hello', procedure(const AReq: IHttpRequest;
    const AW: IHttpResponseWriter)
  begin
    HttpWriteResponseString(AW, HTTP_STATUS_OK, 'text/plain', 'h1-tls-ok');
  end);
  LHandle := StartH1TlsServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LClient := NewH1TlsClient;
    try
      LResp := LClient.Get(HttpsUrl(LPort, '/hello'));
      Check(LResp <> nil, 'H1 TLS GET response');
      CheckEqual(Int64(HTTP_STATUS_OK), Int64(LResp.StatusCode), 'status 200');
      LBody := HttpReadResponseBodyString(LResp);
      CheckEqual('h1-tls-ok', LBody, 'body');
    finally
      LResp := nil;
      LClient.CloseIdleConnections;
      LClient := nil;
    end;
  finally
    StopH1TlsServer(LServer, LHandle);
  end;
end;

procedure TestH1TlsServerPostRoundTrip;
var
  LRouter: IHttpRouter;
  LServer: IHttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LClient: IHttpClient;
  LResp: IHttpResponse;
begin
  LRouter := NewRouter;
  LRouter.Post('/echo', procedure(const AReq: IHttpRequest;
    const AW: IHttpResponseWriter)
  var
    LIn: string;
  begin
    LIn := HttpReadRequestBodyString(AReq);
    HttpWriteResponseString(AW, HTTP_STATUS_OK, 'text/plain', 'echo:' + LIn);
  end);
  LHandle := StartH1TlsServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LClient := NewH1TlsClient;
    try
      LResp := LClient.Post(HttpsUrl(LPort, '/echo'), 'text/plain', 'ping');
      CheckEqual(Int64(HTTP_STATUS_OK), Int64(LResp.StatusCode), 'post 200');
      CheckEqual('echo:ping', HttpReadResponseBodyString(LResp), 'post body');
    finally
      LResp := nil;
      LClient.CloseIdleConnections;
      LClient := nil;
    end;
  finally
    StopH1TlsServer(LServer, LHandle);
  end;
end;

procedure TestH1TlsServerKeepAliveSequentialGets;
var
  LRouter: IHttpRouter;
  LServer: IHttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LClient: IHttpClient;
  LResp: IHttpResponse;
  LI: Int32;
  LHits: Int32;
begin
  LHits := 0;
  LRouter := NewRouter;
  LRouter.Get('/n', procedure(const AReq: IHttpRequest;
    const AW: IHttpResponseWriter)
  begin
    Inc(LHits);
    HttpWriteResponseString(AW, HTTP_STATUS_OK, 'text/plain',
      IntToStr(Int64(LHits)));
  end);
  LHandle := StartH1TlsServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LClient := NewH1TlsClient;
    try
      for LI := 1 to 8 do
      begin
        LResp := LClient.Get(HttpsUrl(LPort, '/n'));
        CheckEqual(Int64(HTTP_STATUS_OK), Int64(LResp.StatusCode), 'seq 200');
        CheckEqual(IntToStr(Int64(LI)), HttpReadResponseBodyString(LResp),
          'seq body');
        LResp := nil;
      end;
      CheckEqual(Int64(8), Int64(LHits), 'handler hit 8');
    finally
      LClient.CloseIdleConnections;
      LClient := nil;
    end;
  finally
    StopH1TlsServer(LServer, LHandle);
  end;
end;

procedure TestH1TlsServerExplicitHttp11Version;
{ Explicit hvHttp11 + TLSContext still uses H1 TLS wrap (not H2). }
var
  LRouter: IHttpRouter;
  LServer: IHttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LClient: IHttpClient;
  LResp: IHttpResponse;
  LOpts: THttpServerOptions;
  LCtx: PServerCtx;
  LWait: Int32;
begin
  LRouter := NewRouter;
  LRouter.Get('/v', procedure(const AReq: IHttpRequest;
    const AW: IHttpResponseWriter)
  begin
    HttpWriteResponseString(AW, HTTP_STATUS_OK, 'text/plain', 'v11');
  end);
  LOpts := THttpServerOptions.Default.WithVersion(hvHttp11).WithIdleTimeout(5000);
  LOpts.TLSContext := NewServerTlsContext;
  LServer := NewHttpServer(LRouter as IHttpHandler, LOpts);
  New(LCtx);
  LCtx^.Server := LServer;
  LCtx^.Addr := '127.0.0.1';
  LCtx^.Port := 0;
  platform_thread_create(LHandle, @ServerThreadFunc, LCtx);
  LWait := 0;
  while (not LServer.IsRunning) and (LWait < 400) do
  begin
    platform_thread_sleep_ns(5000000);
    Inc(LWait);
  end;
  Check(LServer.IsRunning, 'explicit H1.1 TLS server listening');
  LPort := LServer.LocalAddr.Port;
  try
    LClient := NewH1TlsClient;
    try
      LResp := LClient.Get(HttpsUrl(LPort, '/v'));
      CheckEqual(Int64(HTTP_STATUS_OK), Int64(LResp.StatusCode), 'explicit 200');
      CheckEqual('v11', HttpReadResponseBodyString(LResp), 'explicit body');
    finally
      LResp := nil;
      LClient.CloseIdleConnections;
      LClient := nil;
    end;
  finally
    StopH1TlsServer(LServer, LHandle);
  end;
end;

procedure TestH1TlsAlpnConstants;
begin
  CheckEqual('http/1.1', HTTP11_ALPN_PROTOCOL, 'ALPN token is http/1.1');
end;

procedure TestH1TlsRegistryWiresProductPath;
{ Source-contract: H1 factory wraps TLS instead of raising H2-only residual. }
var
  LReg: string;
  LFile: TextFile;
  LLine: string;
  LAll: string;
begin
  LAll := '';
  AssignFile(LFile, '../../../src/nextpas.core.http.impl.registry.pas');
  Reset(LFile);
  try
    while not Eof(LFile) do
    begin
      ReadLn(LFile, LLine);
      LAll := LAll + LLine + #10;
    end;
  finally
    CloseFile(LFile);
  end;
  LReg := LAll;
  Check(Pos('NewH1TlsServerTransport', LReg) > 0,
    'registry wires NewH1TlsServerTransport');
  Check(Pos('TLS HTTP server currently requires HTTP/2', LReg) = 0,
    'registry no longer raises H1 TLS residual');
end;

begin
  T := TTestSuite.Create('nextpas.core.http H1 TLS server (C-A)');
  T.Test('ALPN protocol constant is http/1.1', @TestH1TlsAlpnConstants);
  T.Test('registry wires H1 TLS product path', @TestH1TlsRegistryWiresProductPath);
  T.Test('H1 TLS server GET 200 facade e2e', @TestH1TlsServerGet200);
  T.Test('H1 TLS server POST body round-trip', @TestH1TlsServerPostRoundTrip);
  T.Test('H1 TLS server keep-alive sequential GETs',
    @TestH1TlsServerKeepAliveSequentialGets);
  T.Test('H1 TLS server explicit hvHttp11 + TLSContext',
    @TestH1TlsServerExplicitHttp11Version);
  if not T.Run then
    Halt(1);
end.