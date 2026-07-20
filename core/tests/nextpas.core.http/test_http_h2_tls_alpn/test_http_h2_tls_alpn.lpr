program test_http_h2_tls_alpn;
{**
 * @desc H2P-3: live HTTP/2 over TLS with ALPN "h2".
 *       Server: NewHttpServer(hvHttp2 + TLSContext) → NewH2TlsServerTransport.
 *       Client: NewHttpClient(hvHttp2 + TLSContext) → https:// + ALPN h2.
 *}

{$I nextpas.core.settings.inc}

uses
  SysUtils,
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
    .WithOrganization('nextpas-h2p3')
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

function StartH2TlsServer(const AHandler: IHttpHandler;
  out AServer: IHttpServer; out APort: UInt16): TPlatformThreadHandle;
var
  LOpts: THttpServerOptions;
  LCtx: PServerCtx;
  LWait: Int32;
begin
  LOpts := THttpServerOptions.Default.WithVersion(hvHttp2).WithIdleTimeout(5000);
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
  Check(AServer.IsRunning, 'H2 TLS server listening');
  APort := AServer.LocalAddr.Port;
  Check(APort > 0, 'H2 TLS server port');
end;

procedure StopH2TlsServer(var AServer: IHttpServer;
  const AHandle: TPlatformThreadHandle);
var
  LRet: Pointer;
begin
  if AServer <> nil then
    AServer.Shutdown;
  platform_thread_join(AHandle, LRet);
  AServer := nil;
end;

function NewH2TlsClient: IHttpClient;
var
  LOpts: THttpClientOptions;
begin
  LOpts := THttpClientOptions.Default
    .WithVersion(hvHttp2)
    .WithTimeout(10000)
    .WithConnectTimeout(5000)
    .WithTLSContext(NewClientTlsContext);
  Result := NewHttpClient(LOpts);
end;

function HttpsUrl(const APort: UInt16; const APath: string): string;
begin
  Result := 'https://127.0.0.1:' + IntToStr(Int64(APort)) + APath;
end;

procedure TestH2TlsAlpnGet200;
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
    HttpWriteResponseString(AW, HTTP_STATUS_OK, 'text/plain', 'h2-tls-ok');
  end);
  LHandle := StartH2TlsServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LClient := NewH2TlsClient;
    try
      LResp := LClient.Get(HttpsUrl(LPort, '/hello'));
      Check(LResp <> nil, 'H2 TLS GET response');
      CheckEqual(Int64(HTTP_STATUS_OK), Int64(LResp.StatusCode), 'status 200');
      LBody := HttpReadResponseBodyString(LResp);
      CheckEqual('h2-tls-ok', LBody, 'body');
    finally
      LResp := nil;
      LClient.CloseIdleConnections;
      LClient := nil;
    end;
  finally
    StopH2TlsServer(LServer, LHandle);
  end;
end;

procedure TestH2TlsAlpnPostRoundTrip;
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
  LHandle := StartH2TlsServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LClient := NewH2TlsClient;
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
    StopH2TlsServer(LServer, LHandle);
  end;
end;

procedure TestH2TlsAlpnSequentialGets;
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
  LHandle := StartH2TlsServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LClient := NewH2TlsClient;
    try
      for LI := 1 to 5 do
      begin
        LResp := LClient.Get(HttpsUrl(LPort, '/n'));
        CheckEqual(Int64(HTTP_STATUS_OK), Int64(LResp.StatusCode), 'seq 200');
        CheckEqual(IntToStr(Int64(LI)), HttpReadResponseBodyString(LResp),
          'seq body');
        LResp := nil;
      end;
      CheckEqual(Int64(5), Int64(LHits), 'handler hit 5');
    finally
      LClient.CloseIdleConnections;
      LClient := nil;
    end;
  finally
    StopH2TlsServer(LServer, LHandle);
  end;
end;

procedure TestH2TlsAlpnConstants;
begin
  Checkequal('h2', HTTP2_ALPN_PROTOCOL, 'ALPN token is h2');
end;

begin
  T := TTestSuite.Create('nextpas.core.http H2 TLS ALPN (H2P-3)');
  T.Test('ALPN protocol constant is h2', @TestH2TlsAlpnConstants);
  T.Test('H2 TLS ALPN GET 200 facade e2e', @TestH2TlsAlpnGet200);
  T.Test('H2 TLS ALPN POST body round-trip', @TestH2TlsAlpnPostRoundTrip);
  T.Test('H2 TLS ALPN sequential GETs', @TestH2TlsAlpnSequentialGets);
  if not T.Run then
    Halt(1);
end.
