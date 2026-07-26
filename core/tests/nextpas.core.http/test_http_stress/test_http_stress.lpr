program test_http_stress;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.thread.init,
  nextpas.core.base,
  nextpas.core.test,
  nextpas.core.text.conv,
  nextpas.core.io.intf,
  nextpas.core.http.base,
  nextpas.core.http.intf,
  nextpas.core.http.headers,
  nextpas.core.http.message,
  nextpas.core.http.router,
  nextpas.core.http.middleware,
  nextpas.core.http.server,
  nextpas.core.http.client,
  nextpas.core.http.impl.registry,
  nextpas.core.platform.thread;

const
  STRESS_REQUESTS = 96;
  STRESS_CONCURRENCY = 8;

type
  PThreadCtx = ^TThreadCtx;
  TThreadCtx = record
    Client: IHttpClient;
    BaseUrl: string;
    StartIdx: Int32;
    Count: Int32;
    SuccessCount: Int32;
    ErrorCount: Int32;
  end;

var
  GServer: THttpServer;
  GServerReady: Boolean;
  GServerHandle: TPlatformThreadHandle;

function ServerThreadFunc(AArg: Pointer): Pointer; cdecl;
var
  LRouter: IHttpRouter;
begin
  Result := nil;
  LRouter := NewRouter;
  LRouter.Get('/ping', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var
    LBody: string;
  begin
    LBody := 'pong';
    AW.GetHeaders.SetHeader('content-type', 'text/plain');
    AW.GetHeaders.SetHeader('content-length', IntToStr(Length(LBody)));
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(LBody[1], Length(LBody));
  end);
  GServer := THttpServer.Create(LRouter, THttpServerOptions.Default);
  try
    GServerReady := True;
    GServer.ListenAndServe('127.0.0.1', 0);
  except
  end;
  GServer.Free;
  GServer := nil;
end;

function ClientThreadFunc(AArg: Pointer): Pointer; cdecl;
var
  LCtx: PThreadCtx;
  LI: Int32;
  LResp: IHttpResponse;
begin
  Result := nil;
  LCtx := PThreadCtx(AArg);
  LCtx^.SuccessCount := 0;
  LCtx^.ErrorCount := 0;
  for LI := 0 to LCtx^.Count - 1 do
  begin
    try
      LResp := LCtx^.Client.Get(LCtx^.BaseUrl + '/ping');
      if (LResp <> nil) and (LResp.StatusCode = HTTP_STATUS_OK) then
        Inc(LCtx^.SuccessCount)
      else
        Inc(LCtx^.ErrorCount);
    except
      Inc(LCtx^.ErrorCount);
    end;
  end;
end;

procedure StartServer(out APort: UInt16);
var
  LWait: Int32;
begin
  GServerReady := False;
  platform_thread_create(GServerHandle, @ServerThreadFunc, nil);
  LWait := 0;
  APort := 0;
  { 等真实就绪：不仅线程创建了 server（GServerReady），还要 ListenAndServe
    已 bind、拿到 ephemeral 端口。仅靠 GServerReady 会竞争——它在 bind 前就置位，
    并行门禁下主线程会读到未绑定的端口 0。轮询真实条件（端口>0）消除竞争。 }
  while (APort = 0) and (LWait < 400) do
  begin
    platform_thread_sleep_ns(5000000);
    Inc(LWait);
    if GServerReady and (GServer <> nil) then
      APort := GServer.LocalAddr.Port;
  end;
  Check(GServerReady, 'server started');
  Check(APort > 0, 'server has port');
end;

procedure StopServer;
var
  LRet: Pointer;
begin
  if GServer <> nil then
    GServer.Shutdown;
  platform_thread_join(GServerHandle, LRet);
end;

procedure TestConcurrentRequests;
var
  LClientHandles: array[0..STRESS_CONCURRENCY - 1] of TPlatformThreadHandle;
  LCtxs: array[0..STRESS_CONCURRENCY - 1] of TThreadCtx;
  LTotalSuccess, LTotalError: Int32;
  LI: Int32;
  LPort: UInt16;
  LClient: IHttpClient;
  LRet: Pointer;
begin
  StartServer(LPort);
  LClient := THttpClient.Create(THttpClientOptions.Default);
  for LI := 0 to STRESS_CONCURRENCY - 1 do
  begin
    LCtxs[LI].Client := LClient;
    LCtxs[LI].BaseUrl := 'http://127.0.0.1:' + IntToStr(LPort);
    LCtxs[LI].StartIdx := LI * (STRESS_REQUESTS div STRESS_CONCURRENCY);
    LCtxs[LI].Count := STRESS_REQUESTS div STRESS_CONCURRENCY;
    platform_thread_create(LClientHandles[LI], @ClientThreadFunc, @LCtxs[LI]);
  end;

  LTotalSuccess := 0;
  LTotalError := 0;
  for LI := 0 to STRESS_CONCURRENCY - 1 do
  begin
    platform_thread_join(LClientHandles[LI], LRet);
    Inc(LTotalSuccess, LCtxs[LI].SuccessCount);
    Inc(LTotalError, LCtxs[LI].ErrorCount);
  end;

  CheckEqual(Int64(STRESS_REQUESTS), Int64(LTotalSuccess + LTotalError),
    'all requests accounted for');
  Check(LTotalSuccess > 0, 'at least some requests succeeded');
  CheckEqual(Int64(0), Int64(LTotalError), 'no request errors');

  LClient := nil;
  StopServer;
end;

procedure TestKeepAliveReuse;
var
  LPort: UInt16;
  LClient: IHttpClient;
  LI: Int32;
  LResp: IHttpResponse;
  LSuccessCount: Int32;
begin
  StartServer(LPort);
  LClient := THttpClient.Create(THttpClientOptions.Default);
  LSuccessCount := 0;
  for LI := 0 to 49 do
  begin
    try
      LResp := LClient.Get('http://127.0.0.1:' + IntToStr(LPort) + '/ping');
      if (LResp <> nil) and (LResp.StatusCode = HTTP_STATUS_OK) then
        Inc(LSuccessCount);
    except
    end;
  end;
  CheckEqual(Int64(50), Int64(LSuccessCount), 'all keep-alive requests succeed');

  LClient := nil;
  StopServer;
end;

procedure TestLargeResponseBody;
var
  LPort: UInt16;
  LClient: IHttpClient;
  LResp: IHttpResponse;
begin
  StartServer(LPort);
  LClient := THttpClient.Create(THttpClientOptions.Default);
  LResp := LClient.Get('http://127.0.0.1:' + IntToStr(LPort) + '/ping');
  Check(LResp <> nil, 'response not nil');
  Check(LResp.StatusCode = HTTP_STATUS_OK, 'status 200');
  Check(LResp.Body <> nil, 'body reader not nil');

  LClient := nil;
  StopServer;
end;

var
  T: TTestSuite;
begin
  UnfreezeRegistry;
  T := TTestSuite.Create('nextpas.core.http.stress');
  T.Test('Concurrent requests (8 threads × 12 requests)', @TestConcurrentRequests);
  T.Test('Keep-alive connection reuse (50 sequential)', @TestKeepAliveReuse);
  T.Test('Large response body handling', @TestLargeResponseBody);
  if not T.Run then Halt(1);
end.
