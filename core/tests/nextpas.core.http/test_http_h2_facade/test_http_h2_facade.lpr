program test_http_h2_facade;
{**
 * @desc P2 proof: live NewHttpClient/Server with Options.WithVersion(hvHttp2)
 *       over cleartext prior-knowledge HTTP/2 (no h2c Upgrade, no TLS).
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

function NewH2FacadeServerOptions: THttpServerOptions;
begin
  { Short idle timeout so keep-alive session exits promptly after client close. }
  Result := THttpServerOptions.Default.WithVersion(hvHttp2).WithIdleTimeout(2000);
end;

function StartH2FacadeServerWithOptions(const AHandler: IHttpHandler;
  const AOpts: THttpServerOptions; out AServer: IHttpServer;
  out APort: UInt16): TPlatformThreadHandle;
var
  LCtx: PServerCtx;
  LHandle: TPlatformThreadHandle;
  LWait: Int32;
begin
  AServer := NewHttpServer(AHandler, AOpts);
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
  Check(AServer.IsRunning, 'H2 facade server started listening');
  APort := AServer.LocalAddr.Port;
  Check(APort > 0, 'H2 facade server bound free port');
  Result := LHandle;
end;

function StartH2FacadeServer(const AHandler: IHttpHandler;
  out AServer: IHttpServer; out APort: UInt16): TPlatformThreadHandle;
begin
  Result := StartH2FacadeServerWithOptions(AHandler, NewH2FacadeServerOptions,
    AServer, APort);
end;

procedure StopH2FacadeServer(var AServer: IHttpServer;
  const AHandle: TPlatformThreadHandle);
var
  LRet: Pointer;
begin
  if AServer <> nil then
    AServer.Shutdown;
  platform_thread_join(AHandle, LRet);
  AServer := nil;
end;

function NewH2FacadeClient: IHttpClient;
begin
  Result := NewHttpClient(
    THttpClientOptions.Default.WithVersion(hvHttp2).WithTimeout(5000));
end;

function LocalUrl(const APort: UInt16; const APath: string): string;
begin
  Result := 'http://127.0.0.1:' + IntToStr(Int64(APort)) + APath;
end;

procedure TestFacadeH2Get200;
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
    HttpWriteResponseString(AW, HTTP_STATUS_OK, 'text/plain', 'h2-ok');
  end);

  LHandle := StartH2FacadeServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LClient := NewH2FacadeClient;
    try
      LResp := LClient.Get(LocalUrl(LPort, '/hello'));
      Check(LResp <> nil, 'H2 facade GET returns response');
      CheckEqual(Int64(HTTP_STATUS_OK), Int64(LResp.StatusCode), 'status 200');
      LBody := HttpReadResponseBodyString(LResp);
      CheckEqual('h2-ok', LBody, 'body matches');
    finally
      LResp := nil;
      LClient := nil;
    end;
  finally
    StopH2FacadeServer(LServer, LHandle);
  end;
end;

procedure TestFacadeH2PostBodyRoundTrip;
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
  LRouter.Post('/echo', procedure(const AReq: IHttpRequest;
    const AW: IHttpResponseWriter)
  var
    LIn: string;
  begin
    LIn := HttpReadRequestBodyString(AReq);
    HttpWriteResponseString(AW, HTTP_STATUS_OK, 'text/plain', 'echo:' + LIn);
  end);

  LHandle := StartH2FacadeServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LClient := NewH2FacadeClient;
    try
      LResp := LClient.Post(LocalUrl(LPort, '/echo'), 'text/plain', 'ping');
      Check(LResp <> nil, 'H2 facade POST returns response');
      CheckEqual(Int64(HTTP_STATUS_OK), Int64(LResp.StatusCode), 'status 200');
      LBody := HttpReadResponseBodyString(LResp);
      CheckEqual('echo:ping', LBody, 'body round-trip');
    finally
      LResp := nil;
      LClient := nil;
    end;
  finally
    StopH2FacadeServer(LServer, LHandle);
  end;
end;

procedure TestFacadeH2SequentialGetsReusePath;
var
  LRouter: IHttpRouter;
  LServer: IHttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LClient: IHttpClient;
  LResp1, LResp2: IHttpResponse;
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

  LHandle := StartH2FacadeServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LClient := NewH2FacadeClient;
    try
      LResp1 := LClient.Get(LocalUrl(LPort, '/n'));
      LResp2 := LClient.Get(LocalUrl(LPort, '/n'));
      CheckEqual(Int64(HTTP_STATUS_OK), Int64(LResp1.StatusCode), 'first 200');
      CheckEqual(Int64(HTTP_STATUS_OK), Int64(LResp2.StatusCode), 'second 200');
      CheckEqual('1', HttpReadResponseBodyString(LResp1), 'first hit');
      CheckEqual('2', HttpReadResponseBodyString(LResp2), 'second hit');
    finally
      LResp1 := nil;
      LResp2 := nil;
      LClient := nil;
    end;
  finally
    StopH2FacadeServer(LServer, LHandle);
  end;
end;

procedure TestFacadeH2NotFound;
var
  LRouter: IHttpRouter;
  LServer: IHttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LClient: IHttpClient;
  LResp: IHttpResponse;
begin
  LRouter := NewRouter;
  LRouter.Get('/only', procedure(const AReq: IHttpRequest;
    const AW: IHttpResponseWriter)
  begin
    HttpWriteResponseString(AW, HTTP_STATUS_OK, 'text/plain', 'ok');
  end);

  LHandle := StartH2FacadeServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LClient := NewH2FacadeClient;
    try
      LResp := LClient.Get(LocalUrl(LPort, '/missing'));
      Check(LResp <> nil, 'H2 facade 404 returns response');
      CheckEqual(Int64(HTTP_STATUS_NOT_FOUND), Int64(LResp.StatusCode),
        'status 404');
    finally
      LResp := nil;
      LClient := nil;
    end;
  finally
    StopH2FacadeServer(LServer, LHandle);
  end;
end;

{$IFDEF NEXTPAS_LINUX}
procedure TestFacadeH2Get200EpollBackend;
{ S3-3 regression: H2 poll path must work under epoll (would-block I/O). }
var
  LRouter: IHttpRouter;
  LServer: IHttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LClient: IHttpClient;
  LResp: IHttpResponse;
  LOpts: THttpServerOptions;
  LBody: string;
begin
  LRouter := NewRouter;
  LRouter.Get('/hello', procedure(const AReq: IHttpRequest;
    const AW: IHttpResponseWriter)
  begin
    HttpWriteResponseString(AW, HTTP_STATUS_OK, 'text/plain', 'h2-epoll');
  end);
  LOpts := NewH2FacadeServerOptions;
  LOpts.Backend := TCP_SERVER_BACKEND_EPOLL;
  LHandle := StartH2FacadeServerWithOptions(LRouter as IHttpHandler, LOpts,
    LServer, LPort);
  try
    LClient := NewH2FacadeClient;
    try
      LResp := LClient.Get(LocalUrl(LPort, '/hello'));
      Check(LResp <> nil, 'H2 epoll GET returns response');
      CheckEqual(Int64(HTTP_STATUS_OK), Int64(LResp.StatusCode), 'epoll status');
      LBody := HttpReadResponseBodyString(LResp);
      CheckEqual('h2-epoll', LBody, 'epoll body');
    finally
      LResp := nil;
      LClient := nil;
    end;
  finally
    StopH2FacadeServer(LServer, LHandle);
  end;
end;
{$ENDIF}

begin
  T := TTestSuite.Create('nextpas.core.http h2 facade e2e');
  T.Test('Facade H2 GET 200 cleartext prior-knowledge', @TestFacadeH2Get200);
  T.Test('Facade H2 POST body round-trip', @TestFacadeH2PostBodyRoundTrip);
  T.Test('Facade H2 sequential GETs', @TestFacadeH2SequentialGetsReusePath);
  T.Test('Facade H2 router 404', @TestFacadeH2NotFound);
  {$IFDEF NEXTPAS_LINUX}
  T.Test('Facade H2 GET 200 with epoll backend', @TestFacadeH2Get200EpollBackend);
  {$ENDIF}
  if not T.Run then
    Halt(1);
end.
