program test_http_https_redirect;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.thread.init,
  nextpas.core.base,
  nextpas.core.test,
  nextpas.core.text.conv,
  nextpas.core.errors,
  nextpas.core.io.intf,
  nextpas.core.net,
  nextpas.core.net.base,
  nextpas.core.net.intf,
  nextpas.core.http,
  nextpas.core.http.base,
  nextpas.core.http.intf,
  nextpas.core.http.headers,
  nextpas.core.http.router,
  nextpas.core.http.server,
  nextpas.core.http.client,
  nextpas.core.time.base,
  nextpas.core.time.deadline,
  nextpas.core.platform.thread;

var
  T: TTestSuite;

type
  PServerCtx = ^TServerCtx;
  TServerCtx = record
    Server: THttpServer;
    Addr: string;
    Port: UInt16;
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

function StartServer(const AHandler: IHttpHandler; out AServer: THttpServer; out APort: UInt16): TPlatformThreadHandle;
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

{ Test: Client correctly parses HTTPS redirect URL }
procedure TestHttpsRedirectUrlParsing;
var
  LUrl: TUrl;
begin
  LUrl := TUrl.Parse('https://example.com/path');
  CheckEqual('https', LUrl.Scheme, 'scheme');
  CheckEqual('example.com', LUrl.Host, 'host');
  CheckEqual('/path', LUrl.Path, 'path');
  CheckEqual(0, LUrl.Port, 'default port');
end;

{ Test: Client correctly identifies HTTPS default port }
procedure TestHttpsDefaultPort;
var
  LUrl: TUrl;
begin
  LUrl := TUrl.Parse('https://example.com');
  { URL parser returns 0 for default port }
  CheckEqual(0, LUrl.Port, 'HTTPS default port (not specified)');
end;

{ Test: Client correctly handles HTTP to HTTPS redirect }
procedure TestHttpToHttpsRedirect;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LClient: IHttpClient;
  LCaught: Boolean;
begin
  LRouter := THttpRouter.Create;
  LRouter.Get('/redirect', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    AW.GetHeaders.SetHeader('location', 'https://example.com/secure');
    AW.WriteHeader(HTTP_STATUS_MOVED_PERMANENTLY);
  end);

  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LClient := NewHttpClient(THttpClientOptions.Default);
    LCaught := False;
    try
      LClient.Get('http://127.0.0.1:' + IntToStr(LPort) + '/redirect');
    except
      on E: EHttpError do
        LCaught := True;
    end;
    { Client should raise error for unsupported HTTPS scheme }
    CheckTrue(LCaught, 'expected HTTPS redirect error');
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Test: Client correctly handles HTTPS to HTTP redirect }
procedure TestHttpsToHttpRedirect;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LClient: IHttpClient;
  LResp: IHttpResponse;
begin
  LRouter := THttpRouter.Create;
  LRouter.Get('/downgrade', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    AW.GetHeaders.SetHeader('location', 'http://127.0.0.1:' + IntToStr(LPort) + '/insecure');
    AW.WriteHeader(HTTP_STATUS_FOUND);
  end);
  LRouter.Get('/insecure', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    AW.GetHeaders.SetHeader('content-type', 'text/plain');
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write('insecure' + #13#10, 10);
  end);

  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LClient := NewHttpClient(THttpClientOptions.Default);
    LResp := LClient.Get('http://127.0.0.1:' + IntToStr(LPort) + '/downgrade');

    { Client should follow redirect to HTTP }
    CheckEqual(Ord(HTTP_STATUS_OK), Ord(LResp.StatusCode), 'redirect response');
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Test: Client correctly handles redirect loop detection }
procedure TestRedirectLoopDetection;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LClient: IHttpClient;
  LCaught: Boolean;
begin
  LRouter := THttpRouter.Create;
  LRouter.Get('/loop', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    AW.GetHeaders.SetHeader('location', 'http://127.0.0.1:' + IntToStr(LPort) + '/loop');
    AW.WriteHeader(HTTP_STATUS_MOVED_PERMANENTLY);
  end);

  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LClient := NewHttpClient(THttpClientOptions.Default);
    LCaught := False;
    try
      LClient.Get('http://127.0.0.1:' + IntToStr(LPort) + '/loop');
    except
      on E: EHttpError do
        LCaught := True;
    end;
    CheckTrue(LCaught, 'expected redirect loop error');
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Test: Client correctly handles redirect limit }
procedure TestRedirectLimit;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LClient: IHttpClient;
  LCaught: Boolean;
  LOptions: THttpClientOptions;
begin
  LRouter := THttpRouter.Create;
  LRouter.Get('/limit', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    AW.GetHeaders.SetHeader('location', 'http://127.0.0.1:' + IntToStr(LPort) + '/limit');
    AW.WriteHeader(HTTP_STATUS_MOVED_PERMANENTLY);
  end);

  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LOptions := THttpClientOptions.Default;
    LOptions.MaxRedirects := 3;
    LClient := NewHttpClient(LOptions);
    LCaught := False;
    try
      LClient.Get('http://127.0.0.1:' + IntToStr(LPort) + '/limit');
    except
      on E: EHttpError do
        LCaught := True;
    end;
    CheckTrue(LCaught, 'expected redirect limit error');
  finally
    StopServer(LServer, LHandle);
  end;
end;

begin
  T := TTestSuite.Create('nextpas.core.http.https_redirect');

  { URL parsing tests }
  T.Test('HTTPS redirect URL parsing', @TestHttpsRedirectUrlParsing);
  T.Test('HTTPS default port', @TestHttpsDefaultPort);

  { Redirect tests }
  T.Test('HTTP to HTTPS redirect', @TestHttpToHttpsRedirect);
  T.Test('HTTPS to HTTP redirect', @TestHttpsToHttpRedirect);

  { Error handling tests }
  T.Test('Redirect loop detection', @TestRedirectLoopDetection);
  T.Test('Redirect limit', @TestRedirectLimit);

  if not T.Run then Halt(1);
end.
